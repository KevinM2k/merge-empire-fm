/// Putting vouchers on the cards of a batch before it is drawn.
///
/// The sheet is where a collectable voucher gets spent, so these are as much
/// about REACHABILITY as behaviour: the engine can assign a voucher per slot,
/// and without this screen nothing a player can touch ever does.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/scout_assign_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic> save({
  List<int> vouchers = const [],
  int coins = 10000000,
  String division = 'champions_cup',
  Map<String, dynamic>? rules,
}) {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)['done'] = true;
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  (s['progression'] as Map<String, dynamic>)['currentDivision'] = division;
  if (vouchers.isNotEmpty) {
    (s['shop'] as Map<String, dynamic>)['scoutVouchers'] = [...vouchers];
  }
  if (rules != null) {
    (s['settings'] as Map<String, dynamic>)['autoTierActions'] = rules;
  }
  return s;
}

/// Opens the sheet over a bare page and records what it returns.
///
/// The result is captured rather than awaited, because every test acts on the
/// sheet while it is still up — awaiting the future here would deadlock the
/// pump. [closed] is what the sheet finally handed back.
class Harness {
  Harness._(this.container);

  final ProviderContainer container;
  List<int?>? result;
  bool closed = false;
}

Future<Harness> pumpSheet(
  WidgetTester tester,
  Map<String, dynamic> state, {
  int batch = 4,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  final h = Harness._(container);

  late BuildContext ctx;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                ctx = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    ),
  );

  unawaited(
    showScoutAssignSheet(ctx, batch: batch, state: state).then((v) {
      h.result = v;
      h.closed = true;
    }),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('the tray', () {
    testWidgets('lays out one chip per voucher held', (tester) async {
      await pumpSheet(tester, save(vouchers: [8, 5, 5]));

      expect(find.byKey(const ValueKey('assign-chip-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('assign-chip-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('assign-chip-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('assign-chip-3')), findsNothing);
    });

    testWidgets('THE TOKEN IS THE 🎲, NOT A TIER-ONE CHIP', (tester) async {
      // Its worth is "free, and anything can turn up" — it is the only voucher
      // that can hand over an Icon. Drawing it at the bottom of the tier ladder
      // would say the opposite of what it does.
      await pumpSheet(tester, save(vouchers: [anyCardVoucher]));

      expect(find.text(t('shop.voucher.random')), findsOneWidget);
      expect(find.text(tierLabel[1]!), findsNothing);
    });

    testWidgets('a voucher this division cannot draw is not draggable', (
      tester,
    ) async {
      // Reachable: a prestige keeps the inventory and drops the player back to
      // Sunday League, so a World Class voucher outlives the division that
      // sold it. Assigning one would fail the draw and stop the whole batch.
      await pumpSheet(tester, save(vouchers: [8], division: 'sunday_league'));

      expect(find.byType(Draggable<int>), findsNothing);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('and at the top of the pyramid the same one is', (
      tester,
    ) async {
      await pumpSheet(tester, save(vouchers: [8]));
      expect(find.byType(Draggable<int>), findsOneWidget);
    });
  });

  group('assigning', () {
    testWidgets('a tap covers the first free card and drops the total', (
      tester,
    ) async {
      final state = save(vouchers: [5]);
      final unit = scoutCost(state, ignoreVoucher: true);
      await pumpSheet(tester, state, batch: 4);

      expect(find.text('${t('common.continue')} · ${formatCoins(unit * 4)}'),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('assign-chip-0')));
      await tester.pumpAndSettle();

      expect(find.text('${t('common.continue')} · ${formatCoins(unit * 3)}'),
          findsOneWidget);
      expect(find.text(t('scout.assign.free')), findsOneWidget);
      expect(
        find.text(t('scout.assign.promised', {'tier': tierLabel[5]!})),
        findsOneWidget,
      );
    });

    testWidgets('a drag covers the card it was dropped on', (tester) async {
      await pumpSheet(tester, save(vouchers: [3]), batch: 2);

      final chip = find.byKey(const ValueKey('assign-chip-0'));
      final slot = find.byKey(const ValueKey('assign-slot-1'));
      await tester.drag(chip, tester.getCenter(slot) - tester.getCenter(chip));
      await tester.pumpAndSettle();

      // The badge is on the second card, which is the one that was targeted.
      expect(
        find.descendant(
          of: slot,
          matching: find.text(
            t('scout.assign.promised', {'tier': tierLabel[3]!}),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a covered card takes the voucher back off it', (
      tester,
    ) async {
      final state = save(vouchers: [5]);
      final unit = scoutCost(state, ignoreVoucher: true);
      await pumpSheet(tester, state, batch: 2);

      await tester.tap(find.byKey(const ValueKey('assign-chip-0')));
      await tester.pumpAndSettle();
      expect(find.text(t('scout.assign.free')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('assign-slot-0')));
      await tester.pumpAndSettle();
      expect(find.text(t('scout.assign.free')), findsNothing);
      expect(find.text('${t('common.continue')} · ${formatCoins(unit * 2)}'),
          findsOneWidget);
    });

    testWidgets('ONE CHIP CANNOT COVER TWO CARDS', (tester) async {
      // The assignment is keyed by tray POSITION rather than by floor, because
      // the tray can hold several of the same tier. Keyed by floor, dropping
      // the same chip on a second slot would leave both claiming it and the
      // batch would try to spend a voucher that is not there.
      await pumpSheet(tester, save(vouchers: [5]), batch: 2);

      final chip = find.byKey(const ValueKey('assign-chip-0'));
      for (final slot in ['assign-slot-0', 'assign-slot-1']) {
        final target = find.byKey(ValueKey(slot));
        await tester.drag(
          chip,
          tester.getCenter(target) - tester.getCenter(chip),
        );
        await tester.pumpAndSettle();
      }

      // It MOVED to the second card rather than covering both.
      expect(find.text(t('scout.assign.free')), findsOneWidget);
    });
  });

  group('the warnings', () {
    testWidgets('a floor the sell rules cover is flagged', (tester) async {
      await pumpSheet(tester,
        save(vouchers: [5], rules: {'5': TierAction.sell}),
        batch: 1,
      );

      expect(find.text(t('scout.assign.autosell')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('assign-chip-0')));
      await tester.pumpAndSettle();
      expect(find.text(t('scout.assign.autosell')), findsOneWidget);
    });

    testWidgets('and one they do not is left alone', (tester) async {
      await pumpSheet(tester,
        save(vouchers: [5], rules: {'2': TierAction.sell}),
        batch: 1,
      );

      await tester.tap(find.byKey(const ValueKey('assign-chip-0')));
      await tester.pumpAndSettle();
      // A tier-5 floor draws 5..8; a rule on tier 2 can never catch one.
      expect(find.text(t('scout.assign.autosell')), findsNothing);
    });

    testWidgets('A WORLD CLASS VOUCHER CAN NEVER WARN', (tester) async {
      // `maxAutoTier` is 7 — no rule can be set for tier 8 — so a tier-8 floor
      // is out of reach of every rule. Correct rather than a gap.
      await pumpSheet(tester,
        save(
          vouchers: [8],
          rules: {for (final t in autoTiers) '$t': TierAction.sell},
        ),
        batch: 1,
      );

      await tester.tap(find.byKey(const ValueKey('assign-chip-0')));
      await tester.pumpAndSettle();
      expect(find.text(t('scout.assign.autosell')), findsNothing);
    });
  });

  group('what it hands back', () {
    testWidgets('THE ASSIGNMENT, SLOT BY SLOT', (tester) async {
      // What `signPlayers` takes: one entry per card, in order. A null is a
      // slot left to the coins.
      final h = await pumpSheet(tester, save(vouchers: [8, 3]), batch: 3);

      final chip = find.byKey(const ValueKey('assign-chip-1')); // the 3
      final slot = find.byKey(const ValueKey('assign-slot-2'));
      await tester.drag(chip, tester.getCenter(slot) - tester.getCenter(chip));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('assign-go')));
      await tester.pumpAndSettle();

      expect(h.closed, isTrue);
      expect(h.result, [null, null, 3]);
    });

    testWidgets('and the token comes back as 1, not as a floor', (
      tester,
    ) async {
      final h = await pumpSheet(
        tester,
        save(vouchers: [anyCardVoucher]),
        batch: 1,
      );
      await tester.tap(find.byKey(const ValueKey('assign-chip-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-go')));
      await tester.pumpAndSettle();

      expect(h.result, [anyCardVoucher]);
    });

    testWidgets('continuing with nothing on is all nulls, not a cancel', (
      tester,
    ) async {
      final h = await pumpSheet(tester, save(vouchers: [5]), batch: 2);
      await tester.tap(find.byKey(const ValueKey('assign-go')));
      await tester.pumpAndSettle();

      expect(h.closed, isTrue);
      expect(h.result, [null, null]);
    });

    testWidgets('CANCEL IS NULL, WHICH CALLS THE WHOLE SCOUT OFF', (
      tester,
    ) async {
      // Distinct from "continue with nothing assigned" on purpose. A scrim tap
      // or a swipe down is easy to do by accident, and reading it as "go ahead
      // and charge me for four" spends real coins on a slip.
      final h = await pumpSheet(tester, save(vouchers: [5]), batch: 2);
      await tester.tap(find.byKey(const ValueKey('assign-cancel')));
      await tester.pumpAndSettle();

      expect(h.closed, isTrue);
      expect(h.result, isNull);
    });
  });

  group('the way out', () {
    testWidgets('CONTINUE IS SHUT WHILE THE UNCOVERED CARDS COST TOO MUCH', (
      tester,
    ) async {
      // The hole the additive batch capacity opens: `availableScoutBatchSizes`
      // counts a held voucher as a card, so a ×2 can be offered on one voucher
      // plus one card's worth of coins. Decline to assign it and the batch is
      // suddenly two cards the wallet cannot pay for.
      final state = save(vouchers: [5], coins: 0);
      await pumpSheet(tester, state, batch: 2);

      expect(find.text(t('scout.assign.short')), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('assign-go')),
        ).onPressed,
        isNull,
      );
    });

    testWidgets('and opens as soon as enough of them are covered', (
      tester,
    ) async {
      final state = save(vouchers: [5, 6], coins: 0);
      await pumpSheet(tester, state, batch: 2);

      await tester.tap(find.byKey(const ValueKey('assign-chip-0')));
      await tester.pumpAndSettle();
      expect(find.text(t('scout.assign.short')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('assign-chip-1')));
      await tester.pumpAndSettle();
      expect(find.text(t('scout.assign.short')), findsNothing);
      expect(
        tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('assign-go')),
        ).onPressed,
        isNotNull,
      );
    });
  });
}
