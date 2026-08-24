/// The turn-over a signing lands with.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/add_player_button.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/screens/grid/scout_reveal.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// A save with money and an empty grid — the state Add Player is for.
/// **The tutorial is FINISHED by default here**, because the batch control is
/// its reward: while the script is running a scout signs exactly one card
/// however big a batch the save has stored. Everything in this file that is
/// about batches is therefore about a save past the tutorial; the lock itself
/// has its own test below.
Map<String, dynamic> _save({
  int coins = 100000,
  bool autoSell = false,
  bool tutorialDone = true,
}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  (s['tutorial'] as Map<String, dynamic>)['done'] = tutorialDone;
  if (autoSell) {
    // BOTH tiers Sunday League can draw. Marking only tier one left the test
    // flaky about one run in seven — a tier-two draw is a 15% slice of that
    // pool, and an unmarked card is a reveal with nothing to cash in.
    (s['settings'] as Map<String, dynamic>)['autoTierActions'] =
        <String, dynamic>{'1': TierAction.sell, '2': TierAction.sell};
  }
  return s;
}

int _coins(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

int _filled(Map<String, dynamic>? s) =>
    gridCells(s).where((c) => c != null).length;

/// The reveal for a real batch, drawn off a real save.
({ScoutReveal? reveal, List<Signing> placed}) _revealFor(
  Map<String, dynamic> save,
  int n,
) {
  final batch = signPlayers(save, n);
  return (reveal: scoutRevealFor(save, batch.placed), placed: batch.placed);
}

Future<void> pumpReveal(
  WidgetTester tester,
  ScoutReveal reveal, {
  VoidCallback? onDone,
  bool reduceMotion = false,
  ScoutLanding? landing,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        body: ScoutRevealOverlay(
          reveal: reveal,
          onDone: onDone ?? () {},
          landing: landing,
        ),
      ),
    ),
  ),
);

/// The Players tab's button, on a live save.
Future<ProviderContainer> pumpButton(
  WidgetTester tester,
  Map<String, dynamic> save,
) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: Center(child: AddPlayerButton())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

bool _buttonDead(WidgetTester tester) =>
    tester.widget<InkWell>(find.byKey(const ValueKey('add-player'))).onTap ==
    null;

/// Past the point where the flip has landed, with a frame to spare.
final Duration _flipped =
    scoutRevealSkipAfter + const Duration(milliseconds: 100);

