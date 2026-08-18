// Seeded reference output from the JS event-cup engine.
//
// Two things here are order-sensitive enough to be worth pinning whole. The
// draw is a shuffle of a 49-nation pool, so one extra number taken anywhere
// re-seeds every tie that follows it. And the bracket is simulated IN ARREARS —
// seven ties after the player wins the R16, three after the quarter-final, one
// after the semi — each drawing four numbers of its own, so a port that
// advances the bracket at the wrong moment produces a plausible tournament that
// is nowhere near the JS one.
//
// The runs below were picked by seed search rather than by hand: they cover
// winning as the best-rated nation and the worst, a clean sheet across the
// whole bracket, going out in the first round and losing the semi — which is
// every conditional the win branch has.
//
//   node tool/dump_event_cup_reference.mjs > test/fixtures/event_cup_reference.json

const rng = await import('../../merge-empire-fc/src/utils/random.js');
const ec = await import('../../merge-empire-fc/src/engine/eventCupEngine.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

// Wall-clock stamps are the one thing the two runtimes cannot agree on, so they
// are blanked on both sides rather than compared. The tests that care assert
// their SHAPE separately.
const TIME_KEYS = new Set(['startedAt', 'activatedAt', 'lastMatchAt', 'wonAt', 'scoredAt']);
const stripTimes = (v) => {
  if (Array.isArray(v)) return v.map(stripTimes);
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, val] of Object.entries(v)) out[k] = TIME_KEYS.has(k) ? null : stripTimes(val);
    return out;
  }
  return v;
};

// The event is dormant, so `active` is set directly rather than run through
// activateEligibleEvents — that would pin the trigger's clock arithmetic, which
// belongs to the event engine's own fixture.
//
// A Champions-Cup division makes the bounty the biggest number in the file, and
// the eleven t8 cards give the nation-less legacy run a squad rating to fall
// back on.
const makeState = () => ({
  resources: { fanCoins: 0, trophies: 0, matchRevenue: 0 },
  shop: { freeScoutReady: false, luckyBootReady: false, luckyBootUses: 0 },
  grid: {
    cells: Array(24).fill(null).map((_, i) =>
      i < 11 ? { definitionId: 'player_t8_fwd', instanceId: `t8_${i}`, variant: 0, form: 0 } : null,
    ),
  },
  progression: {
    currentDivision: 'champions_cup',
    seasonCount: 1,
    leagueTrophies: [],
    lastMatchAt: 0,
  },
  events: { active: ['wc2026'], progress: {}, history: [], devOverride: null },
});

const out = { state: makeState() };

const preparedOf = (p) => (p === null ? null : {
  eventId: p.eventId, round: p.round, roundName: p.roundName,
  opponentName: p.opponentName, won: p.won, homeGoals: p.homeGoals,
  awayGoals: p.awayGoals, earned: p.earned, squadRating: p.squadRating,
  opponentRating: p.opponentRating, isFinal: p.isFinal,
});

// ── The draw ────────────────────────────────────────────────────────────────
out.draws = {};
for (const [label, seed, nation] of [
  ['argentina', 1234, 'Argentina'],
  ['haiti', 77, 'Haiti'],
  ['noNation', 9, null],
]) {
  rng.setSeed(seed);
  const state = makeState();
  const cup = ec.startEventCup(state, 'wc2026', nation);
  out.draws[label] = {
    seed, nation,
    cup: stripTimes(clone(cup)),
    lastPickedNation: ec.lastPickedNation(state, 'wc2026'),
  };
}

// A second call while a run is live hands back the SAME object rather than
// redrawing — the identity is the point, since a redraw would move the player
// to a different bracket mid-tournament.
rng.setSeed(1234);
{
  const state = makeState();
  const a = ec.startEventCup(state, 'wc2026', 'Argentina');
  const b = ec.startEventCup(state, 'wc2026', 'Brazil');
  out.idempotentDraw = { same: a === b, playerNation: b.playerNation };
}

// ── Whole runs ──────────────────────────────────────────────────────────────
out.runs = {};
for (const [label, seed, nation] of [
  ['argentinaWin', 1, 'Argentina'],
  ['argentinaOutR16', 6, 'Argentina'],
  ['argentinaOutSf', 12, 'Argentina'],
  ['argentinaCleanWin', 56, 'Argentina'],
  ['haitiWin', 31, 'Haiti'],
  ['haitiCleanWin', 155, 'Haiti'],
  ['noNationWin', 12, null],
  ['noNationOut', 2, null],
]) {
  rng.setSeed(seed);
  const state = makeState();
  ec.startEventCup(state, 'wc2026', nation);

  const rounds = [];
  for (let i = 0; i < 5; i++) {
    const prepared = ec.prepareEventCupRound(state, 'wc2026');
    if (!prepared) break;
    const result = ec.commitEventCupRound(state, 'wc2026', prepared.won, prepared);
    rounds.push({
      prepared: preparedOf(prepared),
      result: clone(result),
      coins: state.resources.fanCoins,
      cup: stripTimes(clone(ec.activeEventCup(state, 'wc2026'))),
    });
    const cup = ec.activeEventCup(state, 'wc2026');
    if (cup.eliminated || cup.won) break;
  }

  out.runs[label] = {
    seed, nation, rounds,
    progress: stripTimes(clone(state.events.progress.wc2026)),
    coins: state.resources.fanCoins,
    leagueTrophies: clone(state.progression.leagueTrophies),
  };
}

