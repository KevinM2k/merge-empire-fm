# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Flutter port, in progress, of a shipped JavaScript game. **The JS at
`../merge-empire-fc/src/` is the specification** — not a reference, the spec. Its
comments carry the reasoning behind nearly every decision and its CSS states
column counts, backgrounds and container nesting. Read the module and its
stylesheet in full before porting either.

Two queues, and they are different lists:

- `docs/REMAINING.md` — the live queue, newest playtesting session first. What a
  player actually noticed. Clear this one first.
- `docs/PARITY.md` — control-by-control and layout-by-layout diff taken from the
  source. Longer, drier, and it finds things playing does not.

## Commands

**Flutter 3.44.9 / Dart 3.12.2**, in `.fvmrc` and in CI. Not a suggestion: the
framework's own assertions move between minors, and the same suite that is green
here fails 34 tests on 3.47. A clone that picks up whatever `flutter` is on the
path will disagree with CI about whether the port works.

**A cloud session starts with NO Flutter at all**, and `analyze` and the suite
are the only evidence a change works — so install the pinned one first rather
than reasoning about the code:

```bash
curl -sSo /tmp/f.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.9-stable.tar.xz
mkdir -p ~/sdk && tar xf /tmp/f.tar.xz -C ~/sdk
git config --global --add safe.directory ~/sdk/flutter   # or every call dies on ownership
export PATH=~/sdk/flutter/bin:$PATH && flutter pub get
```

**Start that in the background and read code while it runs.** The tarball is
~1.5GB and the untar is minutes, not seconds.

**A half-extracted SDK reports success, which is the trap.** `flutter analyze`
run against one prints

```
/root/sdk/flutter/bin/flutter: line 62: .../bin/internal/shared.sh: No such file or directory
```

and **exits 0**. Nothing says "analyze did not run", so it reads exactly like a
clean pass and will happily be believed for the rest of a session. Wait for
`flutter --version` to answer before trusting any green.

