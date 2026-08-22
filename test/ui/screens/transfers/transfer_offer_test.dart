/// A rival's bid, and the two triggers that produce one.
///
/// Both triggers were dead. `maybeGenerateOffer` — the post-match roll — had no
/// caller anywhere in the port, and `transfer:offered` — the idle roll — was
/// emitted by the tick with nothing listening. The second is the worse of the
/// two: an unanswered offer times out after five minutes and the timeout is
/// scored as a DECLINE, which hands the buying club a grudge. Players were
/// being punished for bids they were never shown.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

const String _defId = 'player_t3_fwd';
const String _instanceId = 'c0';
const String _rival = 'Ayton Rovers';

/// A save holding one player and one bid for them.
/// A container over a given save, for the tests that only need to read it.
ProviderContainer shopStyleContainer(Map<String, dynamic> state) {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  return container;
}

Map<String, dynamic> _saveWithOffer({
  int price = 5000,
  int seasonsPlayed = 0,
  bool injured = false,
  int coins = 0,
}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  cells[0] = <String, dynamic>{
    'definitionId': _defId,
    'instanceId': _instanceId,
    'variant': 0,
    'seasonsPlayed': seasonsPlayed,
    'injured': injured,
  };
  final def = players.firstWhere((p) => p.id == _defId);
  s['transferMarket'] = <String, dynamic>{
    'pendingOffer': <String, dynamic>{
      'offerId': 'offer_1',
      'fromTeam': _rival,
      'cardInstanceId': _instanceId,
      'definitionId': _defId,
      'playerName': 'Test Player',
      'tier': def.tier,
      'tierName': def.tierName,
      'sellValue': def.sellValue,
      'marketBasePrice': def.sellValue,
      'price': price,
      'variant': 0,
      // NOW, not epoch: the boot migration clears any offer older than five
      // minutes, so a fixture stamped 1 is gone before the screen sees it.
      'createdAt': now(),
    },
    'grudges': <String, dynamic>{},
    'lastOfferAt': now(),
  };
  return s;
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
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
          home: Scaffold(
            body: Builder(
              builder: (inner) => ElevatedButton(
                key: const ValueKey('open'),
                onPressed: () => showTransferOffer(inner, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  // **Opening the card WRITES to the save now**: the first bid a save ever gets
  // carries Colin's one-time explanation of what one is, and spending that id is
  // a change like any other. Flush the debounce so the test does not end holding
  // its timer.
  await _settleSave(tester);
  return container;
}

/// The pill lives in the shell, so the test gives it one: the widget under a
/// Navigator, with the save it reads.
///
/// **UNDER REDUCED MOTION, and that is not incidental.** The pill breathes on a
/// repeating controller so a parked bid keeps announcing itself, which means
/// `pumpAndSettle` never returns while one is up — the same trap the dugout cam
/// set for `pumpMatch`. The policy stops the clock and leaves the pill at full
/// strength, so a test that is about the pill still sees the pill.
Future<ProviderContainer> _pumpShell(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
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
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: TransferPill(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

KitTheme _kitOf(WidgetTester tester) => Theme.of(
  tester.element(find.byKey(const ValueKey('transfer-pill'))),
).extension<KitTheme>()!;

/// The pill's halo, which is what the pulse moves — a glow rather than a scale,
/// because a pill that grows shoves the tab bar under it.
BoxShadow _haloOf(WidgetTester tester) => ((tester
            .widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('transfer-pill')),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration)
    .boxShadow!
    .first);

Future<void> _settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

Map<String, dynamic> _market(ProviderContainer c) =>
    c.read(gameProvider).state!['transferMarket'] as Map<String, dynamic>;

List<dynamic> _cells(ProviderContainer c) =>
    (c.read(gameProvider).state!['grid'] as Map<String, dynamic>)['cells']
        as List<dynamic>;

void main() {
  tearDown(() {
    resetBus();
    resetPopupQueue();
    resetLocale();
  });

  group('the card', () {
    testWidgets('names the club, the player and the price', (tester) async {
      await _pump(tester, _saveWithOffer());
      expect(find.byKey(const ValueKey('transfer-offer')), findsOneWidget);
      expect(
        find.text(t('transfer.card_title', {'club': _rival})),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('transfer-pitch')), findsOneWidget);
    });

    testWidgets('AND IT SAYS NEITHER THE PERCENTAGE NOR THE GRUDGE', (
      tester,
    ) async {
      // **Both were deliberately removed and this is the test that stops them
      // coming back.** "367% over fair market value" is a figure nobody can act
      // on — the price is the price — and making it legible, which is what the
      // pass that built the band chip did, does not make it useful. The CHIP
      // stays: "JACKPOT" is a judgement, which is what the player wanted off
      // that line. The grudge warning went for the same reason: Colin's read
      // says what to do, and a second sentence warning about the answer he did
      // not recommend is the card arguing with itself.
      //
      // The consequence is deliberate and `docs/REMAINING.md` records it —
      // three keys go back to being shipped copy with no caller, which
      // anywhere else in this port is a bug.
      await _pump(tester, _saveWithOffer());
      expect(find.byKey(const ValueKey('transfer-premium')), findsNothing);
      expect(
        find.text(t('transfer.decline_warning', {'club': _rival})),
        findsNothing,
      );
      // What survives: the band, and Colin.
      expect(find.byKey(const ValueKey('transfer-advice')), findsOneWidget);
    });
  });

  group('THE PILL IS THE LOUDEST THING IN THE SHELL NOW', () {
    testWidgets('it is FILLED in the accent, not outlined on the surface', (
      tester,
    ) async {
      // A `surface`-filled stadium with a 55% accent hairline is the quietest
      // thing the palette can draw, above a tab bar the eye already skips — so
      // the one control between a player and an offer they parked read as
      // chrome.
      final c = await _pumpShell(tester, _saveWithOffer());
      final kit = _kitOf(tester);
      final pill = tester.widget<Material>(
        find.byKey(const ValueKey('transfer-pill')),
      );
      expect(pill.color, kit.accentBright);
      expect(
        tester
            .widget<Text>(find.text(t('transfer.pill_label')))
            .style
            ?.color,
        kit.accentBrightInk,
      );
      c.dispose;
    });

    testWidgets('and it BREATHES, unless the device says not to', (
      tester,
    ) async {
      // Same 1.8s period as Colin's unread pulse, because it is the same
      // signal. Reduced motion stops the clock and leaves it at full strength
      // rather than mid-fade — `_pumpShell` runs under that policy, which is
      // also what keeps `pumpAndSettle` from hanging on it.
      await _pumpShell(tester, _saveWithOffer());
      final still = _haloOf(tester);
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        _haloOf(tester),
        still,
        reason: 'reduced motion has to hold it still',
      );
      expect(still.blurRadius, greaterThan(0));
    });
  });

  group('answering', () {
    testWidgets('accepting sells the player and pays', (tester) async {
      final container = await _pump(tester, _saveWithOffer(price: 5000));
      final coinsBefore = container.read(coinsProvider);

      await tester.tap(
        find.byKey(const ValueKey('coach-action-transfer.accept_amount')),
      );
      await tester.pumpAndSettle();
      await _settleSave(tester);

      expect(container.read(coinsProvider), greaterThan(coinsBefore));
      expect(_market(container)['pendingOffer'], isNull);
      // The card has left the grid — that is what was sold.
      expect(_cells(container).where((c) => c != null).length, 0);
    });

    testWidgets('declining keeps the player and earns a grudge', (
      tester,
    ) async {
      final container = await _pump(tester, _saveWithOffer());

      await tester.tap(
        find.byKey(const ValueKey('coach-action-common.decline')),
      );
      await tester.pumpAndSettle();
      await _settleSave(tester);

      expect(_market(container)['pendingOffer'], isNull);
      expect(
        (_market(container)['grudges'] as Map<String, dynamic>)[_rival],
        isNotNull,
      );
      expect(_cells(container).where((c) => c != null).length, 1);
    });

    testWidgets('parking answers nothing and keeps the bid alive', (
      tester,
    ) async {
      // The one dismissal that is NOT a decline: nothing is discarded, so the
      // squad can be looked over before answering.
      final container = await _pump(tester, _saveWithOffer());

      await tester.tap(
        find.byKey(const ValueKey('coach-action-transfer.minimize')),
      );
      await tester.pumpAndSettle();
      await _settleSave(tester);

      expect(_market(container)['pendingOffer'], isNotNull);
      expect((_market(container)['grudges'] as Map<String, dynamic>), isEmpty);
    });
  });

  group('THE MONEY IS NOT A SENTENCE', () {
    testWidgets('the fee wears a coin and the premium wears its band', (
      tester,
    ) async {
      // Every fact used to be one paragraph in the same 13px grey, so the
      // number the whole card is about had to be found by reading.
      final sellValue = players.firstWhere((p) => p.id == _defId).sellValue;
      await _pump(tester, _saveWithOffer(price: (sellValue * 2.2).round()));
      expect(find.byKey(const ValueKey('transfer-price')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('transfer-price')),
          matching: find.byType(CoinIcon),
        ),
        findsOneWidget,
      );
      // 120% over fair value is a great deal, not a jackpot.
      expect(
        find.byKey(const ValueKey('transfer-band-transfer.market.great')),
        findsOneWidget,
      );
      // The band's own colour is what carries the reading now that the
      // percentage under it has gone.
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('transfer-band-transfer.market.great'),
                ),
                matching: find.byType(Text),
              ),
            )
            .style
            ?.color,
        // Theme-aware now: `#4ADE80` is the dark-mode green and does not carry
        // on a light card, so the band is asked in the same theme it drew in.
        transferBand(
          120,
          tester.element(
            find.byKey(const ValueKey('transfer-band-transfer.market.great')),
          ),
        ).colour,
      );
    });

    test('the bands are Colin\'s own thresholds, so they cannot disagree', () {
      // He calls 200% incredible and 60% a good deal; below fair value he
      // starts talking about what the player is worth instead.
      expect(transferBand(250).key, 'transfer.market.jackpot');
      expect(transferBand(200).key, 'transfer.market.jackpot');
      expect(transferBand(60).key, 'transfer.market.great');
      expect(transferBand(20).key, 'transfer.market.fair');
      expect(transferBand(1).key, 'transfer.market.modest');
      expect(transferBand(0).key, 'transfer.market.below');
      expect(transferBand(-30).key, 'transfer.market.below');
    });

    testWidgets('and a bid at fair value is a BAND, not a +0%', (
      tester,
    ) async {
      final sellValue = players.firstWhere((p) => p.id == _defId).sellValue;
      await _pump(tester, _saveWithOffer(price: sellValue));
      expect(
        find.byKey(const ValueKey('transfer-band-transfer.market.below')),
        findsOneWidget,
      );
    });
  });

  group('THE WAY BACK TO A PARKED BID', () {
    testWidgets('a pending offer puts the pill up, and it opens the card', (
      tester,
    ) async {
      // Minimise had no return trip: the one dismissal that is not an answer
      // was also the one that could lose you the offer.
      final container = await _pumpShell(tester, _saveWithOffer());
      expect(find.byKey(const ValueKey('transfer-pill')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('transfer-pill')));
      await tester.pumpAndSettle();
      await _settleSave(tester);
      expect(find.byKey(const ValueKey('transfer-offer')), findsOneWidget);

      // Answering it takes the pill away with it.
      container.read(gameProvider).update((s) => declineOffer(s));
      await tester.pumpAndSettle();
      await _settleSave(tester);
      expect(find.byKey(const ValueKey('transfer-pill')), findsNothing);
    });

    testWidgets('and a save with no bid shows nothing at all', (tester) async {
      await _pumpShell(tester, createDefaultState());
      expect(find.byKey(const ValueKey('transfer-pill')), findsNothing);
    });
  });

  group('A BID WAITS FOR THE SCREEN IT LANDS ON', () {
    // The idle roll opened the card the instant the tick announced one,
    // wherever the player happened to be — including over the full-time
    // summary, which is the one screen in the game a player is reading a
    // result off. It goes through the queue now, and `play_button` holds a
    // blocker for the whole match, the summary and the round trip after it.
    /// A save with nothing else to say at boot: an unclaimed daily reward is a
    /// popup of its own, and it would be the one on screen.
    Map<String, dynamic> quietBoot() {
      final s = _saveWithOffer();
      s['dailyReward'] = <String, dynamic>{
        'cycleDay': 1,
        'lastClaimDayKey': dateString(),
        'streak': 1,
        'longestStreak': 1,
        'totalClaims': 1,
        'lastAutoPopupDayKey': dateString(),
      };
      return s;
    }

    Future<ProviderContainer> pumpHost(
      WidgetTester tester,
      Map<String, dynamic> state,
    ) async {
      final container = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
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
              home: const PopupHost(child: Scaffold(body: SizedBox.expand())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('a bid rolled during a match holds until the match lets go', (
      tester,
    ) async {
      await pumpHost(tester, quietBoot());
      blockPopups('match');
      addTearDown(() => unblockPopups('match'));

      emit('transfer:offered');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('transfer-offer')),
        findsNothing,
        reason: 'a bid opened over a match',
      );
      // Held, not dropped: nothing in this queue may time out or discard.
      expect(isPopupPending(transferOfferPopupId), isTrue);

      unblockPopups('match');
      await tester.pumpAndSettle();
      await _settleSave(tester);
      expect(find.byKey(const ValueKey('transfer-offer')), findsOneWidget);
    });

    testWidgets('and one answered while it waited never opens', (tester) async {
      // The pill is a second way to answer, so the entry is re-checked at show
      // time rather than trusted from when it was queued.
      final container = await pumpHost(tester, quietBoot());
      blockPopups('match');
      addTearDown(() => unblockPopups('match'));
      emit('transfer:offered');
      await tester.pumpAndSettle();

      container.read(gameProvider).update((s) => declineOffer(s));
      unblockPopups('match');
      await tester.pumpAndSettle();
      await _settleSave(tester);
      expect(find.byKey(const ValueKey('transfer-offer')), findsNothing);
    });
  });

  group("Colin's read", () {
    test('a huge premium outranks everything else', () {
      final state = _saveWithOffer(price: 999999);
      final offer =
          (state['transferMarket'] as Map<String, dynamic>)['pendingOffer']
              as Map<String, dynamic>;
      expect(
        transferAdvice(state, offer, findCardById(state, _instanceId)),
        t('manager.transfer.incredible'),
      );
    });

    test('a player in their final season is a sell, at a fair price', () {
      // Priced AT market: a 200% premium outranks everything, so a fat offer
      // would prove the wrong branch.
      final sellValue = players.firstWhere((p) => p.id == _defId).sellValue;
      final state = _saveWithOffer(
        price: sellValue,
        seasonsPlayed: 14,
        coins: 999999,
      );
      final offer =
          (state['transferMarket'] as Map<String, dynamic>)['pendingOffer']
              as Map<String, dynamic>;
      expect(
        transferAdvice(state, offer, findCardById(state, _instanceId)),
        contains('Final season'),
      );
    });

    test('a club that could not replace them is warned first', () {
      // The one line that is about the CLUB rather than the player, which is
      // why it outranks form and age.
      final state = _saveWithOffer(price: 1, coins: 0);
      final offer =
          (state['transferMarket'] as Map<String, dynamic>)['pendingOffer']
              as Map<String, dynamic>;
      expect(
        transferAdvice(state, offer, findCardById(state, _instanceId)),
        contains('rebuild'),
      );
    });
  });

  group('the provider', () {
    test('hands out a COPY, not the live map', () {
      // A widget holding the save's own map would watch the offer vanish under
      // it the moment the answer landed.
      final container = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({saveKeyPrimary: jsonEncode(_saveWithOffer())}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(gameProvider).load();

      final held = container.read(pendingOfferProvider);
      expect(held, isNotNull);
      container.read(gameProvider).update((s) => declineOffer(s));
      expect(held!['fromTeam'], _rival);
    });
  });
  group('THE TARGETED PLAYER IS MARKED', () {
    testWidgets('a bid picks him out of the squad', (tester) async {
      // A bid names a player and the squad page drew him like the other
      // twenty-nine, on a page whose whole job is that they all look the same —
      // so answering the offer meant finding the man first.
      final c = shopStyleContainer(_saveWithOffer());
      expect(c.read(bidTargetProvider), _instanceId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              home: const Scaffold(
                body: BidTargetMark(
                  instanceId: _instanceId,
                  child: SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bid-target-$_instanceId')),
        findsOneWidget,
      );
      expect(find.text('💸'), findsOneWidget);
    });

    testWidgets('and everybody else is left alone', (tester) async {
      final c = shopStyleContainer(_saveWithOffer());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              home: const Scaffold(
                body: BidTargetMark(
                  instanceId: 'somebody-else',
                  child: SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('💸'), findsNothing);
    });

    test('and a save with no bid marks nobody', () {
      final c = shopStyleContainer(createDefaultState());
      expect(c.read(bidTargetProvider), isNull);
    });
  });

}
