import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pautina/app/providers.dart';
import 'package:pautina/app/theme.dart';
import 'package:pautina/core/database/app_database.dart';
import 'package:pautina/features/library/data/library_repository.dart';
import 'package:pautina/features/reader/reader_screen.dart';

void main() {
  testWidgets(
    'reader restores its page and persists backwards and keyboard navigation',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      final repo = LibraryRepository(db, 'local', Directory.systemTemp);
      final image = File('assets/demo/cover-1.png').absolute.path;
      await tester.runAsync(() async {
        await repo.save('comic', 'issue', {
          'title': 'Reader test',
          'format': 'CBZ',
          'pageCount': 2,
        });
        await repo.attachDocument('comic', image, [image, image], image);
        await repo.saveProgress('comic', 2, 2);
      });
      final snapshot = await tester.runAsync(() => repo.watch().first);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            directoryProvider.overrideWithValue(Directory.systemTemp),
          ],
          child: MaterialApp(
            theme: pautinaTheme(),
            home: ReaderScreen(issue: snapshot!.find('comic')!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Предыдущая страница'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      var persistedPage = 2;
      for (var i = 0; i < 20 && persistedPage != 1; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final persisted = await tester.runAsync(() => repo.watch().first);
        persistedPage = persisted!.progress['comic']!.page;
      }
      expect(persistedPage, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
