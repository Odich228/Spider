import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../app/theme.dart';
import 'book_page.dart';
import 'pdf_layout.dart';
import '../importing/archive_book.dart';
import '../library/domain/library_models.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.issue});
  final LibraryItem issue;
  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageCache cache;
  late final Directory libraryDirectory;
  @override
  void initState() {
    super.initState();
    cache = ref.read(pageCacheProvider);
    libraryDirectory = ref.read(directoryProvider);
  }

  PageController? pagesController;
  final pdfController = PdfViewerController();
  final keyboardFocus = FocusNode();
  bool chrome = true;
  int page = 1;
  int count = 1;
  bool initialized = false;
  bool pdfReady = false;
  String mode = 'single';
  bool rtl = false, tapZones = true;
  final verticalController = ScrollController();
  double pageHeight = 600;
  String source = '';
  List<String> paths = [];
  int get stride => widget.issue.format != 'PDF' && mode == 'spread' ? 2 : 1;
  void changed(int value) {
    if (!mounted) return;
    setState(() => page = value.clamp(1, count));
    unawaited(
      ref
          .read(repositoryProvider)
          .saveProgress(
            widget.issue.id,
            (page + stride - 1).clamp(1, count),
            count,
          ),
    );
    if (widget.issue.format != 'PDF' && !widget.issue.isDemo) {
      for (final index in [
        page - 2,
        page,
        page + 1,
      ].where((i) => i >= 0 && i < paths.length)) {
        if (!paths[index].startsWith(textPrefix)) {
          unawaited(
            ref
                .read(pageCacheProvider)
                .page(source, paths, index)
                .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
      }
    }
  }

  void jump(int value) {
    final target = value.clamp(1, count);
    if (pdfReady) {
      pdfController.goToPage(pageNumber: target);
    } else if (mode == 'vertical') {
      verticalController.animateTo(
        (target - 1) * pageHeight,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      pagesController?.animateToPage(
        (target - 1) ~/ stride,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> options(bool isPdf) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Настройки чтения', style: TextStyle(fontSize: 22)),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in {
                      'single': 'Страница',
                      'spread': 'Разворот',
                      'vertical': 'Вертикально',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: mode == entry.key,
                        onSelected: (_) {
                          final old = pagesController;
                          setState(() {
                            mode = entry.key;
                            if (stride == 2) page = ((page - 1) ~/ 2) * 2 + 1;
                            if (isPdf) pdfReady = false;
                            pagesController = PageController(
                              initialPage: (page - 1) ~/ stride,
                            );
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            old?.dispose();
                            if (mounted) changed(page);
                            if (mode == 'vertical' &&
                                verticalController.hasClients) {
                              verticalController.jumpTo(
                                (page - 1) * pageHeight,
                              );
                            }
                          });
                          refresh(() {});
                          unawaited(
                            ref.read(repositoryProvider).settings({
                              'readerMode': mode,
                            }),
                          );
                        },
                      ),
                  ],
                ),

                SwitchListTile(
                  title: const Text('Справа налево'),
                  value: rtl,
                  onChanged: (value) {
                    setState(() {
                      rtl = value;
                      if (isPdf) pdfReady = false;
                    });
                    refresh(() {});
                    unawaited(
                      ref.read(repositoryProvider).settings({'rtl': value}),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Листать нажатием по краям'),
                  value: tapZones,
                  onChanged: (value) {
                    setState(() => tapZones = value);
                    refresh(() {});
                    unawaited(
                      ref.read(repositoryProvider).settings({
                        'tapZones': value,
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> contents({bool bookmarksOnly = false}) async {
    final bookmarks =
        ref.read(libraryProvider).value?.bookmarks(widget.issue.id) ?? [];
    final indices = bookmarksOnly
        ? bookmarks.map((p) => p - 1).where((i) => i >= 0 && i < count).toList()
        : List.generate(count, (i) => i);
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  bookmarksOnly ? 'Закладки' : 'Страницы',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              if (indices.isEmpty) const Text('Закладок пока нет.'),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: .65,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: indices.length,
                  itemBuilder: (context, i) {
                    final index = indices[i];
                    return InkWell(
                      onTap: () => Navigator.pop(sheet, index + 1),
                      child: Column(
                        children: [
                          Expanded(
                            child: widget.issue.format == 'PDF'
                                ? PdfPageView(
                                    document: pdfReady
                                        ? pdfController.document
                                        : null,
                                    pageNumber: index + 1,
                                    maximumDpi: 72,
                                  )
                                : BookPage(
                                    source: source,
                                    pages: paths,
                                    index: index,
                                    demo: widget.issue.isDemo,
                                    thumbnail: true,
                                  ),
                          ),
                          Text(
                            '${index + 1}${bookmarks.contains(index + 1) ? ' *' : ''}',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) jump(selected);
  }

  @override
  void dispose() {
    pagesController?.dispose();
    keyboardFocus.dispose();
    verticalController.dispose();
    if (p.isWithin(libraryDirectory.path, source)) {
      unawaited(
        cache
            .trim(libraryDirectory)
            .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final local = ref.watch(documentProvider(issue.id));
    final library = ref.watch(libraryProvider);
    final progress = library.value?.progress[issue.id];
    if (!initialized && library.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return local.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Не удалось открыть локальный файл.')),
      ),
      data: (document) {
        source = document?.sourcePath ?? '';
        paths = document == null
            ? <String>[]
            : LibraryItem.strings(jsonDecode(document.pagesJson));
        final isPdf = issue.format == 'PDF';
        if (!issue.isDemo &&
            (document == null ||
                document.sourcePath.isEmpty ||
                !File(document.sourcePath).existsSync())) {
          return Scaffold(
            appBar: AppBar(title: Text(issue.title)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Файл выпуска находится на другом устройстве.\nДобавьте тот же файл в библиотеку на этом устройстве — прогресс сохранится.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!initialized) {
          final settings = library.value?.settings ?? {};
          mode = settings['readerMode'] as String? ?? 'single';
          rtl = settings['rtl'] == true;
          tapZones = settings['tapZones'] != false;
          count = issue.isDemo
              ? 1
              : isPdf
              ? issue.data['pageCount'] as int? ?? 1
              : paths.length;
          count = count.clamp(1, 2000);
          page = (progress?.page ?? 1).clamp(1, count);
          if (stride == 2) page = ((page - 1) ~/ 2) * 2 + 1;
          pagesController = PageController(initialPage: (page - 1) ~/ stride);
          initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (mode == 'vertical' && verticalController.hasClients) {
                verticalController.jumpTo((page - 1) * pageHeight);
              }
              changed(page);
            }
          });
        }
        return KeyboardListener(
          focusNode: keyboardFocus,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space) {
                jump(page + stride);
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                jump(page + (rtl ? -stride : stride));
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                jump(page + (rtl ? stride : -stride));
              }
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                setState(() => chrome = !chrome);
              }
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF070A10),
            appBar: chrome
                ? AppBar(
                    title: Text(
                      '${issue.title} ${issue.data['number'] == '' ? '' : '#${issue.data['number'] ?? ''}'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Закладка',
                        onPressed: () => ref
                            .read(repositoryProvider)
                            .toggleBookmark(issue.id, page),
                        icon: Icon(
                          library.value?.bookmarks(issue.id).contains(page) ==
                                  true
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Меню чтения',
                        onSelected: (value) {
                          if (value == 'settings') options(isPdf);
                          if (value == 'pages') contents();
                          if (value == 'bookmarks') {
                            contents(bookmarksOnly: true);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'settings',
                            child: Text('Настройки чтения'),
                          ),
                          PopupMenuItem(
                            value: 'pages',
                            child: Text('Все страницы'),
                          ),
                          PopupMenuItem(
                            value: 'bookmarks',
                            child: Text('Закладки'),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Скрыть панели · Esc',
                        onPressed: () => setState(() => chrome = false),
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                  )
                : null,
            body: Stack(
              children: [
                Positioned.fill(
                  child: isPdf
                      ? PdfViewer.file(
                          document!.sourcePath,
                          key: ValueKey('pdf-$mode-$rtl'),
                          controller: pdfController,
                          initialPageNumber: page,
                          params: PdfViewerParams(
                            sizeDelegateProvider:
                                PdfViewerSizeDelegateProviderLegacy(
                                  useAlternativeFitScaleAsMinScale: false,
                                  calculateInitialZoom:
                                      (doc, controller, fit, cover) {
                                        final index = (page - 1).clamp(
                                          0,
                                          doc.pages.length - 1,
                                        );
                                        final first = doc.pages[index];
                                        final second =
                                            mode == 'spread' &&
                                                index + 1 < doc.pages.length
                                            ? doc.pages[index + 1]
                                            : null;
                                        final width =
                                            first.width +
                                            (second == null
                                                ? 0
                                                : second.width + 12);
                                        final height = math.max(
                                          first.height,
                                          second?.height ?? 0,
                                        );
                                        return math.min(
                                          (controller.viewSize.width - 24) /
                                              width,
                                          (controller.viewSize.height - 24) /
                                              height,
                                        );
                                      },
                                ),
                            layoutPages: (pages, params) => pdfLayout(
                              pages
                                  .map((p) => Size(p.width, p.height))
                                  .toList(),
                              mode,
                              rtl,
                            ),
                            backgroundColor: const Color(0xFF070A10),
                            onViewerReady: (doc, controller) {
                              setState(() {
                                count = doc.pages.length;
                                pdfReady = true;
                              });
                            },
                            onPageChanged: (value) {
                              if (value != null) changed(value);
                            },
                          ),
                        )
                      : GestureDetector(
                          onTapUp: (details) {
                            final ratio =
                                details.localPosition.dx /
                                MediaQuery.sizeOf(context).width;
                            if (tapZones && (ratio < .22 || ratio > .78)) {
                              jump(
                                page + ((ratio > .5) != rtl ? stride : -stride),
                              );
                            } else {
                              setState(() => chrome = !chrome);
                            }
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              pageHeight = constraints.maxHeight;
                              Widget image(int index) {
                                final child = BookPage(
                                  source: source,
                                  pages: paths,
                                  index: index,
                                  demo: issue.isDemo,
                                );
                                return index == 0
                                    ? Hero(
                                        tag: 'cover-${issue.id}',
                                        child: child,
                                      )
                                    : child;
                              }

                              if (mode == 'vertical') {
                                return NotificationListener<ScrollNotification>(
                                  onNotification: (event) {
                                    if (event.depth == 0 &&
                                        event.metrics.axis == Axis.vertical) {
                                      final value =
                                          (event.metrics.pixels / pageHeight)
                                              .round() +
                                          1;
                                      if (value != page) changed(value);
                                    }
                                    return false;
                                  },
                                  child: ListView.builder(
                                    controller: verticalController,
                                    itemExtent: pageHeight,
                                    itemCount: count,
                                    itemBuilder: (_, index) => image(index),
                                  ),
                                );
                              }
                              return PageView.builder(
                                key: ValueKey(mode),
                                controller: pagesController,
                                reverse: rtl,
                                itemCount: (count / stride).ceil(),
                                onPageChanged: (index) =>
                                    changed(index * stride + 1),
                                itemBuilder: (context, index) =>
                                    InteractiveViewer(
                                      minScale: 1,
                                      maxScale: 5,
                                      child: Center(
                                        child: stride == 1
                                            ? image(index)
                                            : Row(
                                                textDirection: rtl
                                                    ? TextDirection.rtl
                                                    : TextDirection.ltr,
                                                children: [
                                                  Expanded(
                                                    child: image(index * 2),
                                                  ),
                                                  Expanded(
                                                    child: index * 2 + 1 < count
                                                        ? image(index * 2 + 1)
                                                        : const SizedBox(),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                              );
                            },
                          ),
                        ),
                ),
                if (!chrome)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: SafeArea(
                      child: IconButton.filled(
                        tooltip: 'Показать панели',
                        onPressed: () => setState(() => chrome = true),
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: chrome
                ? SafeArea(
                    child: Container(
                      height: 72,
                      color: canvasColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Предыдущая страница',
                            onPressed: page > 1
                                ? () => jump(page - stride)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('$page / $count'),
                          Expanded(
                            child: Slider(
                              value: page.toDouble(),
                              min: 1,
                              max: count > 1 ? count.toDouble() : 2,
                              onChanged: count > 1
                                  ? (value) => jump(value.round())
                                  : null,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Следующая страница',
                            onPressed: page < count
                                ? () => jump(page + stride)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
