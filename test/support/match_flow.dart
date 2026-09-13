/// Getting a widget test through ninety minutes the way a player would.
///
/// **COACH COLIN IS WHY THIS EXISTS.** His card is a `Positioned.fill` with no
/// barrier of its own — see `CoachCorner` — so it covers the match controls,
/// and the rule is that a tap anywhere is done with it. A test that taps SKIP
/// while he is talking therefore dismisses HIM and never presses the button;
/// the match runs on, the screen stays up, and the failure lands forty lines
/// later in an assertion about coins or about the season having moved.
///
/// Two tests hit that when the feed started coming off the positional record
/// and a tactical tip began arriving at minute five. It is not a fault in
/// either of them, and it is not a fault in the tip — it is that dismissing him
/// is a step, and both had it written inline with a guard that assumed he
/// only ever speaks at full time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clear Colin if he is on screen, and assert he has gone.
///
/// **The loop is not paranoia**: the whistle can put a second line up the frame
/// after the first is dismissed — a reaction behind a tip — and one tap then
/// leaves the page still covered. It ends in an unconditional assertion, so a
/// card that will not clear fails HERE, naming him, rather than somewhere later
/// that is about something else.
Future<void> dismissCoachLine(WidgetTester tester, {int taps = 3}) async {
  final colin = find.byKey(const ValueKey('match-coach-line'));
  for (var i = 0; i < taps && colin.evaluate().isNotEmpty; i++) {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }
  expect(colin, findsNothing, reason: 'his bubble covers the match controls');
}

/// Skip to the whistle and press the way out.
///
/// **FULL TIME WAITS.** The page used to leave on its own 1.4s after the sting;
/// it holds now so the ninety minutes can be read back, and the row of controls
/// becomes one CONTINUE — so a test that plays a match has to press it, the
/// same way it has to answer a post-match card.
///
/// The 1.4s leave is a plain `Timer`, which `pumpAndSettle` does not reach on
/// its own: it advances the clock only while frames are pending, and a finished
/// match schedules none. The explicit pump is what fires it.
Future<void> skipToFullTime(WidgetTester tester) async {
  // Before the button, because he may already be standing in front of it.
  await dismissCoachLine(tester);
  final skip = find.byKey(const ValueKey('match-skip'));
  if (skip.evaluate().isNotEmpty) await tester.tap(skip);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
  // And again at the whistle: he reacts to a result worth a sentence.
  await dismissCoachLine(tester);
  final go = find.byKey(const ValueKey('match-continue'));
  if (go.evaluate().isNotEmpty) {
    await tester.tap(go);
    await tester.pumpAndSettle();
  }
}
