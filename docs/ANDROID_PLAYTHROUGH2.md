# Android playthrough 2

The rows a player wrote down playing the build on an Android phone. A row is
ticked when it is fixed **and** pinned by a test; the note after it is what was
actually wrong, because that is the part worth keeping.

## Where this queue stands

**37 done, 15 open.** The nine that are done were each a real defect with a
mechanism behind it, and three of them were shipped code doing nothing: a
`strategyId` nothing ever wrote, a `skyPaneTint` with no caller, and a turf band
whose whole job was hiding a seam it was itself making.

The seven still open split into two piles and the split is worth keeping. Three
are **one job**: the scene is painted by a handful of very large `paint()`
methods, and animating hair, stopping the customiser stuttering and fixing the
dugout's hanging arms are all downstream of taking that apart into layers — with
the Spine question sitting on top of the same work. The other three are
ordinary and independent, and two of those four need a device or a recording
rather than a change.

---

## Done

- [x] **The coins on the end-of-match screen are the HUD's badge.** (It was a
      `#1A1F26` plate carrying `gameGold` on a light page and a 12% gold wash on
      a dark one — two grounds and a vivid figure, which the bar itself gave up
      on four rounds ago. `hudBadgeColour`/`hudBadgeInk` now, as `HudChip` and
      the daily reward's chips already do. The light-mode contrast sweep needed
      an exemption for the pair, matched by construction rather than by hex, and
      the argument for it is the one `hudBadgeInkTarget` already records.)

- [x] **A tactic picked on the next-match card reaches the match.** (`playMatch`
      never stamps a `strategyId` — neither does the JS's — because
      `reSimulateRemainder` is the only thing that writes one and it only runs
      on a mid-match switch. The screen read the result alone, so every kickoff
      was Balanced: the strip lit the wrong chip, the scoreboard's ATK/DEF
      carried the wrong multipliers, the arrow read a tactic nobody chose, and
      the player's first pick on the strip was silently a no-op. The JS's
      `MatchPopup` opens on `state.squad.strategyId` and now so does this.)

