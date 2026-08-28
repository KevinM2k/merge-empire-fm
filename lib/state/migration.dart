/// Save migration, ported from `migrate()` in
/// `../merge-empire-fc/src/utils/storage.js`.
///
/// This is the other half of save compatibility. It is not a chain of
/// version-stepped transforms but a long sequence of defensive back-fills, most
/// of them unconditional and idempotent, plus a handful of one-time repairs
/// guarded by their own flags. Running it twice must be a no-op.
///
/// Two RNGs are in play and the split is deliberate. The 2026 rating-band
/// reseed draws from the SEEDED stream (it is gameplay randomness and must
/// advance the shared sequence); the pyramid attack-bias re-roll and the
/// attack-ratio back-fill use unseeded randomness, matching `Math.random()` in
/// the JS. Unifying them would shift every subsequent gameplay draw.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/season_end.dart' show prestigeMultiplierFor;
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/migration_progression.dart';
import 'package:merge_empire_fc/util/player_name.dart';
import 'package:merge_empire_fc/util/time.dart';

/// What the tutorial pays, for the one-time back-fill.
///
/// Deliberately a copy rather than an import: migration is the boot path, and
/// the gem engine reaches for the event bus and analytics, which is a cycle
/// waiting to happen for one number.
const int tutorialGems = 5;

/// Unseeded randomness, matching the JS `Math.random()` calls in this file.
math.Random _rng = math.Random();

/// The shared unseeded generator, read by the progression half of the
/// migration so both use one instance.
math.Random get migrationRandom => _rng;

/// Test seam.
void setMigrationRandom(math.Random rng) => _rng = rng;

void resetMigrationRandom() => _rng = math.Random();

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Reads a nested map, creating it when absent or the wrong type.
Map<String, dynamic> _ensureMap(Map<String, dynamic> parent, String key) {
  final existing = parent[key];
  if (existing is Map<String, dynamic>) return existing;
  final fresh = <String, dynamic>{};
  parent[key] = fresh;
  return fresh;
}

num? _num(Object? v) => v is num ? v : null;

/// Migrates a decoded save to the current schema, mutating and returning it.
///
/// Returns null for a save with no version, or one written by a NEWER build —
/// those must be preserved untouched rather than downgraded.
Map<String, dynamic>? migrate(Map<String, dynamic>? data) {
  if (data == null) return null;
  final version = _num(data['version']);
  if (version == null || version == 0) return null;
  if (version > saveVersion) return null;

  _sanitiseLoadBoundary(data);
  _migrateGridCards(data);
  _migrateClubAssets(data);
  _migrateSquad(data);
  _migrateSettings(data);
  _migrateTutorialAndTips(data);
  _migrateEconomy(data);
  _migrateClub(data);
  _migrateStats(data);
  _migrateBoosts(data);
  migrateProgression(data);
  reseedRatingBands(data);
  reseedFatigue(data);
  backfillPrestigePoints(data);
  scrubTeamNames(data);
  migrateDeadlineDay(data);
  migrateEvents(data);
  migrateGemLedger(data);
  migrateRatingPrompt(data);
  migrateLeaderboard(data);
  migrateRatios(data);
  migrateAgeVerification(data);
  migrateWeather(data);
  backfillCareerCounters(data);
  migrateQuests(data);

  return data;
}

// ── Defensive sanitisation at the load boundary ─────────────────────────────
//
// A corrupt local save, or a tampered or older-build cloud doc, can carry
// wrong-typed collections (a non-list `cells` breaks every loop below) or
// non-finite economy numbers (a NaN that poisons every subsequent income tick
// and can never recover). Normalise both so a single bad payload cannot brick
// the save. Legitimate data is unaffected.
void _sanitiseLoadBoundary(Map<String, dynamic> data) {
  final grid = _map(data['grid']);
  if (grid != null && grid['cells'] is! List) grid['cells'] = <dynamic>[];

  final clubAssets = _map(data['clubAssets']);
  if (clubAssets != null &&
      clubAssets['cells'] != null &&
      clubAssets['cells'] is! List) {
    clubAssets['cells'] = <dynamic>[];
  }

  final resources = _map(data['resources']);
  if (resources != null) {
    final coins = _num(resources['fanCoins']);
    resources['fanCoins'] = (coins != null && coins.isFinite && coins >= 0)
        ? coins
        : 0;

    // Gems are permanent and can only be earned or bought, so a NaN or
    // negative would either brick a purchase or mint currency.
    final gems = _num(resources['gems']);
    resources['gems'] = (gems != null && gems.isFinite && gems > 0)
        ? gems.floor()
        : 0;

    // A save with no coins AND no players is a broken start, not a hard-earned
    // bankruptcy — hand back the starting float.
    if (resources['fanCoins'] == 0) {
      final cells = grid?['cells'];
      final hasPlayers = cells is List && cells.any((c) => c != null);
      if (!hasPlayers) resources['fanCoins'] = startingCoins;
    }
  }
}

