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
    // The barrier has to be instant; being SEEN has to wait, or a warm ad
    // flashes a scrim over the screen on its way to a video.
    await _pump(tester, busy: (placement: 'energy_pip', slow: false));
    expect(find.byKey(const ValueKey('ad-wait')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('under')), warnIfMissed: false);
    expect(_taps, 0, reason: 'a second tap reached the button underneath');
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
      reason: 'a warm ad flashed a scrim',
    );
  });

  testWidgets('and one that is really loading shows the spinner', (
    tester,
  ) async {
    await _pump(tester, busy: (placement: 'energy_pip', slow: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
