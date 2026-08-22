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

**And `../merge-empire-fc` — the spec — is NOT in a cloud container.** It is a
separate repo and only this one is cloned. Read what the port already has (the
source comments carry the JS's reasoning, which is why they are so long) and say
in the commit that the JS could not be consulted; do not reconstruct a rule from
memory and present it as the spec's. The generated catalogues are downstream of
that repo too, so **no new `t()` key can be added from here** — a change that
needs new copy is blocked on `en.js`, and the honest move is a glyph, an
existing key, or the queue saying it is blocked.

```bash
flutter analyze                      # must be clean before any commit
flutter test                         # ~4,430 tests
TZ=UTC flutter test                  # test/data/events_test.dart and
                                     # test/engine/event_engine_test.dart skip
                                     # themselves outside UTC — annual event
                                     # windows resolve local wall-clock time
flutter test test/engine/foo_test.dart          # one file
flutter test test/engine/foo_test.dart --name X # one test
```

**Never run `dart format lib/ test/`.** It reformats ~186 files and trips
`curly_braces_in_flow_control_structures` in about ten pre-existing ones, turning
a clean analyze into eleven issues. Format only files you touched.

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

Locale copy and generated catalogue text are fixed in `../merge-empire-fc`'s own
`en.js` and regenerated — the catalogue comes from the JS.

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
- **Shipped copy with no caller is the loudest tell there is.** The catalogues
  are generated from the JS, so a translated string nothing can print is a
  feature the port dropped, named and counted in ten languages. It has now found
  the coach tips, the income breakdown, every trait, the match commentary, the
  transfer pill and prestige. Grep `lib/i18n/locales/en.g.dart` for a key prefix
  and then for a caller — the gap between the two counts is a work queue.
- **A shipped string with markup in it is a second tell.** `t()` strips `<br>`
  and `<strong>` at the boundary because the copy was written for a DOM and the
  catalogues are generated; a string that renders its own tags is a call site
  nobody has looked at. `cup.win_reward.body` was printing
  `<strong>Nike</strong>` to players.
- A port with no tests is not done.

## Identifiers

The display name is "Merge Empire Football Manager" (`CFBundleDisplayName`,
`android:label`, window title, store listings); `CFBundleName` is
"Merge Empire FM". The identifiers deliberately still read `mergeempirefc` —
`com.mergeempirefc.app` on both stores is the primary key of an already-published
app, and the Dart package name `merge_empire_fc` is internal.