// ── Grid cards ──────────────────────────────────────────────────────────────
void _migrateGridCards(Map<String, dynamic> data) {
  final grid = _map(data['grid']);
  final cells = grid?['cells'];
  if (grid == null || cells is! List) return;

  final progression = _map(data['progression']);
  final maxSeasons = _num(progression?['seasonCount'])?.toInt() ?? 1;
  final nowMs = now();

  for (var i = 0; i < cells.length; i++) {
    final card = CardInstance.from(cells[i]);
    if (card == null) {
      cells[i] = null;
      continue;
    }
    final raw = card.raw;

    // Back-fill a portrait variant so pre-variant cards stop looking identical.
    raw['variant'] ??= _rng.nextInt(playerVariants);

    final def = getPlayerDef(card.definitionId);

    // Back-fill displayName so a card whose newly-assigned variant is female
    // gets a female name.
    if (raw['displayName'] == null && def != null) {
      raw['displayName'] = pickDisplayName(
        def.position,
        math.max(0, def.tier - 1),
        female: isVariantFemale((raw['variant'] as num).toInt()),
      );
    }

    // Player-set names are rendered into unescaped templates, so re-run the
    // whitelist on load: a save can arrive from cloud sync or a hand-edited
    // store, and this keeps "sanitised" an invariant of the state rather than
    // something only the rename sheet enforces. A name sanitising to nothing
    // is dropped, falling back to the rolled name.
    if (raw['customName'] != null) {
      final clean = sanitizePlayerName(raw['customName']);
      if (clean.length >= playerNameMin) {
        raw['customName'] = clean;
      } else {
        raw.remove('customName');
      }
    }

    raw['form'] ??= 0;

    // Back-fill career stats for pre-stats saves.
    final stats = _map(raw['stats']);
    if (stats == null) {
      raw['stats'] = <String, dynamic>{
        'goals': 0,
        'assists': 0,
        'tackles': 0,
        'saves': 0,
        'matchesPlayed': 0,
      };
    } else {
      for (final k in [
        'goals',
        'assists',
        'tackles',
        'saves',
        'matchesPlayed',
      ]) {
        if (stats[k] is! num) stats[k] = 0;
      }
    }

    // Clamp seasonsPlayed inflated by the old multi-click season-end bug.
    if (card.seasonsPlayed > maxSeasons) raw['seasonsPlayed'] = maxSeasons;

    // Pro-mode fatigue: back-fill a full bar. Harmless for Casual saves, and
    // gives a correct full-energy start if they later switch via New Team.
    if (def != null && raw['energy'] == null) {
      raw['energy'] = getCardRating(def, ratingBonus: card.ratingBonus);
      raw['energyUpdatedAt'] = nowMs;
    }
  }

  // Pad to the current grid size. The array is fixed-length only so that
  // index-based drag targets stay stable.
  while (cells.length < Grid.totalCells) {
    cells.add(null);
  }

  // Name-order fix (2026): display names flipped from "Nickname Firstname" to
  // "Firstname Nickname" so they read like real names. Cached names on owned
  // cards were stored in the old order, so recompute each from the pools —
  // selection is deterministic from position, tier and variant gender, so this
  // reproduces the same name in the new order. One-time, flag-guarded.
  if (data['_nameOrderFix2026'] != true) {
    for (final c in cells) {
      final card = CardInstance.from(c);
      if (card == null) continue;
      final def = getPlayerDef(card.definitionId);
      if (def == null) continue;
      card.raw['displayName'] = pickDisplayName(
        def.position,
        math.max(0, def.tier - 1),
        female: isVariantFemale((_num(card.raw['variant']) ?? 0).toInt()),
      );
    }
  }
  data['_nameOrderFix2026'] = true;
}

