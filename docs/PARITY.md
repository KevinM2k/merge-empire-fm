# Screen parity — what the JS has that the port does not

A control-by-control diff of `../merge-empire-fc/src/ui/` against `lib/ui/`.

**Why this exists.** The port was being built screen by screen and the gaps were
turning up as bug reports from playing — which is the slowest possible way to
find them, and unnecessary: the whole source is here. This is the list, taken
from the source rather than from playing, and it is the work queue.

**How it was built.** Every JS screen's interactive elements were extracted
(`addEventListener('click')`, `data-action`, `.btn` class names) and checked
against the `ValueKey`s in the matching `lib/ui/screens/` directory. Ticked
means present and reachable, not merely present.

**Layout counts too.** An earlier version of this file punted on layout as
"needs a device". That was wrong: `src/ui/styles/` is 13,454 lines of CSS and it
states the structure exactly — column counts, backgrounds, which container wraps
what. Diffing it found things the control diff could not, including one case
where the port had added the very thing a CSS comment says was removed. Layout
gaps are in this list.

---

## Players (grid) — `screens/GridScreen.js`, `components/Grid.js`

- [x] Add Player (scout), priced on the button
- [x] Scout batch ×1 / ×2 / ×4, offering only what the save can pay for and house
- [x] Merge All, carrying the pair count **and its price** — half a scout, which
      the port had been giving away free
- [x] Sort by tier, hidden when already sorted
- [x] Drag to merge, drag to move
- [x] Tap a card for the sell sheet
- [x] **The scout REVEAL.** The batch is held back and turned over together,
      each card captioned — voucher pill, auto-sold verdict, gold halo for a
      first-ever sighting — and the marked ones are cashed in only once they
      have been seen. The Scout button is dead for the duration, which is what
      stops a double-tap drawing over a reveal.
      **The fly-to-slot is deliberately not ported**: the port's grid is a
      scrolling `GridView` whose rows are built on demand, so the slot a card is
      going to usually is not mounted, and flying toward a rect that does not
      exist is worse than not flying at all.
- [x] **What a merge COUNTS.** The move was ported and none of the bookkeeping
      was: career totals, `stats.highestTier`, the two merge quests, and a
      rival's pending bid dying with a parent card. See the method note.
- [x] **The auto-sell rules can be SET.** `setTierAction` had no caller at all,
      so a fully tested engine could never fire. The sheet is on the Settings row
      that owns it and on a pill beside the grid's count — the JS's own two
      entry points, and the second matters because the rules fire on the Players
      tab: a scouted card of a switched-on tier never reaches the grid.
- [x] The player-count pill, red at the roster limit
- [ ] The merged-into float — `grid.merged_into` ('✨ {name}!'), which names the
      tier a merge produced at the cell it landed in. The burst says something
      happened; this says what.
- [ ] Lazy card mounting — only if a profile run asks for it

## Squad — `screens/SquadScreen.js`

- [x] The eleven by formation, drag to pick or swap
- [x] Formation picker
- [x] Tactic picker
- [x] Rating / ATK / DEF header
- [x] **Auto-fill / auto-rotate** (`.auto-lineup-btn`). Two different jobs
      behind one button: casual picks the shape that wins the NEXT FIXTURE
      (`bestFormationForFixture`), Pro rotates personnel to the freshest fit
      within the manager's chosen shape and never switches tactics under them.
- [x] **Clear lineup** (`.clear-lineup-btn`)
- [x] **The pitch.** The eleven were floating on the page background — a
      formation-shaped list rather than a team. 7:10, fitted to both axes, with
      the markings drawn in the JS's own `0 0 100 140` space and stretched.
- [x] **The bench is a SHEET**, behind a Subs button. It was an inline strip
      showing three cards and taking a third of a portrait screen.
- [x] **The player detail sheet** — everything below is inside it:
  - [x] Career stats grid, rating and income header
  - [x] Fitness bar (Pro)
  - [x] Sell, with its own confirm — refused for a loanee or anyone out on loan
  - [x] Recall from loan (`.detail-recall`)
  - [x] Send back early (`.detail-sendback`)
  - [x] Swap into the XI / send to the bench (`.detail-xi-btn`)
  - [x] **The trait wheel**, priced on the control. `rollTrait`, `applyTrait` and
        `traitRollCost` were all ported with nothing able to spend a coin on
        them. Refused for a loanee and for anyone out on loan, each with its own
        line: one's trait would go back with them, the other cannot take the
        field.
        **Both reels are `ListWheelScrollView`** — Flutter has the widget the JS
        builds out of DOM strips repeated seven times, and a looping delegate
        plus `animateToItem` gives three revolutions and a landing with no clock
        of our own.
  - [ ] Rename (`.detail-rename-btn`)
  - [ ] The market-value BAR — the price is there, the coloured gauge is not

## Home — `screens/LeagueScreen.js`, `components/PitchScene.js`

- [x] Coach Colin bottom left, burger bottom right
- [x] Play button in the sticky footer
- [x] Event strip
- [x] Table / fixtures / index / quests / training / trophies behind the burger
- [x] **The next-match card.** Who, home or away, and the two ratings either
      side of the VS. Numbers only: it has been five stars (which banded a
      0–100 figure into five buckets, so 61 and 79 drew the same row) and then a
      bar beside the figure, which is the same comparison drawn twice.
