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
    test('A NEW ADVENTURE ANNOUNCES ITSELF', () {
      // `prestige.season_begin_toast` was translated ten times over with
      // nothing able to reach it, and from the outside a prestige is
      // indistinguishable from the save having been wiped: an empty grid, a
      // Sunday League badge and a coin balance that changed. This is the one
      // sentence that says otherwise.
      final toast = toastFor('prestige:complete', {
        'level': 1,
        'multiplier': 1.1,
        'season': 1,
      });
      expect(toast?.good, isTrue);
      expect(toast?.text, contains('1.1'));
      expect(toast?.text, isNot(contains('{mult}')));
      expect(toast?.text, isNot(contains('{season}')));
    });

    test('and a deep run does not print its floating point at the player', () {
      // `1.1 ^ 7` is 1.9487171000000004.
      final toast = toastFor('prestige:complete', {
        'level': 7,
        'multiplier': 1.9487171000000004,
        'season': 1,
      });
      expect(toast?.text, contains('1.95'));
      expect(toast?.text, isNot(contains('1.9487')));
    });

    test('a prestige event with no multiplier stays quiet', () {
      expect(toastFor('prestige:complete', {'level': 1}), isNull);
    });

    /// **Gems arrive from four faucets and none of them said so.**
    /// `gems:updated` carries a balance and nothing else, so no listener could
    /// tell a welcome gift from a purchase, and all three `gems.toast.*`
    /// strings sat translated in ten languages with nothing able to reach one.
    group('gems, and which of them are worth saying', () {
      test('THE WELCOME GIFT SAYS SO, with the number in it', () {
        final toast = toastFor('gems:granted', {
          'amount': 5,
          'reason': 'tutorial',
        });
        expect(toast?.good, isTrue);
        expect(toast?.text, contains('5'));
        expect(toast?.text, isNot(contains('{n}')));
      });

      test('a season milestone speaks, whichever kind it was', () {
        // Two faucets share the one string: winning the Champions League, and
        // the first time this player has ever reached one of the top three
        // divisions — which names the division in its reason, so the match has
        // to be on the prefix rather than the whole.
        for (final reason in [
          'chl_title',
          'division_first:elite_league',
          'division_first:champions_cup',
        ]) {
          final toast = toastFor('gems:granted', {
            'amount': 10,
            'reason': reason,
          });
          expect(toast?.text, t('gems.toast.season', {'n': 10}), reason: reason);
        }
      });

      test('and both halves of a prestige payout do', () {
        // A first-ever prestige pays twice — the repeatable grant and the
        // lifetime bonus — and both are gems arriving for the same reason.
        for (final reason in ['prestige', 'first_prestige']) {
          expect(
            toastFor('gems:granted', {'amount': 3, 'reason': reason})?.text,
            t('gems.toast.prestige', {'n': 3}),
          );
        }
      });

      test('AND SO DOES EVERY OTHER FAUCET, whatever handed them over', () {
        // A stated exception to this file's quiet-by-default rule. That rule
        // exists because `coins:updated` fires on every tick; gems are the
        // opposite case — premium currency, a handful of times in a whole run,
        // and a player handed some without being told has been given something
        // they do not know they have. Occasion decides the WORDS, never whether
        // there are any.
        for (final reason in [
          'iap',
          'daily_streak',
          'quest_division_capstone',
          'cup',
          'unknown',
          '',
        ]) {
          final toast = toastFor('gems:granted', {
            'amount': 40,
            'reason': reason,
          });
          expect(toast, isNotNull, reason: reason);
          expect(toast!.gem, isTrue, reason: reason);
          expect(toast.text, contains('40'), reason: reason);
          // The glyph and the number, which needs no key that does not exist —
          // `toast.cup_gems` already prints gems this way and a new string is
          // blocked on the spec repo.
          expect(toast.text, contains('💎'), reason: reason);
        }
      });

      test('and a gem line is marked as one, whichever words it used', () {
        // The mark is what makes it gold, hold longer and play a cue, so a
        // reason with copy of its own must not lose it.
        for (final reason in [
          'tutorial',
          'chl_title',
          'division_first:elite_league',
          'prestige',
          'first_prestige',
          'anything_else',
        ]) {
          expect(
            toastFor('gems:granted', {'amount': 2, 'reason': reason})?.gem,
            isTrue,
            reason: reason,
          );
        }
        // And nothing else in the layer is marked as one.
        expect(
          toastFor('prestige:complete', {
            'level': 1,
            'multiplier': 1.1,
            'season': 1,
          })?.gem,
          isFalse,
        );
      });

      test('and a grant of nothing is still not an announcement', () {
        // `addGems` floors and refuses anything under one, so an event that
        // carries no gems is a bug upstream rather than news.
        expect(
          toastFor('gems:granted', {'amount': 0, 'reason': 'tutorial'}),
          isNull,
        );
        expect(toastFor('gems:granted', {'reason': 'tutorial'}), isNull);
        expect(
          toastFor('gems:granted', {'amount': 'lots', 'reason': 'tutorial'}),
          isNull,
        );
      });

      test('THE LAYER IS ACTUALLY LISTENING FOR IT', () {
        // The line and the mark are worth nothing if the host never subscribes,
        // and `toastEvents` is a hand-maintained list — which is exactly the
        // kind of join that gets forgotten and fails silently.
        expect(toastEvents, contains('gems:granted'));
      });
    });

    test('an achievement is NOT said here', () {
      // It has its own banner — `achievement_unlock.dart`. A reward that
      // arrives in the same slot as a refused merge is not a reward.
      expect(toastFor('achievement:unlocked', {'id': 'first_merge'}), isNull);
      expect(toastEvents, isNot(contains('achievement:unlocked')));
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

    test('a short scout batch says what it managed', () {
      final toast = toastFor('scout:short', {'got': 2, 'want': 4});
      expect(toast!.text, t('grid.scouted_partial', {'got': 2, 'want': 4}));
      expect(toast.good, isFalse, reason: 'fewer than asked for');
    });

    test('an auto-sale reports the coins it made', () {
      final toast = toastFor('scout:auto_sold', {'sold': 2, 'coins': 1200});
      expect(toast!.text, contains('1,200'));
      expect(toast.good, isTrue);
    });

    test('a division ceiling is explained, not just refused', () {
      final toast = toastFor('merge:refused', {
        'reason': 'division_locked',
        'tier': 4,
      });
      expect(toast!.text, t('grid.tier_unlock_higher', {'tier': 4}));
      expect(toast.good, isFalse);
    });

    test('a sweep nobody can pay for quotes the price', () {
      final toast = toastFor('merge:refused', {
        'reason': 'insufficient_coins',
        'coins': 250,
      });
      expect(toast!.text, contains('250'));
    });

    test('a refusal with no reason it can explain stays quiet', () {
      expect(toastFor('merge:refused', {'reason': 'same_cell'}), isNull);
    });

    test('a club whose bid died says something, from the pool', () {
      final toast = toastFor('transfer:grudge', {'team': 'Real Somewhere'});
      expect(toast!.text, contains('Real Somewhere'));
      expect(
        toast.text,
        isNot(contains('|')),
        reason: 'one line, not all of them',
      );
    });

    test('a grudge with no club named stays quiet', () {
      expect(toastFor('transfer:grudge', {'team': ''}), isNull);
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

      emit('cup:won', {'cupName': 'The Cup', 'gems': 5});
      await tester.pump();
      expect(find.byKey(const ValueKey('toast')), findsOneWidget);
      expect(find.textContaining('The Cup'), findsOneWidget);

      // And it clears itself.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('toast')), findsNothing);
    });

    testWidgets('A GEM PAYOUT ARRIVES IN GOLD, AND STAYS LONGER', (
      tester,
    ) async {
      // `addGems` is the only thing that raises this, and it raises it for
      // every faucet — so this is the path from "the engine handed the player
      // gems" all the way to "the player was told".
      await pumpToasts(tester);
      emit('gems:granted', {'amount': 5, 'reason': 'tutorial'});
      await tester.pump();
      expect(find.byKey(const ValueKey('toast')), findsOneWidget);
      expect(find.textContaining('5'), findsOneWidget);

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('toast')),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.color, const Color(0xFFFFD700));
      expect(text.style?.fontWeight, FontWeight.w800);

      // An ordinary line is gone by three seconds; this one is not.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('toast')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('toast')), findsNothing);
    });

    testWidgets('and an ordinary line is not dressed as one', (tester) async {
      await pumpToasts(tester);
      emit('quests:swept', {'count': 2, 'coins': 100});
      await tester.pump();
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('toast')),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.color, isNot(const Color(0xFFFFD700)));
    });

    testWidgets('a second line replaces the first', (tester) async {
      await pumpToasts(tester);
      emit('quests:swept', {'count': 2, 'coins': 100});
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
      emit('cup:won', {'cupName': 'The Cup', 'gems': 2});
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
      expect(busListenerCount('cup:won'), 1);
      await tester.pumpWidget(const SizedBox());
      expect(busListenerCount('cup:won'), 0);
    });
  });

  group('THE CAPSTONE GEM ANNOUNCES ITSELF', () {
    // `quest:capstone` has been emitted by `awardDivisionCapstone` since the
    // quest engine was ported and NOTHING listened, so clearing a division's
    // whole season track paid a gem in silence — the one lifetime-capped reward
    // in the game landing with no more ceremony than a coin.
    // `quests.capstone_toast` shipped in ten languages with no caller.
    test('and it names the division and the gem', () {
      final toast = toastFor('quest:capstone', {
        'divisionId': 'sunday_league',
        'gems': 1,
      });
      expect(toast, isNotNull);
      expect(toast!.good, isTrue);
      expect(toast.text, contains('1'));
      expect(toast.text, isNot(contains('{')));
      expect(toast.text, isNot(contains('sunday_league')));
    });

    test('and a payload with no gems in it says nothing', () {
      expect(toastFor('quest:capstone', {'divisionId': 'sunday_league'}), isNull);
      expect(toastFor('quest:capstone', null), isNull);
    });
  });
}