// ── Club assets ─────────────────────────────────────────────────────────────
void _migrateClubAssets(Map<String, dynamic> data) {
  final existing = _map(data['clubAssets']);

  // v3: club assets moved from a grid of card instances to fixed upgradeable
  // assets. Convert the highest existing tier per category.
  if (existing?['cells'] != null || existing?[AssetCategory.training] == null) {
    final oldCells = existing?['cells'];
    final highestTier = <String, int>{};

    if (oldCells is List) {
      final pattern = RegExp(r'^(\w+)_t(\d+)$');
      for (final card in oldCells) {
        final defId = _map(card)?['definitionId'];
        if (defId is! String) continue;
        final m = pattern.firstMatch(defId);
        if (m == null) continue;
        final cat = m.group(1)!.toUpperCase();
        final tier = int.parse(m.group(2)!);
        if ((highestTier[cat] ?? 0) < tier) highestTier[cat] = tier;
      }
    }

    data['clubAssets'] = <String, dynamic>{
      for (final cat in AssetCategory.all)
        cat: () {
          final tier = highestTier[cat] ?? 0;
          return <String, dynamic>{
            'owned': tier > 0,
            'tier': tier,
            'invested': 0,
            'tapCount': 0,
          };
        }(),
    };
  }

  final assets = _ensureMap(data, 'clubAssets');

  // Fan Zone: home advantage moved off Stadium onto the new FANZONE asset.
  // Left alone, every existing save would silently drop from up to +4 home
  // advantage to +1 — a nerf nobody asked for and nobody would understand. So
  // grandfather it: a save that had a Stadium gets a Fan Zone already built at
  // the same tier, free. Runs exactly once, so upgrading the Stadium afterwards
  // does not keep handing out free Fan Zone tiers.
  if (data['_fanZoneGrandfathered'] != true) {
    final stadium = _map(assets[AssetCategory.stadium]);
    final fan = _map(assets[AssetCategory.fanzone]);
    if (stadium?['owned'] == true && fan != null && fan['owned'] != true) {
      assets[AssetCategory.fanzone] = <String, dynamic>{
        'owned': true,
        'tier': _num(stadium!['tier'])?.toInt() ?? 0,
        'invested': 0,
        'tapCount': 0,
      };
    }
    data['_fanZoneGrandfathered'] = true;
  }

  // v4: reset tapCount after the cost formula changed from linear to compound —
  // old saves carried inflated counts that made upgrades unreasonably dear.
  if (data['_tapCountReset2025'] != true) {
    for (final key in ['TRAINING', 'MERCH', 'STADIUM', 'MEDIA', 'SPONSOR']) {
      final asset = _map(assets[key]);
      if (asset != null) asset['tapCount'] = 0;
    }
    data['_tapCountReset2025'] = true;
  }
}

// ── Squad ───────────────────────────────────────────────────────────────────
void _migrateSquad(Map<String, dynamic> data) {
  final squad = _ensureMap(data, 'squad');
  if (squad['formation'] is! String) squad['formation'] = defaultFormation;

  final grid = _map(data['grid']);
  final rawCells = grid?['cells'];
  final cards = <CardInstance?>[
    if (rawCells is List)
      for (final c in rawCells) CardInstance.from(c),
  ];

  // 4-2-4 was removed: migrate to 4-3-3, preserving positions where possible.
  if (squad['formation'] == '4-2-4') {
    final oldRaw = squad['lineup'];
    squad['formation'] = '4-3-3';
    if (oldRaw is List && oldRaw.isNotEmpty) {
      final old = <LineupSlot>[
        for (final s in oldRaw)
          LineupSlot(
            slotId: _map(s)?['slotId'] as String? ?? '',
            slotPosition: _map(s)?['slotPosition'] as String? ?? '',
            cardInstanceId: _map(s)?['cardInstanceId'] as String?,
          ),
      ];
      squad['lineup'] = encodeLineup(migrateLineup(old, '4-3-3'));
    } else {
      squad['lineup'] = encodeLineup(buildDefaultLineup('4-3-3', cards));
    }
  }

  final lineup = squad['lineup'];
  if (lineup is! List || lineup.length != 11) {
    squad['lineup'] = encodeLineup(
      buildDefaultLineup(squad['formation'] as String?, cards),
    );
  }

  squad.remove('bench');
}

