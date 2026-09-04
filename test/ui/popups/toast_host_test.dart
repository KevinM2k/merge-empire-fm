/// The layer that makes the engines audible.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/prestige_card.dart' show proLockedAnswer;
import 'package:merge_empire_fc/ui/popups/toast_host.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
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
  group('THE UI\'S OWN THREE CHANNELS ALL SPEAK', () {
    // **TWO OF THE THREE WERE SHOUTING INTO NOTHING.** `toast:info` was
    // handled and listed; `toast:success` and `toast:error` were emitted from
    // thirteen places and appeared in neither the switch nor [toastEvents], so
    // every purchase confirmation, every "not enough gems", every energy
    // refill, both sign-in outcomes and healing a player said nothing at all.
    // The same class of bug this file's header was written about, one layer up.
    test('success is a good line', () {
      final toast = toastFor('toast:success', 'bought it');
      expect(toast, isNotNull);
      expect(toast!.text, 'bought it');
      expect(toast.good, isTrue);
      expect(toast.gem, isFalse);
    });

    test('error is not', () {
      final toast = toastFor('toast:error', 'not enough gems');
      expect(toast, isNotNull);
      expect(toast!.text, 'not enough gems');
      expect(toast.good, isFalse);
    });

    test('and an empty line still says nothing', () {
      expect(toastFor('toast:success', ''), isNull);
      expect(toastFor('toast:error', ''), isNull);
    });

    test('all three are subscribed, or the host never hears them', () {
      // The switch answering is only half of it — `toastEvents` is what the
      // host actually listens to, and that is where these two were missing.
      expect(
        toastEvents,
        containsAll(<String>['toast:info', 'toast:success', 'toast:error']),
      );
    });

    testWidgets('a purchase confirmation reaches the screen', (tester) async {
      await pumpToasts(tester);
      emit('toast:success', 'bought it');
      await tester.pump();
      expect(find.byKey(const ValueKey('toast')), findsOneWidget);
      expect(find.text('bought it'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('IT KEEPS OUT OF THE KEYBOARD\'S WAY', () {
    // A full-bleed band centred on the whole screen landed across the bottom
    // half of the visible strip whenever a keyboard was up — reported from the
    // couch after prestige, where the gem line opened over the box the new
    // club's name was about to be typed into. Centred still, in the space the
    // keyboard leaves.
    testWidgets('with no keyboard it is dead centre', (tester) async {
      await pumpToasts(tester);
      // The very line that was reported: the new adventure's own toast, up
      // while the club-name card is asking for a name.
      emit('prestige:complete', {'level': 1, 'multiplier': 1.1, 'season': 1});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final band = tester.getRect(find.byKey(const ValueKey('toast')));
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(band.center.dy, closeTo(screen.center.dy, 1));
    });

    testWidgets('and with one up it sits clear of it', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.resetViewInsets);
      await pumpToasts(tester);
      // The very line that was reported: the new adventure's own toast, up
      // while the club-name card is asking for a name.
      emit('prestige:complete', {'level': 1, 'multiplier': 1.1, 'season': 1});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final band = tester.getRect(find.byKey(const ValueKey('toast')));
      final screen = tester.getRect(find.byType(MaterialApp));
      final keyboardTop =
          screen.bottom - 600 / tester.view.devicePixelRatio;
      expect(
        band.bottom,
        lessThanOrEqualTo(keyboardTop + 1),
        reason: 'the band is over the keyboard',
      );
    });
  });


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

    test('AND A LOCKED PRO SAYS WHAT WOULD OPEN IT', () {
      // This used to be `prestige.body_pro_hint` alone — a fragment of the
      // prestige card's offer, which describes Pro and never says how it opens.
      // The condition leads it now, in the game's own shipped words.
      //
      // **AND THE CONDITION IS THE CHAMPIONS LEAGUE, not prestige.** Nobody
      // knows what prestige is: it was the gate AND the whole of the
      // explanation, so the padlock was answered with a second unknown word.
      // The hint that follows is `settings.difficulty.hint` for the same
      // reason — `prestige.body_pro_hint` opens with "Or prestige into Pro
      // Mode", which is no longer the route.
      //
      // And it ASKS for the league rather than reporting it won: the caption
      // `champ.subtitle` is written for the moment after — see
      // [proLockedAnswer].
      final toast = toastFor('prestige:locked', null)!;
      expect(toast.text, startsWith(proLockedAnswer()));
      expect(toast.text, contains(t('division.champions_cup')));
      expect(toast.text, isNot(contains(t('champ.subtitle'))));
      expect(toast.text, isNot(contains(t('ach.desc.prestige_level_1'))));
      expect(toast.text, contains(t('settings.difficulty.hint')));
      expect(toast.good, isFalse);
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

      // And it clears itself — after the slide out, which is why this settles
      // rather than jumping the clock: a toast that simply stopped being there
      // was the fault being fixed.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
    });

    /// **IT WAS A HAIRLINE ROUND NOTHING** — reported as "just a clear box
    /// with a red border". `kit.surface` is the value the page behind it is
    /// built from, so the box had no edge of its own, and the ink was the kit's
    /// accent whatever had happened: a refusal was a GREEN sentence inside a
    /// red outline.
    testWidgets('A LINE IS A PLATE, and it is the tone all the way through', (
      tester,
    ) async {
      await pumpToasts(tester);
      emit('merge:refused', {'reason': 'division_locked', 'tier': 3});
      await tester.pump();

      final box = tester
          .widget<Container>(find.byKey(const ValueKey('toast')))
          .decoration as BoxDecoration;
      final kit = buildAppTheme(
        kitId: '#4caf50',
        light: false,
      ).extension<KitTheme>()!;

      // Opaque, and not the page's own ground.
      expect(box.color!.a, 1);
      expect(box.color, isNot(kit.surface));
      // Something under it, so it reads as being on top of the screen.
      expect(box.boxShadow, isNotNull);
      expect(box.boxShadow!, isNotEmpty);

      // And the sentence wears the same colour the band's edges do. Edges, not
      // an outline: it runs off both sides of the screen, so the two it has are
      // top and bottom and the sides are deliberately absent.
      expect(box.border, isA<Border>());
      final border = box.border! as Border;
      final edge = border.top.color;
      expect(edge, dangerInk);
      expect(border.bottom.color, dangerInk);
      expect(border.left, BorderSide.none);
      expect(border.right, BorderSide.none);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('toast')),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.color, dangerInk);
      expect(
        text.style?.color,
        isNot(kit.accentBright),
        reason: 'a refusal was printed in the kit accent',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    /// **A BAND ACROSS THE MIDDLE, not a card near the foot.** It sat 96pt off
    /// the bottom with a 16pt margin either side — the corner of the screen
    /// nobody is looking at, under the tab bar's own furniture. Reported from
    /// the couch: the line kept being missed.
    testWidgets('IT RUNS EDGE TO EDGE, ACROSS THE MIDDLE', (tester) async {
      await pumpToasts(tester);
      emit('quests:swept', {'count': 2, 'coins': 100});
      await tester.pumpAndSettle();

      final screen = tester.getSize(find.byType(MaterialApp));
      final band = tester.getRect(find.byKey(const ValueKey('toast')));
      expect(band.left, 0);
      expect(band.right, screen.width);
      // Centred on the screen, not parked at the foot of it.
      expect(band.center.dy, closeTo(screen.height / 2, 1));
      // A little air above and below the sentence, and no more.
      expect(band.height, lessThan(screen.height * 0.25));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    /// **A toast MOVES.** It used to be there and then not be there, which
    /// reads as a rendering fault rather than as a notification. It strikes in
    /// from the left and closes back the same way.
    testWidgets('IT STRIKES IN FROM THE LEFT AND CLOSES BACK', (tester) async {
      await pumpToasts(tester);
      final host = tester.state<ToastHostState>(find.byType(ToastHost));
      emit('quests:swept', {'count': 2, 'coins': 100});
      await tester.pump();

      // Mid-strike: on screen, and only part of the way across.
      await tester.pump(const Duration(milliseconds: 90));
      expect(host.sweep, greaterThan(0));
      expect(host.sweep, lessThan(1));
      expect(find.byKey(const ValueKey('toast')), findsOneWidget);

      // All the way over.
      await tester.pumpAndSettle();
      expect(host.sweep, 1);

      // And it closes back the same way rather than being switched off.
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump(const Duration(milliseconds: 120));
      expect(host.sweep, lessThan(1));
      expect(host.sweep, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('toast')), findsNothing);
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

  testWidgets('AND A FULL-SCREEN ROUTE DOES NOT FREEZE THE STRIKE', (
    tester,
  ) async {
    // **The band goes up in the ROOT overlay and the HOST is under every route
    // in the game**, so a Navigator mutes its `TickerMode` and a toast fired
    // from inside a mini-game, a shop sheet or the settings screen never slid
    // in: it sat off-screen at the start of its own animation until the route
    // was popped, and then arrived, about something the player had finished
    // doing. Same fault as the frozen coin sprite, found looking for it.
    //
    // `TickerMode(enabled: true)` is NOT the fix — it composes with its
    // ancestors — so the host provides its own ticker. See `createTicker`.
    await pumpToasts(tester);
    final host = tester.state<ToastHostState>(find.byType(ToastHost));
    final navigator = Navigator.of(tester.element(find.byType(ToastHost)));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('a whole screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('a whole screen'), findsOneWidget);

    emit('quests:swept', {'count': 2, 'coins': 100});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      host.sweep,
      greaterThan(0),
      reason: 'the strike is frozen under the route',
    );
    await tester.pumpAndSettle();
    expect(host.sweep, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
