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
- [x] The merged-into float — `grid.merged_into` ('✨ {name}!'), which names the
      tier a merge produced at the cell it landed in. The burst says something
      happened; this says what. **Done**, and it is the JS's own label: 1.4s,
      a 40px climb, and `#76e876` whatever the kit is — the same "you gained
      something" green the income floats use, and a label that changed colour
      with the club would stop meaning that.
      **Outside the burst rather than inside it**: the burst scales and squashes
      its child, and a label squashing with the card reads as part of the card
      rather than as something rising off it. The NAME is held for the length of
      the float, so a second merge landing elsewhere cannot rewrite it half way
      up. Reduce motion keeps the words and drops the climb — what the merge
      produced is information, the rise is not.
      **And `tierName` is one function now.** It was private to the player index;
      two copies of "what is this tier called" is how one screen ends up
      translated and the other does not.
- [ ] Lazy card mounting — only if a profile run asks for it
- [x] **A COUNT WAS ANNOUNCING MERGES THAT NEVER HAPPENED.** `mergeablePairs`
      answers "what would Merge All eliminate" by running a sweep against a COPY
      of the cells — "asking the question must not answer it" — and the copy
      protected the grid but not the BUS. Every probe merge fired
      `merge:complete`, whose listener re-syncs the lineup and writes to the
      save, so the number on the button wrote to the save on every rebuild.
      It surfaced as a CRASH rather than as drift, which is the only lucky part:
      the count is read by a provider, so the write bumped the save revision
      from inside another provider's build and Riverpod refuses that outright.
      `announce: false` is the probe flag; a real sweep still emits.

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
  - [x] Rename (`.detail-rename-btn`) — built as `_RenameButton`, and the row
        was stale rather than open.
  - [x] The market-value BAR — the price was there and the coloured gauge was
        not. **Done**, on the sell sheet where the decision is made: the JS's
        own five-stop red-to-green track with a white marker on it.
        **The figure alone says what a sale is worth and nothing about whether
        it is a GOOD one**, which is the entire decision the market clock
        exists to create — a position on a coloured track says it without a
        legend.
        **The top of the scale is the best rung PLUS a half**, which is the JS's
        own `MARKET_TIERS[4].mult + 0.5` and is not arbitrary: a roll lands on a
        rung and adds a little on top, so the jackpot's 2.8 is the FLOOR of the
        best band. Ending the bar at 2.8 would peg every jackpot at the far end
        and make the best outcome in the game look identical to the second best.

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
- [x] The parallax scene behind him — **and it evolves with the STADIUM, which
      is what the JS actually does.** Its own header says "the background
      evolves with the division tier" and this row copied that; the code reads
      `clubAssets.STADIUM.tier`, and so does the port (`stadiumTierProvider`).
      Worth writing down, because a future pass comparing the two would have
      found the comment first and "fixed" a scene that was already right.
- [x] **CUSTOMISE badge** → the manager customiser. Built — the pill between the
      two orbs (`dock-customise`), opening `manager_customiser.dart`.
- [x] **Prestige orb, when a prestige is available.** Built — and this line and
      `home_dock.dart`'s own header agreed about it independently, which is what
      made it safe to place from a container that cannot read the JS. The whole
      system was unreachable behind it: `canPrestige` and `performPrestige` had
      no caller in `lib/`, fourteen `prestige.*` strings were translated ten
      times over with nothing able to print one, and three achievements read a
      level that could never rise. `ui/popups/prestige_card.dart`.
- [x] Daily-reward orb with its streak count. **The ORB stays in the burger** —
      that is the port's own documented divergence, nine of the JS's ten orbs
      moved in there and only what INTERRUPTS was left on the scene. What was
      genuinely missing is the half that matters: the STREAK, which was legible
      only once the sheet was already open, one tap too late to be the reason
      for the tap. It is on the Daily tile now, in the `badge` slot the table
      tile already uses for a live value.
      **From two days, not one.** A streak of one is not a streak, it is today —
      and a "1" every morning after a missed day would report a run the player
      has just lost as if it were an achievement.
      **A flame rather than a word, and that is a constraint not a preference:**
      the catalogues are generated from `../merge-empire-fc`'s own `en.js` so no
      new key can be minted here, and the one shipped string — `daily.streak`,
      "{n}-day streak" — is a sentence, which on a 54pt tile is four words of
      nothing.
- [x] The news ticker — built, in `event_strip.dart`: the NEWS chip and the
      headlines strung into one line that scrolls right to left, off
      `deadline_news_engine.dart`.

## Club — `screens/ClubScreen.js`

- [x] Seven facilities, build and invest, tier bar, refusals explained
- [x] Facility artwork, dimmed when unbuilt
- [x] Stadium hero
- [x] **Kit redesign** (`.kit-redesign-btn` → swatch grid) — `kit_picker.dart`,
      built and reachable. The row under the hero, a five-across grid of
      colours, locked ones included, and the striped kits deriving their swatch
      from the same bands the shirt is painted with.
