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

**3,991 tests, `flutter analyze` clean.**

**84 items are open**, down from 108. What went in the last pass, and every one
of them turned out to be the same shape — a thing that was fully ported, fully
tested and never called, or a piece of shipped copy nothing could reach:

- **The football is on the diorama.** `PitchBallSim.js`, pinned frame by frame
  against the JS with the random draws in the fixture. `windAccelFor` has a
  reader at last.
- **The gesture halt EASES, and it ends.** It never ended: the world stopped for
  a bow and stayed stopped until the next gesture, up to sixteen seconds later.
  And there is one clock now for his legs and the ground.
- **`CoachTips.js`.** `seenTips` was a ledger with no ledger in it — sixteen
  tips and forty-four strings unreachable.
- **The income breakdown.** Eighteen more unreachable strings, behind a chip
  that already carried its accessibility label.
- **Every trait was untranslatable.** Forty-two more.
- **Six builds instead of one**, and an outfit palette, without which a
  tracksuit was a collar line and nothing else.
- **Every decision goes through Colin now, actually** — four still arrived as
  `AlertDialog`s.

What is biggest now is the match cutaway and the mini-games with no screen. Each
section carries its own status block: the count, the clusters, what is blocked on
a decision and what is blocked on artwork.

`docs/PARITY.md` is the OTHER queue — a control-by-control and layout-by-layout
diff of the JS against the port, taken from the source. It is the longer list and
the less urgent one: nothing on it is a thing a player has complained about.

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

**2. FOUR engines had no caller at all.** `recordDiscovery` was never ported,
so `discoveredPlayers` never grew — the Player Index would have read 0 of 66
forever. `maybeGenerateOffer` had no caller, so post-match transfer bids never
fired. And `transfer:offered` was emitted by the tick with NOTHING listening,
which had teeth: an unanswered bid times out after five minutes and the timeout
is scored as a decline, so players were collecting grudges from offers they were
never shown. A reachability audit does not catch these — the control is not
missing, the engine behind it is simply never called. **Grep for who calls an
engine, not just for who reaches a screen.**

The fourth turned up in the playtest queue below: `club_asset_tiers.dart`, which
computes what every club facility gives at every tier and what one step up the
ladder changes. It exists to fix two things a player could SEE — a "next tier"
line that repeated the current one, and unlocks nothing advertised — and it had
been ported, tested against a fixture, and never once asked. The Club screen's
cards showed a name, a hint and a price. **A green fixture test is not a caller.**

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

## From playtesting — 19 Aug

Found by playing, not by reading the source, and all of it was in `src/ui/` where
it could be checked. Ordered roughly by how much of the screen it cost.

**Every code item here is done.** The two left open are not code decisions and
are marked so: both are product calls about giving away paid content, and neither
is blocked on anything but a decision.

Three things the queue turned up that reading the source had not, all of them
things a player could see:

- **`club_asset_tiers.dart` had no caller** — the fourth such engine. See point
  two at the top of this file.
- **The Shop was showing the wrong product names**, in every language including
  English, and printing `{coins}` verbatim on the coin and gem tiles. It had been
  rendering `IapProduct.name`/`.desc`, which are the English literals on the
  record rather than the catalogue's copy.
- **The welcome-back card said one line twice** and never said the number, with
  two thirds of the copy written for it unreachable.

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

## From playtesting — 20 Aug

A second session, all of it visual and all of it checkable against
`../merge-empire-fc`. Grouped by where the work is rather than by severity,
because most of these are two or three to a file.

### Where this queue stands

**50 done, 30 open** across both playtest sessions — counted off the boxes in
both sections rather than kept as a running total, because the two had drifted
apart.

| Cluster | Open | What it is |
|---|---|---|
| Manager and customiser | 5 | the rig's shadow, body shape, the tracksuit, a walking backdrop, style previews, and the wrong navigation for it |
| Squad and the player sheet | 5 | portrait over the buttons, a release button, the traits, the tier-maxed highlight, the card's portrait |
| Home, odds and ends | 5 | the position badge, the `+1` tooltip, Colin's third person, income per second, the safe area's depth |
| The Play page | 3 | the 2D cutaway, the commentary, the styling |
| Sound, and the buttons | 3 | **sound is blocked on an audio-dependency call**; the emoji sweep; the JS's action colours |
| Fixtures, daily reward, vouchers | 3 | three screens wanting a pass |
| Deadline Day and names | 2 | renaming a player, and buying the player you actually bought |
| Not code decisions | 2 | the IAP tiles and the rewarded-video buttons |
| Artwork packs | 2 | the backdrop pack and going back to the sports pack |

**One of those thirty is BLOCKED and the rest are not.** Music and sound need a
new dependency — Flame ships no audio, so `flame_audio`/`audioplayers` is a call
nobody has taken. See the Settings cluster below.

**The two things that were worth reading before picking one up are both settled
now.**

**1. The sky follows the THEME, and it does.** Light mode is daylight, dark mode
a floodlit night, with the stadium tier running the grandeur inside whichever of
the two you are in — `lib/ui/theme/sky.dart`. Every compromise that had been
struck against the old fixed dusk-blue sky came off with it: the next-match card,
the HUD's glass, the diorama's turf, the crowd's haze, and
`glassThemeProvider`, which is deleted. See "The sky, and why it follows the
theme" below.

**2. The artwork question is answered.** `kenneynl/` holds six CC0 packs and the
useful one is now bundled — see "Artwork, and which packs" at the end of this
section. Nothing on the list below is blocked for want of art any more.

### The grid

- [x] **The merge-ready pulse is ONE pulse.** Every ring owned its own
      `AnimationController` and called `repeat()` the moment its card became
      mergeable, so a card that qualified later started its cycle from zero — and
      a grid with three pairs on it beat in three different phases. Identical
      animations out of step read as a fault in the game rather than as a hint
      about the cards. One inherited clock (`GridPulse`) now drives all of them,
      so a ring appearing mid-cycle joins the beat already in progress.
      The card's INCOME bar is deliberately left alone: its cycle length is
      derived from the player's own earning rate, so two bars running at different
      speeds is the information, not a bug. Do not "fix" it by syncing it.
- [x] **A signing arrives when it LANDS.** The engine has to place a card to
      allocate its square, so the card was already sitting in the cell the flight
      was about to deliver it to — the flight landed on top of itself.
      `gridPendingProvider` holds an instance id back for the length of the
      reveal, so the square is empty until the card gets there. The merge's own
      discovery reveal does the same.
- [x] **A card moved by hand is just THERE.** The 350ms slide is for the SORT,
      which reorders the whole grid at once and is the one case where a player
      needs telling what moved. A card dragged between two squares travelled
      under their finger already.

### The HUD, on every screen

- [x] **The resources are a group on the RIGHT**, with the crest on the left —
      `.hud-chips { margin-left: auto }`, which is the JS's own layout. They had
      been packed against the badge with the empty half of the bar on the right.
- [x] **The glass covers the notch.** The shell wrapped the whole HUD in a
      `SafeArea`, which pushed the frosted band BELOW the notch and left the strip
      above it showing the raw page — a white bar across the top of the Shop and
      the Squad tab in light mode, with the blurred bar starting underneath it.
      The safe area is inside the glass now, so the blur and the tint run to the
      top of the screen and the chips still sit clear.

### Shop

- [x] **The coin and gem sheets fit their content.** `heightFraction` is a
      CEILING now, not a height: four coin packs is four coin packs tall, and
      taking two thirds of the screen to show them read as a screen that had
      failed to load.
- [x] **Every shelf has its art.** `ShopTile` has had a `glyph` since it was
      written and nothing ever passed one. Not the catalogue's emoji either —
      that one is plain text for the toast to render — but the app's OWN line art
      from `game_icon.dart`, which is what the rest of the game is drawn in.
- [x] **The four coin packs have pictures of what they are called** —
      `coin_pack_art.dart`: a drawstring pouch, a heap, a strongbox with the lid
      up, and a peak with coins coming off it. Nothing bundled and nothing needed:
      four compositions of the same filled coin the cluster is built from, so they
      scale to any tile and theme with nothing.
- [x] **Nothing is ever refused for want of money.** A priced row stays live
      whatever the balance; tapping it asks, and answering yes either completes
      and shows a receipt or opens the coin/gem packs — `purchase_flow.dart`. "Not
      enough gems" is a dead end, and the answer to wanting something is a way to
      afford it.
- [x] **Restore Purchases is a quiet row** rather than a stranded button with a
      caption under it, and the "coming soon" under it is gone — it was the fourth
      time that sentence appeared on one screen.

### Club

- [x] **The whole card opens the upgrade path**, not just the 64px strip of
      artwork the tap used to live on.
- [x] **The bottom of the screen adds it all up** — `club_stats_panel.dart`,
      ported from `_renderStats`. Seven facilities at eight tiers each is too much
      arithmetic to do in your head, and "what is all this worth" had no answer
      anywhere in the port. Every figure is the gate function the game runs on, so
      the panel cannot claim a multiplier the engine does not apply. Each row
      explains itself on a tap — those hints were written, shipped and
      unreachable — and before the first build it is one line rather than seven
      rows of ×1.00.

### Home

- [x] **The next-match card's ATK and DEF bars were drawn at NO HEIGHT.**
      `FractionallySizedBox` with a `widthFactor` and no `heightFactor` passes the
      incoming height through loose, and a `DecoratedBox` with no child takes the
      smallest size it is allowed. Both tracks read as empty because both were
      zero pixels tall.
- [x] **`<LEAGUE> · MATCH N` is back over the card** — `fixture_caption.dart`,
      the JS's `.league-fixture-caption` including the two rules that fade out of
      the accent. Without it the card was two clubs and a VS with no competition
      and no place in the season. **No ellipsis**: the whole line scales down
      instead, because a division's name is a name.
- [x] **A rule above the tactic, and no glyph on it.** The chip already wears the
      tactic's colour on its fill, its hairline and its name; a fourth statement
      of it cost a row of vertical space the card has none of. Both halves in
      caps, and `TOTAL REWARD` with them.
- [x] **The trophy badge was cropped on all four sides.** The artwork is square
      and the badge is a circle, and it was set to `cover` — so a trophy lost its
      handles, its plinth and the top of the cup. Contained and inset now.
- [x] **The dock orbs' glyphs are LIGHT, whatever the theme.** The disc is
      deliberately dark glass over the diorama and the glyph was inheriting the
      app's own icon colour — so in dark mode the burger drew three black lines on
      a black orb. One `IconTheme` on the disc fixes every orb at once.
- [x] **The Play button has three edges and a glow now.** The white rim alone
      was not enough: the face is the club's colours, those are green as often as
      not, and the button sits on green turf — rim, face and background were all
      one hue apart. A dark ring outside the white one means something between
      the button and the pitch differs sharply on ANY kit, and the accent glow is
      what makes it read as lit rather than painted on.
- [x] **The position badge over the club name opens the table.** A position is
      a claim about a table, and the only route to it was three taps behind the
      burger.
- [x] **The `+1` home icon explains itself ON A TAP.** It always carried the
      right sentence — "Home advantage — your Fan Zone" — behind a `Tooltip`,
      whose default trigger on a touch screen is a LONG PRESS. The comment above
      it said "tapping one says the word", which the widget did not keep. Was: on a
      tap — where the number comes from, which is the Stadium's Fan Zone tier.
- [ ] **Coach Colin talks about himself in the third person** — "Coach Colin
      suggests Balanced". He is the one speaking and he has the whole state to
      hand; he should sound like it. **Every decision should come through him**:
      he is who the player talks to, so a confirmation is his card.
- [x] **THE INCOME BREAKDOWN.** `_showIncomeBreakdown` from the JS's HUD, on
      Colin's card: where the rate comes from, what the multipliers are doing,
      and what a loaned-in player is costing every second. Eighteen
      `hud.income.*` strings were unreachable and the coin chip had carried
      `hud.aria.income_breakdown` as its label since it was written with nothing
      behind it. Was: has to be on screen somewhere. It matters most
      when it is NEGATIVE: a loaned-in player costs money, and the only sign of
      it today is the idle bar quietly running backwards.
- [x] **IT WAS FOUR PIXELS TOO SHALLOW, not too deep.** Measured: the crest's
      tap target is 48 rather than the 38 it is drawn at, so the bar is 60 and a
      page starting at `56 + 10` began six pixels UNDER the glass. Derived from
      the bar now, with a test that measures the rendered band. Was: `hudClearance` is 56 on top of the
      notch; check it against the bar's real height.

### Quick nav and menus

- [x] **The quick nav is GLASS over the screen** — blurred and translucent
      rather than the opaque `surface` slab it was, which is the heaviest thing
      the app puts up for what is only a way of getting somewhere else.
- [x] **Its group headings are centred over the tiles they head**, and the tile
      labels are caps with no ellipsis — they scale instead.
- [x] **The Table tile was WHITE ON NEAR-WHITE in light mode.** A mid-table
      position was hard-coded to `Colors.white`, so the one league position most
      players are actually in was the one nobody could read. It takes the theme's
      ink now.

### The Play page

- [x] **The 2D cutaway comes on for a REAL chance now.** Three reasons to show
      nothing and the port honoured none: the two Settings switches
      (`cutawayOurTeam`/`cutawayOpponent`) were read by nothing at all, it cut to
      every chance rather than only a big one, and there was no pacing gap — the
      engine makes a chance every seven minutes, so the screen was a cutaway with
      a match happening behind it. Was: it should come on for a real
      chance and it should ANIMATE — `../merge-empire-fc` has a whole set of
      scenarios to port.
- [x] **The commentary said "Chance" because it was PRINTING THE EVENT TYPE.**
      A corner read as "corner" and full time as "fulltime" too — three raw,
      untranslated strings from the engine. `feedOf` is the JS's own rules, and
      the point of them is what they leave out. And a goal is DESCRIBED now:
      eight `commentary.goal.*` pools were unreachable while the feed printed
      the scorer's name alone.
- [ ] **And the styling throughout it needs sorting.**

### The squad, and the player sheet

- [x] **The player's image runs over the swap/bench buttons.** 200px of
      head-and-shoulders of a figure drawn full length; 260 now, with the
      buttons floating on its lower edge over a scrim — the scrim because the
      kit is the club's colour and so is the button. Was: should run over them, so he has
      room to render.
- [x] **THE SELL ASKS AS COLIN**, and so do the send-back and the recall. All
      three were `AlertDialog`s — the app's own voice asking about the squad, on
      a screen whose premise is that you have a manager to talk to. **No 30s
      timer exists anywhere in the port**, so there was none to drop. Was: drop the sell section and its 30s timer. One RELEASE button that
      deletes him, behind a Coach Colin confirmation.
- [x] **The trait section is a BADGE now**, with its glyph on a disc, the name
      and level beside it, the sentence saying what it does, and the accent on
      the border when a card has one.
      **And every trait in the game was untranslatable**: the sheet rendered
      `Trait.name`/`Trait.desc`, the English literals on the record, while all
      forty-two `trait.name.*` and `trait.desc.*` strings sat generated in ten
      catalogues with nothing able to reach one — the same tell that found the
      Shop's product names. `trait_copy.dart`, beside `shop_copy.dart`.
- [x] **A tier-maxed player is NOT highlighted for merging** — already done and
      already tested, including the ring: `mergeTargetsFor` checks
      `maxPlayerTier`. Was: should not be — he cannot
      be, until the next tier unlocks.
- [x] **The card's art starts at its TOP.** `contain` centres the slack, so art
      squarer than the card left a band of nothing above his head and shrank him
      to pay for it. As wide as the card and top-aligned; what is cropped is his
      boots, and the name band is over them anyway. Was: should run to the top. Wider is
      fine; the gap above it is not needed.

### The manager, and the customiser

- [x] **The moonwalk was a mis-MEASURED stride.** `walkerStrideArtUnits` was
      `_footX(0.5) - _footX(0)`, which assumes the foot is at its front and back
      extremes exactly on the halves of the cycle. The knee's own curve moves
      those turning points off the halves, so the figure was short — and the
      ground is matched against it, so he skated by exactly the amount it was
      out. Sampled across the whole cycle now.
- [x] **The advertising hoardings ran nearly four times too slow.** They were
      pinned to 2.1× the grass period against a 240px segment, where the ground
      they are planted in runs at the farthest tuft band's ratio — so the pitch
      swept past and the boards crawled. Derived the same way the tufts are, so
      the boards and the grass at their feet can only ever agree.
