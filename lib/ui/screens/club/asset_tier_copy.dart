/// What a facility's tiers SAY. The words for `club_asset_tiers.dart`'s numbers,
/// ported from `_statText`, `_unlockHtml` and the two colour tables in
/// `ui/screens/ClubScreen.js`.
///
/// **`club_asset_tiers.dart` had no caller.** It is a fully ported, fully tested
/// engine that computes what every facility gives at every tier, and what one
/// step up the ladder actually changes — including the two bugs it exists to fix
/// (a "next" line that repeated the current one, and unlocks nobody advertised).
/// None of it reached the screen: the Club tab's cards said a name, a hint and a
/// price, so a player investing had no idea what they were buying. That is most
/// of what "the Build column looks unfinished" was.
///
/// This is the mapping layer only — ids and params in, localised strings out. It
/// is deliberately separate from the screen so the ladder sheet and the card use
/// the same words for the same tier.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_tiers.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// Where an unlock is being said, which changes how it is worded.
///
/// A mini-game on a `card` is a bare name — the row is already a list of perks.
/// In the `ladder` it takes the verb, because a game's name beside a percentage
/// is ambiguous. Cosmetics never take it: the Fan Zone unlocks some at all eight
/// tiers, and eight rows ending in "unlocked" is a column of noise.
enum UnlockVoice { card, ladder }

/// The tier ladder's colours: bronze, copper, silver, bright silver, gold, deep
/// gold, legend purple, and the cyan an eighth tier alone wears.
const List<Color> assetTierInk = [
  Color(0xFFAAAAAA), // 0 — unbuilt
  Color(0xFFCD7F32),
  Color(0xFFB87333),
  Color(0xFFA8A9AD),
  Color(0xFFD4D4D4),
  Color(0xFFFFD700),
  Color(0xFFFFB830),
  Color(0xFFC084FC),
  Color(0xFF00C8FF),
];

Color assetTierColour(int tier) => tier >= 0 && tier < assetTierInk.length
    ? assetTierInk[tier]
    : const Color(0xFFFFD700);

/// Each facility's own glyph, by the icon names `game_icon.dart` already ships.
const Map<String, String> assetCategoryIcon = {
  AssetCategory.training: 'dumbbell',
  AssetCategory.merch: 'bag',
  AssetCategory.stadium: 'club',
  AssetCategory.media: 'tv',
  AssetCategory.sponsor: 'handshake',
  AssetCategory.academy: 'userAdd',
  AssetCategory.fanzone: 'megaphone',
};

/// A mini-game id, as `getUnlockedMinigames` reports it, to its name and glyph.
/// Penalty Training is free from the start, so it never turns up in a tier diff.
const Map<String, ({String nameKey, String icon})> minigameDisplay = {
  'training': (nameKey: 'club.minigame.goalkeeper', icon: 'goal'),
  'keepy_uppys': (nameKey: 'club.minigame.keepy_uppys', icon: 'keepyUppys'),
  'through_ball': (nameKey: 'club.minigame.through_ball', icon: 'target'),
  'pairs': (nameKey: 'club.minigame.memory_pairs', icon: 'star'),
  'whack': (nameKey: 'club.minigame.whack', icon: 'invader'),
  'boot_room': (nameKey: 'club.minigame.boot_room', icon: 'bootRoom'),
};

/// One live stat, as words.
String statText(TierLine line) => t('club.effect.${line.id}', line.params);

/// A customisation key (`hair:mohawk`, `outfit:coat`) as its display name.
/// Outfits live under their own prefix; every other axis is an item.
String cosmeticName(String key) {
  final parts = key.split(':');
  if (parts.length < 2) return key;
  return parts.first == 'outfit'
      ? t('customise.outfit.${parts[1]}')
      : t('customise.item.${parts.first}.${parts[1]}');
}

/// One milestone unlock: its glyph and its words, or null when there is nothing
/// to say about it.
({String? icon, String text})? unlockLine(
  TierLine line, {
  UnlockVoice voice = UnlockVoice.card,
}) {
  switch (line.id) {
    case 'minigame':
      final display = minigameDisplay['${line.params['game']}'];
      if (display == null) return null;
      final name = t(display.nameKey);
      return (
        icon: display.icon,
        text: voice == UnlockVoice.card
            ? name
            : t('club.minigame_unlocked', {'name': name}),
      );
    case 'colours':
      return (icon: null, text: t('club.unlock.colours', line.params));
    case 'looks':
      // NAMED, not counted. Every Fan Zone tier unlocks a different set, and
      // "+2 manager customisations" threw that away and made the ladder read
      // like the same reward eight times over.
      final items = line.params['items'];
      if (items is! List || items.isEmpty) return null;
      return (
        icon: 'userAdd',
        text: [for (final key in items) cosmeticName('$key')].join(', '),
      );
    case 'slots':
      final n = line.params['n'];
      return (
        icon: 'userAdd',
        text: n == 1
            ? t('club.effect.player_slot')
            : t('club.squad_slots_unlocked', line.params),
      );
    default:
      return null;
  }
}

/// The facility's live numbers at [tier] — what the club HAS.
///
/// Milestones are deliberately absent: "2 new manager looks unlocked" describes
/// the moment a tier landed, not a standing perk, so it belongs on the tier-up
/// card and in the ladder rather than on this one for ever.
String assetPerkLine(String key, int tier) =>
    tier <= 0 ? '—' : assetStatsAt(key, tier).map(statText).join(' · ');

/// What the NEXT tier changes, or null at the top of the ladder.
///
/// Only what changes: the Fan Zone's home advantage moves at tiers two, four and
/// seven only, and echoing "+3 home advantage" on both lines is what made the
/// card read as broken.
String? assetNextLine(String key, int tier) {
  final delta = assetTierDelta(key, tier);
  if (delta == null) return null;
  final parts = <String>[
    for (final stat in delta.stats) statText(stat),
    for (final unlock in delta.unlocks) ?unlockLine(unlock)?.text,
  ];
  if (parts.isEmpty) return null;
  return t('club.next_tier', {'n': delta.tier, 'effect': parts.join(' · ')});
}
