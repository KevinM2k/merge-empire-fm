/// A button that has been pressed and is waiting on an answer.
///
/// **Nothing is preloaded any more** (`services/rewarded_ads.dart`), so every
/// rewarded-video tap in the game pays a cold load and the control it was made
/// on has to say so. The requirement is three things at once: the tap cannot
/// land twice, the button says it is working, and the saying-so MOVES — a still
/// "Loading…" cannot tell a player whether the app is busy or hung.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

Future<void> pumpButton(
  WidgetTester tester, {
  required bool busy,
  VoidCallback? onTap,
  VoidCallback? onHold,
  StoreTone tone = StoreTone.ad,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: Scaffold(
      body: Center(
        child: StoreButton(
          key: const ValueKey('the-button'),
          tone: tone,
          label: 'Watch',
          busy: busy,
          onTap: onTap,
          onHold: onHold,
        ),
      ),
    ),
  ),
);

const _button = ValueKey('the-button');
const _spinner = ValueKey('store-button-busy');

void main() {
  testWidgets('A BUSY BUTTON CANNOT BE TAPPED AGAIN', (tester) async {
    var taps = 0;
    await pumpButton(tester, busy: true, onTap: () => taps++);
    await tester.tap(find.byKey(_button));
    await tester.pump();
    expect(taps, 0, reason: 'a second tap reached the caller');
  });

  testWidgets('and a HOLD cannot keep firing through the wait either', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    await pumpButton(
      tester,
      busy: true,
      onTap: () => taps++,
      onHold: () => holds++,
    );
    final press = await tester.press(find.byKey(_button));
    await tester.pump(holdArms + holdRepeat * 4);
    expect(holds, 0);
    await press.up();
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('IT SAYS SO, AND THE SAYING-SO TURNS', (tester) async {
    // The animation is the requirement rather than decoration: it is the only
    // thing on screen that separates a working app from a hung one.
    await pumpButton(tester, busy: true, onTap: () {});
    expect(find.byKey(_spinner), findsOneWidget);
    expect(find.text(t('common.loading')), findsOneWidget);
    expect(find.text('Watch'), findsNothing);

    final first = tester
        .widget<CircularProgressIndicator>(find.byKey(_spinner))
        .value;
    expect(first, isNull, reason: 'a determinate spinner does not turn');
    // And it is still going a few frames later rather than being one paint.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_spinner), findsOneWidget);
  });

  testWidgets('AND IT DROPS THE AD CHIP while it waits', (tester) async {
    // The chip answers "what does this cost me?", and the answer is already
    // given: the player has said yes and is watching the ask go out.
    await pumpButton(tester, busy: false, onTap: () {});
    expect(find.text('AD'), findsOneWidget);

    await pumpButton(tester, busy: true, onTap: () {});
    expect(find.text('AD'), findsNothing);
  });

  testWidgets('BUT IT IS NOT DRAWN AS A DEAD BUTTON', (tester) async {
    // A tap that has been taken but not yet answered is not the same thing as
    // a control that cannot be tapped, and the grey face says the wrong one.
    await pumpButton(tester, busy: true, onTap: () {});
    final busyFaded = tester.widget<Opacity>(
      find.descendant(of: find.byKey(_button), matching: find.byType(Opacity)),
    );
    expect(busyFaded.opacity, 1);

    await pumpButton(tester, busy: false, onTap: null);
    final deadFaded = tester.widget<Opacity>(
      find.descendant(of: find.byKey(_button), matching: find.byType(Opacity)),
    );
    expect(deadFaded.opacity, lessThan(1), reason: 'a dead button is faded');
  });

  testWidgets('and it goes back to a button the moment it is done', (
    tester,
  ) async {
    var taps = 0;
    await pumpButton(tester, busy: true, onTap: () => taps++);
    expect(find.byKey(_spinner), findsOneWidget);

    await pumpButton(tester, busy: false, onTap: () => taps++);
    expect(find.byKey(_spinner), findsNothing);
    expect(find.text('Watch'), findsOneWidget);
    await tester.tap(find.byKey(_button));
    await tester.pump();
    expect(taps, 1);
  });
}
