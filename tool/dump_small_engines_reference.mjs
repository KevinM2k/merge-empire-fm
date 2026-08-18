// Reference output from three small engines that share one fixture because
// none of them is big enough to earn its own: the rewarded-ad frequency gate,
// the shirt badge, and the look-pack shop tile.
//
// What each is worth pinning FOR is different. The ad gate is a rolling window
// and a countdown that has to round the right way — a label reading 0:00 while
// the gate is still shut is a button that lies. The badge is an ordering: newest
// for the auto-equip, oldest-first for the picker, off the same list. And the
// look tile is a deliberate simplification of an older design, so the thing to
// pin is what it no longer does — no free-video status, no countdown.
//
//   node tool/dump_small_engines_reference.mjs > test/fixtures/small_engines_reference.json

const ag = await import('../../merge-empire-fc/src/engine/adGateEngine.js');
const be = await import('../../merge-empire-fc/src/engine/badgeEngine.js');
const lp = await import('../../merge-empire-fc/src/engine/lookPackEngine.js');
const { LOOK_PACKS } = await import('../../merge-empire-fc/src/data/managerAvatar.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

const NOW = 1700000000000;
const MIN = 60 * 1000;

const out = {};

// ── The ad gate ─────────────────────────────────────────────────────────────
out.adGate = { limit: ag.AD_PACK_LIMIT, windowMs: ag.AD_PACK_WINDOW_MS, now: NOW };

const AD_STATES = {
  none: {},
  noAdsBranch: null,
  emptyList: { ads: { packUnlocks: [] } },
  notAList: { ads: { packUnlocks: 'nonsense' } },
  oneRecent: { ads: { packUnlocks: [NOW - MIN] } },
  twoRecent: { ads: { packUnlocks: [NOW - 2 * MIN, NOW - MIN] } },
  full: { ads: { packUnlocks: [NOW - 3 * MIN, NOW - 2 * MIN, NOW - MIN] } },
  // Out of order on disk, in order coming back.
  unsorted: { ads: { packUnlocks: [NOW - MIN, NOW - 4 * MIN, NOW - 2 * MIN] } },
  // One has aged out, so the window is not full after all.
  oneAgedOut: { ads: { packUnlocks: [NOW - 6 * MIN, NOW - 2 * MIN, NOW - MIN] } },
  allAgedOut: { ads: { packUnlocks: [NOW - 9 * MIN, NOW - 8 * MIN, NOW - 7 * MIN] } },
  // Exactly on the boundary: the window is `< WINDOW_MS`, so this one is out.
  exactlyAtTheEdge: { ads: { packUnlocks: [NOW - ag.AD_PACK_WINDOW_MS, NOW - MIN, NOW - 2 * MIN] } },
  rubbishStamps: { ads: { packUnlocks: [null, 'soon', NaN, Infinity, NOW - MIN] } },
};

out.adGate.rows = [];
for (const [label, state] of Object.entries(AD_STATES)) {
  out.adGate.rows.push({
    label,
    recent: ag.recentPackAds(state, NOW),
    remaining: ag.packAdsRemaining(state, NOW),
    canWatch: ag.canWatchPackAd(state, NOW),
    msUntil: ag.msUntilPackAd(state, NOW),
  });
}

out.adGate.record = [];
{
  const state = {};
  for (let i = 0; i < 5; i++) {
    ag.recordPackAd(state, NOW + i * MIN);
    out.adGate.record.push({
      i,
      ads: clone(state.ads),
      remaining: ag.packAdsRemaining(state, NOW + i * MIN),
      msUntil: ag.msUntilPackAd(state, NOW + i * MIN),
    });
  }
}
// A null state is a no-op rather than a throw.
out.adGate.recordNullState = (() => {
  ag.recordPackAd(null, NOW);
  return true;
})();

out.adGate.format = [0, 1, 999, 1000, 1001, 9000, 60000, 60001, 161000, 300000, -5]
  .map((ms) => ({ ms, label: ag.formatAdWait(ms) }));

// ── The badge ───────────────────────────────────────────────────────────────
const ach = (id, unlockedAt) => ({ id, unlockedAt, count: 1 });

const BADGE_STATES = {
  fresh: {},
  noAchievements: { progression: { achievements: [] } },
  three: {
    progression: {
      achievements: [
        ach('first_merge', 3000),
        ach('first_win', 1000),
        ach('coins_1k', 2000),
      ],
    },
  },
  // Same instant: the tie has to break the same way both sides.
  tied: {
    progression: {
      achievements: [ach('first_merge', 1000), ach('first_win', 1000)],
    },
  },
  // A stamp missing entirely reads as zero.
  unstamped: {
    progression: { achievements: [ach('first_merge', undefined), ach('first_win', 5000)] },
  },
  // An id nothing in the catalogue matches is dropped from the choices.
  unknownId: {
    progression: { achievements: [ach('not_an_achievement', 9000), ach('first_win', 1000)] },
  },
  alreadyChosen: {
    progression: {
      equippedBadgeId: 'first_win',
      badgeManuallySet: true,
      achievements: [ach('first_merge', 3000), ach('first_win', 1000)],
    },
  },
};

out.badge = { defaultId: be.DEFAULT_BADGE_ID, rows: [] };
for (const [label, base] of Object.entries(BADGE_STATES)) {
  const state = clone(base);
  const latest = be.getLatestUnlockedAchievement(state);
  const changed = be.autoEquipLatestBadge(state);
  out.badge.rows.push({
    label,
    equippedBefore: be.getEquippedBadgeId(clone(base)),
    latest: latest?.id ?? null,
    choices: be.getBadgeChoices(clone(base)).map((a) => a.id),
    autoEquipChanged: changed,
    equippedAfter: be.getEquippedBadgeId(state),
    progression: clone(state.progression ?? null),
  });
}

// Auto-equip a second time changes nothing — the badge is already the newest.
out.badge.autoTwice = (() => {
  const state = clone(BADGE_STATES.three);
  const first = be.autoEquipLatestBadge(state);
  const second = be.autoEquipLatestBadge(state);
  return { first, second, equipped: be.getEquippedBadgeId(state) };
})();

out.badge.setEquipped = [];
for (const [label, base, badgeId] of [
  ['theDefault', BADGE_STATES.three, be.DEFAULT_BADGE_ID],
  ['anUnlockedOne', BADGE_STATES.three, 'first_win'],
  ['oneNotUnlocked', BADGE_STATES.three, 'prestige_level_10'],
  ['nonsense', BADGE_STATES.three, 'not_an_achievement'],
  ['onABareSave', {}, be.DEFAULT_BADGE_ID],
]) {
  const state = clone(base);
  const ok = be.setEquippedBadge(state, badgeId);
  out.badge.setEquipped.push({
    label, badgeId, ok,
    valid: be.isValidBadgeId(clone(base), badgeId),
    progression: clone(state.progression ?? null),
    // Once set by hand, the auto-equip stops tracking.
    autoAfter: be.autoEquipLatestBadge(state),
  });
}
out.badge.setOnNullState = be.setEquippedBadge(null, 'first_win');

// ── The look-pack tile ──────────────────────────────────────────────────────
const PACK_IDS = LOOK_PACKS.map((p) => p.id);
out.lookPack = { packIds: PACK_IDS, rows: [] };

for (const packId of [...PACK_IDS, 'not_a_pack']) {
  const pack = LOOK_PACKS.find((p) => p.id === packId);
  const cases = {
    // Nothing owned at all.
    none: {},
    // The whole pack, bought outright.
    packOwned: { club: { lookPacks: [packId] } },
    // One item, the way a video buys one.
    oneItem: { club: { lookItems: pack ? [pack.items[0]] : [] } },
    // Every item, one at a time — which is the same as owning the pack.
    everyItem: { club: { lookItems: pack ? [...pack.items] : [] } },
  };
  for (const [label, state] of Object.entries(cases)) {
    out.lookPack.rows.push({ packId, label, tile: lp.lookTileState(state, packId, NOW) });
  }
}
out.lookPack.nullState = lp.lookTileState(null, PACK_IDS[0], NOW);

process.stdout.write(JSON.stringify(out));
