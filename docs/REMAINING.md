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

**4,575 tests, `flutter analyze` clean.** Flutter **3.44.9** / Dart **3.12.2**,
in `.fvmrc` and in CI. See `The SDK the port builds against` below.

**The newest pass also ran green on 3.38.3**, which is the version that happened
to be on the author's PATH — `fvm` is still not installed, so `.fvmrc` resolves
to nothing. That is a data point and not a change of policy: 3.44.9 is still the
number CI runs and the number to develop against.

**And a contended machine will fail three tests for no reason.** One full run
during this pass reported `+4457 -3` while a `flutter test` on a single file was
running beside it; the same tree, run twice on its own, is `+4535` in 44 seconds
both times. A suite that takes 44 seconds clean and 17 minutes under load is
timing out rather than failing, so **run it alone before believing a red**.

**4,418 to 4,491 across this session's ten passes**, and the first fourteen of
those are the fourteen that went the pass before.
The pass before this one took the suite DOWN — 4,426 to 4,418 — because fourteen
of its tests belonged to a keeper nothing drew and the rest to a penalty model
nothing took. Deleting them was right; what came with them was `keeperKits`, and
this pass put those back on the live rig with fourteen tests of their own. The
symmetry is a coincidence, but the lesson is not: **a suite that only ever grows
has stopped being asked whether what it proves is still reachable, and a
deletion that takes shipped behaviour with it will not announce itself.** The
only reason this one was caught is that the last pass wrote down what it could
no longer see.

**THE PASS THAT WROTE THIS RAN WITH `../merge-empire-fc` ON DISK.** Most of
this file was written from a cloud container, where the spec repo is not cloned
and a dozen items are recorded as blocked on it. **They are blocked on the
ENVIRONMENT, not on the work** — on the author's own machine the spec is a
sibling directory and every one of those items is simply open. Two came off this
way in one sitting, and the pattern in both is the same: **what was missing was
never the copy or the surface, it was the NUMBERS**, and a number invented here
would have been balance passed off as a port.

So if you are running where `../merge-empire-fc` exists, read the blocked list
above as a work queue rather than as a wall. The ones that stay blocked there are
the ones that need NEW COPY — `en.js` plus a `gen_i18n.mjs` run — which is a
different kind of blocked and is called out where it applies.

**HIS READ ON OUR OWN SQUAD** — `squadstate.*`, thirteen keys and forty-odd
sentences in ten languages, with no file in `lib/` so much as mentioning the
prefix. It is `engine/squad_state_engine.dart` now, last in Colin's pool and
only when there is room for it, which is the JS's own rule: everything above it
is about the fixture in front of you, and a squad note is what he falls back on.

**The ORDER was as much of the spec as the thresholds were**, and it is the half
nobody could have reconstructed. Every branch below the first true one is
something he could also have said, so a moved branch changes what he talks about
far more often than it looks like it would — `assets_t1` sits above `thin_squad`,
so a club with both problems is told about the one an upgrade fixes.

**And the first branch is the only one that asks whether the advice is
ACTIONABLE.** `few_players` fires on a squad under three *and* enough coin to
scout — telling a manager with an empty wallet to go shopping is naming the
problem twice. Nothing else in the chain does this, which is worth knowing before
adding to it.

**He is allowed to say NOTHING, and that is a branch rather than a gap.** The
last case returns null instead of reaching for filler, because the floating coach
appears when there is real advice and a head that always has an opinion is one
nobody opens. The port's own `manager.default_tip` still covers a pool that is
empty for other reasons.

**Two things about the port's own state layer that the JS did not have to say.**
`seasonAwardedPlayed` rather than `seasonMatchesPlayed` is what the win RATE is
read against — the rate has to come off the counter the wins were added to — and
an UNOWNED club asset is not a tier-one asset, so it is filtered out rather than
counted as one. Counted, every fresh save would have been told its facilities
were basic before it owned any.

**THE RECORD JOINS THE POOL, it does not replace what is in it.** The other item
the spec unblocked was `manager_hint.record.dominant` / `.struggling`, and the
three numbers were a SAMPLE SIZE (three meetings), a MARGIN (two clear, so
`wins > losses + 1`) and a ONE-IN-THREE roll on whether the record is mentioned
at all. Miss any of the three and the line is either never seen or seen every
time.

**The shape is the part worth carrying.** The JS concatenates the record's
sentences onto the fixture's own and then picks once from the combined list, so
a run of four still gets to be the headline most of the times it exists — and a
two-variant key does not get the same weight as a four-variant one. That needed
`tPoolStableOf`, which takes a LIST of keys; `tPoolStable` is now one line of
delegation to it, so there is still one implementation of the pick. The hash came
out with it as `stableIndex`, because the roll on whether the record joins is the
same stable choice over something that is not a sentence, and a second hash would
have been a second answer to "which one is stable".

**AND THE SPEC CLOSED SIX AUDIT ROWS WITHOUT A LINE OF CODE, which is the
cheapest thing in this file.** Every row on the unreached list that said "check
the JS for which shape it ships" was a five-second grep once the repo was there,
and **five of the six came back the same way: a dead end in the JS as well.**
`purchaseCoinSink`, `getBadgeChoices`, `describeOffer`, `peekGrudge` and
`tapsForTier` each have only their own declaration and their own unit test in
`src/` — no UI, no caller. So they are not features the port dropped; they are
functions the shipped game does not use either, and building a surface for one
is adding a feature rather than porting it.

**The sixth was a live bug and it took eleven minutes to find and fix.**
`hasEnoughPlayers` is the one the JS DOES call, and it calls it as half of a
pair: the play button ANDs three healthy cards on the GRID with three filled
LINEUP slots. The port had only the second — and an injured card still fills a
slot — so **a side of eleven with nine of them injured could kick off**. It went
into `matchStartBlocked`, the port's screen gate, rather than into
`canPlayMatch`, which is a parity function pinned against the JS's own and does
not carry the check there either.

**The transferable bit is which half of a pair got ported.** Both halves are
"can we field a side", they read two different collections, and the narrower one
passes every test the wider one would — so nothing failed and nothing could.
`unreached.sh` found it by asking a completely different question.

**AND FOUR MORE BLOCKS OF SHIPPED COPY TURNED OUT TO BE THE JS'S OWN
ORPHANS.** `fixtures.played`, `prestige.season_income`, the four `prize.*` and
the two `boost.*_chip` all have no caller in `src/` either — and one of them,
`_prizeHtml`, is a whole panel (WIN/DRAW/LOSS prize figures, the boost
multiplier column, both boost chips) sitting fully written in `LeagueScreen.js`
with nothing calling it. **So an unreachable string is not automatically a
feature the port dropped**, and the gap between "translated ten times over" and
"the shipped game draws it" is real. Grep the JS for a caller before building a
surface, every time; three of this pass's answers cost a single grep each.

**One of them also killed a guess this file had written down as "almost
certainly".** `boost.tv_deal_chip`'s `{n}` was read here as matches left in the
season; it is `matchRevBoostMatchesLeft`, a match COUNTER, and the port deleted
both counters in `migration.dart` when it moved those boosts to season scoping.
The number the string names does not exist in this port at all.

**PRO MODE HAD A DOOR IN THE JS AND NONE HERE.** `_showPrestigeColin` is the
dock star's card and it is the port's card exactly — except that on a save NOT
already in Pro the JS offers TWO buttons, `prestige.button_standard` and
`champ.pro_cta`, and the second prestiges straight into Pro. That is why
`prestige.button_standard` had no caller: **a card with one button has no reason
for a shorter label on it**, and the short label was the tell that a second one
was missing.

**The warning moved to where the JS keeps it.** `prestige.pro_note` now also
rides the CONFIRM card when the Pro route was the answer, which is where
`_doPrestige(true)` appends it — choosing the harder game and being told what it
costs are two beats, and the second is the last card before the career goes.

**And the flag is written AFTER the reset here, which is the opposite of the
difficulty-switch rule three sections up.** Both are one line saying
`hardMode = true` and the order is opposite, because what is downstream is
different: `resetState` COPIES settings forward, so the New Team flow has to
write before it; `performPrestige` mutates in place and never touches
`settings`, so this one writes after — which is also the JS's order. The rule is
about the function, not about the sentence.

**And `champ.*` is answered without being built.** It is not a second prestige
card: the JS's celebration is a SEASON-END popup fired on winning the top
flight, after the offseason report, and it feeds the same prestige flow the dock
card does. Which makes it and `offseason.*` one piece of work — **the port has
no season-end popup chain** — and that is the biggest thing this pass leaves
open with a known shape.

**`From playtesting — 28 Aug` IS CLEAR.** It was the longest section in this
file and every item in it is done — the summary's layout, the match screen's
chrome, the light-mode palette, the shop, the bid window, the arrow, the two
mini-games, the frame rate and the perspective pitch. **91 items are open**, and
the shape of what is left is worth knowing before picking one:

| section | open | can it be done from here? |
|---|---|---|
| playtesting, 19–27 Aug | 45 | mostly yes |
| M1 logic core / M3 UI | 11 | yes |
| M4 services | 16 | **no** — AdMob, Firebase, Play Billing, StoreKit |
| M5 i18n | 2 | needs the spec repo's `en.js` |
| M6 release / M7 cutover | 9 | **no** — signing, both consoles, staged rollout |
| open questions | 5 | decisions and physical hardware |

So **twenty-five of the ninety-one are blocked on accounts, consoles and
devices**, not on effort. Everything else is open.

Three things about the 28 Aug section's shape, kept because they are the
general lessons rather than the items:

**Two of its items REVERSE decisions recorded here as done** — the match clock's
own card, and Colin's head filling its orb. Both reversals say so in place,
because a session that reads only the older entry will helpfully put them back.

**Four of its items are the SAME bug on four screens**, and it is worth seeing
as one: a colour picked against a dark surface, printed unchanged on a light
one. Dark mode is right in every one of the four reports, which is the tell —
these are not colour choices, they are missing SECOND choices. The player card's
chips were the fifth and are fixed; the pattern that fixed them (contrast from
near-black ink, identity from a pale tint) is the shape to reach for, because
swapping a dark pair's two values almost never works.

**And "could not reproduce" was wrong once already.** The dark card bottoms were
closed on 27 Aug after checking the caption scrim, which really had been fixed;
the dark thing was the CHIP on top of it. **A report that comes back after a fix
is usually a second cause in the same place**, not a player misremembering.

**THE SEASON ENDED AND NOTHING SAID WHAT THE BREAK DID.** The port had a
season-end SCREEN and no season-end CHAIN: `endSeason` has returned an injury
report, a sponsor report and an ageing report since M1, emitted all three on
`season:ended`, and **every reader of them was a test**. Twenty translated
strings — eleven `offseason.*` and nine `champ.*` — with nothing able to print
one, over data the engine was already producing.

Both cards go through `enqueuePopup`, which is what puts them in the JS's order
without either knowing about the other: the offseason report, then the
celebration, because **the celebration is the card that offers to end the career
the report is about**.

**The celebration is not a second prestige card and the JS proves it.** There
are two surfaces: `_showPrestigeColin` is the dock star, which the port already
had, and `_showChampionsCelebration` fires once from the season-end chain when
the top flight has been won. Both call the same `_doPrestige`, so
`confirmAndPrestige` was split out of `showPrestigeOffer` rather than a second
reset being written — the failure mode being a celebration that wipes a career
without warning anybody or asking the new club its name.

**`wonTheTitle` reads the OUTCOME, never `wonChampionsCup`.** The flag is
permanent — it is what keeps the prestige orb on the dock for ever after — so a
save that won the title three seasons ago would have celebrated again every May.

**Only what can happen is drawn.** The JS's ageing rows carry a
`fromTierName → toTierName` decline and a rating-penalty note, and neither can
ever fire: `processAgeRegression` is character-for-character identical in both
codebases and reports nothing but retirements, always with a zero penalty.
Porting the branch would have been porting a screen state the shipped game
cannot reach.

**AND SIX OF THE NINE `champ.*` STRINGS ARE STILL ENGLISH IN EVERY LOCALE.**
`champ.title`, `.subtitle`, `.body`, `.prestige_teaser`, `.new_adventure` and
`.defend` are character-for-character English in German while `.pro_title`,
`.pro_teaser` and `.pro_cta` are properly translated — which is what makes it a
gap in `../merge-empire-fc`'s own catalogue rather than a decision. Nothing a
call site can fix; the test pins that every key RESOLVES and that the three
which are translated actually change.

**A fixture trap worth carrying: a veteran cannot be older than the career.**
`migration.dart` clamps every card's `seasonsPlayed` to `seasonCount` — written
for an old multi-click season-end bug — so a fourteen-season man dropped into a
season-one save loads as a rookie and never retires. The test that could not
make anybody retire was right about the engine and wrong about the save.

**START HERE if you are picking this up cold:**

```bash
bash tool/unreached.sh        # 65 rows — engines nothing calls
bash tool/unreached_ui.sh     # 2 rows — UI files nothing imports; it LOOPS
```

Both have headers listing the hits that are expected and are NOT bugs. Read the
header before acting on a row — most rows are not work, and telling which is
which is most of the job.

**AND IT COMPILES ON AN OLDER SDK AGAIN.** `home_screen.dart` used
`TickerMode.valuesOf`, which does not exist before 3.44, so a clone on anything
earlier failed to BUILD rather than failing to lint — every test file that loads
the home screen died at compile. It is `TickerMode.of` with the ignore the
framework's own doc prints for it: deprecated on the pinned SDK, present on both,
and analyze stays clean. 3.44.9 is still the number CI runs and the number to
develop against; this only means a machine that has not got it yet can still run
the app.

**THE NEWEST PASS WORKED THE AUDIT'S OWN QUEUE**, and six of its rows came off.
Three of the first four were the same shape, and it is the shape to expect from
the rest of that list: **an engine with no caller is usually not a missing feature, it is
the only NAMED copy of a rule the port had already written out again somewhere
else.** `isTrophyPolishActive` was one of five copies of "is the polish stamped
for this season" — the other four anonymous, in `idle_engine` twice, in
`income_breakdown` and in `gem_engine`'s shop guard — and they had ALREADY
drifted on a missing `seasonCount`. `refreshCupAvailability` was two copies, both
in `season_end`, one of which skipped a save with no cups branch entirely.
`liveListingsBySide` was the Deadline Day board splitting the feed inline.

**The fourth was a real hole, and shipped copy found it again.**
`acceptSellerCounter` had no caller and neither did five of the six
`event.deadline.counter*` strings, so a club that countered an offer got a
snackbar reading "They want more" with no number in it and no way to take the
deal — over a card still quoting the price that club had just refused. It is
built: a dialog in the confirm's shape, and the card goes on offering the number
afterwards, which is what `counter_keeps` promises. **The peek is the part worth
carrying**: their figure is a TOTAL and the cash is what is left after the swap
already on the table, so `sellerCounter` was pulled out of the accept rather than
the subtraction being written a second time in the UI.

**The penalty's predecessor was still in the tree, all three pieces of it.**
`takePenalty` was on the list as "worth checking which of the two is right". The
port's own headers answer it: `planKeeper` says a read is no longer an automatic
save, "which is the change from the old game, where a read was an automatic save
and aim was therefore worth nothing", and `penalty_view.dart` says the old scene
was "a flat photograph of a goalmouth with a keeper sprite slid across it". The
rebuild replaced the arcade model and then left every part of it behind:
`takePenalty` and its enum, `penalty_scene.dart` (313 lines, imported by nothing),
and `keeper_figure.dart` (768 lines and **14 passing tests** — commit `25ab12c`'s
message says eighteen, which was the net suite drop, not the file) — whose `KeeperPose`
and `KeeperRig` share their names with the live rig in `penalty_view.dart`. All
gone. `assets/bg/penalty_goal.jpeg` is orphaned too, 105KB still shipping because
`assets/bg/` is declared as a directory; art is not a thing to bin on a whim, so
it is left for someone who can look at it.

**`tool/unreached.sh` could not have found the UI half, so `tool/unreached_ui.sh`
is committed beside it.** The first scans `lib/engine`, `lib/data` and
`lib/state` for functions with no caller, which a widget can never fail: its
functions are called by its own `build`, so a dead SCREEN reads as busy and is
structurally invisible to it. The new one asks what IMPORTS the file.

**It loops, and round 2 is the whole reason.** A single pass found
`penalty_scene.dart` and stopped — `keeper_figure.dart` looked alive because the
dead scene imported it, which is 768 lines and fourteen tests hidden behind 313.
So it drops what it found and asks again until a round comes back empty. Liveness
is a `lib/` importer only: the sibling sweep's header already says a green test is
not a caller, and counting one here would have kept the keeper alive on his own
tests after the only screen that drew him had gone.

**And it left one thing behind that the sweep could not tell you about.**
Deleting `keeper_figure.dart` took `keeperKits` with it — eight kit palettes
indexed by division — and `PARITY.md` had that ticked as done. It is not:
`penalty_view.dart` draws its own rig and takes only `readChance` and
`keeperSpread`, so **the keeper gets harder as you climb and looks exactly the
same**. The rebuild dropped it, not the cleanup; the dead file kept the parity
item looking honest for as long as it sat there, which is the second-order cost
of leaving a superseded screen in the tree. `PARITY.md` now carries it as `[~]`
with the git incantation to recover the palettes:

- [x] **Dress the penalty keeper from the division.** Done, and it was the
      third argument the row said it would be: `keeperKits` and
      `keeperKitForDivision` sit in `penalty_view.dart` beside the two ramps,
      `PenaltyView` takes a `kit`, and `PenaltyPainter` paints it. See
      **The keeper wears the division again** below for the two things it turned
      up that the row could not have known.

**SIX MINI-GAMES RAMP OFF ONE DIVISION INDEX AND THERE WERE TWO OF IT.**
`keeperDivisionIndex` was documented as shared — "two ways of resolving it would
be two ways of disagreeing" — and a character-for-character copy called
`divisionIndexOf` lived in `boot_room_screen.dart`, which four sibling mini-game
screens imported it FROM. **A screen exporting a state accessor to other screens
is the tell**: the rule is about the save, so it belongs beside the ladder it
indexes into. `currentDivisionIndex` in `data/divisions.dart` now, and both old
names are gone rather than one delegating to the other.

