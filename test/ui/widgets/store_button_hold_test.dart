/// Hold to keep spending.
///
/// Filling a facility's tier one takes ten taps and tier seven takes forty, so
/// the JS lets the invest button repeat. The interesting part is the ARMING:
/// fire immediately and every ordinary tap spends twice; fire `onTap` on
/// release as well and a hold spends one extra time at the end.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

Future<void> pumpButton(
  WidgetTester tester, {
  required VoidCallback? onTap,
  VoidCallback? onHold,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: Scaffold(
      body: Center(
        child: StoreButton(
          key: const ValueKey('the-button'),
          tone: StoreTone.coin,
          label: 'Invest',
          onTap: onTap,
          onHold: onHold,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a plain tap spends ONCE', (tester) async {
    var taps = 0;
    var holds = 0;
    await pumpButton(tester, onTap: () => taps++, onHold: () => holds++);
    await tester.tap(find.byKey(const ValueKey('the-button')));
    await tester.pump();
    expect(taps, 1);
    expect(holds, 0, reason: 'a tap is not a hold');
  });

  testWidgets('HOLDING REPEATS, once it has armed', (tester) async {
    var taps = 0;
    var holds = 0;
    await pumpButton(tester, onTap: () => taps++, onHold: () => holds++);
    final press = await tester.press(find.byKey(const ValueKey('the-button')));

    // Nothing at all until the arm time is up.
    await tester.pump(holdArms - const Duration(milliseconds: 50));
    expect(holds, 0);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(holdRepeat * 3);
    expect(holds, greaterThan(2));

    // **And the release does NOT tap.** A hold that has already spent must not
    // spend once more when the finger comes off.
    await press.up();
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('a hold that lets go before it arms is just a tap', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    await pumpButton(tester, onTap: () => taps++, onHold: () => holds++);
    final press = await tester.press(find.byKey(const ValueKey('the-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await press.up();
    await tester.pump();
    expect(holds, 0);
    expect(taps, 1);
  });

  testWidgets('THE REPEAT STOPS WHEN THE BUTTON GOES DEAD', (tester) async {
    // A hold running past the last affordable upgrade would spend coins that
    // are not there — `onTap` null is the same signal a tap reads.
    var holds = 0;
    await pumpButton(tester, onTap: () {}, onHold: () => holds++);
    final press = await tester.press(find.byKey(const ValueKey('the-button')));
    await tester.pump(holdArms + holdRepeat * 2);
    final before = holds;
    expect(before, greaterThan(0));

    await pumpButton(tester, onTap: null, onHold: () => holds++);
    await tester.pump(holdRepeat * 5);
    expect(holds, before, reason: 'it kept spending after going dead');
    await press.up();
    await tester.pump();
  });

  testWidgets('and a button with no hold behaves exactly as it did', (
    tester,
  ) async {
    var taps = 0;
    await pumpButton(tester, onTap: () => taps++);
    final press = await tester.press(find.byKey(const ValueKey('the-button')));
    await tester.pump(holdArms * 3);
    await press.up();
    await tester.pump();
    expect(taps, 1);
  });
}
