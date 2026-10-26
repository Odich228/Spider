import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pautina/app/providers.dart';
import 'package:pautina/core/database/app_database.dart';
import 'package:pautina/features/library/data/library_repository.dart';
import 'package:pautina/main.dart';

void main() {
  for (final width in [320.0, 1400.0]) {
    testWidgets('library navigation remains usable at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            directoryProvider.overrideWithValue(Directory.systemTemp),
          ],
          child: const PautinaApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Твоя история начинается здесь'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Коллекции').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Создайте коллекцию и добавьте в неё свои серии.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Хронология').last);
      await tester.pumpAndSettle();
      expect(find.text('Хронологии'), findsOneWidget);
      await tester.tap(find.text('Профиль').last);
      await tester.pumpAndSettle();
      expect(find.text('Оформление и хранение'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('demo comics render as library cards on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    await tester.runAsync(
      () => LibraryRepository(db, 'local', Directory.systemTemp).addDemo(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          directoryProvider.overrideWithValue(Directory.systemTemp),
        ],
        child: const PautinaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Amazing Spider-Man'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