**And routing around a named entry point is how you create the next one of
these.** Hoisting the index tempted a rewrite of the penalty screen's read
chance through `penaltyKeeperSmartChance`, which would have left
`keeperSmartChanceFor` — the engine's own named accessor — with no caller in
`lib/`. Caught before it landed; it is the exact fault this sweep exists to find.

**EVERY STRING THE LEAGUE TABLE OWNS WAS UNREACHABLE**, all fifteen, and three
different faults were sitting in the one gap.

**The column letters were translated and the table printed English.** The
micro-line under the points read `P12 · 7W 3D 2L` to everybody; German is
S/S/U/N and French is M/V/N/D. The mechanism will happen again: the port
deliberately dropped the JS's four-column header for that micro-line — the
reasoning is in the widget's own doc and it is right — and **the LETTERS came
off with the header they were attached to**, then got typed back in as literals.
A layout divergence is where translated strings go to die.

**The last-season badge was a whole feature.** `season_end` has stamped
`lastSeasonStatus` every rollover since M1 — who went up, who came down, who won
it — and nothing has ever read it. ↑, ↓ and 🏆 beside the club name now, with a
legend under the table. The glyphs are not a choice: `play.zone_promo` already
carries ↑ and this file already strips it off for the band labels, where colour
and position say it instead. The catalogue ships each label twice and that is
the design — `table.was_promoted` is a sentence and `table.legend_promoted` is a
word — so the sentence is the tooltip and the word is the legend.

**And the table was meant to be the whole LADDER.** `table.swipe_to_cycle` and
`table.back_to_league` only mean anything if you can look at leagues you are not
in — and `buildPyramidTable`, which plays every AI fixture in any division
through the same sampler the player's own season is pre-simulated with, had no
caller either. Engine, copy and control all shipped; only the join was missing.
That is the third time this queue has found a whole feature one call short.

**Your own division is still not drawn by that function, deliberately.**
`buildLeagueTable` writes movement back into the save — `prevPos` and `posDelta`,
which the next-match card reads — so swiping to a neighbour must not stamp a
"position last round" for a league you were only looking at. The pager asks the
provider for your league and the engine for everyone else's, and there is a test
for exactly that.

**Two test assumptions were wrong and both are worth carrying.** A fresh save is
round ZERO, so the whole pyramid honestly reads P0 all the way down — a test
that forgets to advance `seasonMatchesPlayed` proves nothing about the
simulation it claims to check. And `ensureLeaguePyramid` legitimately writes the
ladder on first browse, so "browsing stores nothing" is false as stated; what
the engine actually promises is that a league renders IDENTICALLY every time,
seeded off (season, division), and that is what is pinned.

**A third: the club names cannot be hardcoded.** A fresh `createDefaultState()`
and the same save after `GameState.load()` name the division's clubs
DIFFERENTLY, because the pyramid is reseeded on the way in. Three badges keyed
to "Anchor Athletic" badged nobody, and the test proved the empty case twice
while claiming to prove the full one. It reads the rows off the loaded save now.

`table.col_club` and `table.col_pts` stay unreachable and should: they are the
JS's column header, which the port replaced on purpose.

**PRO MODE WAS UNREACHABLE, and it is a whole difficulty mode.** `hardMode` had
FOURTEEN readers across ten engines — player fatigue, squad rotation, live subs,
a different trait pool, different daily rewards, different quests, no auto-pick,
a quieter coach — and exactly ONE writer: `false`, in `createDefaultState`.
Nothing in the app could ever turn it on, so every one of those branches was
dead for every player who has ever installed the port.

**The control was there and inert**, both choices carrying `onTap: null`, with a
comment saying why: "the JS changes it only through the new-team flow". That
reading was right and the conclusion was not — **switching HERE starts the
career over**, which `difficulty.switch.toHard` says in as many words, so this
IS that flow, entered from the one row that names the mode. `resetState` has
been wired since the pass that found both reset rows confirming into an empty
handler, so the flow existed; what was missing was the CHOICE on the way in.

The flag is written BEFORE the reset, not after: `resetState` copies `settings`
forward, so the new career starts in the mode that was chosen — and the other
order leaves a window where the save is reset but still in the old mode.

**A test was asserting the gap**, and replacing it rather than deleting it is
the point: what survives is why the row is on the tab at all (which mode you are
playing is the single biggest thing about a save, so it is shown rather than
hidden), and what goes is the claim that neither half of it does anything.

