# What's left

The running list for the Flutter port. Tick a box when the module is ported
**and** tested — a port with no tests is not done.

Sources are `../merge-empire-fc/src/`. Line counts are the JS originals, as a
rough sense of size, not a target.

**Where we are:** M1 (logic core) is about 70% through by module count.
1,900 tests, 97.4% line coverage, `flutter analyze` clean.

**Standing rules**
- `lib/engine/`, `lib/data/`, `lib/state/`, `lib/util/` must never import
  `package:flutter/*` — enforced by `test/architecture_test.dart`.
- Seeded gameplay randomness goes through `util/random.dart`; anything matching
  JS `Math.random()` uses `dart:math`. Mixing them shifts every later draw.
- Save state stays `Map<String, dynamic>` with key insertion order preserved.
- Anything with non-obvious arithmetic gets a node-generated fixture under
  `test/fixtures/`, produced by a script in `tool/`.

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

- [x] `data/config.dart`, `data/divisions.dart`, `data/players.dart`
- [x] `data/formations.dart`, `data/traits.dart`, `data/sponsors.dart`
- [x] `data/loans.dart`, `data/transfer_market.dart`, `data/club_assets.dart`
- [x] `data/coin_sinks.dart`, `data/cups.dart`, `data/player_art.dart`
- [x] `data/events.dart` (379) — both window kinds, pinned under `TZ=UTC`
- [x] `data/ad_units.dart` — AdMob unit tables, split out of energyEngine
- [x] `engine/player_rating.dart` (ratingEngine, 111)
- [x] `engine/trait_engine.dart` (226)
- [x] `engine/merge_engine.dart` (217)
- [x] `engine/idle_engine.dart` (359)
- [x] `engine/sponsor_engine.dart` (112)
- [x] `engine/player_energy_engine.dart` (325)
- [x] `engine/energy_engine.dart` (310, pure half only — see M4 for the AdMob half)
- [x] `engine/lineup_engine.dart`
- [x] `engine/squad_rating.dart`, `engine/match_tactics.dart`,
      `engine/goal_model.dart`, `engine/match_events.dart`,
      `engine/match_resolution.dart` — matchEngine split five ways
- [x] `engine/transfer_engine.dart` (427)
- [x] `engine/loan_engine.dart` (417)
- [x] `engine/team_names.dart`
- [x] `engine/league_pyramid.dart`, `engine/season_fixtures.dart`,
      `engine/league_table.dart` — progressionEngine's league half (1,381)
- [x] `engine/gem_engine.dart` (451)
- [x] `engine/sell_engine.dart` (27)
- [x] `engine/auto_tier_engine.dart` (148)
- [x] `engine/event_engine.dart` (330)
- [x] `data/quests.dart` (1,042) — the 77-quest bank, a compile-time constant
- [x] `engine/quest_engine.dart` + `engine/quest_match.dart` (1,468) — both
      tracks, split by what they read: the save, and a match result
- [x] `engine/fixture_preview.dart` — `previewFixture`, split out of the match
      engine to break the quest/match import cycle the JS lives with
- [x] `engine/scout_engine.dart` (125)
- [x] `engine/coin_sink_engine.dart` (186)
- [x] `util/analytics.dart` — pluggable sink, so engines can log without Firebase
- [x] `util/sorting.dart` — stable sort, which Dart's `List.sort` is not

### Next up — the season-end chain

`progressionEngine.endSeason` is the last piece of progression and needs all of
these first. This is the critical path.

- [ ] `engine/cup_engine.dart` (637) — `data/cups.dart` is already done
- [ ] `engine/progression_season_end.dart` — `endSeason`, `processAgeRegression`,
      prestige, `trackEvent`. Depends on quests, cups, gems, events, auto-tier,
      and `managerAvatar` for the prestige cosmetics carry-over.
- [ ] `engine/match_orchestration.dart` — `simulateMatch`, `simulateHardGoals`,
      `previewFixture`. Needs quests and progression.

### Remaining engines

