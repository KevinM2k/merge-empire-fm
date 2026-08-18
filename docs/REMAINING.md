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

- **A ported engine is not a working feature.** The logic core and the state
  layer are both finished and a player would still see nothing: there is no UI
  and there are no services. Ticking those two milestones did not, on its own,
  move the game closer to playable.
- **IAP is a chain, and one broken link means no revenue.** See the IAP block in
  M4 — the engine half is done, the billing bridge, the consent gate and the store
  configuration are not.

---

## Where we are

**2,938 tests, 97.7% line coverage, `flutter analyze` clean.** Everything below the M1 heading that
isn't ticked is what remains.

M0 (save bridge) is finished. **M1 (the logic core) is done** — every engine,
every data table but one, every utility, and the differential harness. The one
exception is `managerAvatar`'s SVG geometry, which is drawing rather than logic
and is listed under M3 where it belongs. **M2 (the state layer) is done** — the
save, the loop, the listeners that pay, the providers and the lifecycle
observer. **The i18n layer is in** — `t()`, all ten catalogues and the guard
suite — which was M5 and landed early so no screen has to hardcode English.
**M3 has started**: the theme, the five-tab shell, the HUD, the popup plumbing
and Settings are in. The five tab bodies are still placeholders.

The proof that it is done, rather than merely all ticked: the harness plays six
whole seasons through both runtimes, casual and Pro, and every byte of the save
matches at every one of 336 matches a run. A match is PLAYED (ninety minutes,
injuries, tactic changes, settlement), a season plays out, the table settles, the
pyramid shuffles, quests roll and pay, cups run, and the season boundary hands
over to the next campaign — and the JS and the port agree about all of it.

**It runs, and now there is something to look at — but nothing to do.** The app
boots into a themed five-tab shell with a live HUD, and Settings works. What no
tab has yet is a body: the grid, the squad, the league, the club and the shop
are all placeholders. Each is its own module from here.

### How far along, honestly

Measured, not estimated: `101,866` lines of non-test JS in `../merge-empire-fc/src`,
of which roughly **56,000 are ported — about 55%.**

That number doubled in one module and it should not be read as the work
doubling. See the first bullet below the table.

| Area | JS lines | State |
|---|---|---|
| `engine/` | 15,331 | done bar `iapClient.js` (195) |
| `data/` | 6,357 | done bar `managerAvatar.js` (1,458) |
| `utils/` | 3,396 | done bar 1,170 (`sound` 782, `ageVerification` 134, `devTools` 114, `adConsent` 63, `wakeLock` 54, `openUrl` 15, `network` 8) |
| `state/` + `main.js` | 2,333 | done |
| `assets/` | 853 | `playerArt` done; `clubArt` 430, `gemArt` 146, `svgCache` 54 left |
| `services/` | 4,144 | only `nativeSaveMirror` has a counterpart |
| `i18n/` | 29,123 | done — the lookup layer and all ten catalogues |
| `ui/` | 40,329 | the shell, HUD, theme, popup shapes and Settings; no tab body |

Do not read 53% as "half the work", in either direction:

- **29,067 of those lines are the ten locale catalogues**, converted by a script
  in an afternoon. They were 29% of the port by line count and nothing like 29%
  of the effort — which is exactly why the percentage jumped from 24% to 53%
  without the game getting materially closer to playable. Discount them and the
  real figure is nearer 25%.
- **The UI will not be a line-for-line port.** 40,329 lines of hand-rolled DOM
  manipulation becomes materially less Dart, so that denominator is soft.
- **The UI is where the port gets SHORTER.** The shell replaced roughly 1,100
  lines of `App.js`, `HUD.js` and `popupQueue.js` with about 1,300 lines of
  Dart — but a large part of what it did not have to port was workaround:
  `screenFreeze.js` in full, the two-frame `requestAnimationFrame` dance before
  every slide, the swipe-vs-drag exclusion list, and the re-parenting that let
  one wrapper serve tabs, sheets and overlays. `TickerMode`, routes and the
  gesture arena are those four, and they are one line each.

The useful summary is that the correctness-critical half is finished and proven,
and the visible half has not started.

### Where the JS modules went

