import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/app_database.dart';
import '../library/data/library_repository.dart';
import '../library/domain/library_models.dart';

class SyncConflict {
  const SyncConflict(this.id, this.title, this.remote);
  final String id;
  final String title;
  final Json remote;
}

class SyncState {
  const SyncState(this.message, {this.busy = false, this.conflicts = const []});
  final String message;
  final bool busy;
  final List<SyncConflict> conflicts;
}

class SyncService {
  SyncService(this.client, this.repository, {required this.api});
  final SupabaseClient client;
  final SupabaseClient api;
  final LibraryRepository repository;
  final _events = StreamController<SyncState>.broadcast();
  Stream<SyncState> get events => _events.stream;
  SyncState state = const SyncState('Ожидание синхронизации');
  Timer? _poll;
  Timer? _debounce;
  StreamSubscription<dynamic>? _subscription;
  bool _busy = false;
  bool _closed = false;
  void start() {
    _subscription = repository.watchPending().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), sync);
    });
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => sync());
    unawaited(sync());
  }

  void _emit(SyncState next) {
    state = next;
    if (!_closed) _events.add(next);
  }

  Future<void> sync() async {
    if (_closed || _busy || client.auth.currentUser?.id != repository.owner) {
      return;
    }
    _busy = true;
    _emit(const SyncState('Синхронизация…', busy: true));
    try {
      await _uploadCovers();
      final conflicts = <SyncConflict>[];
      for (final mutation in await repository.pending()) {
        final row = await repository.entity(mutation.entityId);
        if (row == null) continue;
        final response = await api.rpc(
          'apply_library_mutation',
          params: {
            'p_id': row.id,
            'p_kind': row.kind,
            'p_payload': jsonDecode(row.payload),
            'p_deleted': row.deleted,
            'p_base_revision': row.remoteRevision,
            'p_mutation_id': mutation.mutationId,
          },
        ) as Json;
        final remote = response['entity'] as Json;
        if (response['conflict'] == true) {
          conflicts.add(
            SyncConflict(
              row.id,
              (jsonDecode(row.payload) as Json)['title'] as String? ??
                  'Прогресс чтения',
              remote,
            ),
          );
        } else {
          await repository.acknowledge(mutation, remote['revision'] as int);
        }
      }
      // Paginated full reconciliation does not depend on device clocks.
      String? cursor;
      while (true) {
        var query = api
            .from('library_entities')
            .select()
            .eq('user_id', repository.owner);
        if (cursor != null) query = query.gt('id', cursor);
        final batch = await query.order('id').limit(500);
        for (final remote in batch) {
          await repository.mergeRemote(remote);
          await _downloadCover(remote);
        }
        if (batch.length < 500) break;
        cursor = batch.last['id'] as String;
      }
      _emit(
        SyncState(
          conflicts.isEmpty
              ? 'Синхронизировано'
              : 'Есть изменения на другом устройстве',
          conflicts: conflicts,
        ),
      );
    } on AuthException {
      _emit(const SyncState('Войдите в аккаунт повторно.'));
    } on PostgrestException {
      _emit(
        const SyncState(
          'Облако недоступно или схема сервера ещё не установлена. Изменения сохранены локально.',
        ),
      );
    } catch (_) {
      _emit(
        const SyncState('Нет связи с облаком. Изменения сохранены локально.'),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _uploadCovers() async {
    final db = repository.db;
    final pending =
        await (db.select(db.localDocuments)..where(
              (row) =>
                  row.owner.equals(repository.owner) &
                  row.coverPendingUpload.equals(true),
            ))
            .get();
    for (final document in pending) {
      if (document.coverPath == null) continue;
      final file = File(document.coverPath!);
      final key =
          '${repository.owner}/${document.issueId}/${p.basename(file.path)}';
      await api.storage
          .from('library-covers')
          .upload(key, file, fileOptions: const FileOptions(upsert: true));
      final issue = await repository.entity(document.issueId);
      if (issue == null) continue;
      await repository.save(issue.id, issue.kind, {
        ...jsonDecode(issue.payload) as Json,
        'coverObject': key,
      });
      await (db.update(db.localDocuments)..where(
            (row) =>
                row.owner.equals(repository.owner) &
                row.issueId.equals(issue.id) &
                row.coverPath.equals(file.path),
          ))
          .write(
            const LocalDocumentsCompanion(coverPendingUpload: Value(false)),
          );
    }
  }

  Future<void> _downloadCover(Json remote) async {
    if (remote['kind'] != 'issue' || remote['deleted'] == true) return;
    final id = remote['id'] as String;
    final dirty =
        await (repository.db.select(repository.db.pendingMutations)..where(
              (row) =>
                  row.owner.equals(repository.owner) & row.entityId.equals(id),
            ))
            .getSingleOrNull();
    if (dirty != null) return;
    final object = (remote['payload'] as Json)['coverObject'] as String?;
    final local = await repository.document(id);
    if (local?.coverPendingUpload == true) return;
    if (object == null) {
      if (local == null) return;
      final original = LibraryItem.strings(jsonDecode(local.pagesJson))
          .firstOrNull;
      if (local.coverPath != original) {
        await (repository.db.update(repository.db.localDocuments)..where(
              (row) =>
                  row.owner.equals(repository.owner) & row.issueId.equals(id),
            ))
            .write(LocalDocumentsCompanion(coverPath: Value(original)));
      }
      return;
    }
    if (!object.startsWith('${repository.owner}/')) return;
    final target = File(
      p.join(
        repository.directory.path,
        repository.owner,
        remote['id'] as String,
        p.basename(object),
      ),
    );
    if (!await target.exists()) {
      final bytes = await api.storage.from('library-covers').download(object);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes);
    }
    if (local?.coverPath == target.path) return;
    await repository.attachDocument(
      remote['id'] as String,
      local?.sourcePath ?? '',
      local == null ? [] : LibraryItem.strings(jsonDecode(local.pagesJson)),
      target.path,
    );
    await (repository.db.update(repository.db.localDocuments)..where(
          (row) =>
              row.owner.equals(repository.owner) &
              row.issueId.equals(remote['id'] as String),
        ))
        .write(LocalDocumentsCompanion(coverPath: Value(target.path)));
  }

  Future<void> resolve(SyncConflict conflict, {required bool keepLocal}) async {
    if (keepLocal) {
      await repository.keepLocal(
        conflict.id,
        conflict.remote['revision'] as int,
      );
    } else {
      await repository.useRemote(conflict.remote);
    }
    await sync();
  }

  Future<void> dispose() async {
    _closed = true;
    _poll?.cancel();
    _debounce?.cancel();
    await _subscription?.cancel();
    await _events.close();
    await api.dispose();
  }
}
