/// "+66" rising off a card once per fill of its income bar — the JS's
/// `floatCoinTick`. The bar was ported; the coins coming off it were not, so
/// idle income was a counter changing in a corner rather than money seen
/// leaving the players who earn it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/grid/coin_tick_float.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

Future<void> pumpHost(
  WidgetTester tester, {
  required double amount,
  bool enabled = true,
  required void Function(VoidCallback fire) grab,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: Center(
      child: SizedBox(
        width: 84,
        height: 108,
        child: CoinTickHost(
          amount: amount,
          enabled: enabled,
          builder: (onCycle) {
            grab(onCycle);
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  ),
);

void main() {
  test('THE LABEL IS THE JS\'S: compact past 1k, 2dp under 1', () {
    expect(coinTickLabel(1234), '+1,234');
    expect(coinTickLabel(125000), '+125k');
    expect(coinTickLabel(0.5), '+0.50');
    expect(coinTickLabel(66), '+66');
    expect(coinTickLabel(66.4), '+66.4');
    expect(coinTickLabel(12, negative: true), '-12');
  });

  testWidgets('nothing until a cycle completes', (tester) async {
    await pumpHost(tester, amount: 66, grab: (_) {});
    expect(find.byKey(const ValueKey('coin-tick')), findsNothing);
  });

  testWidgets('one cycle floats the payout, then it is gone', (tester) async {
    late VoidCallback fire;
    await pumpHost(tester, amount: 66.4, grab: (f) => fire = f);
    fire();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+66.4'), findsOneWidget);
    await tester.pump(coinTickDuration);
    await tester.pump();
    expect(find.byKey(const ValueKey('coin-tick')), findsNothing);
  });

  testWidgets('IT RISES and fades', (tester) async {
    late VoidCallback fire;
    await pumpHost(tester, amount: 66, grab: (f) => fire = f);
    fire();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final early = tester.getCenter(find.byKey(const ValueKey('coin-tick')));
    await tester.pump(const Duration(milliseconds: 600));
    final late = tester.getCenter(find.byKey(const ValueKey('coin-tick')));
    expect(late.dy, lessThan(early.dy));
  });

  testWidgets('a drag mutes it, as in the JS', (tester) async {
    late VoidCallback fire;
    await pumpHost(tester, amount: 66, enabled: false, grab: (f) => fire = f);
    fire();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('coin-tick')), findsNothing);
  });

  testWidgets('a rate of nothing floats nothing', (tester) async {
    late VoidCallback fire;
    await pumpHost(tester, amount: 0, grab: (f) => fire = f);
    fire();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('coin-tick')), findsNothing);
  });
}
