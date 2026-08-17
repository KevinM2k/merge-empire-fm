/// The manager's wardrobe: what exists, how each piece is obtained, and what a
/// save is allowed to wear. Ported from the unlock half of
/// `../merge-empire-fc/src/data/managerAvatar.js`.
///
/// That file is 1,458 lines and most of it is SVG geometry for the walking
/// figure — a rendering concern, and M3's. This is the half the ENGINES need:
/// prestige has to carry the persistent cosmetics across, and a look that
/// references something the player no longer owns has to be swapped back to a
/// free default. The two halves already split cleanly there, because the
/// membership checks the normaliser makes are exactly the id lists below (a
/// test pins that against node).
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

// ── The wardrobe ────────────────────────────────────────────────────────────
// Ids only. The geometry keyed by them lives with the renderer.

const List<String> buildIds = [
  'regular',
  'lean',
  'broad',
  'belly',
  'athletic',
  'curvy',
];

const List<String> outfitIds = ['kit', 'tracksuit', 'coat', 'suit'];

const List<String> hairStyleIds = [
  'crop', 'buzz', 'shaved', 'afro', 'pony', 'bun', 'flow', 'mohawk',
  'spikes', 'mullet', 'curtains', 'dreads', 'slick', 'fauxhawk', 'braids',
];

const List<String> facialHairIds = [
  'none', 'stubble', 'moustache', 'goatee', 'beard', 'full',
  'pencil', 'handlebar', 'muttonchops', 'braided',
];

const List<String> hatIds = [
  'none', 'headband', 'cap', 'beanie', 'crown', 'flatcap', 'bucket',
  'snapback', 'visor', 'sunhat', 'santa', 'tophat', 'viking', 'party',
  'hardhat', 'headphones', 'laurel', 'diamond',
];

const List<String> faceIds = [
  'none', 'specs', 'shades', 'aviators', 'goggles', 'monocle', 'cigar',
  'whistle', 'nosestrip', 'eyeblack', 'warpaint', 'facepaint',
];

const List<String> ballIds = [
  'classic', 'retro', 'winter', 'beach', 'gold',
  'disco', 'flame', 'eightball', 'star', 'futsal',
];

const List<String> neckIds = ['none', 'scarf'];

/// The five moods the face can wear. Every one of them is emitted by the rig,
/// and CSS shows the matching one — so the expression follows the figure
/// everywhere it renders.
const List<String> moodMouthIds = [
  'elated',
  'pleased',
  'neutral',
  'glum',
  'crushed',
];

/// A hair colour, as a pickable id and the value a save stores.
typedef HairColor = ({String id, String color});

const List<HairColor> hairColors = [
  (id: 'black', color: '#1a1410'),
  (id: 'darkbrown', color: '#3a2a1c'),
  (id: 'brown', color: '#6b4423'),
  (id: 'auburn', color: '#a9762f'),
  (id: 'blonde', color: '#d9b44a'),
  (id: 'ginger', color: '#b5482a'),
  (id: 'grey', color: '#9a9a9a'),
  (id: 'platinum', color: '#e6ddc9'),
  (id: 'pink', color: '#e0559b'),
  (id: 'blue', color: '#3f7fd6'),
  (id: 'green', color: '#2fae6a'),
  (id: 'purple', color: '#8a5cd6'),
  (id: 'gold', color: '#ffc233'),
  (id: 'white', color: '#f4f4f0'),
  (id: 'silver', color: '#c3ccd4'),
  (id: 'teal', color: '#22b3a6'),
  (id: 'tangerine', color: '#f07a1f'),
  (id: 'lilac', color: '#b79ae8'),
  (id: 'crimson', color: '#c2223f'),
];

final List<String> hairColorIds = [for (final c in hairColors) c.id];

String? hairColorValue(String? id) {
  for (final c in hairColors) {
    if (c.id == id) return c.color;
  }
  return null;
}

String? hairColorId(String? value) {
  for (final c in hairColors) {
    if (c.color == value) return c.id;
  }
  return null;
}

