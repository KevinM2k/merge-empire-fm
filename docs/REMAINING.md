# What's left

The running list for the Flutter port. Tick a box when the module is ported
**and** tested — a port with no tests is not done.

Sources are `../merge-empire-fc/src/`. Line counts are the JS originals, as a
rough sense of size, not a target.

---

## What done looks like

The whole game, running on Flutter, with nothing switched off. Concretely: a player
can install it, have their old save picked up, play matches and seasons, merge,
scout, trade, take part in events and **spend real money** — every SKU buyable on
both stores — with cloud save, leaderboards, ads, sound and every language working.

Two consequences worth keeping in view, because both are easy to leave until it is
too late:

- **A ported engine is not a working feature.** The logic core is nearly finished
  and almost none of it is reachable yet: there is no UI, no state plumbing and no
  services. M1 finishing does not move the game closer to playable on its own.
- **IAP is a chain, and one broken link means no revenue.** See the IAP block in
  M4 — the engine half is done, the billing bridge, the consent gate and the store
  configuration are not.

---

## Where we are

**2,535 tests, 97.6% line coverage, `flutter analyze` clean.** Everything below
the M1 heading that isn't ticked is what remains.

M0 (save bridge) is finished. **M1 (the logic core) is roughly 80% through by
module count**, and — more usefully — the whole spine now works end to end:
a match can be PLAYED (ninety minutes, injuries, tactic changes, settlement), a
season played out, the table settles, the pyramid shuffles, quests roll and pay,
cups run, and the season boundary hands over to the next campaign. `matchEngine.js`
is fully ported. What is left in M1 is a long tail of smaller engines, none of
them on the critical path.

### How to pick this up

