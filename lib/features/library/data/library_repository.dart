import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/library_models.dart';
import '../../importing/archive_book.dart';

class LibraryRepository {
  LibraryRepository(this.db, this.owner, this.directory);
  final AppDatabase db;
  final String owner;
  final Directory directory;
  static const uuid = Uuid();

  SimpleSelectStatement<$LibraryEntitiesTable, LibraryEntity> get _query =>
      db.select(db.libraryEntities)..where((row) => row.owner.equals(owner));

  Future<LibraryEntity?> entity(String id) =>
      (_query..where((row) => row.id.equals(id))).getSingleOrNull();

  Stream<LibrarySnapshot> watch() => _query.watch().map((rows) {
    final items = <LibraryItem>[];
    final progress = <String, ReadingProgress>{};
    for (final row in rows.where((row) => !row.deleted)) {
      final data = jsonDecode(row.payload) as Json;
      if (row.kind == 'progress') {
        progress[data['issueId'] as String] = ReadingProgress(
          page: data['page'] as int? ?? 0,
          pageCount: data['pageCount'] as int? ?? 0,
        );
      } else {
        items.add(LibraryItem(row.id, row.kind, data));
      }
    }
    items.sort((a, b) => a.title.compareTo(b.title));
    return LibrarySnapshot(items, progress);
  });

  Future<void> save(
    String id,
    String kind,
    Json data, {
    bool deleted = false,
  }) => db.transaction(() async {
    final previous = await entity(id);
    await db
        .into(db.libraryEntities)
        .insertOnConflictUpdate(
          LibraryEntitiesCompanion.insert(
            owner: owner,
            id: id,
            kind: kind,
            payload: jsonEncode(data),
            deleted: Value(deleted),
            remoteRevision: Value(previous?.remoteRevision ?? 0),
          ),
        );
    await db
        .into(db.pendingMutations)
        .insertOnConflictUpdate(
          PendingMutationsCompanion.insert(
            owner: owner,
            entityId: id,
            mutationId: uuid.v4(),
          ),
        );
  });

  Future<String> createSeries(String title) async {
    final cleaned = _title(title);
    final id = uuid.v5(
      Namespace.url.value,
      'pautina:series:${cleaned.toLowerCase()}',
    );
    final existing = await entity(id);
    if (existing != null && !existing.deleted) return id;
    await save(id, 'series', {'title': cleaned});
    return id;
  }

  Future<String> createCollection(String title) async {
    final id = uuid.v4();
    await save(id, 'collection', {
      'title': _title(title),
      'seriesIds': <String>[],
      'readingOrder': <String>[],
    });
    return id;
  }

  String _title(String value) {
    final title = value.trim();
    if (title.isEmpty || title.length > 180) {
      throw const FormatException(
        'Название должно содержать от 1 до 180 символов.',
      );
    }
    return title;
  }

  Future<void> assignSeries(LibraryItem issue, String seriesId) =>
      save(issue.id, 'issue', {...issue.data, 'seriesId': seriesId});

  Future<void> rename(LibraryItem item, String title) =>
      save(item.id, item.kind, {...item.data, 'title': _title(title)});

  Future<void> editIssue(
    LibraryItem item,
    String title,
    String number,
    String year,
  ) => save(item.id, item.kind, {
    ...item.data,
    'title': _title(title),
    'number': number.trim(),
    'year': year.trim(),
  });

  Future<void> removeSeries(LibraryItem series) => db.transaction(() async {
    final snapshot = await watch().first;
    for (final issue in snapshot.issues.where((i) => i.seriesId == series.id)) {
      await save(issue.id, 'issue', {...issue.data, 'seriesId': null});
    }
    for (final collection in snapshot.collections) {
      if (collection.seriesIds.contains(series.id)) {
        await save(collection.id, collection.kind, {
          ...collection.data,
          'seriesIds': collection.seriesIds
              .where((id) => id != series.id)
              .toList(),
        });
      }
    }
    await save(series.id, series.kind, series.data, deleted: true);
  });

  Future<void> moveIssues(Iterable<String> ids, String seriesId) =>
      db.transaction(() async {
        for (final id in ids) {
          final row = await entity(id);
          if (row != null && !row.deleted && row.kind == 'issue') {
            await save(id, 'issue', {
              ...jsonDecode(row.payload) as Json,
              'seriesId': seriesId,
            });
          }
        }
      });

  Future<String> createReadingList(String title) async {
    final id = uuid.v4();
    await save(id, 'readingList', {
      'title': _title(title),
      'readingOrder': <String>[],
      'completed': <String>[],
    });
    return id;
  }

