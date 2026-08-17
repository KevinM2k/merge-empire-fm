# What's left

The running list for the Flutter port. Tick a box when the module is ported
**and** tested — a port with no tests is not done.

Sources are `../merge-empire-fc/src/`. Line counts are the JS originals, as a
rough sense of size, not a target.

---

## Where we are

**2,038 tests, 97.2% line coverage, `flutter analyze` clean.** Everything below
the M1 heading that isn't ticked is what remains.

M0 (save bridge) is finished. **M1 (the logic core) is roughly 75% through by
module count**, and — more usefully — the whole progression spine now works end
to end: a season can be played out, the table settles, the pyramid shuffles,
quests roll and pay, cups run, and the season boundary hands over to the next
campaign. What is left in M1 is the match ORCHESTRATION (the outer
`simulateMatch`) plus a long tail of smaller engines.

### How to pick this up

```bash
cd ~/code/github/kevinm2k/merge-empire-fc-flutter
flutter analyze          # must be clean
flutter test             # 2,038 passing
TZ=UTC flutter test      # one parity group needs UTC — see below
```

Two things to know before writing any code:

1. **Read `../merge-empire-fc/src/<module>.js` in full before porting it.** The
   comments in that repo carry the reasoning for nearly every decision, and most
   of them are worth keeping. The port's comments are a rewrite of them, not a
   copy.
2. **Generate a node fixture for anything with non-obvious arithmetic or an RNG
   draw.** Scripts live in `tool/dump_*_reference.mjs`, fixtures in
   `test/fixtures/`. Every one of them has caught something.

### Standing rules

- `lib/engine/`, `lib/data/`, `lib/state/`, `lib/util/` must never import
  `package:flutter/*` — enforced by `test/architecture_test.dart`.
- Seeded gameplay randomness goes through `util/random.dart`; anything mirroring
  JS `Math.random()` uses `dart:math`. Mixing them shifts every later draw.
  **The draw ORDER matters as much as the formula** — see the bugs below.
- Save state stays `Map<String, dynamic>` with key insertion order preserved. A
  Dart record must never be stored in it: records don't serialise.
- `TZ=UTC` is needed for two parity groups (`test/data/events_test.dart` and
  `test/engine/event_engine_test.dart`), which skip themselves elsewhere. The
  annual event window resolves LOCAL wall-clock time, so the reference is only
  comparable in the zone it was generated in.

### Bugs the parity fixtures have caught so far

Worth reading before writing the next port — all three are the same shape.

- **`transferEngine`** derived a club's division index from pyramid key order,
  while the same file documents that key order is not ladder order. Fixed in the
  port, with a deliberately out-of-order pyramid in the test.
- **`cupEngine`** stored the sponsor drop on the result as a Dart record, and
  that result goes into the cup history, which is part of the save. `jsonEncode`
  would have thrown on the first save after a cup win.
- **`endSeason`** drew the promotion rating nudge BEFORE checking the club was
  in this division's pyramid. The JS only draws once it has found one, and a
  table row can name a club that isn't there — so a wasted draw shifted every
  later number and shuffled the entire pyramid differently.

---

## M0 — foundation and save bridge ✅

- [x] Scaffold, lints, architecture test
- [x] `util/random.dart` — bit-exact mulberry32, pinned against node
- [x] `util/time.dart`, `util/format.dart`, `util/event_bus.dart`
- [x] `util/club_name.dart`, `util/player_name.dart`
- [x] `state/state_schema.dart` — key order pinned against the v7 fixture
- [x] `state/migration.dart` + `state/migration_progression.dart`
- [x] `state/save_codec.dart`, `state/card_instance.dart`
- [x] `services/legacy_save_bridge.dart` — reads the Capacitor native mirror
- [x] Save-bridge risk retired on both platforms

---

## M1 — logic core

### Done

**Data**

- [x] `config`, `divisions`, `players`, `formations`, `traits`, `sponsors`
- [x] `loans`, `transfer_market`, `club_assets`, `coin_sinks`, `cups`,
      `player_art`
- [x] `events` (379) — both window kinds, pinned under `TZ=UTC`
- [x] `quests` (1,042) — the 77-quest bank, a compile-time constant
- [x] `manager_looks` — the unlock half of `managerAvatar.js` (packs, gates,
      ownership, normalise, sanitise). The SVG geometry stays for M3.
- [x] `ad_units` — the AdMob tables, split out of `energyEngine`

**Engines**

- [x] `player_rating` (ratingEngine, 111), `trait_engine` (226)
- [x] `merge_engine` (217), `idle_engine` (359), `sponsor_engine` (112)
- [x] `player_energy_engine` (325)
- [x] `energy_engine` (310, pure half only — the AdMob half is M4)
- [x] `lineup_engine`
- [x] `squad_rating`, `match_tactics`, `goal_model`, `match_events`,
      `match_resolution` — `matchEngine` split five ways