/// Skin tones as a base and its shade.
const List<(String, String)> skinTones = [
  ('#f7d9bd', '#e0bd98'),
  ('#eebb8c', '#cf9f77'),
  ('#e3b183', '#c4926a'),
  ('#d99a6c', '#bd7f52'),
  ('#b87a49', '#9a5f34'),
  ('#8d5a2b', '#6e421c'),
  ('#6f462a', '#53321c'),
  ('#5e3a1f', '#452a15'),
];

// ── How each piece is obtained ──────────────────────────────────────────────

/// Shapes unlocked by Fan Zone tier — stacking, so every tier up to the current
/// one is unlocked.
///
/// The Fan Zone is the club asset that owns personalisation: the crowd that
/// watches you is also the crowd you dress up for.
const Map<int, List<String>> fanzoneLookUnlocks = {
  1: ['beard:stubble', 'hair:mohawk'],
  2: ['beard:moustache', 'hair:mullet'],
  3: ['beard:goatee', 'hair:spikes', 'outfit:coat'],
  4: ['hat:headband', 'hair:curtains'],
  5: ['beard:beard', 'hair:dreads'],
  6: ['hat:cap', 'hair:braids', 'outfit:suit'],
  7: ['beard:full', 'face:specs'],
  8: ['hair:slick'],
};

/// Cup-exclusive looks. Not sold, not tier-gated — the ONLY way to get one is
/// to lift the trophy, so a manager wearing one is making a claim that cannot
/// be bought.
const Map<String, List<String>> cupLookUnlocks = {
  'regional_cup': ['hair:fauxhawk'],
  'national_cup': ['hat:headphones'],
  'continental_cup': ['hat:laurel'],
  'world_club_cup': ['hat:diamond'],
};

/// A themed pack of cosmetics.
///
/// [tint] is the pack's colour on the shop shelf — display only, so ten tiles
/// don't read as one grey block.
typedef LookPack = ({String id, String tint, String icon, List<String> items});

/// The bulk of the cosmetics, and the only ones that cost anything.
///
/// ONE AD PER ITEM, not per pack. A video buys the single cosmetic you tapped;
/// the PACK is never an ad reward, it just becomes yours once you happen to own
/// everything in it. That is a deliberate reversal — a pack per video priced
/// the whole catalogue at ten videos, about a quarter of an hour, which is not
/// something a Style Vault can be sold against.
///
/// Packs mix slots on purpose. A pack of nothing but hats is a list; a hat, a
/// face item, a hair colour and an emote is a LOOK, and it shows up in three
/// different places the moment you unlock it.
///
/// Coins buy nothing here. Coins are the run's economy — a reset wipes them, so
/// anything they bought would have to go back too, and a cosmetic that re-locks
/// when you take a new job is one nobody trusts.
const List<LookPack> lookPacks = [
  (
    id: 'pack_summer',
    tint: '#ffb300',
    icon: '☀️',
    items: ['hat:sunhat', 'hat:visor', 'face:aviators', 'emote:wave'],
  ),
  (
    id: 'pack_winter',
    tint: '#4fc3f7',
    icon: '❄️',
    items: ['hat:santa', 'face:goggles', 'color:white', 'emote:blowkiss'],
  ),
  // `pack_neon` and `pack_swagger` keep their ids from when they were coin
  // packs, so the save needs no migration — anyone who bought either keeps it
  // and gets it upgraded from run-scoped to permanent for free.
  (
    id: 'pack_neon',
    tint: '#e040fb',
    icon: '💿',
    items: [
      'color:pink',
      'color:blue',
      'color:green',
      'color:purple',
      'emote:robot',
    ],
  ),
  (
    id: 'pack_swagger',
    tint: '#ff8f00',
    icon: '😎',
    items: ['face:shades', 'hat:crown', 'color:gold'],
  ),
  (
    id: 'pack_oldschool',
    tint: '#8d6e63',
    icon: '📻',
    items: [
      'hat:flatcap',
      'beard:pencil',
      'beard:muttonchops',
      'color:silver',
      'emote:fingerwag',
    ],
  ),
  (
    id: 'pack_terrace',
    tint: '#ef5350',
    icon: '📣',
    items: [
      'hat:bucket',
      'hat:party',
      'face:facepaint',
      'emote:badgekiss',
      'emote:shush',
    ],
  ),
  (
    id: 'pack_rockstar',
    tint: '#7c4dff',
    icon: '🎸',
    items: [
      'hat:snapback',
      'face:eyeblack',
      'color:teal',
      'color:lilac',
      'color:crimson',
    ],
  ),
  (
    id: 'pack_legend',
    tint: '#ffd700',
    icon: '👑',
    items: [
      'hat:tophat',
      'face:monocle',
      'face:cigar',
      'beard:handlebar',
      'emote:bow',
    ],
  ),
  (
    id: 'pack_warrior',
    tint: '#78909c',
    icon: '⚔️',
    items: ['hat:viking', 'beard:braided', 'face:warpaint', 'emote:salute'],
  ),
  (
    id: 'pack_touchline',
    tint: '#66bb6a',
    icon: '📋',
    items: [
      'hat:hardhat',
      'face:whistle',
      'face:nosestrip',
      'color:tangerine',
      'emote:facepalm',
    ],
  ),
];

