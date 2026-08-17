// Seeded reference output from the JS negotiation engine.
//
// Both sides of every deal speak the same shape — `{ cash, players, incoming }` —
// and both are judged by the same `offerValue`. That symmetry is the whole design
// claim: a deal that reads as fair IS fair, with no hidden multiplier favouring
// either side. A port that gets one of the two valuations subtly wrong breaks the
// claim without breaking anything visible, so both directions are pinned here.
//
// The RNG-heavy half (rollDealCard, buildRivalOffer, pickBidTarget) draws from the
// seeded stream in an order that decides WHICH card arrives, so whole rolls are
// compared rather than their summary numbers.
//
//   node tool/dump_negotiation_reference.mjs > test/fixtures/negotiation_reference.json

import { readFileSync } from 'node:fs';

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

// `rollDealCard` mixes BOTH generators: the gender roll and the trait-chance roll
// come off the seeded stream, while the variant, the rating spread, the ATK/DEF
// ratio and the trait itself come off bare Math.random (createInstance and
// rollTrait). So the unseeded one is pinned too — same second mulberry32 the
// match-orchestration dump uses. On the Dart side ONE JsMathRandom instance feeds
// merge_engine and trait_engine, because here there is only one Math.random.
let mathSeed = 1;
Math.random = () => {
  mathSeed |= 0;
  mathSeed = (mathSeed + 0x6d2b79f5) | 0;
  let t = Math.imul(mathSeed ^ (mathSeed >>> 15), 1 | mathSeed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const setMathSeed = (s) => { mathSeed = s; };

// The instance id embeds a module counter that depends on how many cards each
// runtime happened to have built already — nothing about the deal. Dropped here,
// and its SHAPE asserted separately on the Dart side.
const stripId = (card) => {
  if (!card) return card;
  const { instanceId, ...rest } = card;
  return rest;
};

const rng = await import('../../merge-empire-fc/src/utils/random.js');
const ne = await import('../../merge-empire-fc/src/engine/negotiationEngine.js');
const nd = await import('../../merge-empire-fc/src/data/negotiation.js');
const ie = await import('../../merge-empire-fc/src/engine/idleEngine.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

const baseState = (over = {}) => {
  const s = clone(questRef.state);
  s.resources.fanCoins = 500000;
  for (const [k, v] of Object.entries(over)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && s[k] && typeof s[k] === 'object') {
      Object.assign(s[k], v);
    } else {
      s[k] = v;
    }
  }
  return s;
};

/// A squad with a known spread of tiers, so weighting and valuation both have
/// something to separate.
const pos = ['gk', 'def', 'def', 'mid', 'mid', 'mid', 'fwd', 'fwd', 'def', 'mid', 'fwd', 'mid', 'def'];

const tieredSquad = (tiers) => {
  const s = baseState();
  s.grid.cells = s.grid.cells.map((c, i) => {
    if (!c || i >= tiers.length) return null;
    return { ...c, definitionId: `player_t${tiers[i]}_${pos[i]}` };
  });
  return s;
};

/// A grid filled right up to getMaxPlayers, which the reference save is nowhere
/// near — it holds 15 cards against a roster of 30.
const cappedSquad = () => {
  const s = baseState();
  const max = ie.getMaxPlayers(s);
  s.grid.cells = Array.from({ length: max }, (_, i) => ({
    instanceId: `f${i}`,
    definitionId: `player_t${1 + (i % 6)}_${pos[i % pos.length]}`,
    seasonsPlayed: 0,
  }));
  s.squad.lineup = s.squad.lineup.map((l, i) => ({ ...l, cardInstanceId: `f${i}` }));
  return s;
};

const out = { fixedNow: FIXED_NOW, constants: { ...nd } };

// ── valuation, and the symmetry that rests on it ──────────────────────────
out.playerValue = [];
for (const tier of [1, 2, 4, 6, 8]) {
  for (const seasons of [0, 8, 14]) {
    for (const sponsor of [null, { multiplier: 1.5 }]) {
      for (const division of ['sunday_league', 'regional_league', 'champions_cup']) {
        const s = baseState({ progression: { currentDivision: division } });
        const card = { instanceId: 'x', definitionId: `player_t${tier}_mid`,
          seasonsPlayed: seasons, sponsor };
        out.playerValue.push({
          tier, seasons, sponsored: sponsor != null, division,
          value: ne.playerValue(s, card),
        });
      }
    }
  }
}

// An offer's worth: cash, OUR players by id, and THEIR pre-rolled cards. All
// three add on the same scale, which is what makes a swap unarbitrageable
// against a sale.
out.offerValue = [];
{
  const s = tieredSquad([3, 3, 4, 5, 6, 3, 4, 7, 3, 4, 5, 3, 4]);
  const incoming = { instanceId: 'inc', definitionId: 'player_t5_fwd', seasonsPlayed: 0 };
  for (const offer of [
    null,
    {},
    { cash: 0 },
    { cash: -50 },
    { cash: 1000 },
    { cash: 1000, players: ['c0'] },
    { cash: 1000, players: ['c0', 'c7'] },
    { cash: 0, players: ['unknown'] },
    { cash: 500, incoming: [incoming] },
    { cash: 500, players: ['c7'], incoming: [incoming] },
  ]) {
    out.offerValue.push({ offer, value: ne.offerValue(s, offer) });
  }
  out.describeOffer = ne.describeOffer(s, {
    cash: 1000, players: ['c0', 'nope'], incoming: [incoming],
  }).map((p) => ({ kind: p.kind, amount: p.amount ?? null, name: p.name ?? null, value: p.value ?? null }));
}

// ── the transfer list ─────────────────────────────────────────────────────
out.listing = [];
for (const [label, build, instanceId] of [
  ['plain', () => baseState(), 'c5'],
  ['unknown', () => baseState(), 'nope'],
  ['alreadyListed', () => { const s = baseState(); s.grid.cells[5].listed = true; return s; }, 'c5'],
  ['loanCard', () => { const s = baseState(); s.grid.cells[5].loanMatchesLeft = 4; return s; }, 'c5'],
  ['lastPlayer', () => {
    const s = baseState();
    s.grid.cells = s.grid.cells.map((c, i) => (i === 0 ? c : null));
    return s;
  }, 'c0'],
]) {
  const s = build();
  const result = ne.listPlayer(s, instanceId);
  out.listing.push({
    label, instanceId,
    ok: result.ok, reason: result.reason ?? null,
    card: result.card ? { listed: result.card.listed ?? null, listedAt: result.card.listedAt ?? null } : null,
    lineup: clone(s.squad.lineup),
    usable: ne.usableCards(s).map((c) => c.instanceId),
    listedCards: ne.listedCards(s).map((c) => c.instanceId),
  });
}

out.unlisting = (() => {
  const s = baseState();
  ne.listPlayer(s, 'c5');
  const before = { listed: s.grid.cells[5].listed, listedAt: s.grid.cells[5].listedAt };
  const result = ne.unlistPlayer(s, 'c5');
  return {
    before,
    ok: result.ok,
    hasListed: 'listed' in s.grid.cells[5],
    hasListedAt: 'listedAt' in s.grid.cells[5],
    unknown: (() => { const r = ne.unlistPlayer(s, 'nope'); return { ok: r.ok, reason: r.reason }; })(),
  };
})();

// ── the AI's side ─────────────────────────────────────────────────────────
out.traitChanceForTier = Object.fromEntries(
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map((t) => [t, ne.traitChanceForTier(t)]),
);

// A whole rolled card, not a summary: the name, the variant, the ATK/DEF split
// and any trait all come off the same seeded sequence.
out.rollDealCard = [];
for (const tier of [1, 3, 5, 8]) {
  for (const seed of [1, 42, 777]) {
    rng.setSeed(seed);
    setMathSeed(seed * 5 + 3);
    const pool = (await import('../../merge-empire-fc/src/data/players.js')).getPlayersByTier(tier);
    const def = pool[0];
    out.rollDealCard.push({
      tier, seed, mathSeed: seed * 5 + 3, defId: def.id,
      card: stripId(ne.rollDealCard(def)),
    });
  }
}
out.rollDealCardNull = ne.rollDealCard(null);

// What a rival puts on the table. The mixed-offer branch is the interesting one:
// it has to respect how many of their players we could actually house.
out.buildRivalOffer = [];
// Seeds 12 and 24 are the two-incoming-player branch; the rest spread across
// cash-only and single-player offers.
for (const seed of [1, 2, 3, 5, 8, 12, 13, 21, 24, 34, 55, 86, 89, 118, 144, 233]) {
  for (const [label, build] of [
    ['room', () => tieredSquad([3, 4, 5, 3, 4, 6, 3])],
    // Three cards, so there is room for anything they offer.
    ['roomy', () => tieredSquad([3, 4, 5])],
    // A squad at getMaxPlayers, so the ONLY space is the cell the outgoing
    // player vacates and a two-player swap has to be cut to one. Offering more
    // than we can house was a quiet robbery: the accept path drops what it
    // cannot place and pays only the cash.
    ['capped', () => cappedSquad()],
  ]) {
    rng.setSeed(seed);
    setMathSeed(seed + 100);
    const s = build();
    const target = s.grid.cells[2];
    const offer = ne.buildRivalOffer(s, target, 50000);
    out.buildRivalOffer.push({
      seed, mathSeed: seed + 100, label,
      maxPlayers: ie.getMaxPlayers(s),
      occupied: s.grid.cells.filter(Boolean).length,
      cash: offer.cash,
      incoming: offer.incoming.map(stripId),
      value: ne.offerValue(s, offer),
    });
  }
}
// No target definition at all — a cash deal, and no draw wasted looking.
out.buildRivalOfferNoDef = (() => {
  rng.setSeed(9);
  setMathSeed(9);
  const s = tieredSquad([3, 4, 5]);
  const offer = ne.buildRivalOffer(s, { definitionId: 'nope' }, 1234);
  return { cash: offer.cash, incoming: offer.incoming.length };
})();

// Who a rival comes in for. Listing is meant to visibly work without becoming
// the only answer, so the DISTRIBUTION is what matters.
out.pickBidTarget = [];
for (const seed of [1, 7, 99]) {
  for (const [label, build, opts] of [
    ['plain', () => tieredSquad([3, 4, 5, 3, 4, 6, 3]), {}],
    ['minTier6', () => tieredSquad([3, 4, 5, 3, 4, 6, 3]), { minTier: 6 }],
    ['minTier9', () => tieredSquad([3, 4, 5, 3, 4, 6, 3]), { minTier: 9 }],
    ['excluded', () => tieredSquad([3, 4, 5, 3, 4, 6, 3]), { exclude: new Set(['c5']) }],
    ['injured', () => { const s = tieredSquad([3, 4, 5, 3, 4, 6, 3]); s.grid.cells[5].injured = true; return s; }, {}],
    ['loanee', () => { const s = tieredSquad([3, 4, 5, 3, 4, 6, 3]); s.grid.cells[5].loanMatchesLeft = 3; return s; }, {}],
    ['listed', () => { const s = tieredSquad([3, 4, 5, 3, 4, 6, 3]); s.grid.cells[0].listed = true; return s; }, {}],
    ['sponsored', () => { const s = tieredSquad([3, 4, 5, 3, 4, 6, 3]); s.grid.cells[0].sponsor = { multiplier: 1.5 }; return s; }, {}],
  ]) {
    rng.setSeed(seed);
    const s = build();
    const pick = ne.pickBidTarget(s, opts);
    out.pickBidTarget.push({
      seed, label,
      opts: { minTier: opts.minTier ?? null, exclude: [...(opts.exclude ?? [])] },
      picked: pick?.card?.instanceId ?? null,
    });
  }
}
// The listed weighting, measured rather than asserted: with one of an otherwise
// equal squad listed, listing should visibly work and still leave room for a
// rival to want somebody else.
out.listedDraw = (() => {
  rng.setSeed(4242);
  const s = tieredSquad(Array(10).fill(4));
  s.grid.cells[3].listed = true;
  let hits = 0;
  const runs = 4000;
  for (let i = 0; i < runs; i++) {
    if (ne.pickBidTarget(s)?.card?.instanceId === 'c3') hits++;
  }
  return { runs, hits };
})();

out.listedPremium = {
  listed: ne.listedPremium({ listed: true }),
  plain: ne.listedPremium({}),
  nullCard: ne.listedPremium(null),
};

// ── evaluating counters ───────────────────────────────────────────────────

// We hold a bid and want more. Four outcomes, and one of them ends the deal —
// which is the only reason haggling has a downside.
out.evaluateAsk = [];
{
  const s = baseState();
  for (const listing of [
    { price: 10000, askAnchor: 10000, askCeilingMult: 1.35 },
    { price: 10000, askAnchor: 10000, askCeilingMult: 1.53 },
    { price: 10000, askAnchor: 10000, askCeilingMult: 1.17 },
    { price: 10000, askAnchor: 10000, askCeilingMult: 1.35, haggled: true },
    { price: 13500, askAnchor: 10000, askCeilingMult: 1.35 },
    { price: 10000 },
    {},
  ]) {
    for (const ask of [null, 0, -100, 5000, 10000, 10001, 12000, 13500, 13501,
      15000, 18000, 19000, 19001, 25000]) {
      const r = ne.evaluateAsk(s, listing, ask);
      out.evaluateAsk.push({ listing, ask, outcome: r.outcome, price: r.price });
    }
  }
}

// We want to buy and we're offering something other than the asking price. The
// seller answers the same three ways a buyer does.
out.evaluateOurOffer = [];
{
  const s = tieredSquad([3, 4, 5, 3, 4, 6, 3]);
  for (const listing of [
    { price: 10000, offerAnchor: 10000, offerMinMult: 0.88, haggleRounds: 1 },
    { price: 10000, offerAnchor: 10000, offerMinMult: 1.00, haggleRounds: 1 },
    { price: 10000, offerAnchor: 10000, offerMinMult: 0.80, haggleRounds: 0 },
    { price: 10000, offerAnchor: 10000, offerMinMult: 0.88, haggleRounds: 3, haggleUsed: 3 },
    { price: 10000, offerAnchor: 10000, offerMinMult: 0.88, haggleRounds: 3, sellerCounter: 9000 },
    { price: 10000 },
    {},
  ]) {
    for (const offer of [
      { cash: 0 },
      { cash: 5000 },
      { cash: 6200 },
      { cash: 6300 },
      { cash: 8800 },
      { cash: 10000 },
      { cash: 20000 },
      { cash: 5000, players: ['c5'] },
      null,
    ]) {
      const r = ne.evaluateOurOffer(s, listing, offer);
      out.evaluateOurOffer.push({
        listing, offer,
        outcome: r.outcome, value: r.value, needed: r.needed,
        shortfall: r.shortfall, counterPrice: r.counterPrice,
      });
    }
  }
}

// ── handing players over ──────────────────────────────────────────────────
out.surrenderPlayers = [];
for (const [label, ids] of [
  ['none', []],
  ['one', ['c5']],
  ['two', ['c5', 'c7']],
  ['unknown', ['nope']],
  ['mixed', ['c5', 'nope']],
]) {
  const s = baseState();
  const gone = ne.surrenderPlayers(s, { players: ids });
  out.surrenderPlayers.push({
    label, ids,
    gone: gone.map((c) => c.instanceId),
    cells: s.grid.cells.map((c) => c?.instanceId ?? null),
    lineup: s.squad.lineup.map((l) => l.cardInstanceId ?? null),
  });
}
out.surrenderNullOffer = (() => {
  const s = baseState();
  return { gone: ne.surrenderPlayers(s, null).length };
})();

process.stdout.write(JSON.stringify(out));