- [x] **Upgrade-path ladder** (`.asset-open-path`) — `asset_ladder_sheet.dart`,
      built and reachable off the tier badge on the facility's art.
- [x] **Club stats block** (`.club-stats`) — `club_stats_panel.dart`, built.
- [x] **Hold-to-invest.** The JS's own 500ms to arm and 150ms a tick, and it is
      on `StoreButton` rather than at the call site because the button already
      owns the press — so any priced control can have it.
      **Two things it has to get right and neither is the repeat.** A hold that
      fired immediately would make every ordinary tap spend twice; one that also
      fired `onTap` on release would spend an extra time at the end. So the tap
      moved to the RELEASE, and a press that armed the repeat swallows it.
      **And the gesture handlers stay attached when the button goes dead**, with
      the check moved inside them. Dropping them on `dead` looks tidier and is
      wrong: the last affordable upgrade kills the button DURING a press, which
      loses the recogniser mid-gesture and reports the release as a spontaneous
      cancel.
      The repeat spends WITHOUT the tier-up splash — a full-screen celebration
      arriving mid-hold stands between the player and the button they are still
      pressing. The splash on release is the tap's job.

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
- [x] **Lucky Boot ad button** (`.lucky-boot-ad-btn`) — built, on the free
      shelf, with its own HELD state: a boot already waiting is not capped, it
      is there, and a second would overwrite it.
- [x] **Match-cooldown ad button** (`.match-cooldown-ad-btn`) — built, with the
      cap of its own (three a day) on top of the shared frequency gate.
- [x] ~~The premium section's emoji header~~ — **the row misread the key.**
      `shop.section.premium_emoji` is not a header: it is the VIP tile's RIBBON
      fallback, shown when the product has no bonus line of its own. Chasing it
      found the real gap, which was much bigger.
- [x] **THE OWNED AND ACTIVE STATES ON THE THREE PREMIUM TILES.** Seven
      `shop.vip.*` keys shipped in ten languages with no caller, plus
      `shop.owned_check`, `shop.owned_regranted` and the Energy Director's
      active note — a state machine the JS draws on three tiles and the port
      drew on none. Every one of them printed its price and a live Buy button
      whatever the save said.
      **It stopped being cosmetic the moment the tiles could actually buy**: a
      player who owns the Starter Pack was being offered it again, and the
      purchase now gets as far as `initiatePurchase` before being refused
      `already_purchased` — a dead end reached by pressing the thing the shop
      was pointing at.
      **VIP has three states and the middle one is the interesting one.** Active
      and never-bought are obvious; LAPSED — it ran and has run out — gets its
      own ribbon and its own line, because a player who has paid once is the one
      most likely to pay again and the tile is the only place that can say so.
      And the Energy Director is owned by its EFFECT (`energyUpgraded`) rather
      than by a receipt, because that flag is what every other reader checks; a
      second source for "do they have it" is how a restore and a purchase come
      to disagree.

## Match — `components/MatchPopup.js`

- [x] Scoreboard, feed, skip, close
- [x] The 2D cutaway on a persistent pitch
- [x] **The match quest track, judged and paid at full time.** All three, with
      what was missed as well as what was won. `resolveMatchQuests` had no caller
      and `rollMatchQuests` had none either, so the track was empty for every
      match ever played — see the method note.
- [x] In-match subs — `subs_panel.dart`, behind the Subs button, with the
      kickoff lineup captured because it has to go back.
- [x] In-match tactic changes — `applyStrategy`, on its own cooldown, and the
      remainder of the match is genuinely RE-DECIDED rather than re-labelled.
- [x] Stats tab — **as a different affordance, deliberately.** The statistics
      used to be the stage's resting state, which is what made the pitch flip in
      and out; the port made the SCOREBOARD the door instead. It costs no height
      at all, and the numbers are what the panel is about, so tapping them to
      see more of them is where a hand goes anyway.
      **`match.tab.stats`, `.commentary` and `.tactics` therefore have no caller
      and should not** — they name a tab strip this port does not draw. Recorded
      here so a future sweep of uncalled copy reads this rather than building
      one.
- [x] Tactics tab — same: the tactic picker is a control on the screen rather
      than a tab of its own.
