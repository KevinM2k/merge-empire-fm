# Merge Empire FC — Flutter Port Design

**Date:** 2026-08-17
**Status:** Approved, pending implementation plan
**Source:** `../merge-empire-fc` @ v1.15.11
**Target:** `merge-empire-fc-flutter` (Flutter 3.38.3 / Dart 3.10.1)

## Purpose

Rewrite the shipped Capacitor/vanilla-JS game as a native Flutter app for iOS and
Android. The app already ships to both stores; the rewrite is not about reach. It
is about four defects of the webview approach, all of which the user confirmed as
drivers:

1. **Performance** — DOM/CSS animation drops frames on the grid, merge animations,
   league diorama and match scenes.
2. **Native feel** — scrolling, gestures and transitions are approximations.
3. **Maintainability** — 53.8k lines of vanilla JS and 13.5k lines of CSS with no
   framework are hard to change safely.
4. **Plugin/webview pain** — Capacitor plugin breakage and webview-specific bugs.

Success means: the same game, recognisably identical to players, running at a
measured frame budget on real devices, with existing players' saves and purchases
carried across intact.

## Constraints

These are hard. Everything downstream is shaped by them.

- **Save compatibility is mandatory.** The Flutter build ships as an update to the
  same app IDs (`com.mergeempirefc.app`). It must read existing saves, run the same
  migration chain, and round-trip the exact JSON shape. `SAVE_VERSION` is 7.
- **Visual identity is preserved.** Layout, kit-colour theming, card design, screen
  structure and all 236 art assets carry over. Interactions are rebuilt the Flutter
  way; the look is not redesigned.
- **The game is live, tuned and monetised.** Balance must not drift. Purchases must
  survive. Store continuity (bundle IDs, signing keys, version codes past 1.15.11)
  must hold.
- **Everything is tested.** See "Testing" — this is an explicit requirement, not a
  default, and it expands scope by roughly 30–40%.

## Scope

Ported from the source repo:

| Layer | Source | Prod lines | Port path |
|---|---|---|---|
| Engines | `src/engine/` (37 files) | 15.3k | Mechanical → Dart |
| Data | `src/data/` | 6.4k | Mechanical → const Dart |
| State | `src/state/` | 0.9k | Mirror schema exactly |
| Utils | `src/utils/` | 3.4k | Mostly mechanical |
| i18n | `src/i18n/` (10 locales) | 29.1k | Generated → ARB |
| Services | `src/services/` | 4.1k | Re-plumb onto Flutter plugins |
| Assets | `src/assets/` (SVG fallbacks + cache) | 0.9k | Mechanical |
| UI | `src/ui/` (10 screens, 50 components, 13.5k CSS) | 53.8k | **Full rewrite** |

Total production code in scope: ~114k lines. Of that, 29.1k is translation tables
converted mechanically to ARB, leaving **~85k lines of hand-ported code** — of which
53.8k is the UI rewrite. Add 19.5k lines of existing tests to port, plus a
substantial volume of new tests to write.

Out of scope: the marketing website (`website/`, `merge-empire-fc-website`), the
`functions/` Firebase backend (reused as-is), and any gameplay redesign.

## Architecture

### Project layout

```
merge-empire-fc-flutter/
├── lib/
│   ├── main.dart              # boot: load save → migrate → runApp → idle ticker
│   ├── data/                  # static game data, ported 1:1 as const Dart
│   ├── engine/                # 37 pure engines — zero Flutter imports
│   ├── state/
│   │   ├── game_state.dart    # models mirroring stateSchema exactly
│   │   ├── save_codec.dart    # JSON round-trip + `extras` passthrough
│   │   └── migration.dart     # ported migrate() chain → v7
│   ├── services/              # firebase, cloud save, leaderboard, iap, ads
│   ├── i18n/                  # generated from JS locales
│   ├── ui/
│   │   ├── app.dart           # shell: 5 tabs + settings + trophy room
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── theme/             # kit-colour theming (replaces CSS variables)
│   └── util/
├── assets/                    # 236 files (~11MB) from public/assets
├── test/                      # ported + new tests
├── integration_test/          # device-level flows
└── tool/                      # codegen: locale→ARB, JS↔Dart diff harness
```

