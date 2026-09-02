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
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

const String _defId = 'player_t1_fwd';
const String _foundKey = '$_defId:m';

Map<String, dynamic> _save({
  List<String> discovered = const [],
  Map<String, int> counts = const {},
  bool light = true,
}) {
  final s = createDefaultState();
  (s['settings'] as Map<String, dynamic>)['lightMode'] = light;
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
          // The home screen's walker loops forever, so `pumpAndSettle` would
          // never settle. He honours reduce-motion; declaring it here is what a
          // device with that setting on would do.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),

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
      expect(allIndexEntries.where((e) => e.female), hasLength(players.length));
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

    testWidgets('AN UNFOUND CARD IS A LOCKED SLOT, not a dark portrait', (
      tester,
    ) async {
      // A silhouette is still the card: its build, its stance and its haircut
      // all read at a glance, which gives away the thing the page exists to
      // make you want. The recipe dialog one tap behind this had already
      // settled it — it draws `❓` — and the tile never got the decision.
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 2}),
      );

      final unfound = find.byKey(const ValueKey('pi-card-$_defId:f'));
      await _reveal(tester, unfound);
      expect(
        find.descendant(of: unfound, matching: find.text('❓')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: unfound, matching: find.byType(ArtImage)),
        findsNothing,
        reason: 'the portrait is the spoiler',
      );

      final found = find.byKey(const ValueKey('pi-card-$_foundKey'));
      await _reveal(tester, found);
      expect(
        find.descendant(of: found, matching: find.text('❓')),
        findsNothing,
      );
    });

    testWidgets('and it says the TIER and the gender, and nothing else', (
      tester,
    ) async {
      // The two things that make a slot worth chasing. The position came off
      // with the portrait — the caption had already dropped it and the badge
      // was still printing it beside a silhouette in the shape of a keeper.
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 2}),
      );
      final def = players.firstWhere((p) => p.id == _defId);

      final unfound = find.byKey(const ValueKey('pi-card-$_defId:f'));
      await _reveal(tester, unfound);
      // Twice: the corner badge and the caption's second line, which has read
      // the bare tier for an unfound card since it was written.
      expect(
        find.descendant(of: unfound, matching: find.text('T${def.tier}')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: unfound, matching: find.text('♀')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unfound,
          matching: find.text('${def.position} T${def.tier}'),
        ),
        findsNothing,
      );
      // A count of nothing is not a fact worth a badge.
      expect(
        find.descendant(of: unfound, matching: find.text('×0')),
        findsNothing,
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

      expect(
        find.byKey(const ValueKey('pi-recipe-$_foundKey')),
        findsOneWidget,
      );
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

  group('light and dark', () {
    /// The card's caption band — the strip of colour under the portrait.
    /// The colour the caption is READ OFF.
    ///
    /// **It is a gradient's last stop now, not a `Container.color`.** The band
    /// was a solid strip UNDER the art — a thumbnail with a label rather than a
    /// card — and the Players tab has drawn its own the other way since
    /// `PlayerCard` was written: the picture is the card and the words float on
    /// it. So what carries the contrast is the bottom of a fade, and that is
    /// what this reads.
    Color captionOf(WidgetTester tester) {
      final card = find.byKey(const ValueKey('pi-card-$_foundKey'));
      expect(card, findsOneWidget);
      final scrims = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: card, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((b) => b.gradient)
          .whereType<LinearGradient>()
          .where((g) => g.colors.last.a > 0.5)
          .toList();
      expect(scrims, isNotEmpty, reason: 'the card has no caption scrim');
      return scrims.last.colors.last;
    }

    testWidgets('THE INDEX CARD IS LIGHT IN LIGHT MODE', (tester) async {
      // Every colour on this card was fixed: the tier's DARK body gradient and
      // a 70% black caption in both themes. Light mode is the DEFAULT — see
      // `lightModeProvider` — so a page of dark tiles under a light sheet is
      // what most players were looking at.
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 2}),
      );
      final caption = captionOf(tester);
      expect(
        caption.r + caption.g + caption.b,
        greaterThan(2.4),
        reason: 'the caption band is $caption, which is not a light scrim',
      );
    });

    testWidgets('and dark in dark mode, which it always was', (tester) async {
      await _pump(
        tester,
        _save(discovered: [_foundKey], counts: {_foundKey: 2}, light: false),
      );
      final caption = captionOf(tester);
      expect(
        caption.r + caption.g + caption.b,
        lessThan(0.6),
        reason: 'the caption band is $caption, which is not a dark scrim',
      );
    });
  });

  group('reachability', () {
    testWidgets('the quick-nav menu opens it', (tester) async {
      await _pump(tester, _save(), viaShell: true);
      await tester.tap(find.byKey(const ValueKey('dock-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('quick-nav-scene.dock.index')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-index')), findsOneWidget);
    });
  });
}
