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
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

const String _defId = 'player_t3_fwd';
const String _instanceId = 'c0';
const String _rival = 'Ayton Rovers';

/// A save holding one player and one bid for them.
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

    testWidgets('says plainly that declining costs something', (tester) async {
      // It is the half of the decision the numbers do not carry.
      await _pump(tester, _saveWithOffer());
      expect(
        find.text(t('transfer.decline_warning', {'club': _rival})),
        findsOneWidget,
      );
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
}
