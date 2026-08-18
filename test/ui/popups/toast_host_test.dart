/// The layer that makes the engines audible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/toast_host.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Future<void> pumpToasts(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: const ToastHost(child: Scaffold(body: SizedBox.expand())),
    ),
  ),
);

void main() {
  tearDown(() {
    clearBus();
    resetLocale();
  });

  group('what it says', () {
    test('an achievement is worth saying', () {
      expect(toastFor('achievement:unlocked', null)?.text, t('ach.unlocked'));
    });

    test('a cup names its gems', () {
      final toast = toastFor('cup:won', {
        'cupId': 'c',
        'cupName': 'The Cup',
        'gems': 5,
      });
      expect(toast!.text, contains('5'));
      expect(toast.text, contains('The Cup'));
      expect(toast.good, isTrue);
    });

    test('only a SEASON quest is announced', () {
      // Match quests finish constantly; a toast each would bury the rest.
      expect(toastFor('quest:completed', {'scope': 'match'}), isNull);
      expect(
        toastFor('quest:completed', {'scope': 'season'})?.text,
        t('quests.season_done'),
      );
    });

    test('a sweep reports what it paid', () {
      final toast = toastFor('quests:swept', {'count': 3, 'coins': 1200});
      expect(toast, isNotNull);
      expect(toast!.text, contains('1,200'));
    });

    test('an expired loan names the player, or stays quiet', () {
      // The copy carries a {name}, and an unfilled placeholder renders as
      // literal "{name}" on screen.
      final named = toastFor('loan:expired', {
        'card': {'displayName': 'Bobby'},
      });
      expect(named!.text, contains('Bobby'));
      expect(named.text, isNot(contains('{name}')));
      expect(toastFor('loan:expired', {'card': <String, dynamic>{}}), isNull);
    });

    test('the noisy events stay silent', () {
      // coins:updated fires every tick.
      for (final event in ['coins:updated', 'card:placed', 'energy:updated']) {
        expect(toastFor(event, null), isNull, reason: event);
      }
    });
  });

  group('on screen', () {
    testWidgets('an engine event puts a line up', (tester) async {
      await pumpToasts(tester);
      expect(find.byKey(const ValueKey('toast')), findsNothing);

      emit('achievement:unlocked', {'id': 'a'});
      await tester.pump();
      expect(find.byKey(const ValueKey('toast')), findsOneWidget);
      expect(find.text(t('ach.unlocked')), findsOneWidget);

      // And it clears itself.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('toast')), findsNothing);
    });

    testWidgets('a second line replaces the first', (tester) async {
      await pumpToasts(tester);
      emit('achievement:unlocked', null);
      await tester.pump();
      emit('cup:won', {'cupName': 'The Cup', 'gems': 2});
      await tester.pump();
      expect(find.byKey(const ValueKey('toast')), findsOneWidget);
      expect(find.textContaining('The Cup'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a silent event puts nothing up', (tester) async {
      await pumpToasts(tester);
      emit('coins:updated', 100);
      await tester.pump();
      expect(find.byKey(const ValueKey('toast')), findsNothing);
    });

    testWidgets('it never swallows a tap', (tester) async {
      // A toast interrupts nothing: it is not the thing a player is answering.
      await pumpToasts(tester);
      emit('achievement:unlocked', null);
      await tester.pump();
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('toast')),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('it stops listening when it goes', (tester) async {
      await pumpToasts(tester);
      expect(busListenerCount('achievement:unlocked'), 1);
      await tester.pumpWidget(const SizedBox());
      expect(busListenerCount('achievement:unlocked'), 0);
    });
  });
}
