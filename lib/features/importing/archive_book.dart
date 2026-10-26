import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:koni_archive/io.dart' as ka;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../library/domain/library_models.dart';
import 'comic_importer.dart' show imageExtensions, naturalCompare;

const archivePrefix = 'archive:';
const textPrefix = 'epubtext:';

String resolveBookPath(String base, String href) {
  final decoded = Uri.decodeComponent(href.split('#').first);
  return p.posix.normalize(p.posix.join(p.posix.dirname(base), decoded));
}

Future<Json> indexBook(String source) async {
  final archive = await ka.openArchiveFile(source);
  try {
    final files = archive.entries.where((e) => e.isFile).toList();
    final metadata = <String, dynamic>{};
    final comicInfo = files
        .where((e) => p.posix.basename(e.path).toLowerCase() == 'comicinfo.xml')
        .firstOrNull;
    if (comicInfo != null) {
      final xml = XmlDocument.parse(
        utf8.decode(await archive.readBytes(comicInfo, maxSize: 1024 * 1024)),
      );
      for (final pair in {
        'Title': 'title',
        'Number': 'number',
        'Year': 'year',
        'Series': 'seriesTitle',
      }.entries) {
        final value = xml
            .findAllElements(pair.key)
            .firstOrNull
            ?.innerText
            .trim();
        if (value != null && value.isNotEmpty) metadata[pair.value] = value;
      }
    }
    List<String> pages;
    if (p.extension(source).toLowerCase() == '.epub') {
      Future<XmlDocument> xml(String path) async {
        final entry = archive.entry(path);
        if (entry == null) {
          throw const FormatException('Повреждена структура EPUB.');
        }
        return XmlDocument.parse(
          utf8.decode(await archive.readBytes(entry, maxSize: 4 * 1024 * 1024)),
        );
      }

      final container = await xml('META-INF/container.xml');
      final opfPath = container.descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.name.local == 'rootfile')
          .getAttribute('full-path')!;
      final opf = await xml(opfPath);
      final title = opf.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'title')
          .firstOrNull
          ?.innerText;
      if (title != null && title.trim().isNotEmpty) {
        metadata['title'] = title.trim();
      }
      final manifest = <String, String>{};
      for (final item in opf.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'item',
      )) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          manifest[id] = resolveBookPath(opfPath, href);
        }
      }
      pages = [];
      for (final spine in opf.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'itemref',
      )) {
        final chapterPath = manifest[spine.getAttribute('idref')];
        if (chapterPath == null) continue;
        if (imageExtensions.contains(p.extension(chapterPath).toLowerCase())) {
          pages.add('$archivePrefix$chapterPath');
          continue;
        }
        final chapter = await xml(chapterPath);
        final body = chapter.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'body')
            .firstOrNull;
        if (body == null) continue;
        final text = StringBuffer();
        void flush() {
          final value = text.toString().trim();
          if (value.isNotEmpty) {
            pages.add('$textPrefix${base64Encode(utf8.encode(value))}');
          }
          text.clear();
        }

        void visit(XmlNode node) {
          if (node is XmlText) {
            text.write(node.value);
            return;
          }
          if (node is! XmlElement ||
              {'script', 'style'}.contains(node.name.local)) {
            return;
          }
          if ({'img', 'image'}.contains(node.name.local)) {
            final href =
                node.getAttribute('src') ??
                node.attributes
                    .where((a) => a.name.local == 'href')
                    .firstOrNull
                    ?.value;
            if (href != null) {
              final path = resolveBookPath(chapterPath, href);
              if (imageExtensions.contains(p.extension(path).toLowerCase()) &&
                  archive.entry(path) != null) {
                flush();
                pages.add('$archivePrefix$path');
              }
            }
          } else {
            for (final child in node.children) {
              visit(child);
            }
            if ({
              'p',
              'div',
              'h1',
              'h2',
              'h3',
              'br',
              'li',
            }.contains(node.name.local)) {
              text.write('\n\n');
            }
          }
        }

        visit(body);
        flush();
      }
    } else {
      final images =
          files
              .where(
                (e) =>
                    !e.path.startsWith('__MACOSX/') &&
                    imageExtensions.contains(p.extension(e.path).toLowerCase()),
              )
              .toList()
            ..sort((a, b) => naturalCompare(a.path, b.path));
      var total = 0;
      for (final image in images) {
        total += image.uncompressedSize;
        if (image.uncompressedSize > 50 * 1024 * 1024 ||
            total > 1024 * 1024 * 1024) {
          throw const FormatException(
            'Распакованный выпуск превышает допустимый размер.',
          );
        }
      }
      pages = images.map((e) => '$archivePrefix${e.path}').toList();
    }
    if (pages.isEmpty || pages.length > 2000) {
      throw const FormatException('В книге должно быть от 1 до 2000 страниц.');
    }
    return {'pages': pages, 'metadata': metadata};
  } finally {
    await archive.close();
  }
}

/// Only rendered pages are decoded. The immutable source remains authoritative.
Future<String> materializePage(Json job) async {
  final page = job['page'] as String;
  if (!page.startsWith(archivePrefix)) return page;
  final source = job['source'] as String;
  final folder = Directory(p.join(p.dirname(source), 'cache'));
  await folder.create(recursive: true);
  final target = File(
    p.join(folder.path, '${job['index']}${p.extension(page).toLowerCase()}'),
  );
  if (await target.exists()) {
    await target.setLastModified(DateTime.now());
    return target.path;
  }
  final archive = await ka.openArchiveFile(source);
  try {
    final entry = archive.entry(page.substring(archivePrefix.length));
    if (entry == null || !entry.isFile) {
      throw const FormatException('Страница отсутствует в архиве.');
    }
    final bytes = await archive.readBytes(entry, maxSize: 50 * 1024 * 1024);
    final temporary = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await temporary.delete();
    } else {
      await temporary.rename(target.path);
    }
    return target.path;
  } finally {
    await archive.close();
  }
}

class PageCache {
  final Map<String, Future<String>> _inFlight = {};
  Future<String> page(String source, List<String> pages, int index) {
    if (!pages[index].startsWith(archivePrefix)) {
      return Future.value(pages[index]);
    }
    final key = '$source:$index';
    return _inFlight.putIfAbsent(
      key,
      () =>
          compute(materializePage, {
            'source': source,
            'page': pages[index],
            'index': index,
          }).whenComplete(() {
            _inFlight.remove(key);
          }),
    );
  }

  /// Evict only reproducible cache entries. Source files and covers are kept.
  Future<int> trim(Directory library, {int budget = 256 * 1024 * 1024}) async {
    final files = <File>[];
    if (!await library.exists()) return 0;
    await for (final entry in library.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is File &&
          p.basename(p.dirname(entry.path)) == 'cache' &&
          !entry.path.endsWith('.tmp')) {
        files.add(entry);
      }
    }
    final stats = <String, FileStat>{};
    var total = 0;
    for (final file in files) {
      final stat = await file.stat();
      stats[file.path] = stat;
      total += stat.size;
    }
    files.sort(
      (a, b) => stats[a.path]!.modified.compareTo(stats[b.path]!.modified),
    );
    var freed = 0;
    for (final file in files) {
      if (total <= budget) break;
      final size = stats[file.path]!.size;
      try {
        await file.delete();
        total -= size;
        freed += size;
      } on FileSystemException {
        /* A viewer may still hold a file. */
      }
    }
    return freed;
  }
}