// ── A second trophy pays nothing ────────────────────────────────────────────
// The gate is a trophy already in `leagueTrophies` tagged with this event, and
// the conditional challenge actions deliberately fire ANYWAY, so a count-based
// challenge keeps accruing on a repeat win.
rng.setSeed(1);
{
  const state = makeState();
  state.progression.leagueTrophies = [
    { name: 'International Cup 2026', cup: true, event: true, eventId: 'wc2026' },
  ];
  ec.startEventCup(state, 'wc2026', 'Argentina');
  const rounds = [];
  for (let i = 0; i < 5; i++) {
    const r = ec.playEventCupRound(state, 'wc2026');
    if (!r) break;
    rounds.push(clone(r));
    const cup = ec.activeEventCup(state, 'wc2026');
    if (cup.eliminated || cup.won) break;
  }
  out.repeatWin = {
    rounds,
    coins: state.resources.fanCoins,
    progress: stripTimes(clone(state.events.progress.wc2026)),
  };
}

// ── The popup's result wins, not the prepared one ───────────────────────────
// A strategy swap mid-tie can flip the outcome, so the commit takes `won` as an
// argument. The scoreline still comes from the prepared draw, which is why a
// flipped loss reads as a win on a losing scoreline.
rng.setSeed(6);
{
  const state = makeState();
  ec.startEventCup(state, 'wc2026', 'Argentina');
  const prepared = ec.prepareEventCupRound(state, 'wc2026');
  const result = ec.commitEventCupRound(state, 'wc2026', !prepared.won, prepared);
  out.flipped = {
    prepared: preparedOf(prepared),
    result: clone(result),
    cup: stripTimes(clone(ec.activeEventCup(state, 'wc2026'))),
  };
}

// ── Restarting ──────────────────────────────────────────────────────────────
out.restarts = {};
for (const [label, arg] of [
  ['remembered', undefined],
  ['picked', 'Brazil'],
  ['picker', ''],
]) {
  rng.setSeed(6);
  const state = makeState();
  ec.startEventCup(state, 'wc2026', 'Argentina');
  ec.playEventCupRound(state, 'wc2026');   // seed 6 goes out in the R16
  const eliminated = ec.activeEventCup(state, 'wc2026').eliminated;
  const next = arg === undefined
    ? ec.restartEventCup(state, 'wc2026')
    : ec.restartEventCup(state, 'wc2026', arg);
  out.restarts[label] = {
    eliminated,
    next: stripTimes(clone(next)),
    historyLength: (state.events.progress.wc2026.cupHistory ?? []).length,
    lastPickedNation: ec.lastPickedNation(state, 'wc2026'),
    cupAfter: stripTimes(clone(ec.activeEventCup(state, 'wc2026'))),
  };
}

// A run still going cannot be restarted — no rerolling a bracket you don't like
// the look of.
rng.setSeed(6);
{
  const state = makeState();
  const before = ec.startEventCup(state, 'wc2026', 'Argentina');
  const next = ec.restartEventCup(state, 'wc2026');
  out.restartMidRun = {
    next,
    unchanged: ec.activeEventCup(state, 'wc2026') === before,
  };
}

// Restarting from a run that was won remembers the nation that won it, and a
// fresh start over a WON run redraws in place rather than being refused.
rng.setSeed(1);
{
  const state = makeState();
  ec.startEventCup(state, 'wc2026', 'Argentina');
  for (let i = 0; i < 5; i++) {
    if (!ec.playEventCupRound(state, 'wc2026')) break;
    if (ec.activeEventCup(state, 'wc2026').won) break;
  }
  const redrawn = ec.startEventCup(state, 'wc2026', 'Brazil');
  out.startOverWonRun = {
    playerNation: redrawn.playerNation,
    round: redrawn.round,
    results: redrawn.results.length,
    historyLength: (state.events.progress.wc2026.cupHistory ?? []).length,
  };
}

// ── The guards ──────────────────────────────────────────────────────────────
out.guards = (() => {
  const idle = makeState();
  idle.events.active = [];
  const noCupEvent = makeState();
  noCupEvent.events.active = ['deadline_day'];

  const started = makeState();
  ec.startEventCup(started, 'wc2026', 'Argentina');
  const elim = makeState();
  ec.startEventCup(elim, 'wc2026', 'Argentina');
  ec.activeEventCup(elim, 'wc2026').eliminated = true;

  const fresh = makeState();

  return {
    startInactive: ec.startEventCup(idle, 'wc2026', 'Argentina'),
    startUnknownEvent: ec.startEventCup(makeState(), 'nope', 'Argentina'),
    startEventWithoutCup: ec.startEventCup(noCupEvent, 'deadline_day'),
    prepareInactive: ec.prepareEventCupRound(idle, 'wc2026'),
    prepareNoCup: ec.prepareEventCupRound(fresh, 'wc2026'),
    prepareEliminated: ec.prepareEventCupRound(elim, 'wc2026'),
    playNoCup: ec.playEventCupRound(makeState(), 'wc2026'),
    playEliminated: ec.playEventCupRound(elim, 'wc2026'),
    commitNoPrepared: ec.commitEventCupRound(started, 'wc2026', true, null),
    restartInactive: ec.restartEventCup(idle, 'wc2026'),
    activeOnEmptyState: ec.activeEventCup({}, 'wc2026'),
    lastPickedOnEmptyState: ec.lastPickedNation({}, 'wc2026'),
    // A run started with no nation must not be remembered as one.
    lastPickedAfterNoNation: (() => {
      const s = makeState();
      ec.startEventCup(s, 'wc2026', null);
      return ec.lastPickedNation(s, 'wc2026');
    })(),
  };
})();

process.stdout.write(JSON.stringify(out));
