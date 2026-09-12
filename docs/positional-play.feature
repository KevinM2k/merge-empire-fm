# Positional Match Simulation

## Context

The match sim currently turns two teams into a scoreline with two independent
Poisson draws:

```
homeGoals = poissonGoals(goalRateLambda(ourAtk, theirDef) * variance)
awayGoals = poissonGoals(goalRateLambda(theirAtk, ourDef) * variance)
```

`goalRateLambda` (`lib/engine/goal_model.dart:119-133`) is the Bradley-Terry
model: `atkProb = a⁴/(a⁴+b⁴)`, normalised so an even match yields
`evenMatchLambda = 1.35` per side, with a soft cap at 2.8 and a floor at 0.12.
Team ATK/DEF come from `computeSquadRatings` (`lib/engine/squad_rating.dart:236`)
— a position-weighted mean of eleven FIFA splits using `attackWeights` /
`defenceWeights` (`lib/engine/match_tactics.dart:91-103`).

**Nothing in the sim knows where anyone is standing.** `FormationSlot.x/y`
exists and `lib/data/formations.dart:72` says outright: *"The numbers are
display-only — nothing in the sim reads `x` or `y`."* The only spatial notions
are four position buckets (`attackWeights`, `computePositionPenalty`,
`goalScorerWeights`). The chance/corner feed in `match_events.dart:279-307` is
generated **after** the score is decided, purely as decoration, and which side
gets a given chance is drawn from the *unseeded* RNG.

The goal is a spatial layer on top: attacks start in a zone, a specific attacker
faces a specific defender, a Bradley-Terry duel decides whether the move
progresses, and chances emerge from that chain — producing real heatmaps and
real post-match analysis, without breaking the balance the existing model has.

**One correction to the brief:** the sim produces ~13 chances a match, not
10–11 — `chanceCount = floor(span/7 + 0.5)` at `match_events.dart:283`. The
target to preserve is 13.

## Decisions taken

| Question | Decision |
|---|---|
| Scope | Full Phase 1–7 roadmap, staged as separately-shippable commits |
| Goal source | λ calibrates, positions distribute (see **The calibration bridge**) |
| Results | Change immediately — one code path, no flag |
| JS parity | **Retire the JS match fixtures**, replace with Dart-owned goldens |
| UI | Post-match heatmap, match analysis text, side-bias tactics control |

---

## Architecture

Five new pure-Dart engine files. All must be Flutter-free
(`test/architecture_test.dart:12-45`).

| File | Role |
|---|---|
| `lib/engine/pitch_space.dart` | The zone grid, coordinate frame, lane/band helpers |
| `lib/engine/pitch_influence.dart` | Per-player attacking/defensive influence maps |
| `lib/engine/attack_sequence.dart` | The zone → attacker → defender → duel → progress loop |
| `lib/engine/match_analysis.dart` | Aggregates the recorded event stream into heatmaps and stats |
| `lib/data/player_roles.dart` | Phase 6 roles (data only) |

Flow, replacing the two `simulateGoals` calls at
`match_orchestration.dart:898-901`:

```
computeSquadRatings ──► team ATK/DEF ──► goalRateLambda ──► λ per side  (UNCHANGED)
                                                              │
lineup + formation ──► influence maps ──► attack sequences ──► Σ raw xG
                                                              │
                                          scale so Σ xG == λ  ◄┘
                                                              │
                              Bernoulli per shot ──► goals + recorded event stream
```

### Coordinate frame

Reuse `FormationSlot.x/y` rather than inventing a second set of coordinates —
`x` 0–100 across, `y` 0–100 with **100 = own goal line** (GK is at y:90).
Attacking direction is toward y=0. The opponent's shape is mirrored into the
same absolute frame (`x → 100-x`, `y → 100-y`).

Grid: **5 lanes × 4 bands = 20 zones**. Lanes collapse to three flanks
(left / centre / right) for analysis copy.

> ⚠️ **Verify the x-axis handedness before anything else.** `rb` sits at x:14
> and `lb` at x:86 in every shape (`formations.dart:82-85`). For a team
> attacking up the screen, screen-left is that team's *left*, so either the slot
> ids are mirrored relative to x, or x is measured from the team's own right.
> The whole feature says "your RW against their LB" and the analysis says
> "you attacked down the right 48%" — getting this backwards ships a screen that
> lies. Settle it in Phase 1, state the convention in the `pitch_space.dart`
> header, and pin it with a test in `test/data/formations_test.dart`.

