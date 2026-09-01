/// Dressing the manager.
///
/// The wardrobe, the gates and the sanitiser were all here and there was no way
/// to reach any of it — eight axes, nineteen hair colours and six look packs
/// writing to a value the player could not edit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_customiser.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

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

  /// **THE CAMERA STEPS BACK.** He was 170 of the stage's 190, so the ground he
  /// is being dressed for was a strip either side of his shoulders — asked for
  /// as "the body needs to be slightly more zoomed out". The half that is easy
  /// to get wrong is the other one: `Align` centres the BOX, so a figure scaled
  /// down under a fixed alignment lifts off the grass by half of what came off
  /// his height.
  testWidgets('THE PREVIEW STANDS BACK, and stays on the grass', (
    tester,
  ) async {
    phone(tester);
    await pumpHome(tester);
    await openCustomiser(tester);
    final stage = tester.getRect(find.byKey(const ValueKey('customise-stage')));
    final grass = tester.getRect(find.byKey(const ValueKey('customise-grass')));
    final him = tester.getRect(find.byKey(const ValueKey('customise-preview')));

    // Air above his hat and turf in front of his boots.
    expect(him.height, lessThan(stage.height * 0.85));
    expect(him.top, greaterThan(stage.top + 12));

    // And his soles are on the ground rather than over it. The art carries
    // empty units under the figure — see [walkerFootOffset] — so the box's
    // bottom edge is not where he is standing.
    final soles = him.bottom - walkerFootOffset * (him.height / walkerHeight);
    expect(soles, greaterThan(grass.top));
    expect(soles, lessThan(grass.bottom));
    await settleSave(tester);
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

  testWidgets('AND `none` TAKES THE BEARD OFF, which is a pick like any other', (
    tester,
  ) async {
    // Reported from the couch: choosing none left the stubble on his jaw.
    phone(tester);
    final container = await pumpHome(tester);
    await openCustomiser(tester);
    // A beard he already has on. Written straight into the save, because
    // `stubble` itself is Fan-Zone gated and this is about taking one OFF.
    container.read(gameProvider).update((state) {
      final club = state['club'] as Map<String, dynamic>;
      club['managerAvatar'] = <String, dynamic>{
        ...normalizeAvatar(club['managerAvatar']),
        'beard': 'stubble',
      };
    });
    await settleSave(tester);
    Map<String, dynamic> lookNow() =>
        ((container.read(gameProvider).state!['club']
                as Map<String, dynamic>)['managerAvatar'])
            as Map<String, dynamic>;
    expect(lookNow()['beard'], 'stubble', reason: 'the save would not take it');

    await openAxis(tester, 'beard');

    await tapChip(tester, 'beard', 'none');
    await settleSave(tester);
    expect(lookNow()['beard'], 'none');
    // And nothing is drawn for it: the beard is the first layer over the head,
    // and on `none` there is no layer at all.
    final parts = managerPartsFor(
      lookNow(),
      kit: const Color(0xFF4CAF50),
      skin: const Color(0xFFEEBB8C),
      hair: const Color(0xFF3A2A1C),
    );
    expect(parts.overHead.where((l) => l.clipToFace), isEmpty);
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

    // **ON THE STAGE, not in a toast.** It was a toast because a Fan Zone lock
    // has nothing to sell — but a sentence about a beard, with the beard still
    // not on him, answers the wrong question. The bar shows the item and says
    // what it waits on, which is what was asked for; the CTA row is what a
    // pack lock adds, not what makes the bar worth raising.
    //
    // (Its ancestor was a `SnackBar`, which `ScaffoldMessenger.of` posted to
    // the Scaffold BEHIND this modal sheet — reported as a locked item doing
    // nothing at all. The bus fixed that; the bar answers the rest.)
    final said = <String>[];
    void listen(Object? line) => said.add('$line');
    on('toast:info', listen);
    addTearDown(() => off('toast:info', listen));

    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
    await tester.pump();
    expect(said, isEmpty, reason: 'it is shown now, not narrated');
    expect(find.byKey(const ValueKey('locked-look-offer')), findsOneWidget);
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('locked-look-progress')),
      ).data,
      t('customise.locked.fanzone', {'tier': 1}),
    );

    // Tried on, on the PREVIEW figure only.
    expect(
      tester
          .widget<ManagerWalker>(
            find.byKey(const ValueKey('customise-preview')),
          )
          .look?['beard'],
      'stubble',
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
      // **AND THE TREELINE STANDS ON THE GRASS.** It filled the stage
      // top-anchored, which put the drawing's own ground line below the bottom
      // edge and left its hedges cut off by the turf strip — shrubs growing out
      // of the ground rather than standing behind it, reported with a
      // screenshot. `cover` cannot fix that at any alignment; the art is PLACED
      // instead, the same way the penalty screen and Goalkeeper Practice lay
      // these four Kenney drawings behind their own ground.
      final art = tester.getRect(
        find.byKey(const ValueKey('customise-backdrop')).first,
      );
      final grass = tester.getRect(
        find.byKey(const ValueKey('customise-grass')),
      );
      // 0.62 is where the Kenney backdrops put their own ground line.
      expect(
        art.top + 0.62 * art.height,
        closeTo(grass.top, 0.5),
        reason: 'the horizon and the turf disagree',
      );
      // And it still leaves no gap round the box: the surplus goes off the top,
      // which is sky, and off the sides, which is more of the same treeline.
      expect(art.top, lessThanOrEqualTo(stage.top + 0.5));
      expect(art.left, lessThanOrEqualTo(stage.left + 0.5));
      expect(art.width, greaterThanOrEqualTo(stage.width - 0.5));
      expect(art.bottom, greaterThanOrEqualTo(grass.top - 0.5));
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

      // **AND THERE IS SKY OVER HIS HEAD.** He was drawn at the art's full
      // height in a stage only twenty points taller, so the crown sat fifteen
      // points off the top edge and the stage's treeline and sky had nowhere to
      // be. Reported as needing to be zoomed out. A tenth of the stage is the
      // floor; his box carries no empty art above him, so its top edge IS very
      // nearly the top of his hair.
      expect(
        walker.top - stage.top,
        greaterThan(stage.height * 0.1),
        reason: 'he fills the frame like a passport photo',
      );
      // But he is still the subject — a figure lost in a landscape is the
      // opposite mistake, and this stage is 190 points tall in total.
      expect(walker.height, greaterThan(stage.height * 0.7));
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

  group('WHAT THE CHIPS ARE CALLED', () {
    test('skin tones are NUMBERED, not printed as hex', () {
      // The grid asked for `customise.skin.<id>` where the id is the tone's
      // BASE COLOUR, so every chip fell through to the tidied id and the label
      // under the swatch read `#Eebb8c`. The catalogue has a key made for this
      // and nothing was calling it.
      expect(lookItemLabel('skin', skinTones.first.$1), t('customise.item.skin.tone', {'n': 1}));
      expect(lookItemLabel('skin', skinTones[2].$1), t('customise.item.skin.tone', {'n': 3}));
      expect(lookItemLabel('skin', skinTones.first.$1), isNot(contains('#')));
    });

    test('and the item axes find their own key prefix', () {
      // Not one scheme: build/outfit/emote live at `customise.<kind>.<id>` and
      // the rest at `customise.item.<kind>.<id>`. The port only tried the first,
      // so five of the eight axes showed a tidied id — "Sunhat" for "Sun Hat".
      expect(lookItemLabel('hat', 'sunhat'), t('customise.item.hat.sunhat'));
      expect(lookItemLabel('color', 'ginger'), t('customise.item.color.ginger'));
      expect(lookItemLabel('build', 'lean'), t('customise.build.lean'));
      expect(lookItemLabel('emote', 'fistpump'), t('customise.emote.fistpump'));
    });

    test('an id with no string still comes back readable', () {
      expect(lookItemLabel('hat', 'nosuchhat'), 'Nosuchhat');
    });
  });

  group('CELEBRATIONS ARE REACHABLE', () {
    test('the wardrobe has an emote axis, and it equips nothing', () {
      // Nine gestures translated in ten catalogues with `lookAxes` stopping at
      // `face`, so none of it could be reached. `pickGesture` has always gated
      // the idle rota on owning them.
      final emote = lookAxes.where((a) => a.kind == 'emote');
      expect(emote, hasLength(1), reason: 'the Celebrations tab is missing');
      expect(emote.first.field, isEmpty, reason: 'an emote is not worn');
      expect(emote.first.labelKey, 'customise.tab.emote');
    });

    testWidgets('and its chips are the gestures', (tester) async {
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'emote');
      expect(
        find.byKey(const ValueKey('customise-chip-emote-fistpump')),
        findsOneWidget,
      );
    });

    testWidgets('and each chip shows ITS OWN celebration', (tester) async {
      // **Sixteen copies of the same picture.** The axis has no field — an
      // emote is not worn — so the look handed to every chip was identical and
      // the grid told the player nothing about which one they were picking. A
      // gesture is a POSE, not a garment, so the thing to vary is the rig's
      // angles: see `LookPreview.pose`.
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'emote');

      final poses = tester
          .widgetList<LookPreview>(find.byType(LookPreview))
          .map((p) => p.pose)
          .toList();
      expect(poses, isNotEmpty, reason: 'no chips on the Celebrations axis');
      expect(
        poses.every((p) => p != null),
        isTrue,
        reason: 'a celebration chip with no pose is the walking figure again',
      );
      expect(
        poses.toSet(),
        hasLength(poses.length),
        reason: 'two celebrations drew the same figure',
      );
    });

    testWidgets('and a WORN axis holds no pose', (tester) async {
      // The pose is for the axis that swaps no garment. Every other one varies
      // the look itself, and a held pose there would freeze the same figure
      // into all of them.
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      final poses = tester
          .widgetList<LookPreview>(find.byType(LookPreview))
          .map((p) => p.pose);
      expect(poses, isNotEmpty);
      expect(poses.every((p) => p == null), isTrue);
    });
  });

  group('A LOCKED CHIP THAT A VIDEO CAN OPEN', () {
    test('is told apart from one nothing can', () {
      final state = createDefaultState();
      // A Fan Zone tier is a refusal: there is nothing to offer for it.
      expect(isLookUnlocked(state, 'beard', 'stubble'), isFalse);
      expect(isPackLocked(state, 'beard', 'stubble'), isFalse);
      // A pack item is an offer, and every one of them is one video away.
      final packItem = lookPacks.first.items.first;
      final parts = packItem.split(':');
      expect(isLookUnlocked(state, parts[0], parts[1]), isFalse);
      expect(isPackLocked(state, parts[0], parts[1]), isTrue);
    });

    /// **IT IS SHOWN, AND THEN OFFERED.** A tap used to fire a rewarded video
    /// on the spot: nothing said what was about to happen, and nothing showed
    /// the item. Reported from the couch twice — once as a locked item doing
    /// nothing, and once as an ad item never saying it was an ad item.
    testWidgets('TRIES THE ITEM ON and offers both routes', (tester) async {
      phone(tester);
      final container = await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      // A hat that is in a pack, which is the only lock a video can open.
      final locked = lookPacks
          .expand((p) => p.items)
          .map((i) => i.split(':'))
          .firstWhere((parts) => parts[0] == 'hat');

      await tapChip(tester, 'hat', locked[1]);
      final bar = find.byKey(const ValueKey('locked-look-offer'));
      expect(bar, findsOneWidget);
      // Both routes, in the shop's own colour language.
      expect(find.byKey(const ValueKey('locked-look-watch')), findsOneWidget);
      expect(find.byKey(const ValueKey('locked-look-buy')), findsOneWidget);
      // And it names the item and the pack it is in — the chip behind it
      // carries the same label, hence `descendant`.
      expect(
        find.descendant(of: bar, matching: find.text(lookItemLabel('hat', locked[1]))),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('locked-look-progress')), findsOneWidget);
      // **ON THE STAGE HE WALKS ACROSS**, not in a sheet over it — asked for
      // directly, and the reason is that the thing being sold is on the figure
      // the sheet would have covered.
      final stage = tester.getRect(find.byKey(const ValueKey('customise-stage')));
      final offer = tester.getRect(bar);
      expect(offer.left, greaterThanOrEqualTo(stage.left - 1));
      expect(offer.right, lessThanOrEqualTo(stage.right + 1));
      expect(offer.bottom, closeTo(stage.bottom, 1));

      // **WORN ON THE PREVIEW, and nowhere else.** Nothing reaches the save
      // until it is paid for, and the chip must not read as selected.
      final preview = tester.widget<ManagerWalker>(
        find.byKey(const ValueKey('customise-preview')),
      );
      expect(preview.look?['hat'], locked[1]);
      expect(
        isLookUnlocked(container.read(gameProvider).state, 'hat', locked[1]),
        isFalse,
        reason: 'a locked item was given away by looking at it',
      );

      // Taken off again when the offer closes.
      await tester.tap(find.byKey(const ValueKey('locked-look-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('locked-look-offer')), findsNothing);
      final after = tester.widget<ManagerWalker>(
        find.byKey(const ValueKey('customise-preview')),
      );
      expect(after.look?['hat'], isNot(locked[1]));
      await settleSave(tester);
    });

    testWidgets('AND A LOCKED CELEBRATION PLAYS while it is offered', (
      tester,
    ) async {
      // An emote is not worn — owning one is what puts it in the touchline
      // rota — so there is nothing to try on. It plays on the figure instead,
      // which is the only way to show what one actually is, and the same bar
      // rises under him.
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'emote');
      final locked = lookPacks
          .expand((p) => p.items)
          .map((i) => i.split(':'))
          .firstWhere((parts) => parts[0] == 'emote');

      await tapChip(tester, 'emote', locked[1]);
      expect(find.byKey(const ValueKey('locked-look-offer')), findsOneWidget);
      expect(
        tester
            .widget<ManagerWalker>(
              find.byKey(const ValueKey('customise-preview')),
            )
            .gesture,
        isNotNull,
        reason: 'nothing showed what the celebration is',
      );
      await settleSave(tester);
    });

    /// **TAPPING SOMETHING ELSE ANSWERS THE OFFER.** Asked for from the couch:
    /// the ✕ was the only way out, so a player who moved on was left looking at
    /// an item they do not own under a bar selling it.
    testWidgets('picking an owned item takes the try-on off', (tester) async {
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      final locked = lookPacks
          .expand((p) => p.items)
          .map((i) => i.split(':'))
          .firstWhere((parts) => parts[0] == 'hat');

      await tapChip(tester, 'hat', locked[1]);
      expect(find.byKey(const ValueKey('locked-look-offer')), findsOneWidget);

      // Bare-headed is the one hat every save owns.
      await tapChip(tester, 'hat', 'none');
      expect(find.byKey(const ValueKey('locked-look-offer')), findsNothing);
      expect(
        tester
            .widget<ManagerWalker>(
              find.byKey(const ValueKey('customise-preview')),
            )
            .look?['hat'],
        isNot(locked[1]),
        reason: 'the locked hat stayed on after the player moved on',
      );
      await settleSave(tester);
    });

    /// The same for a celebration, which equips nothing — so the offer has to
    /// be cleared by the PLAY rather than by a write to the save.
    testWidgets('and so does playing another celebration', (tester) async {
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'emote');
      final locked = lookPacks
          .expand((p) => p.items)
          .map((i) => i.split(':'))
          .firstWhere((parts) => parts[0] == 'emote');

      await tapChip(tester, 'emote', locked[1]);
      expect(find.byKey(const ValueKey('locked-look-offer')), findsOneWidget);

      await tapChip(tester, 'emote', gestures.first.id);
      expect(find.byKey(const ValueKey('locked-look-offer')), findsNothing);
      await settleSave(tester);
    });

    /// The row variant is for a list line. These two are the only controls on
    /// the stage — "the buttons need a little more height to match others".
    testWidgets('the offer wears full-size buttons', (tester) async {
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'hat');
      final locked = lookPacks
          .expand((p) => p.items)
          .map((i) => i.split(':'))
          .firstWhere((parts) => parts[0] == 'hat');

      await tapChip(tester, 'hat', locked[1]);
      for (final key in ['locked-look-watch', 'locked-look-buy']) {
        final button = find.byKey(ValueKey(key));
        if (button.evaluate().isEmpty) continue;
        expect(tester.widget<StoreButton>(button).small, isFalse);
        expect(tester.getSize(button).height, greaterThan(30));
      }
      await settleSave(tester);
    });

    testWidgets('and a lock nothing can open still SHOWS the item', (
      tester,
    ) async {
      // A Fan Zone tier has nothing to sell and nothing to watch — so the bar
      // drops its buttons rather than the whole bar. Two dead CTAs would be
      // worse than the sentence; so is the sentence on its own, which is what
      // this used to be.
      phone(tester);
      await pumpHome(tester);
      await openCustomiser(tester);
      await openAxis(tester, 'beard');

      await tapChip(tester, 'beard', 'stubble');
      expect(find.byKey(const ValueKey('locked-look-offer')), findsOneWidget);
      expect(find.byKey(const ValueKey('locked-look-watch')), findsNothing);
      expect(find.byKey(const ValueKey('locked-look-buy')), findsNothing);
      expect(
        tester.widget<Text>(
          find.byKey(const ValueKey('locked-look-progress')),
        ).data,
        t('customise.locked.fanzone', {'tier': 1}),
      );
      await settleSave(tester);
    });
  });
}