- [x] The doubling offer on the closing screen — built in `match_summary.dart`
      on the `double_match` placement, with the rewards deferred for it exactly
      as `play_button.dart` set up. One tap only: a second while the video is
      opening would double twice.

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
- [~] The shootout, kick by kick. **The kicks now reach the screen and are
      drawn; the JS's animated step-through is not ported, deliberately.**
      The engine has always simulated a shootout kick by kick — sudden death and
      all — and `cup_launcher.dart` carried only its three totals, so a drawn
      tie arrived as a bare one-goal defeat the player never saw decided. That
      is `penaltyReveal.js`'s own warning about this field, word for word: "a
      2-2 tie surfacing as lost 2-3 with no penalties shown".
      **IT IS DRAWN, NOT WRITTEN, and that is a constraint rather than a
      style.** The JS's reveal is hardcoded English — "It's going to
      penalties!", "We go through!", "Out on penalties" — with no `t()` key
      behind any of it, and the catalogues here are generated from that same
      repo, so there is no translated copy to port and none can be minted. Two
      totals over two rows of ticks and crosses say the same thing in ten
      languages and say the part that matters: which kicks went in.
      **The step-through went with the copy.** That machinery exists to build
      suspense and the suspense was in the words; marks appearing one at a time
      saying nothing would be a progress bar. Worth revisiting if `en.js` ever
      gains the lines.
      **And it turned up a real bug on the way**, recorded under Players above:
      counting the mergeable pairs was announcing merges that never happened.
- [x] The cup-win celebration, the round-win card and the knocked-out card.
      **Twenty-odd `cup.round_win.*`, `cup.knocked_out.*` and `cup.banner.*`
      strings shipped in ten languages with no caller** — the whole of the cup's
      reaction. A round won and a run ended were the same event from the
      screen's side: a scoreline, a toast, and back to the Play tab.
      **They are the UNLOCK SPLASH, not a fourth shape.** `feature_unlock.dart`
      already makes the argument and it applies word for word: a tier-up and a
      first build are the same kind of event, and giving them different shapes
      would make the smaller one read as a lesser thing. A cup round won is that
      same beat. The elimination takes the same card in RED, which is the whole
      reason it is not simply the same call — the splash is a celebration by
      default, and the same card in green would read as congratulating somebody
      on going out.
      **The JS's button is dropped**: "Bring it on!" does nothing but dismiss,
      and the splash dismisses itself.
      **Which line each earns is told by POSITION, and that bit once.**
      "Quarter-Final" contains the word "final", so sniffing the round's NAME
      called a quarter-final exit a heartbreak at the last hurdle. The round
      index cannot be wrong about it. The win path reads the round AHEAD for the
      same reason: "one win away from lifting the cup" is a thing to say to
      somebody about to play a final, not to somebody who has just won a
      quarter-final, and the difference is one index.
      **And the round is captured BEFORE the commit**, because committing moves
      the round counter — read after, "which round did we just play" is already
      the wrong answer.
- [x] The tie in the fixture list (`cupInsertAt`), and the round badge on the
      next-match card. **The badge was already built** (`fixture_caption.dart`
      names the competition and the round when a tie is due); the LIST was not,
      so a player's fixtures showed only league games and the tie between them
      was invisible until it was the next thing to play.
      **A tie does NOT take a fixture slot.** Cups run between league games —
      the league index does not move for one, which is why a cup season is not a
      league season one match shorter — so the row is INTERLEAVED after the
      league match it waits on rather than replacing one. `cupDueAfterMatches`
      is already the single source both the list and the play button read, so
      they cannot disagree about when a tie is due.
      **And the row looks deliberately unlike a league row**: inset, tinted, led
      by the round rather than by a venue chip. A row that matched its
      neighbours would read as a fifteenth league game, which is the one thing
      the fixture count must not suggest. Before it is played it names the
      COMPETITION, because the opponent is not drawn yet; after, the opponent
      and the score.
      **Writing the test found the guard that protects it**: the migration
      clears an active run whose `startedSeason` is not the current one, and its
      own comment names "ghost scores on the fixture list" as what a leaked run
      looks like — which is exactly what these rows would have shown.
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
- [x] The quest block on the home card — `match_quests_block.dart`, the fifth
      thing on the next-match card, which is where the JS shows the match track
      before kick-off rather than behind the burger.

## Boot popups — `WelcomeBackPopup.js`, `DailyRewardPopup.js`

- [x] Welcome back, with the offline earnings it holds
- [x] **The daily reward, as a SHEET**: the seven-day cycle with today marked,
      the streak, the trained-yesterday bonus, and what a claim actually paid.
      It was a coach card reading "Day 3" — `getDailyRewardPreview` and
      `canRepairStreak` were both ported with no caller, so the cycle and the
      broken-streak branch were invisible, and day seven's gems (the only
      recurring gem faucet in the game) were never advertised.
