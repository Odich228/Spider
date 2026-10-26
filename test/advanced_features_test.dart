import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koni_archive/io.dart' as ka;
import 'package:path/path.dart' as p;
import 'package:pautina/core/database/app_database.dart';
import 'package:pautina/features/importing/archive_book.dart';
import 'package:pautina/features/importing/comic_importer.dart';
import 'package:pautina/features/library/data/library_repository.dart';

void main() {
  late Directory scratch;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('pautina-advanced-');
  });
  tearDown(() async {
    final root = p.normalize(p.absolute(scratch.path));
    if (p.dirname(root) != p.normalize(p.absolute(Directory.systemTemp.path)) ||
        !p.basename(root).startsWith('pautina-advanced-')) {
      throw StateError('Unsafe test cleanup');
    }
    await scratch.delete(recursive: true);
  });
  test('compressed CBR is indexed and pages decode lazily', () async {
    final source = await File('test/fixtures/synthetic_comic.cbr')
        .copy(p.join(scratch.path, 'comic.cbr'));
    final book = await indexBook(source.path);
    final pages = (book['pages'] as List).cast<String>();
    expect(pages, hasLength(3));
    expect(await Directory(p.join(scratch.path, 'cache')).exists(), isFalse);
    final page = await PageCache().page(source.path, pages, 2);
    expect(await File(page).length(), 1032);
    expect((await File(page).readAsBytes()).take(8), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
    expect(await Directory(p.join(scratch.path, 'cache')).list().length, 1);
    expect(await PageCache().trim(scratch, budget: 0), 1032);
    expect(await File(source.path).exists(), isTrue);
    expect(
      await File(await PageCache().page(source.path, pages, 2)).length(),
      1032,
    );
  });
  test('CB7 page bytes and natural order survive 7z compression', () async {
    final source = p.join(scratch.path, 'comic.cb7');
    final writer = await ka.createArchiveFile(
      source,
      format: const ka.SevenZWriteFormat(),
    );
    await writer.addBytes(
      ka.ArchiveEntrySpec(path: 'page10.png'),
      Uint8List.fromList([10, 10, 10]),
    );
    await writer.addBytes(
      ka.ArchiveEntrySpec(path: 'page2.png'),
      Uint8List.fromList([2, 2, 2]),
    );
    await writer.close();
    final pages = ((await indexBook(source))['pages'] as List).cast<String>();
    expect(pages.first, endsWith('page2.png'));
    expect(await File(await PageCache().page(source, pages, 0)).readAsBytes(), [
      2,
      2,
      2,
    ]);
  });
  test(
    'EPUB respects spine order and interleaves chapter text and images',
    () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'META-INF/container.xml',
            '<container><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OPS/book.opf',
            '<package><metadata><title>My Book</title></metadata><manifest><item id="b" href="b.xhtml"/><item id="a" href="a.xhtml"/></manifest><spine><itemref idref="b"/><itemref idref="a"/></spine></package>',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OPS/a.xhtml',
            '<html><body><img src="images/a.png"/></body></html>',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OPS/b.xhtml',
            '<html><body><p>First chapter</p><img src="images/b.png"/><p>After image</p></body></html>',
          ),
        )
        ..addFile(ArchiveFile.bytes('OPS/images/a.png', [1]))
        ..addFile(ArchiveFile.bytes('OPS/images/b.png', [2]));
      final source = File(p.join(scratch.path, 'book.epub'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final book = await indexBook(source.path);
      final pages = (book['pages'] as List).cast<String>();
      expect(book['metadata']['title'], 'My Book');
      expect(pages, hasLength(4));
      expect(
        utf8.decode(base64Decode(pages[0].substring(textPrefix.length))),
        'First chapter',
      );
      expect(pages[1], 'archive:OPS/images/b.png');
      expect(pages[3], 'archive:OPS/images/a.png');
    },
  );
  test(
    'ComicInfo metadata imports and only cover is decoded initially',
    () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'ComicInfo.xml',
            '<ComicInfo><Title>Web story</Title><Number>7</Number><Year>1994</Year><Series>Web</Series></ComicInfo>',
          ),
        )
        ..addFile(ArchiveFile.bytes('1.png', [1]))
        ..addFile(ArchiveFile.bytes('2.png', [2]));
      final source = File(p.join(scratch.path, 'book.cbz'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LibraryRepository(db, 'local', scratch);
      final id = await ComicImporter(repo).importFile(source.path);
      final snapshot = await repo.watch().first;
      final issue = snapshot.find(id)!;
      expect(issue.title, 'Web story');
      expect(issue.data['number'], '7');
      expect(issue.data['year'], '1994');
      expect(snapshot.find(issue.seriesId)!.title, 'Web');
      final doc = (await repo.document(id))!;
      expect(
        jsonDecode(doc.pagesJson),
        everyElement(startsWith(archivePrefix)),
      );
      expect(
        await Directory(p.join(p.dirname(doc.sourcePath), 'cache'))
            .list()
            .length,
        1,
      );
    },
  );
  test(
    'lists have independent progress; series deletion preserves issues',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LibraryRepository(db, 'alice', scratch);
      final series = await repo.createSeries('Web');
      await repo.save('issue', 'issue', {'title': 'Story', 'seriesId': series});
      await repo.rename(
        (await repo.watch().first).find(series)!,
        'Renamed web',
      );
      expect(await repo.createSeries('Web'), series);
      expect((await repo.watch().first).find(series)!.title, 'Renamed web');
      final first = await repo.createReadingList('Chronology');
      final second = await repo.createReadingList('Reread');
      var snapshot = await repo.watch().first;
      await repo.updateReadingList(
        snapshot.find(first)!,
        order: ['issue'],
        completed: ['issue'],
      );
      await repo.updateReadingList(snapshot.find(second)!, order: ['issue']);
      await repo.saveProgress('issue', 2, 10);
      await repo.toggleBookmark('issue', 2);
      await repo.toggleBookmark('issue', 5);
      await repo.toggleBookmark('issue', 2);
      await repo.settings({'theme': 'symbiote'});
      await repo.settings({'coverSize': 260});
      snapshot = await repo.watch().first;
      expect(snapshot.find(first)!.data['completed'], ['issue']);
      expect(snapshot.find(second)!.data['completed'], isEmpty);
      expect(snapshot.progress['issue']!.page, 2);
      expect(snapshot.bookmarks('issue'), [5]);
      expect(snapshot.settings, containsPair('theme', 'symbiote'));
      await repo.removeSeries(snapshot.find(series)!);
      snapshot = await repo.watch().first;
      expect(snapshot.issues, hasLength(1));
      expect(snapshot.issues.single.seriesId, isNull);
      expect(snapshot.listIssues(snapshot.find(first)!), hasLength(1));
    },
  );
  test(
    'guest transfer copies files and preserves existing account records',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final guest = LibraryRepository(db, 'local', scratch);
      final account = LibraryRepository(db, 'alice', scratch);
      final image = File(p.join(scratch.path, 'page.png'))
        ..writeAsBytesSync([1, 2, 3]);
      final id = await ComicImporter(guest).importFile(image.path);
      await guest.save('shared', 'series', {'title': 'Guest title'});
      await account.save('shared', 'series', {'title': 'Account title'});
      expect(await account.copyGuestLibrary(), 1);
      final doc = (await account.document(id))!;
      expect(p.isWithin(p.join(scratch.path, 'alice'), doc.sourcePath), isTrue);
      expect(await File(doc.sourcePath).readAsBytes(), [1, 2, 3]);
      expect(
        (await account.watch().first).find('shared')!.title,
        'Account title',
      );
      expect(await account.copyGuestLibrary(), 0);
    },
  );
}
