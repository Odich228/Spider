import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../importing/archive_book.dart';

final pageCacheProvider = Provider((ref) => PageCache());

class BookPage extends ConsumerStatefulWidget {
  const BookPage({
    super.key,
    required this.source,
    required this.pages,
    required this.index,
    this.demo = false,
    this.thumbnail = false,
  });
  final String source;
  final List<String> pages;
  final int index;
  final bool demo, thumbnail;
  @override
  ConsumerState<BookPage> createState() => _BookPageState();
}

class _BookPageState extends ConsumerState<BookPage> {
  Future<String>? file;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(BookPage old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source || old.index != widget.index) load();
  }

  void load() {
    if (!widget.demo && !widget.pages[widget.index].startsWith(textPrefix)) {
      file = ref
          .read(pageCacheProvider)
          .page(widget.source, widget.pages, widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.demo) {
      return Image.asset('assets/demo/reader-page.png', fit: BoxFit.contain);
    }
    final page = widget.pages[widget.index];
    if (page.startsWith(textPrefix)) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          utf8.decode(base64Decode(page.substring(textPrefix.length))),
          style: TextStyle(fontSize: widget.thumbnail ? 10 : 19, height: 1.65),
        ),
      );
    }
    return FutureBuilder<String>(
      future: file,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Не удалось прочитать страницу.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.file(
          File(snapshot.data!),
          fit: BoxFit.contain,
          cacheWidth: widget.thumbnail
              ? 240
              : (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(800, 2400),
          errorBuilder: (_, _, _) =>
              const Center(child: Text('Не удалось прочитать изображение.')),
        );
      },
    );
  }
}

class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(libraryProvider).value?.settings ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Оформление и хранение', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: [
            for (final entry in {
              'classic': 'Классическая',
              'symbiote': 'Симбиот',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: (settings['theme'] ?? 'classic') == entry.key,
                onSelected: (_) =>
                    ref.read(repositoryProvider).settings({'theme': entry.key}),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Размер обложек'),
        Slider(
          value: (settings['coverSize'] as num?)?.toDouble() ?? 200,
          min: 140,
          max: 320,
          divisions: 9,
          onChanged: (value) =>
              ref.read(repositoryProvider).settings({'coverSize': value}),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final freed = await ref
                .read(pageCacheProvider)
                .trim(ref.read(directoryProvider), budget: 0);
            PaintingBinding.instance.imageCache.clear();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Освобождено ${(freed / 1048576).toStringAsFixed(1)} МБ. Исходные файлы сохранены.',
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Очистить кэш страниц'),
        ),
        const Text(
          'Кэш распакованных страниц ограничен 256 МБ и очищается после чтения.',
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
