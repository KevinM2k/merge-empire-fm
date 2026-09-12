/// The wait between tapping "watch a video" and a video.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/shell/ad_wait_host.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {AdBusy? busy}) async {
  final container = ProviderContainer(
    overrides: [if (busy != null) adBusyProvider.overrideWith((ref) => busy)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(kitId: 'classic', light: false),
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('under'),
                onTap: () => _taps += 1,
                child: const ColoredBox(color: Color(0xFF123456)),
              ),
            ),
            const AdWaitHost(),
          ],
        ),
      ),
    ),
  );
  return container;
}

int _taps = 0;

void main() {
  setUp(() => _taps = 0);

  testWidgets('nothing is on screen while no video is being asked for', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('ad-wait')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('under')));
    expect(_taps, 1, reason: 'the app was blocked with no ad in flight');
  });

  testWidgets('A BUSY ASK SWALLOWS THE SECOND TAP, invisibly', (tester) async {
    // The barrier has to be instant; being SEEN has to wait, or an ask that
    // answers in a frame flashes a scrim over the screen on its way to a video.
    await _pump(
      tester,
      busy: (placement: 'energy_pip', slow: false, showing: false),
    );
    expect(find.byKey(const ValueKey('ad-wait')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('under')), warnIfMissed: false);
    expect(_taps, 0, reason: 'a second tap reached the button underneath');
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
      reason: 'a scrim flashed before the wait had earned one',
    );
  });

  testWidgets('and one that is really loading shows the spinner', (
    tester,
  ) async {
    await _pump(
      tester,
      busy: (placement: 'energy_pip', slow: true, showing: false),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('THE SCRIM COMES DOWN WHEN THE VIDEO GOES UP', (tester) async {
    // The ad owns the screen from here; a scrim of our own under it is a
    // second thing to dismantle when the player comes back.
    await _pump(
      tester,
      busy: (placement: 'energy_pip', slow: true, showing: true),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
  });

  testWidgets('BUT THE BARRIER DOES NOT', (tester) async {
    // What is behind the video must still be a button rather than a second ask
    // waiting to fire the moment the player taps through.
    await _pump(
      tester,
      busy: (placement: 'energy_pip', slow: false, showing: true),
    );
    await tester.tap(find.byKey(const ValueKey('under')), warnIfMissed: false);
    expect(_taps, 0, reason: 'a tap landed under a playing video');
  });
}