LookPack? getLookPack(String? packId) {
  for (final p in lookPacks) {
    if (p.id == packId) return p;
  }
  return null;
}

/// The IAP that unlocks every pack at once.
///
/// Cup exclusives are deliberately NOT included — the diamond crown stays
/// unbuyable, which is the entire point of it.
const String styleVaultId = 'style_vault';

/// Does this save own the Style Vault?
///
/// Checked before pack ownership everywhere, so a future pack is unlocked by an
/// old purchase the moment it ships — which is the actual promise the Vault
/// makes.
bool hasStyleVault(Map<String, dynamic>? state) {
  final ids = (state?['shop'] as Map<String, dynamic>?)?['purchasedIds'];
  return ids is List && ids.contains(styleVaultId);
}

/// How a cosmetic is obtained. All three are null for anything free.
typedef LookRequirement = ({int? fanTier, String? cupId, String? packId});

final Map<String, LookRequirement> _gated = () {
  final map = <String, LookRequirement>{};
  for (final entry in fanzoneLookUnlocks.entries) {
    for (final key in entry.value) {
      map[key] = (fanTier: entry.key, cupId: null, packId: null);
    }
  }
  for (final entry in cupLookUnlocks.entries) {
    for (final key in entry.value) {
      map[key] = (fanTier: null, cupId: entry.key, packId: null);
    }
  }
  for (final pack in lookPacks) {
    for (final key in pack.items) {
      map[key] = (fanTier: null, cupId: null, packId: pack.id);
    }
  }
  return map;
}();

/// How this item is obtained, or null when it is free from the start.
LookRequirement? lookRequirement(String? kind, String? id) =>
    _gated['$kind:$id'];

List<String> _ownedPacks(Map<String, dynamic>? state) {
  final list = (state?['club'] as Map<String, dynamic>?)?['lookPacks'];
  return list is List ? [for (final id in list) '$id'] : const [];
}

/// Individual cosmetics unlocked one at a time, as opposed to the packs owned
/// OUTRIGHT.
///
/// Two lists rather than one because they answer different questions and decay
/// differently: a pack bought with gems stays bought even if its contents
/// change, whereas a set of items is exactly what it says. Adding an item to a
/// pack later must not silently re-lock it for someone who paid for the pack.
Set<String> ownedLookItems(Map<String, dynamic>? state) {
  final list = (state?['club'] as Map<String, dynamic>?)?['lookItems'];
  return {if (list is List) for (final key in list) '$key'};
}