**AND A POOLED KEY'S VARIANTS DO NOT ALL TAKE THE SAME PLACEHOLDERS.** This cost
an intermittent failure and it is the most transferable thing in this pass.
`manager_hint.streak.win.3plus` has four sentences; the fourth ("{n} unbeaten
runs against these, gaffer") never names the club, and one variant of
`streak.loss.2` takes no params at all. A caller supplying what ONE variant
needs leaves literal braces in the others — and since `tPoolStable` picks off a
seed that includes the opponent's NAME, which is itself drawn from the seeded
stream, it surfaces as a test that fails one run in four rather than as a broken
screen.

So: **the params a pooled key needs are the UNION across its variants**, and
there is now a test that checks the engine supplies that union for every key it
can emit — plus a check that every one of those keys was actually exercised, so
a key nobody reached cannot pass by never being looked at. The screen-level test
asserts only that nothing is left unresolved, which is the invariant that
actually holds.

**THE COACH HAD NOTHING TO SAY ABOUT THE FIXTURE**, only about the squad.
Fourteen `manager_hint.*` strings, translated ten times over, with nothing able
to print one — and the surface they belong to has existed since the home screen
was written. `coach_bubble.dart`'s own header says it is the port of
`_computeManagerTips`, which is the JS function these ARE the output of. Its
pool had the grudge and the rating gap and nothing about the two clubs.

**The data was all there as well.** `fixtureResults` is keyed `s{season}_m{n}`,
every entry carries the opponent, the score and the outcome, and it is cleared
only by a PRESTIGE reset rather than by a season rollover — which is exactly
what "last season" and "{n} seasons back" need in order to mean anything.

**Only what the keys themselves specify is built.** `streak.win.3plus` against
`streak.win.2` is a threshold the key NAMES, and a last meeting is a fact rather
than a judgement. `record.dominant` and `record.struggling` are NOT built: they
need a sample size and a margin before an all-time record counts as either, and
those numbers are in the spec repo. That line — build what the copy specifies,
leave what it does not — is the difference between this and `squadstate.*`,
which is thresholds all the way down and stays blocked.

**IT IS POOLED COPY AND THE FIRST VERSION PRINTED THE WHOLE POOL.** Every
`streak.*` and `last_meeting.*` string is three or four sentences separated by
pipes, so a straight `t()` reads all four at the player in one line. The test
caught it. `tPoolStable` rather than `tPool`, too: the pool is rebuilt on every
change to the save, so a random pick would have Colin rephrasing himself while
the bubble is open — the seed is the fixture and the run, so his wording holds
until the thing he is talking about changes.

**And a test whose expectation moves with its neighbours is worse than no
test.** One assertion counted sentences in the chosen line; it passed in a
full-file run and failed a filtered one, because the opponent's NAME is drawn
from the seeded stream and which pooled line the seed lands on therefore depends
on how many tests ran first. Gone, and the reason is in the test.

Sorting is the other thing worth carrying: `meetingsWith` sorts by (season,
match) off the KEY rather than trusting map order, because a save's map order is
whatever the JSON round-trip produced — and "our last two against them" read off
an unsorted list is two arbitrary matches that would pass any test whose fixture
happened to be in order.

**`<strong>` WAS NOT THE ONLY TAG IN THERE**, and the boundary now strips the
CLASS rather than a list somebody maintains. Nine more entries carry markup
`t()` never covered: seven `offseason.*`, whose whole report is built on
`<b>{n}</b> players recovered`, plus `tut.welcome.body`, plus `squad.subtext`
with a `<span style="color:#4ade80">` around the form arrows.

**None of the nine has a caller today, which is the entire point.** That is
exactly the position `cup.win_reward.body` was in until a screen reached for it
and started printing `<strong>Nike</strong>` at players. Handling one tag and
not its synonym is a boundary that only works for the strings somebody has
already looked at — and both of the features those nine belong to (the offseason
report, the tutorial) are open items on this list, so the call sites are coming.

So `<b>`, `<i>`, `<em>`, `<u>`, `<small>` and `<span …>` — attributes included —
all come off, and `<br>` stays the one tag that means something a `String` can
hold. **Stripping the span leaves `▲▲` behind**, which is right twice over: it is
what the sentence is about, and a glyph is what this port reaches for where the
DOM reached for a colour.

The test that matters is not the nine keys, it is the sweep: **every key in
every one of the ten catalogues, checked against the tag pattern.** A per-key
list is how the first version of this got to nine unnoticed strings.

- [~] **`tier.*` (4 keys) is NOT the same bug as `division.*`**, and was checked
      rather than assumed. `card_theme.dart`'s `tierLabel` has NINE entries —
      Bronze, Bronze+, Silver, Silver★, Gold, Gold★, Legend, WORLD CLASS, ⚡ ICON
      — and the catalogue has four, matching tiers 1, 3, 5 and 7 only. Routing
      the port's labels through `tName('tier', …)` would translate four of nine
      and lose the ★ and + distinctions on the rest. Whether the JS ships nine
      and the generator caught four, or the port enriched a four-tier scheme,
      cannot be answered from here.

**THE SHIPPED-COPY SWEEP IS NOW MECHANISED, and it found four things in one
pass.** The technique this queue keeps rewarding — grep the catalogue for a key
prefix, then grep for a caller, and the gap is a work queue — run over every
prefix at once rather than one hunch at a time. Two lessons about running it:

- **Group by what the CALL SITE looks like, not by the key.** `tName('division',
  d.id)` never contains the string `'division.'`, so a naive sweep reports the
  whole prefix as unreachable when two screens are already using it. The
  interesting state is not "no callers" but **PARTIAL adoption**, which is
  strictly harder to see: grep says the prefix is used, the screens that matter
  are the ones not using it, and nothing fails.
- **Most of a big number is keys built from ids at render time** — `ach.title.
  ${id}`, `quest.${id}`, `product.${id}`. `call_sites_test` already covers
  those. Filter them out first or the sweep reports 148 unreachable event
  strings and buries the four real ones.

**1. THE LEAGUE YOU PLAY IN WAS CALLED BY ITS ENGLISH NAME.** All seven division
names ship translated in ten catalogues — German reads Sonntagsliga,
Regionalliga, Champions-Liga — and `Division.name` is the English literal on the
data record. That is what the table header, the season-end promotion card and
the match clock all printed. The helper was already there, already used by the
trophy room and the pyramid editor, and its own doc names divisions FIRST:
`tName`. This is the partial-adoption case above, on the most-shown proper noun
in the game.

The match clock is localised at the SCREEN deliberately: `match_orchestration`
stamps `divisionName` into a result map the parity harness compares field for
field, so the engine keeps the English name and the screen resolves it off the
`divisionId` beside it. A cup tie puts its own already-localised string in that
field under a cup id, which has no `division.` key and falls straight back — so
one call site covers both paths without a branch.

**2. GEMS ARRIVED IN SILENCE, from four faucets, and one of them had never
fired.** `grantTutorialGems` is the onboarding grant and its only caller in the
JS is the scripted tutorial, which the port does not have — so **every save this
port has ever written started with no gems**, meeting the gem shop with an empty
wallet. It is paid at boot now.

**And the parity harness picked the place.** The first attempt put it beside
`settleTutorial` in `load()` — where the port already admits the tutorial cannot
run — and `game_state_test`'s reset fixtures failed: they load a save, reset it,
and compare the result to the JS's field for field, so a grant on that path is
the port inventing currency the JS never gave. `GameRunner.boot` is where sweeps
the port owes the player live, and the harness does not compare it.

**Every grant announces itself now, and that is a STATED EXCEPTION to the toast
layer's quiet-by-default rule.** That rule exists because `coins:updated` fires
on every tick; gems are the opposite case — premium currency, arriving a handful
of times in a whole run — and a player handed some without being told has been
given something they do not know they have. Occasion decides the WORDS, never
whether there are any: three occasions have copy, the rest get the glyph and the
number, which is what `toast.cup_gems` already does and needs no new key. Gold
rather than the club's accent, heavier, held a second longer, and audible on
`newDiscovery` — `coin` is the sound of every idle tick's income.

**3. AND THE SWEEP'S OWN LEFTOVERS ARE A QUEUE.** Eighteen prefixes have no
mention in `lib/` at all. Most are M4 services that do not exist yet — `agegate`,
`cloud`, `cloudsave`, `feedback`, `notif`, `rating` (Rate Us, which wants a store
URL). Three are real and are their own items:

- [x] **`squadstate.*` (13 keys, 3-4 pooled variants each)** — built as
      `engine/squad_state_engine.dart` and last in Colin's pool. It was blocked
      on the spec repo and the spec repo answered it: `_squadStateTip` in
      `LeagueScreen.js` carries every threshold AND the priority order, which is
      the half that could not have been guessed at all. See **His read on our
      own squad** below.
- [~] **`champ.*` (9 keys) — ANSWERED: it is not a second prestige card.** The
      JS has TWO surfaces here and they are different moments.
      `_showPrestigeColin` is the dock star's Coach Colin card — `prestige.title`
      / `.body` / `.body_pro_hint`, one button in Pro and TWO otherwise — and
      **that is the port's card exactly**, which is also why
      `prestige.button_standard` had no caller: a card with one button has no
      reason for a shorter label. The second button is `champ.pro_cta`, and it
      is built now; see **Pro mode had a door in the JS** below.
      **The other eight are the CELEBRATION**, `_showChampionsCelebration`, and
      it is a season-end popup rather than a dock one — auto-opened 500ms after
      the season-end flow when `isChampion`, after the offseason report and
      never racing the promotion rating prompt (the two outcomes are mutually
      exclusive). Its three buttons are New Adventure, 🔥 Pro and **⚽ Defend the
      Title**, and all three feed the same `_doPrestige` the dock card does.
      So it is not a second endgame — it is the moment the endgame is WON, on a
      surface the port has not built, and the trigger is
      `LeagueScreen.js:3581`. Left `[~]` because the port's season-end chain is
      the thing to build first and it wants the offseason report beside it.
- [x] **`fixtures.opp_rating` and `.opp_rating_est`** — the opponent's rating is
      a bare number in an unlabelled 34px column between a club name and a
      score, and the sentences identifying it (including the one explaining what
      the tilde means) shipped in ten languages with no caller. They are the
      tooltip now, the same shape as the table's last-season markers.
      **`ratingEstimated` is only true on a save whose ratings have not been
      drawn** — the boot sweep materialises `seasonOpponentRatings` for the
      whole season — so the test builds that state rather than hoping a fresh
      save is in it.
- [x] **`fixtures.played`** ('Played') duplicates `play.previousMatches`
      ('Previous Matches'), and the spec settles it: `LeagueScreen.js:5635`
      prints `play.previousMatches` over the played block and **nothing in the
      JS references `fixtures.played` at all**. The port is already on the right
      one; the other is the JS's own orphan and wants no call site.
- [x] **`prize.win` / `.draw` / `.loss` / `.boost`** (4) and
      **`boost.tv_deal_chip` / `.kit_sponsor_chip`** (2) — **checked against the
      spec and it says do not build them**, for two independent reasons.
      `_prizeHtml` — the whole panel, WIN/DRAW/LOSS at `matchRevenueBase × mult`,
      `× 0.4` and `× 0.1`, the boost column when `mult > 1` and both chips under
      it — is in `LeagueScreen.js:5162` and **has no caller in `src/` either**.
      It is a surface the shipped game does not draw.
      **And the guess about `{n}` was wrong**, which is the part worth carrying.
      The chips read `matchRevBoostMatchesLeft` and `kitSponsorMatchesLeft` — a
      MATCH COUNTER — and the port deliberately replaced both with season
      scoping and `migration.dart` DELETES the counters on the way in. So `{n}`
      names a number this port does not have and would have to be reinterpreted
      to print at all. Two reasons, either one sufficient.
- [ ] **`offseason.*` (11)** — an "Offseason Report" card: how many injured
      players recovered over the break, how many had time taken off, how many
      sponsorships expired, veterans in decline, who retired. Needs an engine
      that diffs the squad across a season rollover; `season_end` does the work
      but does not report it. Its `<b>` markup is handled now, so the copy is
      printable the day the card exists.
      **UNBLOCKED, and it is `_showOffseasonReport` in `LeagueScreen.js`.** It
      takes `{ injuryReport, sponsorReport, ageingReport, onClose }` and is
      fired from the season-end flow BEFORE the promotion rating prompt and
      before the champions celebration — `hasOffseasonNews` gates it, and when
      there is none the rest of the chain runs on an 800ms timer instead. So
      this and `champ.*` are one piece of work: **the port has no season-end
      popup CHAIN**, and both of these are links in it.
- [x] **`manager_hint.*` — eleven of the fourteen**, built as
      `engine/manager_hint_engine.dart` and wired into Colin's existing pool.
      See **The coach had nothing to say about the fixture** below.
- [x] **`manager_hint.record.dominant` / `.record.struggling`** — built off the
      spec. Three numbers, none of them guessable: a SAMPLE SIZE of three
      meetings, a MARGIN of two clear (`wins > losses + 1`), and a one-in-three
      roll on whether the record is mentioned at all. See **The record joins
      the pool** below.
- [ ] **`manager_hint.aria.head` / `.aria.dismiss`** are what is left of that
      row, and they are DOM accessibility labels that want a Flutter
      `Semantics` rather than a printed string.
- [x] **`difficulty.switch.*` (5)** — built, and it turned out to be the door
      into a whole difficulty mode nobody could reach. See **Pro Mode was
      unreachable** below.

**THE KEEPER WEARS THE DIVISION AGAIN**, which was the row the last pass left
behind, and it cost two decisions the row could not have predicted.

**Seven kits, not the sprite's eight.** Its ramp was `2 + divisionIndex.clamp(0,
6)`, so tiers two through eight are every kit that was ever worn and the first
was never on the ramp at all — an olive club top no division could select. The
table is indexed by DIVISION now rather than by a tier the division has to be
converted into, which is one lookup instead of two and makes the dead entry
impossible to reintroduce by accident. Every colour a division actually wore is
unchanged; the olive one stays in git with the rest of the file. Carrying it
here would have been shipping a palette nothing can pick, which is the fault
this whole queue keeps finding.

**AND THE SKIN COMING OFF THE KIT BROKE THE FACE.** The mouth was a fixed
`0xFF9C6B4E` — which is the old hardcoded skin, shaded, and was correct for
exactly as long as the skin was hardcoded too. Two of the seven kits are darker
than that, so the moment the skin became the division's those keepers would have
had a mouth LIGHTER than the face around it. It is `Color.lerp(skin, black,
0.36)` now. The general shape is worth carrying: **turning a constant into a
parameter breaks every other constant that was derived from it by eye**, and
those are invisible because nothing names the relationship. The brows were the
same find and the sprite had already answered it — it drew them in `kit.hair`,
so they follow the hair here too.

**One thing the sprite got right for the wrong frame.** It shaded its torso
top-left to bottom-right, which is an axis of the SCREEN — fine for a sprite
that never rotated, wrong here, where a full dive lays the whole figure flat and
that gradient would light his back. The shade runs shoulder-to-hip along the
stroke instead (`ui.Gradient.linear` on two rig points), so his chest is lit at
every angle of the dive. **A gradient ported from a rig that could not turn has
to be re-expressed in the body's frame, not copied.**

**The test that mattered is the one that goes through the SCREEN.** Six of the
new fourteen are data invariants — one kit per division, seven distinct shirts,
no glove the colour of its own sleeve, a shade darker than its shirt — and every
one of them could pass with the scene still painting a hardcoded shirt. So seven
more pump `PenaltyScreen` on a save sitting in each named division and read the
kit back off the built `PenaltyView` *and* off the `PenaltyPainter` under it.
The sprite's palettes were reachable too, right up until they were not.

**And two traps in writing those, both costing a wrong diagnosis first:**

- **Seven pumps in one test body is one pump.** The save is a process-lifetime
  map whose contents a load REPLACES, so the second division read back as the
  first and it looked exactly like the wiring not working. One `testWidgets` per
  division; a failure names the division rather than the loop.
- **`addTearDown` is too late for a pending `Timer`.** The screen's debounced
  save leaves one outstanding, `flutter_test` asserts on it — and reports it at
  the TOP of the body, so all seven read as the expectation having failed when
  the scene had simply never been shut. `closePenalty(tester)` at the end of the
  body, the same shape as `goalkeeper_practice_test`'s `closeGame`.

**Two rows in the current tree, both left alone deliberately** — they are the
expected kinds the script's header describes, and neither is a second
implementation of anything live:

- [~] **`ui/screens/placeholder_screen.dart`** (65 lines, 1 test) — a test fixture
      that lives in `lib/`. Its own doc says why: the shell's ticker test needs a
      child that really consumes frames, and `Ticker.isTicking` is the only thing
      that answers "is this screen still being given frames". Reachable from
      `test/` by design. Whether a fixture belongs in `lib/` at all is the only
      question here.
- [~] **`ui/widgets/probe_diorama.dart`** (151 lines, 1 test) — says "**Throwaway**:
      this is a measurement rig, not the beginning of the real scene", and the M3
      question it existed to settle (one painter on one ticker versus a tree of
      animated widgets) has been settled — the diorama is built. A rig you might
      want to re-measure with is not the same as a superseded implementation, so
      it is reported rather than binned.

**The wage bill was a dead pair pointing at a live bug.** `totalLoanWages` summed
the `loanWage` stamped on each card — the TERMS, which nothing debits, because
`loanWagePerSec` charges a share of the definition's income every second instead.
`totalLoanOutFees` summed `feePerMatch`, annotated in the port's own code as
"Display only — what they paid, expressed per game", since `grantLoanOut` pays the
whole spell up front. Neither is owed by anybody.

What they were pointing at: the end-of-night ledger printed `summary['wageBill']`
with a `/ match` suffix — the same per-match arithmetic, in a currency the wallet
is never billed in, in a table whose other rows are real money. **And that field
could not just be fixed**: the summary map is compared against the JS's own
summary object field for field by `deadline_day_parity_test`, so its arithmetic
belongs to the harness. The ledger is the port's screen, so it asks the squad
instead. `loanWageRateFor` is the new shared bit — it prices a DEFINITION, so a
listing can be quoted before the card exists, which the board was doing by
building a throwaway `CardInstance` inline.

**Two more rows on that list should not be built as written**, and both were
checked rather than assumed:

- **`purchaseCoinSink` is A DEAD END IN THE JS TOO, which is the answer.** The
  old note here said it was blocked on `en.js` and named the check to run first;
  the check has been run. `src/data/coinSinks.js` carries the four sinks with
  raw English `name` fields, there is no `coin_sink` copy in the JS's own
  catalogues either, and `purchaseCoinSink` has **no caller anywhere in
  `src/`** — only its own unit test, exactly like the port. So it is not a shelf
  the port dropped: it is a shelf the shipped game does not have. Building one
  would be adding a feature rather than porting it, which is the same call the
  transfer list already got.
  (`isTrophyPolishActive`, bundled with it in the old row, was never about the
  shelf: the polish is a GEM item now, bought through `gem_engine`.)
- **`getBadgeChoices` is a dead end in the JS too.** Same check, same answer:
  only `badgeEngine.js`'s own declaration and its own test, no UI. So the trophy
  room's per-achievement picker — `setEquippedBadge` with the achievement in
  front of you — is the ONLY shape either codebase ships, and the grid this
  function is the data source for was never built anywhere. Do not build the
  second one.

**THE AUDIT ITSELF WAS NOT A PLAYTEST**, and it is a different shape
from everything below: nobody watched a screen and disliked it. A reachability
sweep over every public top-level function in `lib/engine`, `lib/data` and
`lib/state` asked one question — does anything in `lib/` name this apart from
its own declaration — and for a great many the answer was no.

**The sweep is `tool/unreached.sh`, committed rather than described**, so the
number is reproducible instead of asserted and a next session re-runs it rather
than rebuilding it:

```bash
bash tool/unreached.sh            # file :: function :: test-files=N
bash tool/unreached.sh | wc -l    # 65 as this pass ends; was 79
```

A HIGH test-file count is the interesting case, not the safe one: it means the
thing is ported, proven and unreachable. The script's own header lists the four
kinds of hit that are EXPECTED and are not bugs, so read that before acting on a
row. Five findings from this run are worth carrying, and between them they take
the tally of engines caught this way to six: `recordDiscovery`,
`maybeGenerateOffer`, `trackEvent`, `club_asset_tiers`, `grantLookPack` and now
the whole of prestige.

**1. PRESTIGE WAS THE WHOLE SYSTEM, and none of it could be reached.**
`canPrestige` and `performPrestige` had no caller in `lib/` at all; fourteen
`prestige.*` strings sat generated in all ten catalogues with nothing able to
print one; and `prestige_level_1`, `prestige_level_3` and `prestige_level_10`
read a level that could therefore never rise. It is built now —
`ui/popups/prestige_card.dart`, a gold-star orb above the burger, three cards
and a toast. **Nothing about the placement was reconstructed**: `home_dock.dart`'s
own header had described the orb ("a gold star with a dot, rather than the
full-width call to action that used to sit under the match card") since the dock
was written. When a port's own doc describes a control that is not there, that
is the spec, and it is cheaper to read than the JS.

**2. SHIPPED COPY WAS THE TELL AGAIN, and this time it was on screen.** `<br>`
had been handled at the `t()` boundary and `<strong>` had not — twenty-three
entries carry it, and `cup.win_reward.body` HAS a caller, so the cup sponsor
offer was reading `<strong>Nike</strong> wants to sponsor <strong>Smith</strong>.`
to the player. Stripped rather than honoured, and the reasoning is worth keeping:
a Dart `String` cannot carry emphasis, so honouring the tag means twenty-three
call sites taking spans to buy bold on two of them. `CoachLine.strong` is the
port's answer — a whole line at 15px and w800.

**3. A GATE THAT IS NOT CALLED IS A GATE THAT IS OPEN.** The daily reward's boot
entry asked `!claimedToday`, so the sheet came back on EVERY launch until the
reward was taken — a player who opened the app, looked at the cycle and closed
it got it again, and again. `shouldAutoShowPopup` is the once-a-day rule and had
no caller. The general shape: when an engine exposes both a cheap predicate and
a stateful gate, the UI reaching for the cheap one is not a smaller version of
the same behaviour.

**4. TWO IMPLEMENTATIONS OF ONE RULE, and they agreed — this time.**
`claimableQuestsProvider` wrote "completed and not yet claimed" out again while
`unclaimedCount` sat uncalled in `quest_engine.dart`. Nothing was broken and
nothing had to be; the standing rule about not building a second of anything
exists because the two disagree LATER, not at birth.

**5. What the sweep found and this pass deliberately did NOT act on**, because
the measurement says they are not bugs:

- **`expireBoosts` has no caller and it does not matter.** Every reader of
  `incomeBoostActive` and `vipActive` — `income_breakdown`, `match_orchestration`,
  `iap_engine` — already guards on the expiry timestamp beside the flag, so a
  stale flag pays nobody anything. It is housekeeping, not a live bug. The one
  reader that checks the flag alone is `season_end.dart:645`, which is the
  `vipPrestigeLinked` branch the queue already lists as dead.
- **`getDailyStreak` has no caller, and "needs none" was wrong** — `PARITY.md`
  says so, which is the argument for reading both queues rather than one. Its
  own doc names a HUD chip and PARITY names a daily-reward ORB "with its streak
  count"; the port has neither, and the daily lives in the burger where the
  sheet prints the streak only once it is open. So the engine is not dead, it is
  waiting on a control that is still an open PARITY item — and the streak, which
  is the whole reason to come back tomorrow, is currently invisible until you
  open the thing it is meant to draw you to.
- **`setXRandom` / `resetXRandom` are test seams** and are supposed to look like
  this. A dozen of the rows are those.
- **`listPlayer`, `unlistPlayer` and `listedCards`** are the transfer list, which
  the queue already records as a dead end in the JS too.
- **`reset_after_prestige` still cannot unlock**, and prestige is not why: it
  reads `maxPrestigeLevelAtReset`, which a New Team reset writes, and the port
  has no New Team flow at all. That is its own item.

**Still open from that sweep**, in rough order of how much a player would
notice — each one is an engine with no caller in `lib/`, so the module's real
status is "only its own test":

- [x] **`refreshCupAvailability`** (`cup_engine.dart`) — `season_end` wrote the
      flag by hand in both the rollover and the prestige reset, and guarded on
      the branch existing, so a save without one silently got no cup.
- [x] **`grantTutorialGems`** (`gem_engine.dart`) — paid at boot now, and it had
      never been paid at all. See **Gems arrived in silence** below.
- [ ] **The tutorial itself, all 56 strings of it**, and it is the biggest thing
      left on this list. **The copy is not the blocker; the CHOREOGRAPHY is.**
      Every `tut.` string ships in ten languages, and `migration.dart` pins more
      than it looks: nine steps (0..8), two of them inserted at old indices 3 and
      6, and a `borrowedPlayers` mechanic the tutorial lends and takes back. What
      is NOT recoverable from this repo is which key is which step, what each
      step anchors to, and when the borrowed players come and go. That is in
      `../merge-empire-fc`, so writing a nine-step script from here would be
      reconstructing a rule from memory and presenting it as the spec's, which
      `CLAUDE.md` forbids for good reason. Blocked on the spec repo, not on
      effort.
- [x] **`isTrophyPolishActive`** (`coin_sink_engine.dart`) — one of five copies
      of the rule, and the only one with a name. All four readers go through it.
- [x] **`purchaseCoinSink`** (`coin_sink_engine.dart`) — checked against the
      spec and CLOSED: no caller in `src/` either, and no `coin_sink` copy in
      the JS's own catalogues. The shipped game has no shelf. See above.
- [x] **`acceptSellerCounter` and `liveListingsBySide`** (`deadline_day_engine.dart`)
      — the counter had a figure, six translated strings and nothing on screen
      able to take it. Both wired; `sellerCounter` is the new peek the button
      needs, so the cash is worked out once.
- [x] **`getBadgeChoices`** (`badge_engine.dart`) — the question is answered:
      the JS ships the per-achievement picker and nothing else. No caller in
      `src/` for this one either. The grid is not a missing feature.
- [x] **`takePenalty`** (`penalty_game_engine.dart`) — checked, and the physics
      is right. It went, and so did the two UI files nobody had noticed went with
      it. See **The penalty's predecessor** below.
- [x] **`seasonStatusFor`** (`league_table.dart`) — a whole feature, and it took
      the rest of the league table's copy with it. See **Every string the league
      table owns** below.
- [x] **`getCardSplit`** (`player_rating.dart`) — a strict subset of
      `getCardStats`, which has five callers and is what every screen showing an
      ATK/DEF pair goes through. Gone; its tests moved to the live one, where
      they pass unchanged, which is also the proof the two agreed. The rule it
      named that WAS duplicated is the attack-ratio precedence, written out
      three more times in `squad_rating.dart` and now `_attackRatio` there.
- [x] **`traitLabelPlain`** (`trait_engine.dart`) — the port's own addition, not
      the JS's, written so a caller supplying its own glyph would not render
      two. That caller arrived as `TraitBadge` plus `traitName`, through the
      CATALOGUE, and the untranslated helper sat unreachable behind it.
      `traitLabel` beside it stays and now says why: it is a parity function
      whose output is pinned against the JS's.
- [x] **`retirementMultiplier`** (`goal_model.dart`) — the port's own doc said
      "deprecated in the JS, kept so any future caller does not silently break",
      and a caller that never came is not one that breaks.
- [x] **`describeOffer`, `peekGrudge`, `hasEnoughPlayers`, `tapsForTier` and
      `getNextDivision`** — the rest of that row, all five now answered against
      the spec rather than reasoned about. **Four of the five are dead ends in
      the JS as well** and want no call site: `describeOffer`
      (`negotiationEngine.js`), `peekGrudge` (`transferEngine.js`) and
      `tapsForTier` (`data/clubAssets.js`) each have only their own declaration
      and their own unit test in `src/`.
      - **`hasEnoughPlayers` WAS a live bug, and it is fixed.** It is the one of
        the five that the JS actually calls, and it calls it as HALF of a pair:
        `LeagueScreen.js`'s play button ANDs `hasEnoughPlayers(state)` — three
        HEALTHY cards on the grid — with the filled-lineup count. The port had
        only the second, and an injured card still fills a slot, so **a side of
        eleven with nine of them injured could kick off**. The gate went into
        `matchStartBlocked`, which is the port's SCREEN gate, and not into
        `canPlayMatch`, which is a parity function pinned character-for-character
        against the JS's own and does not carry this check there either.
      - **`getNextDivision` is live in the JS and the port is right not to call
        it.** `LeagueScreen.js:3333` recomputes the promotion target from the
        current division at render time, because its season-end card is drawn
        before the rollover. The port's `season_end_screen.dart` reads
        `outcome.newDivision` — the league `endSeason` has already moved you
        into — which is a fact rather than a second derivation of one. Deriving
        it again is how the two answers get to disagree.
- [x] **`totalLoanOutFees` and `totalLoanWages`** (`loan_engine.dart`) — both
      the per-match economy the port replaced, and between them they found a live
      one: the end-of-night ledger was printing a per-match wage bill with a
      `/ match` suffix. See **The wage bill** below.
- [x] **`prestige.season_income` is unreachable in the JS TOO**, which is the
      answer and not a placement problem. "Season {season} · Income ×{mult}" has
      no caller anywhere in `src/` — it is the JS's own orphan, like
      `fixtures.played` and the four `prize.*` — so there is no header line to
      find and nothing to place. `seasonNumberProvider`
      (`home/league_providers.dart`) is still uncalled and that is still true:
      **the season number is never shown to the player outside the season-end
      card and a trophy subtitle.** Worth a surface on its own merits; it is not
      this string's.

**READ `CLAUDE.md`'s Commands section before touching anything in a cloud
session.** Two facts about that environment are not obvious and both cost a
session time: there is **no Flutter on the PATH** until you install the pinned
3.44.9 yourself, and **`../merge-empire-fc` — the spec — is not cloned**, which
also means the generated catalogues cannot be regenerated and **no new `t()` key
can be added from here**. Anything in this queue that needs new COPY is blocked
on that repo, not on the port; say so rather than inventing a key.

**92 items are open**, plus fifteen carrying a `[~]` — answered, but with a decision
left for the manager rather than a line of code. **Read the audit block above
first** — nine of the open items came out of it and each is a whole engine
nobody can reach, which is a different kind of gap from the playtesting
sections. After that, `From playtesting — 27 Aug` and `From the whistle back —
27 Aug, later`: a single sitting's worth of playtesting, and most of the rest of
what is open came out of them.

**The pass before the audit cleared the PENALTY SCENE and then went round the
screens a player had called boring or wrong.** Fourteen commits; what a next session
actually needs from it is the six findings, not the list of changes.

**1. The penalty scene is done bar taste** — seven of its eight items. Four of
them were the same shape, which is worth knowing before touching it again: the
scene was right about the goal and wrong about everything around it.

- **`standBaseY` is the seam, not `goalLineY`.** The pitch runs on past the goal
  line — dead ball area, run-off — and handing that strip to the photograph is
  what stood the backdrop's own flat green field up behind the crossbar. With
  the seam moved back and `backdropRect` SIZING the art so its ground line falls
  on it, the goal stands in a ground instead of on a lawn.
- **The spot never moved: `_eyeZ` did.** Eleven metres is regulation and the
  physics is balanced around it. A 2.62m camera was what made eleven metres look
  like three, and the ball-to-line gap scales with the camera's HEIGHT alone —
  the focal length and the camera's distance are both pinned by the goal having
  to fill three quarters of the width.
- **The framing is derived, so it survives a view it did not choose.** The
  horizon was a fraction of the HEIGHT while every projected offset is a
  fraction of the WIDTH. It anchors on the ball now, gives way only to the
  crossbar, and `_focalFor` opens the lens on a view too short to hold both.
- **A goal is a box.** `sideVertex` and `roofVertex` string the two sides and
  the roof off the rear stanchions the frame was already drawing.
- **`_settle` is the picture after the whistle, and the ball is in it.** A goal
  pinned the ball to the cords and stopped stepping it, so it hung at head
  height for the whole 1.9s hold.

**2. A LIMB CONNECTS WHEN IT HANGS OFF A BAR THAT IS DRAWN**, and this is the
one to carry to any other figure in the game. Reported as four separate faults
on both the keeper and the taker — limbs not joining the body, necks too long,
arms too long, faces blank — and the first three were ONE cause: every arm and
leg started at a single point on the centreline, under a torso stroke whose
ROUND cap domed past it. The shirt painted over the tops of the legs and
swallowed the necks. Flat torso cap, a drawn pelvis and a drawn shoulder
girdle, one limb off each end. The necks were only long because they had been
sized to clear that dome.

**3. A rig's invariant belongs on the BONES, not on the joint-to-joint span.**
Twice now: the keeper's arm was pinned to the reach circle, which forced two
bones summing to the length of his own leg, and the taker's leg was pinned
hip-to-boot, which is what stopped it ever having a knee. Both distances SHOULD
vary — a folded limb is a shorter limb — and it is the thigh and the shin, the
upper arm and the forearm, that may never change. See `kneeBetween`.

**4. The reach circle is the PHYSICS' truth and the figure in front of it is a
person.** Making the drawn glove land on the circle is what produced the ape.
A save at the very edge of the reach may now show the glove a hand short for a
frame; that is the better trade, and it is deliberate.

**5. Light mode is the DEFAULT** (`lightModeProvider` returns true unless the
save says otherwise), so a screen that hardcodes a dark scrim is what MOST
players see, not an edge case. The Player Index was the last one doing it. If
another turns up, the fault to look for is `Colors.black.withValues(...)` and a
tier gradient that never reads `bgLight`.

**6. Measure the lag before fixing it.** "The customise button comes up laggy"
was 209ms on the tapped frame and 23ms for everything after — one build, not a
slow sheet. The first guess (twenty walkers' animation clocks) was WRONG:
twenty still walkers register zero tickers and run twenty frames in 2ms. It was
the building. And picking a choice was already free at 91 microseconds, so an
afternoon spent optimising that would have bought nothing.

**Three things this pass could not do, all for the same reason** — the spec repo
is not in a cloud container, and they are marked `[~]` rather than done:

- **The gem pack art is NOT a port.** `assets/gemArt.js` is 146 lines in
  `../merge-empire-fc`, and `../merge-empire-match-day` — which the queue points
  at for the shop — is not cloned either. What landed is this repo's own
  coin-pack pattern carried one shelf across. Check the three compositions
  against the JS when you can read it.
- **"Card bottoms still dark in light mode on the squad page" could not be
  reproduced.** The mechanism is gone — `PlayerCard`'s scrim follows the theme
  and the bench passes `light`. What IS dark on a high-tier card is the
  generated PORTRAIT, which carries its own near-black background from tier 6
  up. If that is the report, it is an art change. Wants a screenshot.
- **"Minimise" still cannot say "Review"**, and nor can anything else needing
  new copy: `en.js` is in the other repo and the catalogues are generated from
  it. Every fix in this pass that wanted a word used a glyph instead — the
  drill faces, the quest medallion, the fixtures' W/D/L — which is the move to
  reach for, not a new key.

**The pass before this one was the SUMMARY, the replay and the bid window.** Five
things whoever picks this up next will want to know before reading the queue:

- **`summary_league_move.dart` is the table moving**, and it invents nothing:
  `buildLeagueTable` stamps `prevPos` and `posDelta` on every row for the
  next-match card, so the block is those two figures given movement. When the
  engine has no honest "before" — a season rollover, a round nobody rendered —
  it draws the settled table and claims none.
- **`goal_replay.dart` plays a goal again**, and a passage is not a recording:
  `clipFor` rebuilds it from the minute, seeded, so the chip costs nothing to
  offer and the replay is the passage that was watched. **The screen's own
  full-time leave now checks it is still the page on top** — `maybePop` pops
  whatever is topmost, and it was closing the replay the player had just opened.
- **`TransferPill` (in `transfer_offer_card.dart`) is the way back to a parked
  bid**, in the shell above the tab bar. Parking is the one dismissal that is
  not an answer, and it used to leave nothing on screen saying so.
- **A rolled bid goes through `enqueuePopup`** rather than opening where it
  lands, which is what keeps it off the full-time summary: the match holds a
  queue blocker until the player is home.
- **`TraitBadge` is the trait on a card**, and `CardView.trait` is where it is
  resolved — one change reaching the Players page, the bench, the subs panel and
  the pitch tokens, because all of them draw the same view.
- **`buyLookPack` is the first thing that spends gems on a look pack.**
  `grantLookPack` had been sitting there uncalled, so the Shop's five-gem price
  was unactionable; the tile now runs `purchase_flow.dart`'s three beats, which
  is the flow any other gem purchase should reuse rather than re-implement.
- **`divisionCapstonePending` is a READ of the quest capstone**, where
  `checkDivisionCapstone` is the award — the quests sheet has to be able to say
  what finishing the track is worth without paying anybody for looking at it.

The section below still applies to the full-time summary and the live match
screen, which is what the pass before this one was about:

- **`ui/screens/match/match_summary.dart` is a route, not a sheet**, pushed by
  `play_button` after the match screen pops. It MUTATES `result['coinsEarned']`
  when the doubling video is watched, and the caller pays afterwards — that
  ordering is the whole reason `applyMatchRewards` has always been deferred.
- **`services/rewarded_ads.dart` is the only ad seam.** Every placement answers
  `AdOutcome.unavailable` today; when AdMob lands, one override in
  `rewardedAdsProvider` turns the shop's free shelf, the quick-fire matches, the
  lucky boot and the double-or-nothing on together. Nothing else needs touching.
- **`engine/match_coach.dart` is Colin's in-match voice**, and it is pure Dart:
  the read, the cadence and the tactic ask are all testable without a widget.
- **`marketQuote` in `sell_card_engine.dart` is the market's clock.** One roll
  per card per `marketWindow`, so reopening a sheet cannot reroll a price.

The section below still applies to the dugout camera, which is what the pass
before this one was about:

- **`ManagerWalker` has two new seams**, `standing` and `idle`, and they are
  general rather than cam-specific. `standing` stops the STRIDE and nothing
  else — it is not `walking: false`, which is a scene nobody is watching and
  stops him dead. `idle` is a base pose that a playing gesture outruns joint by
  joint (`poseOverIdle`), which is the stylesheet's own specificity written
  out. Anything that wants a planted, living manager now has one.
- **`pumpMatch` runs under reduced motion by default.** The cam is the one
  thing on the match screen that runs forever, so a live one makes
  `pumpAndSettle` never return — and the policy refuses the shot outright
  under reduced motion, so that default is also the honest behaviour. The
  tests that are ABOUT the camera pass `reduceMotion: false` and pump by
  hand.

**The newest section is `From playtesting — 26 Aug`, and it is the one to read
first.** It is a different shape from everything above it: those were things
ported and never called, and these are things a player watched and did not
believe. Several turned out not to be the fault they looked like, and each of
those is written up with the measurement rather than the guess — the walk was not
stopping for the bow, the ghost hits had nothing to do with the lineup, the coin
was not orange by accident.

**Two decisions the manager has already made, so nobody re-asks:**

- **Selling STAYS** — not release-for-nothing. Which makes the reroll on reopen a
  real bug rather than a curiosity; see the players page.
- **Colin should be MORE VISIBLE**, confirmed, but which of the three was not
  chosen: a stronger badge and pulse, a bigger head, or him opening himself
  unprompted. The first is the least intrusive and is the one to do absent
  anything else.

What went in the pass BEFORE this one, and every one of them turned out to be the
same shape — a thing that was fully ported, fully tested and never called, or a
piece of shipped copy nothing could reach:

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
| `assets/` | 853 | `playerArt`, `clubArt` and `svgCache`'s path half done; `gemArt` (146) left — but see `gem_pack_art.dart`, which draws the shelf's three packs WITHOUT it |
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
flutter test             # 4,491 passing
TZ=UTC flutter test      # two parity groups skip themselves outside UTC
```

