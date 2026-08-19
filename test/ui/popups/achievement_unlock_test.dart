/// The banner an achievement arrives on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/achievement_unlock.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Future<void> pumpHost(WidgetTester tester, {double height = 800}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: MediaQuery(
          data: MediaQueryData(size: Size(400, height)),
          child: const AchievementUnlockHost(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );

/// What the engine actually puts on the bus.
Map<String, dynamic> _payload({
  String id = 'first_merge',
  int coins = 0,
  int count = 1,
  bool reUnlock = false,
}) => {
  'id': id,
  'title': 'On the record',
  'description': 'Off the record',
  'category': 'merge',
  'coinsRewarded': coins,
  'isReUnlock': reUnlock,
  'count': count,
};

AchievementUnlockHostState _host(WidgetTester tester) =>
    tester.state<AchievementUnlockHostState>(
      find.byType(AchievementUnlockHost),
    );

void main() {
  tearDown(() {
    clearBus();
    resetLocale();
  });

  group('what it reads off the bus', () {
    test('the CATALOGUE names it, and the payload is the fallback', () {
      // The engine puts the definition's English title on the bus. It is the
      // fallback, not the copy — same order the shop resolves a product in.
      final unlock = achievementUnlockFrom(_payload())!;
      expect(unlock.title, t('ach.title.first_merge'));
      expect(unlock.title, isNot('On the record'));
      expect(unlock.description, t('ach.desc.first_merge'));

      final unknown = achievementUnlockFrom(_payload(id: 'no_such_thing'))!;
      expect(unknown.title, 'On the record', reason: 'nothing to look up');
    });

    test('the reward and the repeat count come through', () {
      final unlock = achievementUnlockFrom(
        _payload(coins: 2500, count: 3, reUnlock: true),
      )!;
      expect(unlock.coinsRewarded, 2500);
      expect(unlock.count, 3);
      expect(unlock.isReUnlock, isTrue);
    });

    test('anything that is not an unlock is nothing', () {
      expect(achievementUnlockFrom(null), isNull);
      expect(achievementUnlockFrom('first_merge'), isNull);
      expect(achievementUnlockFrom(<String, dynamic>{}), isNull);
      expect(achievementUnlockFrom({'id': ''}), isNull);
    });
  });

  group('on screen', () {
    testWidgets('it leads with the achievement, by name', (tester) async {
      await pumpHost(tester);
      expect(find.byKey(const ValueKey('achievement-unlock')), findsNothing);

      emit('achievement:unlocked', _payload(coins: 2500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byKey(const ValueKey('achievement-unlock')), findsOneWidget);
      expect(find.text(t('ach.title.first_merge')), findsOneWidget);
      expect(find.text(t('ach.desc.first_merge')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('achievement-unlock-reward')),
        findsOneWidget,
        reason: 'the coins it paid were never mentioned before',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('and it sits at the TOP of the screen', (tester) async {
      // Not the bottom, where a refused merge and a lapsed loan go.
      await pumpHost(tester);
      emit('achievement:unlocked', _payload());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final banner = tester.getRect(
        find.byKey(const ValueKey('achievement-unlock')),
      );
      expect(banner.top, lessThan(120));
      await tester.pumpAndSettle();
    });

    testWidgets('it slides in rather than appearing', (tester) async {
      await pumpHost(tester);
      emit('achievement:unlocked', _payload());
      await tester.pump();
      final arriving = tester.getRect(
        find.byKey(const ValueKey('achievement-unlock')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final landed = tester.getRect(
        find.byKey(const ValueKey('achievement-unlock')),
      );
      expect(arriving.top, lessThan(landed.top), reason: 'it came from above');
      await tester.pumpAndSettle();
    });

    testWidgets('a tap sends it early', (tester) async {
      await pumpHost(tester);
      emit('achievement:unlocked', _payload());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('achievement-unlock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('achievement-unlock')), findsNothing);
    });

    testWidgets('and it leaves on its own', (tester) async {
      await pumpHost(tester);
      emit('achievement:unlocked', _payload());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('achievement-unlock')), findsOneWidget);
      await tester.pump(achievementUnlockHold);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('achievement-unlock')), findsNothing);
    });

    testWidgets('two at once QUEUE, so each gets its own moment', (
      tester,
    ) async {
      // A match can unlock several. Stacking them would be four celebrations in
      // one place.
      await pumpHost(tester);
      emit('achievement:unlocked', _payload());
      emit('achievement:unlocked', _payload(id: 'first_win'));
      await tester.pump();
      expect(_host(tester).queued, 1);
      expect(find.text(t('ach.title.first_merge')), findsOneWidget);
      expect(find.text(t('ach.title.first_win')), findsNothing);

      // Not `pumpAndSettle`: the banner animates for the whole of its stay, so
      // settling would run the SECOND one out too and find nothing.
      await tester.pump(achievementUnlockHold);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(t('ach.title.first_win')), findsOneWidget);
      expect(_host(tester).queued, 0);
      await tester.pump(achievementUnlockHold);
      await tester.pumpAndSettle();
    });

    testWidgets('a repeat says how many times, but never once', (tester) async {
      await pumpHost(tester);
      emit('achievement:unlocked', _payload(reUnlock: true, count: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('achievement-unlock-count')),
        findsNothing,
        reason: '"×1" is noise',
      );
      await tester.pumpAndSettle();

      emit('achievement:unlocked', _payload(reUnlock: true, count: 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('×4'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('it stops listening when it goes', (tester) async {
      await pumpHost(tester);
      expect(busListenerCount('achievement:unlocked'), 1);
      await tester.pumpWidget(const SizedBox());
      expect(busListenerCount('achievement:unlocked'), 0);
    });
  });
}