/// The Fan Zone tier actually in effect — zero when the asset isn't built.
int fanZoneLookTier(Map<String, dynamic>? state) {
  final a = (state?['clubAssets'] as Map<String, dynamic>?)?['FANZONE'];
  if (a is! Map || a['owned'] != true) return 0;
  return (a['tier'] as num?)?.toInt() ?? 0;
}

/// Cup ids this club has ever won, from two sources unioned.
///
/// The permanent record written on each cup win is the one that matters,
/// because it survives a soft reset. The trophy cabinet is session-only, but it
/// grants retroactive credit to a save that won cups before cup-exclusive looks
/// existed.
Set<String> wonCupIds(Map<String, dynamic>? state) {
  final club = state?['club'] as Map<String, dynamic>?;
  final won = club?['cupLooksWon'];
  final ids = <String>{
    if (won is List)
      for (final id in won) '$id',
  };
  final trophies =
      (state?['progression'] as Map<String, dynamic>?)?['leagueTrophies'];
  if (trophies is List) {
    for (final tr in trophies) {
      if (tr is Map && tr['cup'] == true) ids.add('${tr['division']}');
    }
  }
  return ids;
}

/// Is this cosmetic available right now?
///
/// The Vault short-circuits PACK ownership only. Fan Zone tiers and cup
/// exclusives are checked first and are unaffected by it — money buys flair,
/// not progress and not silverware.
bool isLookUnlocked(Map<String, dynamic>? state, String kind, String? id) {
  final req = lookRequirement(kind, id);
  if (req == null) return true;
  if (req.fanTier != null) return fanZoneLookTier(state) >= req.fanTier!;
  if (req.cupId != null) return wonCupIds(state).contains(req.cupId);
  if (hasStyleVault(state) || _ownedPacks(state).contains(req.packId)) {
    return true;
  }
  return ownedLookItems(state).contains('$kind:$id');
}

/// Items in this pack the player already has, by any route.
int packUnlockedCount(Map<String, dynamic>? state, String? packId) {
  final pack = getLookPack(packId);
  if (pack == null) return 0;
  if (hasStyleVault(state) || _ownedPacks(state).contains(packId)) {
    return pack.items.length;
  }
  final items = ownedLookItems(state);
  return pack.items.where(items.contains).length;
}

/// Does the player have everything in this pack?
///
/// Owning a pack and owning all of its contents are different facts that look
/// the same from outside, which is the point: it is what makes a pack complete
/// without ever being an ad reward itself.
bool isPackComplete(Map<String, dynamic>? state, String? packId) {
  final pack = getLookPack(packId);
  if (pack == null) return false;
  return packUnlockedCount(state, packId) >= pack.items.length;
}

/// Every pack the player owns outright, the Vault included.
List<String> unlockedPackIds(Map<String, dynamic>? state) {
  if (hasStyleVault(state)) return [for (final p in lookPacks) p.id];
  final outright = [
    for (final id in _ownedPacks(state))
      if (getLookPack(id) != null) id,
  ];
  // A pack completed item by item counts here too, or the shop's "8 / 10" line
  // would never move for a player taking the free route.
  final completed = [
    for (final p in lookPacks)
      if (!outright.contains(p.id) && isPackComplete(state, p.id)) p.id,
  ];
  return [...outright, ...completed];
}

Map<String, dynamic> _clubBranch(Map<String, dynamic> state) {
  final existing = state['club'];
  if (existing is Map<String, dynamic>) return existing;
  final fresh = <String, dynamic>{};
  state['club'] = fresh;
  return fresh;
}

List<dynamic> _clubList(Map<String, dynamic> club, String key) {
  final existing = club[key];
  if (existing is List) return existing;
  final fresh = <dynamic>[];
  club[key] = fresh;
  return fresh;
}

/// Grant a look pack. False when the pack is unknown or already owned.
bool grantLookPack(Map<String, dynamic>? state, String? packId) {
  if (state == null || getLookPack(packId) == null) return false;
  final club = _clubBranch(state);
  final owned = _clubList(club, 'lookPacks');
  if (owned.contains(packId)) return false;
  owned.add(packId);
  return true;
}

