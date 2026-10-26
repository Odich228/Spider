import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../library/domain/library_models.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.issue});
  final LibraryItem issue;
  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  PageController? pagesController;
  final pdfController = PdfViewerController();
  final keyboardFocus = FocusNode();
  bool chrome = true;
  int page = 1;
  int count = 1;
  bool initialized = false;
  bool pdfReady = false;
  void changed(int value) {
    if (!mounted) return;
    setState(() => page = value.clamp(1, count));
    unawaited(
      ref.read(repositoryProvider).saveProgress(widget.issue.id, page, count),
    );
  }

  void jump(int value) {
    final target = value.clamp(1, count);
    if (pdfReady) {
      pdfController.goToPage(pageNumber: target);
    } else {
      pagesController?.animateToPage(
        target - 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    pagesController?.dispose();
    keyboardFocus.dispose();
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
        final paths = document == null
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
          count = issue.isDemo
              ? 1
              : isPdf
              ? issue.data['pageCount'] as int? ?? 1
              : paths.length;
          count = count.clamp(1, 2000);
          page = (progress?.page ?? 1).clamp(1, count);
          pagesController = PageController(initialPage: page - 1);
          initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) changed(page);
          });
        }
        return KeyboardListener(
          focusNode: keyboardFocus,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                jump(page + 1);
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                jump(page - 1);
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
                          controller: pdfController,
                          initialPageNumber: page,
                          params: PdfViewerParams(
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
                          onTap: () => setState(() => chrome = !chrome),
                          child: PageView.builder(
                            controller: pagesController,
                            itemCount: count,
                            onPageChanged: (index) => changed(index + 1),
                            itemBuilder: (context, index) => InteractiveViewer(
                              minScale: 1,
                              maxScale: 5,
                              child: Center(
                                child: issue.isDemo
                                    ? Image.asset(
                                        'assets/demo/reader-page.png',
                                        fit: BoxFit.contain,
                                      )
                                    : Image.file(
                                        File(paths[index]),
                                        fit: BoxFit.contain,
                                        cacheWidth:
                                            (MediaQuery.sizeOf(context).width *
                                                    MediaQuery.devicePixelRatioOf(
                                                      context,
                                                    ))
                                                .round()
                                                .clamp(800, 2400),
                                        errorBuilder: (_, _, _) => const Center(
                                          child: Text(
                                            'Не удалось прочитать эту страницу.',
                                          ),
                                        ),
                                      ),
                              ),
                            ),
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
                      color: canvasColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Предыдущая страница',
                            onPressed: page > 1 ? () => jump(page - 1) : null,
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
                                ? () => jump(page + 1)
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
