/// "✨ Legend!" rising off the square a merge landed in.
///
/// **The burst says something happened; this says what** — two halves of one
/// moment, and the port only had the first. `grid.merged_into` sat generated in
/// ten catalogues with nothing able to print it, so a merge that produced a
/// Gold and one that produced a Bronze were the same event in different
/// colours.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/grid/merged_float.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';

Future<void> pumpFloat(
  WidgetTester tester, {
  required bool playing,
  int tier = 3,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 84,
          height: 108,
          child: MergedFloat(tier: tier, playing: playing),
        ),
      ),
    ),
  ),
);

void main() {
  test('IT NAMES THE TIER, in the catalogue\'s words', () {
    // The tier name comes from `trait_copy.dart` — the same one the player
    // index uses, because two copies of "what is this tier called" is how one
    // screen ends up translated and the other does not.
    expect(mergedIntoLine(7), contains(tierName(7)));
    expect(mergedIntoLine(7), isNot(contains('{name}')));
    expect(mergedIntoLine(1), isNot(mergedIntoLine(7)));
  });

  testWidgets('nothing until a merge lands', (tester) async {
    await pumpFloat(tester, playing: false);
    expect(find.byKey(const ValueKey('merged-float')), findsNothing);
  });

  testWidgets('the words, then gone', (tester) async {
    await pumpFloat(tester, playing: true, tier: 5);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(mergedIntoLine(5)), findsOneWidget);
    await tester.pump(mergedFloatDuration);
    expect(find.byKey(const ValueKey('merged-float')), findsNothing);
  });

  testWidgets('IT RISES', (tester) async {
    await pumpFloat(tester, playing: true);
    await tester.pump(const Duration(milliseconds: 100));
    final start = tester.getTopLeft(find.byKey(const ValueKey('merged-float')));
    await tester.pump(const Duration(milliseconds: 600));
    final later = tester.getTopLeft(find.byKey(const ValueKey('merged-float')));
    expect(later.dy, lessThan(start.dy));
  });

  testWidgets('REDUCE MOTION KEEPS THE WORDS AND DROPS THE CLIMB', (
    tester,
  ) async {
    // What the merge produced is information; the rise is not. Same call the
    // burst makes about itself.
    await pumpFloat(tester, playing: true, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 100));
    final start = tester.getTopLeft(find.byKey(const ValueKey('merged-float')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('merged-float'))).dy,
      start.dy,
    );
  });

  testWidgets('THE NAME IS HELD for the length of the float', (tester) async {
    // A second merge landing elsewhere must not rewrite this one half way up.
    await pumpFloat(tester, playing: true, tier: 2);
    await tester.pump(const Duration(milliseconds: 100));
    await pumpFloat(tester, playing: true, tier: 8);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(mergedIntoLine(2)), findsOneWidget);
  });
}