**In a CLOUD session there is no Flutter yet**, and that is the first thing to
do rather than the thing you discover twenty minutes in — the install is in
`CLAUDE.md`'s Commands section and takes about three minutes:

```bash
curl -sSo /tmp/f.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.9-stable.tar.xz
mkdir -p ~/sdk && tar xf /tmp/f.tar.xz -C ~/sdk
git config --global --add safe.directory ~/sdk/flutter
export PATH=~/sdk/flutter/bin:$PATH && flutter pub get
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
      **SUPERSEDED — the scene was rebuilt and this constraint went with it.**
      `takePenalty` is gone; the shot is simulated in `engine/penalty_physics.dart`
      and the outcome falls out of the flight rather than being decided before it.
      Kept because the note below it is still the argument against a solver.
      **The trap, as it read:** the OUTCOME is already decided by `takePenalty`
      before anything moves, and it must stay that way (the engine is proven
      against the JS). So this is not a simulation — it is an animation that has to be
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
      JS — `takePenalty` knew whether it was a goal before anything moved, and it
      is gone now: the penalty rebuild simulates the flight. The cutaway still has
      a decided outcome, so what follows holds for that one — so a
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

### Seen only in a test — 26 Aug

- [ ] **MOST OF WHAT CHANGED THIS PASS IS VISUAL, and a widget test cannot say
      whether it reads right.** The suite proves the geometry and the rules; it
      says nothing about whether a thing looks like the thing. Three to put in
      front of an eye, in order:
      **The penalty scene.** Both figures were re-rigged from the joints out and
      the whole picture changed behind them — a stadium above the goal line, a net
      of two-pass cord with the crowd showing through it, a dashed aim line that
      marches. Every number is pinned; none of it has been watched.
      **The customiser stage.** A scrolling backdrop on a shared clock, a lower
      horizon, a shallower strip of grass, and the hair now clipped under
      eighteen different hats. The clip is tested per hat; what it LOOKS like
      under each one is not.
      **The light-mode cards.** The caption scrim flipped to white with dark ink,
      the corners are clipped to the inside of the border, and `light` now
      resolves from the theme everywhere rather than per caller — so every card in
      the game changed at once, on the theme nobody plays in by default.

### The Play Match screen

- [x] **The top card should be the NEXT MATCH CARD from the home page.** It is
      the same fixture described twice, and the home page's version is the one
      that got the design work.
      Two things were literally duplicated. The `[1fr | gutter | 1fr]` row —
      the shape whose entire job is making the ratings line up under the club
      names — existed once per screen; it is `MatchRow`, with `nmGutter` and
      `nmGap`, which are what it is made of. And the STANDINGS band the card
      opens with was missing from the board: `PosChip` is public now and takes a
      position rather than the card's own record, because a chip that can only be
      drawn from one screen's data structure is a chip that gets built twice.
      **The standings are a SNAPSHOT taken at kick-off.** `finalizeMatchOutcome`
      runs at full time with the screen still up, so a live table would slide the
      chips under the player at the whistle — and a fixture card describes the
      fixture as it was played.
      **The MODIFIER chips did not come across, and cannot yet.** They are what
      explains the two ratings — home advantage, the grudge, a relegation scrap —
      and the card builds them from `previewFixture`. The match screen has only
      the RESULT, which carries `playerInRelegationZone`, `grudgeBoost` and
      `homeAdvDisplay` but neither the opponent's home advantage nor their
      relegation flag: three of the five, and a card that under-explains a rating
      is worse than one that does not try. Re-previewing mid-match is not the way
      out either — `simulateMatch` has already consumed the grudge. Adding the
      two fields to the result map is the fix and it is a PARITY change: the
      whole map is compared against the JS fixture field by field.
      The board also had to give the height back — see the 0.28 stage cap. At
      full time on a 600pt screen the feed is down to single figures.
- [x] **The commentary needs to look better, and it should carry the
      GOALSCORER'S FACE.** A goal line naming a player, next to the art of the
      player it names. What was missing was the row knowing WHO it was about: it
      had the scorer's name as a string, while the engine has written
      `scorerInstanceId` all along — `finalizeMatchOutcome` attributes career
      goals by it — and the timeline was dropping it on the floor. `FeedLine`
      carries an `aboutId` now, and so does a SUBSTITUTION, which names the man
      coming on and knows his id for the same reason.
      `PlayerFace` is the round crop, and it lives beside `PlayerHeroArt`
      because it is the same decision — the art is a full-length figure, so the
      crop is `cover` anchored to the TOP or a square box of a standing man is a
      torso. A scorer who has since been SOLD still gets his line: no card, no
      face, and the ball glyph stands in.
      **And a goal is the headline of the feed, so it has a surface** — a tint
      and a rule down the leading edge. That is as far as "needs to look better"
      went: the run-of-play lines are still a transcript, which is what they
      should be, but the feed has had no other design pass.
- [x] **The dugout camera is missing.** A broadcast cut-in on the MANAGER,
      reacting to what just happened — the same rig the diorama walks, cropped
      chest-up at roughly twice the size, which is the first time a hat, a
      haircut or a bought emote has been legible at all. Ten axes of
      customisation and fifteen touchline emotes rendered in exactly one place
      until now, at ~40px in a wide shot.
      **The policy is pure and pinned**: `data/dugout_cam_policy.dart` against
      `dugout_cam_reference.json`, 900 rows of `shouldCutIn` alone. The ORDER
      of its five refusals is the load-bearing part — reduced motion beats the
      settings, the settings beat the full-time exemption, the budget beats the
      gap — and a policy with every rule right and the order wrong agrees on
      most inputs and then drops the one shot the whole feature exists for.
      **It has NO SETTING OF ITS OWN**, deliberately: somebody who turned the
      2D cutaways off wants a quicker, quieter match, and a third switch in
      that menu is a worse answer than reading the two that already say what
      they want. Full time is exempt from that and from everything else — the
      gap, the three-cut budget, Skip, and a clip on the pitch.
      **The figure is the walker, planted.** `ManagerWalker` gained two seams
      rather than a second rig: `standing`, which stops the STRIDE and nothing
      else — it is not `walking: false`, which is a scene nobody is watching
      and stops him dead, blink and all — and `idle`, a base pose a playing
      gesture outruns JOINT BY JOINT, which is what the stylesheet's `:where()`
      specificity does. A fist pump is one arm and the far one should still be
      drifting. `poseOverIdle` is that rule, pure and tested.
      The legs go to their untransformed REST, both straight and together,
      because there is no frame of the cycle that gives it: the two thighs only
      ever meet at -3 degrees, and there with one shin folded to 60 to swing
      the foot through. The bob, the sway and the shadow's stride span go with
      them — all three are the walk.
      **Between gestures he is not still**, which is the half that took the
      work. A planted walker with nothing else running is a photograph, and at
      full time that is most of what anybody watches. Four loops — breath,
      weight, arms, head — on four periods that share no common multiple, so
      the combination never visibly repeats; four separate clocks rather than
      one shared one, because one clock read four ways re-aligns at every wrap,
      which is exactly the repeat this avoids. `camIdleAt` is the arithmetic,
      pure: a pixel and a half of movement that is meant to be noticed only
      when it stops.
      **Where it MOUNTS is the one place the port diverges, and on purpose.**
      The JS lays the full-time shot into a summary card that fills the view;
      this screen has no such card. It goes at the head of the FEED instead —
      above the newest line, which is where a broadcast cuts to the bench
      before the graphic. Two reasons: at the whistle the band above is the
      final statistics, which is the one thing on the page a manager actually
      reads, and a shot in the feed SCROLLS, so it costs a short screen no
      permanent height. A goal cut-in still floats over the pitch.
      **And his reaction waits for the move that caused it.** A goal behind a
      cutaway has not been TOLD yet, so the cam hangs off the clip's own
      `onDone` — the same reason the scoreboard holds the number.
      Two things worth knowing for anyone testing near this. The gap rule
      cannot be seen from the UI side at any live pace: a minute is 120ms, so a
      three-second window spans twenty-five game minutes on its own and the
      "he is already on screen" refusal always gets there first. And
      `pumpMatch` now runs under REDUCED MOTION by default, which is what
      refuses the shot — the cam is the one thing on this screen that runs
      forever, so a live one makes `pumpAndSettle` never return.
- [x] **The mood's body LEAN is cam-only.** Not any more: the touchline walker
      wears it too, about the same boot pivot, which moved out of the cam and
      beside the idle it belongs to. The original entry follows.
      **`--lean` is a whole-body pitch** —
      chest out on a good night, head down on a bad one — and the diorama has
      never had it: the port renders mood as a head tilt, a stride tempo and a
      gesture pool. The cam applies it because a reaction shot is the whole
      reason the lean exists, so the two now disagree about what `crushed`
      looks like. Either the walker takes it for everybody or the cam gives it
      up; it is a five-line change and it is a LOOK decision, not a bug.
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
- [x] **And the hand FREEZES at full stretch.** `_moveKeeper` clamped its
      extension, so for the whole save follow-through the arm was a statue while
      the ball looped away — and a GATHERED ball hung motionless in mid-air for
      0.35s, which is the same "ball vanishing" defect the parry was written to
      kill, moved from the ball to the hands. Measured: catch at t=1.15, and ball
      and hand both at exactly (0, 0, 1.00) until the clip ended.
      A dive is a jump, so it has a LANDING. **How far he falls is how far he
      went**: full length puts him on the turf, while a keeper who simply put his
      hands up is still on his feet and dropping him to the ground would be a man
      collapsing rather than a save. A ball he gathered takes him down whatever
      he did to reach it, because a keeper who has caught one smothers it.
      **It is timed from the DECISION rather than from full extension**, and that
      is a trade rather than an oversight. Letting gravity have him mid-flight is
      physically truer and it is a BALANCE change: measured, a keeper who read a
      corner struck at 0.28 power is a third of the way to the turf when it
      arrives and no longer reaches it, so "a read keeper saves a soft corner" —
      what the whole file is tuned around — stops holding. What a player watched
      was the follow-through, and that is what moved.
      The clip also stopped being STEPPED the instant it was decided, while the
      picture holds for the best part of two seconds; `advance` settles a
      finished kick now. And the renderer had a second copy of the dive curve on
      a straight ramp, so the limbs were on a different curve from the glove they
      hang off — `keeperDive` is published and is the one that moved the hand.
- [x] **HIS HANDS TELEPORT 35cm THE INSTANT HE COMMITS.** Fixed — and **the
      one-line fix this entry proposed was tried first and is wrong**, which is
      the part worth carrying. Interpolating the whole curve from standing lifts
      his gloves through the ENTIRE flight, and measured it turned "a read no
      longer guarantees a save" — a property this file is tuned around and has a
      test for — into a keeper who saves everything he reads. Two other tests
      moved with it.
      **The defect is a DISCONTINUITY, so what is fixed is the discontinuity.**
      He settles onto the curve over the first slice of the dive
      (`keeperSettle`): continuous, over inside a fiftieth of a second, and
      finished long before the ball is anywhere near — so the flight path, and
      therefore what he saves, is exactly as it was. The balance the entry asked
      for is now stated as a test rather than assumed.
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

### Penalty training

- [x] **THE KEEPER HITS THE FLOOR AND HIS LIMBS DO NOT.** **`keeperLand` has
      existed in `penalty_physics` since the dive got its landing and the RIG
      never read it** — the hand came down and the limbs held the shape the dive
      left them in, so he arrived on the turf as a posed figure. `KeeperPose`
      takes it now: the split closes, the reaching arm folds, and the arms ease
      to straight DOWN IN THE WORLD, which in his own frame is back through the
      lean — a man lying on his side hangs toward the turf, not toward his own
      feet.
      **And no bone changes length**, which is the rig's own invariant: only the
      joint-to-joint spans move, the two-bone solves are untouched, and there is
      a test that says so. The BALL half of this ask was already done — `_settle`
      gives it gravity, the turf and rolling friction (27 Aug).
      Two things this touches that are already written down. `_settle` (27 Aug)
      is the picture after the whistle and it already gives the BALL gravity,
      the turf and rolling friction — so half of this exists and the other half
      is the rig. And the rig's own rule is that a limb's BONES may never change
      length while the joint-to-joint span may (`kneeBetween`); a limb going
      slack is that same solve run toward a hanging target rather than a posed
      one, which is why this is a change to what the pose is solved AGAINST, not
      a second rig.

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
- [ ] **WHEN HE HAS SOMETHING TO SAY IT HAS TO BE VISIBLE.** Confirmed wanted; the
      SHAPE of it is not settled. Three readings, and they are three different
      games: a stronger badge and a bigger pulse; a bigger head; or him opening
      himself unprompted. The first is the least intrusive and is what to do
      absent a decision — the third hijacks the screen and should not be chosen
      by default.
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

### The player sheet, and the trait roll — 26 Aug, later still

- [ ] **The numbers belong ON the card, and then the box goes.** ATK/DEF under the
      main rating in the hero's top-left, income top-right — and with those two
      moved, the whole Attributes block is repeating what is already on screen.
      **Market value goes with it**: Sell has left this sheet, so what he would
      fetch is no longer a decision being made here.
- [x] **What is left is the trait and his STATS** — checked, and both are
      built. `_CareerStats` is a row of columns, each a glyph, a label and a
      figure, and which columns show is by POSITION rather than by whether the
      number is non-zero: a striker on nought goals is information, and hiding
      it would read as the stat not existing. That is the shape the entry asked
      for rather than the label/value rows it feared.
- [x] **The trait box needs designing.** It is a MEDAL now — a radial gradient
      lit from the top left, a rim in the accent, a glow, and the level stamped
      on its corner. See the 28 Aug entry: a 1.4px outlined disc is the shape
      this app uses for a filter chip.
- [x] **THE RATINGS MUST NOT MOVE UNTIL THE REELS STOP.** Half-fixed already —
      the trait's NAME was held for the spin — but every other number on the
      sheet reads the save, and the save is written before the reels move, so the
      rating, ATK and DEF still gave it away. They are exactly what a roll is
      bought to move, which is what made them the tell.
      **The hold belongs to the SHEET rather than to the badge**: it is a fact
      about what the sheet is showing, and two answers to that is the drift the
      badge already had once. `_PlayerDetail` owns it and draws everything from
      the man he is being shown as — a copy of the card's map with the old trait
      in it, never written back, since the save's key order is pinned against the
      fixture. `TraitHold` is a box rather than a bare map for the reason the old
      flag existed: null means he had NOTHING before the roll.
- [x] **And then it should ANNOUNCE it**, the way a club asset unlock does — and
      it is literally that window: `showFeatureUnlock`, with the trait's own
      glyph, its title and what it DOES underneath, and a star per level. AFTER
      the reels stop rather than with them: a splash over a moving wheel is the
      answer arriving before the question has finished being asked.
      **The test for it has to PUMP, not settle.** The splash takes itself away
      after `featureUnlockHold`, so `pumpAndSettle` walks straight past it and
      finds nothing — which is what the first version of that assertion did, and
      it cost a wrong diagnosis before the print statement went in.

### The sell sheet, again

- [x] **The copy had `<br>` in it.** Three catalogue entries are still written for
      a DOM, so the port printed literal markup mid-sentence. Fixed in `t()`
      rather than in the ten catalogues: those are GENERATED from the JS, so
      patching the output would be undone by the next `gen_i18n.mjs` run — and the
      boundary covers every locale and any string that grows one later. Guarded on
      a `contains('<')` so the common case does no work.
- [x] **More room for him, and no border on the money.** 300px of figure, and the
      offer panel loses its rule: a ruled box round a figure reads as a form
      field.
- [~] **DOES THE MARKET FLUCTUATE? No — and the copy is a lie.** `rollMarketMult`
      rolls ONCE when the sheet opens, weighted by the player's form and whether
      he is sponsored (up to +35% of luck shifted in his favour). Nothing moves
      while you look at it and there is no clock, so "time your sale" is asking
      for something the game does not offer. What DOES change it is closing and
      reopening the sheet, which rerolls — a reroll exploit rather than a market.
      Three ways out, and it is a design call: retime it on a real clock and add
      the timer; own the reroll and make it the mechanic; or change the line to
      say what actually decides the price, which is his form.
- [x] **The sell button asks first.** It is irreversible and it sits under the
      thumb at the foot of a sheet. The confirmation used to guard the squad
      sheet's Sell; that button has gone, so the guard moved to the one that
      remains — as Colin, with the shipped copy, including what the sale COSTS in
      its own right: the bonuses go with him.
- [ ] **A coach tip on whether to accept**, and whether the flow should be SELL at
      all rather than RELEASE for nothing. Both are design decisions rather than
      bugs — see the note to the manager.

### The players page

- [x] **The drag's edge band was measured against the SCREEN.** It came off the
      widget's own box, which starts at the top of the phone — behind the HUD and
      above the action bar — so a card had to be dragged under the glass and most
      of the way off the top before the grid moved. It comes off the scroll
      POSITION now rather than a second key: the `Scrollable` already has a
      context and it is by definition the thing that scrolls, so the two cannot
      disagree about which box is meant.
- [x] **And the list bounces at each end.** The default is per-platform and
      Android clamps dead; a list that stops without giving reads as a wall rather
      than as the bottom. Only this one, deliberately — it is the longest scroll
      in the game and the one a thumb lives in.
- [x] **`Sell {name}?` showed its braces.** The card had no way to fill a TITLE —
      only a body — so the one place a name was asked for could not have one.
      `titleParams` now.
- [x] **The money on the card looks like money**, with a coin beside it rather
      than a figure in the middle of a sentence.
- [x] **And it says what the sale actually COSTS.** "You'll lose its bonuses
      permanently" names a category rather than a consequence; what somebody
      weighing an offer wants is the number they are giving up, which is the
      income he pays every second. The old line survives for a view with no rate
      to show, because then there is nothing honest to put in its place.
- [ ] **The market REROLLS on reopen.** Kept as SELL rather than release, so this
      matters: `rollMarketMult` runs on every open, so closing and reopening the
      sheet shops for a better price. Either the roll wants pinning per player
      per period, or the reroll should be the mechanic and said out loud.
- [x] **MERGE ALL should still be watchable.** Both halves. The burst plays over
      every pair at once — `_burstAt` is a SET now, because one drag is one card
      celebrating and a sweep is twelve — and the survivors slide into the holes
      through `animateNextSlide`, which is the seam the sort button has used
      since it was written.
      **The indices could not come out of `mergeAll` directly**, and that is the
      part worth carrying: closing the holes moves every card after them, so an
      index recorded during the sweep names a different square by the time
      anything can use it. Ids come out instead and the squares are read at the
      end — which also means `landedAt` is at most one per merge and often
      fewer, because a survivor can merge AGAIN and the card it was is then gone.
      What it names is what is still on the grid to celebrate, which is the only
      thing a burst can go off over.

### The club

- [x] **The upgrade popup fired on EVERY tap.** Filling tier one takes TEN taps
      and tier seven takes forty, and the full-screen splash went up on each one —
      a celebration standing between the player and the button they are trying to
      press again. It goes up when the bar actually FILLS.
      `tieredUp` comes off the engine rather than being worked out in the screen:
      `investInAsset` already knows, because it is the thing that decides. The UI
      was throwing the return value away.

### Light mode

- [x] **The player cards had dark bottoms in light mode.** The caption band under
      the name was a black scrim in both themes — the one part of the card that
      had not been told which theme it was in. A scrim's job is contrast, and
      white does that for dark ink exactly as well as black does for light, so it
      follows the theme now and the name and the two bar tracks follow it.
- [x] **And the border went missing at the corners.** Not a new fault, a newly
      VISIBLE one: `Container.clipBehavior` clips to the decoration's OUTER path,
      so a child filling the box paints over the border's own curve — the portrait
      at the top, the scrim at the bottom. Invisible while the scrim was black on
      a dark card. Clipped to the border's radius LESS its width now, which is the
      curve of the hole the child is sitting in.
- [x] **And it carries to every card.** `light` was a `bool` defaulting to false,
      so a card was dark unless its caller remembered — seven callers, seven
      chances to forget, which is how the squad, the bench and the pickers ended
      up with dark cards on a light page. It is nullable now and resolves from the
      theme the card is drawn in; the override stays for the one case that is not
      about the theme, a card lifted onto a drag overlay.


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

### Found while clearing this queue — 27 Aug

- [x] **THE SUITE WAS RED, and had been for a while.** 27 tests across
      `auto_tier_sheet_test` and `merge_grid_test` — everything that can open
      the auto-sell sheet — were failing on a framework assertion, not on
      anything they assert: a `ListTile` paints its background and its ink on
      the nearest `Material` ANCESTOR, and inside a bottom sheet that is behind
      the sheet's own decorated box, so Flutter refuses it.
      The sheet's `SwitchListTile`s were the last Material rows in the game and
      they were already the odd ones out — `settings_controls.dart` records the
      objection: Material's `Switch` is 52×32 with its own knob travel and state
      layer, and beside the game's own toggles it reads as a borrowed control.
      They are the house row and `SettingsToggle` now, which is a
      `GestureDetector` with no ancestor to look for, and the whole row is the
      target rather than a 48-pixel switch.
- [x] **And `flutter analyze` was not clean either.** One `info`:
      `TickerMode.of` has been deprecated since 3.35 and `pubspec.lock` pins
      `flutter >=3.44.0`, so it was showing on the project's own SDK.
      `valuesOf(...).enabled` is the replacement and exists throughout that band.
- [x] **The SDK the port builds against is worth writing down.** Written down:
      **Flutter 3.44.9, Dart 3.12.2**, which is where `flutter analyze` is
      clean and the whole suite is green. `.fvmrc` carries it and
      `.github/workflows/ci.yml` now names the same number.
      **And nothing in `lib/` may need it to COMPILE.** `TickerMode.valuesOf`
      did — it does not exist before 3.44 — so a machine on an older Flutter
      could not build the app at all, and every test file that loads
      `home_screen.dart` died at compile rather than at lint. Pinning the SDK is
      about agreeing with CI on what green means; it is not a licence to use an
      API a clone cannot build. `fvm` is not installed on the author's machine,
      so `.fvmrc` resolves to nothing and whatever `flutter` is on the path is
      what runs — either install it, or keep a 3.44.9 checkout and call its
      `bin/flutter` directly.
      It was worse than "nothing said": CI named **3.38.3**, which is BELOW the
      `flutter >=3.44.0` the lock file asks for, so the one place that did name
      a version named the wrong one — and `pubspec.lock` is not committed, so
      nothing reconciled the two. A fresh clone, this job, and the machine the
      tests were last run on could all disagree. On 3.47 the same suite failed
      34 rather than 27, because the newer framework adds assertions; both
      numbers were one bug, and the next one might not be.

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

## From playtesting — 27 Aug

Reported from the couch in one sitting, in the order they were noticed. Nothing
here was found by a test. The pass before this one was mostly things that were
never CALLED; this one is almost entirely things that are called and look wrong.

**Three done already**, at the top of the session:

- [x] **The market is a CLOCK now, not a reroll.** `rollMarketMult` ran on every
      open, so closing and reopening the sell sheet shopped for a better price.
      `marketQuote` in `sell_card_engine.dart` holds ONE roll for
      `marketWindow` — 15s — and `MarketOffer` (`ui/widgets/market_offer.dart`)
      ticks the countdown down to it and rerolls under a player who is still
      looking. `squad.refresh_in` had been translated into all ten catalogues
      with nothing able to reach it, which was the tell. The JS refreshed on the
      wall clock's 30s boundaries; this is a window per card so whoever just
      opened the sheet gets the whole of it — which is also what makes a native
      ad at the foot of the sheet worth the space.
- [x] **The market value box is off the squad sheet.** Selling is not on that
      sheet, so a price with no button under it is a figure the player cannot
      act on. It lives with the Sell, on the Players tab.
- [x] **The coin figure had a BORDER round it in light mode**, and the money is
      YELLOW. The halo that made gold legible on white — two dark shadows under
      the digits — reads as an outline at 26px. The JS's bronze `#a86523` is
      legible and is not what money looks like. So the figure keeps its gold in
      both themes, bare, and the contrast is bought with the SURFACE: the sell
      sheet's offer panel is a dark plate now, the way a scoreboard does it.