### Influence maps

`InfluenceMap` = 20 normalised zone weights. Built from a slot's (x, y) with an
anisotropic Gaussian — wider across than up-pitch — around two anchors:

- **attacking anchor** = slot point pushed toward goal by `attackWeights[pos] × pushUp`
- **defensive anchor** = slot point dropped back by `defenceWeights[pos] × dropBack`

Total magnitude scales with `attackWeights[pos]` / `defenceWeights[pos]` from
`match_tactics.dart:91-103` — **reused, not re-tabulated**, so team ATK/DEF and
zone influence stay derived from one table and cannot drift. A GK gets zero
attacking influence for free.

Roles (Phase 6) and tactics (Phase 5) move the **anchor and σ**, never the
rating — the brief's core requirement.

### The attack sequence

```dart
SequenceOutcome runSequence(SequenceContext ctx, int minute)
  zone     = weightedPick(startZoneWeights)          // side bias × our attacking mass
  carrier  = weightedPick(our attacking influence in zone, weighted by ATK)
  for step in 0..maxSteps(4):
    defender = weightedPick(their defensive influence in zone, weighted by DEF)
    support  = Σ other defenders' influence in zone
    effDef   = defender.def + supportCoeff × support        // Phase 7; coeff 0 until then
    p        = duelProbability(carrier.atk, effDef)
    record(minute, zoneCentre, carrier, type, outcome)
    if roll < p → advance a band toward goal, maybe switch lane, maybe hand off carrier
    else        → turnover, sequence ends
    if in the final third → shot, raw xG from zone quality × carrier ATK
```

`duelProbability(a, b)` goes in `goal_model.dart` beside `goalRateLambda`, using
a **separate, flatter exponent**: `winProbExponent = 4.0` makes a 90-vs-55 duel
an 87% win, which is far too deterministic step to step. Start at
`duelExponent = 2.0` and tune against the balance suite.

Every step appends to the recorded stream — heatmaps emerge from the sim rather
than needing a system of their own.

### The calibration bridge

Per side, per window (the injury-split and Pro-mode segment paths keep their
existing window structure):

1. `λ = goalRateLambda(adjAtk, effOppDef) × variance` — **unchanged**, so home
   advantage, stagnation, relegation resilience, tactic multipliers, the soft
   cap, the floor and the swing all keep working exactly as they do today.
2. Run the sequences; collect raw xG per shot.
3. `k = λ / Σ rawXg`; scale every shot. Guard `Σ rawXg == 0` by falling back to
   `poissonGoals(λ)`.
4. One Bernoulli per shot. **Expected goals equal λ exactly.**

Why this satisfies "enhance, don't destroy": a great RW wins more duels, so he
takes more and better shots and scores a larger share — but eleven stars cannot
break the goals-per-match curve, because the curve is still λ. The
all-out-attack exploit that `lambdaCurveExp = 1.0` was introduced to kill
(`goal_model.dart:76-84`) cannot come back through this door.

**Known consequence, to measure not assume:** a Poisson-binomial is slightly
*under*-dispersed relative to Poisson at the same mean, so draws may tick up and
blowouts down by a point or two. The balance suite below measures it; if the
draw rate moves more than ~1.5pt, jitter `k` per match to restore the spread.

### Recording and the save

`result['positional']`, plain JSON only — `MatchResult` is a
`Map<String, dynamic>` and **a Dart record in it throws on `jsonEncode`** when a
cup result goes into the save (`match_orchestration.dart:63`).

```
{ 'ev': [{'m','x','y','p','op','t','o'}, …],     // raw, in-memory only
  'zone': {'ours': [20], 'theirs': [20]},
  'flank': {'ours': {...}, 'theirs': {...}},
  'duels': {instanceId: {'w': int, 'l': int}} }
```

The raw `ev` list must be **stripped before the result reaches the save** —
`lastMatchResult` and cup results persist, and ~150 events per match across a
season is real save bloat. Aggregates persist; raw events live only on the
in-memory result the summary screen reads.

### Opponents