`lib/engine/` and `lib/data/` must not import `package:flutter/*`. This mirrors the
existing rule that engines under test may not touch `window`/`document`, and keeps
them runnable under plain `dart test`.

### State management

The source uses a mutable singleton `state`, engines that mutate it in place, and a
~30-signal event bus for cross-component updates. Redesigning that wholesale would
destroy the mechanical port path for 15.3k lines of engine code.

Decision: **keep the singleton as the source of truth.** Engines continue to take
`state` and mutate it, ported near-verbatim. Replace *only the event bus* with
Riverpod providers — each existing signal (`coins:updated`, `trophies:updated`,
`match:complete`, `merge:happened`, `kit:changed`, `locale:changed`, …) becomes a
scoped provider so widgets rebuild narrowly rather than globally.

Riverpod over Provider because engines must remain testable with no widget tree.

Mutations continue to funnel through an `updateState(mutator)` equivalent that
queues the 2-second debounced save, with an immediate `saveState()` on app pause /
lifecycle background — matching current durability behaviour.

### Save model and the migration bridge

The single most important technical finding of this design:

| Save slot | Where it lives | Readable from Flutter? |
|---|---|---|
| `mergeEmpireFC_save` (primary) | WebView `localStorage` | **No** |
| `mergeEmpireFC_save_lastgood` | WebView `localStorage` | **No** |
| `mergeEmpireFC_save_native` (mirror) | Capacitor Preferences → Android `SharedPreferences` / iOS `NSUserDefaults` | **Yes** |
| `saves/{uid}` (cloud) | Firestore, full state as a JSON string | Yes, signed-in only |

A Flutter app cannot read the webview's `localStorage`. `nativeSaveMirror.js` — built
to survive Android One UI storage eviction — is therefore the *only* local bridge,
and the cutover depends on it.

**Required precursor:** ship one final Capacitor release of the existing app that
force-writes the native mirror on boot, so that players whose progress currently
lives only in `localStorage` have a readable copy before they update to Flutter.
This is a dependency on the existing repo, not this one, and it must land first.

The Flutter boot sequence then reads the native mirror, falls back to cloud for
signed-in players, runs the ported `migrate()` chain, and takes over.

Because cloud saves persist the whole state as a JSON string, the Dart model must
round-trip the exact shape. Typed models mirror `stateSchema`, each carrying an
`extras` passthrough map for unrecognised keys, guarded by golden round-trip tests
against real save files. Losing an unknown field silently corrupts a save; the
passthrough plus goldens is what prevents it.

### Rendering

Plain Flutter widgets and `CustomPainter`. **No Flame** — this is an animated UI, not
a real-time game loop, and adding a game engine would fragment the widget model.

| Source | Lines | Flutter approach |
|---|---|---|
| `Grid.js` drag & drop | 943 + 872 CSS | `Draggable`/`DragTarget`. The `pan-y` touch-vs-pointer workaround is deleted — Flutter's gesture arena handles it natively. |
| `MergeAnimation.js` (GSAP) | 928 | `AnimatedBuilder` + explicit controllers |
| `MatchPopup` / `ChanceCutaway` / `PitchScene` / `PitchBallSim` | 7.6k | `CustomPainter` — the largest expected performance win |
| `LeagueScreen` diorama | 6.8k + 4.4k CSS | `CustomPainter` sprite compositing. Highest-risk UI work. |
| `Card.js` | 315 + 452 CSS | `RepaintBoundary` per card, const widgets, cached images |
| `kitTheme.js` | — | `ThemeExtension` carrying the derived palette + `SystemChrome` for Android system bars |