- [x] **And Sell and Cancel are one row.** Stacked full-width buttons read as
      two steps of the same flow; it is one decision with two answers.
- [x] **The squad sheet's numbers live on the player now.** The ruled box under
      the picture is gone; rating, ATK and DEF are a glass plate top left,
      seasons and income are one top right, and `BRONZE PRO · DEF` lifts clear
      of Replace and Bench. The trait block was the least interesting-looking
      thing on a card it is the point of: it wears an accent wash and a level
      chip when he has one, the reels land in a lit window rather than a grey
      box, and the roll button carries its own cost.
- [x] **×2 and ×4 floated on nothing in light mode.** The chip inverts to an
      `accentInk` fill, which IS near-white on a light theme, and the hairline
      meant to save it was a BACKGROUND decoration behind an opaque `Material`
      the full size of the box — drawn, then painted over.
      `DecorationPosition.foreground`.

### Coach Colin

- [x] **The card is anchored to Colin everywhere except the Play page** — fixed.
      It hung off his RIGHT SHOULDER (`left: anchor.right - 10`), so on that one
      page it went up and across instead of up, and the wedge pointed back at a
      corner of him rather than at his face. It stacks over the dock now, with
      the tail over the middle of the disc, which is what the floating coach on
      every other tab does.
- [ ] **The tick has no top border on the home page** and has one everywhere
      else. *Which tick?* There is no checkmark on the home page in the port —
      the nearest thing to a "tick" in the coach popup is the bubble's TAIL
      wedge, and its top edge is covered by the painter on one surface and not
      the other. Worth a screenshot before guessing.
- [x] **Keep the scrim.** It survived: `showCoachBubble` still opens on
      `barrierColor: Colors.black26`, and the two other overlays in the app are
      deliberately heavier — the quick-nav menu at 0.32 and the feature-unlock
      card at 0.72, which is a takeover rather than a bubble.

### The squad sheet, redesigned

The card a tap on a player opens. Not a list of fixes so much as one layout that
is wrong in six places.

**All five were done by the entry at the top of this session** — "the squad
sheet's numbers live on the player now" — and never ticked. Left here as the
list of what that change was answering.

- [x] **Get rid of the stats box.** Rating, ATK, DEF, income and seasons in a
      ruled panel is an inventory readout on a card about a person. Gone: the
      numbers are two glass plates on the portrait, `_HeaderPlate`.
- [x] **ATK and DEF go under the rating, top left of the card.**
- [x] **Income goes under seasons, or top right.**
- [x] **`BRONZE PRO · DEF` is too close to the buttons** — lifted, 72px of
      bottom padding rather than 58.
- [x] **The trait box is the point of this card and looks the least like it.**
      It wears an accent wash and a level chip when he has one, and the reels
      land in a lit window.

### Light and dark

- [~] **The card bottoms are still dark in light mode** on the squad page.
      **Could not reproduce, and the mechanism is gone**: `PlayerCard`'s caption
      scrim follows the theme (white under dark ink in light mode), the squad
      page's bench passes `light` explicitly, and rendering the cards in both
      themes shows light feet on a light page. What IS dark on a high-tier card
      in light mode is the ARTWORK — the generated portraits carry their own
      near-black background from tier 6 up, and on a pale card that reads as a
      dark top rather than a dark bottom. If the report is about that, it is an
      art change, not a colour one. Wants a screenshot before anyone guesses
      again.
- [ ] **Anywhere the top has a background, both themes have to work.** Not by
      recolouring the icons — by finding the opacity that holds against whatever
      is behind it. Dark mode is already right.
- [x] **The index cards are light in light mode**, and they were the last screen
      that had not been told which theme it was in. Every colour on the card was
      FIXED: the tier's dark body gradient in both themes and a 70% black
      caption band under white text. `tierBodyGradient` has carried a light half
      (`bgLight`) all along and `PlayerCard` has read it since the grid was
      fixed; this one never did. **And light mode is the DEFAULT** — see
      `lightModeProvider` — so a page of dark tiles under a light sheet is what
      most players were looking at.
      The tier stripe is 2 rather than 3 (at three it is a bar across the top,
      not a hint of which family the card belongs to), the tier line under the
      name uses the ACCENT on a white scrim rather than `accentLight`, which is
      the pale version meant to be read off black — and the card is clipped to
      the INSIDE of its border, which is the same fault the player card's
      caption scrim and the trophy tiles both had: `Container.clipBehavior`
      clips to the decoration's outer path, so an opaque child paints over the
      border's own curve at the corners. Invisible while the caption was black
      on a dark card.

### The home screen

- [x] **Colin's head is circular and the image fills it now.** The orb centres
      its child, and a bare `ArtImage` under loose constraints sizes to its own
      aspect — so his portrait sat in the middle of the disc with a band of dark
      glass above and below.