/// Grant ONE cosmetic — the rewarded-video reward.
///
/// Every pack item is eligible. What is refused is anything with no pack behind
/// it: Fan Zone tiers and cup exclusives are EARNED, and the diamond crown in
/// particular is worthless the moment a video can buy it. Enforcing that here
/// rather than only in the UI means a stray caller can't hand one out.
bool grantLookItem(Map<String, dynamic>? state, String? key) {
  if (state == null || key == null) return false;
  final parts = key.split(':');
  if (parts.length < 2) return false;
  if (lookRequirement(parts[0], parts[1])?.packId == null) return false;
  final club = _clubBranch(state);
  final owned = _clubList(club, 'lookItems');
  if (owned.contains(key)) return false;
  owned.add(key);
  return true;
}

/// The owned packs that survive a New Team reset and a prestige — all of them.
///
/// Every route to a pack (a rewarded video, gems, the Style Vault) sits outside
/// the run's economy, so a reset that wipes coins can't undo any of them. The
/// filter still does work: it drops ids that have left the catalogue, which
/// unlock nothing and would otherwise be carried forward for ever as dead data.
List<String> persistentLookPacks(Map<String, dynamic>? state) => [
  for (final id in _ownedPacks(state))
    if (getLookPack(id) != null) id,
];

/// Items kept through a reset, for the same reason — with the same filter for
/// anything that has left the catalogue.
List<String> persistentLookItems(Map<String, dynamic>? state) {
  final list = (state?['club'] as Map<String, dynamic>?)?['lookItems'];
  if (list is! List) return const [];
  return [
    for (final raw in list)
      if ('$raw'.split(':') case final parts when parts.length >= 2)
        if (lookRequirement(parts[0], parts[1])?.packId != null) '$raw',
  ];
}

// ── A stored look ───────────────────────────────────────────────────────────

/// The manager's appearance, as the save stores it.
typedef ManagerLook = Map<String, dynamic>;

/// Which of the two head slots each id from the retired combined `acc` axis
/// belongs to. Everything not listed here was headwear.
const Map<String, bool> _legacyAccFace = {'specs': true, 'shades': true};

/// The ids the retired `acc` axis could hold.
///
/// An explicit set rather than one derived from the hat and face tables, so a
/// NEW item can never be mistaken for a legacy value just because the two
/// happen to share a name.
const Set<String> _legacyAccIds = {
  'none', 'headband', 'cap', 'beanie', 'specs', 'shades', 'crown',
  'headphones', 'laurel', 'diamond',
};

final math.Random _unseeded = math.Random();

T _pick<T>(List<T> list) => list[_unseeded.nextInt(list.length)];

List<String> _availableIds(
  Map<String, dynamic>? state,
  String kind,
  List<String> ids,
) => state == null
    ? ids
    : [
        for (final id in ids)
          if (isLookUnlocked(state, kind, id)) id,
      ];

/// A fresh random look.
///
/// Pass [state] to roll only from what the player has unlocked — which is what
/// the on-pitch dice does; omit it for an unrestricted roll.
///
/// Uses the UNSEEDED stream, matching the JS `Math.random()`. This is a
/// cosmetic roll, not gameplay, and it must not shift the seeded sequence.
ManagerLook randomAvatar([Map<String, dynamic>? state]) {
  final (skin, skinShade) = _pick(skinTones);
  final colorIds = _availableIds(state, 'color', hairColorIds);
  return <String, dynamic>{
    'build': _pick(_availableIds(state, 'build', buildIds)),
    'outfit': _pick(_availableIds(state, 'outfit', outfitIds)),
    'style': _pick(_availableIds(state, 'hair', hairStyleIds)),
    'hair': hairColorValue(_pick(colorIds)),
    'skin': skin,
    'skinShade': skinShade,
    // A beard reads oddly on some of the longer styles at this size, and both
    // head slots roll low: the point of a reroll is a plausible manager, and a
    // figure in a viking helm AND a monocle every other tap is a novelty rather
    // than a face.
    'beard': _unseeded.nextDouble() < 0.45
        ? _pick(_availableIds(state, 'beard', facialHairIds))
        : 'none',
    'hat': _unseeded.nextDouble() < 0.25
        ? _pick(_availableIds(state, 'hat', hatIds))
        : 'none',
    'face': _unseeded.nextDouble() < 0.2
        ? _pick(_availableIds(state, 'face', faceIds))
        : 'none',
    // Ball skins are shelved.
    'ball': 'classic',
    // Not rolled: what is round his neck is derived from the headwear now, so
    // the field is kept only to hold the look's shape stable.
    'neck': 'none',
  };
}