**And `../merge-empire-fc` — the spec — is NOT in a cloud container.** It is a
separate repo and only this one is cloned. Read what the port already has (the
source comments carry the JS's reasoning, which is why they are so long) and say
in the commit that the JS could not be consulted; do not reconstruct a rule from
memory and present it as the spec's. The generated catalogues are downstream of
that repo too — but copy is no longer blocked on it. **`lib/i18n/en_copy.dart`
is where English is written now, and `lib/i18n/copy/<id>_copy.dart` is where the
other nine are**; both are laid over the generated catalogues at load in
`i18n.dart`, so nothing generated is edited by hand and no key needs `en.js`.
Read their headers before adding to either.

**A new key needs all ten, not just English.** `t()` falls back to English for a
missing translation, which is right for one string and wrong for a paragraph
built out of pools: the match report had thirty English-only keys and a French
write-up read French, then four sentences of English, then French again.
`match_report_test`'s locale matrix now requires the locale's OWN entry.

```bash
flutter analyze                      # must be clean before any commit
flutter test                         # ~4,420 tests
TZ=UTC flutter test                  # test/data/events_test.dart and
                                     # test/engine/event_engine_test.dart skip
                                     # themselves outside UTC — annual event
                                     # windows resolve local wall-clock time
flutter test test/engine/foo_test.dart          # one file
flutter test test/engine/foo_test.dart --name X # one test
```

**A stale `build/unit_test_assets` fails widget tests that have nothing wrong
with them.** The symptom is

```
Exception: Asset 'shaders/ink_sparkle.frag' manifest could not be decoded:
INVALID_ARGUMENT: Unsupported runtime stages format version. Expected 2, got 0.
```

thrown from `FragmentProgram.fromAsset` — Material's ink splash, so it hits any
test that taps something, and it comes and goes with how long a `pumpAndSettle`
runs. It is a bundle left behind by an OLDER engine, not a fault in the change
under test: eleven tests in `test/ui/popups/` failed this way with the working
tree stashed and the same eleven passed in a fresh worktree. `rm -rf
build/unit_test_assets` and re-run.

**Never run `dart format lib/ test/`.** It reformats ~186 files and trips
`curly_braces_in_flow_control_structures` in about ten pre-existing ones, turning
a clean analyze into eleven issues.

**And "format only files you touched" is not the escape hatch it sounds like**,
because the unit is the FILE, not your diff. The repo is not formatted to this
`dart format`'s style, so formatting one file you edited reflows every
pre-existing long line in it too. One pass over nine touched files this way
reported "6 changed" and needed hand-reverting in four — `getLiveGemItems`,
`addGems` and `spendGems` all reflowed in `gem_engine.dart` alone, none of them
anywhere near the edit — and in `deadline_day_engine.dart` it split an `if` onto
two lines and turned a clean analyze into one issue.

**So format nothing, and match the surrounding style by hand.** If you have
already run it, `git diff` the file and revert every hunk that is not yours
before committing; a reviewer cannot find a four-line change inside forty lines
of reflow. Note that `git checkout -- <file>` may be refused in a cloud session,
so the revert is a targeted edit rather than a restore.

Fixtures are dumped from node, not hand-written:

```bash
node tool/dump_<module>_reference.mjs > test/fixtures/<module>.json
node tool/difftest/run.mjs > test/fixtures/season_difftest.json  # whole seasons
```

Generators — edit the generator, never the output:

```bash
node tool/gen_i18n.mjs        # lib/i18n/catalogs.g.dart + locales/*.g.dart
node tool/gen_club_art.mjs    # lib/data/club_art.g.dart
node tool/gen_manager_art.mjs # lib/data/manager_art.g.dart
```

Generated catalogue text comes from `../merge-empire-fc`'s own `en.js`. Copy
this repo owns is laid OVER it and never regenerated: `lib/i18n/en_copy.dart`
for English, `lib/i18n/copy/<id>_copy.dart` for the other nine.

## Mapping the repo

`/graphify` is checked in at `.claude/skills/graphify`, so it is available to
anyone who clones this rather than only to the machine it was installed on. It
turns the tree into a navigable knowledge graph — communities, an audit trail,
and a queryable JSON — which is worth having HERE specifically: the port is 56
engines and a UI layer whose rule is that the bottom half may not import
Flutter, and "what reaches this" is the question `tool/unreached.sh` and
`tool/unreached_ui.sh` already ask one file at a time.

Build it with `/graphify` and query it with `/graphify query "<question>"`. The
output goes to `graphify-out/` and is git-ignored: it is derived, and it goes
stale the moment the tree moves.

## Architecture

**The bottom half may not import Flutter.** `lib/engine/`, `lib/data/`,
`lib/i18n/`, `lib/state/`, `lib/util/` are pure Dart, enforced by
`test/architecture_test.dart`. That is what lets 56 engines and the whole save
layer run under plain `dart test` with no widget binding.

- `lib/state/game_state.dart` — one `Map<String, dynamic>`, held for the process
  lifetime and **mutated in place**. Every screen and engine holds that same map,
  so a cloud restore or reset replaces its *contents*, not the reference. Key
  insertion order is preserved; a Dart record must never be stored in it.
- `lib/state/game_tick.dart` — one pure turn of the loop. Reasons *not* to act
  (a mini-game open, the match popup up) arrive as `TickGates` and it returns a
  `TickReport`. Nothing here emits or draws.
- `lib/state/game_runner.dart` — the loop, the timer, the listeners. Emits on the
  bus; does not draw, toast or play sound.
- `lib/state/game_wiring.dart` — bus listeners that change the **save**. Several
  engines deliberately do not apply their own reward; without these listeners
  achievements unlock and pay nothing. Listeners that toast, play a sound or log
  analytics live in the UI layer on the same bus.
- `lib/util/event_bus.dart` — every cross-cutting signal (`coins:updated`,
  `match:complete`, `merge:happened`, `season:ended`, …). Grep before inventing an
  event name. The UI subscribes and republishes into Riverpod, which is how
  widgets get narrow rebuilds without dragging Flutter into the engines.
- `lib/providers/game_host.dart` — boot, and app-lifecycle pause. Only states
  that mean the app is really gone pause the loop; `inactive` fires for the
  notification shade. Pausing saves and flushes the durable mirror.

## Rules that bite

- **Navigate through `shellControllerProvider`** (`lib/ui/shell/shell_controller.dart`),
  never by emitting a bus event by hand. Its listeners are the only code that
  should know those strings.
- **A popup is one of three shapes** — bottom sheet, Coach Colin card, quick-nav
  menu — and goes on screen through `enqueuePopup`. A fourth shape is a spec
  change first. The queue drains in priority order and **may never time out or
  discard**: the welcome-back card holds coins that exist nowhere else.
- **A post-match card is a real dialog the chain is AWAITING**, so a widget test
  that plays a match has to answer it. `_afterMatch` rolls for a transfer bid
  and then a sponsor on `Math.random`, so both are there on some runs and not
  others, and `_playFixture` does not return until one is answered — which
  leaves the play-button freeze held and the page behind it still showing the
  OLD fixture. That is the chain being right, and it reads as a flaky caption:
  two failures in four full-suite runs and none in twelve on its own. **And a
  Coach Colin card has no barrier**, so the `tapAt(Offset(5, 5))` that parks a
  bottom sheet walks straight past it; the dismissal is the card's own
  `coach-action-common.decline`. An `if (…isNotEmpty)` around a step like that
  is the trap, not the fix — it turns a missed control into a failure forty
  lines later, in an assertion about something else.
- **Every user-facing string goes through `t()`.** The key must exist in `en` or
  `test/i18n/call_sites_test.dart` fails the build. `t()` also strips the markup
  the copy was written with — a catalogue `<br>` becomes a newline, `<strong>`
  becomes nothing — because those entries were written for a DOM and the
  catalogues are GENERATED, so the fix has to live at the boundary or the next
  `gen_i18n.mjs` run undoes it. Twenty-three entries carry `<strong>` and one of
  them was on screen: the cup sponsor offer read `<strong>Nike</strong> wants to
  sponsor <strong>Smith</strong>.` to players. Emphasis inside a run of text is
  a DOM affordance a Dart `String` cannot carry; the port's cards get it from
  their own typography (`CoachLine.strong`) instead.
- **A cue emitted N times in one frame plays ONCE.** `retriggerFloor` in
  `sound_service.dart` is 70ms, because a batch signing places four cards inside
  one `update` and four retriggers of a 0.55s clip is a burr rather than four
  sounds. Anything that wants to stack — thunder, fireworks — passes
  `overlap: true`.
- **Colours come from `Theme.of(context).extension<KitTheme>()!`.** The whole
  palette is derived from the club's kit; a hardcoded colour is a bug.
- **A button's face cannot be coloured through `styleFrom`, and it fails
  silently.** Every Elevated/Filled/Outlined button wears `mouldedButtonStyle`
  from the theme, which paints the face in a `backgroundBuilder` over a
  transparent Material. So `backgroundColor:` colours the layer UNDERNEATH the
  face — invisible, except that it fills the full button rect while the face
  sits 4pt inside it, so it buries the hard bottom edge and the button reads as
  a flat slab; and `side:` is drawn by that same Material on that same full
  rect, putting a second outline 4pt ABOVE the moulded one, which is a ridge
  along the top edge. Neither throws and neither analyses. Ask
  `mouldedButtonStyle(face:, edge:, ...)` for the face instead — the coach
  card, Deadline Day and the pyramid editor all do. `foregroundColor:` is fine,
  but do not reach for `kit.textMuted`: that is the helper's own `deadInk`, so
  it makes a live button look disabled. `architecture_test.dart` checks all of
  this, and it earned its keep on the first run: five buttons across three
  files had shipped with it wrong, and the test is what found the fifth.
- Seeded gameplay randomness goes through `util/random.dart`; anything mirroring
  JS `Math.random()` uses `dart:math`. Mixing them shifts every later draw, and
  **draw order matters as much as the formula**.
- Nothing ending `.g.dart` is edited by hand.
- **Reuse these rather than building a second one.** Each exists because there
  were two and they disagreed: `PitchBoard` (`squad_pitch.dart`) lays the eleven
  out for the squad tab AND the subs panel; `PlayerHeroArt` and `benchColumns`
  (`player_card.dart`) are the full-length figure and the bench's column count;
  `CoachBubbleTail` and `coachAlert` (`coach_card.dart`) are the speech tail and
  the unread red; `TraitBadge` (`player_card.dart`) is the trait glyph the
  eleven's `PitchToken` and every `PlayerCard` both wear, off `CardView.trait`;
  `conceded` (`goal_replay.dart`) is the red a goal AGAINST is drawn in, shared
  by the feed's goal card and the replay popup — it moved out of
  `match_screen.dart` so the dependency runs screen → widget.
- **A gesture pose is a place a hand GOES, and the head is not where the art
  draws it.** The skull is a circle at (62, 48.5) r12.5 in the art's own space,
  but the whole head group is then moved by `_headSetBack` and `_headLift`, so
  the circle a raised arm has to clear is at **(59, 41.5)** — `skullOnScreen`.
  Four of the sixteen poses had been written against the wrong one and the arm
  simply vanished behind his face: the wave's elbow was 10.2 units inside it,
  the robot's forearm 15.8, the badge kiss's hand 3.3, and the fist pump grazed
  at 0.96. **The shoulder sits ~15 units under that centre and the upper arm is
  18 long, so ANY raised arm meets the head** — the elbow reaches its furthest
  forward at `armNear: -90` and every angle past that swings it in behind the
  face. `gesture_reach_test` re-solves the chain from `armShoulder`/`armElbow`/
  `armHand` and fails on a pose that reaches inside; solve against it rather
  than nudging degrees.
- **A planted manager is `standing`, not `walking: false`.** `ManagerWalker`
  distinguishes them: `walking: false` is a scene nobody is watching and stops
  him dead, blink and all; `standing` stops only the STRIDE, and `idle` gives
  him a base pose that a playing gesture outruns joint by joint
  (`poseOverIdle`). The dugout cam is what they were added for; anything else
  wanting a living, planted gaffer wants them too rather than a second rig.
- **`PlayerCard.light` is null by default and resolves from the theme.** It was a
  `bool` defaulting to false, so seven callers each had to remember and the squad,
  the bench and the pickers were dark on a light page. Pass it only for a card
  that is genuinely not in the page's theme — one lifted onto a drag overlay.

## Porting habits

- **Reach for the widget before porting the CSS.** The JS builds what the DOM
  won't give it; a straight port of that build is usually worse than the Flutter
  widget it stood in for (`ListWheelScrollView` for a hand-scrolled DOM strip,
  `AnimatedRotation` with an `Alignment` for four `transform-origin` transitions).
  The exceptions are what a widget cannot express — a rig whose limbs turn about
  their own joints wants a painter.
- **Generate a node fixture for anything with non-obvious arithmetic or an RNG
  draw.** Every fixture so far has caught something.
- **A value the parity harness compares is the JS's, not a figure to print.**
  Several fixtures compare a whole object field for field — `deadline_day_parity_test`
  does it to everything `endSession` returns — so a field there cannot be
  "corrected" to suit a screen, and a fixture cannot be regenerated from a cloud
  container anyway. When the port has deliberately diverged from the JS on a
  mechanic, the divergence belongs on the SCREEN. Deadline Day's `summary['wageBill']`
  is per-match because the JS's is; wages have been a per-second drain on the
  income rate since the port changed them, so the ledger asks the squad what the
  drain is and leaves the field to the harness. The parity failure is how that
  was found — it is a feature, so read one before working around it.
- **Check reachability; do not assume it.** Widget tests construct the state they
  need, so they prove a part works and say nothing about whether a player can get
  to it. Before calling a module done, grep for who *calls* it — "only its own
  test" is the module's real status. This catches engines too: `trackEvent` had no
  caller in `lib/`, so three quests could never advance while every test passed.
  And grep the JS for a caller as well — some functions are a dead end *there*,
  and building a UI for one is adding a feature rather than porting it.
- **`bash tool/unreached.sh` is that check mechanised**, over every public
  top-level function in `lib/engine`, `lib/data` and `lib/state`. Six engines
  have been caught this way, the largest being the whole of prestige — engine,
  fourteen strings in ten catalogues and three achievements, none of it
  reachable. **A high `test-files=` count is the interesting row, not the safe
  one.** The script's header lists the four kinds of hit that are expected and
  are not bugs; read it before acting on a row.
- **`bash tool/unreached_ui.sh` is the same question for `lib/ui`**, and it is a
  different question rather than the same one over more files: a widget's
  functions are called by its own `build`, so a dead SCREEN reads as busy to the
  sweep above and is structurally invisible to it. This one asks what imports the
  file. **It loops, and `round=2` is where the bodies are** — one pass finds a
  dead screen and stops, and it is the file that screen was the last importer of
  that turns out to be the big one. That is exactly how it went: 313 lines in
  round one, 768 more and fourteen passing tests in round two. Liveness means a
  `lib/` importer; a test is not a caller.
- **Shipped copy with no caller is the loudest tell there is.** The catalogues
  are generated from the JS, so a translated string nothing can print is a
  feature the port dropped, named and counted in ten languages. It has now found
  the coach tips, the income breakdown, every trait, the match commentary, the
  transfer pill and prestige. Grep `lib/i18n/locales/en.g.dart` for a key prefix
  and then for a caller — the gap between the two counts is a work queue.
- **Shipped ART carrying an ANIMATION CLASS is the same tell in another
  medium.** The generated SVGs come from a DOM, so a moving part is written as
  its starting position plus a CSS class, and a painter that draws the file
  draws every frame of it at once. `managerFaces['cigar']` ships three
  `.mgr-smoke-puff` circles at ONE point — the port drew a grey disc on the
  cigar's end that never moved, for a bought item named in ten catalogues. Grep
  the generated art for `class="` and ask what moved it in the JS.
- **A shipped string with markup in it is a second tell.** `t()` strips `<br>`
  and `<strong>` at the boundary because the copy was written for a DOM and the
  catalogues are generated; a string that renders its own tags is a call site
  nobody has looked at. `cup.win_reward.body` was printing
  `<strong>Nike</strong>` to players.
- A port with no tests is not done.

## Identifiers

The display name is "Merge Empire Football Manager" (`android:label`, window
title, store listings); `CFBundleName` is "Merge Empire FM". iOS's
`CFBundleDisplayName` is the short "Merge Empire" — the home screen gets one
tightened line and squeezes the spaces out of anything past ~12 characters.

The identifiers deliberately still read `mergeempirefc` — `com.mergeempirefc.app`
on both stores is the primary key of an already-published app, and the Dart
package name `merge_empire_fc` is internal.