Several JS files were split or renamed on the way over, so a filename comparison
will report them missing when they are not. Check here before concluding
something was skipped.

| JS source | Dart |
|---|---|
| `engine/matchEngine.js` (2,709) | `match_orchestration`, `match_events`, `match_resolution`, `match_tactics`, `goal_model`, `squad_rating` |
| `engine/progressionEngine.js` (1,381) | `league_table`, `league_pyramid`, `season_fixtures`, `season_end`, `team_names` |
| `engine/ratingEngine.js` (111) | `player_rating` |
| `utils/storage.js` (1,051) | `state/save_slots`, `state/save_codec`, `state/migration` |
| `data/managerAvatar.js` (1,458) | `data/manager_looks` (the unlock half only — the SVG geometry is M3) |
| `engine/energyEngine.js` (310) | `engine/energy_engine` + `data/ad_units` (the AdMob call itself is M4) |
| `main.js` (1,453) | `state/game_tick`, `state/game_wiring`, `state/game_runner` |
| `utils/eventBus.js` | `util/event_bus` + `providers/bus_providers` |

### How to pick this up

```bash
cd ~/code/github/kevinm2k/merge-empire-fm
flutter analyze          # must be clean
flutter test             # 2,936 passing, 2 skipped
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

- `lib/engine/`, `lib/data/`, `lib/i18n/`, `lib/state/`, `lib/util/` must never
  import `package:flutter/*` — enforced by `test/architecture_test.dart`.
- **Every user-facing string goes through `t()`.** Never a literal. The key must
  exist in `en`, or `test/i18n/call_sites_test.dart` fails the build.
- Nothing ending `.g.dart` is edited by hand — change the generator and re-run it.
- **Read the theme through `Theme.of(context).extension<KitTheme>()!`.** Never a
  hardcoded colour: the whole palette is derived from the club's kit.
- **Navigate through `shellControllerProvider`**, not by emitting a bus event by
  hand. The bus listeners in `shell_controller.dart` are the only code that
  should know those strings.
- **A popup is one of three shapes** — bottom sheet, Coach Colin card, quick-nav
  menu — and goes on screen through `enqueuePopup`. Do not invent a fourth; that
  is a change to the spec first.
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

- **`buildLeagueTable` wrote two keys the wrong way round.** It filled a local
  map and assigned it to `opponentTablePositions` AFTER the loop that writes
  `playerTablePosition`, so the two keys landed in the progression branch in the
  opposite order from the JS. Every value agreed; the bytes did not. Caught by
  the differential harness, which is the only test that compares a save as a
  save rather than as a bag of values.

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
- [x] `manager_mood` (289) — `moodForScore`, `moodForDraw`, the gesture rota and
      the ball plays. The thresholds are deliberately the match popup's, so the
      walker cannot celebrate a result Coach Colin has just called unacceptable;
      the fixture pins the draw EDGE across the whole grid, and a test enforces
      the rule the rota exists for — a gesture marked as a celebration may only
      carry `elated` and `pleased` weights
- [x] `pgs_achievements` (107) — the Play Games id map. Six of the 76 are mapped;
      the rest are null and silently skipped until the Console list is published
- [x] `kit_palette` (79) — what a kit id actually paints with. `kitSwatchCss`
      still returns the web build's CSS string: the pattern DATA is the same
      either way, and turning it into a Flutter gradient is an M3 decision

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
- [x] `scout_voucher_engine` (253) — the guaranteed-floor scout. What is buyable
      is DERIVED from the division's scout odds, which is the rule the whole item
      rests on: a voucher compresses time and never raises the ceiling. The
      one-voucher rule lives in two files that cannot import each other, so the
      test drives `anyVoucherArmed` and `gem_engine`'s `scout_voucher_gem`
      against the same shop shapes and asserts they agree
- [x] `boot_room_engine` (205) — the match-3 board as pure logic: runs, gravity,
      refill, cascades and the deadlock reshuffle. Randomness is an argument, so
      the fixture pins whole settles off a shared mulberry32 — which catches the
      refill ORDER (column by column, top-up counted upward) as well as the
      results, and the L and T shapes where one cell is in two runs at once
- [x] `club_asset_tiers` (148) — the Club screen's tier cards. Every line is
      derived from the gate function the game actually uses, with unlocks as a
      DIFF across the tier boundary, so a card cannot claim a perk the engine
      does not grant or miss one it does. The test pins both directions
- [x] `ad_gate_engine` (86), `badge_engine` (59), `look_pack_engine` (48) — the
      rewarded-ad frequency window, the shirt badge and the look-pack shop tile.
      One shared fixture: none of the three is big enough to earn its own

**Utils**

- [x] `analytics` — pluggable sink, so engines log without importing Firebase
- [x] `sorting` — stable sort, which Dart's `List.sort` is not

The last four were each split the same way the AdMob half of `energy_engine`
was: the decision here, the platform read in M3 or M4.

- [x] `kit_theme` (417) — the colour maths: hex to HSL and back, WCAG luminance,
      and `inkFor`, which used to be an HSL-lightness test and gave a yellow kit
      WHITE ink on a yellow button. The per-kit table of CSS custom properties is
      M3: Flutter has a `ThemeData`, not custom properties
- [x] `device` (130) — the low-end policy: the hardware heuristic and the
      frame-window verdict. Reading the hardware and driving the probe are M3/M4
- [x] `region` (55) — the region code. `ensurePlayerRegion` reports whether it
      wrote, rather than calling `scheduleSave` itself, because that is M2 —
      `providers/game_host.dart` is the caller it was waiting for
- [x] `stat_display` (23)
- [x] `storage` (1,051) — audited. `migrate()` was already ported and the JSON
      round trip is `save_codec`; what was left is the SLOT policy, now
      `state/save_slots.dart`. Not incidental: the last-good mirror is what stops
      a process killed mid-write wiping a player's progress. `recoverSave` hands
      back a PLAN — which copy to use, which bytes to stash — so M2 wires it to
      real persistence without re-deciding any of it

### Next up — M3

Nothing is left in M1 or M2, and M5 came forward to join them: the game boots,
loads, ticks, saves and can now say all of it in ten languages. What it has no
way to do is SHOW any of it. M3 is the biggest block of work in the project and
everything a player can see. Start at "The screens".

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
- **A yellow or cyan kit printed white text on its own accent, in dark mode.**
  `kitTheme.js` grew `inkFor` — a WCAG relative-luminance measure — precisely to
  fix this, and calls it on the light path with a comment saying so. The derived
  DARK path kept the older `lightness > 55` test, which hands white ink to any
  pale accent. `#ffd700` and `#00c8ff` both fail it; `empire` avoids it only
  because that kit's ink is hand-picked. The port measures in both modes, using
  the two inks the JS already paints with so a kit it got right does not shift
  shade. Pinned in `test/util/kit_theme_test.dart`, with the JS's wrong answer
  kept in the fixture so the divergence stays visible.
- **`GameState.dispose()` left its debounced write armed.** The method is
  documented as test-only, and the timer it left behind would fire into a
  disposed object, taking a real change with it. It flushes now.

### The differential harness

- [x] `tool/difftest/` — six whole seasons, casual and Pro, driven through both
      runtimes and compared at every step: 336 matches a run, the save hashed
      after each one and compared in full at every season boundary. See
      `tool/difftest/README.md`.

      It earned its keep on the first run. Every value in the save agreed and
      the BYTES did not: `buildLeagueTable` created `opponentTablePositions`
      after the loop that writes `playerTablePosition`, so the two keys landed
      in the progression branch the other way round from the JS. No per-module
      fixture could have caught it — each one compares values, and this is the
      only test that compares the save as a save.

      Scope, honestly: it plays LEAGUE seasons. Merges, scouts, the shop, cups
      and the event tracks are not driven yet, so the parts of the save they
      write are only carried along. Adding them is a matter of extending the
      driver at both ends, which is now one function each side.

---

## M2 — state and reactivity

**Done.** The game now boots, loads a real save off the device, runs its loop,
pays what the engines announce, and saves when the player leaves. There is still
nothing to look at — that is M3 — but everything under it is running.

- [x] `state/game_state.dart` (525) — load, migrate, debounced save, the freeze
      flag on reset. Also the native mirror, the cloud restore, and the boot
      ladder from `save_slots`' recovery plan
- [x] **`main.js` (1,453) — the wiring.** Split three ways, because the JS keeps
      the loop, the listeners and the DOM lookups in one module scope:
      `state/game_tick.dart` is one turn as a pure function of the save and a
      `TickGates` record; `state/game_wiring.dart` is the bus listeners that
      write to the save; `state/game_runner.dart` owns the timer and turns a
      tick into bus events. The listener that pays achievement coins is tested
      first, as the note here said to
- [x] Riverpod providers over the save — `providers/game_providers.dart`. One
      revision counter fed by `GameState.changes`, and a derived provider per
      value, so a coin landing rebuilds the coin label and nothing else. The
      save is one mutable map, so watching it directly would never fire
- [x] Republish the event bus into providers — `providers/bus_providers.dart`.
      The bus itself is untouched and still Flutter-free
- [x] Save on pause / lifecycle change — `providers/game_host.dart`. Note it
      does NOT pause on `inactive`: that fires for the notification shade and
      the app switcher, and stopping the loop there is a stall the player never
      asked for
- [x] Real persistence — `services/prefs_save_store.dart`. Read into memory once
      at boot and written through, because the `SaveStore` contract is
      synchronous and the debounced save fires from a timer

What is deliberately still stubbed, and lands with the service it belongs to:
the cloud upload hook (`uploadCloudSave`) and the native mirror reader are
constructor seams on `GameState` with nothing plugged into them yet — M4.

---

## M3 — UI

76 files, 41,560 lines of vanilla JS — measured, not estimated, and the single
biggest block of work left in the project by a wide margin. Rebuilt idiomatically
rather than transliterated; identity, layout and assets stay.

The screens are listed by feature below rather than file by file, deliberately: the
mapping is not one-to-one. For scale, the four that dominate are
`LeagueScreen` (6,777), `MatchPopup` (3,715), `SquadScreen` (2,264) and
`ChanceCutaway` (2,036).

### What M2 and the shell left you to build on

The plumbing a screen needs already exists. Use it rather than reaching past it.

- **Read values through a derived provider, never the save map.** The save is one
  mutable instance, so `==` never fires and a widget watching it directly would
  never rebuild. `providers/game_providers.dart` has `savePick(...)` — add a
  provider next to `coinsProvider` for whatever the screen needs.
- **Write through `game.update(...)`.** That is what schedules the save and
  notifies the providers. A raw write to the map needs a `notifyChanged()` and is
  only correct where the tick loop does it, for a reason spelled out there.
- **Put the screen in `AppShell`'s IndexedStack**, replacing that tab's
  `PlaceholderScreen`. It gets `TickerMode` for free, so nothing offscreen
  animates and no screen needs a freeze of its own.
- **A takeover screen MUST set `tickGatesProvider` while it is up.** That is the
  whole reason the gates are a record rather than a DOM query: without it the loop
  will drop a transfer bid over the match, or Coach Colin on top of a mini-game.
  Clear it on the way out.
- **One-shot signals come off `busEventProvider('name')`; values do not.** A
  stream a widget subscribed to late has already missed its event, so anything
  that lives on the save is a derived provider.
- **Use `t()` from the first line of every screen. Never hardcode English.**
  `lib/i18n/i18n.dart` is in and all ten catalogues with it, so there is nothing
  to retrofit and no reason to. `test/i18n/call_sites_test.dart` scans `lib/` and
  fails the build if a screen names a key English does not have — which is the
  test that stops `ach.title.foo` rendering across a card.

### The screens

- [x] Shell: five tabs plus the hidden Settings screen — `lib/ui/shell/`,
      `lib/ui/theme/`, `lib/ui/hud/`, `lib/ui/popups/`. See
      `docs/superpowers/specs/2026-08-18-shell-design.md`. Still to land with
      the League screen: tapping Play resets it to the Overview sub-tab, which
      has nowhere to go until sub-tabs exist
- [ ] Merge grid — drag and drop, lazy card mounting, the frame-budget rules
- [ ] Squad, Club, League, Shop screens
- [ ] The live match page (a takeover screen, not a popup)
- [ ] Season-end takeover
- [x] The three popup shapes — bottom sheet, Coach Colin card, quick-nav menu.
      Do not invent a fourth. The queue behind them is `util/popup_queue.dart`,
      and it holds a no-host blocker from boot so a card queued before any widget
      existed waits rather than being dropped
- [ ] Mini-games: Penalty Training, Boot Room, Pitch Invaders, the rest
- [ ] Trophy room
- [ ] Deadline Day screen
- [ ] The manager rig — walker, dugout cam, gestures, moods
- [ ] **Rive** for the walker (MCP still to be installed)
- [ ] **Kenney.nl sprites** to replace the pitch circles with animated players
- [ ] `manager_avatar` — the SVG geometry half (~1,100 lines). Moved here from
      M1: it is drawing rather than logic, and the unlock half it needs is
      already done.
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

**Done bar the layout check**, and landed before M3 rather than after it: the
engines already emit translation keys, so the match feed and the trophy room
could not render at all without a lookup layer. See
`docs/superpowers/specs/2026-08-18-i18n-layer-design.md`.

- [x] `i18n/index` (62) — `lib/i18n/i18n.dart`. Three-step fallback (active
      catalogue → English → the raw key), literal `{param}` substitution that
      throws on neither a param with no placeholder nor the reverse, and an
      unknown locale narrowed to English. Synchronous and Flutter-free, because
      it is called from `build` methods and from the engines' formatters alike
- [x] The ten locale files: ar, de, en, es, fr, it, ja, ko, pt, zh — 2,652 keys
      each, generated into `lib/i18n/locales/*.g.dart` by `tool/gen_i18n.mjs`.
      **Not ARB**: 30 keys are not valid Dart identifiers, and the engines look
      keys up at runtime from strings, which `gen_l10n` cannot do at all
- [x] The guard suite, ported from `i18n.test.js` — key parity, no invented
      placeholders, the call-site scan, the id-built keys the scan cannot see,
      and the gendered-pronoun check on English
- [ ] Check the long-language layouts (German is the measured worst case) —
      needs screens, so it stays here rather than moving
- [ ] The Settings language picker, and the JS guard that asserts it lists
      exactly `supportedLocales`. Lands with the Settings screen in M3

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

`tool/gen_i18n.mjs` is the odd one out: it writes `lib/i18n/locales/*.g.dart`
rather than a fixture, and wants re-running whenever a catalogue changes.

```bash
node tool/gen_i18n.mjs                     # → lib/i18n/locales/*.g.dart
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
node tool/dump_scout_voucher_reference.mjs > test/fixtures/scout_voucher_reference.json
node tool/dump_i18n_reference.mjs          > test/fixtures/i18n_reference.json
node tool/dump_kit_theme_reference.mjs     > test/fixtures/kit_theme_reference.json
node tool/dump_boot_room_reference.mjs     > test/fixtures/boot_room_reference.json
node tool/dump_club_asset_tiers_reference.mjs > test/fixtures/club_asset_tiers_reference.json
node tool/dump_small_engines_reference.mjs > test/fixtures/small_engines_reference.json
node tool/dump_manager_mood_reference.mjs  > test/fixtures/manager_mood_reference.json
node tool/dump_utils_reference.mjs         > test/fixtures/utils_reference.json
node tool/dump_game_state_reference.mjs    > test/fixtures/game_state_reference.json
```

The differential harness is separate and is not a fixture: `node tool/difftest/run.mjs`
plays whole seasons through both runtimes and diffs the save. See
`tool/difftest/README.md`.

`match_orchestration_reference.json` is the only one that pins the UNSEEDED
stream as well: it stubs `Date.now` and replaces `Math.random` with a second
mulberry32, and the Dart side drives an identical one through `setEventRandom` /
`setMatchRandom`. Both have to be the SAME instance in a test, because the JS has
only one `Math.random`.

`quest_engine_reference.json` is special: it ships the SAVE it was generated
against, and four other fixtures build on that same save. Regenerating it
invalidates the cup, fixture-preview and season-end fixtures too — regenerate
all four together.
