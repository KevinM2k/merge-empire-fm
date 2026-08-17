/// A stable sort, which Dart's `List.sort` is not.
///
/// JS `Array.prototype.sort` has been required to be stable since ES2019, and
/// several ports rely on that: ranking a league by rating alone leaves genuine
/// ties, and the order they settle in decides which club gets trimmed. Dart's
/// introsort would resolve those arbitrarily.
library;

void stableSort<T>(List<T> list, int Function(T a, T b) compare) {
  final decorated = [
    for (var i = 0; i < list.length; i++) (item: list[i], index: i),
  ];
  decorated.sort((a, b) {
    final c = compare(a.item, b.item);
    return c != 0 ? c : a.index - b.index;
  });
  for (var i = 0; i < list.length; i++) {
    list[i] = decorated[i].item;
  }
}

/// [stableSort] applied to a copy, mirroring JS's `[...arr].sort(...)`.
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final out = items.toList();
  stableSort(out, compare);
  return out;
}
