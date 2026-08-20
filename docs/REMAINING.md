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

**3,571 tests, `flutter analyze` clean.** Everything below that is not ticked
is what remains, and **`docs/PARITY.md` is the queue** — a control-by-control and
layout-by-layout diff of the JS against the port, taken from the source.
**"Open from playtesting" below is the short queue**: what a session of actually
playing the thing turned up, which is a different list from what reading the
source turns up and is worth clearing first.

**Read that before porting another screen.** The port was being built screen by
screen with the gaps surfacing as bug reports from playing, which is the slowest
way to find them and unnecessary when the whole source is here. Every gap a
player reported was already visible in `src/ui/`.

**Three things worth knowing before anything else**, because each was invisible
to the way the port was being checked.

**1. The port had been shipping the game's FALLBACK graphics as if they were the
artwork.** `assets/svgCache.js` was listed here as 54 unported lines and read as
trivial; it is the path resolver, and the real game is PNG-first — every player
card, club facility, trophy and stadium is generated artwork, with the
hand-drawn SVG behind it as the `onerror` case. 11MB of it is bundled now and
`test/data/art_paths_test.dart` walks every path the resolver can produce. Two
things fell out of it: the stadium hero was never blocked on gradients in
`svg_canvas` (that SVG is the fallback; the hero is a photograph), and the
Club tiles and cards had been drawing the wrong thing since they landed.

**2. Three engines had no caller at all.** `recordDiscovery` was never ported,
so `discoveredPlayers` never grew — the Player Index would have read 0 of 66
forever. `maybeGenerateOffer` had no caller, so post-match transfer bids never
fired. And `transfer:offered` was emitted by the tick with NOTHING listening,
which had teeth: an unanswered bid times out after five minutes and the timeout
is scored as a decline, so players were collecting grudges from offers they were
never shown. A reachability audit does not catch these — the control is not
missing, the engine behind it is simply never called. **Grep for who calls an
engine, not just for who reaches a screen.**

**3. Where the shipped copy and the port disagree, the copy is usually right.**
`game.penalty.instructions` has always read "Tap anywhere — aim for corners or
risk hitting the woodwork!" while the screen had four corner buttons, and
`penalty.wide_left`, `penalty.post` and `penalty.crossbar` sat translated in all
ten catalogues with nothing able to reach them — buttons cannot miss. The same
shape of tell found the artwork.

M0 (save bridge), **M1 (the logic core)** and **M2 (the state layer)** are all
finished, and **M5 (i18n)** came forward to join them — the lookup layer, all ten
catalogues and the guard suite landed before the first screen, so nothing has
ever had to hardcode English.

**M3 is well under way.** The theme, the five-tab shell, the HUD, the popup
plumbing, the toast layer and all five tab bodies are in. No tab is a
placeholder. What is left is inside them, and it is listed in one place under
"What is actually left".

The proof M1 is done, rather than merely all ticked: the differential harness
plays six whole seasons through both runtimes, casual and Pro, and every byte of
the save matches at every one of 336 matches a run. A match is PLAYED (ninety
minutes, injuries, tactic changes, settlement), a season plays out, the table
settles, the pyramid shuffles, quests roll and pay, cups run, and the season
boundary hands over to the next campaign — and the JS and the port agree about
all of it.

### The loop closes, and it repeats

A player can now, on a fresh save: sign a player, merge them, sell one, pick a
side and a formation and a tactic, build and upgrade the club's facilities, spend
coins and gems in the shop, train at two mini-games, play a match, watch it out,
be paid for it, claim a quest, finish a season, and be promoted or relegated into
the next one — with artwork, a live HUD, toasts and working settings around it.

They can also open the Trophy Room, the Player Index and the Leaderboard from
the burger, sort and auto-merge the grid, scout in batches, open a player and
sell, recall or bench them, take a rival's bid or turn it down, sign a sponsor,
trade through a Deadline Day window, and watch a chance play out on a 2D pitch
with the manager walking on the home screen behind it.

What is missing is no longer function. It is depth (the cups, the customiser,
four more drills, the per-screen controls in `docs/PARITY.md`), spectacle (the
parallax scene, the scout reveal, the rest of the merge animation) and
everything in M4.

### How far along, honestly

Measured, not estimated: `101,906` lines of non-test JS in
`../merge-empire-fc/src`, of which roughly **74,000 are ported — about 73%.**

| Area | JS lines | State |
|---|---|---|
| `engine/` | 15,331 | done bar `iapClient.js` (195) |
| `data/` | 6,357 | done — `managerAvatar.js`'s SVG half is now `manager_art.g.dart` |
| `utils/` | 3,396 | done bar 1,170 (`sound` 782, `ageVerification` 134, `devTools` 114, `adConsent` 63, `wakeLock` 54, `openUrl` 15, `network` 8) |
| `state/` + `main.js` | 2,333 | done |
| `assets/` | 853 | `playerArt`, `clubArt` and `svgCache`'s path half done; `gemArt` (146) left |
| `i18n/` | 29,163 | done — the lookup layer and all ten catalogues |
| `services/` | 4,144 | none — this is M4 |
| `ui/` | 40,329 | roughly 20,000: the shell, HUD, theme, popups, all five tabs, the events, the cutaway and the sheets behind the burger |