  Future<void> updateReadingList(
    LibraryItem list, {
    List<String>? order,
    List<String>? completed,
  }) => save(list.id, list.kind, {
    ...list.data,
    if (order != null) 'readingOrder': order.toSet().toList(),
    if (completed != null) 'completed': completed.toSet().toList(),
  });

  static final settingsId = uuid.v5(Namespace.url.value, 'pautina:settings');
  Future<void> settings(Json changes) => db.transaction(() async {
    final previous = await entity(settingsId);
    await save(settingsId, 'settings', {
      ...?previous == null ? null : jsonDecode(previous.payload) as Json,
      ...changes,
    });
  });

  Future<void> toggleBookmark(String issueId, int page) =>
      db.transaction(() async {
        final id = uuid.v5(Namespace.url.value, 'pautina:bookmarks:$issueId');
        final row = await entity(id);
        final pages = row == null
            ? <int>[]
            : (jsonDecode(row.payload)['pages'] as List).cast<int>();
        pages.contains(page) ? pages.remove(page) : pages.add(page);
        pages.sort();
        await save(id, 'bookmarks', {'issueId': issueId, 'pages': pages});
      });

  /// Copy guest data without replacing existing account records or moving files.
  /// Files are copied into the account's managed directory before attaching them.
  Future<int> copyGuestLibrary() async {
    if (owner == 'local') return 0;
    final guest = LibraryRepository(db, 'local', directory);
    final rows = await guest._query.get();
    var copied = 0;
    for (final row in rows.where((row) => !row.deleted)) {
      if (await entity(row.id) != null) continue;
      final document = await guest.document(row.id);
      if (document != null) {
        final folder = Directory(p.join(directory.path, owner, row.id));
        await folder.create(recursive: true);
        Future<String> copy(String source) async {
          if (!await File(source).exists()) return source;
          final target = p.join(folder.path, p.basename(source));
          await File(source).copy(target);
          return target;
        }

        final source = await copy(document.sourcePath);
        final pages = <String>[];
        for (final path in LibraryItem.strings(
          jsonDecode(document.pagesJson),
        )) {
          pages.add(path.startsWith('archive:') ? path : await copy(path));
        }
        await attachDocument(
          row.id,
          source,
          pages,
          document.coverPath == null ? null : await copy(document.coverPath!),
        );
        if (document.coverPendingUpload) {
          await (db.update(
                db.localDocuments,
              )..where((r) => r.owner.equals(owner) & r.issueId.equals(row.id)))
              .write(
                const LocalDocumentsCompanion(coverPendingUpload: Value(true)),
              );
        }
      }
      await save(row.id, row.kind, jsonDecode(row.payload) as Json);
      copied++;
    }
    return copied;
  }

  Future<void> addSeries(LibraryItem collection, String seriesId) =>
      save(collection.id, 'collection', {
        ...collection.data,
        'seriesIds': {...collection.seriesIds, seriesId}.toList(),
      });

  Future<void> reorder(LibraryItem collection, List<String> ids) => save(
    collection.id,
    'collection',
    {...collection.data, 'readingOrder': ids.toSet().toList()},
  );

