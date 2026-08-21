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
    await tester.tap(find.byKey(const ValueKey('customise-axis-picker')));
    await tester.pumpAndSettle();
    final item = find.byKey(ValueKey('customise-axis-$kind')).last;
    expect(item, findsOneWidget, reason: 'no $kind entry in the picker');
    await tester.tap(item);
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
    testWidgets('THE AXES ARE ONE CONTROL, not eight stacked buttons', (
      tester,
    ) async {
      // Wrapped, eight tabs took two lines of little buttons under each other —
      // which fits and reads as a pile. One picker naming the part you are on is
      // a control; the same idiom as the Player Index's filters.
      phone(tester);
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      await openCustomiser(tester);

      final picker = find.byKey(const ValueKey('customise-axis-picker'));
      expect(picker, findsOneWidget);
      // ONE line. Two rows of chips came to about sixty; a single control is
      // well under that, and the room goes to the wardrobe.
      final box = tester.getRect(picker);
      expect(box.height, lessThan(52));
      // But a real tap target rather than the height of a word: `isDense`
      // shrink-wraps a dropdown to its text.
      expect(box.height, greaterThan(36));
      // And clear of the stage above it, so it reads as the control under the
      // picture rather than as part of it.
      final stage = tester.getRect(
        find.byKey(const ValueKey('customise-stage')),
      );
      expect(box.top - stage.bottom, greaterThanOrEqualTo(10));

      // He stands against a drawn horizon rather than a bare wash of colour.
      expect(
        find.byKey(const ValueKey('customise-backdrop')),
        findsOneWidget,
        reason: 'the preview is still flat colour behind him',
      );

      // And every part is still reachable through it.
      for (final axis in lookAxes) {
        await openAxis(tester, axis.kind);
        expect(
          find.byKey(ValueKey('customise-grid-${axis.kind}')),
          findsOneWidget,
          reason: '${axis.kind} could not be opened',
        );
      }
      await settleSave(tester);
    });

    testWidgets('EVERY OPTION SAYS WHAT IT IS', (tester) async {
      // A grid of thumbnails does not tell you which one is the beanie. The name
      // was on the control for a screen reader and nowhere for anybody else.
      phone(tester);
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      await openCustomiser(tester);
      await openAxis(tester, 'build');

      final chip = find.byKey(const ValueKey('customise-chip-build-broad'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: chip, matching: find.text('Broad')),
        findsOneWidget,
        reason: 'the option is a picture with no name under it',
      );
      await settleSave(tester);
    });

    testWidgets('AND A LOCKED ONE STILL SHOWS WHAT IT WOULD LOOK LIKE', (
      tester,
    ) async {
      // Locked means you cannot pick it, not that you cannot see it. The padlock
      // REPLACED the preview, so the reward for building the Fan Zone was a
      // surprise — which is the opposite of what keeping it on the grid was for.
      phone(tester);
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      await openCustomiser(tester);
      await openAxis(tester, 'beard');

      // On a fresh save every beard but `none` is behind a Fan Zone tier.
      final chip = find.byKey(const ValueKey('customise-chip-beard-stubble'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: chip, matching: find.byType(ManagerWalker)),
        findsOneWidget,
        reason: 'a locked option is still a padlock instead of a preview',
      );
      // With the padlock still on it, because it is still locked.
      expect(
        find.descendant(of: chip, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
        reason: 'nothing says it is locked',
      );
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
