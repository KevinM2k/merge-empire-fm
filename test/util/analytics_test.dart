/// What an app event is allowed to be by the time it leaves.
///
/// **The limits are Firebase's and they are applied at the boundary**, not at
/// the call sites — a parameter the SDK does not like is dropped on the floor
/// without saying so, which is the worst way for an event to be wrong.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/analytics.dart';

void main() {
  late List<({String name, Map<String, Object?> params})> sent;
  late List<({Object? message, bool fatal, StackTrace? stack})> crashes;

  setUp(() {
    sent = [];
    crashes = [];
    setAnalyticsSink((name, params) => sent.add((name: name, params: params)));
    setCrashSink((message, fatal, stack) =>
        crashes.add((message: message, fatal: fatal, stack: stack)));
  });

  tearDown(() {
    setAnalyticsSink(null);
    setCrashSink(null);
  });

  group('the sink', () {
    test('carries the event and its parameters', () {
      logAppEvent('iap_purchase', {'product_id': 'coins_small', 'price': 0.99});
      expect(sent.single.name, 'iap_purchase');
      expect(sent.single.params, {'product_id': 'coins_small', 'price': 0.99});
    });

    test('DROPPING IS THE DEFAULT, which is what a test and a dev build want', () {
      setAnalyticsSink(null);
      logAppEvent('anything');
      expect(sent, isEmpty);
    });

    test('params default to empty rather than null', () {
      logAppEvent('bare');
      expect(sent.single.params, isEmpty);
    });

    test('installing returns the sink it replaced, so a test can restore it', () {
      final first = <String>[];
      final firstSink = setAnalyticsSink((name, _) => first.add(name));
      final second = <String>[];
      final replaced = setAnalyticsSink((name, _) => second.add(name));
      logAppEvent('during');
      setAnalyticsSink(replaced);
      logAppEvent('after');

      expect(second, ['during']);
      expect(first, ['after']);
      setAnalyticsSink(firstSink);
    });

    test('A BROKEN SINK CANNOT FAIL A GAME ACTION', () {
      // The whole point of the try: an event is a side note, and a merge must
      // not fail because counting it did.
      setAnalyticsSink((_, _) => throw StateError('no network'));
      expect(() => logAppEvent('merge:happened'), returnsNormally);
    });
  });

  group('what a parameter is reduced to', () {
    Map<String, Object?> through(Map<String, Object?> params) {
      sent.clear();
      logAppEvent('e', params);
      return sent.single.params;
    }

    test('a number passes straight through', () {
      expect(through({'n': 42, 'd': 1.5}), {'n': 42, 'd': 1.5});
    });

    test('a BOOLEAN becomes 1 or 0, because that is what the JS sends', () {
      // The dashboards are built on it.
      expect(through({'a': true, 'b': false}), {'a': 1, 'b': 0});
    });

    test('a string is capped at a hundred characters', () {
      final long = 'x' * 250;
      expect((through({'s': long})['s']! as String).length, 100);
      expect(through({'s': 'short'})['s'], 'short');
    });

    test('and anything else is stringified rather than dropped', () {
      expect(through({'l': [1, 2]})['l'], '[1, 2]');
      expect(through({'n': null})['n'], '');
    });

    test('an infinite number is NOT a number as far as Firebase cares', () {
      expect(through({'x': double.infinity})['x'], isA<String>());
    });
  });

  group('coins, bucketed', () {
    test('into the six bands the reports are built on', () {
      // A raw figure is useless as a dimension: almost every value is unique.
      expect(bucketCoins(0), '<100');
      expect(bucketCoins(99), '<100');
      expect(bucketCoins(100), '100-1k');
      expect(bucketCoins(999), '100-1k');
      expect(bucketCoins(1000), '1k-10k');
      expect(bucketCoins(10000), '10k-100k');
      expect(bucketCoins(100000), '100k-1M');
      expect(bucketCoins(1000000), '1M+');
      expect(bucketCoins(50000000), '1M+');
    });
  });

  group('an error', () {
    test('IS AN EVENT AS WELL AS A CRASH REPORT', () {
      // So a spike in errors is visible beside the behaviour that caused it,
      // rather than only in a separate console.
      logError('bad thing');
      expect(sent.single.name, 'app_error');
      expect(sent.single.params['description'], 'bad thing');
      expect(sent.single.params['fatal'], 0);
      expect(crashes.single.fatal, isFalse);
    });

    test('and a fatal one is named differently', () {
      logError('very bad thing', fatal: true);
      expect(sent.single.name, 'app_crash');
      expect(sent.single.params['fatal'], 1);
      expect(crashes.single.fatal, isTrue);
    });

    test('with no crash sink it is still counted', () {
      setCrashSink(null);
      logError('bad thing');
      expect(sent, hasLength(1));
      expect(crashes, isEmpty);
    });

    test('THE STACK REACHES THE REPORT AND NOT THE EVENT', () {
      // Firebase caps a parameter at a hundred characters, so an event
      // carrying a trace would ship a truncated first line and nothing
      // useful. Crashlytics is where a symbolicated trace belongs.
      final stack = StackTrace.current;
      logError('boom', fatal: true, stack: stack);
      expect(crashes.single.stack, same(stack));
      expect(sent.single.params.containsKey('stack'), isFalse);
    });
  });

  group('a screen view', () {
    test('names the screen', () {
      logScreen('shop');
      expect(sent.single.name, 'screen_view');
      expect(sent.single.params['screen_name'], 'shop');
    });

    test('and an empty one is not an event', () {
      logScreen(null);
      logScreen('');
      expect(sent, isEmpty);
    });
  });
}
