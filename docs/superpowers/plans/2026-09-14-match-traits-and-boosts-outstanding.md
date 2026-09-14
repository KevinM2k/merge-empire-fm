# Match traits and manager boosts — what is left

Handover for `match-traits-and-boosts`. The features are built and the suite
is green. Nothing is pushed and there is no PR.

**Spec:** `docs/superpowers/specs/2026-09-14-match-traits-and-boosts-design.md`
**Plan:** `docs/superpowers/plans/2026-09-14-match-traits-and-boosts.md`

## Where it stands

26 commits, working tree clean, `flutter analyze` clean. The three failures
below are fixed; nothing is pushed and there is no PR.

**Run the suite with `set -o pipefail`.** `flutter test 2>&1 | tail -40`
reported exit code **0** with three tests failing — the pipe swallowed the
status. That is how this nearly went out believed green.

---

## 1. The type floor — fixed

Nine literals under 12pt across `boost_strip`, `bench_boost_row`,
`boost_bar_paint` and `match_statboard`, all raised to 12. The pill's
reserved `LiveSourcePill.height` went 16 → 18 to hold 12pt at `height: 1.4`;
`match_screen_test`'s layout group is green with the 2pt shift.

## 2. The weight floor — fixed

`bench_boost_row.dart`'s reason line asked for w500 on the dead branch. Both
branches are w700 now; the colour already carried "quieter when dead".

## 3. Crowd Roar — fixed, and it was not Colin

The handover's hypothesis was that a Coach Colin card held the clock so the
window never closed. The captured log said otherwise: `boostWindows` was
empty and `resimCount` was 2 — the failing line was `lifted > after` on
`liveSquadRating`, with both at `15.0`. Alone, the file failed about one run
in three; "green alone" had been luck.

Three random inputs, none seeded by the test:

- **`migrateRatios` back-fills `attackRatio` on every card at load** off an
  unseeded `math.Random` (mirroring the JS), and it wins over
  `definitionRatios`. The eleven's ATK/DEF split moved a point per run.
- **The shared stream is seeded off the wall clock**, and injuries and
  cautions come off it. `match_trait_wiring_test` documents the same trap.
- **The star is an int blended from an already-rounded pair**, so on a
  ~15-rated eleven a 10% lift sometimes rounds away (`12/17 → 15`, `11/16 → 15`).

`_save()` now stamps each cell's `attackRatio` at its position's midpoint, the
file's `setUp` calls `setSeed(7)`, and the Roar assertion compares the
ATK/DEF pair the lift actually lands on. 15 consecutive runs green. The
`PARK THE BUS` and `TWO ROARS STACK` cases flaked off the same inputs.

**Not fixed, not ours:** `test/ui/screens/home/repaint_scope_test.dart` failed
once in a full run and once in ~16 solo runs on this branch; 20/20 on a `main`
worktree. It samples ONE 16ms frame of a live shell with an unseeded gesture
rig, and nothing on this branch reaches the home screen's paint tree. Re-run
before reading it as a regression.

---

## Then

1. `flutter analyze` — clean, not "clean apart from".
2. `set -o pipefail; TZ=UTC flutter test` — and read the exit code.
3. `git diff main --stat` — only the files this work names. A file with far more
   changed lines than its task touched means `dart format` ran; revert every
   hunk that is not ours before the PR.
4. PR through the `pr-writing-style` skill, per the global rules.

## Known and deliberate, not outstanding

- **`tool/unreached.sh` lists `setMatchTraitRandom` and `resetMatchTraitRandom`.**
  Test seams, the same shape as the eight other `set*Random` / `reset*Random`
  pairs already on that list. The script's header names this as one of the four
  expected kinds of hit.
- **👑 Comeback King is not built.** It needs a re-simulation on a goal — a
  trigger that does not exist and that sits against what the 13 Sep scoreline
  audit protects. Held for its own change with its own test group; the trait is
  specified in the design doc so the pool's shape is on record.
- **Mudlark was cut.** `weather_engine` is UI-only and never reaches a match, so
  the trait had no hook. Replaced by 🛟 Relegation Scrapper, which reads
  `result['playerInRelegationZone']` — already stamped and already read by
  `matchRatingMods`.
- **The frequency estimates behind the trait ladder are guesses.** "Derby Devil
  fires in ~10% of matches" and the rest are unmeasured. The LADDER is pinned as
  a test assertion so it cannot drift, but the numbers under it want checking
  against a real season.
- **How a match trait compares to a first-slot one is not known.** They run
  through different channels — slot 1 adds flat points to the ATK/DEF split,
  slot 2 multiplies the whole contribution — so the two are not comparable on
  paper. Intent was bigger-but-conditional; worth measuring once it runs.