- [x] **The walker.** Six keyframe tracks off one clock, linear on the limbs
      and eased on the bob. Honours reduce-motion. Rive was considered and
      dropped — it is paid.
      **He wears the player's own look**: `randomAvatar` had no caller, so every
      save drew one hardcoded man and the look packs the Shop sells had nothing
      to change. A look is generated at boot and stored, as the JS does on the
      diorama's first render, and the rig now draws the JS's OWN parts for
      everything that does not move — hair either side of the skull, beard,
      headwear, glasses, the coat or suit over the kit, a scarf — recoloured per
      look by `data/manager_art.dart`.
      **His MOOD is on his face.** `manager_mood.dart` was ported with no caller:
      how the gaffer felt about the season was a number nobody could see. The
      five mouths are generated from the JS's own `mouthPath`.
      Three things the JS has not got, because the figure is the first thing the
      game shows: a ground shadow that tightens as he rises, an ankle that keeps
      the boot flatter than the shin, and a stride-long sway.
- [x] **The Leaderboard tile**, with the signed-out and offline states the JS
      really shows. The ranked list needs `leaderboardService` (M4).
- [ ] The parallax scene behind him, evolving with the division
- [ ] **CUSTOMISE badge** → the manager customiser. Its parts are generated
      already (`data/manager_art.g.dart`): hair, beard, hat, outfit, neck.
- [x] **Prestige orb, when a prestige is available.** Built — and this line and
      `home_dock.dart`'s own header agreed about it independently, which is what
      made it safe to place from a container that cannot read the JS. The whole
      system was unreachable behind it: `canPrestige` and `performPrestige` had
      no caller in `lib/`, fourteen `prestige.*` strings were translated ten
      times over with nothing able to print one, and three achievements read a
      level that could never rise. `ui/popups/prestige_card.dart`.
- [ ] Daily-reward orb with its streak count. **`getDailyStreak`
      (`daily_reward_engine.dart`) is the count and has no caller** — its doc
      names a HUD chip, this line names an orb, and the port has neither: the
      daily lives in the burger, where the sheet prints the streak once it is
      open. So the engine is not dead, it is waiting on this.
- [ ] The news ticker

## Club — `screens/ClubScreen.js`

- [x] Seven facilities, build and invest, tier bar, refusals explained
- [x] Facility artwork, dimmed when unbuilt
- [x] Stadium hero
- [ ] **Kit redesign** (`.kit-redesign-btn` → swatch grid). The row under the
      hero, a five-across grid of colours, locked ones included, and the striped
      kits deriving their swatch from the same bands the shirt is painted with.
      The Shop sells colours that currently cannot be chosen.
- [ ] **Upgrade-path ladder** (`.asset-open-path`) — what the next tiers give
- [ ] **Club stats block** (`.club-stats`)
- [ ] Hold-to-invest

## Shop — `screens/ShopScreen.js`

All seven shelves are present and in the JS's own order.

- [x] Offers, Gems, Coins, Boosts, Vouchers, Free, Looks
- [x] Restore Purchases (present, disabled — needs the billing bridge)
- [x] **Layout.** The tiles were `ListTile`s in a `Column` — a settings screen
      rather than a shop. They are centred cards in a grid now, glyph on top,
      button pinned to the bottom so every button in a row lines up whatever the
      text above it does, and the description clamped to two lines because
      otherwise one long one sets the height of its whole row.
- [x] **Per-shelf colour.** Each section has its own ink — offers amber, gems
      blue, looks purple. The port painted all seven in the club's accent, which
      made the shop one undifferentiated list.
- [x] **No disc behind the section icon.** The port had added a tinted circle;
      the CSS comment says in as many words that it was taken OUT, because a
      frame round a glyph competes with the card's own edge and shrinks the art
      to pay for it.
- [ ] **Lucky Boot ad button** (`.lucky-boot-ad-btn`)
- [ ] **Match-cooldown ad button** (`.match-cooldown-ad-btn`)
- [ ] The premium section's emoji header (`shop.section.premium_emoji` — the one
      section key the port does not use)

## Match — `components/MatchPopup.js`

- [x] Scoreboard, feed, skip, close
- [x] The 2D cutaway on a persistent pitch
- [x] **The match quest track, judged and paid at full time.** All three, with
      what was missed as well as what was won. `resolveMatchQuests` had no caller
      and `rollMatchQuests` had none either, so the track was empty for every
      match ever played — see the method note.
- [ ] In-match subs
- [ ] In-match tactic changes
- [ ] Stats tab
- [ ] Tactics tab
- [ ] The doubling offer on the closing screen (the rewards are already deferred
      for it — see `play_button.dart`)

## The domestic cup — `_playCupMatch` in `LeagueScreen.js`

- [x] **A cup tie is playable.** `prepareCupRound` and `commitCupRound` had no
      caller, so a club auto-entered into its division's cup at the season
      boundary could never play a round of it. The Play button offers the round
      by name when one is due — a tie sits BETWEEN league games, so it inserts a
      match rather than costing the league a fixture.
