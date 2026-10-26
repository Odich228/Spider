import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/database/app_database.dart';
import '../features/importing/comic_importer.dart';
import '../features/library/data/library_repository.dart';
import '../features/library/domain/library_models.dart';
import '../features/sync/sync_service.dart';

final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError(),
);
final directoryProvider = Provider<Directory>(
  (_) => throw UnimplementedError(),
);
final cloudProvider = Provider<SupabaseClient?>((_) => null);
final cloudConnectionProvider = Provider<({String url, String key})>(
  (_) => (
    url: const String.fromEnvironment('SUPABASE_URL'),
    key: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  ),
);
final sessionProvider = StreamProvider<User?>((ref) async* {
  final client = ref.watch(cloudProvider);
  yield client?.auth.currentUser;
  if (client != null) {
    yield* client.auth.onAuthStateChange.map((event) => event.session?.user);
  }
});
final repositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(databaseProvider),
    ref.watch(sessionProvider).value?.id ?? 'local',
    ref.watch(directoryProvider),
  ),
);
final libraryProvider = StreamProvider<LibrarySnapshot>(
  (ref) => ref.watch(repositoryProvider).watch(),
);
final importerProvider = Provider<ComicImporter>(
  (ref) => ComicImporter(ref.watch(repositoryProvider)),
);
final documentProvider = StreamProvider.family<LocalDocument?, String>((
  ref,
  id,
) {
  final repository = ref.watch(repositoryProvider);
  return (repository.db.select(repository.db.localDocuments)..where(
        (row) => row.owner.equals(repository.owner) & row.issueId.equals(id),
      ))
      .watchSingleOrNull();
});
final syncServiceProvider = Provider<SyncService?>((ref) {
  final user = ref.watch(sessionProvider).value;
  final client = ref.watch(cloudProvider);
  if (user == null || client == null) return null;
  final repository = ref.watch(repositoryProvider);
  // Token lookup is owner-scoped even if an account changes during a request.
  final api = SupabaseClient(
    ref.watch(cloudConnectionProvider).url,
    ref.watch(cloudConnectionProvider).key,
    accessToken: () async {
      final session = client.auth.currentSession;
      if (session?.user.id != repository.owner) {
        throw const AuthException('Account changed');
      }
      return session!.accessToken;
    },
  );
  final service = SyncService(client, repository, api: api)..start();
  ref.onDispose(service.dispose);
  return service;
});
final syncStateProvider = StreamProvider<SyncState>((ref) async* {
  final service = ref.watch(syncServiceProvider);
  yield service?.state ?? const SyncState('Локальная библиотека');
  if (service != null) yield* service.events;
});
