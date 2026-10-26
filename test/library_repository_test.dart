import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pautina/core/database/app_database.dart';
import 'package:pautina/features/library/data/library_repository.dart';

void main() {
  late AppDatabase db;
  late LibraryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepository(db, 'alice', Directory.systemTemp);
  });
  tearDown(() => db.close());
  test('acknowledgement cannot erase an edit made during upload', () async {
    await repo.save('issue', 'issue', {'title': 'First'});
    final sent = (await repo.pending()).single;
    await repo.save('issue', 'issue', {'title': 'Edited offline'});
    await repo.acknowledge(sent, 1);
    expect((await repo.pending()).single.mutationId, isNot(sent.mutationId));
    expect((await repo.entity('issue'))!.remoteRevision, 1);
    expect((await repo.watch().first).find('issue')!.title, 'Edited offline');
  });
  test('remote reconciliation preserves dirty local changes', () async {
    await repo.save('issue', 'issue', {'title': 'Local'});
    await repo.mergeRemote({
      'id': 'issue',
      'kind': 'issue',
      'payload': {'title': 'Remote'},
      'revision': 4,
      'deleted': false,
    });
    expect((await repo.watch().first).find('issue')!.title, 'Local');
    await repo.useRemote({
      'id': 'issue',
      'kind': 'issue',
      'payload': {'title': 'Remote'},
      'revision': 4,
      'deleted': false,
    });
    expect(await repo.pending(), isEmpty);
    expect((await repo.watch().first).find('issue')!.title, 'Remote');
  });
  test(
    'accounts with the same entity ID have independent libraries and outboxes',
    () async {
      final other = LibraryRepository(db, 'bob', Directory.systemTemp);
      await repo.save('same', 'series', {'title': 'Alice'});
      await other.save('same', 'series', {'title': 'Bob'});
      expect((await repo.watch().first).series.single.title, 'Alice');
      expect((await other.watch().first).series.single.title, 'Bob');
      await other.acknowledge((await other.pending()).single, 1);
      expect(await other.pending(), isEmpty);
      expect(await repo.pending(), hasLength(1));
    },
  );
  test('progress supports rereading and clamps out-of-range pages', () async {
    await repo.saveProgress('comic', 99, 20);
    expect((await repo.watch().first).progress['comic']!.page, 20);
    await repo.saveProgress('comic', 3, 20);
    expect((await repo.watch().first).progress['comic']!.page, 3);
    await repo.saveProgress('comic', -1, 20);
    expect((await repo.watch().first).progress['comic']!.page, 1);
  });
  test(
    'one series can belong to multiple collections with independent orders',
    () async {
      final series = await repo.createSeries('Amazing');
      final first = await repo.createCollection('Publication order');
      final second = await repo.createCollection('My order');
      await repo.save('a', 'issue', {'title': 'A', 'seriesId': series});
      await repo.save('b', 'issue', {'title': 'B', 'seriesId': series});
      var snapshot = await repo.watch().first;
      await repo.addSeries(snapshot.find(first)!, series);
      await repo.addSeries(snapshot.find(second)!, series);
      snapshot = await repo.watch().first;
      await repo.reorder(snapshot.find(second)!, ['b', 'a']);
      snapshot = await repo.watch().first;
      expect(
        snapshot.collectionIssues(snapshot.find(first)!).map((i) => i.id),
        ['a', 'b'],
      );
      expect(
        snapshot.collectionIssues(snapshot.find(second)!).map((i) => i.id),
        ['b', 'a'],
      );
    },
  );
}