/// Run a reveal of [cards] out to its end.
///
/// `pumpAndSettle` is not enough on its own: it stops as soon as no frame is
/// scheduled, which is the gap between the flip finishing and the hold timer
/// firing — so the reveal would still be up, with a pending timer, when the
/// test ended.
Future<void> finishReveal(WidgetTester tester, int cards) async {
  // One frame first, so the overlay is actually mounted: its hold does not start
  // counting until it is, and a single long pump would insert it at the very end
  // of the window it was meant to run inside.
  await tester.pump();
  await tester.pump(scoutRevealHold(cards) + const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  // And the debounced write the settle scheduled, which would otherwise be a
  // timer still pending when the tree comes down.
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

void main() {
  tearDown(() {
    clearBus();
    resetLocale();
  });

  group('what the reveal says', () {
    test('nothing at all for a batch that delivered nothing', () {
      expect(scoutRevealFor(_save(), const []), isNull);
    });

    test('a plain single signing gets the tier line', () {
      // Sunday League only draws tier ones, so the modest line is the right one.
      final result = _revealFor(_save(), 1);
      expect(result.reveal!.cards.length, 1);
      expect(result.reveal!.caption, contains(t('merge.signing.new')));
      expect(result.reveal!.cards.first.badge, isNull);
    });

    test('a batch is captioned by its size, not by any one card', () {
      final result = _revealFor(_save(), 4);
      expect(result.reveal!.cards.length, 4);
      expect(result.reveal!.caption, t('grid.scouted_batch', {'n': 4}));
    });

    test('a voucher card wears a pill, and the line stays free', () {
      final save = _save();
      (save['shop'] as Map<String, dynamic>)['freeScoutReady'] = true;
      final result = _revealFor(save, 1);
      expect(result.reveal!.cards.first.badge, t('grid.voucher_badge'));
      expect(result.reveal!.caption, isNot(t('grid.voucher_badge')));
    });

    test('a voucher card that is ALSO a first sighting says both', () {
      // Two captions in two places, so neither has to give way to the other:
      // the pill on the card, "New Player Found" on the line below it.
      final save = _save();
      final drawn = signPlayers(save, 1).placed.single;
      final reveal = scoutRevealFor(save, [
        (
          ok: true,
          reason: null,
          idx: drawn.idx,
          cost: 0,
          wasFree: true,
          isNewDiscovery: true,
          autoSell: false,
          sellCoins: 0,
          voucherFloor: null,
          voucherRandom: true,
        ),
      ])!;
      expect(reveal.cards.single.badge, t('grid.voucher_badge'));
      expect(reveal.cards.single.isNewDiscovery, isTrue);
      expect(reveal.caption, t('grid.new_player_found'));
    });

    test('an auto-sold single card takes the LINE, not a pill', () {
      // A verdict on the card, not a label for it — and it is about to come
      // apart anyway.
      final save = _save(autoSell: true);
      signPlayers(save, 1); // never the last card standing
      final result = _revealFor(save, 1);
      expect(result.placed.single.autoSell, isTrue);
      expect(result.reveal!.cards.single.badge, isNull);
      expect(result.reveal!.cards.single.vanish, isTrue);
      expect(result.reveal!.caption, contains('+'));
    });

    test('an auto-sold card in a BATCH wears the pill instead', () {
      final save = _save(autoSell: true);
      final result = _revealFor(save, 4);
      final marked = result.reveal!.cards.where((c) => c.vanish);
      expect(marked, isNotEmpty);
      expect(marked.first.badge, isNotNull);
      expect(result.reveal!.caption, t('grid.scouted_batch', {'n': 4}));
    });
  });

  group('the overlay', () {
    testWidgets('holds the card face down before it flips', (tester) async {
      final reveal = _revealFor(_save(), 1).reveal!;
      await pumpReveal(tester, reveal);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PlayerCard), findsNothing);

      await tester.pump(_flipped);
      expect(find.byType(PlayerCard), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('says its line', (tester) async {
      final reveal = _revealFor(_save(), 1).reveal!;
      await pumpReveal(tester, reveal);
      await tester.pump(_flipped);
      expect(
        find.byKey(const ValueKey('scout-reveal-caption')),
        findsOneWidget,
      );
      expect(find.text(reveal.caption), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('turns a whole batch over together', (tester) async {
      final reveal = _revealFor(_save(), 4).reveal!;
      await pumpReveal(tester, reveal);
      await tester.pump(_flipped);
      expect(find.byType(PlayerCard), findsNWidgets(4));
      await tester.pumpAndSettle();
    });

    testWidgets('a tap before the flip lands is ignored', (tester) async {
      // Skipping earlier would whisk the card away before the player has seen
      // who they got, which is the one thing the reveal is for.
      var done = false;
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        onDone: () => done = true,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final state = tester.state<ScoutRevealOverlayState>(
        find.byType(ScoutRevealOverlay),
      );
      expect(state.canSkip, isFalse);
      await tester.tap(find.byKey(const ValueKey('scout-reveal')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('a tap after it lands dismisses early', (tester) async {
      var done = false;
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        onDone: () => done = true,
      );
      await tester.pump(_flipped);
      expect(
        tester
            .state<ScoutRevealOverlayState>(find.byType(ScoutRevealOverlay))
            .canSkip,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('scout-reveal')));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('dismisses itself when nobody taps', (tester) async {
      var done = false;
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        onDone: () => done = true,
      );
      await tester.pump(scoutRevealHold(1));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('a batch is held longer than one card', (tester) async {
      expect(
        scoutRevealHold(4),
        greaterThan(scoutRevealHold(1)),
        reason: 'there is more to take in',
      );
    });

    testWidgets('a cashed-in card comes apart rather than settling', (
      tester,
    ) async {
      final save = _save(autoSell: true);
      signPlayers(save, 1);
      final reveal = _revealFor(save, 1).reveal!;
      expect(reveal.cards.single.vanish, isTrue);

      await pumpReveal(tester, reveal);
      await tester.pump(_flipped);
      expect(find.byType(MergeBurst), findsNothing, reason: 'not yet');

      await tester.tap(find.byKey(const ValueKey('scout-reveal')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(MergeBurst), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a first sighting is haloed', (tester) async {
      final reveal = (
        cards: [
          (
            view: (
              name: 'A Kid',
              tier: 1,
              rating: 40,
              position: 'GK',
              injured: false,
              onLoan: false,
              variant: 0,
              fitness: null,
              incomePerSec: null,
              maxed: false,
              atCap: false,
              trait: null,
            ),
            badge: null,
            isNewDiscovery: true,
            vanish: false,
            idx: 0,
          ),
        ],
        caption: t('grid.new_player_found'),
      );
      await pumpReveal(tester, reveal);
      await tester.pump(_flipped);
      expect(
        find.byKey(const ValueKey('scout-reveal-discovery')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('reduce-motion keeps the reveal and drops the movement', (
      tester,
    ) async {
      // The reveal is information, not decoration: what goes is the movement.
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        reduceMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byType(PlayerCard),
        findsOneWidget,
        reason: 'face up at once',
      );
      await tester.pumpAndSettle();
    });
  });

  group('the way home', () {
    /// The square a card is flying to, and a record of what was asked for.
    ({ScoutLanding landing, List<List<int>> asked}) fakeLanding([
      Rect rect = const Rect.fromLTWH(24, 560, 96, 128),
    ]) {
      final asked = <List<int>>[];
      return (
        landing: (idxs) async {
          asked.add(idxs);
          return [for (final _ in idxs) rect];
        },
        asked: asked,
      );
    }

    testWidgets('the reveal says which cell each card landed in', (
      tester,
    ) async {
      final save = _save();
      final batch = signPlayers(save, 2);
      final reveal = scoutRevealFor(save, batch.placed)!;
      expect(
        [for (final c in reveal.cards) c.idx],
        [for (final s in batch.placed) s.idx],
        reason: 'the flight has nowhere to go without it',
      );
    });

    testWidgets(
      'the squares are asked for DURING the hold, not on the way out',
      (tester) async {
        final fake = fakeLanding();
        await pumpReveal(
          tester,
          _revealFor(_save(), 1).reveal!,
          landing: fake.landing,
        );
        // One frame in — long before the hold is up — the grid has been asked.
        await tester.pump();
        expect(fake.asked, [
          [0],
        ]);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('and asked ONCE, for the whole batch', (tester) async {
      final fake = fakeLanding();
      final reveal = _revealFor(_save(), 3).reveal!;
      await pumpReveal(tester, reveal, landing: fake.landing);
      await tester.pump();
      expect(fake.asked.length, 1, reason: 'one ask, one scroll');
      expect(fake.asked.first.length, reveal.cards.length);
      await tester.pumpAndSettle();
    });

    testWidgets('a card is not asked to fly to a square it is giving up', (
      tester,
    ) async {
      final fake = fakeLanding();
      final save = _save(autoSell: true);
      signPlayers(save, 1);
      final reveal = _revealFor(save, 1).reveal!;
      expect(reveal.cards.single.vanish, isTrue);
      await pumpReveal(tester, reveal, landing: fake.landing);
      await tester.pump();
      expect(fake.asked, isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('the card flies from the reveal into its square', (
      tester,
    ) async {
      const target = Rect.fromLTWH(24, 560, 96, 128);
      final fake = fakeLanding(target);
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        landing: fake.landing,
      );
      await tester.pump();
      await tester.pump(scoutRevealHold(1));
      await tester.pump();

      final flight = find.byKey(const ValueKey('scout-reveal-flight'));
      expect(flight, findsOneWidget, reason: 'it left');
      final started = tester.getRect(flight);
      expect(
        started.width,
        greaterThan(target.width),
        reason: 'it starts at reveal size',
      );

      await tester.pump(scoutRevealFlyHome ~/ 2);
      final halfway = tester.getRect(flight);
      expect(
        (halfway.center - target.center).distance,
        lessThan((started.center - target.center).distance),
      );

      await tester.pump(scoutRevealFlyHome);
      // Landed ON the square, not near it: the real card is already underneath.
      final landed = tester.getRect(flight);
      expect(landed.left, moreOrLessEquals(target.left, epsilon: 0.5));
      expect(landed.top, moreOrLessEquals(target.top, epsilon: 0.5));
      expect(landed.width, moreOrLessEquals(target.width, epsilon: 0.5));
      expect(landed.height, moreOrLessEquals(target.height, epsilon: 0.5));
      await tester.pumpAndSettle();
    });

    testWidgets('the reveal is not over until the card is home', (
      tester,
    ) async {
      final fake = fakeLanding();
      var done = false;
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        landing: fake.landing,
        onDone: () => done = true,
      );
      await tester.pump();
      await tester.pump(scoutRevealHold(1));
      await tester.pump(scoutRevealFlyHome - const Duration(milliseconds: 40));
      expect(done, isFalse, reason: 'still in the air');
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('reduce-motion lands it without the journey', (tester) async {
      final fake = fakeLanding();
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        landing: fake.landing,
        reduceMotion: true,
      );
      await tester.pump();
      await tester.pump(scoutRevealHold(1));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('scout-reveal-flight')),
        findsNothing,
        reason: 'the square is on screen either way',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('with no grid to fly into, the card settles as it always did', (
      tester,
    ) async {
      var done = false;
      await pumpReveal(
        tester,
        _revealFor(_save(), 1).reveal!,
        onDone: () => done = true,
      );
      await tester.pump(scoutRevealHold(1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scout-reveal-flight')), findsNothing);
      expect(done, isTrue);
    });
  });

  group('the button, end to end', () {
    testWidgets('a tap signs, reveals, and only then settles', (tester) async {
      final container = await pumpButton(tester, _save(autoSell: true));
      final game = container.read(gameProvider);
      // One card already there, so the next is not the last one standing.
      game.update((s) => signPlayers(s, 1));
      await tester.pumpAndSettle();

      final before = _filled(game.state);
      final coinsBefore = _coins(game.state!);
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await tester.pump();

      // Mid-reveal: the card is in the grid and nothing has been cashed in.
      expect(_filled(game.state), before + 1);
      expect(_buttonDead(tester), isTrue, reason: 'no double-tapping a reveal');
      final coinsMidReveal = _coins(game.state!);

      await finishReveal(tester, 1);
      expect(_filled(game.state), before, reason: 'the marked card went');
      expect(
        _coins(game.state!),
        greaterThan(coinsMidReveal),
        reason: 'paid on the way out, not on the way in',
      );
      expect(_coins(game.state!), lessThan(coinsBefore));
      expect(_buttonDead(tester), isFalse);
    });

    testWidgets('a plain signing leaves the card in the grid', (tester) async {
      final container = await pumpButton(tester, _save());
      final game = container.read(gameProvider);
      final before = _filled(game.state);
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await finishReveal(tester, 1);
      expect(_filled(game.state), before + 1);
    });

    testWidgets('the batch it asks for is one it can deliver', (tester) async {
      // Which is why the short-batch line is a backstop rather than something
      // this button can produce: it clamps the ask to what the save can pay for
      // and house, so the engine's guard only fires for a path that does not.
      final save = _save();
      (save['settings'] as Map<String, dynamic>)['scoutBatch'] = 4;
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('scout:short', listener);
      addTearDown(() => off('scout:short', listener));

      final container = await pumpButton(tester, save);
      final before = _filled(container.read(gameProvider).state);
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await finishReveal(tester, 4);

      expect(_filled(container.read(gameProvider).state), before + 4);
      expect(heard, isEmpty);
    });
  });

  group('how a star arrives', () {
    // The whole point of scouting is the moment a good one turns over, and the
    // standard pacing is tuned for the bronze card that arrives nine times out
    // of ten: long enough to read, not long enough to enjoy.
    test('the bands are the CAPTION\'s own thresholds', () {
      // Three answers to "how good is this" that disagreed would be worse than
      // one that is only roughly right — the line, the glow and the arrival
      // all break at 5 and 7.
      expect(RevealTier.of(1), RevealTier.plain);
      expect(RevealTier.of(4), RevealTier.plain);
      expect(RevealTier.of(5), RevealTier.star);
      expect(RevealTier.of(6), RevealTier.star);
      expect(RevealTier.of(7), RevealTier.legend);
      expect(RevealTier.of(9), RevealTier.legend);
    });

    test('a better card falls further and lands slower', () {
      expect(RevealTier.plain.drop, 0);
      expect(RevealTier.star.drop, greaterThan(RevealTier.plain.drop));
      expect(RevealTier.legend.drop, greaterThan(RevealTier.star.drop));
      expect(
        RevealTier.legend.entrance,
        greaterThan(RevealTier.star.entrance),
      );
      expect(RevealTier.star.entrance, greaterThan(RevealTier.plain.entrance));
    });

    test('and only a star or better catches the light', () {
      expect(RevealTier.plain.shines, isFalse);
      expect(RevealTier.star.shines, isTrue);
      expect(RevealTier.legend.shines, isTrue);
    });

    test('THE HOLD GROWS WITH THE BEST CARD IN THE BATCH', () {
      // One legend among four makes it a legend's reveal.
      final plain = scoutRevealHold(1);
      expect(scoutRevealHold(1, topTier: 5), greaterThan(plain));
      expect(
        scoutRevealHold(1, topTier: 7),
        greaterThan(scoutRevealHold(1, topTier: 5)),
      );
      // And the default is unchanged, so nothing that does not ask is affected.
      expect(scoutRevealHold(1, topTier: 1), plain);
    });
  });
}