- [x] **The walking rig floats above its shadow again.** Found it, and it is why
      it kept coming back: everything INSIDE the painter is in art units and the
      painter scales them, while everything outside it — the sink, the hip bob,
      the sway, the shiver, a gesture's body lift — was written in art units too
      and applied as logical pixels. The shadow is laid out in FRACTIONS of the
      box, so it grew and shrank with the diorama and the figure's offsets did
      not: they agreed at exactly one rendered height and nowhere else. Scaled by
      the laid-out size now, with a test that measures the rig's place in its own
      box at two sizes and fails on the old behaviour.
- [x] **BOTH HALVES OF THIS WERE THE SAME KIND OF GAP.**
      **Body shape did nothing**: the axis was in the customiser, the wardrobe,
      the randomiser and the save, and six choices produced one figure —
      `buildScales`, `buildArmScale` and `buildOverlay` had no port, and the
      renderer carried a `build` parameter nothing passed.
      **And the tracksuit was a necklace because it was only a collar.** An
      outfit is mostly a PALETTE in the JS — forearm, shin, boot, waistband —
      with geometry only for a coat's skirt and a suit's lapels. Those two are
      generated art and drew fine, which is why a coat made him read as a
      person; the tracksuit's whole existence is the palette, so all that
      reached the screen was its collar swoosh. Was: body shape does nothing, and the tracksuit renders as something like a
      necklace. `../merge-empire-fc` is nearly right; this should be better.
- [x] **He WALKS in the customiser, on grass.** He stood still on the sheet's
      own surface, which is a figure in a dressing room — and what is being
      judged is how a look MOVES. The backdrop is the scene's own sky and turf.
- [x] **Every style box is a picture of itself.** The first cut argued against
      miniatures and was half right — at four to a row a whole manager is sixty
      pixels tall and a moustache is four of them. The answer is not a word, it
      is a CROP: the head axes frame the head, the body axes the body. Previewed
      on HIS face, under HIS hat, in HIS colour; the colour axes keep their
      swatch, because a hair colour IS a colour.
- [x] **All eight axes are on screen at once.** They were a horizontal strip and
      eight tabs do not fit across a phone, so Hat and Face lived off the
      right-hand edge with nothing to say they were there. Was: the wrong navigation — the far ones
      are easy to miss behind a scroll.

### Deadline Day, and names

- [x] **The banner said `DEADLINE_DAY`** because the strip asked `tName` for
      `event.deadline_day`, and the catalogue holds the name under the
      definition's own `nameKey`, `event.deadline.name`. The lookup missed, so
      `tName` fell back to the id and the banner shouted it. `eventName` and
      `eventFlavour` resolve it properly, and all three call sites use them.
- [x] **Renaming a player is missing**, and a name that IS set has to carry
      through to Deadline Day. It did not in the original either. Built:
      `util/player_name.dart` was a ported, tested sanitiser and screener with
      no caller anywhere in `lib/`, eight `rename.*` strings were unreachable in
      ten catalogues, and `season_rename` and `season_rename_many` counted
      renamed cards so were quests that could never advance. The pencil sits
      beside the name on the detail sheet, and not on a loan in either
      direction. The name carries: every listing already names our players
      through `card.name()`, which reads the custom one first.
      Also fixed a real collision that came out of building it — the name bar
      and the floated Replace/Bench buttons shared the artwork's bottom edge,
      and the buttons are drawn second, so anything at the end of the name row
      was untappable.
- [x] **Buying a player on Deadline Day must deliver THAT player.** Suspected
      bug in the original too — and it is one: `_acceptSigning` rolled a fresh
      instance and copied only the name, so the variant, the trait and the
      ATK/DEF split the feed showed were not what landed. Fixed, with the roll
      still SPENT and thrown away: the JS's position in the merge RNG stream is
      part of the spec and every later card depends on it, so skipping the draw
      would have turned a one-card fix into a divergence everywhere after it.
      The parity fixture now checks the delivered card against the listing's and
      the rest of the result against the JS's, which keeps the divergence one
      field wide.

### Settings, sound and graphics

- [x] **The screen is CARDS now, not a list.** It was a flat `ListView` of
      `SwitchListTile`s, which is a debug menu: no grouping, no icon column, and
      every setting the same weight as every other. `settings_controls.dart`
      carries the JS's two containers (`SettingsCard` for an unlabelled group,
      `SettingsGroup` for one with a heading) and its row — icon, label, control
      on the right — and nothing on the screen draws its own box any more. The
      toggle is the JS's own 48×28 pill rather than a Material `Switch`, for the
      same reason the icons are the JS's line art: beside the game's own
      controls, a borrowed one reads as borrowed.
- [x] **A pair of named states is a SEGMENT.** Match speed as a toggle asks the
      player to work out which way is fast; as `1× | 2×` it says so. All three of
      the JS's segmented controls were switches here — speed, difficulty, and the
      pitch-view pair, which is not even one choice out of two but **two
      independent flags** drawn side by side, because the cutaway can be on for
      both sides, one, or neither.
- [x] **The entries the JS has and the port did not.** Club name (a real rename
      through Colin's card, screened by `validateClubName` on the way in, with
      the JS's name generator behind a dice); Team Names; Rate Us; Privacy
      Options; the rankings-visibility toggle, disabled the way the JS disables
      it when nobody is signed in; and the FOOTER, which is the only place in the
      game that says which build a player is on. Anything needing a service M4
      has not delivered ships disabled with a reason.
- [x] **The Start Over rows did NOTHING.** Both opened Colin's card with an empty
      handler behind the confirm button — a player could read the warning, agree
      to it, and watch nothing happen. Wired to `resetState` / `fullResetState`,
      which have been in the engine since M1. They are on GENERAL now, under
      their own heading, where the JS has them; they had been on Account, which
      is the tab about signing in.
- [x] **And a reset used to leave the game unable to save, permanently.**
      `_finalizeReset` left `_frozen` set, and the doc comment said so: "only a
      reload clears it". That is true of the JS, which follows a reset with
      `location.reload()`. This app has no reload, so wiring the button would have
      shipped a save that silently stops writing. The freeze is now for the length
      of the reset only — by the end of it the pending timer is cancelled and the
      fresh state is in both the slot and the mirror, so there is nothing left to
      protect against.
- [x] **The audio toggle and slider are ONE control**, with the JS's two rules:
      turning a channel on at 0% nudges it to 5% (a control that says it is on
      while nothing can be heard is indistinguishable from a broken feature), and
      dragging the volume off zero turns the channel back on — reaching for the
      volume is how a player says they want to hear it.
- [x] **The sound engine is built, and the SFX are SYNTHESISED like the JS's.**
      `audioplayers` is the new dependency. Three files: `util/audio_render.dart`
      is an offline renderer (envelopes at Web Audio's own semantics, RBJ biquads,
      a soft-knee compressor, a WAV encoder), `data/sound_defs.dart` is the
      twenty-four recipes ported one for one, and `services/sound_service.dart`
      holds every rule with the platform behind a `SoundBackend` — so the rules
      are all tested and only the thin `audioplayers` adapter is not.
      Five things worth knowing before touching it:
      **(1) Offline, not live** — the JS's reason survives (rendering to a buffer
      never touches the audio hardware, which is what kept it clear of the Samsung
      AAudio crash loop) and it buys a second one here: the output is plain PCM, so
      the whole engine is testable without a device.
      **(2) The blur-equivalent for audio is the COMPRESSOR** — at ratio 6 over a
      -18dB threshold, a 6dB gap between two sounds comes out about 1dB apart, so
      loudness is not a usable cue anywhere in this engine and anything that wants
      to feel bigger has to do it with texture.
      **(3) `_noise`'s volume lands TWICE** in the JS — buffer filled at `vol`,
      then a gain envelope opening at `vol` — so every burst starts at `vol²`.
      Copied rather than corrected, because the numbers were tuned by ear against
      it and "fixing" it makes every noise layer twenty times louder.
      **(4) The randomness is SEEDED**, unlike the JS's `Math.random()`. A synth
      rendered once at boot gains nothing from differing per run, and a seed means
      a test can assert what came out.
      **(5) The bus is the wiring** — `services/sound_cues.dart` is the JS's own
      `on(...)` table, so the merge engine and the transfer engine never learn
      about audio and the same action sounds the same from every screen. Match
      sounds are the exception and belong to the CLOCK: the whole ninety minutes is
      decided before the screen opens, so an event fired when the maths was done
      would have played every goal at once.
      The crowd cheers are deliberately NOT ported — see the note in
      `sound_defs.dart`. Render cost is ~800ms in debug for all 24, in an isolate
      after the first frame.
- [x] **The volume sliders WORK on iOS, and the JS's gate does not port.** It
      hides the slider on iOS because every sound there goes through an
      `HTMLAudioElement` and WebKit treats `HTMLMediaElement.volume` as read-only
      — Apple reserves volume for the hardware buttons. That is a restriction on
      WEBVIEWS, not on the platform: a native player sets its own gain. Porting
      the gate would have carried a web limitation into an app that does not have
      it. Confirmed now that the engine exists: `AudioPlayer.setVolume` is
      `AVAudioPlayer.volume` on iOS and it is writable, so the sliders are shown
      everywhere.
- [ ] **Prefer the Kenney packs, Flame or Rive over emoji** for artwork —
      `kenneynl/` holds game-icons, sports, emotes, modular-characters,
      background-elements and smoke-particles, all CC0. Settings is done: every
      row takes a glyph from the app's own line-art set. The two Start Over rows
      keep their emoji ON PURPOSE — a ball and a skull are what tell those two
      apart at a glance and neither is in the set.
- [x] **The JS's button treatments are `StoreButton`, and the rule is the JS's
      own sentence: ONE BUTTON, FOUR COLOURS, and the colour always answers
      "what does this cost me?"** Green real money, blue gems, gold coins, yellow
      a rewarded video — plus a fifth, accent-coloured tone for the buttons that
      are not prices at all, so a confirm does not borrow a currency's colour.
      Every one of them had been a plain `ElevatedButton` in the kit accent, so a
      shelf holding coin packs, gem packs and cash packs was one green wall and
      the price was the only thing telling them apart.
      Three details that are not decoration: **the card around a button is
      coloured for what it IS and the button for what it COSTS** (which is what
      lets the Looks vault be purple, hold blue-priced packs and carry a green
      buy button without any of the three lying); **it is MOULDED** — a hard 3px
      edge under the face, and a press that drops the face onto its own edge,
      because a shop is the one screen where a control has to look worth pressing;
      and **yellow carries its own DARK ink**, since white on `#ffd54a` is
      unreadable and it is the one tone in the set that inverts. `tone` is
      REQUIRED on `ShopTile` — a tile that forgets its currency looks identical
      to one priced in the accent, and the whole point is that it cannot be got
      wrong quietly.

### The bar that was never there — four times

- [x] **`BarFill`, and every progress bar in the game goes through it now.**
      Four separate bars were drawn, in the tree, and **zero pixels tall**: the
      next-match card's ATK/DEF tracks, the Play button's cooldown sweep,
      Deadline Day's fuse, and the player card's income bar. One of them had been
      fixed in place with a comment explaining the mechanism; the other three
      were still broken, which is what a local fix buys you.
      The mechanism needs BOTH halves, which is why it keeps coming back: a
      `FractionallySizedBox` with a `widthFactor` and no `heightFactor` passes the
      incoming height through LOOSE, and a `ColoredBox`/`DecoratedBox` with no
      child takes the smallest size it is allowed. The code looks right, the
      widget is there, and a test that asks "is it on screen" passes. So no track
      states the factor for itself any more — if a fill is a fraction of a bar,
      it is a `BarFill`, and the test measures the rendered box rather than
      finding it.

### Two screens that want a pass