The AI has no squad. `aiFormationPositions` (`match_tactics.dart:128-134`) is a
bare position list with no coordinates. Add `aiFormationSlots` reusing
`formations[...]` coordinates where the id matches (4-3-3, 4-4-2, 5-3-2) and
adding 3-4-3 and 5-4-1. Synthesise eleven pseudo-players at
`getCardAtkDefSplit(_posRatio[pos], rating)` — the same call
`teamSplitForFormation` already makes, so their per-player numbers and their
team ATK/DEF stay consistent by construction.

### Stay on the cheap path

These must keep calling `goalRateLambda` directly and never run sequences:

- `season_fixtures.dart:49` AI-vs-AI background results (hundreds per matchday)
- `bestFormationForFixture` (`match_orchestration.dart:484`) — scores 5 shapes
- `tactic_coach.dart` `tacticExpectedPoints`
- `fixture_preview.dart`, `poissonPmf` quest projections

---

## Phases

Each phase is one commit on `claude/positional-match-simulation-croeq6`, with
`flutter analyze` clean and `flutter test` green before it lands.

**Phase 1 — Pitch space and influence.** `pitch_space.dart`,
`pitch_influence.dart`. Settle the x-axis handedness. Add `aiFormationSlots`.
No behaviour change; tests assert influence sums, GK zero attacking mass, and
that a 4-3-3 winger's peak zone is the attacking wide band.

**Phase 2 — The duel primitive.** `duelProbability` in `goal_model.dart`, plus
zone-local attacker/defender selection. Still not wired to results. Tests pin
the probability curve and that selection favours the right players.

**Phase 3 — Spatial attacks, wired in.** `attack_sequence.dart`, the calibration
bridge, the recorded stream, and the swap in `simulateMatch`,
`resolveSegmented` and `_simulateHardGoals`. **Results change here.** Update the
draw-order header at `match_orchestration.dart:12-17` — it is the specification
and it is about to be wrong. Sequence draws go on the **seeded** stream: they
decide the score now.

**Phase 3b — The replacement test net.** See below. Its own commit; it is the
largest single piece of work in the plan.

**Phase 4 — Heatmaps.** `match_analysis.dart` aggregation +
`lib/ui/screens/match/match_heatmap.dart`, drawn over the existing pitch
markings. `_PitchPainter` in `squad_pitch.dart:99` is private — **extract it,
don't copy it** (CLAUDE.md's reuse rule). Colours from
`Theme.of(context).extension<KitTheme>()!`. Card on `match_summary.dart`.

**Phase 5 — Side bias.** `state['squad']['attackSide']` (`'left' | 'centre' |
'right' | 'balanced'`), defaulted in `state_schema.dart:138` with a migration.
A `showSidePicker` in `squad_pickers.dart` alongside the formation and tactic
pickers. Feeds `startZoneWeights`; 15/25/60 for a committed side, per the brief.

**Phase 6 — Roles.** `lib/data/player_roles.dart`, `state['squad']['roles']` as
slotId → roleId. Start with three on wide slots — Winger, Inside Forward, Wide
Playmaker — each shifting the influence anchor, none touching ratings.

**Phase 7 — Defensive support.** Raise `supportCoeff` off zero. The hook lands
in Phase 3 so turning it on is a constant and a tuning pass, not a refactor. Use
a saturating combination (not a sum) so a crowded zone cannot manufacture a
defender better than any real player.

---

## Phase 3b — replacing the JS parity net

Retiring `match_orchestration_reference.json` (50 scenarios) and
`season_difftest.json` (6 seasons × 336 matches) removes the strongest
regression net in the repo. Three things replace it.

**1. Dart-owned goldens.** `tool/dump_positional_golden.dart`, run with
`dart run` — **not node**, so it regenerates from a cloud container, which the
`.mjs` dumpers cannot. It replays the same scenario set and the same six seasons
through the Dart engine and writes `test/fixtures/positional_golden.json` and
`test/fixtures/positional_season_golden.json`. Reuse the canonicalisation in
`test/support/canonical.dart` and mirror `tool/difftest/canonical.mjs` so the
save digests mean the same thing. `test/engine/match_orchestration_parity_test.dart`
and `test/difftest/season_difftest_test.dart` are rewritten against these.

> A self-generated golden catches regressions, not correctness — it will happily
> pin a bug. That is why (2) is not optional.

**2. A balance suite** — `test/engine/positional_balance_test.dart`, the thing a
golden structurally cannot do. Over ~20k simulated matches across rating pairs:

