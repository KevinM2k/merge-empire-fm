/// The card that says what the Play button is about to do.
///
/// It is the page's headline on a screen with no spare height, so the LAYOUT is
/// the thing worth pinning: three tracks — home, gutter, away — with every band
/// keyed off the same gutter, so the ratings land under the club names and the
/// mirrored ATK/DEF block sits between them without touching either.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart' show cupForDivision;
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show opponentsPerSeason;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart' show saveDebounceMs;
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart' show GlassPanel;
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

Future<ProviderContainer> pumpCard(
  WidgetTester tester, {
  void Function(Map<String, dynamic>)? mutate,
  double width = 360,
}) async {
  final state = createDefaultState();
  mutate?.call(state);

  // **The VIEWPORT tracks the card width**, because on the page it is the other
  // way round: the card is the viewport less 13 of page inset and 8 of card
  // padding a side. The mirrored stat block now takes its bars off below a
  // 380pt viewport (the spec's media query), so a 320pt card at the harness's
  // default 800pt viewport is a configuration the app cannot produce — bars
  // drawn at a width that has no room for them.
  tester.view.physicalSize = Size(width + 42, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Through the runner: the schedule and the opponents are boot sweeps, and a
  // card with no fixture is a card that draws nothing.
  container.read(gameRunnerProvider).boot();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: const NextMatchCard()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// A save on a cup week: a division that has a cup, a bracket drawn, and a
/// fixture index far enough in for the round to be due.
///
/// The Fan Zone is bought so the LEAGUE fixture genuinely carries a home
/// advantage — a modifier that is zero either way proves nothing about a card
/// that is supposed to drop it.
void _cupWeek(Map<String, dynamic> s, {required bool active}) {
  final prog = s['progression'] as Map<String, dynamic>;
  prog['currentDivision'] = divisions[cups.first.unlocksAtDivisionIdx].id;
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.fanzone] = {
    'owned': true,
    'tier': 3,
  };
  // The first index at or after a round's due mark that is also a HOME
  // fixture, so `ourHomeAdv` is non-zero on the league side of the comparison.
  final season = (prog['seasonCount'] as num?)?.toInt() ?? 1;
  var played = cupDueAfterMatches.first;
  while (!fixtureIsHome(season, played % opponentsPerSeason, played)) {
    played++;
  }
  prog['seasonMatchesPlayed'] = played;
  final round = cupDueAfterMatches.lastIndexWhere((m) => played >= m);
  final cup = cupForDivision(s);
  prog['cups'] = <String, dynamic>{
    'availableThisSeason': false,
    'active': (!active || cup == null)
        ? null
        : <String, dynamic>{
            'cupId': cup.id,
            'round': round < 0 ? 0 : round,
            'opponents': [for (final name in cup.rounds) 'Rival $name'],
            'opponentMeta': [
              for (final _ in cup.rounds)
                <String, dynamic>{
                  'divId': prog['currentDivision'],
                  'rating': 50,
                  'attackRatio': 0.5,
                },
            ],
            'contexts': <dynamic>[],
            'results': <dynamic>[],
            'startedAt': 0,
            'startedSeason': season,
          },
    'history': <dynamic>[],
  };
}

void main() {
  group('A CUP TIE CARRIES NONE OF THE LEAGUE\'S MODIFIERS', () {
    // Reported from the couch: "I got a boost for fighting relegation, but it
    // was a cup game." The opposition's list was emptied for a cup week when
    // the card learned to name the tie's own opponent; ours was not, so the
    // card went on hanging a house and a bolt under OUR figure — and folding
    // both into it — for a fixture that has neither. `prepareCupRound` plays a
    // tie on neutral ground and `cup_engine` has never heard of the relegation
    // lift.
    testWidgets('the league fixture is the control, and it HAS one', (
      tester,
    ) async {
      final container = await pumpCard(
        tester,
        mutate: (s) => _cupWeek(s, active: false),
      );
      final preview = previewFixture(container.read(gameProvider).state)!;
      expect(
        preview.isHome && preview.ourHomeAdv > 0,
        isTrue,
        reason: 'the control fixture carries no modifier to drop',
      );
      final card = container.read(nextMatchProvider)!;
      final us = card.left.ours ? card.left : card.right;
      expect(us.mods, isNotEmpty);
      expect(us.rating, greaterThan(preview.squadRating));
      await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
    });

    testWidgets('and the cup week drops them, chips and figure alike', (
      tester,
    ) async {
      final container = await pumpCard(
        tester,
        mutate: (s) => _cupWeek(s, active: true),
      );
      final state = container.read(gameProvider).state;
      expect(cupDue(state), isTrue, reason: 'no tie was due at all');
      final preview = previewFixture(state)!;
      final card = container.read(nextMatchProvider)!;
      final us = card.left.ours ? card.left : card.right;
      expect(
        us.mods,
        isEmpty,
        reason: 'a cup tie advertised a league fixture\'s modifiers',
      );
      expect(
        us.rating,
        preview.squadRating,
        reason: 'the figure still carried the modifiers the chips lost',
      );
      await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
    });
  });

  group('what the card ANSWERS', () {
    testWidgets('THE POSITION CHIP OPENS THE TABLE', (tester) async {
      // A position is a claim about a table, and the only route to the table was
      // three taps away behind the burger — so the one control on the screen
      // that names where you stand could not show you the standing.
      final container = await pumpCard(tester);
      addTearDown(container.dispose);
      final chip = find.byKey(const ValueKey('nm-pos-ours'));
      expect(chip, findsOneWidget, reason: 'no position on the card');
      await tester.tap(chip, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('league-table')),
        findsOneWidget,
        reason: 'tapping the position showed no table',
      );
    });

    testWidgets('and a modifier explains itself on a TAP', (tester) async {
      // `Tooltip`'s default trigger on a touch screen is a LONG PRESS, so the
      // `+1` beside the club rating had an explanation nobody could reach
      // without knowing to hold it down.
      final container = await pumpCard(tester);
      addTearDown(container.dispose);
      final tips = find.byType(Tooltip);
      expect(tips, findsWidgets, reason: 'no modifiers on the card at all');
      for (final tip in tester.widgetList<Tooltip>(tips)) {
        expect(
          tip.triggerMode,
          TooltipTriggerMode.tap,
          reason: 'a modifier still wants a long press',
        );
      }
    });
  });

  group('the next-match card', () {
    testWidgets('draws at all, without throwing', (tester) async {
      await pumpCard(tester);
      expect(find.byKey(const ValueKey('next-match-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('IS THINNER THAN A DEEP PANEL — the pitch shows through', (
      tester,
    ) async {
      // **Reported from the couch: the card can be a little more
      // transparent.** It stands on the SCENE rather than on a page, and at the
      // deep density's 43% it read as a slab laid over the pitch.
      await pumpCard(tester);
      final pane = tester.widget<GlassPanel>(
        find.byKey(const ValueKey('next-match-card')),
      );
      expect(pane.tint, isNotNull, reason: 'it took the density it was given');
      expect(pane.tint!.first.a, lessThan(0.30));
    });

    testWidgets('names both clubs and rates both sides', (tester) async {
      await pumpCard(tester);
      expect(find.byKey(const ValueKey('nm-name-ours')), findsOneWidget);
      expect(find.byKey(const ValueKey('nm-name-theirs')), findsOneWidget);
      expect(find.byKey(const ValueKey('nm-figure-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('nm-figure-right')), findsOneWidget);
    });

    testWidgets('the ratings never overlap the ATK/DEF block', (tester) async {
      // The ratings are taken out of flow and pinned to the span of the team
      // column above; the stat rows are centred and DERIVED to stop short of
      // them. Get the arithmetic wrong and the big figures print straight
      // through the middle of the comparison they are annotating.
      for (final width in [320.0, 360.0, 400.0, 480.0]) {
        await pumpCard(tester, width: width);
        final left = tester.getRect(
          find.byKey(const ValueKey('nm-figure-left')),
        );
        final right = tester.getRect(
          find.byKey(const ValueKey('nm-figure-right')),
        );
        final atk = tester.getRect(find.byKey(const ValueKey('nm-stat-atk-l')));
        final rows = tester.getRect(
          find
              .ancestor(
                of: find.byKey(const ValueKey('nm-stat-atk-l')),
                matching: find.byType(Row),
              )
              .first,
        );
        expect(
          left.right,
          lessThanOrEqualTo(rows.left + 0.5),
          reason: 'at ${width}px the left rating runs into the stat rows',
        );
        expect(
          right.left,
          greaterThanOrEqualTo(rows.right - 0.5),
          reason: 'at ${width}px the right rating runs into the stat rows',
        );
        expect(atk.width, greaterThan(0));
      }
    });

    testWidgets('and each rating sits under its OWN club', (tester) async {
      // Each figure lands dead centre under the name above it — that is the whole
      // reason both rows key off the same fixed gutter.
      //
      // Venue-agnostic on purpose: the HOME side is the left column, and which
      // of the two that is changes with the fixture. Pinning it to "ours is on
      // the left" would be testing the schedule, not the layout.
      await pumpCard(tester);
      final ourName = tester.getRect(
        find.byKey(const ValueKey('nm-name-ours')),
      );
      final theirName = tester.getRect(
        find.byKey(const ValueKey('nm-name-theirs')),
      );
      final left = tester.getRect(find.byKey(const ValueKey('nm-figure-left')));
      final right = tester.getRect(
        find.byKey(const ValueKey('nm-figure-right')),
      );
      final leftName = ourName.center.dx < theirName.center.dx
          ? ourName
          : theirName;
      final rightName = leftName == ourName ? theirName : ourName;

      expect(
        (left.center.dx - leftName.center.dx).abs(),
        lessThan(12),
        reason: 'the left rating is not under the club above it',
      );
      expect(
        (right.center.dx - rightName.center.dx).abs(),
        lessThan(12),
        reason: 'the right rating is not under the club above it',
      );
      expect(left.center.dx, lessThan(right.center.dx));
    });

    testWidgets('and the ratings sit BESIDE the ATK/DEF rows, not above', (
      tester,
    ) async {
      // The rating belongs outboard of its own stats because it IS those two
      // numbers — the split is position-weighted to land on it. Sat above them it
      // reads as a separate figure to take on trust.
      await pumpCard(tester);
      final figure = tester.getRect(
        find.byKey(const ValueKey('nm-figure-left')),
      );
      final atk = tester.getRect(find.byKey(const ValueKey('nm-stat-atk-l')));
      final def = tester.getRect(find.byKey(const ValueKey('nm-stat-def-l')));
      // Vertically level with the pair it flanks: its centre falls between them.
      expect(figure.center.dy, greaterThan(atk.top - 2));
      expect(figure.center.dy, lessThan(def.bottom + 2));
      // And OUTBOARD of them, not over them.
      expect(figure.right, lessThanOrEqualTo(atk.left + 0.5));
    });

    testWidgets('and the match quests ride on the card', (tester) async {
      // Not in the season popup: a match quest is an instruction for the game you
      // are about to press Play on.
      await pumpCard(tester);
      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
    });
  });

  group('THE MATCH QUESTS HEADER, IN THE THEME THAT SHIPS', () {
    // `lightModeProvider` defaults TRUE, so this whole file already runs in the
    // theme a player sees — which is why both of these were reported off it.

    testWidgets('THE HEADING IS NOT CUT OFF', (tester) async {
      // It flexed with an ellipsis, which was the least-bad answer while the
      // words "TOTAL REWARD" were also in the row. The label is gone and the
      // heading wraps instead: this is a column that can grow a line.
      await pumpCard(tester);
      final heading = tester.widget<Text>(
        find.text(t('quests.match').toUpperCase()),
      );
      expect(heading.overflow, isNot(TextOverflow.ellipsis));
      expect(heading.softWrap, isTrue);
      expect(heading.maxLines, isNull);
      // And the label it made room for is nowhere on the card.
      expect(find.text(t('quests.total_reward').toUpperCase()), findsNothing);
    });

    testWidgets('AND THE COIN FIGURES ARE GOLD, not the bronze', (
      tester,
    ) async {
      // `coinFigureInk` answers `gameGoldLight` — a deep bronze — because
      // `#FFD700` is 1.1:1 on a near-white CARD. This card is not paper: it is
      // glass over the pitch, so the hue stays and the contrast comes from a
      // dark backing instead. Reported as "the coins on the home page are a
      // horrible bronze colour".
      await pumpCard(tester, mutate: (s) {
        (s['quests'] as Map<String, dynamic>)['match'] = <String, dynamic>{
          'fixtureKey': null,
          'active': <dynamic>[],
        };
      });
      final figures = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.color == gameGold);
      expect(
        figures,
        isNotEmpty,
        reason: 'no money figure on the card is actually gold',
      );
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .where((t) => t.style?.color == gameGoldLight),
        isEmpty,
        reason: 'the bronze is for gold on paper, and this card is glass',
      );
      // The backing is what buys the contrast the hue no longer pays for.
      expect(figures.first.style!.shadows, isNotEmpty);
    });
  });
}