- [x] **The customise button comes up laggy — and it is ONE FRAME, measured.**
      209ms on the frame the button is tapped, 23ms for everything after it. So
      the whole complaint is a single build twelve frames long, happening while
      the sheet is trying to slide up.
      **The grid is the expensive half and the half nobody is looking at yet.**
      Twenty chips, each a full `ManagerWalker` rig: ~60ms together, against
      ~18ms for an empty grid of the same shape — measured, not guessed, and
      it is not the animation clocks (a still walker starts none; twenty of
      them run twenty frames in 2ms). Holding the grid back one frame takes the
      opening frame to 107ms, and the chips arrive sixteen milliseconds later,
      which is not a wait.
      **Picking is already free** — 91 MICROseconds for a frame that rebuilds
      every chip — so nothing needed doing there, and the measurement is written
      down so nobody optimises it.
- [x] **REPORTED AGAIN, AFTER that measurement: the customise popup under the
      manager rig still opens slowly** — and **the reporter's reading was right
      both times.** A modal bottom sheet is a `PopupRoute`: it rises over the
      current route without pushing it out, so nothing tells the home screen it
      has stopped being looked at and its pitch scene, weather, ball and walking
      manager all keep their clocks behind something opaque. Counted in
      `showBottomSheetPopup` and `TickerMode` off in the shell, which fixes
      every sheet in the game rather than this one. See the 28 Aug section.
- [x] **The manager was walking in the sky, and the grass was the reason.** The
      strip under him was a `FractionallySizedBox` with a `heightFactor` and no
      `widthFactor` — which passes the incoming width constraint straight
      through, and under an `Align` that constraint is LOOSE, so an empty
      `DecoratedBox` sized itself to ZERO. It was in the widget tree and painted
      nothing, which left the backdrop's own cropped-off hedges as the only
      thing under his feet. Positioned by its edges now, which cannot collapse.

### The shop

- [ ] **THE ADS ARE THE BLOCKER for most of the shop.** "Should actually work"
      means a rewarded video, and there is no ad SDK in the project at all —
      `lib/data/ad_units.dart` holds the placements and nothing can show one.
      That is M4's AdMob work: a package, two app ids, a consent gate. Every
      "coming soon" below is downstream of it.
- [x] **The three special offers should be full width**, one per row, not two up.
      They are the shelf the shop opens on, and two up made the
      highest-converting slot in the game the same size as a consumable — with
      the third alone in a half-width tile beside a gap.
- [ ] **And they should WORK** rather than say coming soon.
- [x] **Quick-fire matches and the free lucky boot say both "already ready" and
      "coming soon".** The contradiction is gone — both statements were true and
      the gate's badge goes while the button is dead; see the 28 Aug shop
      entries. Them being PLAYABLE is the ad SDK, which is M4.
- [~] **The gems look wrong — one gem per image, whatever the pack.** Every
      bundle on the gems shelf wore the same 34px `GameIcon('gem')`, so Pocket
      of Gems, Casket of Gems and Hoard of Gems were three prices under three
      identical pictures, and the tile said nothing about which was the big one
      — on the shelf where that is the only question.
      **`gem_pack_art.dart` is a picture per pack**, and the names are the brief
      exactly the way they were for the coin packs beside it: a pouch with
      stones spilling from the neck, an open casket with a clasp, and a hoard
      with no container at all, because what is being bought is the gems and a
      hoard is a quantity that has outgrown anything you would keep it in. Two
      primitives — a cut gem and a container — against a 100×100 box and scaled,
      so nothing is bundled and it costs one painter.
      **This is NOT a port of the spec's art and does not claim to be.**
      `assets/gemArt.js` (146 lines) is in `../merge-empire-fc`, and neither
      that repo nor `../merge-empire-match-day` — which this entry points at —
      is in a cloud container. What landed is this repo's OWN coin-pack pattern
      carried one shelf across. When the JS can be read, these three
      compositions are what to check against it, which is why this stays `[~]`.
- [x] **The manager-customisation packs have tiny grey buttons with a blue gem in
      them.** They are meant to be a blue button with a WHITE gem. It was a
      near-black pill with the gem's own colour on it at 11px, which reads as a
      disabled chip rather than as the control that buys the pack.
- [x] **And every pack should be tappable** — a confirm ("spend these gems?"),
      and if they cannot afford it, the gem-buy sheet on top of that. All three
      beats already existed in `purchase_flow.dart`; what was missing was the
      engine underneath. `grantLookPack` had never been called from anywhere but
      a test, so a five-gem price sat on ten tiles with nothing able to spend
      it — `buyLookPack` is the debit and the grant, and it refuses in the same
      vocabulary `gemItemBlocked` uses so the Shop reads a refusal the same way
      whatever sold it. A pack completed item by item is not sold again.

### Everywhere else

- [x] **Fixtures: four things, and the biggest was that a result had no shape.**
      How a fixture went was carried by the SCORE'S COLOUR and nothing else — a
      green `2 - 1` against a red `0 - 3` — which asks the player to read a hue
      off two digits, and says nothing at all about a row they have not played.
      It wears the **form dot** now: this file's own `_FormDot`, three classes
      up, already used by the standings and already the green-amber-red the
      summary and the HUD read. No new copy — W, D and L are the letters the
      table prints anyway.
      **The next fixture is a CARD**, not a full-bleed `surface2` band with no
      rounding and no edge, which on a column of otherwise identical rows reads
      as a highlight that has gone wrong. **Every other row gets a hairline**,
      so a season is a list of fixtures rather than a paragraph of club names.
      **The rating has its own slot** — jammed against the score, `31` and
      `2 - 1` ran together into one number. And an unplayed fixture says `—`
      rather than `-:-`, which is a placeholder shaped like a score and so reads
      as a score that failed to load.
- [x] **Season quests do not look good, and do not show the reward** — neither
      for one of them nor for all of them. **The rewards are on now**: every
      quest carries what it pays, resolved for THIS division (the bank's figure
      is a percentage of one league win, not a literal), and the track carries
      what finishing it is worth — the coins plus the division capstone gem,
      which is the only gem in the game that is not a purchase and which nothing
      on screen had ever mentioned. `quests.capstone_title` and
      `quests.capstone_reward` were translated ten times over with no caller.
      **And the LOOK is done too.** The tile was a line of text, a full-width
      bar and a fraction — the SAME THREE ROWS whether the quest was untouched,
      half done, or had money waiting on it, which is exactly why a season's
      worth of them read as a chore list rather than as a track.
      There are three states and they look like three things now. **The bar is a
      RING**, wrapped round the quest's own medallion: a bar under the text is a
      second row saying what the fraction beside it already said, and round the
      dial it is the same reading in no extra height — the tile is one row now
      rather than three. The medallion carries the state's own face: a
      percentage while it is live, a parcel when it is ready, a tick when it is
      claimed. Glyphs rather than strings, because no new `t()` key can be added
      from a cloud session and none is needed — all three say it in every
      language.
      **And a claimable quest is the only one with colour in the card.** It is
      the one thing on the sheet with something owed on it, and it was drawn on
      the same surface as the two that want nothing, so it had to be hunted for.
- [x] **The training popup has images: seven drills, seven faces.** Every row
      wore the same `Icons.sports_soccer` on a bare `ListTile`, which is a list
      that says nothing about what is in it. Each drill gets the thing it is
      ABOUT, on a tile washed in its own colour — and the colour is the KIT's
      accent walked round the wheel (`drillTint`), because the whole palette is
      derived from the club and a fixed hue would be the one thing on screen
      that is not. A locked drill keeps its glyph and loses the colour, which is
      the difference between "not yet" and "not for you" said without a word.
      **Emoji rather than icons**, for the reason the trait badges are: the
      glyph is the same in every language and needs no `t()` key, which is a
      catalogue away from a cloud session.
- [x] **Daily: the boxes should be equal**, there is much more room than it uses,
      and the tick should cross the WHOLE box rather than sit in a corner where
      it does not read as done. They were fixed at 84px in a `Wrap`, so seven
      broke into a full row and a short one centred under it, and a phone wider
      than the four that fitted left a third of the sheet empty. Four and three,
      each tile a share of the same width and all seven the same height. The
      tick is a stamp across the tile now — it was an 11px glyph at the size of
      the caption it sat beside, so a claimed day and an unclaimed one read the
      same from a foot away.
- [x] **Trophies: the bottom-left and bottom-right corners are wrong** — a radius
      plus something else that loses the borders. It is the fault the player
      card's caption scrim had: `Container.clipBehavior` clips to the
      decoration's OUTER path, not to the hole the border leaves inside itself,
      so the opaque caption band painted over the border's own curve — and being
      at the FOOT is why it was the two bottom corners. The child is clipped to
      the outer radius less the border width, and the band's own guessed-at
      third radius has gone. The achievement tiles had it too.
- [x] **The energy popup is two boxes side by side now, with graphics.** The
      two routes to more energy were stacked full-width buttons with their
      refusals printed underneath, so the sheet read as a column of things that
      do not work. They are ALTERNATIVES — watch something, or pay — and
      options that are alternatives belong beside each other: a dead one inside
      a box of its own reads as the half of a choice that is not available yet
      rather than as a broken control. (It is still dead. The ad half is M4's
      AdMob and nothing here changes that.)
      **And the tank is PIPS.** It was `3/6` beside a bolt — the one thing on an
      energy sheet that could be a picture, drawn as a fraction, asking the
      player to do the arithmetic the picture does for them. A row of bolts says
      how much is left and how big the tank is in one look; the figure stays as
      the caption. Past a dozen pips they stop being countable and the figure is
      the honest answer again.

### The Play Match screen

- [x] **THE PITCH IS ALWAYS THERE NOW, with the arrow.** The band never moved;
      what was IN it flipped between a football pitch and a table of numbers
      every few minutes, because the statistics were the stage's resting state
      and `CutawayStage` — which has drawn the idle markings all along — was
      mounted only for a chance. It is one pitch for the whole match, a clip
      cuts in on the same grass, and between chances `MomentumArrow` shows which
      way the game is running: it points at the goal being attacked and drifts
      toward it as the pressure builds, off the same possession figure the board
      prints. The statistics moved to a TAB — `match.tab.stats` was in all ten
      catalogues with nothing able to reach it.
- [ ] **And the full game is still the one you want.** The arrow is the reading;
      a continuous twenty-two-body sim that flows into the chances is the other
      half, and it is a build rather than a fix — `CutawayGame` would need an
      idle mode driven off the same momentum.
- [x] **A GOAL IS A CARD now.** It was one row of text — the single most
      important thing that happens in a match drawn exactly like "nerves
      jangling all around the ground". It has a head (the minute, the word
      GOAL, the score it made), the scorer with his face and his career tally,
      and the commentary line under it as the caption it always was.
      `match.goal_card.title`, `match.career_goal` and `match.career_goals` were
      translated ten times over with nothing able to reach one of them, which
      was the tell. The tally counts today's goals too, because the save is not
      written until the whistle.
- [x] **And the scorer stands on his own touchline** while the clip plays — an
      88px circle sliding in from the edge he then rests against, with his
      surname and the minute. It arrives with the VERDICT rather than with the
      clip: shown from the first beat it gives away that the ball is going in.
- [x] **Every chance drew the SAME passage.** `?? ` binds looser than `+`, so
      `seed ?? 0 + event.minute` added the minute only when the result carried
      no seed at all.
- [~] **The dugout cam still wants watching on a goal — and here is the
      arithmetic, which nobody had done.** The wiring is fine and the gate that
      refuses it is neither the budget nor the gap: it is
      `camFitsBeforeFullTime`, and the numbers are brutal. A minute is 120ms
      (60ms in fast mode), so a 90-minute match is **10.8 real seconds** — and
      the cam window is `220 + gesture + 900 + 200`, with gestures running
      1500–2800ms, so it is **2.8 to 4.1 seconds of an 11-second match**. The
      rule refuses any shot that would still be up at the whistle, which means:

      | pace | last minute that can get the camera |
      |---|---|
      | normal, short gesture | 66' |
      | normal, long gesture | 55' |
      | fast, short gesture | 43' |
      | fast, long gesture | 21' |

      So in fast mode most of the match is camera-free, and it is not a bug —
      the 70th minute really is 2.4 seconds from full time. **The decision is
      whether the window is too long for the match, not whether the gate is
      wrong.** Three goal cut-ins at ~3s each is nine of the eleven seconds;
      that is the number to argue with. Left `[~]` because shortening `camHold`
      or dropping the budget to two is a taste call, and the measurement is
      written down so nobody re-derives it.
- [x] **Colin had NOTHING to say for ninety minutes.** Twenty-four pooled
      `coach.match.*` strings — his read at every scoreline, his half-time word,
      his per-tactic ask — translated into ten catalogues with not one caller.
      `engine/match_coach.dart` is the voice: `suggestTactic` for what he would
      play, the JS's own cadence (25 game-minutes of floor, 40 before he repeats
      himself, nothing before the fifth), and the half-time whistle jumping the
      queue. He floats over the footer with the SHARED bubble tail rather than
      taking a band of his own — a strip that appears and disappears shoves the
      feed about, which is the fault the pitch had. **Casual only**: pro mode
      buys the numbers and gives up the advice, which is the same bargain the
      subs panel strikes.
- [x] **The play card should be the home page's card** — **checked, and there is
      only one of it.** The Play page IS the home tab and it draws
      `NextMatchCard`; there is no second card anywhere in `lib/`. What did not
      match was the MATCH screen's scoreboard, which drew the same rows loose on
      the sky, and that is now the same `GlassPanel` at the same density and the
      same inset, with the clock folded back into it.
- [x] **Commentary and quests are in a box.** They sat loose on the sky
      gradient — the one band on the screen with no surface under it, on a page
      where the scoreboard, the stage and the tactic strip are all panels.
- [x] **The end-of-match reward is an AD OFFER, and it has a shape.** Built to
      that shape exactly: the figure struck through with the doubled one beside
      it while the video runs, a yellow button, and "No thanks" as a text link
      under it carrying the walk-away total. The 28 Aug pass moved the figure
      down beside the button that changes it and gave it a surface — one
      decision, one place.
- [x] **A stat going up PULSES rather than grows.** `Transform.scale` out to
      1.35 and back shoves the row about, on a board whose whole job is holding
      still while the commentary moves. The kit colour says the same thing and
      costs the layout nothing.
- [x] **No more Kenney smoke on the pitch.** A cartoon puff off the turf as the
      boot goes through the ball does not read as football.

### Coins should FLY

- [x] **Coins fly to the counter, and the counter swells when they land.**
      `ui/hud/coin_flight.dart`, above the HUD in the shell's own Stack so a coin
      passes over the glass rather than under it. The trickle is excused by the
      LOOP rather than guessed at: `game_runner` emits `coins:idle` immediately
      before the throttled `coins:updated`, inside the same throttle, and the bus
      is synchronous — so the pair is exact and a skipped update can never leave
      the flag set and swallow a real reward.

### Naming a player

- [x] **The rename card has a Randomise button.** And the reason the squad ends
      up with two of the same man is worth writing down: `pickDisplayName` is
      `pool[tier % 10]`, deliberately deterministic, so every card of one
      position, tier and gender is BORN with the same name. `randomDisplayName`
      rolls another from the same pool and never hands back the one he has; it
      fills the field rather than committing, because the roll is a suggestion
      and the confirm is still what renames him.

### From the whistle back — 27 Aug, later

The match screen and the new summary, in the order they were noticed. The ones
already done are marked; the rest are the queue.

- [x] **Full time leaves the commentary page.** It has nothing left to say — the
      tactic strip has gone, the clock has stopped and the payoff is elsewhere.
- [x] **And the full-time dugout shot went with it.** The summary opens on him,
      with the room for it; two of him a second apart is one too many.
- [x] **The quest outcomes are off the bottom of the play page.** The count
      `(1/3)` rides the Quests tab instead, and it is still one tap to see which
      three.
- [x] **AT HOME WE ATTACK RIGHT, AWAY WE ATTACK LEFT** — the 2D pitch and the
      arrow both. `ourSideLeft` was pinned true for every fixture, so on the road
      our chances ran the opposite way from the scoreboard, which reads home side
      left.
- [x] **A goal against is RED.** Green is what this game uses for a thing going
      well for us, on every screen.
- [x] **The arrow is bigger and SOLID.** At 30–75% alpha the mown stripes ran
      through it and it read as a smear; it is one flat shade of the turf now —
      ours a stripe lighter, theirs a shadow darker.
- [x] **Colin's bubble stands out from the commentary.** Same surface and same
      hairline as the box it floats over is a paragraph, not an interruption.
- [x] **The tactic strip has the page's own margin**, and the rule between the
      card and the pitch has gone.
- [x] **The stats tab fills the space it has.**
- [x] **The dugout cam has air above it in the feed.**
- [x] **The scoreboard is a CARD.** It shared the next-match card's rows and drew
      them loose on the sky, so the fixture you accepted and the fixture you are
      watching did not look like the same object. Same `GlassPanel`, same
      density.
- [x] **The 2× offer exists.** `services/rewarded_ads.dart` is the seam; the
      summary shows a yellow watch-to-double with No Thanks as a text link under
      it, and `applyMatchRewards` — deferred to the closing screen since it was
      written, for exactly this — pays whatever the screen last said. Every
      placement answers `unavailable` until the SDK lands, which is a real
      answer the flow has to handle anyway.
- [x] **A REPLAY button beside each goal in the feed**, opening the 2D passage
      again in a popup. `goal_replay.dart`, and the chip is offered only where
      `clipFor` can actually build a clip — a passage is not a recording, it is
      rebuilt from the minute, which is why asking for it again costs nothing.
      It holds the match while it is up, the way the subs panel does. **And the
      whistle was closing it**: full time leaves the commentary page on a timer
      and `maybePop` pops whatever is TOPMOST, so the replay opened on the goal
      that had just gone in was what the timer shut. The leave checks it is
      still the page on top, and the replay asks again on its way out.
- [x] **No Thanks should carry the match-quest money too** — what the player
      walks away with is the fee plus what the three quests paid. Both answers
      carry the walk-away total now, and so does the hero figure: a match quest
      auto-pays at the whistle, so it passes through neither the offer nor
      `applyMatchRewards`, and the screen was understating the match by whatever
      the track was worth. Totals on both sides also make the two answers
      comparable — the difference between them is exactly what the video pays.