- λ conservation: `|Σ xg − λ| < 1e-9` per side per match
- mean total goals 2.6–2.8 at parity; draw rate 24–27%
- win probability monotonic in rating gap
- the all-out-attack exploit stays dead: a weak side switching to an attacking
  tactic must not gain expected points over balanced
- a 90-ATK winger against a 55-DEF full-back wins materially more duels, takes a
  materially larger share of his side's shots, and his side's flank share
  shifts — the feature actually doing its job, asserted

**3. Keep what is already invariant-based.** `match_orchestration_test.dart`
(1219 lines) tests serialisability, injury caps and ordering, not parity — keep
it as-is. Extend `goal_pairing_test.dart` to the new duel call sites so
"our ATK vs their DEF" stays pinned at every one.

**Fixtures that survive.** Because `goalRateLambda`, the pre-kickoff modifier
chain and `computeSquadRatings` are untouched, these stay green and must **not**
be regenerated: `utils_reference.json`, `fixture_preview_reference.json`,
`tactic_coach_reference.json`, `progression_reference.json`,
`game_state_reference.json`. Only fixtures that bake in a *simulated match
outcome* move: the two above plus the player-tie scenarios in
`cup_engine_reference.json` and `event_cup_reference.json`. Confirm by running
the suite before assuming either way.

---

## i18n

~36 new keys, and **every one needs all ten locales** — `t()` falls back to
English, which is right for one string and wrong for a report paragraph;
`match_report_test`'s locale matrix requires the locale's own entry. English in
`lib/i18n/en_copy.dart`, the other nine in `lib/i18n/copy/<id>_copy.dart`.
Nothing generated is edited.

| Prefix | Keys | Where |
|---|---|---|
| `report.zone.*` | ~6 | flank dominance beats |
| `report.duel.*` | ~4 | a player's duel record |
| `match.analysis.*` | ~10 | headings on the summary card |
| `squad.side.*` | ~8 | side-bias picker |
| `role.*` | ~8 | Phase 6 role names and hints |

Two details that will otherwise bite:

- New report beats are subject to `reportBeatBudget = 6` and get trimmed by
  `beatRank` (`match_report.dart:905-940`). Assign ranks deliberately or the new
  analysis lines will silently never appear.
- `commentary.blocked` is a shipped seven-line pool with **no caller**
  (`en.g.dart:1460`) — exactly the "shipped copy with no caller" tell CLAUDE.md
  describes. A duel lost to a blocking defender is what it was written for; wire
  it rather than adding a new key.

---

## Verification

Install the pinned SDK **first, in the background**, and read code while it runs
— a half-extracted SDK makes `flutter analyze` exit 0 without running:

```bash
curl -sSo /tmp/f.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.9-stable.tar.xz
mkdir -p ~/sdk && tar xf /tmp/f.tar.xz -C ~/sdk
git config --global --add safe.directory ~/sdk/flutter
export PATH=~/sdk/flutter/bin:$PATH && flutter pub get
flutter --version    # must answer before trusting any green
```

Per phase:

```bash
flutter analyze                                        # clean before any commit
flutter test                                           # ~4,420 tests
TZ=UTC flutter test                                    # events/event_engine skip outside UTC
flutter test test/engine/positional_balance_test.dart  # the real net
dart run tool/dump_positional_golden.dart              # regenerate goldens (Phase 3b)
bash tool/unreached.sh                                 # nothing new landing unreachable
```

If widget tests fail on `shaders/ink_sparkle.frag`, that is a stale bundle —
`rm -rf build/unit_test_assets` and re-run.

End-to-end, in the app: play a match, confirm the scoreline still looks sane
across ten runs, open the summary and check the heatmap matches the shape you
picked, switch the side bias to Right and confirm the flank share and the
analysis text both move.

**Never run `dart format`** — it reflows ~186 files and turns a clean analyze
into eleven issues. Match the surrounding style by hand.

## Risks

- **The x-axis handedness** (Phase 1) — silently ships a lying analysis screen if
  wrong. Pin it with a test.
- **Under-dispersion** from the Poisson-binomial. Measured by the balance suite,
  fixable by jittering `k`.
- **Save bloat** if raw events are not stripped before persistence.
- **The self-generated golden** pins whatever it is given. The balance suite is
  what makes retiring the JS fixtures survivable, so it is not deferrable to a
  later phase.