- [x] **An injury's replacement keeps his place; an ordinary sub does not.**
      (Asked for in those terms. Restoring the kickoff eleven put every slot
      back unconditionally, so the cover a manager chose for a casualty was
      thrown away and refilled with whoever the bench sweep picked — and
      `cleanLineup` deliberately does NOT drop an injured card, so a man hurt
      after the snapshot went straight back into the side. The rule is
      `restoreKickoffLineup` in `lineup_engine.dart` now, where it can be tested
      without a match running: a slot that held somebody goes back, a slot that
      held nobody keeps the cover, and nobody comes back injured. It also runs
      at every full time rather than only after a sub, which is what stops a
      casualty's hole carrying into the next fixture.)

- [x] **The coach shows the swap he is confirming.** (The card was the heading
      `match.subs` over the FEED line — the sentence written for the commentary
      after the change has happened — so a confirmation that decides who plays
      the rest of the match read as "Subs" and a caption. It is the two player
      cards with an arrow between them now, the same `PlayerCard` the bench
      sheet was just tapped in, with the line kept underneath. No new copy: no
      `t()` key can be added from this repo without the spec's `en.js`.)

- [x] **The Quarter-Final label is white in both themes.** (The cup face is a
      fixed purple→amber and the ink was still `playButtonInk(kit.accent)` — a
      colour derived for a face that is not there, which on a dark club came out
      a deep variant on deep purple. The one face that is the same in both
      themes gets the one ink that is, with the stylesheet's own
      `0 1px 3px rgba(0,0,0,0.45)` back under it because the gradient's far end
      is an amber white does not clear on its own.)

- [x] **"World Class", not "WORLD CLASS".** (`settings.autoTier.top_safe`, shown
      on the auto-sell sheet the Players tab opens. Fixed in the spec's ten
      locale files and regenerated — the catalogues are generated, so the fix
      cannot live here.)

- [x] **Pitch invaders: the figure is in front of the hole.** (The tile carried
      a full-width turf band at the mouth's waist drawn AFTER the figure, so
      what actually cut him was a straight horizontal edge across his shins,
      with the arc that was supposed to do it sitting harmlessly below. The cut
      is a `ClipPath` on the figure now — same silhouette, hole drawn once and
      drawn first, and `bandGradient` went with the band it was hiding the seam
      of.)

- [x] **Through Ball: padding, a visible line, and a top league you can play.**
      (Three things. The marker was a flat `Colors.white` on `kit.surface2`,
      which on a daylit page is very nearly white — it existed only while
      crossing the green zone. It is the page's ink in a casing now, and wider,
      because no single flat colour clears the track AND the fixed mid-green.
      The lane gap cap went 30 → 40. And the difficulty was not a matter of
      taste: the marker covers 200% of the bar per sweep, so the window on a
      zone `w`% wide is `w / 200 * sweep`, and Champions Cup ran 42ms down to
      **16.8ms** — one frame. Sunday League runs 324 → 130ms. The new constants
      put the top league at 172 → 69ms, about half the time at every rung.
      Changed in the spec's `miniGames.js` too, with `mini_games_reference.json`
      re-dumped: the fixture pins the whole curve.)

- [x] **The next-match card is more transparent, and the modifiers stay off the
      ratings.** (Two rows, one file. The card took `GlassDensity.deep`'s 43%
      while standing on the scene rather than on a page — `skyPaneTint`, the
      material written for exactly this and carrying no caller, is what it wears
      now. And the modifier row was `MainAxisSize.min` and centred inside a
      rating column that sits in a `Clip.none` stack, so three of them — an away
      grudge against a side in the drop zone — grew straight over the ATK/DEF
      well. They grow outward into the card's own margin now, bounded by the
      clear air rather than by the rating column, which is forty points wider.)

- [x] **The end-of-season screen starts at the top, like full time.** (It was
      vertically centred, which reverses a decision and the reversal was asked
      for. `ReportScroll` was written because a stack of cards over a pinned
      foot left 420 points of nothing here; centring closed that hole and opened
      a different one, because the first card is the RESULT and a result that
      drifts down the page as the report grows reads as the page settling. Full
      time has been `Alignment.topCenter` for exactly this reason since it was
      asked for there, and the inset now matches it too.)

- [x] **The welcome-back card no longer fires after an ad break.** (The only
      gate was "did this earn anything", and thirty seconds of a rewarded video
      earns something the moment the squad has income — so the game welcomed the
      player back from a video it had shown them itself. **Five minutes, not
      thirty**, and the opinion was asked for: thirty is longer than this genre
      uses, because the offline-earnings modal is how a player learns the game
      earns while they are gone, and it usually lands after a couple of minutes.
      What the threshold is really filtering is absences that are not absences —
      an ad, a text, the notification shade, a phone call — and five minutes
      covers every one. Nothing is lost below the line: the coins are paid
      straight in, because they exist nowhere else. `welcomeBackFloorMs` is one
      number to move.)

- [x] **The keeper's elbow no longer snaps across his arm.** (Reported as the
      arms bending the wrong way at the elbow. The two-bone solve picked which
      side to bow with `perp.dx * side < 0`, and `perp.dx` is `-way.dy` — it
      changes sign the instant an arm passes through HORIZONTAL. The TRAILING
      arm does exactly that on every dive, sweeping 158° → 22° through 90°, so
      mid-dive the elbow jumped from one side of the shoulder-to-glove line to
      the other in a single frame. Measured: a 12.8px snap at dive 0.50, and
      either side of it one of the two poses reads as a backwards bend. It is a
      fixed quarter turn now, mirrored between the arms, which is continuous
      everywhere and still right at rest. Note the figure is the PENALTY
      keeper — Goalkeeper Practice is the keeper's-eye view and has no figure in
      it at all.)

- [x] **The pitch says whose end is which.** (Asked as a question — "does the
      arrow point the right way? I started dominating as away team but it was
      pointing to the right." It was, and the tests already pinned it:
      `ourSideLeft = isHome`, the clips mirror off the same flag, and the
      scoreboard reads home-side-left. The defect is that a pitch's markings are
      SYMMETRIC, so "pointing right" carries no information unless you already
      know which end you are attacking, and nothing on the grass said. Each goal
      now carries the defending club's name, painted on the turf in the mown
      stripe's own green — passed in the SAME two expressions `_Scoreboard`
      takes, so the board and the pitch cannot disagree by construction.)

- [x] **The dugout manager's arms hang instead of holding a stride.** (Exactly
      as reported — "one behind and one in front, almost like it's a pause of
      him walking forwards" — and that is what it was. The idle swung about
      `armNearRest`/`armFarRest`, and `gesture_poses.dart` says what those are
      in as many words: *the walk cycle's own mid-swing values*, +27 and −27.
      A fifty-four degree split is a stride, and the idle's own sway of 1.6°
      on top could not touch it. The stand has its own pair now —
      `camArmNearRest` / `camArmFarRest`, eleven degrees apart so the far arm
      still reads behind the near one — and the gestures keep the walk's pair,
      because a gesture returns to the angles it was authored from.)