- [x] `transfer_engine` (427), `loan_engine` (417)
- [x] `team_names`, `league_pyramid`, `season_fixtures`, `league_table` —
      `progressionEngine`'s league half
- [x] `season_end` — `endSeason`, `processAgeRegression`, prestige, `trackEvent`
- [x] `gem_engine` (451), `sell_engine` (27), `auto_tier_engine` (148)
- [x] `event_engine` (330), `cup_engine` (637)
- [x] `quest_engine` + `quest_match` (1,468) — both tracks, split by what they
      read: the save, and a match result
- [x] `fixture_preview` — `previewFixture`, split out to break the quest/match
      import cycle the JS lives with
- [x] `scout_engine` (125), `coin_sink_engine` (186)

**Utils**

- [x] `analytics` — pluggable sink, so engines log without importing Firebase
- [x] `sorting` — stable sort, which Dart's `List.sort` is not

### Next up — the match orchestration

The last big piece of the spine. Everything it needs is now ported.

- [ ] **`engine/match_orchestration.dart`** — the outer half of
      `matchEngine.js` (2,709 lines total; the five files already ported are
      most of the arithmetic, this is the flow around it):
  - `simulateMatch` — the whole ninety minutes, injuries, windows, tactics,
    scorer allocation, the result object every screen reads
  - `simulateHardGoals` — the Pro-mode per-minute path with live fatigue
  - `finalizeMatchOutcome` — including `drawContextOf`, which stores the three
    facts the dugout cam and the diorama both read so they can't disagree about
    the same draw
  - `applyMatchRewards`, `bestFormationForFixture`
  - This is the biggest single remaining file. Generate a node fixture for a
    full simulated match at several seeds before trusting any of it.

### Remaining engines

Roughly in dependency order — the first three unlock the most.

- [ ] `deadline_day_engine` (1,073) + `data/deadline_day` (140)
- [ ] `iap_engine` (500) — the catalogue and purchase application
- [ ] `achievement_engine` (145) + `data/achievements` (301) — 81 state
      predicates; needs `events` (done)
- [ ] `negotiation_engine` (381) + `data/negotiation` (135)
- [ ] `event_cup_engine` (371)
- [ ] `mini_games_engine` (368) + `data/mini_games` (234)
- [ ] `weather_engine` (330)
- [ ] `pyramid_names_engine` (313)
- [ ] `deadline_news_engine` (310)
- [ ] `deal_advice_engine` (310)
- [ ] `daily_reward_engine` (270)
- [ ] `scout_voucher_engine` (253) — a test must pin it against `gemEngine`'s
      `scout_voucher_gem.heldWhen`; the two halves of the one-voucher rule can't
      import each other
- [ ] `boot_room_engine` (205)
- [ ] `club_asset_tiers` (148)
- [ ] `ad_gate_engine` (86)
- [ ] `badge_engine` (59)
- [ ] `look_pack_engine` (48)

### Remaining data

- [ ] `manager_avatar` — the SVG geometry half (~1,100 lines). Really M3
      material; the unlock half it needs is already done.
- [ ] `manager_mood` (289) — `moodForScore`, `moodForDraw`
- [ ] `geo_zones` (189)
- [ ] `pgs_achievements` (107)
- [ ] `kit_palette` (79)

### Remaining utils

- [ ] `kit_theme` (417)
- [ ] `device` (130)
- [ ] `region` (55)
- [ ] `stat_display` (23)
- [ ] `storage` (1,051) — most of it is `migrate()`, already ported; audit what
      is left over and delete this line if nothing is

### The differential harness

- [ ] `tool/difftest/` — drive seeded scenarios through both node and Dart and
      diff WHOLE SIMULATED SEASONS rather than function-by-function fixtures.
      The nine per-module fixtures already in `test/fixtures/` are the
      groundwork, and the pattern is proven; this is the same idea at the level
      of "play twenty seasons and compare every byte of the save".

---

## M2 — state and reactivity

- [ ] Riverpod providers over the save
- [ ] Republish the event bus into providers (the bus itself stays pure Dart)
- [ ] `state/game_state.dart` (525) — load, migrate, debounced save, the freeze
      flag on reset
- [ ] Save on pause / lifecycle change

---

## M3 — UI

76 files, ~41.5k lines of vanilla JS. Rebuilt idiomatically rather than
transliterated; identity, layout and assets stay.