- [ ] `engine/deadline_day_engine.dart` (1,073) + `data/deadline_day.dart` (140)
- [ ] `engine/deadline_news_engine.dart` (310)
- [ ] `engine/deal_advice_engine.dart` (310)
- [ ] `engine/iap_engine.dart` (500) — catalogue and purchase application
- [ ] `engine/negotiation_engine.dart` (381) + `data/negotiation.dart` (135)
- [ ] `engine/event_cup_engine.dart` (371)
- [ ] `engine/mini_games_engine.dart` (368) + `data/mini_games.dart` (234)
- [ ] `engine/weather_engine.dart` (330)
- [ ] `engine/pyramid_names_engine.dart` (313)
- [ ] `engine/daily_reward_engine.dart` (270)
- [ ] `engine/scout_voucher_engine.dart` (253)
- [ ] `engine/club_asset_tiers.dart` (148)
- [ ] `engine/achievement_engine.dart` (145) + `data/achievements.dart` (301)
- [ ] `engine/ad_gate_engine.dart` (86)
- [ ] `engine/boot_room_engine.dart` (205)
- [ ] `engine/badge_engine.dart` (59)
- [ ] `engine/look_pack_engine.dart` (48)

### Remaining data

- [ ] `data/manager_avatar.dart` (1,458) — the customisation rig. Mostly SVG
      geometry, so it is really M3 material, but the persistence helpers
      (`persistentLookPacks`, `sanitizeAvatar`) are needed by prestige.
- [ ] `data/manager_mood.dart` (289) — `moodForScore`, `moodForDraw`
- [ ] `data/geo_zones.dart` (189)
- [ ] `data/pgs_achievements.dart` (107)
- [ ] `data/kit_palette.dart` (79)

### Remaining utils

- [ ] `util/kit_theme.dart` (417)
- [ ] `util/device.dart` (130)
- [ ] `util/region.dart` (55)
- [ ] `util/stat_display.dart` (23)
- [ ] `util/storage.dart` (1,051) — most of it is `migrate()`, already ported;
      audit what is left over

### The differential harness

- [ ] `tool/difftest/` — drive seeded scenarios through both node and Dart and
      diff whole simulated seasons, rather than function-by-function fixtures.
      The per-module fixtures already in `test/fixtures/` are the groundwork.

---

## M2 — state and reactivity

- [ ] Riverpod providers over the save
- [ ] Republish the event bus into providers (the bus itself stays pure Dart)
- [ ] `state/game_state.dart` (525) — load, migrate, debounced save, freeze on
      reset
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
- [ ] **Rive** for the walker (MCP to be installed)
- [ ] **Kenney.nl sprites** to replace the pitch circles with animated players

---

## M4 — services

- [ ] AdMob adapter (the half of energyEngine left behind, plus `iapClient`)
- [ ] Firebase: analytics sink, Crashlytics
- [ ] `authService` (662), `playGamesService` (155), `nativeAuthPlugin`
- [ ] `cloudSaveService` (498), `firestoreRest` (334), `firestoreRestAuth` (83)
- [ ] `leaderboardService` (1,831)
- [ ] `feedbackService` (195) — dormant; the Settings button is hidden
- [ ] `weatherService` (157)
- [ ] Local notifications — four of them, all `allowWhileIdle`
- [ ] `util/sound.js` (782) — synthesised SFX plus the one background track
- [ ] `util/wake_lock.dart` (54)
- [ ] `util/ad_consent.dart` (63), `util/network.dart`, `util/open_url.dart`

---

## M5 — i18n

- [ ] Locale files and the lookup layer
- [ ] Check the long-language layouts (German is the measured worst case)

---

## M6 — release

- [ ] **A final Capacitor release from the OLD repo that force-writes the native
      save mirror.** This is on the critical path: without it the Flutter build
      cannot read an existing player's local save. Must ship before cutover.
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
      & Profiles → Devices. It is what unblocks every iOS device pass, and it has
      been blocking since v1.15.9 of the old app.
- [ ] The `wc2026` event slot is dormant and will be reused for something else.
      Its shape and tests are the spec for whatever replaces it.
- [ ] `cosmetic_pack` has no AdMob unit on either platform, so it falls back to
      `energy_pip` and shares its frequency cap. Carried over from the JS.
