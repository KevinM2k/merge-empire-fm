/// Every path the resolver can produce names a file that is actually bundled.
///
/// This is the test that earns its keep. A path is a string built from an id, a
/// tier and a suffix, so a renamed category or a tier past the generated range
/// fails SILENTLY — `errorBuilder` swaps in the fallback and the screen looks
/// fine, just wrong, forever. Reading the directory is the only way to notice.
///
/// It reads `assets/` off disk rather than through `rootBundle` deliberately:
/// what is on disk is what `pubspec.yaml` ships, and a file present but
/// unregistered is the other half of the same bug — covered below.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';

bool _exists(String path) => File(path).existsSync();

void main() {
  group('the artwork every screen asks for is on disk', () {
    test('a card, for every definition and every variant', () {
      final missing = <String>{};
      for (final def in players) {
        for (var v = 0; v < variants.length; v++) {
          final path = playerImagePath(def.position, def.tier, v);
          if (!_exists(path)) missing.add(path);
        }
      }
      expect(missing, isEmpty);
    });

    test('a club tile, for every category and every tier', () {
      final missing = <String>{};
      for (final category in AssetCategory.all) {
        for (var tier = 1; tier <= maxClubArtTier; tier++) {
          final path = clubAssetImagePath(category, tier);
          if (!_exists(path)) missing.add(path);
        }
      }
      expect(missing, isEmpty);
    });

    test('a stadium hero, for every tier', () {
      for (var tier = 1; tier <= maxClubArtTier; tier++) {
        expect(_exists(stadiumBackgroundPath(tier)), isTrue, reason: '$tier');
      }
    });

    test('a trophy, for every division and every cup', () {
      for (final division in divisions) {
        expect(
          _exists(divisionTrophyPath(division.id)),
          isTrue,
          reason: division.id,
        );
      }
      for (final cup in cups) {
        expect(_exists(cupTrophyPath(cup.id)), isTrue, reason: cup.id);
      }
    });

    test('an achievement tile, for every achievement', () {
      final missing = [
        for (final a in achievements)
          if (!_exists(achievementArtPath(a.id))) a.id,
      ];
      expect(missing, isEmpty);
    });
  });

  group('a tier past the generated range reuses the top one', () {
    // The JS clamps with `Math.min(tier, 8)`. Without it a club that reaches a
    // ninth tier loses its artwork at exactly the moment it earned it.
    test('rather than naming a file that does not exist', () {
      expect(
        clubAssetImagePath(AssetCategory.stadium, 99),
        clubAssetImagePath(AssetCategory.stadium, maxClubArtTier),
      );
      expect(stadiumBackgroundPath(99), stadiumBackgroundPath(maxClubArtTier));
      // And a tier of zero — an unowned facility asked for at its real tier —
      // reads as tier one rather than falling off the bottom.
      expect(
        clubAssetImagePath(AssetCategory.stadium, 0),
        clubAssetImagePath(AssetCategory.stadium, 1),
      );
    });
  });

  group('gender', () {
    test('picks the file the name pool would agree with', () {
      // Card art and card name are drawn from the same predicate. If these two
      // ever disagree a female player gets a male portrait, which is the one
      // art bug a player would definitely report.
      for (var v = 0; v < variants.length; v++) {
        final path = playerImagePath('GK', 1, v);
        expect(path.endsWith(isVariantFemale(v) ? '_f.png' : '_m.png'), isTrue);
      }
    });
  });

  group('pubspec ships what the resolver names', () {
    test('every art directory is registered', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final dir in const [
        'assets/players/',
        'assets/club/',
        'assets/bg/',
        'assets/trophies/',
        'assets/penalty/',
        'assets/whack/',
        'assets/ui/',
        'assets/audio/',
      ]) {
        expect(pubspec.contains('- $dir'), isTrue, reason: dir);
      }
    });
  });
}