- [ ] Shell: five tabs plus the hidden Settings screen
- [ ] Merge grid — drag and drop, lazy card mounting, the frame-budget rules
- [ ] Squad, Club, League, Shop screens
- [ ] The live match page (a takeover screen, not a popup)
- [ ] Season-end takeover
- [ ] The three popup shapes — bottom sheet, Coach Colin card, quick-nav menu.
      Do not invent a fourth.
- [ ] Mini-games: Penalty Training, Boot Room, Pitch Invaders, the rest
- [ ] Trophy room
- [ ] Deadline Day screen
- [ ] The manager rig — walker, dugout cam, gestures, moods
- [ ] **Rive** for the walker (MCP still to be installed)
- [ ] **Kenney.nl sprites** to replace the pitch circles with animated players

---

## M4 — services

- [ ] AdMob adapter (the half of `energyEngine` left behind, plus `iapClient`)
- [ ] Firebase: the analytics sink, Crashlytics
- [ ] `authService` (662), `playGamesService` (155), `nativeAuthPlugin`
- [ ] `cloudSaveService` (498), `firestoreRest` (334), `firestoreRestAuth` (83)
- [ ] `leaderboardService` (1,831)
- [ ] `feedbackService` (195) — dormant; the Settings button is hidden
- [ ] `weatherService` (157)
- [ ] Local notifications — four of them, all `allowWhileIdle`
- [ ] `util/sound.js` (782) — synthesised SFX plus the one background track
- [ ] `util/wake_lock` (54)
- [ ] `util/ad_consent` (63), `util/network`, `util/open_url`

---

## M5 — i18n

- [ ] Locale files and the lookup layer
- [ ] Check the long-language layouts (German is the measured worst case)

---

## M6 — release

- [ ] **A final Capacitor release from the OLD repo that force-writes the native
      save mirror.** On the critical path: without it the Flutter build cannot
      read an existing player's local save. Must ship before cutover.
- [ ] iOS: signing, dSYM upload, App Store Connect
- [ ] Android: the CI-generated build config, SDK levels, AGP/Gradle
- [ ] Store listings, whatsnew, changelog

---

## M7 — cutover

- [ ] Internal-track build, device pass on both platforms
- [ ] Staged rollout
- [ ] Watch for save-migration failures in Crashlytics

---

## Open questions and carried risks

- [ ] **Profile-mode timings on physical hardware.** Gates the M3 diorama
      technique choice. The iOS Simulator can't run profile mode;
      `test_driver/integration_test.dart` is committed so the real run is a
      one-liner once a device is attached.
- [ ] **Register the iPhone at developer.apple.com** → Certificates, Identifiers
      & Profiles → Devices. It unblocks every iOS device pass, and has been
      blocking since v1.15.9 of the old app.
- [ ] The `wc2026` event slot is dormant — its window closed in July — and is to
      be reused for something else. It is kept whole because its shape and tests
      are the spec for whatever replaces it: a bracket event with a pickable
      side, per-side ratings and colours, and lifetime challenges.
- [ ] `cosmetic_pack` has no AdMob unit on either platform, so it falls back to
      `energy_pip` and shares its frequency cap. Carried over from the JS.
- [ ] Two migration branches (`tutorial`, `leaderboard`) are non-idempotent in
      the JS — a legacy save needs two boots to settle. The port reproduces the
      quirk deliberately and documents it; worth deciding whether to fix.

---

## Reference: the fixture scripts

Each regenerates a `test/fixtures/*.json` from the live JS. Re-run one whenever
the source module changes.

```bash
node tool/dump_default_save.mjs            > tool/default_save_v7.json
node tool/dump_random_reference.mjs        # prints; values are pasted into the test
node tool/dump_team_name_order.mjs         > test/fixtures/team_name_order.json
node tool/dump_progression_reference.mjs   > test/fixtures/progression_reference.json
node tool/dump_sell_price_reference.mjs    > test/fixtures/sell_price_reference.json
TZ=UTC node tool/dump_event_window_reference.mjs > test/fixtures/event_window_reference.json
node tool/dump_quest_bank_reference.mjs    > test/fixtures/quest_bank_reference.json
node tool/dump_quest_engine_reference.mjs  > test/fixtures/quest_engine_reference.json
node tool/dump_fixture_preview_reference.mjs > test/fixtures/fixture_preview_reference.json
node tool/dump_cup_engine_reference.mjs    > test/fixtures/cup_engine_reference.json
node tool/dump_manager_looks_reference.mjs > test/fixtures/manager_looks_reference.json
node tool/dump_season_end_reference.mjs    > test/fixtures/season_end_reference.json
```

`quest_engine_reference.json` is special: it ships the SAVE it was generated
against, and four other fixtures build on that same save. Regenerating it
invalidates the cup, fixture-preview and season-end fixtures too — regenerate
all four together.