// ── Settings ────────────────────────────────────────────────────────────────
void _migrateSettings(Map<String, dynamic> data) {
  if (data['clubName'] == null) data['clubName'] = '';

  // `soundEnabled` is seeded only when the whole branch is being created, which
  // is the JS's behaviour and therefore the save's shape. Seeding it
  // unconditionally added a key to every existing save that did not have one —
  // harmless to read, and still a difference in the bytes. The differential
  // reset comparison is what surfaced it.
  final hadSettings = data['settings'] is Map<String, dynamic>;
  final settings = _ensureMap(data, 'settings');
  if (!hadSettings) settings['soundEnabled'] = true;
  settings['notificationsEnabled'] ??= true;

  // Existing saves keep the language they have been playing in — auto-detection
  // applies to brand-new games only. Anything we no longer ship a catalogue
  // for, or a corrupt value, falls back to English so the picker always has a
  // valid selection.
  if (!supportedLocales.contains(settings['locale'])) {
    settings['locale'] = fallbackLocale;
  }

  if (settings['regionCode'] != null && settings['regionCode'] is! String) {
    settings['regionCode'] = null;
  }

  settings['cutawayOurTeam'] ??= true;
  settings['cutawayOpponent'] ??= true;
  settings['hardMode'] ??= false;

  // Auto-sell rules. Drop anything that is not a known action so a corrupt or
  // hand-edited save cannot silently dispose of scouted cards.
  final actions = settings['autoTierActions'];
  if (actions is! Map<String, dynamic>) {
    settings['autoTierActions'] = <String, dynamic>{};
  } else {
    // Tiers 8 and 9 can never be auto-sold.
    actions.removeWhere((tier, action) {
      final t = int.tryParse(tier);
      return action != 'sell' || t == null || t < 1 || t > 7;
    });
  }

  // Saved team-name pyramids — keep only well-formed presets so a corrupt or
  // hand-edited save cannot crash the editor.
  final pyramids = settings['customPyramids'];
  if (pyramids is! List) {
    settings['customPyramids'] = <dynamic>[];
  } else {
    pyramids.retainWhere((p) {
      final m = _map(p);
      if (m == null) return false;
      if (m['id'] is! String || m['label'] is! String) return false;
      final names = m['names'];
      if (names is! Map) return false;
      return names.values.every(
        (arr) => arr is List && arr.every((n) => n is String),
      );
    });
  }
}

// ── Tutorial and coach tips ─────────────────────────────────────────────────
void _migrateTutorialAndTips(Map<String, dynamic> data) {
  final tutorial = _map(data['tutorial']);
  if (tutorial == null) {
    // A save with no tutorial branch predates it, so its owner has plainly
    // played the game already.
    //
    // The loan-hook flags are written here too, which the JS does NOT do — it
    // creates the branch bare and only adds them on the NEXT boot, through the
    // else path. That makes its migration non-idempotent for this one case.
    // Both builds converge on the same state; including them here just gets
    // there in one pass instead of two, and an idempotent migration is worth
    // more than matching a quirk.
    data['tutorial'] = <String, dynamic>{
      'done': true,
      'step': 0,
      'borrowedPlayersAdded': false,
      'borrowedPlayersRemoved': false,
    };
  } else {
    tutorial['borrowedPlayersAdded'] ??= false;
    tutorial['borrowedPlayersRemoved'] ??= false;

    // Step-index migration: two steps were inserted at old indices 3 and 6.
    // A mid-tutorial save at old step 3+ has already played its first match or
    // will skip the loan flow, so mark both flags done and shift the index.
    final step = _num(tutorial['step']);
    if (tutorial['done'] != true && step != null) {
      final s = step.toInt();
      if (s >= 3) {
        tutorial['borrowedPlayersAdded'] = true;
        tutorial['borrowedPlayersRemoved'] = true;
      }
      if (s >= 6) {
        tutorial['step'] = s + 2; // old 'done' (6) becomes new 8
      } else if (s >= 3) {
        tutorial['step'] = s + 1; // old play_match onward shifts by one
      }
      // s < 3: welcome / scout_1 / scout_2 stay at 0, 1, 2.
    }
  }

  // Existing players already know the game, so suppress the educational tips
  // they do not need. Two are deliberately left able to fire for veterans:
  // save_progress (an unsigned-in veteran may not realise sync exists) and
  // atk_def (the split is a new mechanic, so it is new to them too).
  // Brand-new games start with an empty list, so this only hits old saves.
  if (data['seenTips'] is! List) {
    data['seenTips'] = <dynamic>[
      'injury',
      'loss',
      'promotion',
      'merge',
      'energy',
      'club_assets',
      'training',
      'traits',
      'sponsor',
      'transfer_offer',
    ];
  }
}

