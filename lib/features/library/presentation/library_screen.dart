import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../importing/comic_importer.dart';
import '../../profile/profile_screen.dart';
import '../../reader/reader_screen.dart';
import '../domain/library_models.dart';

const destinations = ['Библиотека', 'Коллекции', 'Хронология', 'Профиль'];
const destinationIcons = [
  Icons.grid_view_rounded,
  Icons.folder_copy_outlined,
  Icons.route_outlined,
  Icons.person_outline,
];

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int section = 0;
  String search = '';
  int filter = 0;
  bool importing = false;
  String? selectedCollection;
  String? selectedSeries;

  Future<void> perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Не удалось выполнить действие. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    }
  }

  Future<String?> askTitle(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 180,
          decoration: const InputDecoration(labelText: 'Название'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(dialog, value);
          },
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
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    // The closing route can still render its text field during its animation.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    return result;
  }

  Future<String?> choose(String title, List<LibraryItem> items) =>
      showDialog<String>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(title),
          children: items.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Сначала создайте серию в библиотеке.'),
                  ),
                ]
              : items
                    .map(
                      (item) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(dialog, item.id),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(item.title),
                        ),
                      ),
                    )
                    .toList(),
        ),
      );
  Future<void> import() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
    );
    if (files.isEmpty) return;
    if (!mounted) return;
    setState(() => importing = true);
    await perform(() async {
      final repository = ref.read(repositoryProvider);
      final targetSeries =
          selectedSeries ?? await repository.createSeries('Без серии');
      final importer = ComicImporter(repository);
      final failures = <String>[];
      for (final file in files) {
        if (file.path == null) {
          failures.add(file.name);
          continue;
        }
        try {
          await importer.importFile(file.path!, seriesId: targetSeries);
        } catch (_) {
          failures.add(file.name);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failures.isEmpty
                  ? 'Комиксы добавлены в библиотеку'
                  : 'Не удалось импортировать: ${failures.join(', ')}. Поддерживаются CBZ, CBT, PDF и изображения.',
            ),
          ),
        );
      }
    });
    if (mounted) setState(() => importing = false);
  }

  void read(LibraryItem issue) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ReaderScreen(issue: issue)));
  }

  Future<void> issueAction(
    String action,
    LibraryItem issue,
    LibrarySnapshot library,
  ) => perform(() async {
    final repository = ref.read(repositoryProvider);
    if (action == 'series') {
      final id = await choose('Переместить в серию', library.series);
      if (id != null) await repository.assignSeries(issue, id);
    } else if (action == 'cover') {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      final path = file?.path;
      if (path != null) {
        await repository.replaceCover(issue.id, File(path));
        ref.invalidate(documentProvider(issue.id));
      }
    } else if (action == 'reset') {
      await repository.resetCover(issue.id);
      ref.invalidate(documentProvider(issue.id));
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Убрать выпуск из библиотеки?'),
          content: Text(issue.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Убрать'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await repository.save(issue.id, 'issue', issue.data, deleted: true);
      }
    }
  });
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final sync = ref.watch(syncStateProvider).value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Scaffold(
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: section,
                  onDestinationSelected: (value) =>
                      setState(() => section = value),
                  destinations: List.generate(
                    4,
                    (i) => NavigationDestination(
                      icon: Icon(destinationIcons[i]),
                      label: destinations[i],
                    ),
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  Container(
                    width: 224,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F141E),
                      border: Border(
                        right: BorderSide(color: Color(0xFF242D3D)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(25, 35, 20, 42),
                          child: Row(
                            children: [
                              Icon(
                                Icons.hub_outlined,
                                color: spiderRed,
                                size: 30,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'ПАУТИНА',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...List.generate(
                          4,
                          (i) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                selected: section == i,
                                selectedTileColor: spiderRed.withValues(
                                  alpha: .12,
                                ),
                                selectedColor: const Color(0xFFFF7C88),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                leading: Icon(destinationIcons[i]),
                                title: Text(
                                  destinations[i],
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onTap: () => setState(() => section = i),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ТВОЯ ВСЕЛЕННАЯ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: secondaryText,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                sync?.message ?? 'Локальная библиотека',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: section == 3
                      ? const ProfileScreen()
                      : library.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => const Center(
                            child: Text(
                              'Не удалось открыть библиотеку. Перезапустите приложение.',
                            ),
                          ),
                          data: (data) => buildContent(data, desktop),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildContent(LibrarySnapshot library, bool desktop) {
    final collection = library.find(selectedCollection);
    final active = library.issues.where((item) {
      final progress = library.progress[item.id];
      return progress != null && progress.page > 0 && !progress.finished;
    }).firstOrNull;
    var issues = library.issues
        .where(
          (item) =>
              item.title.toLowerCase().contains(search.toLowerCase()) &&
              (selectedSeries == null || item.seriesId == selectedSeries),
        )
        .toList();
    if (filter == 1) {
      issues = issues
          .where((i) => (library.progress[i.id]?.page ?? 0) == 0)
          .toList();
    }
    if (filter == 2) {
      issues = issues
          .where(
            (i) =>
                (library.progress[i.id]?.page ?? 0) > 0 &&
                !(library.progress[i.id]?.finished ?? false),
          )
          .toList();
    }
    if (filter == 3) {
      issues = issues
          .where((i) => library.progress[i.id]?.finished ?? false)
          .toList();
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 36 : 20,
            28,
            desktop ? 36 : 20,
            20,
          ),
          sliver: SliverList.list(
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 18,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ВАША КОМИКСНАЯ ВСЕЛЕННАЯ',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 9,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        destinations[section],
                        style: TextStyle(
                          fontSize: desktop ? 34 : 29,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${library.issues.length} выпусков · ${library.series.length} серий · ${library.collections.length} коллекций',
                        style: const TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (section == 0)
                        OutlinedButton.icon(
                          onPressed: () => perform(() async {
                            final name = await askTitle('Новая серия');
                            if (name != null) {
                              await ref
                                  .read(repositoryProvider)
                                  .createSeries(name);
                            }
                          }),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Серия'),
                        ),
                      if (section == 1)
                        FilledButton.icon(
                          onPressed: () => perform(() async {
                            final name = await askTitle('Новая коллекция');
                            if (name != null) {
                              final id = await ref
                                  .read(repositoryProvider)
                                  .createCollection(name);
                              if (mounted) {
                                setState(() => selectedCollection = id);
                              }
                            }
                          }),
                          icon: const Icon(Icons.add),
                          label: const Text('Коллекция'),
                        ),
                      if (section == 0)
                        FilledButton.icon(
                          onPressed: importing ? null : import,
                          icon: importing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add, size: 18),
                          label: Text(
                            importing ? 'Импорт…' : 'Добавить комиксы',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 26),
              if (section == 0 && active != null)
                Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ПРОДОЛЖИТЬ ЧТЕНИЕ',
                                style: TextStyle(
                                  color: Color(0xFFFF8C98),
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                active.title,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: desktop ? 26 : 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Страница ${library.progress[active.id]!.page} из ${library.progress[active.id]!.pageCount}',
                                style: const TextStyle(color: secondaryText),
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: () => read(active),
                                child: const Text('Читать дальше'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: desktop ? 116 : 75,
                          height: desktop ? 162 : 110,
                          child: ComicCover(issue: active),
                        ),
                      ],
                    ),
                  ),
                ),
              if (section == 0) ...[
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Поиск по библиотеке',
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              [
                                'Все выпуски',
                                'Не прочитано',
                                'В процессе',
                                'Прочитано',
                              ][i],
                            ),
                            selected: filter == i,
                            onSelected: (_) => setState(() => filter = i),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Все серии'),
                      selected: selectedSeries == null,
                      onSelected: (_) => setState(() => selectedSeries = null),
                    ),
                    ...library.series.map(
                      (series) => ChoiceChip(
                        label: Text(series.title),
                        selected: selectedSeries == series.id,
                        onSelected: (_) =>
                            setState(() => selectedSeries = series.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (library.issues.isEmpty) buildEmpty(),
                if (library.issues.isNotEmpty && issues.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Нет выпусков по выбранным фильтрам.'),
                  ),
              ],
              if (section == 1) ...[
                if (library.collections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Создайте коллекцию и добавьте в неё свои серии.',
                    ),
                  ),
                ...library.collections.map(
                  (item) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: const Icon(
                        Icons.folder_copy_outlined,
                        color: spiderRed,
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.seriesIds.length} серий · ${library.collectionIssues(item).length} выпусков',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() => selectedCollection = item.id),
                    ),
                  ),
                ),
                if (collection != null) ...[
                  const SizedBox(height: 22),
                  Text(collection.title, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => perform(() async {
                      final id = await choose(
                        'Добавить серию в коллекцию',
                        library.series,
                      );
                      if (id != null) {
                        await ref
                            .read(repositoryProvider)
                            .addSeries(collection, id);
                      }
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить серию'),
                  ),
                  const SizedBox(height: 16),
                  ...collection.seriesIds.map(
                    (id) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.collections_bookmark_outlined,
                        ),
                        title: Text(library.find(id)?.title ?? 'Серия'),
                        subtitle: Text(
                          '${library.issues.where((issue) => issue.seriesId == id).length} выпусков',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => section = 2),
                    child: const Text('Настроить порядок чтения →'),
                  ),
                ],
              ],
              if (section == 2) ...[
                if (library.collections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Сначала создайте коллекцию и добавьте серии.'),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: library.collections
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.title),
                          selected: selectedCollection == item.id,
                          onSelected: (_) =>
                              setState(() => selectedCollection = item.id),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                if (collection == null && library.collections.isNotEmpty)
                  const Text(
                    'Выберите коллекцию, чтобы составить свою хронологию.',
                  ),
                if (collection != null) ...[
                  const Text(
                    'Перетаскивайте выпуски за маркер справа.',
                    style: TextStyle(color: secondaryText),
                  ),
                  const SizedBox(height: 16),
                  buildReadingOrder(library, collection),
                ],
              ],
            ],
          ),
        ),
        if (section == 0 && issues.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              desktop ? 36 : 20,
              0,
              desktop ? 36 : 20,
              36,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final count = (constraints.crossAxisExtent / 200).floor().clamp(
                  2,
                  7,
                );
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => issueCard(issues[index], library),
                    childCount: issues.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 18,
                    childAspectRatio: .53,
                  ),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget buildEmpty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 38),
    child: Column(
      children: [
        const Icon(Icons.auto_stories_outlined, size: 60, color: spiderRed),
        const SizedBox(height: 20),
        const Text(
          'Твоя история начинается здесь',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        const Text(
          'Добавь CBZ, CBT, PDF или изображения.\nБиблиотека и прогресс работают без интернета.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryText, height: 1.7),
        ),
        const SizedBox(height: 25),
        TextButton(
          onPressed: () => perform(ref.read(repositoryProvider).addDemo),
          child: const Text('Посмотреть демонстрационную библиотеку'),
        ),
      ],
    ),
  );
  Widget issueCard(LibraryItem issue, LibrarySnapshot library) {
    final progress = library.progress[issue.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => read(issue),
                  child: Hero(
                    tag: 'cover-${issue.id}',
                    child: ComicCover(issue: issue),
                  ),
                ),
              ),
              Positioned(
                right: 5,
                top: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: 'Действия с выпуском',
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onSelected: (action) => issueAction(action, issue, library),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'series',
                        child: Text('Переместить в серию'),
                      ),
                      PopupMenuItem(
                        value: 'cover',
                        child: Text('Изменить обложку'),
                      ),
                      PopupMenuItem(
                        value: 'reset',
                        child: Text('Вернуть оригинальную обложку'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Убрать из библиотеки'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          issue.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 5),
        Text(
          '${issue.data['number'] == '' ? '' : '#${issue.data['number'] ?? ''} · '}${issue.format}${issue.isDemo ? ' · пример' : ''}',
          style: const TextStyle(color: secondaryText, fontSize: 11),
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: progress?.fraction ?? 0,
          minHeight: 2,
          backgroundColor: const Color(0xFF283348),
        ),
      ],
    );
  }

  Widget buildReadingOrder(LibrarySnapshot library, LibraryItem collection) {
    final issues = library.collectionIssues(collection);
    if (issues.isEmpty) {
      return const Text('В сериях этой коллекции пока нет выпусков.');
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: issues.length,
      onReorderItem: (oldIndex, newIndex) => perform(() async {
        final reordered = issues.map((i) => i.id).toList();
        final id = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, id);
        await ref.read(repositoryProvider).reorder(collection, reordered);
      }),
      itemBuilder: (context, index) {
        final issue = issues[index];
        return Card(
          key: ValueKey(issue.id),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 48, 8),
            leading: SizedBox(
              width: 38,
              height: 56,
              child: ComicCover(issue: issue),
            ),
            title: Text('${index + 1}. ${issue.title}', maxLines: 2),
            subtitle: Text(library.find(issue.seriesId)?.title ?? 'Без серии'),
            onTap: () => read(issue),
          ),
        );
      },
    );
  }
}

class ComicCover extends ConsumerWidget {
  const ComicCover({super.key, required this.issue});
  final LibraryItem issue;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(documentProvider(issue.id)).value;
    final path = document?.coverPath;
    final fallback = Container(
      color: panelColor,
      child: Center(
        child: Icon(
          issue.format == 'PDF'
              ? Icons.picture_as_pdf_outlined
              : Icons.auto_stories_outlined,
          color: spiderRed,
          size: 45,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: path != null
          ? Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 600,
              errorBuilder: (_, _, _) => fallback,
            )
          : issue.demoCover != null
          ? Image.asset(issue.demoCover!, fit: BoxFit.cover)
          : fallback,
    );
  }
}
