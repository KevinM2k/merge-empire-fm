/// The auto-sell rules, as the player sets them.
///
/// The engine was ported and tested in M1 with nothing able to switch it on —
/// `setTierAction` had no caller at all — so these tests are as much about
/// REACHABILITY as behaviour: every one of them starts from a tap.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/auto_tier_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> _save({
  bool tutorialDone = true,
  Map<String, dynamic>? rules,
}) {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)['done'] = tutorialDone;
  if (rules != null) {
    (s['settings'] as Map<String, dynamic>)['autoTierActions'] = rules;
  }
  return s;
}

Future<ProviderContainer> pumpRow(
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
          home: const Scaffold(body: AutoTierRow()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

String _rule(ProviderContainer c, int tier) =>
    getTierAction(c.read(gameProvider).state, tier);

void main() {
  tearDown(resetLocale);

  group('the summary', () {
    test('says Off when no rule is set', () {
      expect(autoTierSummary(_save()), t('settings.autoTier.off'));
    });

    test('names the tiers while there are few enough to name', () {
      final s = _save(rules: {'1': TierAction.sell, '3': TierAction.sell});
      final summary = autoTierSummary(s);
      expect(summary, contains(tierLabel[1]!));
      expect(summary, contains(tierLabel[3]!));
    });

    test('counts them once naming would not fit', () {
      final s = _save(
        rules: {
          '1': TierAction.sell,
          '2': TierAction.sell,
          '3': TierAction.sell,
          '4': TierAction.sell,
        },
      );
      expect(autoTierSummary(s), t('settings.autoTier.count', {'count': 4}));
    });
  });

  group('the sheet', () {
    testWidgets('opens from the Settings row and lists every eligible tier', (
      tester,
    ) async {
      await pumpRow(tester, _save());
      await tester.tap(find.byKey(const ValueKey('auto-tier-row')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auto-tier-sheet')), findsOneWidget);
      for (final tier in autoTiers) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('auto-tier-$tier')),
          80,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byKey(ValueKey('auto-tier-$tier')), findsOneWidget);
      }
    });

    testWidgets('and offers no switch for the two that are never sold', (
      tester,
    ) async {
      // A chase card sold out from under the player, and a globally unique tier
      // nine that could never be got back.
      await pumpRow(tester, _save());
      await tester.tap(find.byKey(const ValueKey('auto-tier-row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auto-tier-8')), findsNothing);
      expect(find.byKey(const ValueKey('auto-tier-9')), findsNothing);
    });

    testWidgets('a toggle writes the rule to the save', (tester) async {
      final container = await pumpRow(tester, _save());
      expect(_rule(container, 1), TierAction.keep);

      await tester.tap(find.byKey(const ValueKey('auto-tier-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auto-tier-1')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(_rule(container, 1), TierAction.sell);
    });

    testWidgets('and switching it back off clears it', (tester) async {
      final container = await pumpRow(
        tester,
        _save(rules: {'1': TierAction.sell}),
      );
      await tester.tap(find.byKey(const ValueKey('auto-tier-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auto-tier-1')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(_rule(container, 1), TierAction.keep);
      expect(
        activeAutoTiers(container.read(gameProvider).state),
        isEmpty,
        reason: 'cleared, not stored as keep',
      );
    });

    testWidgets('mid-tutorial it says the rules are not live yet', (
      tester,
    ) async {
      // They are dormant by design: every Sunday League draw is bronze, so a
      // live bronze rule would soft-lock "scout until you have three".
      await pumpRow(tester, _save(tutorialDone: false));
      await tester.tap(find.byKey(const ValueKey('auto-tier-row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auto-tier-dormant')), findsOneWidget);
    });

    testWidgets('and once it is done, it does not', (tester) async {
      await pumpRow(tester, _save());
      await tester.tap(find.byKey(const ValueKey('auto-tier-row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auto-tier-dormant')), findsNothing);
    });

    testWidgets('the row reflects what is set behind it', (tester) async {
      final container = await pumpRow(
        tester,
        _save(rules: {'1': TierAction.sell}),
      );
      expect(
        find.textContaining(tierLabel[1]!),
        findsOneWidget,
        reason: 'the summary, on the row',
      );
      expect(container.read(autoTierActiveProvider), isTrue);
    });
  });
}
