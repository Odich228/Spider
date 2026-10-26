import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Portable metadata is kept apart from device-only paths and pending writes.
/// The owner is part of every primary key so signing out cannot leak a library.
class LibraryEntities extends Table {
  TextColumn get owner => text()();
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get remoteRevision => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {owner, id};
}

class PendingMutations extends Table {
  TextColumn get owner => text()();
  TextColumn get entityId => text()();
  TextColumn get mutationId => text()();
  @override
  Set<Column> get primaryKey => {owner, entityId};
}

class LocalDocuments extends Table {
  TextColumn get owner => text()();
  TextColumn get issueId => text()();
  TextColumn get sourcePath => text()();
  TextColumn get pagesJson => text()();
  TextColumn get coverPath => text().nullable()();
  BoolColumn get coverPendingUpload =>
      boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {owner, issueId};
}

@DriftDatabase(tables: [LibraryEntities, PendingMutations, LocalDocuments])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open(Directory directory) => AppDatabase(
    NativeDatabase.createInBackground(
      File(p.join(directory.path, 'library.db')),
    ),
  );

  @override
  int get schemaVersion => 1;
}
