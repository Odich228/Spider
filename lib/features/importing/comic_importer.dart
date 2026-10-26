import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../library/data/library_repository.dart';
import '../library/domain/library_models.dart';

const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
const supportedExtensions = [
  'cbz',
  'zip',
  'cbt',
  'tar',
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'webp',
];

abstract interface class ArchivePageDecoder {
  List<String> extract(String sourcePath, String destination);
}

class ZipTarPageDecoder implements ArchivePageDecoder {
  @override
  List<String> extract(String sourcePath, String destination) {
    final input = InputFileStream(sourcePath);
    Archive? archive;
    try {
      archive = {'.tar', '.cbt'}.contains(p.extension(sourcePath).toLowerCase())
          ? TarDecoder().decodeStream(input)
          : ZipDecoder().decodeStream(input, verify: true);
      final images =
          archive.files
              .where(
                (e) =>
                    e.isFile &&
                    !e.isSymbolicLink &&
                    !e.name.startsWith('__MACOSX/') &&
                    imageExtensions.contains(p.extension(e.name).toLowerCase()),
              )
              .toList()
            ..sort((a, b) => naturalCompare(a.name, b.name));
      if (images.isEmpty) {
        throw const FormatException('В архиве нет изображений страниц.');
      }
      if (images.length > 2000) {
        throw const FormatException('В выпуске больше 2000 страниц.');
      }
      var size = 0;
      for (final image in images) {
        size += image.size;
        if (image.size > 50 * 1024 * 1024 || size > 1024 * 1024 * 1024) {
          throw const FormatException(
            'Распакованный выпуск превышает допустимый размер.',
          );
        }
      }
      Directory(destination).createSync(recursive: true);
      final pages = <String>[];
      for (var i = 0; i < images.length; i++) {
        // Generate destination names: never trust a path from an archive.
        final target = p.join(
          destination,
          '${i.toString().padLeft(5, '0')}${p.extension(images[i].name).toLowerCase()}',
        );
        final output = OutputFileStream(target);
        try {
          images[i].writeContent(output);
        } finally {
          output.closeSync();
        }
        pages.add(target);
      }
      return pages;
    } finally {
      archive?.clearSync();
      input.closeSync();
    }
  }
}

int naturalCompare(String left, String right) {
  final pattern = RegExp(r'\d+|\D+');
  final a = pattern
      .allMatches(left.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();
  final b = pattern
      .allMatches(right.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();
  for (var i = 0; i < a.length && i < b.length; i++) {
    final an = int.tryParse(a[i]);
    final bn = int.tryParse(b[i]);
    final result = an != null && bn != null
        ? an.compareTo(bn)
        : a[i].compareTo(b[i]);
    if (result != 0) return result;
  }
  return a.length == b.length
      ? left.compareTo(right)
      : a.length.compareTo(b.length);
}

Future<Json> prepareImport(Json job) async {
  final source = File(job['source'] as String);
  if (await source.length() > 512 * 1024 * 1024) {
    throw const FormatException(
      'Максимальный размер файла в первой версии — 512 МБ.',
    );
  }
  final hash = (await sha256.bind(source.openRead()).first).toString();
  final id = const Uuid().v5(Namespace.url.value, 'pautina:sha256:$hash');
  final extension = p.extension(source.path).toLowerCase();
  if (!supportedExtensions.contains(
    extension.isEmpty ? '' : extension.substring(1),
  )) {
    throw const FormatException(
      'Этот формат пока не подключён. Используйте CBZ, CBT, PDF или изображения.',
    );
  }
  final folder = Directory(
    p.join(job['directory'] as String, job['owner'] as String, id),
  );
  await folder.create(recursive: true);
  final imported = p.join(folder.path, 'source$extension');
  if (p.normalize(source.path) != p.normalize(imported)) {
    await source.copy(imported);
  }
  List<String> pages = [];
  if (imageExtensions.contains(extension)) {
    pages = [imported];
  } else if (extension != '.pdf') {
    pages = ZipTarPageDecoder().extract(imported, p.join(folder.path, 'pages'));
  }
  return {'id': id, 'hash': hash, 'source': imported, 'pages': pages};
}

class ComicImporter {
  ComicImporter(this.repository);
  final LibraryRepository repository;
  Future<String> importFile(String path, {String? seriesId}) async {
    final prepared = await compute(prepareImport, {
      'source': path,
      'directory': repository.directory.path,
      'owner': repository.owner,
    });
    final id = prepared['id'] as String;
    final pages = LibraryItem.strings(prepared['pages']);
    final source = prepared['source'] as String;
    var count = pages.length;
    if (p.extension(source) == '.pdf') {
      await pdfrxFlutterInitialize();
      final document = await PdfDocument.openFile(source);
      count = document.pages.length;
      await document.dispose();
    }
    await repository.attachDocument(id, source, pages, pages.firstOrNull);
    if (await repository.entity(id) == null) {
      await repository.save(id, 'issue', {
        'title': p.basenameWithoutExtension(path),
        'number': RegExp(r'#(\d+)').firstMatch(path)?.group(1) ?? '',
        'format': p.extension(path).substring(1).toUpperCase(),
        'seriesId': seriesId,
        'fingerprint': prepared['hash'],
        'pageCount': count,
      });
    }
    return id;
  }
}