// ── Prestige, shop, transfers, mini-games ───────────────────────────────────
void _migrateEconomy(Map<String, dynamic> data) {
  final prestige = _map(data['prestige']);
  if (prestige == null) {
    data['prestige'] = <String, dynamic>{
      'level': 0,
      'incomeMultiplier': 1.0,
      'totalTrophies': 0,
    };
  } else {
    // Sanitise a corrupt or absurd level so the pow below cannot yield a
    // non-finite multiplier and poison income. Legitimate play never nears it.
    var lvl = _num(prestige['level'])?.toDouble() ?? 0;
    if (!lvl.isFinite || lvl < 0) lvl = 0;
    lvl = math.min(lvl, 5000);
    // Store back as an int when it is whole. Widening 0 to 0.0 changes the
    // serialised bytes for identical data, which breaks byte-comparison
    // against the JS save — the main tool for proving the port faithful.
    prestige['level'] = lvl == lvl.roundToDouble() ? lvl.toInt() : lvl;

    // Recompute after the income bonus changed from 1.5 to 1.1 per level, and
    // again when it stopped compounding — see [prestigeMultiplierFor]. A save
    // written under the old power carries a multiplier this one never issues.
    final level = lvl;
    if (level > 0) {
      final m = prestigeMultiplierFor(level.toInt());
      prestige['incomeMultiplier'] = m.isFinite ? m : 1.0;
    } else {
      final mult = _num(prestige['incomeMultiplier'])?.toDouble();
      if (mult == null || !mult.isFinite) prestige['incomeMultiplier'] = 1.0;
    }
  }

  final shop = _map(data['shop']);
  if (shop == null) {
    data['shop'] = <String, dynamic>{
      'freeScoutReady': false,
      'luckyBootReady': false,
      'luckyBootUses': 0,
    };
  } else {
    shop['luckyBootUses'] ??= 0;
  }

  final market = _map(data['transferMarket']);
  if (market == null) {
    data['transferMarket'] = <String, dynamic>{
      'pendingOffer': null,
      'grudges': <String, dynamic>{},
    };
  } else {
    if (!market.containsKey('pendingOffer')) market['pendingOffer'] = null;
    if (market['grudges'] is! Map) market['grudges'] = <String, dynamic>{};

    // Clear offers that expired while the app was closed.
    final offer = _map(market['pendingOffer']);
    if (offer != null) {
      final createdAt = _num(offer['createdAt']) ?? 0;
      if (now() - createdAt > 5 * 60 * 1000) market['pendingOffer'] = null;
    }
  }

  final miniGames = _map(data['miniGames']);
  if (miniGames == null) {
    data['miniGames'] = <String, dynamic>{
      'penaltyLastPlayed': 0,
      'trainingLastPlayed': 0,
    };
  } else {
    miniGames['penaltyLastPlayed'] ??= 0;
    miniGames['trainingLastPlayed'] ??= 0;
  }
}