- [x] **The 2× block, the quests and the verdict all want the same box** the
      score is in, and the verdict wants its own colour. One `GlassPanel`, ruled
      in the result's colour between what happened and what it paid. The verdict
      wore `accentBright`, which belongs to the CLUB — a side in red shirts was
      told it had won in the same red the game uses for a goal against — so it
      reads the green-amber-red scale the form dots and the HUD read. The two
      buttons stay pinned at the foot: the yellow one is the screen's action,
      not part of the report.
- [x] **THE LEAGUE TABLE, ANIMATED, on the summary.**
      `summary_league_move.dart`. It opens on the table AS IT WAS, holds long
      enough to be read, then rearranges — every club sliding to where this
      round left it, with an arrow and a count. Nothing there decides a
      position: `buildLeagueTable` has stamped every row with `prevPos` and
      `posDelta` for the next-match card all along, and this is those two
      figures given the movement they describe. It refuses to animate rather
      than invent one — a round the engine cannot honestly compare against (a
      rollover, or a round nobody rendered) draws the settled table and claims
      nothing. Off for a cup tie, which changes no standing.
- [x] **The commentary has very little room left.** It got the rethink: the tab
      bar has gone entirely — the quests report on the summary and the stats are
      behind the board's chart button — and the clock came off its own card into
      the scoreboard. The feed has the whole box, on glass. See the 28 Aug
      match-screen entries.
- [x] **The Sunday League header — the timer and the progress bar — is a card of
      its own, under the score.** It was the scoreboard's OPENING band, which
      put the one thing that changes every tick at the top of the one card whose
      job is to hold still: every minute, the whole score card was a widget
      whose contents had moved. They are also different questions — the board is
      WHO and what the score is, and this is HOW FAR IN, which is what the bar
      says without arithmetic. `_ClockCard`, same `GlassPanel`, same inset, a
      hair of gap: two cards read top to bottom as one object rather than two
      panels on a page.

### Goalkeeper Practice

- [x] **THE SHOTS SHOULD BE FOOTBALLS COMING AT YOU.** They were five faces in
      rotation — a runner, a target, a bolt, a flame — inside a coloured disc
      with a white rim, pulsing, which is a button with a picture on it rather
      than a shot. One ball, no disc, no rim, growing from 0.28 to full over its
      window. **The closing ring went with them**: the growth IS the clock now,
      and one reading is better than two saying the same thing. Eased OUT, which
      is both what a struck ball does and what makes the late save the hard
      one.
- [x] **It is too easy, and too samey.** The window is per SHOT now rather than
      per session — `drillWindowFor` jitters it — because shots that all arrive
      at exactly the same speed are a metronome, and after two of them the
      player is counting rather than reacting. **It jitters DOWN only**: a
      jitter that could lengthen the window would be a hole in the division's
      ramp, and the ramp is still what sets the middle.
- [x] **THE GAME ENDS WHEN THE LAST SHOT IS SETTLED, not when the clock runs
      out.** It waits out the flash first — the ✓ or ✗ on the last one is the
      answer to it — and then the summary comes up.

### The full-time summary — the third report

- [x] **The goalscorers go in the TOP card**, names and minutes only. They had a
      panel of their own further down with a portrait per row, which is a second
      card telling the story the number above it already told — and the number
      is the part that has to be found first. Under the score is a scoreboard's
      own convention rather than a design choice.
- [x] **The defeat/victory button on the MATCH screen has gone.** The whistle
      already leaves that page on its own 1.4s after the sting, so the button
      was a control for something about to happen anyway — a row of height on
      the one screen with none, inviting a tap that raced the timer.
      **And it cost the tests a trap worth writing down**: that leave is a plain
      `Timer`, so `pumpAndSettle` never reaches it — it advances the clock only
      while frames are pending and a finished match schedules none. A pump of
      1.5s is what fires it.

### The bid window

- [x] **The coins want a coin beside them**, and the percentage over fair value
      wants the colour scale. The fee, the premium and the income lost were one
      paragraph in one 13px grey. `transfer.market.jackpot` down to
      `transfer.market.below` — five band names, translated ten times over with
      nothing able to reach one of them — are the chip beside the figure, and
      the thresholds are Colin's own so the chip and his read cannot disagree.
- [~] **"Minimise" should say "Review"** — and a minimised bid needs a way back.
      **The way back is built**: `transfer.pill_label` — "Transfer offer — tap
      to review", another string with no caller — is a pill in the shell above
      the tab bar, so a parked bid follows the player across every tab. The
      RENAME is the half that cannot be done here: the catalogues are generated
      from `../merge-empire-fc`'s own `en.js`, so "Review" has to start there
      and be regenerated.
- [x] **And it must not open over the result.** The idle roll opened the card
      the instant the tick announced one, wherever the player was — the
      full-time summary included. It goes through `enqueuePopup` now, which
      already knows a match is on: `play_button` holds a blocker for the match,
      the summary and the round trip after it. It waits rather than expires, and
      it is re-checked at show time, because the pill is a second way to answer.

### The cards

- [x] **A player's TRAIT should show on his card** — squad, subs, bench and the
      Players page. `CardView` carries it, resolved in `cardViewFor` where every
      other value on a card is resolved, so one change reached all four. The
      badge is `TraitBadge` and there is one of it: the eleven draw a
      `PitchToken` and everything else draws a `PlayerCard`, and a trait that
      looks like one thing on the pitch and another on the bench is a trait the
      player has to learn twice. No new copy — the emoji is the trait's own and
      the level is a roman numeral, so it says it in every language.

### The penalty mini-game

Its own list, because almost none of it is right yet.

- [~] **The figures and the net still do not read as real** — reported more
      precisely from the couch mid-pass: **the problem is the BODIES**. The
      kicker had no neck, tiny arms coming out of his waist, and no football
      kit — shirt, shorts or socks; the keeper had monkey arms, no neck, and a
      top that did not read as a keeper's, with no socks, boots or feet. All of
      that is addressed below; what remains of this line is taste — say what
      still looks wrong after playing it.
      - **The arms came out of the waist because of where they were DRAWN
        from**: both hung off the torso's centreline, so the 0.30-wide torso
        stroke swallowed their top third and they surfaced at hip height,
        tiny. They hang off the girdle's edges now, over a two-bone elbow,
        with a sleeve to the elbow and skin to the hand.
      - **The kit is a kit**: the whole leg was one dark stroke, which is
        trousers. Shorts stop at the knee, socks run into the boots, the boots
        are boots; the taker's shirt has short sleeves; the keeper wears the
        classic strip — long sleeves in one loud colour, black shorts,
        matching socks, and WHITE gloves.

      **Reported again after that pass, and this is the round that answers
      it**: the limbs still did not CONNECT on either figure, both necks were
      too long, the keeper's arms were still too long and bent backwards, and
      the faces were blank.
      - **A limb connects when it hangs off a bar that is DRAWN.** Every arm
        and leg started at a single centreline point under a torso stroke whose
        ROUND cap domed past it — so the shirt painted over the tops of the
        legs and the limbs surfaced out of the body instead of joining it. The
        torso ends flat now (butt cap), and there is a pelvis
        (`_keeperHip` / `_takerHip`) and a shoulder girdle, both painted, with
        one limb off each end. That is the whole fix and it is four strokes.
      - **The necks were long because of the cap they were sized to clear.**
        0.34 was solved against the round cap's dome; with the torso ending
        flat the head sits at 0.25 and the neck is the sliver it should be.
      - **The keeper's arm is a BODY's arm now, not the reach circle's
        radius.** Pinning the glove to the circle at full stretch forced the
        two bones to sum to `keeperReach` less the girdle — 0.88m of arm on a
        man 1.8m tall, which is the length of his own leg. The circle is the
        PHYSICS' truth and it already includes what it includes; the figure in
        front of it is a person. 0.33 + 0.34 now, and a save at the very edge
        of the reach may show the glove a hand short for a frame — which is a
        better trade than an ape in every frame of every kick.
      - **"Bent backwards" was the rest-angle, not the elbow.** At 104 degrees
        from vertical the arm was near-horizontal, so an elbow bowing below the
        chord sent the forearm back UP to the glove. At 132 both bones point
        downward and the same kink reads as a relaxed hang — gloves at his
        hips, where a set keeper's are.
      - **The taker's forearm folds IN.** It turned further OUT, so the two
        bones straightened into one splayed stick and his arms reached
        sideways nearly as far as his legs reached down. From directly behind,
        a running arm is an elbow at the ribs with the hand tucked in front.
      - **The faces**: the keeper has brows, eyes, a mouth, ears, hair over the
        crown and down the nape, and a collar; the taker, seen from behind, has
        the hair, the ears and the collar and no face, because there is none to
        see. Two or three pixels each at a keeper's size on screen, and the
        difference between a person and a blank.
- [x] **The background was at the wrong height, and the goal line was why.**
      The seam between the painter's turf and the photograph behind it was
      `goalLineY`, so the band handed to the art started ON the line — and the
      Kenney backdrops are a square drawing with a flat green field filling
      their bottom third, cropped to exactly that band. What stood behind the
      crossbar was the ART's grass, at the art's own scale, which is the
      mountain. **Ground does not stop at the goal line**: there is the dead
      ball area and the run-off first, and all of it is the painter's turf in
      the painter's perspective. `standBaseY` is the seam now, 7.5m past the
      line.
      **And the art is PLACED rather than fitted**, which is the half that a
      new seam alone would not have fixed. `BoxFit.cover` shows whichever slice
      the alignment picks, and on a tall view the band is nearly as tall as the
      drawing — so no alignment exists that shows only what is above its ground
      line, and asking for one gets a clamp and the field back. `backdropRect`
      SIZES it so the drawing's own ground line lands on the seam. The treeline
      stands on the grass.
- [x] **The turf's horizontal lines are barely visible** — they were one shade,
      on every other band. Five per cent white on the odd bands and nothing on
      the even ones is a single faint edge rather than a stripe; a mown pitch is
      light against DARK. Both cuts now, and the ground pass is CLIPPED to the
      seam — a band laid beyond the run-off projects above it, which at five per
      cent nobody could see and at ten is grass painted in the sky.
- [x] **The goal has SIDE netting, and a roof.** It had a back and nothing else,
      so a ball along the inside of a post passed through open air and the goal
      had no depth in it — the side panels are the only surface in the picture
      running away from the camera. `sideVertex` and `roofVertex` hang off the
      rear stanchions the frame has been drawing all along. Static rather than
      sprung, which is honest: taut between post and stanchion is why side
      netting is the part of a net that does not billow, and the back plane
      still takes the shot.
- [x] **The penalty spot is ELEVEN METRES and did not move — the camera did.**
      `spotDistance` is regulation and every number the physics is balanced
      around rests on it. What was too close was the PICTURE: from a 2.62m
      camera the gap between the ball and the goal line was barely a third of
      the goal's own width, with the bottom half of the frame empty grass, so
      eleven metres read as three. The separation is
      `f · h · (1/back − 1/(back + spotDistance))` — it scales with the camera's
      HEIGHT and with nothing else that is free, because the focal length and
      the camera's distance are both pinned by the goal filling three quarters
      of the width. Up to 3.9m opens it by half again and costs the scene
      nothing: same goal, same shape, same run-up depth.
      **And the framing is derived now rather than solved for one window.** The
      horizon was a constant fraction of the HEIGHT while every offset the
      projection produces is a fraction of the WIDTH, so the whole picture slid
      up and down the frame as the aspect changed — and the view is an
      `Expanded` in a column of score lines, so its shape is whatever is left
      over. It anchors on the ball, gives way only to the crossbar, and
      `_focalFor` opens the lens when the view is too short to hold both. A
      widget test's own 800×600 surface is already past that aspect, which is
      how the wide case was caught.
- [x] **The kicker's odd swing was a leg with no knee in it.** One rigid
      segment from hip to boot, pivoting through 45 degrees, with no backlift at
      all — the angle ran from 0.36 radians to 1.14 and that was the whole kick.
      It is two bones over a knee now (`kneeBetween`, a two-bone solve), and the
      strike is TWO BEATS: back with the knee folded (`_takerCock`), then an
      eased snap through that STRAIGHTENS into the ball, which is the part that
      lands on it. The thigh and the shin are what may never change length —
      the hip-to-boot distance is what SHOULD, because a folded leg is a shorter
      leg, and pinning that distance is exactly what forced the bones to
      stretch.
- [x] **The keeper's arms were huge in two ways, and only one was the length.**
      `keeperHand` is the centre of the reach and the centre is his CHEST, so an
      arm drawn from there to the glove is the whole of `keeperReach` — 1.05m of
      limb on a figure whose entire leg is 0.88m, radiating out of his sternum
      with no joint in it. The glove has to stay on that circle, because the
      circle is what decides saves; where the arm STARTS does not.
      `_keeperShoulder` puts the joint a girdle's half width out and there is an
      elbow between it and the glove.
      **Displaced along the arm's own direction, not square across the chest** —
      a fixed sideways offset leaves a tucked arm longer than an outstretched
      one, which is exactly the stretching this rig was rebuilt to kill. Along
      the arm, every limb is `keeperReach` less the girdle and none of them
      moves.
      The other half was the POSE. `_armRest` was 52 degrees from straight up: a
      man signalling a touchdown, holding two full-reach limbs in a V above his
      shoulders. A keeper set for a penalty has them out to the sides and a
      little below, which is also the pose the dive leaves from.
- [x] **The keeper was fixed first; this is the BALL.** "No physics at all: the
      ball sticks in the net and the keeper sticks in the air" — he stopped
      sticking when the dive got its landing, and the ball did not. A goal pinned
      it against the cords and left every component of its velocity untouched,
      and then `done` stopped stepping it: the frame the word went up was the
      frame the ball stopped, and the screen holds on the goalmouth for 1.9s
      after that. It hung at head height for all of it.
      `_settle` is the picture after the kick is decided, and everything that
      stops moving in it is something the player watches not move. The net TAKES
      the pace — a ball into a net is stopped by it and then drops — and gravity,
      the turf and rolling friction do the rest, so a goal ends with the ball on
      the ground inside the net. It cannot come back out through the cords and it
      cannot roll out through the SIDE of the goal either: an angled shot carries
      most of a metre of drift across the hold, which put it through the side
      netting and out past the post. A ball he CAUGHT still goes down with his
      gloves, and none of it can reach `result` — the outcome is set once.

## From playtesting — 28 Aug

Reported from the couch in one sitting. **Two of these REVERSE decisions this
file records as done**, and both reversals are marked as such — a next session
that reads only the older entry will put them back.

### The full-time summary

- [x] **THE TABLE HAS TO BE ABOVE THE FOLD.** It is the thing the player scrolls
      to and the one part of the screen that moves on its own, so it may not be
      the part that needs finding. `summary_league_move.dart` animates every
      club to where the round left it and it is currently below what fits.
      **The quests can go below it**, and the verdict/2× block is what has to
      make room.

### The match screen — it needs ROOM, and here is where it comes from

- [x] **The clock and the progress bar go INTO the scoreboard card.**
      **This reverses `_ClockCard`**, which was split out on 27 Aug for a good
      reason — "the one thing that changes every tick at the top of the one card
      whose job is to hold still" — and the reason is overruled by the space.
      Two cards stacked is a rule and a gap that buy nothing; the minute is
      small and the bar is a hairline, and neither has to move the score.
- [x] **The Quests and Stats TABS should find another home, and then the tab bar
      goes too.** Done. The quests report on the summary and the statistics are
      behind the board's own chart button — a bottom sheet that does NOT pause
      the match, because subs decide what happens next and this is a look at
      what already has. `MatchStatboard` and `match.tab.stats` moved rather than
      went; deleting them would have been the fault the sweeps exist to find.
      The commentary has the whole box, on glass. That bar is a full row of chrome serving two panels the player
      does not watch during a match. **Quests are welcome to live only on the
      end screen** — confirmed — which is where the money is paid anyway, and
      the count already rides the Quests tab elsewhere. Stats wants a home; if
      one cannot be found, the honest answer may be that a live match does not
      need them. Everything that comes off goes to the COMMENTARY, which the
      27 Aug entry already records as having very little room left.
- [x] **The pitch should be in PERSPECTIVE, and it has to be DRAWN.** It is —
      and the way it is done is the answer to why it could not be a photograph.
      **Everything on the grass has to sit in the SAME projection**, and the way
      to get that without teaching each of them about it is to apply the
      projection ONCE, over all of them: the markings, the twenty-two bodies,
      the ball and the arrow go through one `Transform` together, and
      `CutawayGame` and the marking painter go on working in the flat
      coordinates they always did.
      **The overlays deliberately stay flat** — the verdict word and the
      scorer's badge are a broadcast graphic laid over the picture, not
      something standing on the pitch, and a headline that leans away from the
      reader is a headline nobody reads.
      **The tilt is small on purpose**: a high wide, not a corner-flag camera.
      Past about fifteen degrees the far half stops being a place a chance can
      be understood in, which is the one thing that band is for.

### The arrow has to mean something

- [x] **THE ARROW SHOULD PREDICT THE CHANCE, not just describe the half.** It
      does now — and the way round it had to be done is the interesting part.
      **The arrow read POSSESSION and the engine attributes chances on the
      RATINGS.** Two formulas: possession carries the rating gap, the TACTIC and
      the swing, while `generateMatchEvents` weights attribution on the ratings
      alone. So a side set up to keep the ball moved the arrow and got no more
      of the chances for it, which is exactly "the arrow doesn't mean anything".
      **The first attempt weighted the CHANCES on possession and the harness
      refused it** — thirty-two rows of `match_orchestration_parity_test`, which
      compares the feed against the JS's own. That is the harness doing its job
      and it settles the direction: the engine is the JS's, the arrow is the
      port's, so the arrow is what moved. `LiveStats.dangerHome` is where the
      chances are coming from, off the same ratings the engine uses, and
      `momentumBias` reads that instead of possession.
      **And the counter exception is what stops it reading as a foregone
      conclusion.** Only the side with LESS of the ball can counter — that is
      what the word means — and it closes a share of the GAP rather than taking
      a share of the leader's play: at the first draft's strength a countering
      underdog OVERTOOK the side dominating the game, which is not a counter
      attack, it is a different match. How far a side leans into it is read off
      its tactic's own possession figure rather than named by id, so a side
      expecting 30% of the ball is playing for the moment it wins it back and
      one expecting 62% is not countering anything.

