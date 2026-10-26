import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pautina/features/profile/update_settings.dart';
import 'package:pautina/features/reader/pdf_layout.dart';

void main() {
  test('updater compares app version before build number and never offers a downgrade', () {
    expect(isNewerRelease('0.1.0', 99, '0.2.0', 1), isFalse);
    expect(isNewerRelease('0.2.0', 9, '0.2.0', 8), isTrue);
    expect(isNewerRelease('0.2.0', 8, '0.2.0', 8), isFalse);
    expect(isNewerRelease('0.3.0', 1, '0.2.0', 8), isTrue);
  });
  test('PDF spreads keep mixed sizes inside the document and RTL reverses each row', () {
    const sizes = [Size(600, 900), Size(700, 1000), Size(500, 800)];
    final left = pdfLayout(sizes, 'spread', false);
    final right = pdfLayout(sizes, 'spread', true);
    for (final layout in [left, right]) {
      expect(layout.pageLayouts, hasLength(3));
      final bounds = Offset.zero & layout.documentSize;
      for (final rect in layout.pageLayouts) {
        expect(bounds.contains(rect.topLeft), isTrue);
        expect(rect.right, lessThanOrEqualTo(bounds.right));
        expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
      }
      expect(layout.pageLayouts[0].overlaps(layout.pageLayouts[1]), isFalse);
      expect(
        layout.pageLayouts[2].top,
        greaterThanOrEqualTo(layout.pageLayouts[1].bottom),
      );
    }
    expect(left.pageLayouts[0].left, lessThan(left.pageLayouts[1].left));
    expect(right.pageLayouts[0].left, greaterThan(right.pageLayouts[1].left));
  });
  test('update unpacker rejects traversal and incomplete bundles', () async {
    final scratch = await Directory.systemTemp.createTemp(
      'pautina-update-test-',
    );
    try {
      final source = File(p.join(scratch.path, 'update.zip'));
      await source.writeAsBytes(
        ZipEncoder().encode(
          Archive()..addFile(ArchiveFile.bytes('../escape.exe', [1])),
        ),
      );
      await expectLater(
        unpackWindowsUpdate({
          'zip': source.path,
          'target': p.join(scratch.path, 'app'),
        }),
        throwsFormatException,
      );
      expect(File(p.join(scratch.path, 'escape.exe')).existsSync(), isFalse);
      await source.writeAsBytes(
        ZipEncoder().encode(
          Archive()..addFile(ArchiveFile.bytes('pautina.exe', [1])),
        ),
      );
      await expectLater(
        unpackWindowsUpdate({
          'zip': source.path,
          'target': p.join(scratch.path, 'app'),
        }),
        throwsFormatException,
      );
    } finally {
      final target = p.normalize(p.absolute(scratch.path));
      if (p.dirname(target) !=
              p.normalize(p.absolute(Directory.systemTemp.path)) ||
          !p.basename(target).startsWith('pautina-update-test-')) {
        throw StateError('Unsafe cleanup');
      }
      await scratch.delete(recursive: true);
    }
  });
}
