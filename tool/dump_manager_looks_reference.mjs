// Reference output from the JS manager-look unlock layer.
//
// The port keeps only this half of managerAvatar.js — the SVG geometry is a
// rendering concern. The membership checks the normaliser makes are the ID
// LISTS here rather than the geometry maps, and this is what proves the two are
// the same set.
//
//   node tool/dump_manager_looks_reference.mjs > test/fixtures/manager_looks_reference.json

const m = await import('../../merge-empire-fc/src/data/managerAvatar.js');

const out = {
  ids: {
    build: m.BUILD_IDS,
    outfit: m.OUTFIT_IDS,
    hair: m.HAIR_STYLE_IDS,
    beard: m.FACIAL_HAIR_IDS,
    hat: m.HAT_IDS,
    face: m.FACE_IDS,
    ball: m.BALL_IDS,
    neck: m.NECK_IDS,
    color: m.HAIR_COLOR_IDS,
    mood: m.MOOD_MOUTH_IDS,
  },
  hairColors: m.HAIR_COLORS,
  skinTones: m.SKIN_TONES,
  fanzone: m.FANZONE_LOOK_UNLOCKS,
  cup: m.CUP_LOOK_UNLOCKS,
  packs: m.LOOK_PACKS,
  styleVaultId: m.STYLE_VAULT_ID,
  requirements: {},
  normalized: {},
  sanitized: {},
  unlocked: {},
};

// Every id on every axis, and how it is obtained.
for (const [kind, ids] of Object.entries(out.ids)) {
  for (const id of ids ?? []) {
    out.requirements[`${kind}:${id}`] = m.lookRequirement(kind, id) ?? null;
  }
}

// The normaliser, over every id on every axis plus the legacy shapes.
const NORMALIZE_CASES = {
  empty: {},
  nullish: null,
  legacyHat: { acc: 'crown' },
  legacyFace: { acc: 'shades' },
  legacyUnknownAcc: { acc: 'nonsense' },
  legacyAccWithNewField: { acc: 'crown', hat: 'viking' },
  garbage: { build: 7, outfit: [], style: {}, beard: 'nope', hat: 'nope', face: 'nope' },
  neckIsAlwaysBare: { neck: 'scarf' },
  ballIsAlwaysClassic: { ball: 'gold' },
  full: {
    build: 'broad', outfit: 'suit', style: 'braids', hair: '#e0559b',
    skin: '#8d5a2b', skinShade: '#6e421c', beard: 'full', hat: 'viking',
    face: 'monocle', ball: 'classic', neck: 'none',
  },
};
for (const [label, input] of Object.entries(NORMALIZE_CASES)) {
  const n = m.normalizeAvatar(input);
  // The random half of the fallback can't be compared, so only the fields the
  // normaliser is deterministic about are recorded.
  out.normalized[label] = {
    build: n.build, outfit: n.outfit, beard: n.beard,
    hat: n.hat, face: n.face, ball: n.ball, neck: n.neck,
  };
}

// Sanitising, against a handful of ownership states.
const STATES = {
  bare: {},
  fanzone3: { clubAssets: { FANZONE: { owned: true, tier: 3 } } },
  fanzone8: { clubAssets: { FANZONE: { owned: true, tier: 8 } } },
  vault: { shop: { purchasedIds: ['style_vault'] } },
  onePack: { club: { lookPacks: ['pack_legend'] } },
  oneItem: { club: { lookItems: ['hat:viking'] } },
  wonCup: { club: { cupLooksWon: ['world_club_cup'] } },
  trophyOnly: { progression: { leagueTrophies: [{ cup: true, division: 'continental_cup' }] } },
};
const DRESSED = {
  build: 'broad', outfit: 'suit', style: 'slick', hair: '#e0559b',
  skin: '#8d5a2b', skinShade: '#6e421c', beard: 'full', hat: 'diamond',
  face: 'monocle', ball: 'classic', neck: 'none',
};
for (const [label, state] of Object.entries(STATES)) {
  const s = m.sanitizeAvatar(state, DRESSED);
  out.sanitized[label] = {
    build: s.build, outfit: s.outfit, style: s.style, hair: s.hair,
    beard: s.beard, hat: s.hat, face: s.face, ball: s.ball,
  };
  out.unlocked[label] = {};
  for (const [kind, ids] of Object.entries(out.ids)) {
    for (const id of ids ?? []) {
      out.unlocked[label][`${kind}:${id}`] = m.isLookUnlocked(state, kind, id);
    }
  }
  out.unlocked[label].packIds = m.unlockedPackIds(state);
  out.unlocked[label].persistentPacks = m.persistentLookPacks(state);
  out.unlocked[label].persistentItems = m.persistentLookItems(state);
}

process.stdout.write(JSON.stringify(out));