- [x] **The Fixtures screen is still not right stylistically.** It was showing
      the WRONG LIST, which is why nothing about it read right: it rendered
      `seasonFixtures` — the whole division's grid — as neutral "Ayton v
      Beeches" rows with a round number. That table exists to feed the
      standings' form dots and is not what a manager opens Fixtures for. The
      source's panel is the manager's own fourteen, and every one of them
      involves US — so a row names only the OPPONENT, leads with a fixed-width
      venue chip that can be scanned straight down (it answers "am I at home"
      for the whole season at a glance), carries their rating with a `~` while
      it is still a guess off the division's midpoint, and puts the score in a
      fixed right column coloured by the OUTCOME rather than by whether it has
      been played. Three headings split it: previous, next, coming up.
      Still to do: the cup rounds woven in between league matches (after #3, #8
      and #12 in the source), and scrolling to the current fixture on open.
- [x] **The daily reward's cycle FILLS UP.** The strip picked out today and
      marked nothing else, so a player four days into a streak saw days one to
      three drawn exactly like days five to seven — seven identical tiles with
      one border on them. What each day pays was already on every tile; what was
      missing was the ticks, and watching it fill is the whole point of a cycle.
      A broken streak has nothing banked, which is right.
- [x] **The scout voucher shelf is wrong** — five things, and four of them were
      copy nothing could reach. Every tile read "Scout Vouchers 5", which spends
      the widest line on each of eight tiles saying what the section heading has
      already said; the TIER is the name. The floor rule — "or better · normally
      4%" — was missing entirely, and it is load-bearing rather than a footnote:
      a tile reading just "GOLD★" is the exact-tier misreading the whole design
      was chosen to avoid. Only the rungs this division can BUY were listed, so
      the top of the ladder was not there and `shop.voucher.unlocks_in` had
      nothing able to reach it — a ladder with its top hidden is a shelf, and it
      takes the reason to climb with it. The rung being held did not say so
      (reading "am I holding this" off the block had every tile claiming to be
      the one). And the 🎲 gamble rung — the cheapest, and the only one that can
      hand over an Icon — was not on the shelf at all.
- [x] **Every decision comes through Coach Colin now.** His card is the shape:
      his portrait floating ON the top border rather than an avatar in a title
      row, `COACH COLIN` under it, what he says shown immediately — these are
      decisions, often on a clock — and the answers COLOURED, green for yes and
      red for no, in a line and the same width. `CoachCardFrame` is the chrome on
      its own, so a card with real content (a sponsor's terms, a player's
      portrait) uses his frame rather than inventing one. The sponsor offer had a
      company logo where his head goes and two uncoloured buttons at the bottom.

---

### The sky, and why it follows the theme

**Decided: light mode is daylight, dark mode is night.** The stadium TIER keeps
driving the grandeur — park to floodlit arena — which is what the JS already keys
its own `darkScene` flag off. What is dropped is the JS's ~10-minute day→night
clock, and it is dropped on purpose.

- [x] **`skyGradient` is a FUNCTION of the theme and the tier** —
      `lib/ui/theme/sky.dart`, which is the one place the mapping is stated and
      the only thing the diorama, the match page and the crowd's haze read. Two
      ramps rather than the JS's one: the day ramp runs its tier 0 to its tier 2,
      the night ramp its tier 5 to its tier 8, so the ends are lifted from the
      source rather than invented. The two must not OVERLAP — a park in daylight
      has to beat an arena at night, or the setting stops meaning anything, and
      that is asserted rather than eyeballed.
- [x] **The floodlights are BUILT by the tier and LIT by the theme.** The JS's
      own counts (one at tier 4, two at tier 7), so a top-tier ground has its
      pylons standing grey and cold in the afternoon — which is the whole
      difference between a big club at three o'clock and the same club at night.
      If the tier decided both, the theme would be cosmetic. The pylon is
      proportioned off the TERRACE (2.6 of them) rather than off the viewport as
      the JS does: at 46% of the scene the heads land behind the next-match card
      and all you see of a floodlight is two thin poles crossing the sky, which
      read as cables.

**And then theme everything else against it — which was the real prize here, and
it is collected.** Every panel that floated on the diorama was a COMPROMISE
struck against one fixed dusk-blue sky:

- [x] **The next-match card follows the theme now.** In light mode it is a light
      pane under the app's own ink, and the one card on the screen that ignored
      the theme stops being that.
- [x] **`glassThemeProvider` is GONE, not halved.** It existed only to hand a
      dark subtree the dark build of the kit — and once the pane follows the
      theme, the app's ink is already the right ink for the surface it is written
      on. The `DefaultTextStyle`/`IconTheme` merge inside `GlassPanel` went with
      it, and so did the `Builder`s at both call sites that existed to get under
      the override. **The light recipe is DENSER than the dark one, not a mirror
      of it**: a dark pane hides a busy backdrop by swallowing it, a light one has
      to out-shine it, and the rim and sheen invert too — a white hairline is the
      edge of dark glass and is invisible on light, so light glass is edged in its
      own shadow.
- [x] **The diorama's turf has both palettes now.** A sunlit pitch under a night
      sky was the thing that gave away that the two halves of the scene were each
      deciding their own light. Floodlit grass is cooler and darker rather than
      simply dimmer, and the pools the pylons throw put the light back in two
      places. (The `_turf`/`_turfLight` pair the note pointed at is the SQUAD
      pitch — a different file, and the pattern rather than the fix.)
- [x] **The crowd's aerial haze was hard-coded to `#1B3A57`** — the old fixed
      sky's top stop. Anything that fades into the distance now takes `skyHaze`,
      which is the sky at the HORIZON rather than the sky overhead, or a daylight
      scene would have had its terrace receding into a twilight that was nowhere
      else on the screen.
- [x] **The HUD's `onScene` branch** no longer forces the whole bar under the
      dark build of the kit. In dark mode that override was always a no-op; in
      light mode it was the reason for pale-green figures on a near-white pill.

Five reasons the theme won, in the order they mattered:

1. **The glass is already tuned against a KNOWN sky.** `glassThemeProvider`, the
   pitch's `_turfLight`, the HUD's dark-glass branch and the next-match card's
   "deep" tint were each chosen against one fixed backdrop. A sky on its own
   ten-minute clock fights all four: the card's opacity, the HUD's tint and the
   turf's palette would each be right twice a cycle and wrong the rest of it.
2. **The match page stands on this same sky** — deliberately, so that "arriving
   at a match is not arriving in a different world". A cycling sky means the
   background changes mid-match for a reason nothing on screen explains.
3. **The device clock has a failure mode with no fix.** A player on a night shift
   never sees the daylight art at all — and the stadium heroes are PHOTOGRAPHS
   keyed to tier, not to time, so you would get a night sky over a daylit
   stadium. That needs a second set of eight photographs to solve.
4. **It makes the setting mean something.** Someone who chooses dark mode gets a
   night match. The clock option makes their choice cosmetic.
5. **It is deterministic**, so a widget test can assert what the sky is.

**And one correction that came out of checking this.** The port's sky was a
single static gradient — nothing modulated it — so there was no day cycle in the
port to change. If a slow light → dark → light drift is visible on a real device
it is coming from something else and I have not found it: the scrollers tile
seamlessly and the stand's gradient runs down its height rather than across its
width. **Worth a screenshot if it is still there** now that the theme-driven sky
has landed, because it would then be a second, separate bug.

**What is NOT here, on purpose.** The JS also hangs a sun, clouds, stars and
camera flashes on this sky, and none of them are ported yet — they are a
`docs/PARITY.md` item rather than a compromise this decision unblocked. The one
thing to know before adding them: stars and flashes are night furniture and the
sun is day furniture, so they key off `nightScene` and nothing else.

**And one thing this cannot fix from inside the scene.** On a five-band
next-match card the pylon heads sit behind the glass. The scene does not know
where the card ends and should not; the heads glow through, which is what the
pane being glass is for. What DID have to change is how tall the pylon is: the
JS gives it 100% of a layer that is 46% of the scene, which on a phone put the
lamps behind the card at every size. It is proportioned off the TERRACE now
(2.0 of them), so the head lands in the strip of sky between the card's foot and
the stand's fascia.

### What the light sky broke, and what it took to fix

A daylit sky is not a free win: **every panel and every line of text on the
diorama had been written against a dark backdrop**, and the ones that hardcoded
white went white-on-white the moment the sky came up. Found by rendering the
screen rather than by reading it, which is the only way this class shows up.

- [x] **The glass was far too pale.** The first light recipe was a wash at 78%,
      which composites to about 0.92 luma over a sky already at 0.58 — 1.4:1, so
      the pane did not read as a pane and the next-match card was a smear. **A
      dark pane hides a bright backdrop by swallowing it; a light one has to
      OUT-SHINE it**, and that takes most of the way to opaque. What keeps it
      glass is the 15% of sky still coming through, the blur, and the rim — not
      the transparency being high. The rim and the drop shadow both went UP for
      the same reason: in daylight the pane is brighter than the sky, so the
      shadow is the only thing lifting it off, and a light card without one is a
      hole in the sky.
- [x] **The fixture caption was white in both themes**, and its own note said
      why: "no theme colour survives both ends of that". True of a sky on a
      clock, false of one that follows the theme. `skyInk` is the single answer
      now — dark ink with a white halo in daylight, white with a dark halo at
      night — and the halo has to invert with the ink or the line dissolves
      wherever the gradient passes through its own tone.
- [x] **Everything a pane draws INSIDE itself was white at 6–15%.** On dark glass
      that is the whole vocabulary for separating one band from the next; on a
      near-white pane it is nothing, so every rule, chip outline and hairline in
      the card vanished. `glassInk` inverts it and keeps the alphas.
- [x] **The ATK/DEF well was a black wash at 24%** — depth on dark glass, a
      mid-grey slab on a light one that outweighed everything else on the card.
      A whisper there; the border does the work instead.
- [x] **The ×2/×4 chip disappeared in light mode.** Inverting to an accent-INK
      fill is what makes it read as the selected half of the pair — but
      `accentInk` is near-white on a light theme and so is the page behind the
      bar, so the ×4 floated on nothing. It takes an edge in the ACCENT, which is
      the colour it inverted away from, so the pair still reads as one control.

**The rule this leaves behind:** anything sitting on the diorama takes `skyInk`
or `glassInk`. A literal `Colors.white` there is now a bug by construction, and
grepping for one is how the next of these gets found.

### Artwork, and which packs

`kenneynl/` holds six of Kenney's packs, all CC0 (credit optional). The rule from
playtesting is **no emoji where a drawn thing will do** — which is why the shop
now uses the app's own line art and the coin bundles get real pictures.

- [x] **`kenney_modular-characters` is BUNDLED** — 428 PNGs, 1.8MB, extracted flat
      per layer into `assets/manager/{skin,face,hair,shirts,pants,shoes}` and
      registered in `pubspec.yaml`. Only the PNG tree: the pack also ships
      vectors, spritesheets, a preview and a licence, and a pubspec pointed at the
      raw folder would put all of it in the app.
      It is a layered paper doll — head, neck, arm, hand and leg per skin tint,
      shirts carrying their own sleeve lengths, pants, shoes, hair in six colours,
      face features — which is exactly the shape `manager_walker.dart` already
      works in. The rig turns JOINTS, so giving it real parts to turn is a swap
      rather than a rewrite. **This is what unblocks the whole manager cluster
      above**, previews included.
- [ ] **`kenney_background-elements-remastered` (1.6MB) is the next candidate** —
      for the customiser's backdrop, and possibly the diorama.
- [ ] **`kenney_sports-pack` is already half-extracted** into `assets/pitch/`.
      Worth going back to it for the 2D cutaway rather than drawing more by hand.

Three that are deliberately NOT bundled, so nobody spends the download twice:

- **`kenney_game-icons`** — the app already ships a consistent line-art set
  ported from the JS (`game_icon.dart`, 57 glyphs). Swapping it churns something
  that works. `video` for the rewarded-ad buttons is the only piece worth taking.
- **`kenney_smoke-particles`** — 5.9MB, and the merge burst already draws its
  particles procedurally at any size and in any tier's colours.
- **`kenney_emotes-pack`** — good for Colin's reactions one day; nothing needs it.

**Rive is not a route yet.** The MCP server is registered for this project but
ships inside the Rive **Early Access** desktop app, which is not installed — and
Rive's own pricing page lists Early Access under Cadet/Voyager/Enterprise rather
than Free. Separately, PLAYING a Rive rig in the app would mean adding the `rive`
runtime alongside `flame`, which is a dependency decision nobody has taken.

---

## From playtesting — 21 Aug

A third session, run against the light-mode sky and the new sound engine. Most
of it was closed as it came in — the entries below are what is LEFT, plus three
designs that came out of it and are worth writing down properly before anyone
starts them.

### Where this queue stands

**7 open.** Three controls are waiting on M4, one is the daily reward, three are
designs, one is a copy fix that has to go through the JS first, and one is the
rest of a consistency sweep. The five mini-game screens and the pyramid editor
are done.

### The five mini-games that had no screen — built

- [x] **The locked row NAMES the tier now, and the ladder is data.**
      `getUnlockedMinigames` was a stack of ifs, and the row asked
      `club.minigame_unlocked` with no parameters — so it rendered the literal
      `{name} unlocked`, and "the Training Ground has not reached it" and "there
      is no screen for it" both said nothing useful. `minigameUnlockTier` is the
      one ladder both read, and a test walks every tier against it.
- [x] **A resting drill offers the SKIP.** `resetMiniGameCooldown`,
      `skipAdsLeftToday`, `recordSkipAd` and `Minigame.skipCapPerDay` had all been
      in the engine since M1 with **no UI caller at all**, which is the whole
      reason there was no advert button. It shows only on a drill that is
      unlocked, built and waiting on the clock — there is nothing to skip on a
      locked one and nothing to skip on one with no screen. Dead until AdMob
      lands, shown rather than hidden, same as the Shop's own two ad tiles.
- [x] **And the five screens themselves.** "Training sessions are not unlocking"
      was never an unlock bug: the ladder works and the provider recomputes on
      every save change, but `playableMiniGames` held only `penalty` and
      `bootRoom`, so tiering up unlocked a drill that could not be played.
      All five are built now and `playableMiniGames` holds all seven:
      **Through Ball** (the timing bar, a shrinking zone per round),
      **Pitch Invaders** (nine holes, one wall-clock deadline read every frame),
      **Team Work** (the memory grid over the card art),
      **Goalkeeper Practice** (a scheduled sixteen seconds of drills) and
      **Keepy Uppys** (three balls of physics, pinned frame by frame against a
      node dump of the JS's own loop). Every engine behind them had been ported
      and tested since M1 and roughly forty translated strings across ten
      catalogues could not be reached by anything.

### Four controls that look broken because they are waiting on M4

- [ ] **Rate Us, Privacy Options and Account Connection** are `PendingControl`s
      with "coming soon" on them, and a player reasonably reads that as broken.
      Rate Us is the one that could ship now — it is a store URL and a
      `url_launcher` dependency, nothing more. Privacy needs the consent SDK and
      Account needs auth; both are genuinely M4.
- [x] **Team Names is a SCREEN, not a service** — the pyramid editor, with
      presets, import and export (`pyramid.*` has fourteen keys waiting for it).
      It is the one of the four that is only work. Built: the Settings row was a
      `PendingControl` over five hundred ported, tested lines of
      `pyramid_names_engine`, and twenty-five `pyramid.*` strings translated in
      ten catalogues could not be reached. The sheet steps division by division,
      renames a club through the engine's validation, pastes a whole division as
      a list, and saves, applies and imports presets.

### The daily reward

- [x] **It ticks off the days you have claimed.** Was: it does not, which is the whole
      point of a seven-day strip, and tapping a day does not say what that day
      pays — it just swaps the title to "Congrats". Check `../merge-empire-fc`:
      the cycle strip marks banked days and a tap previews the rung.

### Three designs that came out of this session

**These are specs rather than tickets.** Each is a real piece of work and each
has a trap in it that is worth stating before the first line is written.

- [ ] **THE 2D PITCH SHOULD PLAY CONTINUOUSLY, not cut to chances.** Today the
      cutaway appears for a chance and vanishes; the idea is that the players
      keep moving between chances — making runs, passing, holding shape — and
      that when a chance is coming the shapes TRANSITION into the positions the
      chance needs, so the passage flows out of the play rather than replacing
      it. Stats move behind a button next to the commentary; with the 2D view
      switched off the stats stay put and the button does not appear.
      **The trap, and it is the whole difficulty: the ball has to be
      CONTINUOUS.** Chances are independent draws from the sim — four shots in a
      row can be at alternate ends — so played literally the ball teleports
      after every one. Making it work means the in-between play is what RECONCILES
      two consecutive events: after a shot the ball has to plausibly get from
      that goal-kick or corner to wherever the next event starts, and the
      interval between the two minutes is the budget for doing it. That is a
      pathing problem over a fixed timetable, not an animation problem, and it is
      where the design either holds or does not. A tackle, a clearance and a
      throw-in are the vocabulary that makes an arbitrary transition legible.
      **What is already in place:** the clock now STOPS while a chance is on the
      pitch (it did not, which is why the minute lurched), and `cutaway_stage`
      already owns a clip with an outcome.
- [ ] **THE PENALTY GAME WANTS A PHYSICS PASS.** The ball should turn as it is
      struck, arc and fall properly, and bounce off the frame; the keeper should
      fall rather than translate. Building the goal, the frame and the net as
      geometry rather than using the flat art is explicitly fine, and is probably
      the way in — a net that can be deformed by the ball is most of what sells
      it.
      **The trap: the OUTCOME is already decided** by `takePenalty` before
      anything moves, and it must stay that way (the engine is proven against the
      JS). So this is not a simulation — it is an animation that has to be
      constrained to end in a known state, which means solving for the flight
      that reaches the given corner and the given result rather than integrating
      forces and seeing what happens.
- [ ] **USE THE KENNEY PACKS FOR CELEBRATION AND BACKDROP.**
      `kenney_smoke-particles` for a merge, a discovery, a pop — anything that
      appears or is worth celebrating; `kenney_background-elements-remastered`
      behind the manager customiser, the training screens and the match popups;
      and more of `kenney_game-icons` where the app's own set has no glyph.
      **The trap: the merge burst is currently PROCEDURAL** and draws at any size
      in any tier's colours, which a sprite sheet cannot do. So this is an
      addition rather than a replacement — sprites for the things that have no
      effect at all today, and the procedural burst stays where a tier colour has
      to drive it.

### Odds and ends closed on the way

- [x] **The top HUD has a 10px margin under it.** `hudClearance` is the bar plus
      `hudBottomMargin`, so the first thing on every page starts clear of the
      cluster rather than reading as one block with it.
- [x] **The tactic line's padding came off.** It is a line rather than a badge
      now, and 5px top and bottom made it read as the chip it stopped being — on
      the one card with no vertical room to give.
- [x] **The manager's hair is not a block any more.** The JS draws each style as
      one filled silhouette, which at this size is a helmet. Three passes over the
      SAME path fix it with no new geometry: a soft white rim along the outline
      (which the notches at the temple and the parting already pick out), a darker
      line just inside it in the hair's own slot colour, and two crown strands on
      the styles with a solid cap. Generic on purpose — there are twelve styles
      and the painter supports neither clip paths nor scale transforms, so anything
      hand-drawn would have to be drawn and checked twelve times. In the
      GENERATOR, not the `.g.dart`.
- [ ] **Counter Attack's description is WRONG, and it is wrong in the JS too.**
      "ATK and DEF swap as play flows" — they do not swap. Its base is DEFENSIVE
      (`atkMult 0.92`, `defMult 1.08`); what moves is the attack multiplier,
      lifted by `commitmentGain 0.18 × commitmentRead(...)` against a side that
      commits forward and cut against a deep block, with `swing 0.5` widening the
      result either way. The true line is "sits deep and reads the opponent —
      deadly against a side that commits, toothless against a block, and the
      widest spread of results". The string lives in the GENERATED catalogue, so
      fixing it means changing the JS's own i18n first. High Press's "Strongest
      boost" is accurate — `1.22` is the biggest attack shift — but omits that it
      is also the most exposed at the back at `0.78`, below All Out Attack's
      `0.82`.

### Consistency, and how far it got

- [x] **`SheetHeader` is the one rule for a popup title** — caps, the club's
      accent, centred, 15/w900, with an optional muted sentence under it. There
      were five: the Energy sheet's green at 18 centred, Auto-Sell's plain ink at
      16 left-aligned, the Trophy Room's caps, Coach Colin's plain w900 at 17,
      the quick nav's accent at 18. Each defensible alone; the set of them reads
      as five different apps.
- [x] **The sweep is finished.** Energy, Quests, Auto-Sell, Daily Reward, the
      league table and the asset ladder were converted first; the currency sheet,
      the sell sheet, the deadline negotiation sheet, the training list and the
      leaderboard's own header followed, and all SEVEN mini-game screens now wear
      one `MiniGameHeader` instead of a Material `AppBar` — sentence-case ink at
      the left with a back arrow is the chrome of somewhere you navigated to, and
      a drill is a takeover. `test/ui/popups/sheet_header_test.dart` sweeps the
      tree so a new sheet cannot quietly grow a sixth style.
      The player sheet is a THIRD stated exception rather than a conversion: its
      title is the player's name written across his own portrait, which is the
      source's design and a header the artwork is part of. A bar above it would
      say his name twice and push the picture down to do it. All three exceptions
      now say in their own headers that they are exceptions.
      Two are deliberate exceptions and should stay that way — Coach Colin's card
      (his title is him speaking, under his own name plate) and the achievement
      banner (a celebration, not a heading).

## From playtesting — 22 Aug

Live feedback, mostly on the diorama, the HUD and the 2D cutaway. What is left is
at the end; the rest was closed as it came in and is recorded because two of the
findings were arithmetic rather than taste and one is a reversal.

### The chrome is the club, and that is the JS's decision

- [x] **Both bars wear the kit colour now.** `kitTheme.js` says it in as many
      words: light mode is deliberately NEUTRAL — white cards on a light-grey page
      — and the hue is for accents *"AND for the HUD top bar + bottom tab bar,
      which are solid accent-coloured chrome"*, with their text and icons flipped
      to `accentInk`. Both bars were `surface`, so a player who picked claret and
      blue got a grey app with a green tint in the buttons. On four of the five
      tabs those bars are the only surfaces big enough to say whose club it is.
      Dark mode is a very dark tint of the same hue rather than the accent at full
      strength — a saturated bar on a near-black page is a stripe of daylight
      across it. Derived from the accent rather than added to `KitSurfaces`: the
      JS builds `--hud-gradient` per kit from the same hue, and blending to
      near-black reaches the same place without a second pinned value.
      Two consequences that had to follow: the tab bar's ink is `accentInk`
      (`textMuted` is a grey for a grey surface and on claret read as dirt), and
      the Play tab's disc INVERTS — an accent circle on an accent bar is one
      colour, and the one tab with any weight in the bar was the one that
      disappeared.

### One HUD, after three tries

- [x] **The cluster is ONE glass pane, on every tab.** Worth recording the whole
      path because two of the three attempts were wrong for the same reason.
      It began as four separate pills — one per reading — which read as embossed
      buttons: four rims, four shadows and four highlights for what is one
      instrument. Collapsing them into one box fixed that, and the box was then
      made a SOLID pill because a 13px accent-green figure on glass was under
      2:1. That was the wrong end: the pane was never the problem, the FIGURE was.
      With `glassAccent` handling the ink the pane can be the app's one glass
      recipe, and the HUD stops being the surface that does its own thing.
- [x] **The glyph keeps its hue; the figure buys the contrast.** Pushing the
      resource icons through `glassAccent` with everything else took the colour
      coding out — a darkened gold and a darkened cyan are two browns. A 16px
      glyph with a distinctive SHAPE is identity and a number is information, so
      the icon is left alone and the value is darkened.
- [x] **And two of the three resource colours were the same colour.** Energy was
      `#57BCFF` and gems `#7FD4FF`: twenty degrees of hue apart, both pale, both
      blue. The constraints are tighter than they look — gold is money and is not
      negotiable, the gem keeps cyan because that is what a gem is, yellow is out
      for energy because that is the coins, green is out because green is the
      chrome half the kits sit on, and orange came out 30° from gold, which is the
      same mistake one hue over. So the bolt is VIOLET: 135° from the gold, 90°
      from the gem, and the one hue no wallet in this game has a claim on.
- [x] **The top HUD has a 10px margin under it — except on Play**, where there is
      no bar for it to separate the page from.

### What the arithmetic caught

- [x] **Our own club name was 2.4:1.** `accentBright` is `#259328` on the default
      kit and the pane composites to about 0.80 — under even the 3:1 large text
      needs, on the most important text on the next-match card. It looked like a
      colour choice.
      The fix cannot be a fixed darker green, because the accent is the player's
      and there are two dozen kits. `glassAccent` DARKENS toward black until the
      contrast clears 4.5:1 against the brightest pane the app draws, and stops —
      so a kit that is already dark is untouched and a bright one comes down as
      far as it needs to. Everything coloured on glass goes through it now: the
      club name, the tactic's hue, the verdict figures, the HUD's numbers. A raw
      hue on a pane is a bug by construction.
- [x] **The ball's bend was always the same perpendicular.**
      `Vector2(-delta.y, delta.x)` never varies, so every ball in every clip
      curved the same way — which does not read as a struck ball, it reads as the
      ball drifting for no reason with nobody near it. Randomised per flight, and
      the styles with no business bending have had it taken off: a square pass, a
      through ball and a cutback go straight.

### The cutaway has an AFTER

- [x] **A goal used to end on the frame the ball crossed the line** — the one
      moment in a match worth watching, cut as it happened. There is an outro now:
      GOAL / SAVED / MISSED goes up (in Flutter, not Flame — a headline wants the
      app's own type and a spring), the scorer runs to the NEARER corner with two
      teammates chasing, everyone in red stops dead, and only then does the pitch
      clear. A miss gets a shorter beat, long enough to read the word.
- [x] **The clock stops while a chance is on the pitch.** It did not, which is why
      the minute lurched: the cutaway takes a second or two and the clock kept
      counting under it, so the passage ended three or four minutes after the one
      it belongs to and the feed jumped to catch up. A chance is a RETELLING of a
      minute — the minute cannot have moved on while it is being retold.
- [x] **Kenney's smoke is in.** Eight frames of the white puff, trimmed to their
      alpha box and down to 128px — 140KB of the pack's 5.9MB — on the strike and
      in the net. The merge burst stays PROCEDURAL and that is not laziness: it
      has to draw in whatever colour the tier is at whatever size the card is,
      which a sprite sheet cannot do. Sprites are for the things that had no
      effect at all.
- [x] **Movers rock foot to foot.** Kenney's top-down characters are a shirt oval,
      a head and two arm stubs — there are no legs in the pack to swap, and the
      modular-character pack's legs are side-on so they would not work here
      either. What a top-down runner actually shows is the body rocking: a small
      roll and a bob, driven off DISTANCE COVERED so a walking figure rocks slowly
      and a sprinting one fast without a second speed to keep in step. They
      already faced their direction of travel.

### The diorama

- [x] **The crowd moves.** Every fan was pinned to its seat and a few hundred
      motionless heads read as a printed backdrop. Each one bounces on its OWN
      phase, so at rest a scattering are up and out of step — and tapping the
      terrace brings the rest to their feet and lifts everyone higher, which is
      the JS's own interaction. Per fan rather than per row on purpose: a stand
      that bounces in unison is a Mexican wave, which is a different thing and
      reads as one. Excitement decays, so a tap is a surge that settles.
- [x] **The manager stopped floating.** The shadow was a fixed 34% ellipse at 4.5%
      of his height — a 7px sliver under a 230px figure, centred on his BOX. At the
      widest point of the stride the rear boot was outside it entirely. It spans
      the FEET now (`_footX(t)` and `_footX(t + 0.5)`, the two legs half a cycle
      apart), is tall enough for its top edge to reach the soles, tracks at HALF
      the feet's offset so it reads as weight moving rather than as a separate
      object being dragged, and is biased left because the figure is drawn side-on
      facing right — its mass sits left of the box's centre while the leading boot
      reaches right of it.
- [x] **The hair is not a block.** See the 21 Aug entry.

### Still open from this session

- [x] **A football on the diorama.** See 25 Aug. `pitch_ball.dart`. The JS runs a small SIM: `.ps-ball` with an
      x-position and a hop, `.ps-ball-spin` for the roll, a shadow that separates
      as it rises, and a `.ps-hold-arm` pose for when the manager picks it up —
      driven every frame and frozen by the same scene-pause gate as everything
      else. There is no ball at all in the port. It is the last thing on the
      diorama that moves and does not exist.
- [x] **More perspective on the manager's turf**, so he reads as further from the
      crowd than he does. The mowing fan already converges; what is missing is
      that HE does not scale with depth and the tuft bands' size ratio is gentle.
- [x] **The manager wants LIFE: a blink, and a tap.** Both in — see 25 Aug. He should blink on his own
      every few seconds, and tapping him should play one of the celebrations the
      save has UNLOCKED — chosen by mood, so an elated gaffer and a crushed one
      reach for different ones. `manager_looks.dart` has the unlock tables and
      `manager_mood.dart` has the five moods; the JS's `GESTURES` table in
      `data/managerMood.js` is the mapping, and `DugoutCam.js` is how it plays
      one.
- [~] **The match popup is missing most of itself** — boxes, tactics, subs, the
      watch-ad buttons. The boxes were already there (`MatchStatRows`, drawn by
      the scorecard), and **the TACTIC STRIP is in**: five buttons under the
      pitch it acts on, each in its own hue, with the JS's one-second cooldown.
      It is the caller `reSimulateRemainder` never had — 350 ported, tested
      lines that re-decide the remaining minutes, keeping every event whose
      minute has passed and counting the baseline from those kept EVENTS rather
      than the scoreboard tally, so a goal whose cutaway is still playing cannot
      be un-scored. Five quests and four achievements read `strategyChanged`,
      `strategiesUsed`, `finalStrategy` and `followedCoachSuggestion`, and until
      now they only ever saw the kickoff defaults — three of those achievements
      were unwinnable.
      **And SUBS are in.** Twenty `match.subs.*` strings translated in ten
      catalogues with nothing able to reach one, `subsUsed` and `subbedOnIds`
      written into every result at kickoff and never moved off zero, and
      `match_use_subs` and `match_sub_scores` — two more quests that could not
      advance. The panel is two lists and one rule; the clock waits while it is
      open, because choosing is not watching; and the kickoff eleven goes BACK
      at full time, so a 70th-minute gamble does not quietly become next week's
      team.
      One deliberate difference from the source: it restores the lineup at every
      full time and refills the bench with it, while this restores only when a
      change was actually made — a save write at the end of every match that
      changed nothing is a write for nothing. The post-match refill of an
      injury's hole belongs to whoever applies the injuries, not to the replay,
      and is worth checking separately.
      **And the LIVE QUEST TRACKER is in**, behind a Commentary/Quests tab pair
      under the pitch. `partialMatchResult` and `liveMatchQuestStatus` are
      ported, documented and tested and had no caller, so the three quests a
      match is being played FOR were invisible until the whistle told the player
      how they went. The tracker reads only the events the CLOCK has shown, so
      it cannot tick a quest off for a goal nobody has watched yet, and it gives
      only the two answers that can honestly be given early: something that
      happened cannot un-happen, and something that can no longer happen is
      gone. Everything else stays undecided — "win by two" is not missed at 0-0
      in the 89th.
      **The INJURY FLOW is in too**: one of ours goes down, the match stops and
      the panel opens by itself with the hole already picked, so a single tap on
      the bench covers it. Nobody is ever subbed on automatically — that is the
      manager's call — so without it a side quietly finishes with ten men
      because the player was reading the feed. The slot is FOUND rather than
      carried: the port's injury event has the casualty's name and nothing else,
      and the sim vacates their slot before the screen opens. One hole is the
      ordinary case and is preselected; with two the manager chooses, which is
      the honest answer rather than a guess.
      Still to go: the watch-ad buttons (M4), and Colin naming the best cover on
      the panel — the `match.subs.injury_tip*` and `best_cover` copy is still
      unreached, and it wants the casualty's instance id on the event.
      **And the SPEED button** is in: the setting decides how a match opens, the
      button is for the moment ten minutes in when the manager has seen enough
      of this one.
- [ ] **A PHYSICS pass, and it wants a real decision first.** The ask is to be
      more creative with a physics engine for the cutaway, the penalty game and
      the character drawing. The honest position:
      **Flame ships no physics; `flame_forge2d` (Box2D) is another dependency**,
      and it is the wrong shape for two of the three. The cutaway and the penalty
      both have an outcome ALREADY DECIDED by an engine that is pinned against the
      JS — `takePenalty` knows whether it is a goal before anything moves — so a
      rigid-body simulation is not a simulation here, it is an animation that must
      terminate in a known state. Forge2D gives you "let go and see what happens",
      which is exactly what neither can have.
      What actually buys the look, without a solver fighting a constraint: solve
      the FLIGHT for the known landing point (the launch velocity and spin that
      reach that corner with that result), then integrate it forward — spin on the
      ball so it turns as it is struck, a parabola that falls properly, and a
      restitution bounce off a post or a bar. A net built as geometry rather than
      as flat art, deformed by the impact point, is most of what sells a goal. The
      keeper falls under gravity from a launch impulse rather than translating. All
      of that is a couple of hundred lines of purpose-built integration and no new
      dependency, and it can be made deterministic — which the outcome-pinned
      design needs and a Box2D world does not give you for free.
      **Forge2D earns its place only where the outcome is genuinely emergent.**
      If a mini-game is ever built where the physics DECIDES rather than
      illustrates, that is the moment to add it.

## From playtesting — 23 Aug

The penalty game rebuilt as a simulation, the weather wired to the actual sky, the
manager's walk rebuilt from the foot up, and a handful of fixes that came out of
each.

### The penalty game

- [x] **It was a coin flip with a picture over it.** Four corner buttons, one roll
      of `keeperSmartChance`, and a read was an AUTOMATIC save — so aim was a menu
      of four and everything else was luck. The scene was a flat photograph with a
      keeper sprite slid across it, which is why a ball could not hit a post, a net
      could not move, a dive was a translation, and three of the shipped outcome
      lines (`penalty.post`, `penalty.crossbar`, `penalty.wide_left`) were
      unreachable copy.
- [x] **`engine/penalty_physics.dart`: real geometry, and the outcome is
      EMERGENT.** A 7.32×2.44 goal, a spot 11m out, a 430g ball; gravity,
      quadratic drag and a Magnus force. One swipe carries three decisions — where
      it finishes is the aim, how far you dragged is the power, and how much you
      HOOKED the drag is the curl. Whether it goes in is where the ball ends up.
      **The keeper is luck, not a verdict**, which is the change that matters: he
      goes the right way with the division's own probability and then still has to
      REACH it.
      **The whole thing balances on one number.** 2.6m of dive plus a 1.05m arm is
      3.65 — the post, to the centimetre. Shorter and the corners are free; longer
      and there is nowhere to shoot. So a perfect corner is only saved by a keeper
      who read it AND went early, and that trade is the difficulty.
      Deterministic, so it is all tested without a widget — 19 cases, including
      that a dropped frame cannot change the answer.
      Three bugs the tests caught, all sign or saturation errors: the post
      reflection drove the ball INTO the post (a rebound came out at 17 metres
      across), the Magnus cross product bent a positive curl left when the field
      is documented as positive-is-right, and a proportional dive under-reached
      every corner — a keeper diving for a corner dives FULLY that way, so it
      saturates at three quarters out.
- [x] **`penalty_view.dart`: the goal is GEOMETRY.** Posts, bar, side netting,
      roof netting and a back net, drawn from the same regulation numbers the
      physics simulates in — which is the only way the picture and the outcome can
      agree. The camera is a pinhole and nothing more, four lines, so the net's
      vertices, the keeper's hands and the ball all project through one function
      and nothing can drift relative to anything else.
      **The four camera values are SOLVED, not chosen.** The ball at rest is a few
      metres from the lens and the goal is twenty-odd, so a lens wide enough to
      fill the frame throws the ball off the bottom of it — which the first set of
      numbers did. Writing out both constraints and solving gives a camera 10m
      behind the spot at 2.6m with eye level near the top of the frame. Move one
      and the other three have to be re-solved.
      **A goal resolves at the BACK NET, not on the line**, which is what lets the
      net be struck and bulge — and it is why the ball is still in the picture,
      in the net, when the word goes up.
      **The net MOVES.** A grid whose vertices are pushed by the impact and spring
      back, soft and lightly damped so it ripples two or three times; edges pinned,
      because a net is tied to its frame.
      **The keeper is a person** — two legs that split as he dives, a torso, two
      arms that both reach, gloves in a different colour from the shirt, a head
      with a face. The dive is a ROTATION of his whole frame, so at full stretch
      he is lying down; three strokes and a circle read as a bollard.
      **The ball is a ball** — a shaded sphere, the real panel pattern, and it
      TURNS at the rate the physics says it is rolling.
- [x] **And two things the rebuild exposed.** The ticker ran unconditionally, so
      the screen repainted the whole pitch sixty times a second to draw an
      identical picture — and worse, a live `Ticker` keeps a frame scheduled
      forever, so `pumpAndSettle` timed out in every test that so much as OPENED
      the screen, including the ones about the gate and the cooldown. It now runs
      only while something is moving. And a `late final` ticker that nothing
      touched until `dispose` was CREATED in dispose, where looking up an
      inherited `TickerMode` is illegal.

### The weather

- [x] **The engine has had a live tier since M1 and nothing ever wrote to it.**
      `weather_engine.dart` reads `state.weather.live` first and falls through to
      a seasonal model — and the live branch has always been empty, so the weather
      over the pitch has never had anything to do with the weather outside.
      `services/weather_service.dart` is the missing writer.
      **No location permission is asked for anywhere in it.** The coordinates come
      from the DEVICE TIMEZONE via `data/geo_zones.dart` (already ported, also
      waiting for a caller), rounded to two decimals — a city, not a person, and
      all the precision a backdrop could use. No key, no signup, no account:
      Open-Meteo is the one that fits because a decorative sky cannot justify a
      credential to rotate or a bill to watch.
      **Nothing in it throws and nothing in it blocks boot.** Offline, DNS
      failure, a captive portal, a timeout, malformed JSON — all the same outcome,
      which is that the seasonal model carries on. A failure backs off for fifteen
      minutes so an outage is not retried every time the Play tab opens, and a
      missing thermometer stores NULL rather than zero, because 0°C is a
      plausible reading and a missing one must not read as a freezing one.

### And the rest

- [x] **A sound that would not stop.** `ReleaseMode` is a platform promise about
      what happens at the end of a clip and it has not held everywhere, so an
      effect could run on. The service passes the clip's own LENGTH to the backend
      now and the backend stops it itself — a sound that will not stop is far
      worse than one that costs a little to start.
- [x] **The manager sits IN his shadow.** The shadow's centre is at the footline
      by construction, but the boot art carries its own sole below it and the
      taller shadow made the difference show. He is sunk a third of the shadow's
      height, which puts the contact through the middle of the ellipse rather than
      along its top edge.
- [x] **Counter Attack's description is fixed at SOURCE.** "ATK and DEF swap as
      play flows" — nothing swaps. Changed in `../merge-empire-fc`'s own `en.js`
      and regenerated, because the catalogue is generated and the JS is where it
      comes from; the nine other locales carry the old line, which is ordinary
      translation lag. The picker's pill was making the same claim — it shows the
      attack multiplier's RANGE now, which is what the tactic actually does.

### The walk, rebuilt from the foot up

- [x] **THE RIG WAS KEYFRAMED AND THE KEYFRAMES WERE WRONG.** Three separate
      complaints — a residual moonwalk, a judder as he put his foot down, and a
      knee that went rigid — turned out to be one cause: the JS's thigh and shin
      angles were played back and the foot went wherever they put it, which was
      not anywhere a foot goes. Measured: over the first 6% of the step the
      planted foot travelled BACKWARDS against a ground travelling forwards (the
      judder), and through the rest of the stance it covered 25.8 units in the
      first quarter and 30.4 in the second — 8% slow then 8% fast against a
      constant grass (the skate). Neither can be retimed out, because the poses
      themselves are wrong.
      **So the foot's PATH is the input now and the joints are solved from it.**
      Ordinary two-bone IK: the law of cosines gives the knee, the angle to the
      target less the triangle's angle at the hip gives the thigh. Stated as a
      path a walk is simple — a straight line at a constant rate while planted,
      which is what "planted" MEANS and the only property that lets the boot and
      the ground agree, and an eased arc while swinging.
- [x] **The ankle rides up over the rolling boot.** It was pinned at ground height
      while the boot rotated about it, which drives thirty degrees of toe into the
      turf at push-off and leaves the heel planted when it should be the first
      thing off the grass. The boot's own corners say where the ankle has to be:
      rotate them and whichever ends up lowest is the bit standing on the ground.
      That also means the contract to test is about the SOLE, not the ankle.
- [x] **The step cannot be symmetric.** The two ends of it are different shapes —
      flat foot and low hip at heel strike, up on the toe with five more units of
      reach at push-off — so a sweep centred on the hip cuts the back half short,
      the knee's slack eats the difference, and the THIGH stays within ten degrees
      of vertical while the calf trails fifty. Which reads exactly as "his legs go
      forwards and never back", because the part of a leg you read is the thigh.
      Each end is solved from the reach available there: 21 forward, 30 back.
- [x] **And he walked in a half-crouch**, because two bones of equal length bend
      `2·acos(reach/total)` — brutally sensitive near full extension, so 97% of
      reach is still a 28-degree knee. Standing him a unit deeper puts mid-stance
      at 99% and the crouch goes with it. `walkerFootline` is derived from the
      ankle height and the boot's sole now rather than being a typed constant that
      could drift from either.
- [x] **Shorts that are shorts.** A rectangle with a 4px radius from the waist to
      the knee, with the legs coming out of its side — and the far leg swinging
      through left its square bottom corner hanging in the air behind him, which
      is the "hip block" that got reported. It is a waistband and a seat that
      curves under now, the thighs are drawn in the garment's colour over bare
      legs so the shorts END mid-thigh, and both hips are centred on it. The kit
      reads as a kit rather than a romper suit, which took THREE tones — the old
      one had shirt, seat and both thighs all within 22% of each other.
- [x] **The elbow was pointing his arm horizontally.** -38 to -68 degrees on top
      of a shoulder swinging to -27 put the forearm at -95 from vertical. Ten to
      thirty is what an elbow does at a walk; anything more is a jog.
- [x] **The head sat four units forward of the body**, on a torso centred at 58
      with the skull at 62. Moved back with its hair, beard, glasses and hat as ONE
      group — the art is all drawn against a skull at 62, so shifting the painted
      head alone slides the face out from under its own hat.

### The grid

- [x] **A merge left a hole and the next card fell into it.** Two cards go in and
      one comes out in the target's cell, so the source's cell empties — and after
      a few merges the grid is a scatter with gaps, where "the next slot" is
      something you have to hunt for. Closed up now, keeping the order the player
      left them in; it is not a sort.
- [x] **And the merged card KEEPS the cell it was dropped on.** The first cut slid
      it to the front of the run, which meant the burst, the pop and the new face
      all happened somewhere other than where the player was looking while a
      NEIGHBOUR bounced into the cell they were watching. It holds its cell unless
      that would leave a gap in front of it, in which case it goes to the end of
      the run — because no gaps is the point. The celebration follows the card by
      instance, not by the drop index.
- [x] **Empty slots carry their own number**, faintly. An empty grid was a field
      of identical dashed boxes with nothing to say how far along it you were
      looking; now that a merge closes the gaps behind it, the first numbered box
      is always the next card's home.
- [x] **A pair the DIVISION will not allow is no longer offered.** `mergesInto`
      only says a card has a next tier at all; whether this division permits it is
      `maxPlayerTier`, which `attemptMerge` checks and refuses with
      `division_locked`. `mergeTargetsFor` did not, so a pair the league would turn
      down wore the gold ring and lit up as a drop target — the grid promised a
      merge and then said no.

### Coach Colin

- [x] **He gave the same advice twice in one window.** The bubble's header already
      reads `COACH COLIN SUGGESTS <TACTIC>`, and the tip pool carried a
      `coach.tactic_suggest` line saying the identical sentence. The pool is for
      what the header cannot say.
- [x] **And that header line is one sentence in three treatments** — caps, then
      sentence case, then title case. All caps now.

### Still open

Ordered by how visible each one is to somebody playing.

- [ ] **The reading is only as local as a timezone.** `Europe/London` is one
      coordinate for the whole UK, so a player in the rain in Manchester gets
      London's sky. IP geolocation would normally fix that to city level with no
      permission prompt — but it was checked against a Starlink connection and
      both providers put it at the London ground station, so it buys nothing for
      satellite users. Accepted as country-level for now; a town picker in
      Settings, using Open-Meteo's own free geocoding search, is the only thing
      that would be exact without a permission.

- [x] **`CoachFloating.js` is ported — he follows you across every tab now.**
      See 24 Aug. `CoachTips.js` (448 lines) is still not: that is the OTHER
      Colin, the one-time educational popups keyed on `state.seenTips`, and it is
      a separate system from the floating head.
- [x] **`CoachTips.js` — the one-time milestone tips.** DONE — `engine/coach_tip_engine.dart`
      and `ui/shell/coach_tip_host.dart`. Sixteen of them, `takeTipOnce` with the
      sponsor offer as its first caller, and `seenTips` finally a ledger with
      something in it. Three things fell out of it: **nothing blocked popups
      during a match** (the welcome-back card could land on the pitch), the coach
      card's `Column` **overflowed** in a loose box and now scrolls, and
      `baselineCoachTips` has no caller because this port has no onboarding
      tutorial — which is stated on it rather than left to be rediscovered.
      Twenty-odd educational
      popups that fire the first time a player hits something (first injury,
      first mergeable pair, no energy, hard mode's fitness bars) and then never
      again: the id goes into `state.seenTips` and stays there until a full
      reset. `seenTips` is in the schema and the migration writes it; nothing
      reads it, so the ledger is a field with no ledger in it.
      Three gates in the JS worth keeping when it goes in: never over the
      onboarding tutorial (`tutorial.done`), never during a match (checks run on
      `match:close`, not `match:complete`), and never over another popup —
      `hasPopupWork()` plus a DOM probe there, and just `hasPopupWork()` here.
      `takeTipOnce` is the seam for a surface that says Colin's piece itself
      instead of having a tip pop up over it.

**The diorama, still.**

- [x] **The football.** DONE — `pitch_ball.dart`, and the fixture is two
      forty-second runs of the real JS with the draws themselves in the file. It
      caught three things: a free ball's velocity has to absorb every change in
      the turf's pace (the JS needs that only at the halt; here the ground
      follows his boot, so it is always on), the JS's countdown lands a hair
      above zero at 48 frames so the first ball arrives on the 49th, and Dart's
      `%` is always positive where the JS's keeps the sign. The last thing on that screen that moves in the JS and does
      not exist here. `pitchBallSim.js` is 791 lines: a ball arrives at his feet,
      and what he does with it is a mood-weighted roll — pass, chip, clear, pick up
      or ignore (`ballPlays` and `_ballPlayWeight` are already ported, with
      nothing rolling them). A carry poses the arm and suppresses gestures; an
      ignore plays a snub gesture as it rolls past.
- [x] **Gestures — the data is all ported and nothing plays it.** Done, 25 Aug. `manager_mood.dart`
      carries all 16 (`fistpump`, `applaud`, `point`, `checkwatch`, `armsfolded`,
      `handsonhips`, `handsonhead`, plus nine look-pack emotes), their weights per
      mood, `gestureGapMs`, `nextGestureDelay`, `pickGesture` with its
      exclude-list, and the `stops` and `fullTime` flags. The keyframes are all in
      `league-scene.css` as `.is-gest-*` blocks — arm and forearm tracks per
      gesture, plus head tilts for checkwatch, handsonhead and bow, a body fold for
      bow and a hard-stepped body for robot. What is missing is the scheduler, the
      poses on the rig, and the tap that plays one.
- [x] **The blink.** Done, 25 Aug.
- [x] **More turf perspective**, so the diorama reads as further from the crowd.
      Done, 25 Aug — `_mowApex` -0.95 to -0.58.

**The match popup and the cutaway.**

- [~] **The popup is missing its boxes, tactics, subs and watch-ad buttons** — the
      boxes were already there, and the TACTICS and the SUBS are both in as of
      21 Aug, along with the live QUEST TRACKER behind a tab pair. The watch-ad
      buttons are M4, and the injury flow that opens the subs panel by itself is
      still to do. See 22 Aug.
- [ ] **Continuous play between chances.** The stage is persistent and the players
      only exist during a chance; the JS runs them between chances too. The hard
      part is the one raised in the request: the ball has to arrive at each chance
      from wherever the last one left it, or it teleports.

**Elsewhere.**

- [x] **The penalty needs a run-up and a striker.** There is somebody taking it
      now: he enters from the left, runs in, plants and strikes, and follows
      through as the ball goes. Seen from BEHIND, because the camera stands
      behind the taker — which is where the shot comes from on television — so
      the last thing on screen is his back.
      Two things it is careful about. The path is in WORLD space and projected,
      so he shrinks as he runs the ten metres to the ball; interpolating two
      screen points would slide a same-sized figure across a converging pitch.
      And **only the BALL waits for him** — the kick is created the moment the
      swipe ends, the keeper's plan is already rolled and a second swipe is
      already refused, so nothing about the physics or the outcome depends on
      the animation in front of it.
- [x] **The keeper could use a save ANIMATION** — the ball is stopped by a reach
      test and then the clip ends. Parrying it away, or holding it, is the
      difference between a save and the ball vanishing. Both are in: a struck
      penalty is PUSHED away — back out towards the taker and off to the side
      the glove met it on, at a fraction of the pace it arrived with, with the
      boot's spin taken off it — and a weak one is GATHERED, riding the hands
      rather than dropping out of them, which would be a fumble and a different
      outcome from the one that was rolled. The simulation keeps running through
      it, which is the point: it used to set the result and return.
      The result is set BEFORE the deflection, so nothing about which way the
      game went depends on the animation. `flightTime` is the new name for how
      long the ball was in the air — the follow-through is time on the clock but
      it is not flight, and the keeper's dive is tuned against the flight.
- [x] **The daily reward** ticks the days already claimed now — and what a day
      pays was always on the tile. See 25 Aug.
- [x] **The five mini-games with no screen** — `training` aside, `keepy_uppys`,
      `through_ball`, `whack` and `pairs` were engine-only. All five built
      21 Aug; all seven drills are playable.
- [x] **Team Names / the pyramid editor** has no screen. Built 21 Aug.
- [ ] **Rate Us, Privacy and Account connection** are waiting on M4 — a store URL
      and `url_launcher`, a consent SDK, and auth respectively. They look broken
      because they are stubs; see 21 Aug.
- [ ] **Kenney smoke, backdrops and more icons** — the merge burst and the
      celebrations should use the particle sheets, and the customiser, training and
      match popups could use the backdrops. See 22 Aug.
- [x] **The rest of the `SheetHeader` sweep** — done 21 Aug, including all seven
      mini-game screens. Coach Colin's card, the achievement banner and the player
      sheet stay exceptions on purpose, and each says so.

## Found while porting — 21 Aug

- [x] **Every AWAY fixture showed the score the wrong way round.** `team: 'home'`
      on a match event means US, whichever ground we are on: the engine builds
      the goal list from the result's own `homeGoals`/`awayGoals` — which are
      ours and theirs, since `won` is `homeGoals > awayGoals` with no reference
      to `isHome` — and it picks the scorer from OUR squad whenever the team is
      `home`. The scoreboard, by contrast, is laid out home-side-left, and it was
      handed that tally straight. Three places read it through `isHome` and all
      three were wrong away from home: our score sat under the opponent's name,
      our goals played the crowd's disappointment, and an away WIN played the
      defeat sting at the final whistle. `MatchFrame` names the two fields
      `ourGoals`/`theirGoals` now, which is what stops it coming back.

## From playtesting — 24 Aug

The weather, drawn. Everything else on this list was in the way of that.

### The sky

- [x] **`resolveCondition` HAD NO CALLERS, and now it has one.** The service
      fetched the reading and the engine turned it into `rain | snow | fog | wind
      | storm | sunny | cloudy | clear` — and all eight looked identical, because
      nothing on screen drew any of them. `lib/ui/screens/home/pitch_weather.dart`
      is the layer: clouds, sun, overcast, rain, snow with its settled cover and
      his boot prints, fog, gusts, and lightning with the thunder behind it.
- [x] **`services/weather_cycle.dart` is the missing scheduler.** Live weather
      HOLDS — it is the player's real sky and not ours to retime, so all the cycle
      does is look again every five minutes. Seasonal weather runs spells: a roll,
      a spell, a clear gap, another roll, with `clear` falling straight through
      because it IS the gap rather than being scheduled twice. Nothing in it draws
      and nothing in it fetches, so the whole schedule is tested with a fake clock
      and no widget — nine cases, including the two that catch a `clear` scheduled
      as a spell and a second `start()` running a second set of timers.
- [x] **ONE PAINTER PER CONDITION, not one node per particle.** The JS builds 30
      drops, 50 flakes and 7 gusts as DOM elements and spends most of its comments
      on the consequences — each has to ride a translating column so the browser
      composites instead of relayouting, `will-change` has to be scoped per
      condition or the GPU pins a layer per drop forever, and `filter: blur()` is
      off the table because it would repaint. **None of that is about weather; it
      is about the DOM.** A `CustomPaint` has no layout to invalidate and no layers
      to pin, so a shower is one painter reading one clock — and the near flakes
      get the soft edge the CSS had to fake.
      **The clock counts SECONDS, not a 0→1 phase**, because the particles in one
      field do not share a period: a drop falls in 0.55s and its neighbour in 1.0s.
      A wrapping controller would have to jerk every particle back to the top at
      once to stay in step with itself.
- [x] **Every layer is in fractions of the scene.** The JS mixes `%`, `px` and
      `vw` and only gets away with `vw` because its diorama happens to be
      full-bleed. A 400pt scene and a 1200pt one have to show the same weather.
- [x] **Nothing ticks unless it is on screen and moving**, which is politeness and
      also the lesson from the penalty screen: a `Ticker` that never stops keeps a
      frame scheduled forever, and `pumpAndSettle` then times out in every test
      that so much as opens the screen.
- [x] **Reduced motion still shows you the weather** — the layers hold still, the
      lightning is off entirely, but an overcast sky is still grey and fog is
      still fog. That is what the stylesheet's own `prefers-reduced-motion` block
      says it wants, and the JS contradicts its own stylesheet here: it gates the
      whole cycle on `_sceneInteractive()`, so under reduced motion it never
      leaves `clear` and not one of those rules can ever apply. The CSS is the
      deliberate half of the disagreement, so it is the half ported.
- [x] **The shower is a curtain BEHIND him, and only the flash goes over.** Not an
      oversight — it is the CSS's z-order (`.ps-overcast` 2, rain/snow/fog/gusts
      3, `.ps-walker` 4, lightning last) and it is right: he is the subject of the
      shot, and a flash that lights the whole ground lights the man standing in
      it. Asserted on the scene's own child order rather than described.
- [x] **The prints ride the ground's period, and the mask is what makes them
      HIS.** They are not spawned per stride: they travel at exactly the speed of
      the grass at his boots, which makes it structurally impossible for a print
      to slide against the pitch — the one mistake here the eye catches instantly.
      Everything from his boot forward is masked out, so a print can only appear
      directly under his foot, and the oldest fade out to the left where the scene
      is dissolving anyway.
- [x] **And a test that renders the layer and counts the ink.** A structural test
      cannot see a silent painter: a gradient with a bad transform, a shader
      anchored to the wrong point, a field placed off the top of the box — every
      one leaves the layer present, at full opacity, drawing nothing. It caught
      two things. The alpha has to be SUMMED rather than counted, because a veil
      touches every pixel with a little and a count saturates; and every layer is
      keyed, so a second capture in one test photographs the sky it was comparing
      against unless the fade is pumped through first.

### Where the cycle is started, and why it is not started by the screen

- [x] **`GameHost` starts it, not the first widget to watch it.** The JS runs its
      cycle off `LeagueScreen`'s mount, and the obvious port is a provider that
      arms itself when a screen reads it. It does not survive contact with the
      suite: `flutter_test` asserts on pending timers while the tree is STILL
      MOUNTED, so a spell timer armed on first watch failed every widget test that
      built the home tab — fifty of them, every one about something else. The host
      is the port's answer to "the app is actually running", and it is the only
      thing that should own that.
      Two smaller versions of the same lesson: `ref` is unusable once a widget is
      disposed, so the notifier is held rather than read in `dispose` — and the
      first turn emits immediately, which Riverpod refuses inside a widget
      lifecycle, so the start rides the post-frame callback that was already there
      for the boot notify.
- [x] **The periodic refetch went with it.** The JS asks for a fresh reading from
      inside the cycle; here `refreshWeatherForGame` is called from the host at
      boot, on resume and every five minutes, because a network call wired to
      something a screen watches is an HTTP request and a scheduled save in every
      widget test that builds that screen. One function rather than one per
      caller: the timezone, the region and the save hook are three chances for
      three call sites to disagree about what a reading is for.

### Still open from this session

- [x] **`windAccelFor` HAS A READER NOW.** The stray ball is it — a gale
      visibly carries a clearance or a throw and leaves a rolling ball alone,
      which is the JS's own rule and not a simplification. Was: nothing reading it, and cannot until the stray
      ball exists — see the diorama's football, below. The wind is on screen; what
      it would push is not there yet.
- [x] **He is visibly suffering now, which is the other half of the weather.**
      `comfortFor` was the last unread link in a chain that was otherwise
      finished: the service reads the sky, the engine estimates the temperature,
      and that gets compared against how warmly the player dressed him. Two
      things were missing.
      **`garmentWarmth` was not ported at all.** It is in `data/manager_looks.dart`
      now, pinned against node over every outfit crossed with every hat — 93
      combinations, because the arithmetic is three lookups and the interesting
      part is which ids are MISSING from each table. A cap or a crown is not
      insulation, so a manager in shorts and a baseball cap is still visibly
      freezing; the santa hat is wool, so it counts. **A stored `neck` is ignored**
      — `neckForLook` derives the scarf from the beanie, because a save from when
      the scarf was its own choice had one and no longer any control to take it
      off.
      **And the rig had no poses for the answer.** `_Comfort` in
      `manager_walker.dart` is the JS's `.psv-chill` and `.psv-swelter`: a cold
      pallor over the whole head with two breath puffs on the same path offset
      into a rhythm, or a flushed cheek and brow with sweat running off the
      temple. **The puffs are what read at this size** — a tint on its own looks
      like a lighting change.
      **Nothing here dresses him.** The player picks the clothes and the game
      reacts to how well they suit the day, which is why a coat in February is
      `ok` and the same coat under a visible sun is `hot`: `estimatedTempC` floors
      a sunny sky at `sunnyC`, so the scene and the thermometer cannot disagree
      about a sky the player can see.
- [x] **Its own clock, and only while it is needed.** A breath is 2.6s against a
      stride of 1.45–2.3s, so a phase taken off the walk clock would cut every
      puff off in the middle of itself. The tremble DOES ride the walk clock,
      off its elapsed seconds rather than its 0→1 — the stride retimes with his
      mood, and a phase from the fraction would have him shivering faster when he
      was pleased.
- [x] **The tremble stops under reduced motion, which the JS does not do.**
      `.psv-tremble` is in the stylesheet's PAUSED block and missing from its
      reduced-motion one, which reads as an omission rather than a decision: a
      130ms strobe is exactly what that setting exists to stop. Gated on whether
      he is walking at all, so a frozen clock cannot leave him sitting a third of
      a unit to one side either — a permanent lean rather than a shiver, which is
      what the first cut did.
      Tested on his LEGS, where neither the pallor nor the flush paints: any
      difference down there is the whole body having moved, which is the only
      thing the shiver does.


### Coach Colin, on all five tabs

- [x] **HE EXISTED ON ONE SCREEN OUT OF FIVE, AND THE CATALOGUE HAD 120 THINGS
      FOR HIM TO SAY.** `coach.*` is a hundred and twenty generated strings and
      the port read four of them: the tactic call on the Play tab's dock orb. The
      whole per-tab pipeline — `computeCoachTip` and the five functions under it —
      had no caller at all, so on Players, Squad, Club and Shop he did not exist.
      `ui/shell/coach_tips.dart` is that pipeline and `ui/shell/coach_floating.dart`
      is the surface it goes on.
- [x] **The pool is tab-scoped and nothing crosses over**, which is the JS's own
      decision and worth restating: a coach who says the same thing on the squad
      screen as on the shop shelf is a banner. Order inside each pool is priority
      — health, then age, then form, then money — so an injury outranks a merge
      and a merge outranks a nudge about scouting.
- [x] **`tPoolStable`, because the sentence must not reshuffle.** Dozens of
      catalogue entries are `|`-separated pools and `tPool` picks at random, which
      meant a different line on every rebuild. The JS seeds the pick on the thing
      the tip is ABOUT — the season, the division, the squad size — and its own
      comment records what happens otherwise: the Shop's seed was once the coin
      balance, so it reshuffled on every idle tick and made his head flash. Same
      32-bit hash as the JS, so both runtimes pick the same line out of the same
      pool.
- [x] **A dismissal MUTES the tip; it does not close a window.** Ten minutes for
      most of them, a day for the ones about a decision rather than a moment (a
      veteran is still in his final season ten minutes later), and `priority` tips
      ignore the mute so an urgent signal still gets through. Kept in the save at
      `ui.coachDismissals`, which is what makes a "not now" survive a restart the
      way a player would expect.
      **And asking is not writing.** The first cut created the ledger branch on
      read, so every build left a `coachDismissals: {}` behind and the save was
      dirty for having been looked at.
- [x] **The home tab shows nothing, on purpose.** His orb already carries him
      there, and a floating head over a screen that has him on it is the same
      coach twice — which is exactly what the JS's `setEnabled` gate is for on its
      League > Overview sub-tab.
- [x] **The REF-COUNTED suppression is not ported, because there is nothing left
      for it to do.** The JS appends the head to `document.body` at `z-index:
      20000`, so every modal in the app has to tell it to step aside — and a count
      rather than a flag, because a sheet can open a sheet and only the last close
      should bring him back. All of that is bookkeeping for a decision the DOM
      made on its behalf. Here he lives in the shell's own `Stack` below the
      `Navigator`, and every popup in this app is a route, so a modal covers him
      by construction. Porting the counter would have been porting a workaround.
      A first cut kept `hasPopupWork()` as the one non-route case; it went too,
      because it is read at build time with nothing listening to it — a check that
      cannot notice the thing it is checking for.
- [x] **And a reachability test that starts at the shell**, not at the widget:
      open the app, tap Squad, find the head. The rule this repo learned the hard
      way is that constructing a thing proves it works and says nothing about
      whether a player can get to it.

### Still open from the session

- [ ] **The league sub-tab pools have nowhere to go yet.** `coach.table.*`,
      `coach.fixtures.*`, `coach.minigames.*` and the per-sub-tab
      `coach.cup_due.*` / `coach.low_energy.*` lines belong to what the JS has as
      League sub-tabs and the port has as SHEETS — and a sheet is a route, so it
      covers him. They want an inline coach inside those sheets rather than the
      floating one, which is a design call before it is a port.

## From playtesting — 25 Aug

The manager redrawn, the HUD made readable in daylight, and the gesture rota
running at last.

### The figure

- [x] **THE MOTION WAS NEVER THE PROBLEM; EVERY PART OF HIM WAS A PRIMITIVE.**
      Limbs were round-capped lines of constant width, the torso a 15×32 rounded
      rectangle, the boot another rectangle, the head a circle with an ellipse for
      a jaw. Constant-width sausages on a rounded brick is programmer art however
      well it walks. `ui/screens/home/walker_figure.dart` is the form layer:
      tapered limbs with a highlight inset from the leading edge and an occlusion
      at each socket, a torso silhouette, a boot with a heel and a toe, and a neck
      — which did not exist, so the skull sat straight on the shirt.
- [x] **The torso's width was not a choice — the generated art already stated
      it.** Every outfit overlay in `manager_art.g.dart` is a full garment
      silhouette running x 47.8 to 69.9, so the coat and the suit have always
      drawn a body 22 units across. The hand-drawn shirt under them was 15.7,
      which is exactly why he read as a stick in the plain kit and as a person the
      moment you put a coat on him. Reading the art rather than guessing at a
      build is the same lesson the CSS keeps teaching.
- [x] **The arm reached the waistband**, which is a child's proportion — the hand
      hung level with the hip. It goes to mid-thigh now.
- [x] **The nose had a line through it.** It was its own slightly-lighter sliver
      drawn over the face, and a two-point curve closed with a straight edge — so
      the closing edge ran down the middle of the cheek as a visible seam. A nose
      is a bump in the PROFILE; it is part of the skull path now and there is
      nothing left to see.
- [x] **Nothing moved a pivot**, and that was the constraint throughout: the
      shoulder is still (56, 62), the elbow (56, 80), the hips (58±2, 95), the
      skull a circle at (62, 48.5) r12.5. The gesture poses rotate about those and
      every generated hat, hair and outfit is drawn against them. The geometry
      tests are what caught it each time the redraw drifted.

### Coach Colin's gestures, finally playing

- [x] **`manager_mood.dart` has carried all sixteen since M1 and nothing ever ran
      the timer.** Weights per mood, `gestureGapMs`, `nextGestureDelay`,
      `pickGesture` with its exclude-list, the `stops` and `fullTime` flags — all
      ported, all tested, and he just walked. `gesture_poses.dart` is the poses,
      `home_screen.dart` runs the rota, and a tap on him jumps the queue.
- [x] **A joint a gesture does not mention KEEPS WALKING**, which is the CSS's
      semantics rather than a simplification: `animation` on `.psv-armN` replaces
      the walk for that element and leaves its siblings alone. A fist pump is one
      arm; the other arm swings on. Every track is nullable and null means the
      walk still owns that joint.
- [x] **He plants his feet for the bow and the world stops with him.** He walks in
      place while the scene scrolls, so a stride that stops without the scroll
      stopping is a man standing still on a conveyor belt. The crowd is
      deliberately NOT frozen with it — a stand that stopped dead because the
      manager paused to bow would be stranger than one that carried on.

### The HUD in daylight

- [x] **Four of the bar's colours went onto the pane raw**, and `glass.dart` says
      in as many words that "every coloured thing ON glass goes through this — a
      raw hue there is a bug by construction". The figures, the cog and the energy
      ladder are ramped now, and the cap beside the energy figure uses
      `glassMuted`, whose own doc names "a progress fraction": it was the figure's
      colour at 60% alpha, and that colour is already at the edge of legibility,
      so `11/10` read as `11` and a smudge.
- [x] **But the WALLET ICONS are not ramped, and that is the interesting half.**
      You cannot fix a bright hue by darkening it. Yellow is intrinsically light —
      taking gold to 4.5:1 against a near-white pane lands on `#665600`, a dark
      olive that reads perfectly and is no longer money. Their hue IS the meaning
      and their separation from each other is the whole reason those three were
      picked, so the hue stays and the backing changes: a soft dark halo under the
      glyph in daylight, and nothing at all at night, where the vivid hues were
      chosen to sit.
- [x] **Asserted as a ratio rather than a screenshot.** A widget test renders
      icons as tofu and text without fonts, so a picture of this bar proves
      nothing. `paneContrast` and `paneContrastTarget` are public now, so the test
      measures through the app's own model instead of restating the formula and
      drifting from it — seven kits, every step of the energy ladder, and both
      panes.

### Still open from the session

- [x] **THE INCOMING BIDS — here is the fault, and it is fixed.** The card FAKED
      Colin's chrome: an emoji, his name, a title, no portrait and three
      uncoloured buttons — exactly the fault the sponsor offer had before it was
      fixed, and the JS's own note says both render in his card. It is his frame
      now, with Park / Decline / Accept coloured for what each does, and it takes
      its one-time explainer through `takeTipOnce` like the sponsor does. Was:
      the specific fault is not written down yet, so this was a placeholder with
      the surfaces named rather than a diagnosis. What exists: `maybeGenerateOffer` in the transfer
      engine, `transfer_offer_card.dart` for a rival's bid on one of ours,
      `sponsor_offer_card.dart` beside it, and the incoming list Deadline Day
      reads at `deadline_day_view.dart`. The 19 Aug notes already record that the
      engine half had no caller once and that an unanswered bid times out after
      five minutes. **Next step is to write down what actually looks wrong** —
      whether it is the card, the timing, the queueing against other popups, or
      the arithmetic in the offer itself.
- [x] **THE WALK IS THE JS'S OWN AGAIN, and the port's IK is gone.** Solving the
      legs from the foot's path is measurably better and looks worse. Three
      reports in a row said so and each named a symptom of the same thing: he
      lunged (it solves for the longest step the legs allow — 48 units), he
      crouched (40 degrees of knee on the leg he was standing on), and he pointed
      his toe at the end of every step (the boot's angle solved against the ground
      rather than following the shin).
      **What the eye reads is a STRAIGHT leg to stand on.** The JS's shin track
      stays inside 13 degrees through the whole stance and folds to 60 only to
      swing through, and its stride is actually LONGER at 59 units — so the
      complaint was never really about stride length. `psvThighN/F` and
      `psvShinN/F` are transcribed and played; the ankle comes out of them by
      forward kinematics.
      **Its lengths too**: the shin is 24, not 30. The JS's shin rect runs
      y126→150 against a thigh of y96→126, and the port had both at 30 — six units
      of extra leg, which is part of why he read as long-legged and small-headed.
      **And its bob, unchanged.** Deriving the bob from the supporting foot gives
      an exact contact at every frame — no float, no skate — and it reads as
      BOUNCING, because the JS's angles were never drawn to sit on a flat floor and
      the correction is seven units against a bob of four. Tried, reported, and
      reverted; the note is in the code so it is not tried again.
      **The two flaws are now pinned as ACCEPTED** rather than left to be
      rediscovered: the planted foot's rate varies by ~5.6 units across the stance
      (the skate) and its sole by ~5.2 (the float).
- [x] **HANDS ON HIPS LANDS ON THE HIP NOW, and it is the one pose that is
      SOLVED rather than transcribed.** The JS's 44 and -106 put a hand on a hip on
      the JS's arm and not on this one: the redraw relengthened it, and the same
      angles left the elbow at x 42.8 — five units outside a back that stops at
      47.9 — with the hand at (60, 85), the middle of his belly. Two-bone IK onto
      (65, 89) and (63, 90) instead, which is the top corner of the shorts each
      side. **A pose is a place a hand goes**, and when the limb it hangs off
      changes length the numbers have to as well.
- [x] **The arms were STUCK, and it was a real bug rather than a look.** The
      gesture clock only ever runs forward, so when it stops it stops at 1.0 — and
      the pose getter treated only 0.0 as "nothing playing". From the first gesture
      of a session onward the pose was still being read at progress 1.0, which is
      every track's REST value: the arms pinned at 27 and -52 and never swung
      again. `isAnimating` is the whole question.
      Also: a gesture handed in at MOUNT never played, because the start only ran
      from `didUpdateWidget`. Invisible in the app, where the rota always arrives
      after the first frame, and it made the poses impossible to render in a test.
- [x] **The head is UP when it is going well and down when it is not.**
      `moodHeadTilt` — seven degrees of chin up when elated, twelve of chin down
      when crushed. The cheapest acting on the figure and the one that reads
      furthest, because the mouth is four pixels across on a phone.
      **It is a baseline and a gesture ADDS to it**, so a beaten manager who points
      at the far post lifts his head from wherever he was carrying it and is handed
      back to it afterwards — `_chinUp` on the outward gestures. All three head
      layers share one angle, or the face slides out from under its own hat.
- [x] **He blinks.** Its own five-second clock, twice per cycle at an uneven
      spacing, because a metronome blink is its own kind of dead. **Clipped to the
      eye**: drawn straight, a skin-coloured lid on a shaded face is a sticking
      plaster, which is exactly what the first cut looked like.
- [x] **Pointing shows the finger**, which the JS shares across all three of its
      pointing gestures (`psvFingerShow`) and the port had no finger at all for. A
      point with no finger is a fist held out at the pitch. Hidden the rest of the
      time — at this size a permanent finger makes the hand read as a mitten.
- [x] **And there is a watch on the near wrist**, without which checking it is a
      man staring at his own knuckles.
- [x] **THE BUZZ CUT IS SCALP SHADING, NOT HAIR, and the generator was treating it
      as hair.** The JS draws it as ONE path at `opacity: 0.42` — the shape hair
      would occupy, tinted, and nothing else, because that is what a buzz cut is.
      `gen_manager_art.mjs` adds three passes to every style — a lit rim, an
      outline and two crown strands — and on a buzz cut that is an outlined blob
      with a swoosh across it: a cap of hair drawn on a shaved head. The passes
      exist to make a MASS of hair read as hair and there is no mass here, so a
      `SCALP` set skips them. Fixed in the GENERATOR and regenerated, per the rule.
- [x] **A neck, and the head lifted to make room for one.** It existed and could
      not be seen: the skull's underside sat four units INSIDE the shirt, so the
      neck was hidden between them and the head read as resting on the collar.
      Seven units of lift puts the chin three clear of the shoulder line. The whole
      GROUP moves — hair, beard, glasses, hat and skull together.
- [x] **THE "EAR THAT LOOKS LIKE AN EYE" WAS NOT THE EAR.** It was the FAR EYE — a
      pale oval with a dark dot at x 59.6, drawn as "a hint of the eye on the other
      side of the head". On a head seen side-on there is no other side to see, and
      x 59.6 is precisely where an ear belongs, so what it read as was a small
      second eye stuck where his ear should be. Deleted; the ear went there instead.
      **And the ear is a C with no fill.** Three attempts: a flat disc with a
      smaller dark disc inside it, then a filled teardrop with a dark crescent
      inside it — and a pale blob with something dark in the middle is an EYE, which
      is what both read as. There is no interior left to mistake for an eyeball now,
      just a thin stroked arc opening FORWARD, the way he faces.
      Three more things it took: **drawn AFTER the skull**, because an ear halfway
      along a profile is in front of the outline and the old
      draw-it-behind-and-let-the-edge-peek trick showed nothing at all in the
      middle of the head; **small**, since the first C at 5.2×7.6 with a 2.2 stroke
      was a third of his face; and **back from the skull's own centre**, because
      the visible head's middle sits forward of the circle's — the nose and face
      stick out past it.
- [x] **A LIFT ONLY BRINGS HIM UP TO LEVEL.** Adding the mood baseline and the
      gesture's head track blindly meant a manager already looking straight ahead —
      or up, when it was going well — raised his chin FURTHER to point at
      something, and ended up addressing the sky. A gesture that looks DOWN still
      adds (a beaten manager checking his watch looks further down than a cheerful
      one, which is right); a gesture that LIFTS is capped at the horizontal and
      does nothing at all to a head that was not down.
- [x] **The crowd answers a celebration.** `manager_mood.dart` already marks which
      of the sixteen gestures are worth getting out of your seat for, and the stand
      already had an excitement surge that decays — but only a TAP on the terrace
      could trigger it, so the one thing on the screen most worth cheering could
      not. A fist pump or a wave at the terrace now surges it. Identity rather than
      a flag, so two fist pumps in a row are two surges.
- [x] **THE TURF RECEDES HARDER AND THE STADIUM CAME DOWN WITH IT.** `_mowApex`
      -0.95 → -0.58, which is the strength of the perspective: a ray's travel per
      radian is its depth below the apex, so pulling the apex closer shortens every
      distance and widens the gap between them. The near row ran 1.38x the far one;
      it is 1.60x now, and the surface reads as going away from you rather than as
      a green band with lines on it.
      That is what paid for the horizon: `_horizonAboveBoots` 0.72 → 0.55, so the
      terrace sits in the middle of the picture where it can be looked at instead
      of being a strip along the top. **It cost nothing in scale** — his size is
      about his own contact line, so the horizon cannot change how big he is.
- [x] **The mown bands are fatter** — `_mowPeriod` 5.2° → 7°. The lanes are
      angular, so the period widens all of them; at 5.2 they read as a texture on
      the grass rather than as mown bands. `mowDuration` solves the sweep against
      it, so the grass at his boots keeps its speed.
- [x] **And he is smaller: `walkerScale` 1.35 → 1.22.** 1.35 was the settled middle
      when the terrace was a strip along the top and he was the only thing on
      screen with detail on it; with the stand in the middle of the picture he was
      competing with it. The ground speed follows him, so a smaller man takes
      smaller steps and the grass slows to match.
- [x] **THE TUFTS WERE MOONWALKING BY 17.7%, AND HAD BEEN ALL ALONG.** Checked
      rather than assumed, which is the only reason it turned up: the bands carried
      ratios measured against BAND 0, and band 0 is not the row the ground's speed
      is defined at. That row is his contact line — lower down the box and further
      below the apex — so the whole tuft layer ran 17.7% slower than the mown
      stripes it grows in, at every band, on every screen. A tuft is a clump of the
      same grass the stripes are mown into; if it slides against them both layers
      stop being ground and become wallpaper.
      `turfScroll` replaces the ratios: every strip on the turf — three tuft bands
      and the hoardings — is solved against HIS row, the same row `mowDuration`
      solves the fan at. The test asserts the ratio of each layer's speed to the
      fan's at its own row is 1, so a future change to the perspective cannot
      desync them; the old test pinned the two constants and would have failed for
      the wrong reason.
- [ ] **The play button's pop is matched but unverified.** The JS's `.play-match-btn`
      is a 1px white rim at 55%, a bevel (`inset 0 1px 0` white 55%, `inset 0 -2px
      0` black 22%), a sheen and THREE shadows — and its own comment says why:
      "the diffuse far shadow alone reads as a glow; what actually lifts a button
      off the pitch is the tight contact shadow right under its edge". The port had
      the far pass and the glow only, plus a heavier 2px rim and a dark outer ring
      that the JS does not have. All four are in now; nobody has looked at it on a
      device yet.
- [x] **THE GROUND MOVES AT THE FOOT'S OWN RATE NOW, and no constant speed ever
      could.** Reported as the feet going backwards slightly faster than the grass.
      Measured: the JS's tracks are linear in ANGLE, so the supporting ankle's
      horizontal rate swings from -17 to +173 art units per cycle across a single
      stance while a constant ground sat at 119 — 45% slow at mid-stance, briefly
      going the wrong way at heel strike. The slip is in the POSES, not the speed,
      and raising the average only makes the rest of the cycle too fast.
      `groundEase` is the integral of the supporting boot's own velocity, and
      `_GroundDrive` hands that one distance to every layer on the turf. A strip
      driven by it is stationary under the planted foot at every instant, which is
      what "planted" means and the one property a solved rig gets for free.
      **Three things it took, and two of them were errors of mine.** The layers had
      to stop owning a clock each — a `% segmentWidth` off a clock with its own
      period jumps every time that clock repeats, so a shared VARYING rate is
      impossible until they all read one position. The scale had to be the SUPPORT
      foot's distance (51.83) rather than the near ankle's nominal stance (53.05);
      the foot carrying him changes hands part way through, and scaling by one while
      warping by the other smears 2.3% across every step. And `groundSpeedTrim` went
      back to 1: at 1.12 it was covering for the varying rate, which is now matched
      outright.
      Worst residual slip is under 25 units/cycle against 78 before, and all of it
      is the deliberate clamp — the support foot really does creep forward either
      side of each hand-over, and a world that never reverses is better than one
      that judders.
- [x] **(superseded) The ground ran 12% faster on a named trim.** Reported as still
      slightly moonwalky. Measured rather than nudged: the near sole only genuinely
      touches the grass for about 15% of the cycle and floats a couple of units for
      the rest, so "the speed of the planted foot" is a RANGE — 99 to 106 art units
      per cycle, from the travel across the tightest contact window up to the net
      displacement across the nominal stance. The stride the ground was solved from
      already sat at the top of that range and still read slow, so `groundSpeedTrim`
      lifts it above the range's own ceiling.
      A contact-weighted average was tried as the principled alternative and
      abandoned: widen the weighting and the SWING foot begins cancelling the
      planted one, so the answer walks from 84 down to 17 depending on a tolerance
      nobody can justify. There is no number to derive here — that is the flaw the
      JS's poses were knowingly taken with — so it is a trim, it is documented with
      the range that bounds it, and it sits in `groundSpeedPxPerSec` where every
      layer on the turf reads it through `turfScroll`. **If he ever reads as
      dragging his feet again, that constant is the one thing to move.**
- [ ] **Nobody has seen the play button, the crowd surge or the ear on a device.**
      All three are in and all three are unverified by anything but arithmetic and
      a widget test: the button's bevel and three-tier shadow, the stand's surge on
      a celebration, and the ear as a thin unfilled C. Worth one pass through the
      Play tab with an eye on each.
- [x] **The gesture halt is a hard stop, not a ramp.** DONE — `walk_ramp.dart`.
      **And the halt never ENDED**: the scene read `_cue.gesture.stops`, the cue
      is never cleared, so the world stopped for the bow and stayed stopped until
      the next gesture happened along — up to sixteen seconds of a man standing
      on a pitch that was not moving, his own clock stopped with it because
      nothing called `_sync` when the gesture finished. **And there is one clock
      now**: his legs and the ground each owned a ticker, kept together only by
      both starting in the same frame and every stop restarting both from zero,
      which an ease cannot survive. Was: The JS eases the walk, the
      strips and the ball down to zero over ~0.4s (`_rampWalk`) because
      `animation-play-state` cannot express anything between running and stopped.
      Here the walk clock and the turf simply stop together. One gesture in
      sixteen has `stops`, so it is one abrupt halt on one celebration.
- [x] **And the BACKGROUND never stopped with him.** The halt above reached his
      legs and the turf, and stopped there: the stand, the floodlight pylons and
      the advertising boards each ran an `AnimationController.repeat()` of their
      own, so a man came to rest in front of a stadium that was still sliding
      past him. The comment on the strip said as much and thought it was a
      reason — "they are not ground and have no foot to agree with" — but a
      terrace is not self-propelled either; it moves because HE does. What a
      free-running controller cannot do is vary its rate, which is the whole
      requirement once the world can ease to a stop.
      `parallaxOffset` converts each strip's old loop period into a distance off
      the walk clock, so **every speed on the scene is unchanged and all of it
      stops together** — pinned by a test, because a strip that halts and then
      crawls is the next bug. `_Scroller` owns no clock at all now and takes its
      offset as required, so the next strip somebody adds cannot repeat this.


## From playtesting — 26 Aug

Reported from the couch, in the order they were noticed. Nothing here was found
by a test.

### The Play Match screen

- [ ] **The top card should be the NEXT MATCH CARD from the home page.** It is
      the same fixture, described twice in two different shapes — and the home
      page's version is the one that got the design work.
      `lib/ui/screens/home/next_match_card.dart` against whatever the match
      screen puts up now.
- [ ] **The commentary needs to look better, and it should carry the
      GOALSCORER'S FACE.** A goal line naming a player, next to the art of the
      player it names — the portraits are already bundled and already resolved
      by `playerImagePath`, so this is a feed row that knows who it is about
      rather than a string.
- [ ] **The dugout camera is missing.** In `../merge-empire-fc` — read it before
      building anything, it is the spec.
- [x] **THE GOAL LANDED ON THE SCOREBOARD BEFORE THE 2D PITCH SHOWED THE MOVE.**
      The number told you the answer and the animation then explained what you
      already knew. The score and the feed were in lockstep with each other —
      `frameAt` counts goals from events already SHOWN, which was the point —
      but both ran ahead of the cutaway.
      **Where the clock is and what has been TOLD are two questions**, and
      `frame` answers them separately now: the minute and `finished` stay on the
      clock, while the tally and the feed are counted to the minute before the
      one being retold. It holds for a chance and an injury too, and it should —
      "forces a save" is no better read before you watch the save.
      Note for anyone testing near this: a clip cannot be driven to its own end
      in a widget test, because the stage is a Flame loop and a Flame loop never
      settles. `skipToEnd` is the path that clears one.
- [x] **Ghost hits — the ball moved with nobody in the position.** Nothing to do
      with the lineup: the cutaway builds its cast from the SCRIPT. The bug was
      that the two halves disagreed. `_attackerStarts` created a body only for a
      pass that named a `run`, while every pass was still assigned a receiver —
      and the index landed on whoever was nearest the end of the list, which is
      very often the man doing the passing. He was then told to run onto his own
      pass, so the ball crossed the pitch to empty grass and waited there for
      him. `tiki_box` was one man passing to himself three times, and
      `through_center` did it on beat 2.
      `castFor` is one pure function answering both halves now — a body per pass
      and the receiver index for each — so they cannot disagree. A bare pass
      gets its receiver placed `_receiverLag` back from the ball, because the
      point of the `run` field is that he runs ONTO it rather than standing on
      it. Two invariants over every shipped sequence: nobody passes to himself,
      and no receiver starts on the ball.

### The squad page — rolling a trait

- [x] **The STATS DID NOT CHANGE when the trait rolled**, and it was not the
      roll: the sheet's rating came from `getCardRating`, which is the
      DEFINITION's rating plus a merge bonus and knows nothing about traits,
      aging, form or sponsor. `getCardStats` is the documented single source of
      truth and folds the trait's directional bonus back into the overall — so
      the one number a roll is bought to move was the one number that could not
      move. ATK and DEF are on the sheet now as well, because the bonus is
      directional and on the overall alone a Finisher III reads as three points
      from nowhere. (Those two labels are literals, as they are in the source —
      `SquadScreen.js:372` and `Card.js:34` have no key for either.)
- [x] **The text above the spinner GAVE THE ANSWER AWAY.** The badge reads the
      save, and the roll writes the save BEFORE the reels move — deliberately,
      because a spin that decided at the end would have to be unwound when the
      debit was refused. So the answer sat printed over a wheel still pretending
      to decide it. The old trait is held for the length of the spin now, behind
      a flag rather than a null, because "nothing" is what most first rolls
      start from.
- [x] **And the spinner was too quick** — 900ms is a flick. 1.9s over five
      revolutions, and the ease-out makes that read as slowing down rather than
      as waiting.

### The penalty shootout

- [x] **THE KEEPER'S AND THE TAKER'S LIMBS STRETCHED like the Fantastic Four.**
      Two faults, and the measurements are in `penalty_view_test.dart`.
      A LIMB GREW: the keeper's leading arm ran 0.40 to 1.35 units across the
      dive while the trailing one halved, and the taker's kicking leg went 0.80
      to 1.05 right at the strike. Every segment is a fixed length at an animated
      ANGLE now, which is what a joint is.
      And HE WAS IN THE WRONG PLACE: the figure sat at `hand.x * 0.42` with the
      arm drawn to a body-relative offset, so the drawn glove was 1.3 to 2.4
      METRES from the point the save was decided at.
      **`keeperHand` is the CENTRE of his reach, not a fingertip** — whatever its
      name says, `_keeperGotIt` tests against it and then allows another
      `keeperReach` on top, and `_parry` calls it "the centre of the gloves". So
      it is his chest: `keeperRigFor` anchors him there, the arms are
      `keeperReach` long so the sweep on screen IS the circle in the maths, and a
      gathered ball ends up pinned to his chest, which is where a keeper holds
      one he has caught. The taker is anchored on his PLANT BOOT, because that is
      his contact with the turf.
      Both rigs are pure functions returning screen-space joints, so the figure
      that is drawn is the figure that is tested — fifteen cases over five dive
      angles, four extensions and three heights.
- [ ] **And the hand FREEZES at full stretch.** `_moveKeeper` clamps its
      extension, so for the whole save follow-through the arm is a statue while
      the ball loops away — and a GATHERED ball hangs motionless in mid-air for
      0.35s, which is the same "ball vanishing" defect the parry was written to
      kill, moved from the ball to the hands. He should land, and the ball he
      caught should come down with him. Measured: catch at t=1.15, and ball and
      hand both sit at exactly (0, 0, 1.00) until the clip ends.
- [x] **The aim line is dotted, and the dashes MARCH toward the goal.** A solid
      curve reads as a target; the same curve with movement in it reads as a
      shot, which is the part the preview was not saying. `dashedPath` is pure
      and tested — path arithmetic is easy to get subtly wrong and impossible to
      see — and the ticker now counts a drag as live, since it is the one thing
      on that screen that moves while the ball is still on the spot.
- [x] **OFF THE FRAME AND IN.** Both frame contacts reversed the ball's FORWARD
      velocity outright and parked it back outside the line, so anything that
      touched the frame came out — while the one thing everybody knows about a
      crossbar is that a ball can come down off it and go in.
      A bounce is a REFLECTION about the surface that was hit, and the same three
      lines give both answers: rising into the underside of the bar reverses the
      CLIMB and keeps the forward pace, so it drops in; clipping the top reverses
      it upward and it goes over. Inside half of a post sends it into the net,
      outside half sends it away. Measured bands, for anyone retuning it: bar in
      at lift 0.74–0.79 and out from 0.80; post in at across −0.80 to −0.77 and
      out at −0.83 to −0.81.
      Each part can be struck ONCE — the reflection leaves the ball moving away,
      but a ball re-crossing the line at bar height every step would hammer the
      same upright until the clock ran out. And the belt-and-braces "anything
      behind the goal is a goal" now asks whether it was ever INSIDE, because a
      ball off the top of the bar is behind the net without having been in it.
- [x] **He spreads himself better further up.** The read chance was the ONLY
      ramp, so a Champions Cup keeper guessed as badly as a Sunday League one and
      simply guessed right more often. `keeperReachFor` is the second ramp, and
      the plan/reach split is the point: the plan is his DECISION (which way, how
      early) and the reach is his ABILITY.
      **It ramps DOWN from the top rather than up from it.** `keeperDiveSpan`
      plus `keeperReach` is the post to the centimetre and that is the number the
      whole balance rests on — longer and there is nowhere to shoot. So the top
      division keeps the documented reach and the ones below get less, which is
      also the direction a difficulty ramp should run: it makes the early game
      forgiving rather than the late game impossible. 0.82m at Sunday League to
      1.05m at the Champions Cup, and a corner into the top of the goal is now
      the same shot that one keeper reaches and the other does not.
- [x] **The net is a NET now — you see through it.** It could not be: there was
      nothing behind the goal but a wash of flat blue, so the cords needed a dark
      sheet behind them to read as a hole at all.
      **Four Kenney backdrops are bundled**, 92KB of the pack's 1.6MB, on the
      same rule the modular characters went in under — only what is used.
      `backdropPath` resolves the four moods and `art_paths_test` walks them
      against disk, so an enum entry without a file cannot ship. The painter
      draws nothing above `goalLineY` now and the photograph sits behind it, so
      the goal stands against a horizon and the net is what a net is: two passes
      of cord, dark under light, which reads as string against a bright stand and
      against a dark one.

### Goalkeeper Practice

- [ ] **It is meant to be the ball coming AT you, with no time to react.** The
      drill exists and plays; the pressure does not. Check the timing against
      the source before retuning it.

### Sound

- [x] **Buying four players played the signing chime over and over.** A batch
      signing places four cards inside ONE `update`, so `card:placed` fires four
      times in the same frame — and `play` retriggers a non-overlapping effect
      from the top, which meant a 0.55s clip restarted four times within a few
      milliseconds. That is not four sounds; it is a burr.
      `retriggerFloor` is 70ms — a frame or two, deliberately nowhere near the
      length of a clip, so a repeat at any human pace is still a second sound and
      only the ones caused by a single action collapse. Per effect, so a batch
      does not swallow the coin or the discovery alongside it, and overlapping
      effects are exempt because stacking is the whole point of the two that ask.

### The subs bench

- [x] **It is the same pitch as the Squad tab now.** It was two scrolling lists,
      which asks the manager to rebuild the shape in their head from position
      labels — while the shape IS the information, and they already know it from
      the Squad tab. `PitchBoard` came out of `squad_screen.dart` so both screens
      lay the eleven out by one set of rules; what differs is only what a tap
      does. A hurt player wears the cross and reads zero (see above), and an
      empty slot says "Injured — needs cover" rather than reading as a formation
      with a gap in it.
      Tapping a man opens the bench from the bottom, tapping a bench card asks
      "X off, Y on" through Colin, and only a YES closes the bench — a manager
      who says no is still choosing, and taking the bench away would make trying
      somebody else a whole extra journey.
- [x] **A BENCH button**, so the bench can be read before nominating anybody.
      Who is available is half of deciding who to take off, and needing to pick a
      man first to find out made that a chicken and an egg.
- [x] **Three bench cards per row, not four** — and responsive above that. A
      max-extent delegate fitted as many 92px cards as the width allowed, which
      is four on most phones. `benchColumns` lives with `PlayerCard` because BOTH
      benches use it and two answers to one question would read as a bug.
- [x] **The withdrawn set reset when the panel was REOPENED.** Pre-existing, not
      introduced by the rewrite: "nobody who has been off goes back on" held only
      for as long as the sheet stayed up, because the set lived on the panel
      while `used` was passed in from the screen. Two taps and a substituted man
      was back on the pitch. It sits beside `_kickoffLineup` now — both are facts
      about the ninety minutes rather than about whichever sheet is open — and it
      is handed in live, so the set the panel reads is the one the screen writes.

### The player card and the sell sheet

- [x] **ATK and DEF were nowhere on the player.** Added to the detail sheet, and
      the sheet's RATING was wrong besides — see the trait entry above. The grid
      card still shows the rating alone: `CardView` carries `rating` and no
      split, so putting it there means widening the record and every builder of
      it, and finding room on a card an inch wide. Not done, on purpose.
- [x] **The sell sheet shows the PLAYER now.** It was a 72px thumbnail of his
      merge card in a 96px box — the same man the squad sheet gives 260px of
      full-length figure to, described here as an inventory item. What is being
      decided is whether to sell a person. `PlayerHeroArt` came out of the squad
      sheet so the two cannot drift, and the offer is a panel rather than three
      centred lines under a picture: the figure IS the decision, so it gets a
      surface, the market's own word over it and the small print under it. The
      sheet is taller to match — a confirm button below the fold looks broken.
- [x] **And SELL is off the squad page.** Two flows took the same money by
      different routes; the one that stays is the sheet a player reaches by
      tapping the thing they want to sell. The market VALUE stays there, because
      what he is worth is information about him either way — routed through
      `coinFigureInk` now, so the money on that sheet is the same money as
      everywhere else.

### The customiser, and the walking manager — 26 Aug, later

- [x] **A hat hides the hair going through it now.** The hat is drawn over the
      hair, so whatever its own shape covers was already hidden — what came
      through was hair ABOVE it, a mohawk's fin standing clear of a cap. The hair
      layers are clipped to below the hat's brow, which leaves whatever escapes
      at the side and the back.
      **It could not be a blanket rule, and that is the whole of the design.**
      Four of the eighteen are BANDS — a headband, a visor, a laurel, a pair of
      headphones — and clipping the hair for those would shave the top off his
      head, which is a worse bug than the one being fixed. So `hatCrownY` has an
      entry per hat and `manager_looks_test` fails the build if one is added
      without deciding; an unknown id off a newer save hides nothing, because
      showing the hair is recoverable and a clip at a guessed height is not.
      The numbers are each hat's own DOME, not its trimming: a beanie's bobble
      and a Santa hat's pom sit above the part that covers anything. And the clip
      is on the LAYER rather than the head, so the hat is not clipped by its own
      brow — a test pins that only hair ever carries it.
- [x] **The walk stopped on EVERY STEP, and it was not the gesture halt at all.**
      The bow stopping the whole scene is wanted and is one gesture in sixteen.
      What was being reported was in `groundEase`: clamping the support foot's
      backward creep to zero leaves a genuine standstill in the curve. Measured
      over one half-stride the rate ran 0.36, 0.21, 0.06, **0.00** — and then
      jumped to 1.11. Twice a stride the whole diorama stopped dead and surged out
      of it.
      `groundEaseFloor` blends a third of a constant rate in. The trade is real
      and worth stating: the worst foot slip goes from 15 art units a cycle to 46,
      against the 78 a wholly constant ground was rejected for — and a planted
      foot creeping a little is a much smaller lie than a pitch stalling under a
      man mid-stride. The blend is linear in the same 0..1, so the distance a
      half-stride covers is untouched and the world still cannot reverse.
      Two tests hold it: the rate never drops below 0.2, and the surge out of the
      slow part stays under six to one — a rate swinging twenty to one reads as a
      stutter even without ever reaching zero.
      **Measured, not guessed:** taking whichever foot is moving forward faster
      was tried first and is worse than a constant ground (slip 107).
- [x] **The tab buttons stacked down the customiser.** A horizontal strip of eight
      does not fit across a phone, so wrapping them fixed the reachability and
      left two lines of little buttons under each other, which reads as a pile
      rather than as navigation. One picker naming the part you are on now — the
      same `DropdownButton` idiom the Player Index's filters use — which is one
      line, says where you are without being read left to right, and cannot run
      out of room however many axes the wardrobe grows.
- [x] **Every option carries its name under it.** The label was on the control for
      a screen reader and nowhere at all for anybody else; a grid of thumbnails
      does not say which one is the beanie.
- [x] **And a locked option shows what it would look like.** The padlock REPLACED
      the preview, which made the reward for building the Fan Zone or lifting a
      cup a surprise — the exact opposite of what keeping it on the grid was for.
      It sits over the drawing now, on a dimmed but visible preview.

- [x] **The backdrop TRAVELS PAST HIM**, off the same clock his legs are on. He
      walks in place and the world moves, so a backdrop holding still is a man on
      a treadmill — and two clocks in one box is the drift `walk_ramp.dart` exists
      to stop, so `WalkClock` publishes the diorama's own `WalkBeat` for a walker
      that has no diorama around it. Two copies of the drawing, slid by how far
      the world has gone, which is the trick the diorama's strips use.
      It sits LOWER and taller as well — `cover` on the full box put the treeline
      up near his head with a third of the frame in grass. The picture is the
      trees; the grass only has to be the ground he is standing on.
      And the stage takes the same 13 either side as the picker and the grid, so
      the sheet has one margin rather than a full-bleed picture over inset
      controls.
- [x] **A Kenney backdrop behind the preview**, and the picker given room. He was
      standing against a bare sky gradient, which reads as a swatch rather than a
      place; the gradient stays underneath so the box is never empty if the asset
      goes missing and still darkens with the theme. The picker gets vertical
      padding — `isDense` shrink-wraps a dropdown to the height of a word — and
      12px clear of the stage, so it reads as the control under the picture
      rather than as part of it.
- [ ] **EVERYTHING ON HIM HAS TO SIT WHERE IT BELONGS.** A full pass over the
      accessories, the facial hair and the clothing, checking each against the
      skull and the torso rather than against how it looked on one build:
      nothing floating, face paint not painted onto hair, a moustache on the
      mouth, beards on the jaw.
      And two garments are wrong rather than misplaced: **the suit and the coat
      are tops only** and should be full-body — a suit needs trousers and to read
      as a suit, a coat needs a length. `walker_figure.dart` already carries the
      per-outfit sleeve and shin coverage the rig understands, so this is the
      art, not the rig.

### Coach Colin — 26 Aug, later

- [x] **The badge is RED.** It was the kit accent, which reads as decoration on a
      screen already wearing that colour — and it is the one thing in the corner
      asking to be pressed. `coachAlert` sits with the card, so the home page and
      the dock can take the same red.
- [x] **The dock orbs are CIRCLES now**, like the floating head. They were rounded
      squares while the same coach on every other screen was a ringed disc — one
      control, two shapes, depending which tab you were on. The burger takes it
      too, so the three round controls are one control.
      Their rim stays a LIGHT one rather than the accent the floating head can
      afford: these sit ON the diorama, and in dark mode the theme's border is a
      near-black ring, which round Colin's portrait — art of a face on white —
      read as a black frame stuck to him.
      And the nag is one red in both places. The home badge was `#D32F2F` and the
      floating one `#E23B3B`; two reds a shade apart is two badges, so both take
      `coachAlert` and the floating one takes the home badge's white ring and drop
      shadow with it.
- [ ] **WHEN HE HAS SOMETHING TO SAY IT HAS TO BE VISIBLE.** Whatever it takes:
      it is the game talking to the player and it currently sits quietly in a
      corner.
- [x] **And the bubble sits ABOVE him**, because the tail points down. Beside him
      it pointed past his shoulder into the HUD, which is a bubble attributed to
      the coin counter. He is at the foot of the stack now and what he says goes
      over his head, the way the home page has it — with the wedge over the middle
      of the head rather than its far edge.
- [x] **The bubble has a TAIL now**, pointing back at him. Off the home page it
      was a plain panel with no speaker, which is a caption rather than a line of
      dialogue. `CoachBubbleTail` came out of `coach_bubble.dart` so both draw the
      same wedge — a shape that differs between two bubbles reads as two
      different kinds of thing.
- [x] **The home page takes the font size the others use** — 13, not 12.
- [x] **Changing screen CLOSES an open bubble.** What he said was about the page
      you were on, and the pool it came from is per-tab — so carrying it across
      would leave a sentence on screen the new tab does not even have to offer.
      CLOSED rather than dismissed: the player never said they were finished with
      it, so it must not be muted for ten minutes. A test pins that the ledger is
      untouched.

### Light mode

- [x] **The match-quest coin yellow read ORANGE.** It was an amber, `#E8A100`,
      picked to clear 4.5:1 on white — while the coin GLYPH beside it is a filled
      disc and stays actual gold, because its black rim carries its own contrast.
      An amber figure next to a gold coin is two currencies in one pair.
      The way out was already half-built: buy the separation with a dark HALO
      rather than with lightness, and the hue gives up nothing. It stopped half
      way, at a darkened value AND a light shadow. One gold now, in both themes,
      with the halo carrying all of it.
- [~] **The reds and greens** — every one I can find is already a single fixed
      value used in both themes (`#4ADE80` and `#F87171`, the dark-mode pair):
      the pitch token's fit colours, the league zones, the form letters, the club
      stats, the cutaway's verdict. So either this is already what was wanted, or
      it is a pair I have not found — worth naming the screen.

### The walker

- [ ] **Lottie for the walking man.** No MCP needed — `lottie` is a Flutter
      package and the format is open; what is actually missing is the FILE. The
      current walker is not an SVG played back either, it is a solved rig
      (`walker_figure.dart` + `groundEase`), which is why the planted foot does
      not slip and why the ground and his legs share one clock. A Lottie clip is
      a recorded animation: it would look smoother and it would give up the
      solved contact, so the ground would have to be driven off the clip's own
      timeline instead. Worth doing only with a clip in hand — and worth
      knowing that "better than the SVG we have" is comparing it to something
      the port does not do.

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

**Mini-games**: all seven are playable. The pattern for a new one is
`lib/ui/screens/minigames/` plus a row in `playableMiniGames` — and the row is
the point: a kind in the catalogue without one is shown locked with a reason
rather than offered, which is what stopped the menu-row-to-nowhere bug coming
back while five of them were unbuilt.

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

- [x] **A Deadline Day signing hands over a different card from the one the feed
      showed.** FIXED — see 21 Aug; the roll is still spent so nothing else in
      the session moves. `_acceptSigning` rolled a FRESH instance and copied only the name,
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
