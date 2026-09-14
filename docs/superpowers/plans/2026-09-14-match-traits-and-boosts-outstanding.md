# Match traits and manager boosts — what is left

Handover for `match-traits-and-boosts`. The features are built; three tests
fail. Nothing is pushed and there is no PR.

**Spec:** `docs/superpowers/specs/2026-09-14-match-traits-and-boosts-design.md`
**Plan:** `docs/superpowers/plans/2026-09-14-match-traits-and-boosts.md`

## Where it stands

22 commits, working tree clean, `flutter analyze` clean.

Full suite, `TZ=UTC flutter test`, 14 Sep 2026: **6,911 passed, 3 failed.**

**Run it with `set -o pipefail`.** `flutter test 2>&1 | tail -40` reported exit
code **0** with three tests failing — the pipe swallowed the status. That is
how this nearly went out believed green.

---

## 1. The type floor — nine literals under 12pt

`test/architecture_test.dart :: no text is declared below the type floor`

`minFontSize` is 12. The rule's own note says the way to fit type into a slot
that cannot hold it is `FittedBox`, which shrinks at DRAW time — never a
smaller literal, because "the next tight slot will want a 10 too, and a rule
that lives only in a doc comment loses that argument every time."

| File | Lines | What it is |
|---|---|---|
| `lib/ui/screens/match/boost_strip.dart` | 153, 163, 178 | the `→ 65'` window end, the `x2` count, the gem price |
| `lib/ui/screens/match/bench_boost_row.dart` | 110, 125, 144 | the count, the gem price, the reason line |
| `lib/ui/screens/match/boost_bar_paint.dart` | 201 | the live-source pill's text |
| `lib/ui/screens/match/match_statboard.dart` | 377, 406 | the Active heading, the `until 65'` label |

**How to fix each:**

- **`boost_strip.dart`** — all three are already inside the tile's
  `FittedBox(fit: BoxFit.scaleDown)` at line 129. Raise them to 12 and the
  FittedBox absorbs it. No layout risk.
- **`bench_boost_row.dart`** — NOT inside a FittedBox. Either wrap the tile's
  content row the way `boost_strip` does, or raise to 12 and confirm the tile
  still fits two of them side by side at 400px. The reason line already has
  `maxLines: 2` + ellipsis, so it degrades safely; the count and price row is
  the one to watch.
- **`boost_bar_paint.dart`** — the pill. Raising 10 → 12 at `height: 1.4` needs
  16.8pt, and `LiveSourcePill.height` is **16** (line 175). Bump that constant
  to 18 as well. It is a reserved height, so the board's layout moves by 2pt —
  re-run `match_screen_test`'s `ONE INSET DOWN THE PAGE` group afterwards.
- **`match_statboard.dart`** — plain raise to 12. The sheet scrolls, so there
  is no slot to overflow.

## 2. The weight floor — one `w500`

`test/ui/font_weight_test.dart :: and NOTHING in lib/ui asks for a weight under the floor`

`lib/ui/screens/match/bench_boost_row.dart:146`:

```dart
fontWeight: live ? FontWeight.w700 : FontWeight.w500,
```

`pubspec.yaml` bundles ONE Barlow cut at `uiBaseWeight` = **w600**, so asking
for w500 asks for a face that is not there. The intent was "quieter when the
tile is dead" — carry that with the COLOUR, which the line already does
(`kit.textMuted` against `kit.accentBright`), and make both branches w700. Or
use w600 for the dead branch if the contrast reads too flat.

## 3. Crowd Roar fails ONLY in the full suite

`test/ui/screens/match/boost_strip_test.dart :: THE BOOST STRIP CROWD ROAR: debits, opens a window, lifts the side, and says so`

**Reproduce it before changing anything.** Confirmed so far:

- Passes run on its own.
- Passes with the whole `test/ui/screens/match/` directory — 496 tests, green.
- Fails in `TZ=UTC flutter test`.

The failing assertion in the last full run was not captured (`tail -40` cut it),
so **the first job is a full run that keeps the failure block**, e.g.
`set -o pipefail; TZ=UTC flutter test 2>&1 | tee /tmp/suite.log` and then read
around the `[E]`.

**Working hypothesis, untested.** The test's `_runTo` helper finishes a cutaway
but does NOT answer a Coach Colin card:

```dart
Future<void> _runTo(WidgetTester tester, MatchScreenState state, int minute) async {
  for (var i = 0; i < 400 && state.frame.minute < minute && !state.frame.finished; i++) {
    if (state.clipPlaying) { …onDone!(CutawayOutcome.goal); await tester.pump(); continue; }
    await tester.pump(minuteDurationFor(1));
  }
}
```

Colin holds the match whenever he has something to say, and `_tick` returns
early while `_paused`. If he speaks between the tap at 40' and the window's end
at 65', the clock never reaches 65 and `boostWindows` is still populated when
the assertion runs — which is exactly the failure seen. `retrospective_boosts_test.dart`
has a `_runTo` that DOES answer him (`_coachSpeaks`, `pumpAndSettle` when
paused); lifting that shape across is the likely fix.

CLAUDE.md documents this family of failure: "two failures in four full-suite
runs and none in twelve on its own."

**But do not assume it.** Two other explanations fit "green alone, green by
directory, red in full" and are worth ruling out from the captured log:

- **A shared-stream position.** The strip test never calls `setSeed`, so the
  seeded stream's position at the start of the CROWD ROAR case depends on what
  the earlier cases in that file consumed. Within-file order should not change
  between runs, so this is the weaker theory — but if the log shows a different
  minute or a different scoreline than a solo run, this is why.
- **A stale `build/unit_test_assets`.** Ruled out for this run — the suite was
  started after `rm -rf build/unit_test_assets` — but it is the first thing to
  re-check if the symptom becomes an `ink_sparkle.frag` decode error rather
  than this assertion.

**If it is Colin:** the fix belongs in the test, not the screen. Do not wrap the
dismissal in `if (…isNotEmpty)` — CLAUDE.md is explicit that this turns a missed
control into a failure forty lines later in an assertion about something else.

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