  Future<void> saveProgress(String issueId, int page, int pageCount) async {
    if (pageCount <= 0) return;
    final id = uuid.v5(Namespace.url.value, 'pautina:progress:$issueId');
    await save(id, 'progress', {
      'issueId': issueId,
      'page': page.clamp(1, pageCount),
      'pageCount': pageCount,
      'readAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<LocalDocument?> document(String id) =>
      (db.select(db.localDocuments)
            ..where((row) => row.owner.equals(owner) & row.issueId.equals(id)))
          .getSingleOrNull();

  Future<void> attachDocument(
    String id,
    String source,
    List<String> pages,
    String? cover,
  ) async {
    final previous = await document(id);
    await db
        .into(db.localDocuments)
        .insertOnConflictUpdate(
          LocalDocumentsCompanion.insert(
            owner: owner,
            issueId: id,
            sourcePath: source,
            pagesJson: jsonEncode(pages),
            coverPath: Value(previous?.coverPath ?? cover),
            coverPendingUpload: Value(previous?.coverPendingUpload ?? false),
          ),
        );
  }

  Future<void> replaceCover(String id, File source) async {
    final current = await document(id);
    if (current == null) throw StateError('Сначала загрузите файл выпуска.');
    if (await source.length() > 20 * 1024 * 1024) {
      throw const FormatException('Обложка должна быть меньше 20 МБ.');
    }
    final folder = Directory(p.join(directory.path, owner, id));
    await folder.create(recursive: true);
    final cover = await source.copy(
      p.join(
        folder.path,
        'cover-${uuid.v4()}${p.extension(source.path).toLowerCase()}',
      ),
    );
    await (db.update(
      db.localDocuments,
    )..where((row) => row.owner.equals(owner) & row.issueId.equals(id))).write(
      LocalDocumentsCompanion(
        coverPath: Value(cover.path),
        coverPendingUpload: const Value(true),
      ),
    );
  }

  Future<void> resetCover(String id) async {
    final current = await document(id);
    if (current == null) return;
    final pages = LibraryItem.strings(jsonDecode(current.pagesJson));
    final index = pages.indexWhere((page) => !page.startsWith(textPrefix));
    String? original;
    if (index >= 0) {
      final source = await materializePage({
        'source': current.sourcePath,
        'page': pages[index],
        'index': index,
      });
      original = (await File(source).copy(
        p.join(
          p.dirname(current.sourcePath),
          'original-cover${p.extension(source)}',
        ),
      )).path;
    }
    await (db.update(
      db.localDocuments,
    )..where((row) => row.owner.equals(owner) & row.issueId.equals(id))).write(
      LocalDocumentsCompanion(
        coverPath: Value(original),
        coverPendingUpload: const Value(false),
      ),
    );
    final row = await entity(id);
    if (row != null) {
      await save(id, row.kind, {
        ...jsonDecode(row.payload) as Json,
        'coverObject': null,
      });
    }
  }

  Stream<List<PendingMutation>> watchPending() => (db.select(
    db.pendingMutations,
  )..where((row) => row.owner.equals(owner))).watch();

  Future<List<PendingMutation>> pending() => (db.select(
    db.pendingMutations,
  )..where((row) => row.owner.equals(owner))).get();

  /// An acknowledgement must not erase an edit made while the request was flying.
  Future<void> acknowledge(PendingMutation mutation, int revision) =>
      db.transaction(() async {
        await (_queryForUpdate(mutation.entityId))
            .write(LibraryEntitiesCompanion(remoteRevision: Value(revision)));
        await (db.delete(db.pendingMutations)..where(
              (row) =>
                  row.owner.equals(owner) &
                  row.entityId.equals(mutation.entityId) &
                  row.mutationId.equals(mutation.mutationId),
            ))
            .go();
      });

  UpdateStatement<$LibraryEntitiesTable, LibraryEntity> _queryForUpdate(
    String id,
  ) =>
      db.update(db.libraryEntities)
        ..where((row) => row.owner.equals(owner) & row.id.equals(id));

  Future<void> mergeRemote(Json remote) => db.transaction(() async {
    final id = remote['id'] as String;
    final dirty =
        await (db.select(db.pendingMutations)..where(
              (row) => row.owner.equals(owner) & row.entityId.equals(id),
            ))
            .getSingleOrNull();
    if (dirty != null) return;
    final previous = await entity(id);
    final revision = remote['revision'] as int;
    if (previous != null && previous.remoteRevision >= revision) return;
    await db
        .into(db.libraryEntities)
        .insertOnConflictUpdate(
          LibraryEntitiesCompanion.insert(
            owner: owner,
            id: id,
            kind: remote['kind'] as String,
            payload: jsonEncode(remote['payload']),
            deleted: Value(remote['deleted'] as bool),
            remoteRevision: Value(revision),
          ),
        );
  });

  /// Explicit conflict resolution: preserve the local value, then retry against
  /// the server revision. This is only called after the user chooses it.
  Future<void> keepLocal(String id, int revision) =>
      _queryForUpdate(id)
          .write(LibraryEntitiesCompanion(remoteRevision: Value(revision)));

  Future<void> useRemote(Json remote) => db.transaction(() async {
    await (db.delete(db.pendingMutations)..where(
          (row) =>
              row.owner.equals(owner) &
              row.entityId.equals(remote['id'] as String),
        ))
        .go();
    // Reset revision to permit applying an equal revision after a conflict.
    await _queryForUpdate(remote['id'] as String)
        .write(const LibraryEntitiesCompanion(remoteRevision: Value(0)));
    await mergeRemote(remote);
  });

  Future<void> addDemo() async {
    final series = await createSeries('Демонстрационные выпуски');
    for (var i = 1; i <= 3; i++) {
      final id = uuid.v5(Namespace.url.value, 'pautina:demo:$i');
      if (await entity(id) != null) continue;
      await save(id, 'issue', {
        'title': [
          'The Amazing Spider-Man',
          'Spectacular Spider-Man',
          'Ultimate Spider-Man',
        ][i - 1],
        'number': ['300', '31', '1'][i - 1],
        'seriesId': series,
        'format': 'DEMO',
        'demo': true,
        'demoCover': 'assets/demo/cover-$i.png',
        'pageCount': 1,
      });
    }
  }
}
