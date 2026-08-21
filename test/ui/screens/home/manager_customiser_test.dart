/// Dressing the manager.
///
/// The wardrobe, the gates and the sanitiser were all here and there was no way
/// to reach any of it — eight axes, nineteen hair colours and six look packs
/// writing to a value the player could not edit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_customiser.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

import 'home_screen_test.dart' show pumpHome, settleSave;

void main() {
  tearDown(resetLocale);

  /// A phone, not the 800×600 default: the sheet is eight axes wide and five
  /// rows of chips deep, and both scroll.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> openCustomiser(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('dock-customise')));
    await tester.pumpAndSettle();
  }

  /// **Every axis is on screen at once now**, so this no longer has to go
  /// looking for the far ones behind a horizontal scroll — which is the whole
  /// complaint the wrap fixed.
  Future<void> openAxis(WidgetTester tester, String kind) async {
    final tab = find.byKey(ValueKey('customise-axis-$kind'));
    expect(tab, findsOneWidget, reason: 'no $kind tab');
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  Future<void> tapChip(WidgetTester tester, String kind, String id) async {
    final chip = find.byKey(ValueKey('customise-chip-$kind-$id'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('the pill opens the sheet', (tester) async {
    phone(tester);
    await pumpHome(tester);
    await openCustomiser(tester);
    expect(find.byKey(const ValueKey('manager-customiser')), findsOneWidget);
    // The rig that walks the touchline is the one previewing the look — one
    // source of truth means a look can never preview differently from how it
    // walks out.
    expect(find.byKey(const ValueKey('customise-preview')), findsOneWidget);
  });

  testWidgets('picking a part writes it to the save', (tester) async {
    phone(tester);
    final container = await pumpHome(tester);
    await openCustomiser(tester);

    await tapChip(tester, 'build', 'belly');
    await settleSave(tester);

    final club = container.read(gameProvider).state?['club'];
    final look = (club as Map<String, dynamic>)['managerAvatar'];
    expect((look as Map)['build'], 'belly');
  });

  testWidgets('hair colour is stored as the COLOUR, not the id', (
    tester,
  ) async {
    // The walker paints from the value and `hairColorId` reads it back; storing
    // the id would render a manager with no hair at all.
    phone(tester);
    final container = await pumpHome(tester);
    await openCustomiser(tester);

    await openAxis(tester, 'color');
    await tapChip(tester, 'color', 'ginger');
    await settleSave(tester);

    final club =
        container.read(gameProvider).state?['club'] as Map<String, dynamic>;
    expect((club['managerAvatar'] as Map)['hair'], hairColorValue('ginger'));
  });

  testWidgets('a locked part stays on the grid and says what unlocks it', (
    tester,
  ) async {
    // Hidden, the reward for building the Fan Zone or lifting a cup would be a
    // surprise nobody was working towards.
    phone(tester);
    final container = await pumpHome(tester);
    await openCustomiser(tester);
    await openAxis(tester, 'beard');

    final state = container.read(gameProvider).state;
    expect(isLookUnlocked(state, 'beard', 'stubble'), isFalse);
    final chip = find.byKey(const ValueKey('customise-chip-beard-stubble'));
    expect(chip, findsOneWidget, reason: 'a locked look was hidden, not gated');

    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining(t('customise.locked.fanzone', {'tier': 1})),
      findsOneWidget,
    );
    // And it did NOT get worn — the save is untouched, not written-and-reverted.
    final club =
        container.read(gameProvider).state?['club'] as Map<String, dynamic>;
    final look = club['managerAvatar'];
    expect(look is Map ? look['beard'] : null, isNot('stubble'));
  });

  group('what the sheet SHOWS', () {
    testWidgets('EVERY AXIS IS REACHABLE WITHOUT SCROLLING', (tester) async {
      // They were a horizontal strip, and eight tabs do not fit across a phone —
      // so Hat and Face lived off the right-hand edge with nothing to say they
      // were there. A row that runs out of the frame is not navigation.
      phone(tester);
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      await openCustomiser(tester);

      final strip = tester.getRect(
        find.byKey(const ValueKey('customise-axes')),
      );
      for (final axis in lookAxes) {
        final tab = find.byKey(ValueKey('customise-axis-${axis.kind}'));
        expect(tab, findsOneWidget, reason: '${axis.kind} is not in the tree');
        final box = tester.getRect(tab);
        expect(
          box.right,
          lessThanOrEqualTo(strip.right + 0.5),
          reason: '${axis.kind} hangs off the right-hand edge',
        );
      }
      await settleSave(tester);
    });

    testWidgets('and a choice is a PICTURE of itself, not a word', (
      tester,
    ) async {
      // A moustache described as "Moustache" is a list; a moustache drawn on his
      // face is a choice.
      phone(tester);
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      await openCustomiser(tester);
      await openAxis(tester, 'build');

      // An UNLOCKED one — a padlocked chip is a padlock, deliberately, and on a
      // fresh save every beard but `none` is behind a Fan Zone tier.
      final chip = find.byKey(const ValueKey('customise-chip-build-broad'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: chip, matching: find.byType(ManagerWalker)),
        findsOneWidget,
        reason: 'the build chip is still a word',
      );
      // The colour axes keep their swatch: a hair colour IS a colour, and a head
      // drawn to show one is a worse look at it.
      await openAxis(tester, 'color');
      final swatch = find.byKey(
        ValueKey('customise-chip-color-${hairColorIds.first}'),
      );
      await tester.ensureVisible(swatch);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: swatch, matching: find.byType(ManagerWalker)),
        findsNothing,
      );
      await settleSave(tester);
    });

    testWidgets('and he WALKS in here, on grass', (tester) async {
      // He used to stand still on the sheet's own surface, which is a figure in
      // a dressing room — and the thing being judged is how a look MOVES.
      phone(tester);
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      await openCustomiser(tester);
      expect(find.byKey(const ValueKey('customise-stage')), findsOneWidget);
      final preview = tester.widget<ManagerWalker>(
        find.byKey(const ValueKey('customise-preview')),
      );
      expect(preview.walking, isTrue, reason: 'he is standing still again');
      await settleSave(tester);
    });
  });
}
