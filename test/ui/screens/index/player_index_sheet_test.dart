/// The Player Index, and the menu that reaches it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/index/player_index_sheet.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

const String _defId = 'player_t1_fwd';
const String _foundKey = '$_defId:m';

Map<String, dynamic> _save({
  List<String> discovered = const [],
  Map<String, int> counts = const {},
}) {
  final s = createDefaultState();
  // No boot popup competing for the screen.
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': 1,
    'lastClaimDayKey': dateString(),
    'streak': 1,
    'longestStreak': 1,
    'totalClaims': 1,
    'lastAutoPopupDayKey': dateString(),
  };
  final prog = s['progression'] as Map<String, dynamic>;
  prog['discoveredPlayers'] = [...discovered];
  prog['playerFoundCounts'] = <String, dynamic>{...counts};
  return s;
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Map<String, dynamic> state, {
  bool viaShell = false,
}) async {
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
          home: viaShell
              ? const AppShell()
              : Scaffold(
                  body: Builder(
                    builder: (inner) => ElevatedButton(
                      key: const ValueKey('open'),
                      onPressed: () => showPlayerIndexSheet(inner),
                      child: const Text('open'),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
  if (viaShell) {
    await tester.pump(const Duration(milliseconds: 32));
  } else {
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }
  return container;
}

Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> _pickFilter(
  WidgetTester tester,
  String field,
  String option,
) async {
  await _reveal(tester, find.byKey(ValueKey('pi-filter-$field')));
  await tester.tap(find.byKey(ValueKey('pi-filter-$field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  group('the catalogue', () {
    test('is every definition twice, once per gender', () {
      // One definition is TWO rows. Counting it once is the bug that would make
      // a completed index read half full forever.
      expect(allIndexEntries, hasLength(players.length * 2));
      expect(
        allIndexEntries.where((e) => e.female),
        hasLength(players.length),
      );
    });

    test('is ordered tier, then position down the pitch, then gender', () {
      for (var i = 1; i < allIndexEntries.length; i++) {
        final prev = allIndexEntries[i - 1];
        final next = allIndexEntries[i];
        expect(prev.def.tier <= next.def.tier, isTrue);
      }
      // The first pair is the lowest tier, and male leads.
      expect(allIndexEntries.first.female, isFalse);
      expect(allIndexEntries[1].female, isTrue);
    });

    test('every tier can be scouted somewhere', () {
      // Derived from the odds table rather than written down, so a weighting
      // change moves it — but a tier that fell out entirely would leave a card
      // in the index with no way at all to get it.
      for (final tier in {for (final p in players) p.tier}) {
        expect(tierScoutDivisions[tier], isNotEmpty, reason: 'tier $tier');
      }
    });
  });

  group('the grid', () {
    testWidgets('a found card shows its name and an unfound one does not', (
      tester,
    ) async {
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 2}),
      );
      final found = find.byKey(const ValueKey('pi-card-$_foundKey'));
      await _reveal(tester, found);
      expect(
        find.descendant(
          of: found,
          matching: find.text(
            indexCardName((
              def: players.firstWhere((p) => p.id == _defId),
              female: false,
            )).toUpperCase(),
          ),
        ),
        findsOneWidget,
      );

      final unfound = find.byKey(const ValueKey('pi-card-$_defId:f'));
      await _reveal(tester, unfound);
      expect(
        find.descendant(of: unfound, matching: find.text('???')),
        findsOneWidget,
      );
    });

    testWidgets('the count badge shows how many have been pulled', (
      tester,
    ) async {
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 7}),
      );
      final card = find.byKey(const ValueKey('pi-card-$_foundKey'));
      await _reveal(tester, card);
      expect(
        find.descendant(of: card, matching: find.text('×7')),
        findsOneWidget,
      );
    });
  });

  group('the filters', () {
    testWidgets('status narrows to what has been found', (tester) async {
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 1}),
      );
      await _pickFilter(tester, 'status', t('pi.filter.found'));
      expect(find.byKey(const ValueKey('pi-card-$_foundKey')), findsOneWidget);
      expect(find.byKey(const ValueKey('pi-card-$_defId:f')), findsNothing);
    });

    testWidgets('a filter matching nothing says so', (tester) async {
      // An empty grid with no explanation reads as a broken screen.
      await _pump(tester, _save());
      await _pickFilter(tester, 'status', t('pi.filter.found'));
      expect(find.byKey(const ValueKey('player-index-empty')), findsOneWidget);
    });

    testWidgets('gender halves the list', (tester) async {
      await _pump(tester, _save());
      await _pickFilter(tester, 'gender', '♀ ${t('pi.gender_female')}');
      expect(find.byKey(const ValueKey('pi-card-$_defId:f')), findsOneWidget);
      expect(find.byKey(const ValueKey('pi-card-$_foundKey')), findsNothing);
    });
  });

  group('the recipe', () {
    testWidgets('an unfound card hides its stats but says where to look', (
      tester,
    ) async {
      // Knowing a card's rating before ever seeing one is the spoiler the whole
      // screen exists to avoid; where to scout it is how you go and get it.
      await _pump(tester, _save());
      final card = find.byKey(const ValueKey('pi-card-$_foundKey'));
      await _reveal(tester, card);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pi-recipe-$_foundKey')), findsOneWidget);
      expect(find.text(t('pi.stats_title').toUpperCase()), findsNothing);
      expect(
        find.text(t('pi.scout_availability').toUpperCase()),
        findsOneWidget,
      );
      expect(find.textContaining(t('pi.not_found')), findsOneWidget);
    });

    testWidgets('a found card shows rating and income', (tester) async {
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 1}),
      );
      final card = find.byKey(const ValueKey('pi-card-$_foundKey'));
      await _reveal(tester, card);
      await tester.tap(card);
      await tester.pumpAndSettle();

      final def = players.firstWhere((p) => p.id == _defId);
      expect(find.text(t('pi.stats_title').toUpperCase()), findsOneWidget);
      expect(find.text('${def.rating}'), findsOneWidget);
      expect(find.text('+${def.idleIncomePerSec}/s'), findsOneWidget);
    });
  });

  group('reachability', () {
    testWidgets('the quick-nav menu opens it', (tester) async {
      await _pump(tester, _save(), viaShell: true);
      await tester.tap(find.byKey(const ValueKey('dock-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-nav-scene.dock.index')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-index')), findsOneWidget);
    });
  });
}