/// Retired kit colours, remapped to their distinct replacements.
///
/// Each value is a colour still in the palette. When a replacement is itself
/// later retired, its target is updated here too, so one lookup always lands on
/// a kept colour.
const Map<String, String> retiredColours = {
  // First cull, before light mode went neutral.
  '#e74c3c': '#0d47a1', '#3498db': 'empire', '#9b59b6': '#e91e63',
  '#f1c40f': '#795548', '#c0392b': '#006064', '#e67e22': '#33691e',
  '#1abc9c': '#880e4f', '#cd853f': '#37474f',
  // Second cull: near-duplicate hues and near-colourless greys, retired once
  // light mode went neutral and the accent hue became the only differentiator.
  '#00acc1': 'empire', '#ff7043': 'sunset', '#7e57c2': 'void',
  '#f06292': '#e91e63', '#e8e8e8': '#546e7a', '#bdc3c7': '#546e7a',
  '#7f8c8d': '#546e7a',
};

void _migrateClub(Map<String, dynamic> data) {
  final club = _ensureMap(data, 'club');

  if (club['kitPrimaryColor'] is! String) club['kitPrimaryColor'] = '#4caf50';
  if (club['polishLevel'] is! num) club['polishLevel'] = 0;

  final remapped = retiredColours[club['kitPrimaryColor']];
  if (remapped != null) club['kitPrimaryColor'] = remapped;

  // Manager look packs and item-level unlocks. Old saves have no items and
  // need none: they hold whole packs, and pack ownership short-circuits every
  // item check, so nobody loses a cosmetic they had.
  if (club['lookPacks'] is! List) club['lookPacks'] = <dynamic>[];
  if (club['lookItems'] is! List) club['lookItems'] = <dynamic>[];

  // Local mirror of the ad frequency cap. Only the container is created here —
  // the stamps are pruned on every read, so a save restored from an old backup
  // starts with a clear window rather than a phantom cooldown.
  final ads = _ensureMap(data, 'ads');
  if (ads['packUnlocks'] is! List) ads['packUnlocks'] = <dynamic>[];
}

// ── Stats ───────────────────────────────────────────────────────────────────
void _migrateStats(Map<String, dynamic> data) {
  final stats = _ensureMap(data, 'stats');
  final coins = _num(_map(data['resources'])?['fanCoins']) ?? 0;

  final defaults = <String, num>{
    'maxCoinsReached': math.max(0, coins),
    'transfersAccepted': 0,
    'transfersDeclined': 0,
    'penaltyRounds': 0,
    'penaltiesScored': 0,
    'perfectPenalties': 0,
    'perfectTrainings': 0,
  };

  defaults.forEach((k, v) {
    if (stats[k] is! num) stats[k] = v;
  });
}

// ── Boosts ──────────────────────────────────────────────────────────────────
void _migrateBoosts(Map<String, dynamic> data) {
  final boosts = _map(data['boosts']);
  if (boosts == null) return;

  final season = _num(_map(data['progression'])?['seasonCount'])?.toInt() ?? 1;

  // Migrate legacy match-counter sponsors to the season-scoped fields: a save
  // with matchesLeft above zero keeps the buff for the current season, then
  // expires naturally at season end.
  if (!boosts.containsKey('kitSponsorSeason')) {
    final legacy = _num(boosts['kitSponsorMatchesLeft']) ?? 0;
    boosts['kitSponsorSeason'] = legacy > 0 ? season : null;
  }
  if (!boosts.containsKey('matchRevBoostSeason')) {
    final legacy = _num(boosts['matchRevBoostMatchesLeft']) ?? 0;
    boosts['matchRevBoostSeason'] = legacy > 0 ? season : null;
  }
  boosts.remove('kitSponsorMatchesLeft');
  boosts.remove('matchRevBoostMatchesLeft');

  // Legacy prestige-linked VIP used a sentinel expiry. VIP is 30 days from
  // purchase now, so convert an effectively-infinite expiry into 30 days from
  // migration rather than cutting existing buyers off mid-run.
  final saneMax = now() + 365 * 24 * 60 * 60 * 1000;
  const thirtyDays = 30 * 24 * 60 * 60 * 1000;

  if ((_num(boosts['vipExpiresAt']) ?? 0) > saneMax) {
    boosts['vipExpiresAt'] = now() + thirtyDays;
    boosts['vipPrestigeLevel'] = null;
  }
  final shop = _map(data['shop']);
  if (shop != null && (_num(shop['vipExpiresAt']) ?? 0) > saneMax) {
    shop['vipExpiresAt'] = now() + thirtyDays;
    shop['vipPrestigeLevel'] = null;
  }
}