/// Coerce a stored — possibly partial or legacy — look into a valid one.
///
/// A missing or invalid field is filled from a random pick so the figure never
/// renders undefined. Legacy saves predate the build, beard and outfit axes, so
/// THOSE default to the plain look rather than a random one: an existing
/// player's manager must not sprout a beard the first time they open the app
/// after updating.
ManagerLook normalizeAvatar(Object? a) {
  final base = randomAvatar();
  if (a is! Map) return base;

  // A legacy save carries one `acc` field from when hats and glasses shared a
  // slot. Fold it into whichever of the two now owns that item, and only when
  // the new field is absent — a save written since the split is authoritative.
  final legacy = _legacyAccIds.contains(a['acc']) ? '${a['acc']}' : null;
  final hat = a['hat'] ??
      (legacy != null && _legacyAccFace[legacy] != true ? legacy : 'none');
  final face = a['face'] ??
      (legacy != null && _legacyAccFace[legacy] == true ? legacy : 'none');

  return <String, dynamic>{
    'build': buildIds.contains(a['build']) ? a['build'] : 'regular',
    'outfit': outfitIds.contains(a['outfit']) ? a['outfit'] : 'kit',
    'style': hairStyleIds.contains(a['style']) ? a['style'] : base['style'],
    'hair': hairColorId(a['hair'] as String?) != null ? a['hair'] : base['hair'],
    'skin': a['skin'] is String ? a['skin'] : base['skin'],
    'skinShade': a['skinShade'] is String ? a['skinShade'] : base['skinShade'],
    'beard': facialHairIds.contains(a['beard']) ? a['beard'] : 'none',
    'hat': hatIds.contains(hat) ? hat : 'none',
    'face': faceIds.contains(face) ? face : 'none',
    'ball': 'classic',
    // Always bare: what is round his neck is derived from the headwear now, so
    // any value a save still carries is normalised away.
    'neck': 'none',
  };
}

/// The first hair colour that is free from the start — every fallback below has
/// to be, so a sanitised look is always a valid figure no matter what the
/// player has, or has lost.
final String freeHairColorId = hairColorIds.firstWhere(
  (id) => lookRequirement('color', id) == null,
);

/// A stored look with anything the player no longer owns swapped back to the
/// free default.
///
/// Run after a prestige, where the club that earned a Fan Zone cosmetic no
/// longer exists — the point is to measure the face against the FRESH club
/// rather than the one that just ended.
ManagerLook sanitizeAvatar(Map<String, dynamic>? state, Object? a) {
  final look = normalizeAvatar(a);

  Object? keep(String kind, String key, String free) =>
      isLookUnlocked(state, kind, look[key] as String?) ? look[key] : free;

  return <String, dynamic>{
    ...look,
    'build': keep('build', 'build', 'regular'),
    'outfit': keep('outfit', 'outfit', 'kit'),
    'style': keep('hair', 'style', 'crop'),
    'beard': keep('beard', 'beard', 'none'),
    'hat': keep('hat', 'hat', 'none'),
    'face': keep('face', 'face', 'none'),
    'ball': keep('ball', 'ball', 'classic'),
    'hair': isLookUnlocked(state, 'color', hairColorId(look['hair'] as String?))
        ? look['hair']
        : hairColorValue(freeHairColorId),
  };
}
