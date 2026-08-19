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
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<ProviderContainer> pumpCard(
  WidgetTester tester, {
  void Function(Map<String, dynamic>)? mutate,
  double width = 360,
}) async {
  final state = createDefaultState();
  mutate?.call(state);

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

void main() {
  group('the next-match card', () {
    testWidgets('draws at all, without throwing', (tester) async {
      await pumpCard(tester);
      expect(find.byKey(const ValueKey('next-match-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
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
        final left = tester.getRect(find.byKey(const ValueKey('nm-figure-left')));
        final right = tester.getRect(
          find.byKey(const ValueKey('nm-figure-right')),
        );
        final atk = tester.getRect(find.byKey(const ValueKey('nm-stat-atk-l')));
        final rows = tester.getRect(
          find.ancestor(
            of: find.byKey(const ValueKey('nm-stat-atk-l')),
            matching: find.byType(Row),
          ).first,
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
      final ourName = tester.getRect(find.byKey(const ValueKey('nm-name-ours')));
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
}