- [x] The feed plays the ninety minutes and not the shootout, whose winning goal
      the engine folds into the scoreline
- [x] The prize, the bracket, the fitness charge and the match quests, all at
      full time
- [x] The sponsor a win can drop, offered rather than applied — `acceptCupSponsorDrop`
- [ ] The shootout REVEAL (`components/penaltyReveal.js`), kick by kick
- [ ] The cup-win celebration, the round-win card and the knocked-out card
- [ ] The tie in the fixture list (`cupInsertAt`), and the round badge on the
      next-match card
- [ ] In-match tactic changes rewrite a cup scoreline in the JS, which is what
      its commit carries the popup's final goals for. `PreparedCupRound` is a
      record and cannot be mutated, so a screen that can change a result will
      have to hand the goals in — see the note on `settleCupRound`.

## Quests — the block in `LeagueScreen.js`

- [x] The season track, claimable, with its progress
- [x] **Rolled at boot**, not only at a season boundary — a fresh save reached
      the sheet with an empty season track and the "no quests" line, and stayed
      that way until its first season ended
- [x] **The match track**, rolled for the next fixture when the sheet opens, and
      pinned to it so reopening does not redraw what has just been read
- [x] Reroll, free twice a season and then gems, refused when nothing is left to
      swap
- [ ] The quest block on the home card, which is where the JS shows the match
      track before kick-off rather than behind the burger

## Boot popups — `WelcomeBackPopup.js`, `DailyRewardPopup.js`

- [x] Welcome back, with the offline earnings it holds
- [x] **The daily reward, as a SHEET**: the seven-day cycle with today marked,
      the streak, the trained-yesterday bonus, and what a claim actually paid.
      It was a coach card reading "Day 3" — `getDailyRewardPreview` and
      `canRepairStreak` were both ported with no caller, so the cycle and the
      broken-streak branch were invisible, and day seven's gems (the only
      recurring gem faucet in the game) were never advertised.
- [x] The broken-streak branch, with both ways out
- [ ] The repair itself and Claim ×2, which need a rewarded ad (M4). Both are
      present and disabled rather than hidden.

## Settings — `screens/SettingsScreen.js`

52 interactive elements in the JS, the most of any screen after the events.
Not yet diffed control by control.

- [ ] Diff it

## Mini-games

- [x] Penalty Training (the goal is the target)
- [x] **The keeper is the JS's own illustration**, generated the way the club and
      manager art were, with the **eight kit tiers taken from the division** so
      the opposition visibly improves. He was five flat rectangles with the arms
      permanently out. Rigged as the JS rigs him — each arm and leg turns about
      its documented joint — and posed with `AnimatedRotation`, so a low shot
      lays him full-length and a high one only leans him.
- [x] Boot Room
- [ ] Training Drills, Keepy Uppys, Through Ball, Whack, Teamwork

---

## Still to diff for layout

The same treatment as the shop, against `src/ui/styles/`:

- [ ] Club — `screens.css` `.club-grid`, `.asset-*`
- [ ] Players grid — `grid.css` (872 lines)
- [ ] Match page — `match-page.css` (1,041 lines)
- [ ] Home — `league-scene.css` (4,444 lines, the biggest by far)
- [ ] HUD — `hud.css`
- [ ] The glass treatment — `glass.css` (983 lines), which is app-wide

---

## Method note

Three engines were found with no caller at all — `recordDiscovery`,
`maybeGenerateOffer`, and the idle `transfer:offered` listener. A control audit
does not catch those, because the control is not missing; nothing calls the
engine behind it. **Grep for who calls an engine, not just for who reaches a
screen.**

Three more turned up the same way while the grid was being finished, and they
are the reason that rule is here twice:

- **`trackEvent` — the action funnel — had no caller anywhere.** Both consumers
  sit behind it (the season quest track and any live event's reward track), so
  `season_scout`, `season_merge` and `season_merge_hard` could never advance, and
  no scout or merge ever reached an event's rewards. Every quest LOOKED right:
  the definitions, the track, the sweep and the payout were all ported and
  tested. Nothing counted.
- **`applyTierAction` had no caller**, so the auto-sell rules the Settings screen
  writes did nothing whatsoever.
- **`notifyCardRemoved` was not called on a merge**, so a club that had bid for
  either parent was left waiting on a player who no longer existed.
- **`prepareCupRound` and `commitCupRound` had no caller**, so the whole domestic
  cup was unplayable — and `endSeason` enters the player into one every season,
  so a bracket sat there for the length of a campaign with no way into it.
- **`resolveMatchQuests` and `rollMatchQuests` both had no caller**, so the match
  quest track — three quests a fixture, each with a payout — was never drawn,
  never shown and never judged. `rollSeasonQuests` was called only at a season
  boundary, so a new save's season track was empty until its first season ended.

The pattern in all of them: the ENGINE was ported, tested and correct, and the
line that calls it was in a JS screen that had not been ported yet. When a screen
is ported, the engines it called are part of the port — grep the JS screen for
what it imports, not just for what it renders.
