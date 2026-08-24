/// The red-to-green gauge under the sell quote.
///
/// **The figure alone says what a sale is worth and nothing about whether it is
/// a GOOD one** — which is the whole decision the market clock exists to
/// create. A position on a coloured track says it without a legend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/ui/screens/grid/sell_sheet.dart';

Future<Offset> markerAt(WidgetTester tester, double mult) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: 200, child: MarketBar(mult: mult))),
    ),
  );
  return tester.getTopLeft(find.byKey(const ValueKey('sell-market-marker')));
}

void main() {
  testWidgets('the track and its marker are both drawn', (tester) async {
    await markerAt(tester, 1.3);
    expect(find.byKey(const ValueKey('sell-market-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('sell-market-marker')), findsOneWidget);
  });

  testWidgets('A BETTER OFFER SITS FURTHER RIGHT', (tester) async {
    final lowball = await markerAt(tester, marketTiers.first.mult);
    final fair = await markerAt(tester, marketTiers[2].mult);
    final jackpot = await markerAt(tester, marketTiers.last.mult);
    expect(fair.dx, greaterThan(lowball.dx));
    expect(jackpot.dx, greaterThan(fair.dx));
  });

  testWidgets('and a jackpot is ON the bar rather than half off it', (
    tester,
  ) async {
    // The marker is inset by its own width at the far end, and the scale's top
    // is the best rung PLUS a half — so even the best roll in the game has room
    // to the right of it.
    final jackpot = await markerAt(tester, marketTiers.last.mult);
    final bar = tester.getRect(find.byKey(const ValueKey('sell-market-bar')));
    expect(jackpot.dx + 4, lessThanOrEqualTo(bar.right));
    expect(jackpot.dx, lessThan(bar.right - 4));
  });

  testWidgets('the worst possible offer is at the very left', (tester) async {
    final worst = await markerAt(tester, marketTiers.first.mult);
    final bar = tester.getRect(find.byKey(const ValueKey('sell-market-bar')));
    expect(worst.dx, bar.left);
  });
}