- [x] **The stadium's decks are depth layers.** (Asked for in as many words:
      the closest is layer one, layer two a little smaller and further away, and
      the same for layer three. They were three bands at ONE size stacked
      vertically with a balcony wall between them, which reads as a single very
      tall bank of seats rather than a ground with tiers in it. Each deck now
      carries a `deckDepth` — 0.88 per step back, so a three-decker's top tier
      is 0.774 — and everything in it takes that one number: the fans, the row
      pitch, the deck's own height, and the bounce, which would otherwise pop
      the back tier's heads through the facade above them. Two things besides
      size sell it: a deck further back fits MORE fans across the same width,
      because a distant terrace is denser rather than just smaller; and each
      deck gets its own pass of haze, because what actually sits a tier back is
      the air in front of it.)

- [x] **The hair moves, and the head with it.** (Asked for, and the constraints
      came with it. The head group was ONE cached raster, so a fringe turning
      inside it would have dragged the skull, the beard, the glasses and the hat
      into a repaint every frame; it is four cached bands now, in the order it
      has always drawn in, and a swinging fringe is a matrix on a layer that is
      already rasterised — no painting, no SVG, no clip re-run. The motion is a
      quarter-cycle lag on the bob, about the CROWN rather than the skull's
      centre. **And only the parts that would**: `hairSwayFactor` is a decision
      per style AND per half of it — a crop, a buzz, a shaved head and a slicked
      back style are nought and do not move by a hair; a ponytail's tail is one
      while its front is scraped flat off the face — with the same
      build-stopping completeness rule `hatCrownY` keeps. The head takes a third
      of the travel on the same clock, so the hair reads as follow-through. Two
      guards, both from the same screenshot: the swing is CLAMPED to the tuned
      maximum, because a gesture's head angle is twenty degrees and more and the
      tilt term alone could treble it; and it TAPERS to nothing past 14° of
      tilt, because a head held in a pose has settled hair and 3.2° of
      follow-through with his chin on his chest still opens a parting on the
      side of his skull.)

- [x] **Colin's audio channel is gone from Settings.** (It controlled nothing.
      It was added when his voice rode the SFX toggle, then `flutter_tts` was
      dropped for `ClipVoiceBackend`, which plays a clip when one is there and
      is silent when it is not — and `assets/voice/` holds a README and nothing
      else. A switch and a slider that change nothing a player can hear are
      worse than no row. The keys and the backend stay, so dropping the clips in
      is all it takes; what comes back with them is the row.)

- [x] **The pitch ends say HOME and AWAY.** (Two words that fit a goalmouth at
      any club, where a name has to be shrunk or clipped — and the louder
      answer, because the board above already reads home-side-left, so the grass
      repeats the board rather than being a second thing to cross-reference.
      `play.home` / `play.away` are already the words it uses for the venue.)

- [x] **The match summary's gold coin badge is gone.** (Screenshotted: `+10` in
      a gold pill with Match Prizes `+10` and Match Quests `+0` an inch under
      it — three figures for one payout. The rows are the better place for it,
      because they say which part the ninety minutes earned, so the badge went
      and the rows took the coin glyph. It survives in one case only: a match
      with no quest TRACK has no rows at all, and would otherwise show no figure
      whatsoever.)


