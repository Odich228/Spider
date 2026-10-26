import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/library_models.dart';
import '../../reader/reader_screen.dart';

class ReadingListsScreen extends ConsumerStatefulWidget {
  const ReadingListsScreen({super.key});
  @override
  ConsumerState<ReadingListsScreen> createState() => _ReadingListsScreenState();
}

class _ReadingListsScreenState extends ConsumerState<ReadingListsScreen> {
  String? selected;
  Future<void> create() async {
    final input = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Новый список чтения'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 180,
          decoration: const InputDecoration(
            hintText: 'Например, История чёрного костюма',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(dialog, input.text.trim());
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (title == null || !mounted) return;
    final id = await ref.read(repositoryProvider).createReadingList(title);
    if (mounted) setState(() => selected = id);
  }

  Future<void> add(LibraryItem list, LibrarySnapshot library) async {
    final ids = list.readingOrder.toSet();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Выпуски списка'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView(
              children: library.issues
                  .map(
                    (issue) => CheckboxListTile(
                      title: Text(
                        '${issue.title} #${issue.data['number'] ?? ''}',
                      ),
                      value: ids.contains(issue.id),
                      onChanged: (checked) => refresh(() {
                        checked == true
                            ? ids.add(issue.id)
                            : ids.remove(issue.id);
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, ids.toList()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await ref.read(repositoryProvider).updateReadingList(list, order: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider).value;
    if (library == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = library.find(selected);
    final issues = list == null ? <LibraryItem>[] : library.listIssues(list);
    final completed = LibraryItem.strings(list?.data['completed']);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              const Text(
                'Хронологии',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Собственные маршруты чтения с независимыми отметками. Один выпуск может входить в несколько списков.',
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: create,
                  icon: const Icon(Icons.add),
                  label: const Text('Новый список'),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: library.readingLists
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.title),
                        selected: selected == item.id,
                        onSelected: (_) => setState(() => selected = item.id),
                      ),
                    )
                    .toList(),
              ),
              if (library.readingLists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'Создайте первый маршрут и выберите выпуски из любых серий.',
                  ),
                ),
              if (list != null) ...[
                const SizedBox(height: 24),
                Text(
                  '${list.title} · ${issues.where((i) => completed.contains(i.id)).length}/${issues.length}',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => add(list, library),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Выбрать выпуски'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final controller = TextEditingController(
                          text: list.title,
                        );
                        final title = await showDialog<String>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                            title: const Text('Название списка'),
                            content: TextField(
                              controller: controller,
                              maxLength: 180,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialog),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  if (controller.text.trim().isNotEmpty) {
                                    Navigator.pop(dialog, controller.text);
                                  }
                                },
                                child: const Text('Сохранить'),
                              ),
                            ],
                          ),
                        );
                        Future<void>.delayed(
                          const Duration(seconds: 1),
                          controller.dispose,
                        );
                        if (title != null) {
                          await ref
                              .read(repositoryProvider)
                              .rename(list, title);
                        }
                      },
                      child: const Text('Переименовать'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(repositoryProvider)
                            .save(list.id, list.kind, list.data, deleted: true);
                        if (mounted) setState(() => selected = null);
                      },
                      child: const Text('Убрать список'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Перетаскивайте строки, чтобы изменить порядок. Отметки относятся только к этому списку.',
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: issues.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    final order = issues.map((i) => i.id).toList();
                    final id = order.removeAt(oldIndex);
                    order.insert(newIndex, id);
                    await ref
                        .read(repositoryProvider)
                        .updateReadingList(list, order: order);
                  },
                  itemBuilder: (context, index) {
                    final issue = issues[index];
                    return Card(
                      key: ValueKey(issue.id),
                      child: ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 8,
                          right: 50,
                        ),
                        leading: Checkbox(
                          value: completed.contains(issue.id),
                          onChanged: (checked) {
                            final next = completed.toSet();
                            checked == true
                                ? next.add(issue.id)
                                : next.remove(issue.id);
                            ref
                                .read(repositoryProvider)
                                .updateReadingList(
                                  list,
                                  completed: next.toList(),
                                );
                          },
                        ),
                        title: Text('${index + 1}. ${issue.title}'),
                        subtitle: Text(
                          '#${issue.data['number'] ?? ''} · ${library.find(issue.seriesId)?.title ?? 'Без серии'}',
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReaderScreen(issue: issue),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
