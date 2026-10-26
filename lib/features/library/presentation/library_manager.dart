import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/library_models.dart';

Future<void> editIssueDialog(
  BuildContext context,
  WidgetRef ref,
  LibraryItem issue,
) async {
  final title = TextEditingController(text: issue.title);
  final number = TextEditingController(text: '${issue.data['number'] ?? ''}');
  final year = TextEditingController(text: '${issue.data['year'] ?? ''}');
  final save = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Редактировать выпуск'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 180,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: number,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Номер'),
            ),
            TextField(
              controller: year,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Год'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isNotEmpty) Navigator.pop(dialog, true);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  if (save == true) {
    await ref
        .read(repositoryProvider)
        .editIssue(issue, title.text, number.text, year.text);
  }
  Future<void>.delayed(const Duration(seconds: 1), () {
    title.dispose();
    number.dispose();
    year.dispose();
  });
}

class LibraryManager extends ConsumerStatefulWidget {
  const LibraryManager({super.key});
  @override
  ConsumerState<LibraryManager> createState() => _LibraryManagerState();
}

class _LibraryManagerState extends ConsumerState<LibraryManager> {
  final selected = <String>{};
  bool duplicates = false;
  String query = '';
  String? target;
  Future<void> seriesAction(LibraryItem series, bool remove) async {
    final controller = TextEditingController(text: series.title);
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(remove ? 'Убрать серию?' : 'Название серии'),
        content: remove
            ? const Text(
                'Выпуски останутся в библиотеке без привязки к этой серии.',
              )
            : TextField(controller: controller, maxLength: 180),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (remove || controller.text.trim().isNotEmpty) {
                Navigator.pop(dialog, controller.text);
              }
            },
            child: Text(remove ? 'Убрать' : 'Сохранить'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    if (result == null) return;
    final repo = ref.read(repositoryProvider);
    if (remove) {
      await repo.removeSeries(series);
      if (mounted && target == series.id) setState(() => target = null);
    } else {
      await repo.rename(series, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider).value;
    if (library == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final duplicateIds = library.possibleDuplicates;
    final issues = library.issues
        .where(
          (i) =>
              (!duplicates || duplicateIds.contains(i.id)) &&
              i.title.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Управление библиотекой')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Серии', style: TextStyle(fontSize: 24)),
          ...library.series.map(
            (series) => ListTile(
              title: Text(series.title),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Переименовать серию',
                    onPressed: () => seriesAction(series, false),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Убрать серию',
                    onPressed: () => seriesAction(series, true),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const Text('Выпуски', style: TextStyle(fontSize: 24)),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Найти выпуски',
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          SwitchListTile(
            title: const Text('Возможные дубликаты'),
            subtitle: const Text(
              'Совпадение названия, номера и года; одинаковые файлы объединяются при импорте.',
            ),
            value: duplicates,
            onChanged: (value) => setState(() => duplicates = value),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  selected.clear();
                  selected.addAll(issues.map((i) => i.id));
                }),
                child: const Text('Выбрать найденные'),
              ),
              TextButton(
                onPressed: () => setState(selected.clear),
                child: const Text('Снять выбор'),
              ),
              DropdownButton<String>(
                hint: const Text('В серию'),
                value: library.find(target) == null ? null : target,
                items: library.series
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => target = value),
              ),
              FilledButton(
                onPressed: selected.isEmpty || target == null
                    ? null
                    : () async {
                        await ref
                            .read(repositoryProvider)
                            .moveIssues(selected, target!);
                        if (mounted) setState(selected.clear);
                      },
                child: Text('Переместить (${selected.length})'),
              ),
            ],
          ),
          ...issues.map(
            (issue) => CheckboxListTile(
              value: selected.contains(issue.id),
              title: Text(issue.title),
              subtitle: Text(
                '#${issue.data['number'] ?? ''} · ${issue.data['year'] ?? ''} · ${library.find(issue.seriesId)?.title ?? 'Без серии'}',
              ),
              secondary: IconButton(
                tooltip: 'Редактировать выпуск',
                onPressed: () => editIssueDialog(context, ref, issue),
                icon: const Icon(Icons.edit_outlined),
              ),
              onChanged: (value) => setState(() {
                value == true
                    ? selected.add(issue.id)
                    : selected.remove(issue.id);
              }),
            ),
          ),
        ],
      ),
    );
  }
}