### Session two — the couch queue

- [x] **Every coin figure on the full-time report is in the badge.** (The
      payout badge had it; the split rows, the quest tiles and the quest total
      were gold text with a halo — `coinFigureInk` plus `coinFigureShadows` —
      which is the trick for a bright hue on glass and is not enough on a bright
      pane. `CoinBadge` moved out of `match_summary.dart` into
      `widgets/game_icon.dart` on the way, because the sell sheet wanted it too.)

- [x] **No replay control in the match popup.** (`MatchPopup.js` tags a goal's
      feed item with `feed-replay-icon` and the port carried it over. A control
      that stops the clock to replay a passage you are still in the middle of is
      the wrong offer at the wrong moment; the full-time report keeps its own.
      `_replayClip`, `replayClipFor`, `replayGoal` and `_goalAt` went with it.)

- [x] **Half time says what the score MEANS.** (It printed `match.half_time` —
      the same key the row's own HEAD prints — so the interval read "45' HALF
      TIME" over the words "Half Time" and said nothing. `_processEvent` picks
      between `commentary.halftime_ahead`, `_behind` and `_level` off the score
      as the feed has told it; all three were translated in ten catalogues with
      no caller.)

- [x] **Their substitutions reach the feed.** (`buildMatchResult` pushes one
      `opp_sub` per entry in the AI's rotation plan, key and parameters written
      onto the event. `feedOf` had no case for it, so it fell through to
      `default` and the only changes a player ever saw in ninety minutes were
      their own. `commentary.opp_sub`, ten catalogues, no caller.)

- [x] **A commentary line keeps the parameters it was written with.**
      (`TimelineEvent` had no field for `textParams`, so the engine wrote them
      and nothing read them — a grudge match opened by printing the literal
      `{opp}` to the player. `commentary.snub` is the one that reached a screen.)

- [x] **Every feed row says what KIND of thing happened.** (Only half time,
      full time and an injury had a head. `match.subs` heads both substitutions,
      `match.tab.tactics` — shipped copy left with no caller when the tab bar
      came off this screen — heads a tactic change, and `match.chance` went into
      the spec's `en.js` for the one word the catalogues did not have.)

- [x] **A goal against still says GOAL.** (Theirs was headed by their NAME on
      the reasoning that we hold no card for their players — but the head is the
      row's ACTION and `commentary.opp_goal` names them in the sentence below
      it, so the one slot that says what happened was spending itself on a
      repeat.)

- [x] **And ours is GREEN.** (Theirs has been red since the goal card went in;
      ours took `kit.accent`, which is derived from the club's own strip — so a
      club playing in red drew both goals in red, and the one pair of rows on
      the screen whose whole job is to be told apart at a glance were the same
      colour. `vsGreenOn` is a colour rather than a kit.)

- [x] **The club's "Needs x more" button wears the app's coin.** (The last
      emoji on a priced control, left there on the reasoning that a `String`
      cannot carry a widget. True, and beside the point: `{coin}` sits mid
      sentence and moves with the language, so what it needed was a SLOT —
      `coinSlot` and `withCoinGlyph`, with `StoreButton.labelSpans` to carry
      them.)

- [x] **A club card's effect moves on every tap.** (The engine has paid the
      continuous effects per tap since `fractionalAssetTier` — twenty clicks for
      ten per cent is half a per cent a click — but the card and the totals
      panel both read the whole rung, so every tap bought something they refused
      to admit to. `_pct` went to two decimals for the same reason. The Kit
      Sponsor's fatigue half and the Academy's scout discount were still
      stepping against the engine's own documented rule; both now do not. Home
      advantage stays whole: it is rating POINTS.)

- [x] **The funding bar fills, and the figure flashes.** (`_AssetBar` tweens,
      and snaps on a tier-up rather than draining backwards through the reset.
      `_FlashOnChange` lights the line in the facility's own tier colour, and
      only when the rendered text actually changed — a Fan Zone tap mostly moves
      nothing and must not pretend to.)

