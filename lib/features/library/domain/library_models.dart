import 'dart:convert';

typedef Json = Map<String, dynamic>;

class LibraryItem {
  const LibraryItem(this.id, this.kind, this.data);
  final String id;
  final String kind;
  final Json data;
  String get title => data['title'] as String? ?? 'Без названия';
  String? get seriesId => data['seriesId'] as String?;
  String get format => data['format'] as String? ?? '';
  String? get demoCover => data['demoCover'] as String?;
  bool get isDemo => data['demo'] == true;
  List<String> get seriesIds => strings(data['seriesIds']);
  List<String> get readingOrder => strings(data['readingOrder']);
  static List<String> strings(dynamic value) =>
      value is List ? value.whereType<String>().toList() : [];
  String encode() => jsonEncode(data);
}

class ReadingProgress {
  const ReadingProgress({this.page = 0, this.pageCount = 0});
  final int page;
  final int pageCount;
  double get fraction => pageCount == 0 ? 0 : (page / pageCount).clamp(0, 1);
  bool get finished => pageCount > 0 && page >= pageCount;
}

class LibrarySnapshot {
  const LibrarySnapshot(this.items, this.progress);
  final List<LibraryItem> items;
  final Map<String, ReadingProgress> progress;
  List<LibraryItem> ofKind(String kind) =>
      items.where((item) => item.kind == kind).toList();
  List<LibraryItem> get issues => ofKind('issue');
  List<LibraryItem> get series => ofKind('series');
  List<LibraryItem> get collections => ofKind('collection');
  LibraryItem? find(String? id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<LibraryItem> collectionIssues(LibraryItem collection) {
    final members = issues
        .where((issue) => collection.seriesIds.contains(issue.seriesId))
        .toList();
    final order = collection.readingOrder;
    members.sort((a, b) {
      final ai = order.indexOf(a.id);
      final bi = order.indexOf(b.id);
      if (ai == -1 && bi == -1) return a.title.compareTo(b.title);
      return (ai == -1 ? order.length : ai).compareTo(
        bi == -1 ? order.length : bi,
      );
    });
    return members;
  }
}