```bash
cd ~/code/github/kevinm2k/merge-empire-fc-flutter
flutter analyze          # must be clean
flutter test             # 2,358 passing
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

### The name

The game is **Merge Empire Football Manager**. That is the display name only —
`CFBundleDisplayName`, the Android `android:label`, the window title and the store
listings. The IDENTIFIERS deliberately still read `mergeempirefc`:

- iOS `PRODUCT_BUNDLE_IDENTIFIER` = `com.mergeempirefc.app`
- Android `applicationId` / `namespace` = `com.mergeempirefc.app`
- the Dart package, `merge_empire_fc`

The first two are the store's primary key for an existing, published app — change
either and it is a NEW app, with no upgrade path for anyone who already has it and
no access to the existing reviews or rankings. The third is internal, and renaming
it would churn every import in the repo for nothing a player can see.
`CFBundleName` is the short name iOS truncates hard, so it reads
"Merge Empire FM".

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

Worth reading before writing the next port. Two shapes, over and over: a draw
happening in the wrong place, and a Dart type that doesn't serialise the way the
JS number or object did.

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
- **`simulateMatch`** built the AI rotation plan with the draw for HOW MANY subs
  inside the loop condition, so it was re-rolled every iteration. One extra
  number, and every later draw in the match moved — it showed up as the wrong
  added time on the final whistle.
- **`buildDefaultLineup`** (and `fillLineupGaps`) sorted their (player, slot)
  pairs with a comparator that returns 0 on a tie, which is only correct if the
  sort is STABLE. `Array.sort` is; `List.sort` is not. The same squad fielded a
  different XI. Both use `stableSort` now — if you write a comparator that can
  return 0, use it.
- **`roundCoins`** returned a double, so a payout landed in the save as `75.0`
  where the JS writes `75`. Equal as numbers, different as JSON, and coins are
  the most-written field there is. Anything going into the save that JS holds as
  a whole number must arrive as a Dart `int`.

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
- [x] `negotiation_engine` (381) + `data/negotiation` (135) — valuation, offers,
      counters and the transfer list. Deadline Day imports eight functions from
      it, so it has to land first whatever order the list is written in
- [x] `deadline_day_engine` (1,073) + `data/deadline_day` (140) — the live
      wall-clock trading session. Pinned against node over whole SESSIONS at
      fixed instants, plus every interaction path, because the risk here is the
      schedule being anchored to the player rather than to the window
- [x] `iap_engine` (500) — the catalogue and the grant step. **The pure half
      only**, the same split `energy_engine` took: `initiatePurchase` needs native
      billing and the parental-consent gate, both M4. The whole catalogue is
      compared field by field, because a SKU is a live store product id and a typo
      is a product nobody can buy
- [x] `achievement_engine` (145) + `data/achievements` (301) — all 81 predicates,
      each fired against the state that should unlock it AND a near-miss that
      should not, since a predicate missing one condition passes every positive
      case
- [x] `tactic_coach` — `tacticExpectedPoints`, `injuryCostPoints`,
      `baselineInjuryRisk`, `suggestTactic`. Split out of `match_tactics` by what
      it reads: that file is the tactic TABLE every ATK/DEF readout shares, this
      scores those tactics against a matchup and a squad
- [x] `match_orchestration` — the outer half of `matchEngine.js`. `simulateMatch`,
      `simulateHardGoals`, `hardLiveRatings`, `finalizeMatchOutcome` (with
      `drawContextOf`), `applyMatchRewards`, `reSimulateRemainder`,
      `bestFormationForFixture` and the cooldowns. **`matchEngine.js` is now
      fully ported.** Pinned against node over 52 whole matches — result, feed
      and save — with BOTH streams reproducible: the dump script replaces
      `Math.random` with a second mulberry32 and `test/support/js_math_random.dart`
      drives the same one, so the unseeded half is comparable too
- [x] `event_cup_engine` (371) — the bracket that runs alongside the league cup.
      Pinned over whole tournaments rather than per function, because the other
      fifteen nations are simulated IN ARREARS — seven ties the moment the player
      wins the R16, three after the quarter-final, one after the semi — so
      advancing the bracket a beat early or late gives a plausible tournament
      that shares nothing with the JS one. Eight runs cover every conditional the
      win branch has: winning as the best- and worst-rated nation, a clean sheet
      across the whole bracket, and going out in the first round and the semi
- [x] `mini_games_engine` (368) + `data/mini_games` (234) — seven games' worth of
      cooldowns, payouts and stat counters. The JS spells out `penaltyReady`,
      `msUntilPenalty`, `effectivePenaltyCooldown` and their six identical
      siblings; those are one table and four functions taking a kind here, which
      is how the callers already work. The `record*Result` family is NOT
      collapsed — each writes a different set of counters, and the counters are
      quest and achievement targets, so a wrong key is a quest that can never be
      finished. `util/time`'s `dateString` lands with it: the free-skip ledger
      keys off JS `toDateString()` and that key is written to the save
- [x] `weather_engine` (330) + `data/geo_zones` (189) — what the sky is doing
      over the diorama, live where there is a reading and modelled where there
      is not. Pure by construction: `nowMs` and `rand` are arguments, so the
      fixture pins twenty rolls across every band and season, which catches the
      real risk — the weighted walk subtracts as it goes, so the same weights in
      a different ORDER give a different sky for the same roll. Reading the
      device timezone is left to M4, the same split `energy_engine` took;
      `resolveCoords` takes the zone as an argument
- [x] `pyramid_names_engine` (313) — renaming the AI clubs, and saving the
      56-name set as a preset. A rename is a PROPAGATION across eleven
      name-keyed structures, so the fixture compares the whole save after each
      one rather than a summary; the apply is two-phase because re-applying a
      preset after a few seasons routinely asks two clubs to swap names, and one
      pass would collide with a name that is itself about to move
- [x] `deadline_news_engine` (310) — the ticker under the event banner, in its
      three phases. Deterministic by design: the strip is rebuilt on every League
      re-render and a fresh draw would reshuffle the rumours mid-read, so it runs
      off a stream of its OWN seeded on the window (or an hour bucket through the
      build-up). `util/random` gained a `Mulberry32` class for it — the shared
      global stream is now one instance of it, rather than a second copy of the
      algorithm
- [x] `deal_advice_engine` (310) — Coach Colin's read on a listing. No strings:
      it returns reason IDS and the UI maps them, the same rule the club-asset
      tiers follow. The fixture derives every price from `playerValue` at
      generation time, so each case lands in the band it is named for, and it
      pins the CAPS specifically — a cap applied as a demotion prints "worth
      doing" over "we're already well stocked"
- [x] `daily_reward_engine` (270) — the seven-day login calendar, the only
      repeating gem faucet in the game. Everything turns on a LOCAL day key, so
      the fixture ships calendar components rather than epoch stamps and both
      runtimes build their own instants at local noon. The streak and the cycle
      day are pinned apart: they are different numbers, and a repaired streak of
      nine sits on cycle day 6

**Utils**

- [x] `analytics` — pluggable sink, so engines log without importing Firebase
- [x] `sorting` — stable sort, which Dart's `List.sort` is not

### Next up — `scout_voucher_engine`

253 lines, then the handful of sub-100-line engines and the last of the data.

### Remaining engines

Roughly in dependency order.

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
- [ ] `manager_mood` (289) — `moodForScore`, `moodForDraw`. The three facts
      `moodForDraw` needs are already stored on `progression.lastMatchResult`
      by `finalizeMatchOutcome` (`led`, `trailed`, `ratingGap`), so the dugout
      cam and the diorama cannot disagree about the same draw
- [ ] `pgs_achievements` (107)
- [ ] `kit_palette` (79)

### Remaining utils

- [ ] `kit_theme` (417)
- [ ] `device` (130)
- [ ] `region` (55)
- [ ] `stat_display` (23)
- [ ] `storage` (1,051) — most of it is `migrate()`, already ported; audit what
      is left over and delete this line if nothing is

### Bugs carried over from the JS

Found while porting, reproduced faithfully rather than fixed, because each one is a
gameplay or economy decision rather than a mechanical slip. All are pinned by a test
so the current behaviour is visible and a deliberate change is a one-line edit.

- [ ] **A Deadline Day signing hands over a different card from the one the feed
      showed.** `_acceptSigning` rolls a FRESH instance and copies only the name,
      so the variant, the trait and the ATK/DEF split you were shown are not what
      lands on the grid. The feed reads `listing.card` (EventScreen.js:1316) and
      the pre-roll exists precisely so "the portrait, the rating and the stat split
      on the offer are exactly what lands on your grid" — the JS contradicts its
      own comment. Placing `listing.card` instead would change which card arrives
      AND consume fewer draws, shifting every later listing in the window.
      See `_acceptSigning` in `engine/deadline_day_engine.dart`.
- [ ] **Achievements can never be re-unlocked, though the engine is built to let
      them.** `checkAchievements` gates on ids earned THIS RUN — a list cleared on
      prestige or reset, with a comment saying that is what makes them
      re-unlockable — and then ALSO on ids earned ever. The second guard subsumes
      the first, so clearing the per-run list achieves nothing, the branch that
      increments a `count` and reports `isReUnlock` is unreachable, and both are
      always 1 and false. Removing the guard turns every achievement into a coin
      faucet on every reset, so it needs a decision about the economy first.
      See `checkAchievements` in `engine/achievement_engine.dart`.
- [ ] **`hard_100_wins` pays 100 coins; `win_100_matches` pays 1,000.** Every cup,
      Pro-mode, mini-game, reset and event achievement is missing from
      `ACHIEVEMENT_COIN_REWARDS` and falls to the default of 100. Reads like an
      oversight rather than a decision, but it is tuning.
- [ ] **Two achievements are both called "Living Legend"** — `prestige_level_10`
      and `merge_to_legend`. Cosmetic, and a one-word fix, but it is user-facing
      copy so it wants a chosen replacement rather than an invented one.
- [ ] **`vipPrestigeLinked` is dead code, and the comment above `vip_pass`
      describes it as live.** That comment says the pass runs until the next
      prestige with "no wall-clock timer"; the product actually carries
      `vipDays: 30`. One of the two is wrong. The branch is ported and unreachable,
      so switching it on is a data change.
- [ ] **Finishing Goalkeeper Practice can DRAIN an upgraded energy tank.**
      `recordTrainingComplete` clamps against `ENERGY.MAX` (10) rather than
      `getEnergyMax(state)` (15 with the Energy Director upgrade), so a player
      sitting above ten pips is clamped back down by a game that grants no
      energy at all — and the returned `energyGranted` reads as a negative
      "grant". The grant being zero is what hides it. One-line fix, but it is a
      live economy change for anyone holding the upgrade. See
      `recordTrainingComplete` in `engine/mini_games_engine.dart`.
- [ ] **Two of Coach Colin's reasons can never fire.** `too_dear` needs a price
      above the balance on a deal that is NOT blocked, but both buy-side kinds
      gate on the same comparison, so that state does not exist. `no_room` needs
      zero free slots on a signing that is still allowed, and the squad cap (30)
      is twice the grid (15), so it cannot happen either. Both are ported and
      commented; deleting them is a decision about whether the gates might ever
      diverge from the advice.
- [ ] Two smaller dead ends, ported as defensive and worth deleting if nothing is
      going to use them: `product.energy` (no product carries it — every energy
      product uses `energyAdd`), and `WC_RATING_BY_NATION` in `achievements.js`,
      which is declared and never read. The latter is simply not ported.

### Fixed in the port rather than carried

- **`purchaseProduct` crashed on a save with no `shop` branch.** It writes
  `state.shop.totalSpent` while only creating the branch inside two of the grant
  branches, so a coin bundle threw. Unreachable in the app — the schema always
  writes `shop` — but a real latent crash, and the JS's own
  `state.shop = state.shop ?? {}` elsewhere shows the defensiveness was intended.
  The port creates it up front, which cannot change behaviour where it exists.
- The two stable-sort bugs and `roundCoins`, above.

### The differential harness

- [ ] `tool/difftest/` — drive seeded scenarios through both node and Dart and
      diff WHOLE SIMULATED SEASONS rather than function-by-function fixtures.
      The eleven per-module fixtures already in `test/fixtures/` are the
      groundwork, and the pattern is proven; `match_orchestration_reference`
      is the closest to it — it already compares a whole match's result, feed
      and save, off both generators. This is the same idea at the level of
      "play twenty seasons and compare every byte of the save", and now that
      a match can be played end to end there is nothing left blocking it.

---

## M2 — state and reactivity

- [ ] Riverpod providers over the save
- [ ] Republish the event bus into providers (the bus itself stays pure Dart)
- [ ] `state/game_state.dart` (525) — load, migrate, debounced save, the freeze
      flag on reset
- [ ] Save on pause / lifecycle change
- [ ] **`main.js` (1,453) — the wiring.** Bootstrap, the tick loop, and the bus
      listeners that turn an engine's announcement into a state change. Not a
      formality: several engines deliberately do NOT apply their own reward and
      rely on a listener here to do it with the save wrapper. The one that pays
      achievement coins on `achievement:unlocked` is the example to check first —
      without it every achievement unlocks and pays nothing.

---

## M3 — UI

76 files, 41,560 lines of vanilla JS — measured, not estimated, and the single
biggest block of work left in the project by a wide margin. Rebuilt idiomatically
rather than transliterated; identity, layout and assets stay.

The screens are listed by feature below rather than file by file, deliberately: the
mapping is not one-to-one. For scale, the four that dominate are
`LeagueScreen` (6,777), `MatchPopup` (3,715), `SquadScreen` (2,264) and
`ChanceCutaway` (2,036).

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
- [ ] **The SVG art that is not player art**: `assets/clubArt` (430),
      `assets/gemArt` (146), `assets/svgCache` (54). `playerArt` is already ported;
      these three are not, and the crest, the club-asset tiles and the gem icons
      all read from them.

---

## M4 — services

### IAP, end to end

The engine half is done and **cannot take a payment on its own**. Every link below
has to land before a single SKU is buyable, and the chain fails silently: a missing
consent gate ships a compliance problem, a missing store product shows a shop full
of buttons that error.

- [x] `iap_engine` — the catalogue and the grant step (M1)
- [ ] `engine/iapClient` (195) — the native billing bridge. Play Billing and
      StoreKit, via whichever plugin replaces cordova-plugin-purchase
- [ ] `utils/ageVerification` (134) — `isIapAllowed`, which blocks IAP for
      Play-verified minors without parental consent. **A legal requirement**
      (Texas SB 2420), not a nicety, and it gates the purchase flow
- [ ] `initiatePurchase` — the "user tapped Buy" flow that ties the three
      together. Deliberately left out of the M1 port because it needs the two
      above; the pre-flight checks it does are already in the engine
- [ ] Restore purchases, and re-grant of non-consumables on a fresh install
- [ ] The Shop screen (`ShopScreen`, 1,387 — counted in M3)
- [ ] Every SKU created and priced in App Store Connect AND Play Console, in both
      cases matching `IapProduct.sku` exactly (see M6)

### The rest

- [ ] AdMob adapter — the half of `energyEngine` left behind in M1
- [ ] Firebase: `services/firebase` (146) init, the analytics sink, Crashlytics
- [ ] `authService` (662), `playGamesService` (155), `nativeAuthPlugin`
- [ ] `cloudSaveService` (498), `firestoreRest` (334), `firestoreRestAuth` (83)
- [ ] `leaderboardService` (1,831)
- [ ] `feedbackService` (195) — dormant; the Settings button is hidden
- [ ] `weatherService` (157) — and with it the device's IANA timezone, which the
      JS reads from `Intl`. Dart has no equivalent without a plugin, so
      `data/geo_zones` takes the zone as an argument and this is the half that
      has to supply it
- [ ] Local notifications — four of them, all `allowWhileIdle`
- [ ] `util/sound.js` (782) — synthesised SFX plus the one background track
- [ ] `util/wake_lock` (54)
- [ ] `util/ad_consent` (63), `util/network` (8), `util/open_url` (15)

**Not being ported**, recorded so nobody goes looking:

- `services/nativeSaveMirror` (77) belongs to the OLD app — it WRITES the mirror
  the Flutter build reads. Its counterpart here is `legacy_save_bridge`, done in
  M0, and the write side ships one last time from the old repo (see M6).
- `utils/devTools` (114) is a dev-only console helper with no shipping surface.

---

## M5 — i18n

14 files, 29,438 lines: ten locales at ~2,900 each plus the lookup layer. Bulk, not
difficulty — but it is a third of the size of the UI and easy to under-budget.

- [ ] `i18n/index` — the lookup layer and the `t()` contract engines already emit
      keys against (the match feed emits `commentary.flow.*`, the achievements
      `ach.title.*` / `ach.desc.*`)
- [ ] The ten locale files: ar, de, en, es, fr, it, ja, ko, pt, zh
- [ ] Check the long-language layouts (German is the measured worst case)

---

## M6 — release

- [ ] **A final Capacitor release from the OLD repo that force-writes the native
      save mirror.** On the critical path: without it the Flutter build cannot
      read an existing player's local save. Must ship before cutover.
- [ ] iOS: signing, dSYM upload, App Store Connect
- [ ] Android: the CI-generated build config, SDK levels, AGP/Gradle
- [ ] Store listings, whatsnew, changelog — the listing NAME becomes
      "Merge Empire Football Manager"; the bundle id must not move with it
- [ ] **The in-app products themselves, in both consoles.** Eleven SKUs, each
      matching `IapProduct.sku` character for character, with the consumable /
      non-consumable flag matching `IapProduct.type` — the store is what refuses a
      repeat purchase of a one-time product, not our code. They already exist for
      the live app; this is a check, not a creation, and the check matters because
      a renamed product id is an unbuyable product.
- [ ] Sandbox purchase pass on both platforms: every SKU bought once, plus a
      restore on a clean install.

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
node tool/dump_tactic_coach_reference.mjs  > test/fixtures/tactic_coach_reference.json
node tool/dump_match_orchestration_reference.mjs > test/fixtures/match_orchestration_reference.json
node tool/dump_negotiation_reference.mjs   > test/fixtures/negotiation_reference.json
node tool/dump_deadline_day_reference.mjs  > test/fixtures/deadline_day_reference.json
node tool/dump_iap_reference.mjs           > test/fixtures/iap_reference.json
node tool/dump_achievements_reference.mjs  > test/fixtures/achievements_reference.json
node tool/dump_event_cup_reference.mjs     > test/fixtures/event_cup_reference.json
node tool/dump_mini_games_reference.mjs    > test/fixtures/mini_games_reference.json
node tool/dump_weather_reference.mjs       > test/fixtures/weather_reference.json
node tool/dump_pyramid_names_reference.mjs > test/fixtures/pyramid_names_reference.json
node tool/dump_deadline_news_reference.mjs > test/fixtures/deadline_news_reference.json
node tool/dump_deal_advice_reference.mjs   > test/fixtures/deal_advice_reference.json
node tool/dump_daily_reward_reference.mjs  > test/fixtures/daily_reward_reference.json
```

`match_orchestration_reference.json` is the only one that pins the UNSEEDED
stream as well: it stubs `Date.now` and replaces `Math.random` with a second
mulberry32, and the Dart side drives an identical one through `setEventRandom` /
`setMatchRandom`. Both have to be the SAME instance in a test, because the JS has
only one `Math.random`.

`quest_engine_reference.json` is special: it ships the SAVE it was generated
against, and four other fixtures build on that same save. Regenerating it
invalidates the cup, fixture-preview and season-end fixtures too — regenerate
all four together.
