import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

PdfPageLayout pdfLayout(List<Size> pages, String mode, bool rtl) {
  const gap = 12.0;
  final rects = <Rect>[];
  double width = gap, height = gap;
  if (mode == 'single') {
    height = pages.fold<double>(0, (h, p) => math.max(h, p.height)) + gap * 2;
    for (final page in pages) {
      rects.add(
        Rect.fromLTWH(
          width,
          (height - page.height) / 2,
          page.width,
          page.height,
        ),
      );
      width += page.width + gap;
    }
    if (rtl) {
      for (var i = 0; i < rects.length; i++) {
        final rect = rects[i];
        rects[i] = Rect.fromLTWH(
          width - rect.right,
          rect.top,
          rect.width,
          rect.height,
        );
      }
    }
  } else {
    final step = mode == 'spread' ? 2 : 1;
    for (var i = 0; i < pages.length; i += step) {
      final left = pages[i];
      final right = step == 2 && i + 1 < pages.length
          ? pages[i + 1]
          : Size.zero;
      final rowWidth =
          left.width + (right == Size.zero ? 0 : gap + right.width);
      width = math.max(width, rowWidth + gap * 2);
      rects.add(
        Rect.fromLTWH(
          rtl && right != Size.zero ? gap * 2 + right.width : gap,
          height,
          left.width,
          left.height,
        ),
      );
      if (right != Size.zero) {
        rects.add(
          Rect.fromLTWH(
            rtl ? gap : gap * 2 + left.width,
            height,
            right.width,
            right.height,
          ),
        );
      }
      height += math.max(left.height, right.height) + gap;
    }
  }
  return PdfPageLayout(pageLayouts: rects, documentSize: Size(width, height));
}