Do not read 65% as "two thirds of the work", in either direction:

- **29,100 of those lines are the ten locale catalogues**, converted by a script
  in an afternoon. They are 29% of the port by line count and nothing like 29%
  of the effort. Discount them and the real figure is nearer 51%.
- **The UI will not be a line-for-line port.** 40,329 lines of hand-rolled DOM
  manipulation becomes materially less Dart, so that denominator is soft — and
  the `ui/` figure above is the one honest estimate in the table rather than a
  measurement, because several JS files are half-ported by design.
- **The port is more verbose than its source, except where it is not.** `lib/`
  is 81,091 lines across 210 files and the tests are 44,081, of which roughly
  27,800 are generated (the catalogues, the club art and now the manager art)
  that nobody reads or maintains. But the shell REPLACED roughly 2,200 lines of
  `App.js`, `HUD.js`, `popupQueue.js` and `SettingsScreen.js` with about 1,900
  lines of Dart, because much of what it did not have to port was workaround:
  `screenFreeze.js` in full, the two-frame `requestAnimationFrame` dance before
  every slide, the swipe-vs-drag exclusion list, and the re-parenting that let
  one wrapper serve tabs, sheets and overlays. `TickerMode`, routes and the
  gesture arena are those four, one line each. Expect the same on every screen
  that follows.

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
flutter test             # 3,473 passing, 2 skipped
TZ=UTC flutter test      # one parity group needs UTC — see below
```

**Do not run `dart format lib/ test/`.** It reformats ~186 files, collapses
multi-line `if` bodies onto one line and trips
`curly_braces_in_flow_control_structures` in about ten pre-existing files —
turning a clean analyze into eleven issues and burying the real change. Format
only the files you touched.

Two things to know before writing any code:

1. **Read `../merge-empire-fc/src/<module>.js` in full before porting it** —
   and its CSS in `src/ui/styles/`. The comments in that repo carry the
   reasoning for nearly every decision, and most of them are worth keeping; the
   port's comments are a rewrite of them, not a copy. The CSS is not decoration
   either: it states column counts, backgrounds and which container wraps what,
   and diffing it caught a case where the port had ADDED the very thing a
   comment says was removed.
2. **Generate a node fixture for anything with non-obvious arithmetic or an RNG
   draw.** Scripts live in `tool/dump_*_reference.mjs`, fixtures in
   `test/fixtures/`. Every one of them has caught something.
3. **Sweep for engines nothing calls, and check the JS before building one.**
   The highest-yield thing done in a whole session was a script that listed every
   public function in `lib/engine/` referenced nowhere else in `lib/`. It found
   the action funnel, the auto-sell rules, the whole domestic cup, both quest
   rolls and the trait roll — five features that were ported, tested and
   unreachable. Two cautions, both learned the same afternoon: most names on such
   a list are internal helpers or belong to a screen not yet ported, so read
   before believing; and grep the JS for a caller too, because `listPlayer` and
   `unlistPlayer` turn out to be a dead end THERE — building a UI for them would
   be adding a feature to the game rather than porting it.

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

### Reachability — check it, do not assume it

An audit prompted by a player opening the app found three things BUILT, TESTED
and unreachable: the popup queue that nothing queued into, the quick-nav menu
nothing showed, and a HUD cog wired to a stub `Scaffold`. Every one had passing
tests, which is exactly why none of them were noticed.

Widget tests construct the state they need. They prove a part works; they say
nothing about whether a new player can get to it. **Before calling a module
done, grep for who CALLS it** — and where the answer is "only its own test",
that is the module's real status.

**That rule catches engines, not just screens, and the worst case so far was an
engine.** `trackEvent` — the funnel both the season quest track and the event
reward track sit behind — had no caller anywhere in `lib/`. Every quest looked
finished: definitions, track, sweep, payout, all ported and tested. Three of
them could not advance, because nothing ever counted a scout or a merge. The
auto-sell rules were in the same position. Neither shows up in a control audit:
the control is there, and nothing behind it is wired. See the method note in
`docs/PARITY.md`.

Nothing built is currently unreachable. Every screen in `lib/ui/screens/` is
reached from a tab, the burger, a dock orb, the end of a match or the strip in
the home screen's footer, and each has a test that starts at the shell rather
than constructing the sheet.

Two are reachable but INCOMPLETE, and say so on screen rather than pretending:

- The **Leaderboard** shows its signed-out and offline states — both of which the
  JS really has — because the ranked list needs `leaderboardService` (M4). The
  tile is there so the Shop is not selling a rank with no door to look at it
  through.
- The event **cup bracket** is built and nothing reaches it: `wc2026`'s window
  closed in July so it permanently reports `ended`. It exists because that
  engine and its tests are the specification for whatever reuses the slot.

### Reach for the widget before porting the CSS

The JS builds what the DOM does not give it, and a straight port of that build is
usually worse than the Flutter widget it was standing in for. Three that were
found the hard way, all in one pass:

- The trait roulette's two reels are repeated DOM strips with a hand-driven
  scroll; `ListWheelScrollView` with a looping delegate and `animateToItem` is
  the same thing in a dozen lines, and it spins properly.
- The keeper's dive is four CSS transitions about four `transform-origin`s;
  `AnimatedRotation` takes an `Alignment`, which is any point you like, so the
  pose is four widgets and no clock at all.
- The stadium hero's gradients and the manager's cubic paths were being DROPPED
  by `svg_canvas.dart` rather than approximated — see the note under M3's art
  item. Check what a piece of art uses before assuming it draws.

The exceptions are the things a widget cannot express: a rig whose limbs turn
about their own joints inside one figure still wants a painter, and a looping
sway still wants a controller.

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

### The screen-by-screen pass, and what it turned up

A play-through of every tab against `../merge-empire-fc/src` — the whole source is
here, so nothing below needed finding by accident. Two shapes recur, and both are
worth reading before touching another screen.

**A Flutter default that is not the CSS default.** Most of the visual gaps were
one of these, and each looked like art that had never been ported:

- **`stroke` on the `<svg>` ROOT was never inherited.** `icons.js` puts
  `fill="none" stroke="currentColor" stroke-width="1.8"` on the root element and
  lets its paths inherit; the painter read attributes per node, so a path with no
  paint of its own is SKIPPED. All fifty-nine glyphs drew nothing, everywhere. The
  parser folds root and `<g>` attributes into each child now, and
  `test/ui/widgets/game_icon_test.dart` asserts every node in every glyph carries a
  paint it can draw with.
- **`-?[\d.]+` is not an SVG number.** Path data packs numbers without
  separators, so `1.5.35` is `1.5` then `.35` — the greedy form swallowed both and
  threw. Every compact path in the artwork hit it.
- **A centred `Row` gives its children LOOSE cross-axis constraints**, so a
  segment that does not name its own height collapses to ZERO. The diorama's mown
  lanes and grass tufts are a width and a fill, so they came out 84×0 and the
  pitch was simply absent — while the stand, which happens to carry an explicit
  height, rendered fine and made it look like a paint problem rather than a layout
  one. `CrossAxisAlignment.stretch`, and a test that measures a SEGMENT rather
  than the band it sits in. (Measuring the band is the trap: it is positioned, so
  it reports the right height whether or not anything inside it drew.)
- **`Stack(alignment: center)` sizes to its largest NON-POSITIONED child.** On the
  next-match card that is the stat rows, barely half the card wide — so `left: 0`
  on a rating meant the left edge of that narrow box and both big figures printed
  through the middle of the comparison they annotate.
- **An `OverlayEntry` has no `Material` ancestor**, so every `Text` in the scout
  reveal drew Flutter's missing-Material double yellow underline over the caption.
- **A card layer over a slot layer occludes the slot's `DragTarget`.** Moving the
  grid to positioned cards (so a sort could animate) put the cards above the drop
  targets, and merging stopped working outright: a drop onto an occupied cell hit
  the card and never reached a target. The target belongs ON the card, and a test
  asserts it is inside the card's own subtree.

**A value read under the wrong key, or a draw taken on a display path.**

- **`tutorial.done` was read as `== true` where the JS reads `!== false`.** Every
  save without the flag — which is most of them — read as mid-tutorial, hiding the
  ×N scout control and the auto-sell pill from players who finished the tutorial
  long ago.
- **`squad.strategy` for `squad.strategyId`**, so Colin suggested a tactic even
  when it was the one already set.
- **`getSeasonOpponents` called `generateTeamName` from the league table.** That
  draws from the shared seeded stream AND ADVANCES it, and the table is rebuilt on
  every save revision — so the division reshuffled its clubs on every rebuild and
  pulled the sequence out from under the save's determinism. Deterministic and
  RNG-free now, with a test that pins both.
- **`initSeasonOpponents` ran only at a season boundary**, so a save that had not
  finished one had no `seasonFixtures` at all and the Fixtures sheet sat on its
  loading line for good.
- **`defaultManagerLook` was a getter over `normalizeAvatar(null)`**, which is
  random — so a walker with no stored look changed hair, beard and outfit on every
  rebuild, and anything comparing two reads compared two different men.

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

## Open from playtesting — 19 Aug

Found by playing, not by reading the source, and all of it is in `src/ui/` where
it can be checked. Ordered roughly by how much of the screen it costs.

Two are not code decisions and are marked so.

### Cards and the grid

- [x] **A revealed player FLIES into his cell.** The grid lends the reveal a
      `ScoutLanding` — the screen rect of every cell in the batch, with the grid
      already scrolled so they are on it — and the reveal flies each keeper from
      where it was turned over to the square the engine put it in. The scroll
      happens DURING the hold, behind a backdrop that is already opaque, so it
      costs the reveal nothing and the square has stopped moving by the time the
      card leaves. The old note here said the rects could not be had; that was
      true of a `GridView` and has not been true since the cards became a
      positioned layer inside a `SingleChildScrollView`.
- [x] **The merge reads as a set-piece.** All four of the JS's layers, where the
      port had one and a half: the GSAP squash → stretch → elastic settle
      pivoted on the card's bottom edge, the `brightness(3) saturate(2)`
      blow-out on the cell, one to three staggered shockwaves, and the tier's
      own particle palette at the JS's counts (18 / 26 / 38, against a formula
      that spent 24 on a Legend). Every piece comes off a stable per-burst hash
      — a painter that rolls dice inside `paint` re-rolls them every frame.
- [x] **A drag-drop does not replay it.** `_drop` still returns before anything
      celebrates unless the action was a merge, and there is a test that says so
      for both a move and a swap.

### Shop

- [x] **The coin packs have their own sheet.** The HUD's coin chip and the gem
      chip open `currency_sheet.dart` over whatever screen asked, rather than
      switching tabs and scrolling — which landed the heading at the top of the
      viewport, which is where the floating HUD is. Both were done: the tab's
      deep link (still live, for the `nav:shop-coins` bus events) now backs off
      by `hudClearanceOf` plus the JS's own 8px, and there is a test that says
      the heading ends up under the glass rather than behind it.
- [x] **The coin tiles have their own artwork, and it is DRAWN.** Nothing needed
      bundling: `coinCluster` in `ui/icons.js` draws one, two, three and five
      filled coins, which is how the JS tells a bag from a mountain when all four
      bundles share the same 💰. Ported as a painter, along with the rest of the
      tile the port had flattened into a generic one — the bronze-to-diamond
      wash, the crown, and a badge that is either the COMPUTED coins-per-pound
      improvement or the popular tag.
      **Two real bugs fell out of it.** The shop was rendering
      `IapProduct.name`/`.desc`, which are the English literals on the record —
      so every product had the wrong name even in English (`coins_small` is
      "Pocket Change" in the catalogue, "Bag of Coins" on the record) and the
      whole shelf was untranslatable. And `desc` for every coin and gem bundle is
      literally `'{coins} coins'` / `'{gems} gems'`, so the tiles were printing
      the braces. `shop_copy.dart` is the JS's own `pName`/`pDesc`/`pBonus`, and
      `{coins}` resolves through `getProductGrantCoins` — what THIS division
      would pay, not the base on the product.
- [x] **The Style Vault and the packs are one case with a lid.** The tiles sit
      inside the Vault's border under a label that counts them
      (`shop.looks.case_label`), each in its own pack tint, each carrying its own
      five-gem price — the JS's shape, and its own note says why: a caption
      floating between two unrelated-looking blocks is a claim, and the tiles
      having separate prices made the shelf read as seven things for sale.
      What spends those gems is the offer sheet the manager customiser opens,
      which is a screen the port still does not have.

### Screens

- [x] **The idle-earnings card is the JS's** — `welcome_back_card.dart`. It had
      been a generic coach card with `welcome.earned_label` as BOTH its title and
      its body, so the one popup seen on every launch said "Banked while you were
      away" twice and never said the NUMBER. Two thirds of the copy written for it
      was unreachable: `welcome.line`, Colin's own five-line pool and the only
      place the duration is mentioned, and `welcome.note_capped` — which matters,
      because `processOfflineEarnings` clamps the window, so three days away
      arrived as eight hours with nothing saying the books had stopped counting.
      All of it is the catalogue's; none of it was rewritten.
- [x] **An achievement leads with its art, at the top of the screen** —
      `achievement_unlock.dart`, ported from `AchievementUnlock.js`. It had been
      a toast saying "Achievement Unlocked!" and nothing else: no name, no art,
      no coins, at the bottom of the screen in the slot a refused merge uses.
      Its own host rather than a fourth popup shape — it answers nothing, like a
      toast, but it is a celebration and they QUEUE, because one match can unlock
      several.
- [x] **The squad pitch has room for eleven.** The band positions were NOT
      changed: `x`/`y` are `formations.js`'s own data with a parity fixture
      behind them, and all four lines are already an even 24% of the pitch apart.
      What was eating the room is that the tokens never shrank — a fixed 74×97
      whatever the pitch, so on a 360-wide phone the lines had twenty pixels
      between them and the keeper stood ON the goal line. The token is now
      measured against the pitch and never scaled UP, so a tall phone draws it at
      exactly the size it was drawn for. Insetting the field instead was tried
      and is wrong: it buys the outer lines a margin by taking it from between
      the midfield and the attack, which is where it was missing.
      Found while measuring: the formation chip's label had no flex at all, so it
      could only overflow the chip. It yields before the value does now.
- [x] **The Club screen's Build column says what a facility GIVES.**
      `club_asset_tiers.dart` was a fourth engine with no caller — fully ported,
      fully tested, computing what every tier gives and what one step up actually
      changes, and none of it reached the screen. A card was a name, a hint and a
      price, so a player investing could not know what they were buying.
      Now the JS's own tile: full-width artwork in a `minmax(165px, 1fr)` grid,
      the tier badge on it (or a lock), the live perk, the bar, and only what the
      next tier changes. The eight-tier ladder is one tap away on the art —
      `asset_ladder_sheet.dart`, opening on the tier the club is on — which is
      what lets the card stay one height in all ten languages. A dead button now
      names the shortfall rather than only going grey.

### Not code decisions

- [ ] **The IAP tiles are `onPressed: null` with "coming soon"** because there
      is no billing plugin in the project — `starter_pack`, `vip_pass`, the gem
      packs and the coin packs all sit behind `paidDisabledReason()`. They can
      be wired to grant their contents for testing, but that is giving away paid
      content and is a product call, not a porting one.
- [ ] **The rewarded-video buttons are the same.** `ad_gate_engine` is live and
      the gate, the cap and the countdown are all correct — there is no AdMob
      behind the button. Same two options, same call to make.

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

### Found and fixed while building the Shop

- [x] **The Shop's three coin consumables had no engine.** `magic_sponge`,
      `kit_sponsor` and `match_rev` are bought with coins, and their pricing and
      effects lived inside `ui/screens/ShopScreen.js` rather than in an engine —
      so unlike every other purchase on that screen there was nothing ported to
      call. Now `engine/shop_consumables_engine.dart`, lifted OUT of a view
      rather than translated across, and pinned by
      `tool/dump_shop_consumables_reference.mjs` over every division and the
      whole sponge ramp. Not to be confused with `engine/coinSinkEngine.js`,
      which was already ported and belongs to the Club screen, not the Shop.

### What is actually left

One place, so nobody has to reconstruct it from seven milestone headings.

**Reported and still open**, from the screen-by-screen pass. Each is a real gap
against the source, not a polish wish:

- **The match page's live controls.** The JS band order is competition + clock,
  scorecard, pitch stage, TACTICS, tabs, footer — and the port has no tactic strip,
  no subs button, no speed control and no commentary/quests tabs. The reason it is
  not a straight port: the Flutter match REPLAYS a result the sim has already
  produced, so a live tactic change or a sub has nothing to change. Either the sim
  becomes interactive (`resumeMatchFrom` exists in `match_orchestration`) or the
  strip is honest about being a readout. Decide before building it.
- **The event strip's clock and news ticker.** `deadlineHeadlines` in
  `deadline_news_engine.dart` is ported, tested and has NO CALLER — the strip
  should carry a ticking countdown and a right-to-left marquee of the rumour mill,
  and currently shows a dot and a name. This is most of why Deadline Day "looks
  nothing like it should".
- **The rewarded-ad buttons.** Every `watch an ad for X` control, with its own
  colour and its AD chip. M4 work, but the buttons and their dead states are UI.
- **The manager's rig reads stiff.** Six tracks are ported and correct, but the
  JS's arms pivot at the shoulder AND elbow inside their `<g>` groups
  (`k-arm-l` / `k-arm-r`) and the port turns the whole arm as one piece.
- **The keeper's illustration.** Anchored correctly now, but the figure itself is
  still the port's own and not `buildKeeperSvg`'s eight-pose sprite sheet.
- **The crowd.** Seeded speckle standing in for the JS's sprites — it reads as
  texture rather than as people.
- **The Club screen's layout.** The kit picker and the unlock splash are in; the
  panel stack itself has not been diffed against `ClubScreen.js` band for band.

**`docs/PARITY.md` is the working queue.** It is a control-by-control and
layout-by-layout diff of `../merge-empire-fc/src/ui/` against `lib/ui/`, taken
from the source rather than from playing. Read it first; this section is the
shape of the remaining work, that one is the list.

**Screens that do not exist at all.** The engines behind both are ported and
tested.

| Screen | JS lines | Engine | Note |
|---|---|---|---|
| Cups | — | `cup_engine`, `event_cup_engine` | they DO run, at the season boundary; only the toast ever mentions one |
| Manager customiser | 571 | `manager_looks`, `manager_mood`, `manager_art.g.dart` | the Shop sells the Vault that unlocks these, and the parts are now generated |

Built since this table was first written: **Deadline Day** and the **Event**
screen that hosts it, **Transfers** (the bid and sponsor cards, plus the two
triggers that had no caller), the **Trophy Room**, the **Player Index**, the
**2D cutaway**, the **player detail sheet**, the **next-match card**, the
**walker**, and the **Leaderboard**'s signed-out and offline states. The event
CUP branch is built and nothing reaches it — `wc2026`'s window closed in July,
so it permanently reports `ended`; it is there because that engine and its tests
are the spec for whatever reuses the slot.

**Mini-games still to build**: Training Drills, Keepy Uppys, Through Ball, Whack,
Teamwork. Penalty Training and the Boot Room are playable; the pattern for a new
one is `lib/ui/screens/minigames/` plus a row in `playableMiniGames`.

**Spectacle.**

- **The diorama's parallax scene** — the world that scrolls behind the walker,
  evolving with the division. The walker himself is in; this is the backdrop.
  Still the piece the port design gates on profile-mode timings from a physical
  device, which have not been taken.
- The rest of the live match: in-match subs, tactic changes, the stats and
  tactics tabs, and the doubling offer on the closing screen.
- **The scout REVEAL** — a signing still drops into the grid with no reveal, no
  new-discovery badge and no auto-sell marker. The batch sizes it used to be
  listed with are done.
- **The rest of `MergeAnimation.js`** (928): the centre-screen reveal, floating
  income labels, the promotion celebration. The merge burst is done.
- The dugout cam, gestures and moods — the rest of the manager rig.
- The remaining art: `gemArt` (146) and `svgCache`'s SVG half (54).

**Depth inside screens that DO exist.**

- Club: kit redesign, the upgrade-path ladder, the club stats block,
  hold-to-invest.
- Squad: rename, the trait wheel, the market-value gauge.
- Shop: the Lucky Boot and match-cooldown ad buttons.
- Settings: 52 interactive elements in the JS, not yet diffed at all.
- Grid: lazy card mounting, if a profile run asks for it.
- Season end: the season table, the quest auto-payout lines, cup results.
- Match: the tutorial's forced first win, transfer-offer expiry on kickoff.

**Layout still to diff** against `src/ui/styles/` the way the Shop was: Club,
the Players grid, the match page, the home scene, the HUD, and `glass.css`,
which is app-wide.

**Then M4 in full** — see its own section. The Shop's IAP surface is finished and
waiting on the billing bridge; nothing else in M4 has been started.

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
- [ ] **The transfer LIST is a dead end in the JS too.** `listPlayer`,
      `unlistPlayer`, `isListed` and `listedCards` are a complete feature —
      advertise a player, lose them from the XI, draw better bids
      (`listedPremium`) — and nothing in `src/` calls the first two: only their
      own tests do. The card art even has a `card.listed_ribbon` for it. So a
      player can never list anybody, and `listedPremium` and Deadline Day's
      `listedTarget` chip can only ever read a save that was hand-edited.
      **Ported deliberately and NOT given a UI**, because giving it one would be
      adding a feature to the game rather than porting it. If it is ever wanted,
      the detail sheet's Sell row is where it goes.

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
      `docs/superpowers/specs/2026-08-18-shell-design.md`. The home tab has no
      sub-tabs to reset to any more, so "tapping Play takes you home" holds by
      construction — the table and the fixtures close OVER the screen rather
      than replacing it.
- [x] **The player card** — `lib/ui/widgets/player_card.dart`, with its tier
      palette in `lib/data/card_theme.dart` pinned against `Card.js`. The most
      repeated widget in the game, so a `RepaintBoundary` each, and the M0 probe
      is retired: `integration_test/card_perf_test.dart` profiles the real card
      now. It takes a `CardView` record rather than a save map, so a screen
      resolves the values with the engines it already has.
      **Portraits are on it** — `ui/widgets/player_portrait.dart`, a
      `CustomPainter` off the variant table M1 already carried, whose header
      called the JS's inline SVG portraits "UI work for a later milestone".
      Still to add when a screen needs them: the income bar, the trait chip and
      the sponsor drawback marker
- [x] Merge grid — `lib/ui/screens/grid/`. Drag to merge, drag to move, three
      columns by thirteen, slots past the roster shown locked rather than
      hidden. `attemptMerge` owns every rule; the widget reports two indices.
      **Not ported, and deliberately**: the `pan-y` touch-action workaround, the
      `card-dragging` body class and the hand-rolled 200ms hold, all of which
      exist in the JS to stop a card drag and the tab swipe fighting.
      `LongPressDraggable` plus the gesture arena is what the three were
      approximating, and a test asserts a quick flick does not pick a card up.
      **Add Player** is on it — `engine/scout_signing_engine.dart`, another flow
      that only ever lived in the JS screen. It is the action the game OPENS on:
      a fresh save has an empty grid, so without it there is nothing to merge,
      nobody to field and no way to start. Found by PLAYING the thing rather
      than by reading the source, which is worth remembering.
      **Selling** is on it too — tap a card for the sell sheet, drag to merge.
      The market roll happens ONCE, when the sheet opens, so the sale pays the
      figure the player agreed to. `engine/sell_card_engine.dart` is the act of
      selling, which the JS kept in its screen; the pricing was already ported.
      **A merge now lands with a burst** — `merge_burst.dart`. The JS's
      ghost-fly is deliberately not ported: the drag already carried the card
      there under the player's own finger.
      **The reveal is in** — `scout_reveal.dart`. A batch is held back and
      turned over together, each card wearing what is true of it (a voucher
      pill, an auto-sold verdict, a gold halo for a first-ever sighting), and
      the cards the tier rules marked are cashed in only once they have been
      SEEN. Not a fourth popup shape: a reveal asks nothing and holds nothing,
      so it is an animation layer like the burst and the toast host. A merge
      that produces a player nobody has ever seen reuses it.
      **The grid's bookkeeping is in with it**, which was the bigger find —
      `merge_flow_engine.dart`. See the parity file's method note: the action
      funnel had no caller at all, so three season quests could never advance;
      the auto-sell rules had no caller either — nothing could switch them ON,
      so `auto_tier_sheet.dart` is the half that was missing; and a merge never
      told the transfer market that both parents had gone.
      Still to add: the merged-into float (`grid.merged_into`, which names the
      tier a merge produced), and lazy mounting if a profile run asks for it.
      **Worth knowing before writing a grid test:** a card loaded WITHOUT a
      `variant` is backfilled with a random one, and the engine refuses to merge
      two players of different genders — so a fixture that omits `variant` makes
      a merge test pass about one run in three. Set it explicitly and match it
      across a pair
- [x] Shop screen (1,387) — `lib/ui/screens/shop/`. All seven shelves, in the
      JS's own order. See
      `docs/superpowers/specs/2026-08-18-shop-screen-design.md`.
      **What is deliberately inert in it, and why**, so M4 knows what it is
      plugging into:
      - Offers, Gems packs, Coin packs and the Style Vault render real prices
        with dead buttons — they need `iapClient`. Nothing calls
        `purchaseProduct`, which is the post-payment GRANT step, and a test
        reads the source to keep it that way
      - the free shelf's ad GATE is live (`ad_gate_engine` decides ready,
        waiting or capped) but the watch button needs AdMob
      - Restore Purchases is present and disabled
      - Manager Looks buys nothing at all: the pack tiles are progress, and an
        individual pack unlocks by rewarded video in the customiser
- [x] Squad screen (2,264) — `lib/ui/screens/squad/`. The eleven on the pitch by
      formation, the bench under it, drag to pick or swap, and a header whose
      rating, ATK and DEF all come from `computeSquadRatings`. A slot emptied by
      hand is REFILLED from the bench, because `cleanAndFillLineup` is what stops
      an empty slot surviving a sale.
      The formation and tactic pickers are live — both bottom sheets, and a
      shape change goes through `migrateLineup` so the eleven carries across.
      Per-player fitness is on the card, PRO MODE ONLY — casual play has team
      energy pips instead, so `CardView.fitness` is null there rather than a bar
      pinned at full.
      Still to add: the sell and transfer flows, and career stats.
      **Note on copy:** tactic and formation NAMES come from the data
      (`Strategy.name`, `Formation.label`), not the catalogue — there are no
      `tactic.*` or `formation.*` keys in any of the ten, so they read English
      in the JS too. Translating them is a catalogue change, not a port gap
- [x] Club screen (838) — `lib/ui/screens/club/`. All seven facilities, build
      and invest, the tier bar and every refusal explained.
      Build and invest were ANOTHER flow living in the JS screen rather than an
      engine, so `engine/club_asset_engine.dart` lifts them out; the arithmetic
      they use (`buildCost`, `tapCost`, `tierThreshold`) was already ported.
      **The artwork is on it** — `data/club_art.g.dart` carries the JS's own SVG
      strings, generated by `tool/gen_club_art.mjs`, and
      `ui/widgets/svg_canvas.dart` draws them from primitives with no
      dependency. An unbuilt facility shows its tier-one art dimmed, because a
      preview is a better prompt than an empty square.
      Still to add: the stadium hero (gradients, above), the upgrade-path sheet,
      the stadium colour picker, and hold-to-invest
- [x] Home screen (6,777) — `lib/ui/screens/home/`, PARTIAL and deliberately so.
      **It had SUB-TABS across the top and should never have had them.** That is
      the arrangement the JS moved away from: ten orbs used to run up both sides
      of the diorama and the scene was carrying more furniture than scene, so
      nine of them went behind one burger and the Overview/Table/Fixtures/
      Training strip went with them. The layout is Coach Colin bottom left, the
      burger bottom right, and the Play button in the sticky footer — where it
      belongs, rather than two taps deep under a fixture list. The table, the
      fixtures and the training ground are quick-nav sheets.
      The quick-nav MENU changed shape with it: it was a bottom sheet and the JS
      says in as many words that it must not be — "a 3×3 grid wants the middle
      of the screen, and the sheet's chrome promises scrollable content about
      something that has none". As a sheet its last group sat below the fold.
      **Overview is the DIORAMA and stays named rather than half-built**: a
      parallax scene and a ball simulation, and the port design gates its
      technique on profile-mode timings from a physical device, which is still
      open below. It is the natural home for the Rive walker.
- [x] The live match page — `lib/ui/screens/match/`, a takeover screen as the
      note said. It PLAYS OUT a match `simulateMatch` has already decided:
      `match_clock.dart` is pure logic that only chooses when an already-decided
      event appears, which keeps the engine exactly what the differential
      harness proves. The score counts the goals SHOWN rather than reading the
      result, so the number can never run ahead of the commentary explaining it.
      Claims `tickGatesProvider.matchOpen` while up.
      Started from the Fixtures tab: `match_launcher.dart` spends the pip and
      simulates, `finalizeMatchOutcome` runs at full time with the screen still
      up, and `applyMatchRewards` only once the player DISMISSES it — deferred
      because the doubling offer lives on the closing screen, and paying before
      it is answered would make the offer meaningless.
      **The 2D cutaway is in** — `lib/ui/screens/match/cutaway/`, and the port's
      first and so far only use of Flame. A persistent top-down pitch sits above
      the feed and a chance cuts in over it, with Kenney's CC0 sports sprites
      (green us, red them, white keepers). The 29 scripted passages came across
      as DATA in attack space — `p` toward the goal being attacked, `q` across
      it — so one table serves both teams shooting both ways instead of four
      mirrored copies that would drift. A test walks every sequence to its end,
      which is how the four free kicks were caught hanging: their scripts end on
      the foul, so the runner ran out of instructions.
      Still to add: in-match subs and tactic changes,
      the stats and tactics tabs, the transfer-offer expiry on kickoff, and the
      tutorial's forced first win
- [x] **The domestic cup is playable** — `lib/ui/screens/match/cup_launcher.dart`.
      `cup_engine` was ported, tested and reachable by nothing: `endSeason`
      auto-enters the club into its division's cup and nothing could play a round
      of it. The Play button offers the round by name when one is due; the tie
      goes through the same match screen, and the prize, the bracket and the
      sponsor drop settle at full time.
      Still to add: the shootout reveal, the three celebration cards, and the tie
      in the fixture list.
- [x] Season-end takeover — `lib/ui/screens/season/`. Not polish: without it
      the game STOPPED at the fourteenth match, because `simulateMatch` sets
      `progression.seasonComplete`, every gate then refuses, and nothing offered
      a route on. The Play button becomes an End Season button, `endSeason`
      settles the whole thing in one call, and the takeover reports it.
      The season number is captured BEFORE that call — `endSeason` rolls
      `seasonCount` on as part of its work, and the summary is about the season
      that finished.
      Still to add: the season table on the card, the quest auto-payout lines,
      and the cup results the copy already has keys for
- [x] The three popup shapes — bottom sheet, Coach Colin card, quick-nav menu.
      Do not invent a fourth. The queue behind them is `util/popup_queue.dart`,
      and it holds a no-host blocker from boot so a card queued before any widget
      existed waits rather than being dropped
- [~] Mini-games — `lib/ui/screens/minigames/`. The Training tab lists all
      seven, unlocked a tier at a time by the Club's Training Ground, and
      **Penalty Training is playable**. Its shot resolution came out of the JS
      component into `engine/penalty_game_engine.dart`; the keeper's smart-dive
      ramp was already ported with the data.
      **The GOAL is the target**, not four corner buttons. Buttons cannot miss,
      so the woodwork and wayward outcomes were shipped copy in ten catalogues
      that nothing could reach — and the instruction line already told the
      player to tap anywhere. The quadrant they hit picks the corner the engine
      is asked about; off target never reaches it, because the keeper had
      nothing to do with it.
      The cooldown starts on ENTRY rather than on finishing, so walking away
      mid-round cannot farm the reward timer.
      A game with no screen yet is LISTED and says so rather than being offered
      — the menu-row-to-nowhere bug, avoided deliberately.
      **The Boot Room is playable too** — a match-three whose every rule is
      `boot_room_engine`'s, laid out in full rather than in a lazy grid because
      a board the player cannot see all of is not a board.
      Still to build: Training Drills, Keepy Uppys, Through Ball, Whack and
      Teamwork.
- [x] Trophy room — `lib/ui/screens/trophies/`, off the burger and a HUD badge.
      That badge is the only place the game SHOWS the badge you set, so without
      it "Set as Badge" was a button with no visible effect.
- [x] Deadline Day — `lib/ui/screens/events/`, inside the Event screen that
      hosts it.
- [x] **Kenney.nl sprites** — the 2D cutaway draws its two sides from the CC0
      sports pack (green us, red them, white keepers). They are top-down and
      there is no run cycle in the pack: heading is rotation, which is how
      Kenney's own sample works.
- [x] `manager_avatar`'s SVG half — generated into `lib/data/manager_art.g.dart`
      by `tool/gen_manager_art.mjs`, the same way the club art was. Hair keeps
      its back/front split because the head is drawn between the two.
- [x] The walker — `lib/ui/screens/home/manager_walker.dart`.
      **Rive was considered and dropped: it is paid.** The rig is drawn from the
      generated parts instead.
- [x] **The look and the mood are on him** — `data/manager_art.dart` recolours
      the generated parts per look, and the five mood mouths come out of the
      JS's own `mouthPath`. Both were ported data with no reader.
- [ ] The rest of the manager rig — dugout cam, gestures (the walker shows the
      MOOD; `gestures` and `ballPlays` in `data/manager_mood.dart` still have no
      caller)
- [ ] The manager CUSTOMISER, which is what the generated parts are for
- [ ] **The SVG art that is not player art**: `assets/gemArt` (146), which the
      gem icons read from. `playerArt`, `clubArt` and `svgCache`'s path half are
      done.
      **Worth knowing:** `svg_canvas.dart` could not draw cubics, arcs or
      gradients until this was looked at, and it failed SILENTLY — a `C` command
      had its numbers eaten by the command before it, and a `url(#id)` fill left
      the shape with no paint, so it was skipped. That was every manager part
      (66 cubic paths), every crowd seat in the club art (arcs) and twenty
      gradient fills. Check what a new piece of art actually uses before assuming
      the painter covers it.

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
- [x] The Shop screen (`ShopScreen`, 1,387 — counted in M3). **The UI is
      finished and waiting on the bridge**: every real-money tile renders its
      real price with a dead button, and nothing calls `purchaseProduct`. Wiring
      `iapClient` to those buttons is the whole of what is left on this line
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
node tool/dump_shop_consumables_reference.mjs > test/fixtures/shop_consumables_reference.json
node tool/dump_card_theme_reference.mjs    > test/fixtures/card_theme_reference.json
node tool/gen_club_art.mjs                 # → lib/data/club_art.g.dart
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
