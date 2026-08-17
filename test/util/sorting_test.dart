import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/sorting.dart';

typedef _Item = ({String key, int order});

int _byKey(_Item a, _Item b) => a.key.compareTo(b.key);

void main() {
  group('stableSort', () {
    test('sorts', () {
      final list = [3, 1, 2];
      stableSort(list, (a, b) => a - b);
      expect(list, [1, 2, 3]);
    });

    test('keeps equal elements in the order they arrived', () {
      // This is the whole reason the helper exists: JS has guaranteed a stable
      // sort since ES2019, and several ports lean on it — ranking a league by
      // rating alone leaves genuine ties, and the order they settle in decides
      // which club gets trimmed.
      final list = <_Item>[
        (key: 'a', order: 0),
        (key: 'b', order: 1),
        (key: 'a', order: 2),
        (key: 'b', order: 3),
        (key: 'a', order: 4),
      ];
      stableSort(list, _byKey);
      expect(list.map((e) => e.order), [0, 2, 4, 1, 3]);
    });

    test('holds across a list long enough to leave the insertion-sort path', () {
      // Dart's introsort only degrades to an unstable algorithm above a size
      // threshold, so a short fixture would pass with no helper at all.
      final list = [
        for (var i = 0; i < 500; i++) (key: 'k${i % 3}', order: i),
      ];
      stableSort(list, _byKey);
      for (final k in ['k0', 'k1', 'k2']) {
        final orders = list.where((e) => e.key == k).map((e) => e.order).toList();
        expect(orders, List<int>.from(orders)..sort(), reason: k);
      }
    });

    test('mutates in place', () {
      final list = [2, 1];
      final same = list;
      stableSort(list, (a, b) => a - b);
      expect(identical(list, same), isTrue);
      expect(same, [1, 2]);
    });

    test('an empty list and a single element are both fine', () {
      final empty = <int>[];
      stableSort(empty, (a, b) => a - b);
      expect(empty, isEmpty);

      final one = [7];
      stableSort(one, (a, b) => a - b);
      expect(one, [7]);
    });

    test('a comparator that says everything is equal changes nothing', () {
      final list = [3, 1, 2];
      stableSort(list, (a, b) => 0);
      expect(list, [3, 1, 2]);
    });
  });

  group('stableSorted', () {
    test('returns a new list and leaves the original alone', () {
      final list = [3, 1, 2];
      final sorted = stableSorted(list, (a, b) => a - b);
      expect(sorted, [1, 2, 3]);
      expect(list, [3, 1, 2]);
    });

    test('takes any iterable', () {
      expect(stableSorted({3, 1, 2}, (a, b) => a - b), [1, 2, 3]);
    });

    test('is stable too', () {
      final sorted = stableSorted(<_Item>[
        (key: 'b', order: 0),
        (key: 'a', order: 1),
        (key: 'b', order: 2),
      ], _byKey);
      expect(sorted.map((e) => e.order), [1, 0, 2]);
    });
  });
}