- [x] **Light / Dark / System.** (One switch called "Light Mode" can only ever
      disagree with the phone. `themeMode` is the new key and `lightMode` stays
      written beside it, because it is the one every existing save carries and
      the only one the JS build reads. `systemBrightnessProvider` is kept in
      step off `MediaQuery` — following the device means REACTING to it.)

- [x] **The penalty screen says swipe.** (`PenaltyGame.js` is shoot-on-tap and
      this rig is not: the drag's LENGTH is the power and its hook is the curl,
      so the one instruction on screen described neither of the two things the
      gesture controls. `game.penalty.instructions_swipe` is its own key — the
      JS's line is still right about the JS.)

- [x] **The settings header stops changing colour on scroll.** (Material 3's
      `AppBar` tints itself the moment content passes under it. Nothing else in
      the app lifts on scroll, so the bar is pinned to the page it heads —
      fixed in `appBarTheme` rather than on the one screen.)

- [x] **Every settings row is one height.** (A segment is a bordered pill and a
      toggle is not; the theme setting becoming a three-way segment is what made
      it obvious. The switch rows came UP to the segment's height.)

- [x] **Privacy options only where consent applies.** (It went from a dead
      "coming soon" to always-live-and-toast, matching `SettingsScreen.js` —
      which is right about the WEB, where one page is served to every region. A
      store build knows: `adConsentAvailable` is the UMP SDK's own
      `privacyOptionsRequired`, cached at boot.)

- [x] **The sell sheet is not a dark slab any more.** (It was `#14171B` in both
      themes because the figure on it is gold and gold has to sit on something —
      the right answer to the wrong question. `CoinBadge` carries its own
      ground, so the panel went back to `kit.surface2`.)

- [x] **The league move's row keeps its ink when it lifts.** (The row is painted
      in the club's accent at 92% and its text stayed `accentBright`, a lighter
      member of the same hue — so the one row the block exists to pull out could
      go dark-on-dark or light-on-light depending on the kit. It lerps to
      `kit.accentInk`, which the theme already measured for exactly this.)

---

## Open

### One job: the scene is one big `paint()`

These three are the same piece of work seen from three angles, and doing them
separately would mean doing the hard part three times.

- [ ] **Draw the background in LAYERS, not one `paint()`.** **Half done** — the
      STADIUM TIERS are layers now (see Done), and the rest of this row is the
      manager. Split him body/torso/clothes, head, hair, eyes/mouth,
      accessories, as a stack: `RepaintBoundary` per layer, pass the
      `Listenable` to the painter, cache the expensive work, `canvas.save` /
      `restore` sparingly and no `saveLayer` every frame.
      **Two things on this row turned out to be already done, and are struck
      rather than carried:** the scene is not one big `paint()` — `pitch_scene`
      is seven separate painters, each with its own `shouldRepaint` — and SVG
      paths are already memoised by their `d` string in `svg_canvas.dart`, so
      "convert SVG to Dart Path to avoid parsing" buys the first frame only.
      What is genuinely left is the MANAGER's layering, which is what the hair
      row below needs.
- [ ] **DECIDE ON SPINE.** Asked for directly: the manager is too static and a
      bit boring, the dugout cam with him, and the shop's coins and gems could
      use something better. Researched rather than guessed — see **Spine** at
      the foot of this file for the licence, the price, what is actually in the
      examples and what it would cost this repo. Short version: the licence is
      a real gate, `mix-and-match` IS the manager customiser, and the example
      ART cannot ship but the example RIGS can. **The penalty keeper is a third
      candidate** — added after the research, and deliberately parked behind the
      other two: his arms are the one rig in the game already solved as bones,
      so he is the cheapest thing to swap and the least in need of swapping.
- [ ] **The manager customiser stutters on most tabs.** Skin colour and hair
      colour are fine; the rest lag. **Measured before guessing, because this
      file's own history says to** — `customise_timeline_test.dart` exists
      precisely because the first two passes each moved the cost somewhere else
      and were reported again. A tab-switch timeline over skin, colour, hat,
      hair, emote and outfit came back at 20-26ms on the frame the dropdown
      closes and **not one frame over 16ms after it**, on every axis — with the
      colour axes no cheaper than the rig ones. So the BUILD side is not it, and
      the things that would have been the obvious suspects are all already done:
      SVG paths are memoised by their `d` string, each chip is a `SnapshotWidget`
      texture rather than a live rig, the snapshot is capped at 2x, blur is off,
      and the fill is one chip a frame off a notifier.
      **What is left is the RASTER thread** — eighteen rigs each rasterised once
      — and a widget test never runs it. This needs a profile-mode run on the
      device with the DevTools timeline, not another blind pass.

### Independent

- [ ] **Native bounce missing on the Players tab.** The scroll view already
      forces `AlwaysScrollable(Bouncing(RangeMaintaining))` and the app sets
      `BouncingScrollPhysics` app-wide, so the physics are not it. The structural
      difference left is that the `ScoutActionBar` sits OUTSIDE the scroller, so
      the top of the tab does not respond to a drag at all. Wants a device to
      confirm before moving the bar.
- [ ] **FORM IS INVISIBLE, and it should not be.** Raised from the couch — *"we
      say form is down, and I think it does affect ratings? but we need to check
      that, and we also need to show that on the squad/player pages/popups."*
      **Checked, and yes: `getEffectiveRating` adds `card.form` straight into
      the composed rating**, clamped to −1…+1, so a player in form is worth a
      point more and one out of it a point less. That is also exactly what the
      JS's own legend claims — `SquadScreen.js` prints "▲ good form +1 ▼ bad
      form −1" — so the arithmetic here is right and matches the spec.
      **What is missing is every trace of it on screen**, and the usual tell is
      all over it: `squad.form.good` and `squad.form.bad` are translated in ten
      catalogues with no caller in `lib/`, and `squad.subtext` says in as many
      words "▲▲ good form · ▼▼ poor form — affects squad rating" while nothing
      draws an arrow. The JS puts it in two places and both are ported shapes:
      `Card.js` hangs a ▲/▼ on any card with non-zero form, and the bench sheet
      carries the legend. So: a form glyph on `CardView`/`PlayerCard` — which
      the squad, the bench, the pickers and the detail sheet all already read —
      plus the legend.
      One thing NOT to port: `Form.ratingPctPerLevel` (±5% per level) has no
      caller here and **none in the JS either**. It is a stale constant in both
      repos, not a missing feature; the ±1 is the rule.

- [ ] **THE SUBS BENCH NEEDS A POSITION FILTER AND A COMPARISON.** Asked for
      from the couch: a quick GK/DEF/MID/ATK filter, **pre-set to the position
      of the player coming off** so the right candidates are the ones on screen;
      and the ATK/DEF figures coloured against the man being replaced — green
      where the sub is better, red where he is worse.
      **Both halves already exist in this repo and neither is wired here**,
      which is the reuse rule this project keeps: `PositionFilterBar`
      (`squad_screen.dart`) is the JS's own `_benchFilterDefs()` ported, and it
      is already on the squad bench and the pickers — the subs panel is the one
      bench without it. And `benchForSlotProvider(slotPosition)` already ORDERS
      by the slot's position, so the panel knows which position is being
      replaced; it just never says so. For the colours, `vsGreenOn` / `vsRedOn`
      in `match_stat_rows.dart` are the app's own better/worse pair.

- [ ] **A poof/tap sound worth having.** Carried over from `REMAINING.md` — `pop`
      is a 0.1s blip doing the job of a shatter cue. Needs audio, not code.


### Session two — still open

- [ ] **Commentary should tell a little story.** Two or three lines, with a lot
      more variation, so a passage reads like a passage rather than a label:
      "*<player> has looked lively down the left and drives towards goal, knocks
      it beyond the defender who nudges him in the back…*". Asked for with the
      caveat that it must stay READABLE — not every line, a good few of them.
      **The pools are the JS's**, and `match_orchestration_reference.json` pins
      363 commentary lines field for field, so the engine emits what it always
      emitted and any new writing has to arrive as copy in `en.js` plus a
      screen-side pick. `openingFillMinutes` is the precedent for that shape.

- [ ] **Full time waits for a CONTINUE button.** The three buttons at the foot
      of the match popup become one, and the end-game screen comes up when it is
      pressed — so a player can read back the ninety minutes first. Their own
      answer to their own question, and it is the right one: it also fixes the
      1,400ms `_cue` that currently decides for them.

- [ ] **The coach's 30s cooldown should start when the player is back from the
      end-game screen**, not when the match ends behind it.

- [ ] **Energy and gems fly to the HUD like coins do.** `coin_flight.dart`
      exists and is wired for one currency; the bolt and the gem land nowhere.

- [ ] **The next-match card's modifiers align INWARD.** The left team's sit
      right-aligned and the right team's left-aligned, so one modifier reads as
      belonging to a side rather than floating at the page edge.

- [ ] **The daily reward's price boxes are too heavy.** They make it hard to see
      which day gives what.

- [ ] **FORM IS INVISIBLE.** It does affect ratings — `getEffectiveRating` adds
      `card.form`, ±1 — and `squad.form.good` / `squad.form.bad` are shipped in
      ten catalogues with no caller. Port `Card.js`'s glyph onto `CardView` /
      `PlayerCard` and the bench legend. Do NOT port `Form.ratingPctPerLevel`:
      it is dead in both repos.

- [ ] **The subs bench needs a position filter and a comparison.** GK/DEF/MID/ATK,
      pre-set from the outgoing player's slot, with ATK/DEF coloured red or green
      against the man coming off. `PositionFilterBar` already exists and is on
      every other bench; `vsGreenOn`/`vsRedOn` are the colours.

---

## Spine

Asked for after the playthrough: *"there are examples of diamonds and coins…
I wonder if we can use this for our gems/coins sections in the shop? I also
wonder if there are things we can use in spine to recreate our manager rig —
make him look more real and better movement… he is a little too static, looks a
bit boring (same with dugout cam)."*

Both examples are real. Here is what checking actually turned up, because two
of the four findings change the shape of the decision.

### The licence is a gate, and it has a number on it

The runtimes on GitHub are free to *evaluate*. To ship software containing them
to people who do not own Spine, **you need a Spine editor licence at the time of
integration** — that is the Spine Runtimes License Agreement, not a footnote.

The editor is a one-off purchase at the two lower tiers:

| Tier | Price | Note |
|---|---|---|
| Essential | $69 (from $99) | **Meshes are not included** |
| Professional | $379 (from $449) | Everything |
| Enterprise | $2,499 + $379 per user, annually | **Mandatory** above the threshold below |

Two things in that table matter more than the prices.

**Essential is not the cheap option, it is the wrong option.** Mesh deformation
is most of what makes a Spine rig look alive — hair that swings, cloth that
follows, a face that is not a rigid cut-out. It is exactly the row above this
one. Essential cannot export meshes, so the realistic figure is **$379**.

**And the Enterprise threshold is a shipped-app question, not a studio-size
one.** "Companies or individuals making more than $500,000 USD via revenue,
investment income, venture capital, or other financing require Spine Enterprise
and are not eligible to use Spine Essential or Spine Professional." That is a
decision about this game's future, and it belongs to you rather than to a queue
row.

### The example ART cannot ship. The example RIGS can.

This is the finding that changes the coins-and-gems idea, and it is worth
quoting because it cuts exactly down the middle. Every example carries the same
`license.txt` — checked on `coin`, `diamond` and `mix-and-match`:

> The images in this project may be redistributed as long as they are
> accompanied by this license file. **The images may not be used for commercial
> use of any kind.**
>
> **The project file is released into the public domain. It may be used as the
> basis for derivative work.**

So the shop cannot wear Esoteric's gold coin or their diamond. It *can* wear
their rig with our own art on it, and that is the expensive half — the bones,
the timing and the animations are the work, and the images are the part this
project already generates for itself.

`examples/diamond` (added 2025) is eight bones — `holder`, `top-scale`,
`top-rotation`, `middle-scale`, `middle-rotation`, `lower-point`,
`diamond-rotation-control` — and ships `appear`, `disappear`, `idle-still`,
`idle-rotating`, `idle-rotating-alt-shape`, `rotation`,
`size-changing-rotation` and a perspective variant. That is a shop gem's whole
life cycle, already keyed.

### `mix-and-match` is the manager customiser, exactly

This is the strongest case in the whole investigation and it is not the shop.
`examples/mix-and-match` is 143 bones with `idle`, `walk`, `blink`, `aware`,
`dance` and `dress-up` — and its skins are split into `hair/`, `eyes/`,
`eyelids/`, `nose/`, `clothes/`, `legs/` and `accessories/`, with four
`full-skins/` presets on top. One set of animations, every combination.

That is the customiser's own tab list, and it is the answer to two rows above:
the customiser stutters because every tab rebuild repaints the whole rig, and
Spine's model is that the skeleton animates once and the skin is a lookup. The
demo page's own claim is the point — *"the work of animating only needs to be
done once, then you can assign different looks to your skeletons while reusing
all your animations"*, and the runtimes can combine parts from different skins
at runtime.

### The runtime, practically

`spine_flutter` 4.3.6 on pub.dev: spine-c over FFI, WebAssembly on web,
Android / iOS / Linux / macOS / Web / Windows. Needs
`await initSpineFlutter()` in `main()`. **Spine 4.3 exports only.** Supports
every Spine feature **except two-colour tinting and the screen blend mode** —
worth checking against `KitTheme` before committing, because the whole palette
here is derived from the club's kit and a kit-coloured shirt has to be
expressible as per-slot tinting.

It also brings native libraries per platform into a project that currently has
none for rendering, which is a bundle-size and a build-complexity cost.

### What it would cost this repo

Not the money — the structure. The manager is a `CustomPainter` chain over SVGs
**generated from `../merge-empire-fc`** by `gen_manager_art.mjs` into
`manager_art.g.dart`, with `gesture_reach_test` solving the arm chain against
`skullOnScreen` and `ManagerWalker` distinguishing `walking: false` from
`standing` from `idle`. Spine replaces all of it, and it takes the manager's art
**out of the spec repo** — which is a one-way move away from "the JS is the
spec" for that art, and the first place this port would have two sources of
truth.

### The assets, if it goes ahead

Written up separately and in full: **`docs/SPINE_MANAGER_ASSETS.md`** is the
generation brief for every piece the rig needs, read off the shipping catalogue
rather than guessed — 6 builds × 4 outfits, 15 hair styles as back-and-front
pairs, 9 beards, 17 hats, 11 face items, 5 mood mouths and the 15 body parts,
with the pivots, the two-layer hair rule and the paint-versus-hardware rule
stated. About 112 pieces.

It also says loudly what must NOT be asked for: the 19 hair colours and the 8
skin tones are runtime TINTS, and the 16 gestures are ANIMATIONS. Asking a
generator for them is 285 hairstyles and sixteen poses of a wardrobe, which is
the shape of mistake that makes an asset order unusable.

### The recommendation

**Do the layering work first, and do it whether or not Spine happens.** It is
the row above and it is not wasted either way: it is what makes the current rig
cheap enough to animate, it is the only thing that closes the customiser's
stutter and the dugout's hanging arms, and a repaint budget is exactly what you
need in hand before deciding whether a native runtime is worth it.

**Then take Spine to the manager, not to the shop.** `mix-and-match` is the
customiser feature-for-feature and the manager is what was actually reported as
boring; a spinning gem is something the existing painter can do once the layers
are split, so the shop is the weaker case for a $379 licence and a native
dependency.

**The penalty keeper is third, and that ordering is deliberate.** He was raised
as a later candidate and later is right: his arms are already a two-bone solve
in metres with a fixed-length invariant that four tests hold — `keeperRigFor` is
the one rig in this game that is genuinely skeletal already. That makes him the
cheapest thing to move onto Spine and the least in need of moving, and it means
the argument for him is "smoother secondary motion", not "he looks static". Do
him after the manager has proved the pipeline, or not at all.

**Open questions that are yours, not the queue's:** the $500k Enterprise
threshold, and whether the manager's art leaving the spec repo is acceptable.
