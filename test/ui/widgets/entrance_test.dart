/// The pieces of a page arriving when its tab opens — see `entrance.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/entrance.dart';

const _box = ValueKey('box');

Widget _host({int? generation, bool still = false, DateTime? openedAt}) {
  Widget page = const Center(
    child: EntranceItem(
      index: 2,
      child: SizedBox(key: _box, width: 100, height: 100),
    ),
  );
  if (generation != null) {
    page = TabEntrance(
      generation: generation,
      openedAt: openedAt,
      child: page,
    );
  }
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Scaffold(body: page),
    ),
  );
}

Finder get _arriving => find.descendant(
  of: find.byType(EntranceItem),
  matching: find.byType(Opacity),
);

void main() {
  testWidgets('an opened tab pops its pieces on: not there, then there', (
    tester,
  ) async {
    await tester.pumpWidget(_host(generation: 1));
    // Frame zero: the third item has not started, and it is NOT on screen.
    expect(tester.widget<Opacity>(_arriving).opacity, 0);
    final flying = tester.getRect(find.byKey(_box));
    await tester.pumpAndSettle();
    final rest = tester.getRect(find.byKey(_box));
    expect(flying.height, lessThan(rest.height), reason: 'it zooms in');
    expect(
      flying.center,
      rest.center,
      reason: 'about its own centre — no drop, no travel',
    );
    expect(_arriving, findsNothing, reason: 'settled, it carries no layer');
  });

  testWidgets('AND IT BOUNCES: past its square, then back', (tester) async {
    await tester.pumpWidget(_host(generation: 1));
    await tester.pumpAndSettle();
    final rest = tester.getRect(find.byKey(_box));
    await tester.pumpWidget(_host(generation: 2));
    // Two staggers in, then two-thirds of the way through the travel: the
    // overshoot has it a shade too big.
    await tester.pump(const Duration(milliseconds: 70 + 150));
    final over = tester.getRect(find.byKey(_box));
    expect(over.height, greaterThan(rest.height), reason: 'overshoots');
    expect(over.center, rest.center, reason: 'and still has not moved');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_box)), rest, reason: 'and settles');
  });

  testWidgets('and it is quick — the whole thing lands in well under a second', (
    tester,
  ) async {
    await tester.pumpWidget(_host(generation: 1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<Opacity>(_arriving).opacity, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_arriving, findsNothing);
  });

  testWidgets('the resting rectangle IS the layout\'s', (tester) async {
    // The drop is painted, not laid out: where a piece ends up is exactly
    // where a page without the animation would have put it.
    await tester.pumpWidget(_host(generation: 1));
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(_box));
    await tester.pumpWidget(_host());
    expect(tester.getRect(find.byKey(_box)), settled);
  });

  testWidgets('and opening the tab AGAIN replays it', (tester) async {
    await tester.pumpWidget(_host(generation: 1));
    await tester.pumpAndSettle();
    expect(_arriving, findsNothing);
    await tester.pumpWidget(_host(generation: 2));
    expect(tester.widget<Opacity>(_arriving).opacity, 0);
    await tester.pumpAndSettle();
    expect(_arriving, findsNothing);
  });

  testWidgets('outside a shell nothing moves', (tester) async {
    await tester.pumpWidget(_host());
    final rest = tester.getRect(find.byKey(_box));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getRect(find.byKey(_box)), rest);
    expect(_arriving, findsNothing);
  });

  testWidgets('nor on a tab that has never been in front', (tester) async {
    // The shell mounts all five tabs at once at generation zero.
    await tester.pumpWidget(_host(generation: 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_arriving, findsNothing);
  });

  testWidgets('a piece mounting long after the open sits still', (
    tester,
  ) async {
    // A scouted card landing on the grid a minute in is not the page opening.
    // It popped in from a dot at the end of its flight — the white flash.
    await tester.pumpWidget(
      _host(
        generation: 1,
        openedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      ),
    );
    expect(_arriving, findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_arriving, findsNothing);
  });

  testWidgets('and reduced motion lands everything in place', (tester) async {
    await tester.pumpWidget(_host(generation: 1, still: true));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_arriving, findsNothing);
  });
}