### The squad page, and the index

- [x] **THE CARD BOTTOMS ARE STILL DARK IN LIGHT MODE — and it was the CHIPS,
      not the scrim.** The 27 Aug entry closed this as "could not reproduce"
      because it checked the caption scrim, which really had been fixed and
      really does follow the theme. What is dark at the foot of a light card is
      the TIER CHIP sitting on that white band: `#3d2000`, in both themes, with
      a note above it explaining that the chips stay dark so the pale rarity ink
      reads on top.
      **Swapping ground and ink does not work**, which is why the note was
      written in the first place: four of the nine tier accents are `#ffaa00`,
      `#00c8ff` and friends, and none of them carries on white. So light mode
      inverts the JOB of the pair instead — contrast comes from near-black ink,
      the same `captionInk` the name beside it already uses, and the tier is
      carried by a pale TINT of its own colour. Dark mode is untouched.
      **The lesson is the diagnosis, not the fix**: "could not reproduce" was
      reached by checking the thing the previous fix had touched. A report that
      comes back after a fix is usually a second cause in the same place.
- [x] **THE INDEX'S UNKNOWN CARDS ARE TOO DETAILED.** They are a locked slot
      now — `❓` over the art, the TIER and the GENDER and nothing else. A
      silhouette is still the card: its build, its stance and its haircut all
      read at a glance, which gives away the thing the page exists to make you
      want. **The recipe dialog one tap behind it had already settled this** and
      drew `❓` for exactly this case; the tile was the half that never got the
      decision. The POSITION came off with the portrait — the caption had
      already dropped it while the corner badge went on printing it beside a
      silhouette in the shape of a keeper — and the `×0` went with it, a count
      of nothing not being a fact worth a badge.

### The shop

- [x] **The manager-customisation gem buttons are the wrong blue AND the wrong
      shape.** They are `StoreButton` with `StoreTone.gem` now — the same blue
      every other gem price in the shop wears, with the same face, edge, radius
      and press. **The 27 Aug pass fixed the wrong half**: it made them "a blue
      button with a white gem" and picked its own blue, `ShopSectionId.gems.ink`
      — the SECTION's tint — which left the ten controls that buy a look pack as
      the only buy buttons in the shop that were not the shop's button.
- [x] **And the confirm should say what the pack UNLOCKS.** It said "4 items",
      which is a count of things the player cannot see — the tile has the
      picture and the sheet covers it. **No new copy was needed**: a pack's
      contents are `axis:id` pairs and every axis has had a catalogue label
      (`customise.tab.*`) since the customiser was built, so the summary is two
      Headwear, one Accessory, one Celebration, in ten languages.
- [x] **Quick-fire matches and the free lucky boot say BOTH "already ready" AND
      "coming soon".** Both statements were TRUE, which is why neither looked
      like a bug: the first is the ad GATE reporting itself open and the second
      is there being no ad SDK. The gate's badge goes while the button is dead —
      the cap and the countdown stay, because those are facts about the gate
      whatever the SDK is doing. `paidDisabledReason()` is nullable now so a
      tile can tell a true badge from a lie.
- [x] **They are AD buttons, so they should look like one.** The yellow was
      already right — `StoreTone.ad` — and the ICON was the missing half: the
      coin and gem tones both put their wallet on the button and the ad tone put
      nothing, so the label was a bare verb ("Claim"), which reads as a free
      thing rather than a thing you watch a video for.
- [x] **The starter pack, VIP and the Energy Director are SPECIAL OFFERS and do
      not look it.** A gold rim, a gold wash off the top edge, and the glyph and
      title up with them — everything a shopfront does to the thing in the
      window, and none of it new copy. **The gold is fixed rather than the
      club's accent**: a featured offer is the STORE speaking, not the club, and
      half the kits are a shade of the green the chrome is already made of.
      `featured` is the offers shelf and only that one — a shop where everything
      is special has nothing special in it, and there is a test for that.

### Frame rate, everywhere

- [x] **CHECK EVERY POPUP AND MENU ON EVERY PAGE for dropped frames** — and
      the sweep was not needed, because the cause is structural and covers all
      of them at once. **A modal bottom sheet is a `PopupRoute`**: it rises OVER
      the current route without pushing it out, so nothing in Flutter tells the
      screen beneath that it has stopped being looked at and its tickers keep
      running. On the home tab that is a pitch scene, weather, a ball and a
      walking manager, all animating behind something opaque.
      Every sheet in the game goes through `showBottomSheetPopup`, so that is
      where it is counted — a COUNT and not a flag, because sheets stack (the
      gem shelf opens over a confirm that could not be paid for) and the first
      to close must not hand back the frames the second is still holding. The
      shell switches `TickerMode` off for the covered body; nothing is hidden,
      because there is nothing to see.

### Motion, and how static things read

- [x] **The exclamation mark should almost BOUNCE**, and **there were two of it
      with only one moving.** The home dock's badge has bounced since it was
      written; the floating coach's — the same eighteen pixels, the same white
      ring, the same drop shadow, on every OTHER tab — was a still copy of it,
      which is where the report came from. `CoachAlertBadge` is the one of it,
      in `coach_card.dart` with the rest of his chrome. Reduced motion holds it
      still and does NOT hide it: red on its own still reads, and a badge that
      vanishes takes away the only sign something is waiting.
- [x] **THE MANAGER NEEDS TO BE MUCH MORE ANIMATED**, and **there were two of
      him with only one breathing.** The dugout cam has had a complete idle
      since it was built — four out-of-phase loops driving breath, a weight
      rock, arm sway and a slow scan, tuned per mood — and the manager on the
      HOME screen, who is the one most players look at most, had none of it: he
      walked, and between cues that was the whole of him.
      `ManagerIdle` is that idle, moved out of `dugout_cam.dart` unchanged and
      put beside the walker, where it belongs — it is about the FIGURE, and the
      dependency already ran cam → home for `ManagerWalker` itself. It layers
      UNDER the walk and under any gesture, joint by joint, which is
      `poseOverIdle`'s whole job, so nothing here competes with the stride.
      **No Lottie needed for this half**, and that is worth saying because the
      Lottie note is filed against exactly this ask: what was missing was not a
      recorded clip, it was a driver that already existed one directory away.

### Light mode, again, and it is a pattern now

Four separate reports this sitting, all the same shape: **a colour that was
picked against a dark surface, printed unchanged on a light one.** Dark mode is
right every time, which is the tell — these are not colour choices, they are
missing second choices.

- [x] **An incoming offer is TOO MUCH YELLOW and hard to read in light mode.**
      Two things went. The card's band chip took the theme-aware pair with the
      rest of the reds and greens — and the paragraph of yellow under it, the
      fair-value percentage and the grudge warning in `#FFB74D`, is gone
      entirely; see the bid window below. What is left on that card is Colin's
      read, in the muted ink every other sentence in the game uses.
- [x] **The quests' badges: yellow on yellow, and blue on blue.** The hues are
      the CURRENCIES and were never the problem — a 14% wash of the ink is a
      pale tint of it on white with the ink itself on top. The badge is a dark
      plate in light mode now, the way a scoreboard does it, which is the same
      move the coin figure's halo already makes on this theme. Gold and blue
      unchanged.
- [x] **The home page's reds and greens do not match dark mode's, and should.**
      **The 27 Aug entry found the cause and drew the wrong conclusion from it**:
      it looked for a mismatched pair, found one fixed value used in both
      themes, and read that as evidence there was nothing wrong. One value used
      in both is exactly the bug — the pair was chosen for a dark ground.
      Twenty-eight sites across thirteen files, and the theme-aware pair
      (`vsRedOn` / `vsGreenOn`) had existed the whole time with the stat rows as
      its only caller.
- [x] **The match screen's reds and greens are wrong too**, same cause, same
      fix — the verdict, the table's movement arrows and the energy ladder all
      go through the pair now.
      **And `semanticInk` is the part worth carrying.** Some of those colours
      arrive as DATA — a provider's rows, a table keyed by tier — where there is
      no `BuildContext` at the point the colour is chosen, and those are the
      sites that could not simply call `vsRedOn`. It maps the known dark-mode
      semantics to their light counterparts and hands anything else back
      untouched, so a whole column can be run through it: a gold, a club accent
      and a tier colour are all deliberate and none of them is this bug.

### The squad page

- [x] **The player's image is not big enough.** It is a SHARE of the sheet now
      rather than a constant — 42% of the screen, floored at the old 260 so
      nothing shrinks and capped at 420 so he cannot push the trait block off
      the bottom. A fixed height is the wrong shape for a sheet that is 92% of
      whatever screen it opens on.
- [x] **The trait should look much nicer than it does.** It is a MEDAL now: a
      radial gradient lit from the top left, a 2.2px rim in the accent, a glow,
      and the level stamped on its corner. A 1.4px outlined disc is the shape
      this app uses for a filter CHIP — and the level moved off the block's
      title row for the same reason: a numeral in a header is a specification,
      and on the medal it is what the medal is worth.

### The daily popup

- [x] **It is a bit rubbish, and there is far more room than it uses.** The
      27 Aug pass fixed the LAYOUT and stopped there; what was missing was the
      reason to come back tomorrow. The STREAK is the hero band now — a flame,
      the figure at 34px, the sentence beside it — instead of a 12px grey
      caption under the title. It is the one number on that sheet that is about
      the PLAYER rather than about the prize, and the cycle strip below already
      says what today pays. `getDailyStreak` had gone through two reachability
      audits with no caller in `lib/` at all; it has one.

### The match screen — continued

- [x] **Every item wants the same vertical and horizontal margin, and one
      radius.** `matchInset` and `matchGap`, and the radius belongs to
      `GlassPanel` so nothing draws its own. It was 13, 12 and 14 down the page
      with gaps of 6, 7 and 8 between them.
      **The STAGE is the one exception and it is not a miss**: the pitch is an
      `AspectRatio` centred in its band, so it keeps its shape and gives the
      width back either side. Its padding is the same; its pane is deliberately
      narrower, and the test says so.
- [x] **Colin is at the bottom of the play screen and is hard to see.** The
      26 Aug note already had the answer: of three ways to make him more
      visible, a bigger head was the one never tried. 44px to 60, a heavier ring
      and a real shadow, and lifted clear of the row of buttons he was crowding.
      The position stays a touchline, because that is what he is standing on —
      and floating rather than a band of his own, because a strip that appears
      and disappears shoves the feed about.
- [x] **The commentary wants the GLASS of the end screen.** `GlassPanel` is what
      the summary is built from and the commentary box is not using it.
- [x] **THE BALL GOES TO AN INVISIBLE PLAYER, who then scores or misses.** The
      receiver WAS on the pitch — he had not got there yet. **Two clocks with
      nothing keeping them together**: a receiver is a body steering toward a
      target at his own pace, and the ball is a tween on a fixed duration, so a
      through ball outran its runner and landed on empty grass — and a
      `firstTime` finish then fired from a spot with no player on it.
      `Mover.sprintTo` gives him the pace that MEETS it. Never slower than his
      own legs (a short square ball should not make him amble), capped at a
      sprint (a runner who cannot make it in time is a script asking for a run
      nobody could make, and a figure crossing the pitch in a blink is worse
      than one arriving a beat late), and self-cleaning — he goes back to his
      own pace on arrival rather than every call site remembering to reset it.
      The arithmetic is `meetPace`, pure and pinned, because a Flame loop cannot
      be settled in a widget test.
- [x] **THE DUGOUT CAM COVERS THE PITCH, and a chance straight after is missed.**
      **The grass belongs to the chance**: he gives way the moment a clip
      starts, rather than sharing it. The shot he loses is a reaction to
      something already over and the thing replacing it is happening now, which
      is the whole argument. And the window is smaller — 0.34 of the pitch's
      width rather than 0.44 — because nearly half of it is not a cut-in, it is
      a second picture. The inline shot keeps its width: it covers nothing.

### The bid window

- [x] **LOSE THE "367% OVER FAIR MARKET" LINE, and lose "declining will make
      {team} play harder" with it.** Both gone. **This partly reverses the
      27 Aug entry**
      that built the band chip and the colour scale for exactly that percentage:
      it was right that a paragraph of 13px grey was unreadable and wrong that
      the answer was to make the number legible. A figure a player cannot act on
      is not made useful by a chip. Note the consequence and take it knowingly —
      the five `transfer.market.*` band names and the grudge warning go back to
      being shipped copy with no caller, which is normally a bug in this file.
      Here it is a decision, and it is written down so the next sweep does not
      "fix" it.
- [x] **MINIMISING HAS TO BE MORE VISIBLE.** `TransferPill` was a
      `surface`-filled stadium with a 55% accent hairline — the quietest thing
      the palette can draw — above a tab bar the eye already skips. Filled in
      the accent with the accent's own ink now, and it BREATHES on the same
      1.8s period as Colin's unread pulse, because it is the same signal.
      **A halo rather than a scale**: it lives in the shell, where a control
      that grows shoves the tab bar under it.
      **And a repeating controller in the SHELL is a `pumpAndSettle` that never
      returns**, which is the dugout cam's trap in a new place. Reduced motion
      stops the clock and leaves the pill at full strength, so the test pumps
      under that policy — and so does any future test that has a bid parked.
      (The RENAME to "Review" is a separate, still-blocked item — new copy, so
      `en.js`.)
- [x] **AND THE TARGETED PLAYER NEEDS HIGHLIGHTING ON THE SQUAD PAGE.**
      `BidTargetMark` — a ring and the pill's own 💸 — over whatever it wraps,
      so the pitch's `PitchToken` and the bench's `PlayerCard` wear the same
      mark. A mark that looks like one thing on the pitch and another on the
      bench is a mark the player has to learn twice, which is the argument
      `TraitBadge` already settled.
      **Outside the child rather than over it**: the card underneath is already
      the club's colours, and a wash on top would say "selected", which is a
      thing the player did rather than a thing that happened to them.

### The full-time summary — continued

- [x] **The 2× offer, with its coins, belongs at the BOTTOM beside the button
      that answers it.** And it has a card of its own now — it was the one
      figure on the report drawn straight onto the sky, under a column of
      panels, so the biggest number on the screen read as a caption. A figure at the top and the button that changes it at
      the foot is one decision split across a scroll.
- [x] **The quests go to the very bottom** — then, on the next report, BESIDE
      the manager instead, so the whole thing fits one screen. The shot went
      smaller to pay for it; it is a reaction, not a portrait.
- [x] **Which is all so THE TABLE IS VISIBLE** — see the top of this section.
      The point of the animation is watching your club shove everyone else down,
      and it cannot be the part below the fold.

### The home screen

- [x] **Colin's head fills the circle now and that reads wrong.** The 27 Aug
      fix was right and overshot: it was letterboxed, `cover` off the top fixed
      that, and it cropped the crown flush to the rim. A 3px inset and an
      alignment off the very top — with `cover`, padding shrinks the box the
      crop fills rather than letterboxing it, so the air is real and the disc is
      still full.
      **This reverses the 27 Aug entry** that made the image fill the orb: it
      fixed a portrait floating in a band of dark glass, and it has overshot —
      a face cropped to the rim has no air round it. What is wanted is between
      the two, so it is an inset and an alignment rather than a `BoxFit` swap.
- [x] **THE CUSTOMISE SHEET DROPS FRAMES, and this is the third report of it.**
      **The reporter was right twice and the first profile was measuring the
      wrong thing.** It profiled the BUILD — 209ms on the tapped frame — and
      concluded the grid was the cost; the reading offered both times since was
      that it is ANIMATION, and it is: the whole home screen was still running
      behind an opaque sheet. See the entry above for the fix, which is one
      change and covers every sheet in the game rather than this one.
      **The lesson is the diagnosis.** A frame-time number that does not say
      WHICH of build, layout or an unrelated ticker it came from is not a
      measurement, and the first pass wrote its number down without that.
      See the two entries above under `The home screen` (27 Aug) and the
      follow-up beside them: the first pass measured a single 209ms BUILD and
      concluded the grid was the cost. **The reporter's reading both times since
      is that it is ANIMATION, not building** — several rigs running at once —
      and the fixes named are to **pause the ones nobody is looking at**, or,
      better, **to drive the manager rig from a Lottie clip instead**.
      Two things to know before starting. The measurement that exists only
      covers the grid's twenty STILL walkers, which register no tickers at all;
      it says nothing about the hero rig in the sheet or the one on the screen
      behind it, and `TickerMode` for the covered route is the first thing to
      check. And the walker entry under `The walker` (27 Aug) is the argument
      against Lottie *for the walk* — the current rig is SOLVED, which is why
      the planted foot does not slip and why the ground and his legs share one
      clock; a recorded clip gives that up and the ground would have to be
      driven off the clip's timeline. **That argument is about the walk. It is
      not an argument against a Lottie clip for a manager who is standing
      still**, which is what the customiser's chips are, and that is the cheap
      half of this if the diagnosis holds.

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
- The remaining art: `gemArt` (146) and `svgCache`'s SVG half (54). The shop's
  gem packs no longer wait on the first of these — see `gem_pack_art.dart`.

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
- [x] **Finishing Goalkeeper Practice can DRAIN an upgraded energy tank.** Fixed,
      and it is a deliberate divergence from the JS rather than a port fault —
      the JS clamps to `ENERGY.MAX` too, so **the parity fixture keeps its wrong
      answer and the test names the row that diverges**, which is the shape
      `kit_theme_test` already uses for the ink bug.
      **The clamp stays and the CAP moves**, which is the distinction: the grant
      is a tunable and a future one must not be able to overfill the tank. What
      was wrong was clamping to ten when the player had paid for fifteen.
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
- [x] **The transfer LIST is a dead end in the JS too.** Re-checked with the spec
      repo on disk: `listPlayer` and `unlistPlayer` are declared in
      `negotiationEngine.js` and called by nothing but their own test, exactly
      as recorded. **The decision stands and this row is closed** — giving it a
      UI is adding a feature to the game rather than porting it. The original
      note follows. `listPlayer`,
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
      **The shop's three gem packs are no longer waiting on this.**
      `gem_pack_art.dart` draws a pouch, a casket and a hoard from two
      primitives, because every bundle wearing one identical gem icon was a
      reported fault and the JS could not be read from a cloud session. So this
      item is now about the OTHER gem art, and about checking those three
      compositions against `gemArt.js` — not about an empty shelf.
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
