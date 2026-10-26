import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pautina/features/importing/comic_importer.dart';

void main() {
  late Directory scratch;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('pautina_test_');
  });
  tearDown(() async {
    final target = p.normalize(p.absolute(scratch.path));
    final parent = p.normalize(p.absolute(Directory.systemTemp.path));
    if (!p.isWithin(parent, target) ||
        !p.basename(target).startsWith('pautina_test_')) {
      throw StateError('Unexpected cleanup target');
    }
    await scratch.delete(recursive: true);
  });
  test('page ordering uses numeric filename parts', () {
    final names = ['page10.jpg', 'page2.jpg', 'page1.jpg']
      ..sort(naturalCompare);
    expect(names, ['page1.jpg', 'page2.jpg', 'page10.jpg']);
  });
  test('archive paths cannot escape the managed page directory', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('../../escape.png', [1, 2, 3]))
      ..addFile(ArchiveFile.bytes('chapter/10.jpg', [10]))
      ..addFile(ArchiveFile.bytes('chapter/2.jpg', [2]));
    final source = File(p.join(scratch.path, 'input.cbz'));
    await source.writeAsBytes(ZipEncoder().encode(archive));
    final target = p.join(scratch.path, 'managed');
    final pages = ZipTarPageDecoder().extract(source.path, target);
    expect(pages, hasLength(3));
    expect(pages.every((path) => p.isWithin(target, path)), isTrue);
    expect(File(p.join(scratch.path, 'escape.png')).existsSync(), isFalse);
    expect(File(pages[1]).readAsBytesSync(), [2]);
    expect(File(pages[2]).readAsBytesSync(), [10]);
  });
  test(
    'the same file has a stable cross-device identity regardless of its name',
    () async {
      final a = File(p.join(scratch.path, 'a.png'))
        ..writeAsBytesSync([1, 2, 3]);
      final b = File(p.join(scratch.path, 'renamed.png'))
        ..writeAsBytesSync([1, 2, 3]);
      final first = await prepareImport({
        'source': a.path,
        'directory': scratch.path,
        'owner': 'alice',
      });
      final second = await prepareImport({
        'source': b.path,
        'directory': scratch.path,
        'owner': 'bob',
      });
      expect(first['id'], second['id']);
      expect(first['source'], isNot(second['source']));
    },
  );
  test('an archive containing only text is rejected clearly', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('readme.txt', 'No pages'));
    final source = File(p.join(scratch.path, 'empty.cbz'))
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    expect(
      () => ZipTarPageDecoder().extract(
        source.path,
        p.join(scratch.path, 'pages'),
      ),
      throwsFormatException,
    );
  });
}
