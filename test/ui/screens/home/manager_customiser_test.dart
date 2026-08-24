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
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
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
      // Two copies of it, because it travels past him.
      expect(
        find.byKey(const ValueKey('customise-backdrop')),
        findsNWidgets(2),
        reason: 'the preview is still flat colour behind him',
      );
      // **AND IT FILLS THE STAGE.** At 86% of the height there was a hard edge
      // across it where the picture stopped and the sheet's own sky took over —
      // two skies meeting, which reads as the image being cut off.
      final art = tester.getRect(
        find.byKey(const ValueKey('customise-backdrop')).first,
      );
      expect(art.top, closeTo(stage.top, 0.5));
      expect(art.bottom, closeTo(stage.bottom, 0.5));
      // And the stage carries the same side margins as the controls under it.
      expect(stage.left, greaterThanOrEqualTo(10));
      expect(stage.right, lessThanOrEqualTo(box.right + 0.5));

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

    testWidgets('AND THE GRASS IS ACTUALLY THERE', (tester) async {
      // It was in the tree and painted nothing: `FractionallySizedBox` with a
      // height factor and no width factor passes the incoming width constraint
      // through, and under an `Align` that is LOOSE — so an empty
      // `DecoratedBox` sized itself to zero and he walked in the sky.
      phone(tester);
      final container = await pumpHome(tester);
      addTearDown(container.dispose);
      await openCustomiser(tester);

      final stage = tester.getRect(
        find.byKey(const ValueKey('customise-stage')),
      );
      final walker = tester.getRect(
        find.byKey(const ValueKey('customise-preview')),
      );
      final grass = tester.getRect(
        find.byKey(const ValueKey('customise-grass')),
      );
      expect(grass.width, stage.width, reason: 'a strip with no width');
      expect(grass.bottom, stage.bottom);
      expect(
        walker.bottom,
        greaterThan(grass.top),
        reason: 'his feet are above the ground',
      );
      await settleSave(tester);
    });
  });

  testWidgets('THE GRID IS NOT BUILT ON THE FRAME THE SHEET OPENS', (
    tester,
  ) async {
    // Measured on the tap: 209ms on the frame the button is pressed and 23ms
    // for everything after it, which is the whole of "the customise button
    // comes up laggy" — one build twelve frames long while the sheet is trying
    // to slide up.
    //
    // The grid is the expensive half and the half nobody is looking at yet:
    // twenty chips, each a full `ManagerWalker` rig, measured at ~60ms together
    // against ~18ms for an empty grid of the same shape. Holding it back one
    // frame took the opening frame to 107ms. The chips are sixteen
    // milliseconds late, which is not a wait.
    phone(tester);
    await pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('dock-customise')));
    await tester.pump();

    // The sheet is there, with its header and its stage.
    expect(find.byKey(const ValueKey('manager-customiser')), findsOneWidget);
    expect(find.byKey(const ValueKey('customise-preview')), findsOneWidget);
    // And no chip rigs in it yet.
    final grid = find.byKey(ValueKey('customise-grid-${lookAxes.first.kind}'));
    expect(
      grid,
      findsNothing,
      reason: 'the grid was built on the opening frame after all',
    );

    // One frame later, they are there.
    await tester.pumpAndSettle();
    expect(grid, findsOneWidget);
  });

  /// **THE VIDEO ROUTE, which had no surface at all.** `grantLookItem`'s own
  /// comment calls it the rewarded-video reward and nothing in `lib/` called
  /// it, so every locked chip in this grid could do exactly one thing: name
  /// what it was waiting on. Half the wardrobe was waiting on a video nobody
  /// could watch.
  group('unlocking a cosmetic with a video', () {
    /// A seam that answers [outcome] to every placement, and records what it
    /// was asked for — the placement matters, because the frequency cap is per
    /// AD UNIT and hats must not spend energy's budget.
    ({List<String> asked, RewardedAds ads}) fakeAds(AdOutcome outcome) {
      final asked = <String>[];
      return (asked: asked, ads: _FakeAds(outcome, asked));
    }

    testWidgets('a chip in a pack offers a video; a cup exclusive does not', (
      tester,
    ) async {
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'hat');

      // `hat:tophat` is in `pack_legend` — a video buys it.
      await tester.ensureVisible(
        find.byKey(const ValueKey('customise-chip-hat-tophat')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('customise-chip-hat-tophat')),
          matching: find.byKey(const ValueKey('customise-chip-video')),
        ),
        findsOneWidget,
        reason: 'no ▶ on a hat a video would hand over',
      );

      // `hat:diamond` is the World Club Cup's. It keeps its padlock: it is
      // worthless the moment a video can buy it.
      await tester.ensureVisible(
        find.byKey(const ValueKey('customise-chip-hat-diamond')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('customise-chip-hat-diamond')),
          matching: find.byKey(const ValueKey('customise-chip-video')),
        ),
        findsNothing,
        reason: 'the crown was on offer',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('customise-chip-hat-diamond')),
          matching: find.byIcon(Icons.lock),
        ),
        findsOneWidget,
      );
    });

    testWidgets('watching one grants it, spends a slot and WEARS it', (
      tester,
    ) async {
      phone(tester);
      final fake = fakeAds(AdOutcome.rewarded);
      final container = await pumpHome(
        tester,
        overrides: [rewardedAdsProvider.overrideWithValue(fake.ads)],
      );
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      await tapChip(tester, 'hat', 'tophat');
      await settleSave(tester);

      final state = container.read(gameProvider).state!;
      expect(isLookUnlocked(state, 'hat', 'tophat'), isTrue);
      expect(
        recentPackAds(state).length,
        1,
        reason: 'the grant landed without spending the slot',
      );
      // Its own unit, not energy's — the cap is per ad unit.
      expect(fake.asked, ['cosmetic_pack']);
      // And it is being worn, which is the whole feedback: there is no shipped
      // key for "unlocked!" and the catalogues are generated.
      final club = state['club'] as Map<String, dynamic>;
      expect((club['managerAvatar'] as Map)['hat'], 'tophat');
    });

    testWidgets('a video that will not fill grants nothing and says so', (
      tester,
    ) async {
      phone(tester);
      final fake = fakeAds(AdOutcome.unavailable);
      final container = await pumpHome(
        tester,
        overrides: [rewardedAdsProvider.overrideWithValue(fake.ads)],
      );
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      await tapChip(tester, 'hat', 'tophat');
      await settleSave(tester);

      final state = container.read(gameProvider).state!;
      expect(isLookUnlocked(state, 'hat', 'tophat'), isFalse);
      expect(
        recentPackAds(state),
        isEmpty,
        reason: 'a video that never played took a slot',
      );
      expect(find.text(t('toast.ad_unavailable')), findsOneWidget);
    });

    testWidgets('one the player closed early takes nothing and says nothing', (
      tester,
    ) async {
      phone(tester);
      final fake = fakeAds(AdOutcome.dismissed);
      final container = await pumpHome(
        tester,
        overrides: [rewardedAdsProvider.overrideWithValue(fake.ads)],
      );
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      await tapChip(tester, 'hat', 'tophat');
      await settleSave(tester);

      final state = container.read(gameProvider).state!;
      expect(isLookUnlocked(state, 'hat', 'tophat'), isFalse);
      expect(recentPackAds(state), isEmpty);
      // Backing out is a decision the player was told the terms of, so it is
      // not an error and does not get a line.
      expect(find.text(t('toast.ad_unavailable')), findsNothing);
    });

    testWidgets('a spent cap shows the countdown instead of the ▶', (
      tester,
    ) async {
      phone(tester);
      final now = DateTime.now().millisecondsSinceEpoch;
      await pumpHome(
        tester,
        mutate: (s) => s['ads'] = {
          'packUnlocks': [
            for (var i = 0; i < adPackLimit; i++) now - (i + 1) * 1000,
          ],
        },
      );
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      await tester.ensureVisible(
        find.byKey(const ValueKey('customise-chip-hat-tophat')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('customise-chip-hat-tophat')),
          matching: find.byKey(const ValueKey('customise-chip-wait')),
        ),
        findsOneWidget,
        reason: 'the cap was spent and the chip still offered a video',
      );
    });
  });
}

/// A rewarded-ad seam with a fixed answer, recording every placement asked for.
class _FakeAds implements RewardedAds {
  _FakeAds(this.outcome, this.asked);

  final AdOutcome outcome;
  final List<String> asked;

  @override
  Future<AdOutcome> show(String placement) async {
    asked.add(placement);
    return outcome;
  }

  @override
  void prepare(String placement) {}
}