- [x] The broken-streak branch, with both ways out
- [x] The repair itself and Claim ×2. **BOTH LIVE** — the ad SDK is in, and
      `daily_double` and `streak_repair` had both been real unit ids in
      `ad_units.dart` with no caller since the units landed. `repairStreak` was
      a ported engine function with no caller since before that, so the one way
      back from a broken streak was present, dead, and explained.
      **An unavailable ad claims NOTHING, not even at the single rate.** The
      player asked for the doubled one, and quietly giving them half of it
      spends their day's reward on a choice they did not make — the single-rate
      button is still right there. Backing out of the video is the same: a
      choice, not a fault, so nothing is owed and nothing is said.
      And the engine decides whether a streak CAN be repaired; the sheet only
      asks for the video. A second answer to that question is how a window comes
      to disagree with itself.

## Settings — `screens/SettingsScreen.js`

52 interactive elements in the JS, the most of any screen after the events.

- [x] **Diffed control by control**, against the JS's own bound selectors — the
      thirty-four `addEventListener` targets in `SettingsScreen.js` rather than
      a count of tags, because a selector nothing binds is decoration.
      **Everything is there**: the six toggles (account, light mode, music,
      notifications, rankings, rankings-visible), the three rows (auto-tier,
      rename, team names), the four buttons (privacy, rate, reset, full reset)
      with their confirms, the four segmented groups (difficulty, pitch view,
      speed, volume), the language grid and the tab strip.
      **One thing was genuinely missing and it was not a control**:
      `[data-notif-warn]`, the hidden note under the notifications toggle.
      `settings.notifications_blocked` ships in ten languages and had no caller,
      so a toggle that is ON while the phone refuses read as working while
      nothing could ever be delivered — indistinguishable from a broken feature,
      which is what the JS's own comment on that line says.
      **It is CHECKED, never requested**, and the two are separate methods on
      the backend for that reason: requesting would put a system prompt in front
      of somebody who merely opened Settings. iOS keeps its silence — the
      plugin has no check-without-ask there — because a warning nobody can act
      on is worse than no warning.

## Mini-games

- [x] Penalty Training (the goal is the target)
- [x] **The keeper is rigged AND he wears the division again.** The original
      tick was for `keeper_figure.dart`: the JS's own illustration, each arm and
      leg turning about its documented joint, posed with `AnimatedRotation`, and
      carrying **eight kit tiers taken from the division** so the opposition
      visibly improves. The scene rebuild replaced that file with a better rig —
      jointed, against regulation geometry — and did not carry the kits over, so
      for a while this division's keeper was HARDER than the last one's and
      looked identical to him. **Nobody removed it; the rebuild simply did not
      port it**, and the dead file kept this item looking honest for as long as
      it sat there.
      The palettes are back, recovered from
      `git show 25ab12c^:lib/ui/screens/minigames/keeper_figure.dart` and
      indexed by division rather than by tier — `keeperKits` and
      `keeperKitForDivision` in `penalty_view.dart`, a third argument to
      `PenaltyView` beside the two ramps that were already there.
      **Seven, not eight**: the sprite's ramp was `2 + divisionIndex.clamp(0, 6)`,
      so its first kit was never on the ramp at all and carrying it here would
      be shipping a palette nothing can pick. Every colour a division wore is
      unchanged.
- [x] Boot Room
- [x] Training Drills, Keepy Uppys, Through Ball, Whack, Teamwork — all five
      built, reachable from the training sheet, and each with its own test file.
      Whack is `pitch_invaders_screen.dart`, which is why a search for the JS's
      name finds nothing.

---

## Still to diff for layout

The same treatment as the shop, against `src/ui/styles/`:

- [ ] Club — `screens.css` `.club-grid`, `.asset-*`
- [ ] Players grid — `grid.css` (872 lines)
- [ ] Match page — `match-page.css` (1,041 lines)
- [ ] Home — `league-scene.css` (4,444 lines, the biggest by far)
- [~] HUD — `hud.css`. **Diffed class by class**, and the port carries every
      chip: the crest, the three resources in one trough, the two `+` buttons,
      the cog outside the trough.
      **One thing was genuinely missing: `.hud-boosts`** — the active-boost
      pills in the middle of the bar. A player with VIP running or an idle
      double going had nothing on the HUD saying so, and the pills need no copy
      at all, which is why they could be ported: the JS writes "×2" and
      "🌟 VIP" with a unit letter after a number and there is not a `t()` in the
      whole function.
      **Only the boosts that affect IDLE INCOME**, which is the JS's own rule
      and its own reason: the pills sit beside the income rate, so what belongs
      there is what changes it. A match-only boost goes in the pre-match prize
      card and the income breakdown instead.
      **The time is the truth and the flag is a hint** — nothing clears
      `incomeBoostActive` on the tick, so an expired boost still carries it.
      Both counts round UP and floor at one: forty seconds left is not "0m",
      which reads as expired.
      **Deliberately NOT ported**: `.hud-prestige`, because the port moved
      prestige to the dock (see `home_dock.dart`), and `.hud-avatar`, because
      the crest here IS the badge button.
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
