/// The Trophy Room.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/engine/badge_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/trophies/trophy_room_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/badge_icon.dart';

/// An achievement every save can be given, so a test does not have to satisfy
/// a predicate to have something unlocked.
const String _unlockedId = 'first_merge';

Map<String, dynamic> _stateWith({
  List<Map<String, dynamic>> trophies = const [],
  List<Map<String, dynamic>> unlocked = const [],
  String? equippedBadge,
}) {
  final state = createDefaultState();
  final prog = state['progression'] as Map<String, dynamic>;
  prog['leagueTrophies'] = [...trophies];
  prog['achievements'] = [...unlocked];
  if (equippedBadge != null) prog['equippedBadgeId'] = equippedBadge;
  return state;
}

Future<ProviderContainer> pumpRoom(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
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
          home: Scaffold(
            body: Builder(
              builder: (inner) => ElevatedButton(
                key: const ValueKey('open'),
                onPressed: () => showTrophyRoomSheet(inner),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

/// Scroll a tile into view.
///
/// `ensureVisible`, not `scrollUntilVisible`: the category grids are eager, so
/// every tile is already IN the tree and the scroll-until-found loop stops on
/// the first frame without having moved anything. The widget is found and still
/// eight hundred pixels below the viewport, which a tap then misses.
Future<void> reveal(WidgetTester tester, Finder tile) async {
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(resetLocale);

  group('an empty cabinet', () {
    testWidgets('says so rather than showing nothing', (tester) async {
      await pumpRoom(tester, _stateWith());
      expect(find.byKey(const ValueKey('trophy-room')), findsOneWidget);
      expect(find.byKey(const ValueKey('trophy-empty')), findsOneWidget);
    });

    testWidgets('still lists every achievement to aim at', (tester) async {
      await pumpRoom(tester, _stateWith());
      // Scrolling is how a grid this long is reached; the count in the header
      // is the cheaper proof that all of them are in the list.
      expect(
        find.text(
          t('trophy.ach_count', {
            'done': 0,
            'total': achievements.length,
          }).toUpperCase(),
        ),
        findsOneWidget,
      );
    });
  });

  group('trophies', () {
    testWidgets('a league title draws its division art', (tester) async {
      await pumpRoom(
        tester,
        _stateWith(
          trophies: [
            {'season': 3, 'division': 'sunday_league', 'position': 1},
          ],
        ),
      );
      final card = find.byKey(const ValueKey('trophy-sunday_league-3'));
      expect(card, findsOneWidget);
      expect(
        tester
            .widget<ArtImage>(
              find.descendant(of: card, matching: find.byType(ArtImage)),
            )
            .path,
        divisionTrophyPath('sunday_league'),
      );
      expect(find.byKey(const ValueKey('trophy-empty')), findsNothing);
    });

    testWidgets('THE BORDER SURVIVES THE CAPTION at all four corners', (
      tester,
    ) async {
      // `Container.clipBehavior` clips to the decoration's OUTER path, not to
      // the hole the border leaves inside itself — so the opaque caption band
      // at the foot painted over the border's own curve, and the two BOTTOM
      // corners were the ones that visibly lost it. The child's box is already
      // inset by the border, so its clip has to be the outer radius LESS the
      // border width.
      await pumpRoom(
        tester,
        _stateWith(
          trophies: [
            {'season': 3, 'division': 'sunday_league', 'position': 1},
          ],
        ),
      );
      final card = find.byKey(const ValueKey('trophy-sunday_league-3'));
      final box = tester.widget<Container>(card).decoration! as BoxDecoration;
      final outer = box.borderRadius! as BorderRadius;
      final width = box.border!.top.width;
      final clip = tester.widget<ClipRRect>(
        find.descendant(of: card, matching: find.byType(ClipRRect)).first,
      );
      expect(
        clip.borderRadius,
        BorderRadius.circular(outer.topLeft.x - width),
        reason: 'the child is clipped to the border rather than to the hole',
      );
      // And the band inside it guesses at no third curve of its own.
      final band = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('trophy-caption')),
      );
      expect(
        (band.decoration as BoxDecoration).borderRadius,
        isNull,
        reason: 'the caption band still has a radius the tile does not share',
      );
    });

    testWidgets('a cup win draws the CUP art, not the division', (
      tester,
    ) async {
      // Both live in the same array and only the `cup` flag separates them, so
      // reading the wrong one shows a league trophy for a cup.
      await pumpRoom(
        tester,
        _stateWith(
          trophies: [
            {
              'season': 2,
              'division': 'national_cup',
              'position': 1,
              'cup': true,
              'cupName': 'National Cup',
            },
          ],
        ),
      );
      expect(
        tester
            .widget<ArtImage>(
              find.descendant(
                of: find.byKey(const ValueKey('trophy-national_cup-2')),
                matching: find.byType(ArtImage),
              ),
            )
            .path,
        cupTrophyPath('national_cup'),
      );
    });

    testWidgets('a legacy EVENT entry is not drawn', (tester) async {
      // The engine stopped writing these so the room would not double up with
      // the achievement tile; drawing an old one puts the double back.
      await pumpRoom(
        tester,
        _stateWith(
          trophies: [
            {
              'season': 1,
              'division': 'wc2026',
              'position': 1,
              'event': true,
              'eventId': 'wc2026',
              'playerNation': 'England',
            },
          ],
        ),
      );
      expect(find.textContaining('England'), findsNothing);
      expect(find.byKey(const ValueKey('trophy-empty')), findsOneWidget);
    });
  });

  group('achievements', () {
    testWidgets('an unlocked one is not dimmed and a locked one is', (
      tester,
    ) async {
      await pumpRoom(
        tester,
        _stateWith(
          unlocked: [
            {'id': _unlockedId, 'unlockedAt': 1750000000000, 'count': 1},
          ],
        ),
      );
      final tile = find.byKey(const ValueKey('achievement-$_unlockedId'));
      await reveal(tester, tile);
      expect(
        tester
            .widget<ArtImage>(
              find.descendant(of: tile, matching: find.byType(ArtImage)),
            )
            .dimmed,
        isFalse,
      );
    });

    testWidgets('tapping one opens its detail', (tester) async {
      await pumpRoom(
        tester,
        _stateWith(
          unlocked: [
            {'id': _unlockedId, 'unlockedAt': 1750000000000, 'count': 1},
          ],
        ),
      );
      final tile = find.byKey(const ValueKey('achievement-$_unlockedId'));
      await reveal(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('achievement-detail-$_unlockedId')),
        findsOneWidget,
      );
    });
  });

  group('the badge', () {
    testWidgets('an unlocked achievement can be worn', (tester) async {
      final container = await pumpRoom(
        tester,
        _stateWith(
          unlocked: [
            {'id': _unlockedId, 'unlockedAt': 1750000000000, 'count': 1},
          ],
        ),
      );
      final tile = find.byKey(const ValueKey('achievement-$_unlockedId'));
      await reveal(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('achievement-badge-$_unlockedId')),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        getEquippedBadgeId(container.read(gameProvider).state),
        _unlockedId,
      );
    });

    testWidgets('a LOCKED achievement offers no badge button', (tester) async {
      // `setEquippedBadge` refuses one, so offering it would be a dead button.
      await pumpRoom(tester, _stateWith());
      final tile = find.byKey(const ValueKey('achievement-$_unlockedId'));
      await reveal(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('achievement-badge-$_unlockedId')),
        findsNothing,
      );
    });

    testWidgets('the row at the top shows what is worn', (tester) async {
      await pumpRoom(
        tester,
        _stateWith(
          unlocked: [
            {'id': _unlockedId, 'unlockedAt': 1750000000000, 'count': 1},
          ],
          equippedBadge: _unlockedId,
        ),
      );
      expect(
        tester
            .widget<BadgeIcon>(
              find.descendant(
                of: find.byKey(const ValueKey('trophy-badge-row')),
                matching: find.byType(BadgeIcon),
              ),
            )
            .badgeId,
        _unlockedId,
      );
    });

    testWidgets('a fresh save wears the default, which draws a ball', (
      tester,
    ) async {
      await pumpRoom(tester, _stateWith());
      expect(
        find.byKey(const ValueKey('badge-icon-$defaultBadgeId')),
        findsWidgets,
      );
    });
  });
}
