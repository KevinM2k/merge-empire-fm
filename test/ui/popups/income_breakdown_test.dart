/// Where the idle rate comes from, and why it is lower than it looks.
///
/// **Eighteen `hud.income.*` strings sat translated in all ten catalogues with
/// nothing able to reach one**, and the coin chip has carried
/// `hud.aria.income_breakdown` as its accessibility label since it was written
/// with nothing behind it — a door with a sign on it and no room on the other
/// side.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/income_breakdown.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// A grid cell for the cheapest real definition, so the arithmetic uses the
/// game's own numbers rather than an invented player.
Map<String, dynamic> _card(
  String id, {
  int variant = 0,
  int? loanMatchesLeft,
  bool injured = false,
}) => {
  'instanceId': 'i-$id-$variant-${loanMatchesLeft ?? 'x'}',
  'definitionId': id,
  'variant': variant,
  'injured': injured,
  // **`borrowed` AND `loanMatchesLeft`, because they are different facts.** The
  // first is what makes a card earn nothing; the second is what makes it cost a
  // wage. A loaned-in player is both, and that is exactly why he costs twice —
  // the wage, and the slot he occupies without earning.
  if (loanMatchesLeft != null) ...{
    'loanMatchesLeft': loanMatchesLeft,
    'borrowed': true,
  },
};

void main() {
  tearDown(resetLocale);
  final def = players.first;

  group('the books add up', () {
    test('the headline is the NET rate, not the gross', () {
      // Wages come off AFTER the multiplier, so a gross figure with a wage line
      // under it would print a number that never arrives.
      final s = createDefaultState();
      (s['grid'] as Map<String, dynamic>)['cells'] = [
        _card(def.id),
        _card(def.id, variant: 1, loanMatchesLeft: 3),
      ];
      final books = incomeBreakdown(s);
      expect(books.net, closeTo(netIncomePerSec(s), 1e-9));
      expect(books.gross, closeTo(grossIncomePerSec(s), 1e-9));
      expect(books.wages, greaterThan(0), reason: 'a loanee costs nothing');
      expect(books.net, lessThan(books.gross));
    });

    test('and every row comes from the ENGINE, not from local arithmetic', () {
      // The JS learned this the hard way: reproducing the per-card maths made an
      // income trait invisible, because the list read a pre-trait rate while the
      // squad sheet showed the higher one and neither summed to the total.
      final s = createDefaultState();
      final cards = [_card(def.id), _card(def.id, variant: 1)];
      (s['grid'] as Map<String, dynamic>)['cells'] = cards;
      final books = incomeBreakdown(s);
      expect(books.players, hasLength(2));
      expect(
        books.players.fold<double>(0, (n, r) => n + r.perSec),
        closeTo(books.base, 1e-9),
        reason: 'the rows do not sum to the total printed under them',
      );
    });

    test('the multipliers MULTIPLY OUT to the combined figure', () {
      // A list that does not is worse than no list.
      final s = createDefaultState();
      (s['grid'] as Map<String, dynamic>)['cells'] = [_card(def.id)];
      (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.merch] = {
        'owned': true,
        'tier': 3,
      };
      (s['boosts'] as Map<String, dynamic>)['kitSponsorSeason'] =
          (s['progression'] as Map<String, dynamic>)['seasonCount'];

      final books = incomeBreakdown(s);
      expect(books.factors, hasLength(2));
      expect(
        books.factors.fold<double>(1, (n, f) => n * f.x),
        closeTo(books.multiplier, 1e-9),
      );
    });

    test('WAGES THAT WIPE OUT THE INCOME SAY SO', () {
      // The negative case is the whole reason this screen was asked for: the
      // only sign of it was the idle bar quietly running backwards.
      final s = createDefaultState();
      (s['grid'] as Map<String, dynamic>)['cells'] = [
        _card(def.id, loanMatchesLeft: 3),
      ];
      final books = incomeBreakdown(s);
      expect(books.capped, isTrue, reason: 'the squad can somehow afford it');
      expect(books.net, 0, reason: 'the balance is never eaten');
      expect(books.loans, hasLength(1));
    });

    test('an empty grid is a state, not a crash', () {
      final books = incomeBreakdown(createDefaultState());
      expect(books.players, isEmpty);
      expect(books.base, 0);
      expect(books.net, 0);
      expect(books.capped, isFalse);
    });
  });

  group('and the player can reach it', () {
    testWidgets('THE COIN CHIP OPENS THE BOOKS', (tester) async {
      // The chip has carried the breakdown's aria label since it was written and
      // had nothing behind it.
      final state = createDefaultState();
      (state['grid'] as Map<String, dynamic>)['cells'] = [_card(def.id)];
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
              home: const Scaffold(body: Hud()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('hud-coins')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('income-breakdown')),
        findsOneWidget,
        reason: 'the coin chip explains nothing',
      );
      expect(find.text(t('hud.income.title')), findsOneWidget);
      expect(find.byKey(const ValueKey('income-net')), findsOneWidget);
    });
  });
}