The frame-budget rules already documented in the source `CLAUDE.md` ("Card rendering
+ frame budget") carry over as explicit performance test targets.

### Services

This layer gets materially smaller. `firestoreRest.js` and `firestoreRestAuth.js`
(~420 lines combined) exist *only* because the Firestore SDK's WebChannel streams
fail inside the native WebView. On Flutter that entire workaround is deleted in
favour of the normal `cloud_firestore` SDK.

| Current | Flutter |
|---|---|
| `@capacitor-firebase/authentication` | `firebase_auth` + `google_sign_in` / `sign_in_with_apple` |
| `firestoreRest.js` (REST workaround) | `cloud_firestore` — **workaround deleted** |
| `@capacitor-firebase/analytics`, `crashlytics` | `firebase_analytics`, `firebase_crashlytics` |
| `@capacitor-community/admob` | `google_mobile_ads` |
| `cordova-plugin-purchase` | `in_app_purchase` |
| `@capacitor/local-notifications` | `flutter_local_notifications` |
| `@capacitor-community/in-app-review` | `in_app_review` |
| `@openforge/capacitor-game-connect` | `games_services` |
| `@capacitor/preferences` | `shared_preferences` + platform channel for the legacy key |
| `@capacitor/browser` | `url_launcher` |
| `wakeLock.js` | `wakelock_plus` |

### i18n

10 locales × ~2,900 keys. A `tool/` script converts `src/i18n/locales/*.js` to ARB,
then `flutter_localizations` + `intl`.

`gen_l10n` does not fall back per-key, but the source `t()` does — returning the
English string when a key is missing in the active locale, and the raw key when it is
missing everywhere. A custom lookup wrapper must reproduce that exactly, or missing
translations will surface as blank UI instead of English. Arabic RTL is native via
`Directionality`.

## Testing

An explicit requirement: everything is tested. The existing suite covers engines well
and almost nothing else, and that gap must not be carried into the new codebase.

| Layer | Source prod | Source test | Ratio |
|---|---|---|---|
| `engine/` | 15.3k | 14.1k | ~92% |
| `data/` | 6.4k | 2.2k | ~34% |
| `utils/` | 3.4k | 760 | ~22% |
| `services/` | 4.1k | 688 | ~17% |
| `ui/` | 53.8k | 1.2k | **~2%** |
| `i18n/` | 29.1k | 315 | ~1% |

Development is test-first throughout, per `superpowers:test-driven-development`: the
ported JS test becomes the failing Dart spec, then the implementation makes it pass.

1. **Unit — engines, data, state, utils.** Port all 14.1k lines, then fill the gaps:
   every public function and branch, including the thin `data/` and `utils/` surface.
   Plain `dart test`, no Flutter dependency.
2. **Differential parity.** Seeded scenarios run through both node (source repo) and
   Dart, asserting identical output for match simulation, progression, cup brackets,
   merges, idle income and injury rolls. `utils/random.js` is a seeded PRNG, which is
   what makes this possible. This is the anti-balance-drift net and the single
   highest-value test layer for a live, tuned game.
3. **Save and migration.** Golden round-trips on real v7 saves; the full v1→v7
   migration chain; corrupt and truncated save recovery; `lastgood` and `backup` slot
   logic; the native-mirror bridge; cloud conflict resolution including the
   optimistic-concurrency token and precondition-failure paths.
4. **Widget tests — every screen and component.** Grid drag/drop and hit-testing,
   merge interactions, HUD reactivity, popup queue ordering, feature unlocks, modals.
   The layer that currently sits at ~2%.
5. **Golden image tests.** Card rendering across every tier and rarity, kit-colour
   retint variants, light/dark, RTL. Because "same identity" is a requirement, these
   catch visual regression mechanically rather than by eye.
6. **Integration tests** (`integration_test`, device/emulator). Boot → tutorial →
   first merge → first match → season end; promotion and relegation; purchase and
   restore; sign-in and cloud restore; and migration from a real v7 save.
7. **Service contract tests.** Fakes for Firebase, IAP, ads and Game Center/Play
   Games, covering the failure paths — offline, declined purchase, expired token —
   that are untested today.
8. **i18n completeness.** Every locale has every key, no orphans, ICU plurals correct,
   RTL layout, and golden overflow checks against the longest strings (German and
   Arabic).
9. **Performance.** Frame-budget assertions on grid scroll, merge animation and the
   match scene. Jank is driver #1, so it is measured, not assumed.

**Gates.** GitHub Actions runs layers 1–5 and 7–8 on every push; 6 and 9 on a device
matrix nightly and pre-release. `flutter test --coverage` with lcov thresholds that
fail the build, stated as explicit numbers so they are enforceable rather than
aspirational:

| Path | Minimum line coverage |
|---|---|
| `lib/engine/`, `lib/state/` | 95% |
| `lib/data/`, `lib/util/` | 90% |
| `lib/services/` | 80% |
| `lib/ui/` | 70% |
| Project overall | 85% |

Thresholds ratchet upward only: a milestone may raise a floor, never lower it.

## Milestones

Each is its own spec → plan → build cycle, and each carries its own test deliverable
and coverage gate. Testing is not a phase at the end.

| ID | Milestone | Contents |
|---|---|---|
| M0 | Spike | Save-bridge readability from Capacitor Preferences; scaffold rendering one Card at 60fps; diorama technique probe |
| M1 | Core | data, state, utils, 37 engines, ported + new tests, differential harness |
| M2 | Core loop | App shell, HUD, Grid, merge, Card, idle tick — **playable** |
| M3 | Match + League | Match presentation, league tables, cups, diorama |
| M4 | Meta | Shop, quests, events, achievements, trophy room, squad, player index |
| M5 | Mini-games | 7 self-contained games |
| M6 | Services + migration | Firebase, cloud save, leaderboards, IAP, ads, live-player cutover |
| M7 | Release | Icons, store assets, signing, build pipelines for both platforms |

## Risks

1. **LeagueScreen diorama and match scenes.** ~15k lines of bespoke DOM/CSS animation
   with no mechanical port path. Biggest unknown; M0 probes the technique before M3
   commits to it.
   **Status after M0: open.** Both a `CustomPainter` and a widget-tree rig are built,
   tested and committed, but the choice needs profile-mode timings from a physical
   device, which this session could not produce. See `2026-08-17-m0-findings.md`.
   M3 must also evaluate **Rive** for the articulated manager-avatar walker.
2. **Save-bridge platform channel.** Capacitor prefixes Preferences keys
   (`CapacitorStorage`) differently from `shared_preferences` (`flutter.`). Reading the
   legacy key needs a platform channel on both platforms. Spiked in M0 because every
   downstream milestone depends on it.
   **Status after M0: retired on iOS, open on Android.** Key formats were confirmed
   from the plugin source — Android stores the key unprefixed in SharedPreferences
   file `CapacitorStorage`; iOS prefixes it as
   `CapacitorStorage.mergeEmpireFC_save_native`. A real v7 save round-trips
   losslessly on iOS. The Android handler compiles but its integration test has not
   been run for want of an emulator image.
3. **The precursor Capacitor release.** Players whose save exists only in
   `localStorage` are unreachable until the existing app force-writes the native
   mirror. If the Flutter build ships before enough players have taken that update,
   they lose progress. Adoption of the precursor release must be monitored before
   cutover.
4. **IAP entitlement continuity.** Existing purchasers must retain non-consumables via
   restore, mapped to the current product IDs.
5. **Store continuity.** Same bundle IDs and signing keys; version codes must increment
   past 1.15.11.
6. **Art assets.** 236 PNGs sized for CSS rendering; density variants and sizing need
   verification against Flutter's asset resolution.

## Decisions taken

| Question | Decision |
|---|---|
| Why Flutter, given it already ships to both stores | Performance, native feel, maintainability and plugin pain — all four |
| Existing player saves | Must migrate live players; exact JSON round-trip required |
| Visual fidelity | Same game, Flutter-native feel — keep identity and assets, rebuild interactions |
| Sequencing | Hybrid: logic core first with tests, then vertical playable UI slices |
| State management | Singleton state preserved; event bus replaced with Riverpod |
| Game engine library | None — plain widgets + `CustomPainter`, no Flame |
| Test depth | Everything tested; nine layers with CI coverage gates |
| Repository | Own git repo at `merge-empire-fc-flutter` |
