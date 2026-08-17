import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/analytics.dart';

void main() {
  tearDown(() => setAnalyticsSink(null));

  test('the default sink drops events without complaint', () {
    expect(() => logAppEvent('anything', {'a': 1}), returnsNormally);
  });

  test('an installed sink receives the name and the params', () {
    final seen = <(String, Map<String, Object?>)>[];
    setAnalyticsSink((name, params) => seen.add((name, params)));
    logAppEvent('gems_earned', {'amount': 5, 'reason': 'tutorial'});
    expect(seen.length, 1);
    expect(seen.first.$1, 'gems_earned');
    expect(seen.first.$2, {'amount': 5, 'reason': 'tutorial'});
  });

  test('params default to empty rather than null', () {
    Map<String, Object?>? got;
    setAnalyticsSink((_, params) => got = params);
    logAppEvent('bare');
    expect(got, isEmpty);
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

  test('passing null goes back to dropping', () {
    final seen = <String>[];
    setAnalyticsSink((name, _) => seen.add(name));
    setAnalyticsSink(null);
    logAppEvent('ignored');
    expect(seen, isEmpty);
  });

  test('a throwing sink never fails the action that logged it', () {
    // A game action that merely happened to be worth counting must not be
    // brought down by the counting.
    setAnalyticsSink((_, _) => throw StateError('backend down'));
    expect(() => logAppEvent('gems_spent'), returnsNormally);
  });
}
