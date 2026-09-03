# Playthrough 3 — the referee, the write-up, and everything the couch found after

Reported live while playing the build, newest batch last. A row is ticked when it
is fixed **and** pinned by a test; the note after it is what was actually wrong,
because that is the part worth keeping.

## Where this queue stands

**82 done, 5 open, and one feature parked.** None of the open rows is a fault. One is a feature that was
built, tried and turned down; one is a balance question rather than work; one is
a survey to run before building; and one is **blocked on the spec repo**, which
is the row to read if the queue looks short — richer commentary and report copy
cannot be written from a cloud container without the next generator run throwing
it away in ten languages at once.

The FIRST batch's pattern is worth naming: **almost every "the game said X"
report was a claim the game itself contradicted.** Copy that asserted "ten
against ten" when eleven were playing eleven, a score printed in our order rather
than the reader's, a coach reading a league fixture on a cup week, a trait badge
announcing that a card has no trait. None of them were rendering faults; all of
them were something being said that was not true.

The SECOND batch's is different and worth naming beside it: **most of it was
already in the repository.** Four of the reports were shipped copy with no
caller, one was a shipped AdMob unit with no button, and the worst of them was a
screen calling a SIMULATION where it wanted a lookup. Only the confetti was
genuinely new code rather than a wire that had never been run.

**And the tail of that batch is the same pattern again**, which is the part to
take seriously: five more fixes, and every one of them was a shipped string, a
shipped asset or a shipped function with nothing calling it. Two of the five had
to be CORRECTED on the way in rather than merely connected — `signBlockedCopy`
named the wrong key, and a pooled coach line promised a timer the screen it
pointed at did not have. **Unreachable code is not finished code**, and wiring it
up without reading it would have shipped both faults.

---

## Asked for, 3 Sep 2026 — the trait roll

Two reports in one line: the ATK and DEF flags updating before the spin had
finished, and too many traits being the same as each other.

- [x] **The badge's effect chips answered before the reels did.** (The header's
      numbers were already held for the spin — the sheet redraws itself as the
      man he WAS until the wheel stops — but the chips inside the trait block
      were not, and they are the two numbers a roll is actually bought to move.
      `_effectsOf` took the trait's identity from the hold and the "with" side
      from the LIVE card, and the roll writes the save before the reels move, so
      for a second and a half the block named the old trait over the new one's
      ATK and DEF. Both sides are composed from the trait being SHOWN now.)

- [x] **The traits were mechanically distinct and read on screen as three of
      them.** (The block printed ATK and DEF and nothing else, so Crowd Pleaser,
      Tough, Veteran and None drew no chip at all and the rest drew the same one
      or two. The ten `feature.effect.*` strings — "+{n}% income", "-{n}% squad
      injury", "{n}% faster healing" — are shipped in all ten catalogues and had
      NO caller in `lib/`. Same tell as the coach tips, the income breakdown and
      prestige before them.)

- [x] **And several of them genuinely were the same.** (The bank's own rule was
      "no two traits share an effect vector", which is far too weak: Pressing III
      was `10 ATK / 13 DEF` against All Rounder III's `10 / 10` — different
      vectors, same trait, one strictly better. The universals are in EVERY pool,
      so each of the four re-ran a position trait's job: All Rounder was a
      smaller Engine Room for a midfielder and a smaller Ball-Playing for a
      defender, Tough and Enforcer split one injury axis 0.18/0.10, and Rock,
      Veteran, Reflexes and Speedster shared aging and recovery between them
      four ways. The rule is stated per POOL now and `traits_test.dart` enforces
      it: nothing may be dominated by a poolmate; only ATK+DEF may repeat as a
      shape, and then only with the lead stat differing by a sixth of the split;
      and an axis a description claims to be "biggest" at is held outright, at
      1.8× the nearest rival. Pressing became a forward who really defends
      (8/26 — `defenceWeights['FWD']` is 0.15, so the raw number has to be
      large), Engine Room drives forward (18/9), Ball-Playing is a defender who
      attacks (38/5), and All Rounder is the only even one. Ids and names are
      untouched, so an existing save keeps its trait — it just does a new job.
      **The JS could not be consulted**: `../merge-empire-fc` is not in a cloud
      container. These numbers were already the port's own, per the file's
      Balance model section, and the divergence stays on this side.)

## Done

- [x] **A sending-off costs something.** (The card was theatre. The scoreline is
      generated at kickoff, but `reSimulateRemainder` reads the LIVE lineup and
      is what a mid-match tactic switch already goes through — so a red now
      empties the slot and re-rolls the rest of the match against ten men.)

- [x] **A banned player is out of the next side.** (Two stacked faults. The ban
      was written against `matchesPlayed` BEFORE the match was counted, so it
      lapsed the instant the whistle was recorded; and `restoreKickoffLineup`
      ran before the write and put him straight back. The write moved above it,
      and `isSuspended` is part of what counts as available, so the bench covers
      the hole.)

- [x] **The red card is on the squad page and the bench, not the Players tab.**
      (Bans became their own input to `cardViewFor`. Reading them off `state`
      was the trap: `state` is ALSO what switches the income line on, so passing
      it to the bench turned on a looping animation per card — caught as a
      `pumpAndSettle` timeout — and taking it off the grid to hide the ban there
      would have deleted the `+25.1/s` from every card on the Players tab.)

- [x] **A skipped match is still a match somebody was sent off in.**
      (`skipToEnd` jumps the clock rather than running it, so the per-minute
      dispatch never fired: eleven men for the whole ninety. Watching and
      skipping agree now.)

- [x] **A substitution re-sims the remainder.** (Asked as a correction to a
      claim of mine, and it turned out to be a bug rather than a wording
      dispute. `match_sub_scores` — "bring someone on and have them score" — was
      UNWINNABLE: `reSimulateRemainder` draws its scorers from the live lineup
      and nothing re-drew them after a change, so no goal could ever be
      attributed to a substitute. The test asserts it from the deterministic
      end: a man taken off in the 5th cannot score in the 70th.)

- [x] **But a sub does not re-roll the injuries.** (Found by the suite rather
      than by reasoning: with subs re-rolling, a re-simulated remainder injured
      a bench player between two substitutions and the cap test could not bring
      him on. Re-rolling is right for a TACTIC — the multiplier is the
      tactic's — and wrong for a change of personnel, so it is a flag now and
      only the tactic path passes it.)

- [x] **An injury substitution shows the swap.** (The sim empties the slot
      before the panel opens, so the confirmation had nobody to show and fell
      back to the one-sided "{on} comes on" while every other sub got two cards
      and an arrow. `PitchSlot.vacatedById` is who the hole belongs to.)

- [x] **A grudge match no longer opens by saying the same thing twice.** (Not a
      duplicate event: `feedOf` seeds a commentary row on its MINUTE — `1-c` —
      and the line cache was keyed on `type-seed`. The engine inserts
      `commentary.snub` at minute 1 and the opening flow line is already there,
      so two different pools shared one entry and the second rendered the
      first's text.)

- [x] **Colin names who cannot play the next one.** (Asked for about a red card,
      and he was doing it for injuries either — so both went in, named, above
      the rating comparison. A ban outranks an injury when a man has both: he
      cannot play either way, but the ban carries into the NEXT fixture too.)

- [x] **A sending-off is one of the moments on the summary.** (Beside the goals,
      in minute order, with the glyph saying which card it was. No replay on
      that row: the pitch never drew one.)

- [x] **"Ten against ten no more" was nonsense.** (Eleven were playing eleven.
      Mine, and while fixing it a second error in the same lines: four locales
      called the opponent "the visitors", which is wrong half the time. And the
      English red-card line assumed the dismissal came near the hour.)

- [x] **The write-up prints the score the way a score is written.** (Home team
      first. It was our goals then theirs regardless of venue, so an away win
      read "a narrow one, 1-0" while the board said 0-1. Fixed in all ten
      catalogues by a mechanical `{ours}-{theirs}` → `{score}` pass.)

- [x] **And it closes on BOTH clubs' next fixtures.** (The write-up is a summary
      for anyone reading it, so ending on only our own next game tells a reader
      about one of the two sides. The opponent's next opponent is a lookup:
      `generateSeasonFixtures` writes every pairing in the division, not only
      ours.)

- [x] **Two clauses that said nothing.** ("which is exactly how it is supposed to
      look" and "Two halves of a very good afternoon" — both mine, both replaced
      with sentences that carry a fact.)

- [x] **A `None` trait draws no badge.** (`none` is the absence of a trait — its
      own description says "clears any existing trait" — and it is in the bank
      so a roll can land on nothing. Drawing it put a badge on the card
      announcing that the card has no badge.)

- [x] **A caution is a remark, not an interruption.** (It went through a full
      card, then through a small bespoke bubble, and both were wrong the same
      way: it paused the match, lost his head, narrowed the bubble and carried a
      button that made the substitution for you. It is `_say` now — the same
      channel as his reaction to a goal, pitch still running, no button. The
      bespoke bubble went with it rather than being left with no caller.)

- [x] **The home screen names the club you are actually about to play.**
      (`previewFixture` only knows the LEAGUE schedule, so on a cup week the
      caption correctly read the cup and its round while the card underneath
      showed a different club — and the coach agreed with the card.
      `prepareCupRound` is the same call the launcher makes, so the two cannot
      disagree. A cup club carries no table position and no grudge, because
      there is no table for it to be in.)

- [x] **The traits, the pencil, the sheet's arrows and the trait dice were
      emoji.** (`traits.dart` keeps its emoji because that file is the spec's;
      the draw site translates, keyed on the emoji itself.)

- [x] **The tab swipe is gone.** (Every tab in this game is something you drag
      on, so an intercepted or slightly diagonal drag threw the player onto a
      different screen.)

- [x] **One ad is warm from boot.** (`refresh()` returned early whenever nothing
      had EXPIRED, including when nothing had ever loaded, so the first ad tap
      of a session always paid a cold load.)

- [x] **The squad's portraits survive a background.** (Android trims the image
      cache when an app leaves the foreground, so the first scroll back was
      thirty-eight decodes with a thumb already moving.)

- [x] **An atmosphere line may not claim a booking.** (Reported as a yellow card
      for time-wasting that nobody received. Two of the JS's flow pools describe
      a card — `firstB.2` and `secondB.3` — and they were harmless colour until
      the port grew a referee; now they are the feed contradicting itself. They
      are dropped at the boundary rather than in the catalogue: the pools are
      generated from the spec and the engine picks by INDEX, so removing an
      entry would move every later seeded pick in the match.)

- [x] **An injured card keeps its tier and wears a cross.** (`INJ` replaced the
      one label that says what a card IS, so on a bench of twenty there was no
      telling a hurt Legend from a hurt Bronze. `InjuryCross` moved to the
      widgets layer — the token had it and the card needed it, and the token
      imports the card.)

- [x] **The Players grid draws 38 squares, not 39.** (The save's array is 39
      long and its length is pinned against the JS's default state, so it does
      not move — but the roster tops out at thirty plus the Academy's eight
      tiers, and the thirty-ninth was a padlock nothing could ever open.
      `Grid.shownCells` is what is drawn; the cell is still there.)

- [x] **A claimable quest draws the game's own gift.** (It was a 🎁 in the
      middle of a ring the app painted.)

- [x] **The sponsor offer stops saying the company's name twice**, and its terms
      sit two to a row. (`sponsor.title` is "{company} Offer" at the top and the
      row under the portrait said it again. The terms were full-width strips, so
      three drawbacks pushed the buttons off a short phone. A `Wrap` rather than
      a fixed pair, so a long localised term takes its own line instead of being
      squeezed.)

- [x] **A goal line no longer describes a goal that did not happen that way.**
      (Two reports, one cause: "not had a shot in twenty minutes" seven minutes
      after they scored, and a keeper spilling it over a free-kick cutaway. The
      pools are picked by bucket and minute and know nothing about the match, so
      the twenty story lines I had added — every one of which asserted a manner
      or a count — were each a coin flip against the clip. They are gone from
      all ten catalogues. The spec's own short lines stay: they are
      impressionistic rather than specific, and they have always been there.)

- [x] **Same-minute lines keep their order.** (`timelineOf` sorted with
      `List.sort`, which is not stable, so two events on one minute — a booking
      and a goal, the grudge line and the kick-off line — could come out either
      way round and CHANGE between rebuilds. Stable now, tie-broken on arrival:
      the engine's events, then the port's bookings.)

- [x] **The MAX ribbon says MAX.** (Third go. A `FittedBox` scaled it below
      anything readable; ellipsis cut `T2 MAX` to `T2 M`; and the cause of both
      was the `Flexible` around it, which hands a child the space that is LEFT
      rather than the space it needs. It is the shortest and least divisible
      thing in that row, so the two chips beside it are the ones that give.)

- [x] **The Add Player row clears the HUD by twelve.** (It was on
      `hudClearanceOf(underBar: false)`, which drops the bar's own margin
      entirely — that variant is for the Play tab, where the cluster floats over
      a diorama and there is no bar. This tab has one, so the buttons sat
      against the glass.)

- [x] **The write-up reads like somebody wrote it.** (Reported as not reading
      "as if someone is writing independently about the two teams to give
      information to people who didn't watch the game." All thirty-four English
      pools rewritten against three rules that came out of that sentence: name
      both clubs rather than assuming the reader supports one; say WHY rather
      than restating a scoreline the reader can already see; and write full
      sentences, because one clause that reads as a caption breaks the voice of
      the ones either side of it. The nine locales still carry the older,
      terser shape and are queued.)


- [x] **The write-up says how it was seen out.** (Asked for directly: "we know
      the context of the tactics used, if we switched to defence in 70m we can
      happily say they spent the last part of the game defending." Nothing
      recorded WHEN a switch happened — `strategiesUsed` is a set — so
      `applyStrategy` keeps a minute-stamped log and the report reads the last
      one after the hour. Three keys, ten catalogues.)

- [x] **The explanation of a red card is spent once.** (It is a tutorial: the
      man is gone and the substitution is not refunded, which is worth a card
      the first time it happens to anybody and worth nothing the second. It
      goes through `seenTips`, the same ledger every other once-only
      explanation in the game uses. After that the bench opens straight away.)

- [x] **And the bench cannot replace him.** (Clearing `cardInstanceId` is what
      makes the engine field ten — `reSimulateRemainder` reads the live lineup —
      and the same clearing turned his square into an ordinary hole the panel
      offered to fill. The screen hands the panel the slot as it stood the
      instant before, so he is drawn back into it, rated zero and refusing a
      tap.)

- [x] **A banned man cannot be sent on, and is worth nothing while he is
      banned.** (Three faults in one report. The Send On button was live; it
      put him in the side; and the squad rating went UP when it did.
      `computeSquadRatings` zeroes an injured or unavailable player and knows
      nothing about bans — it is compared field for field by the parity
      harness — so the suspension is applied at the provider, by handing it a
      hole where he stands. Which is what the sim fields anyway.)

- [x] **And his sheet says so before it offers anything.** (A red card over the
      portrait, the same treatment an injury gets on a bench card.)

- [x] **One rating per player, in the chip the card already has.** (Three
      reports, one cause. The subs bench carried an ATK/DEF strip across the
      bottom of the portrait and the slot picker carried a coloured bar under
      the card — so a tile showed `26` in the corner and `13` underneath, two
      numbers for one man with the one that mattered furthest from his face.
      Both are now `PlayerCard.ratingInstead`: what he is worth in the hole
      being filled, in the corner, on the pitch token's own green/amber/red.)

- [x] **A trait moves the number on the card.** (`CardView.rating` was
      `getCardRating(def)` — the DEFINITION's rating, with no trait, no form
      and no aging in it — so the one thing a player spends coins to change was
      the one thing the card could not show, and it is also why an `18` on a
      card sat over a `20` on the pill: two different functions answering one
      question. `getCardStats` is the documented single source of truth, and
      the save's split ratios travel with it so every screen prints the same
      figure.)

- [x] **`★ MAX ★` loses its stars.** (The two stars are wider than the word
      between them, so the ribbon outgrew `T8 MAX` and the rating chip beside
      it — the flexible one — scaled itself to nothing to make room. The
      decoration goes rather than the type size; a `★` is a DOM flourish the
      same way `<strong>` is, and the catalogues are generated, so it is
      stripped at the boundary.)

- [x] **Every sheet leaves room for its grabber.** (The handle is an overlay
      rather than a row, which kept each sheet its full height and left the
      clearance to the content — so the ones with a `SheetHeader` happened to
      have enough and the ones without had none. The frame pays for it now, so
      no sheet has to.)

- [x] **Pro mode's squad-fitness alert could never fire.** (Found answering a
      question about whether notifications are wired up. `notification_plan`
      read `grid.cells` as `c is CardInstance`, and a save is JSON — a cell is
      a `Map` — so it saw eleven empty squares on every real save. Its test put
      `CardInstance` objects into the grid directly, which is a shape the game
      never loads, so it passed against a save that cannot exist.)

- [x] **The three controls under the pitch are one row again.** (Subs wore the
      substitution green, so three buttons came in three colours and the green
      one read as a confirmation. The colour is left to the speed toggle, which
      is the one control it is genuinely information for, and all three carry a
      glyph instead.)

- [x] **A customiser chip frames what the camera is framing.** (The stage
      learned to push in on the head and stay wide for a build or an outfit;
      the chips beside it did not follow, so a close-up of the torso sat next
      to a wide shot of the whole figure. `_regionFor` asks `_zoomFor` now, so
      the two are one decision — and a build is a SILHOUETTE, which the
      shoulders-to-hem crop was hiding in exactly the way the camera would
      have.)

---

## Second batch — the cup week, the referee's arithmetic, and a screen that was playing the game

Reported in one sitting, newest first in the report and oldest first here.

- [x] **LOOKING at a cup tie no longer plays it.** (The worst fault on either
      queue, and three reports were one bug: "all my players got injured in that
      last game", players "disappearing and going injured again" while the
      manager sat still on the Squad page, and "ratings for teams is now showing
      0". `nextMatchProvider` and `coachTipsProvider` named the due cup opponent
      by calling `prepareCupRound` — on a comment of mine claiming it was
      read-only because it does not COMMIT a round. It is not read-only in the
      sense that mattered: it simulates the tie, rolls injuries and APPLIES
      them, and spends the Lucky Boot. Both are `savePick`s, so injuring
      somebody bumped the save revision, which re-ran the provider, which
      injured somebody else. Eleven injured men rate 0, which is the third
      report and not a separate bug. `previewCupTie` is the read-only answer to
      the only question those two were asking.)

- [x] **The fixtures sheet names the cup opponent.** (`CupTie.opponent` was null
      until the tie had been PLAYED, on the reasoning that "before it is played
      the opponent is not known" — which is not true and never was. The bracket
      is drawn when the run starts. Reported with a screenshot: "you can see
      Everton nowhere.")

- [x] **And NEXT MATCH points at the tie, not past it.** (The heading hung off
      `OurFixture.isNext`, which is the next LEAGUE fixture. Same screenshot:
      a quarter-final due and the sheet announcing Rangers.)

- [x] **Colin stops reading a record against the wrong club.** (The grudge and
      the rating comparison were already gated on there being no tie; the
      head-to-head was not, and neither was the tactic he says he would pick —
      which was being chosen against the league opponent's ATK and DEF.)

- [x] **Two placeholders that were being printed at players.** (`{opp}` in a
      match summary: `report.clean_sheet`'s second of three variants opens "{opp}
      were kept out entirely" and the beat passed `club` alone. A pool's
      variants do not all take the same placeholders, so the test expands the
      pool — every variant, ten catalogues, twenty-two shapes of match. The same
      sweep found `squad.out_of_position` — "Out of Position {pct}" — called with
      no parameters at all.)

- [x] **An injured player says how long he is out for.** (`squad.badge.injured`,
      `squad.badge.injured_min_left` and `squad.badge.injured_soon` have shipped
      in ten languages since the generator first ran with nothing able to print
      any of them — and `hint.injured_on_grid` goes as far as telling the player
      to "check the Squad tab to see their recovery time", a promise the port
      had no way of keeping.)

- [x] **The bench offers to heal them.** (The one part of the mechanic that was
      never built. A real `heal_all` AdMob unit for both stores, three strings in
      ten languages, and `buyConsumable` pricing the Magic Sponge against "the
      free rewarded video on the Squad bench, which heals the whole squad three
      times a day" — so the coin item had been priced against a video that did
      not exist. The heal is one function both call now.)

- [x] **A banned card wears the injured card's red wash.** (Asked for in exactly
      that shape. It had the red card and not the wash, so a hurt man read as out
      from across a bench and a banned one only once you had looked at him. One
      wash for both, or a man with an injury AND a ban gets it twice.)

- [x] **A card costs the maths, on both sides.** (A yellow was worth ten per cent
      on two widgets and nothing else — the rest of the match went on being
      rolled by a side nobody had booked. And their card was worth nothing at
      all: our man leaves the lineup and the rating engine scores the hole,
      theirs is a pair of numbers with nobody in it. `oppTeamRatingMult` applies
      our own rule to their figure rather than inventing one.
      **The parity harness caught the first attempt and was right to** — the
      live ratings were stamped onto the result, and seventeen scenarios refused
      a field the JS has never heard of. They are handed out to the screen
      instead.)

- [x] **Their cards are counted ONCE, watched or skipped.** (Caught rather than
      reported, and it came in with the fix above. Their tally is incremented by
      the live clock as each card lands AND by the whistle's catch-up over every
      booking; ours are guarded by `_cautioned` and `_sentOff` being sets and
      theirs had nothing, so a fully watched match re-counted every opposition
      card at full time and re-rolled the remainder against a side punished
      twice. **The first version of the test passed with the guard taken out**
      — it used a fixture whose away card is in the 84th minute, and a watched
      match holds on a cutaway well before then, so it exercised only the
      catch-up. `s1_m2` books them in the 17th.)

- [x] **The cooldown label is read over the MASK, not over the face.** ("The
      coach cooldown text is pretty much unreadable in some themes — until the
      bar fills anyways", which names the mechanism exactly. `_CooldownMask`
      lays 68% black over the part of the face the clock has not given back, and
      the ink above it was measured against the BRIGHT face.)

- [x] **The music stops spiking between beds.** ("In between transitions the
      music briefly hits 100% volume then respects the volume switch again." It
      did: the outgoing bed was faded out from `musicBaseVolume` rather than
      from the volume it was playing at, so at a 30% setting the first step of
      the fade threw it to more than three times what had been asked for.)

- [x] **A win gets paper.** (The only genuinely new thing in this batch. Seeded
      on the fixture so one match is one fall, in the club's own colours because
      a hardcoded palette is a bug here, and a ONE-SHOT — a looping animation
      would hang every `pumpAndSettle` that reaches a won match.)

### Found on the way, and then built

- [x] **The rest of the age badges.** `squad.badge.last_season`, `sell_now`,
      `declining` and `ageing` — the injured badge was one of eight. The
      thresholds are NOT invented: they are the ladder `coach_tips.dart` already
      runs on, lifted into `ageBadgeKeyFor` so a badge on a card and a sentence
      out of Colin cannot disagree about the same player, with a test that walks
      0–20 seasons against his ladder. `squad.badge.seasons_inj` is deliberately
      left alone — it is "{seasons} season{s} · {pct}% inj" and the sheet
      already prints both halves in its own plates.

- [x] **`stripBadgeEmoji`, one helper rather than five.** All eight badges open
      on a pictograph because the catalogues were written for a DOM. The first
      version of its test asserted "nothing above U+2600" and Japanese failed
      it — 最 is a CJK ideograph and exactly what the strip must leave alone.
      The stripper was right and the assertion was lazy.

- [x] **The sell sheet says how long he is out, and why not to sell him.** Two
      things met here. `coach.grid.injury` tells the player to "tap the injured
      card to see the timer" — and a tap on the Players grid opens the SELL
      sheet, which dimmed the artwork and said nothing else, so the pooled line
      was a promise the game did not keep. And `hint.injured_income` — "still
      earn 20% ... no need to sell them" — had no caller while the one screen
      it was written for is the one where somebody is deciding exactly that.

- [x] **The paper got its bang.** `playFirework` is the one effect in the game
      that is a recording rather than a synth — the reason the audio backend has
      a second entry point at all — and `assets/audio/firework.mp3` shipped with
      nothing calling it. It is on the win screen, not inside `VictoryConfetti`:
      a reusable widget that plays a sound whenever it is drawn is one nobody
      can put on a second screen.

- [x] **The Add Player button says why it is dead.** `signBlockedCopy` had no
      caller anywhere, and it named `grid.player_count` — "{count} / {max}
      players", a READOUT drawn two inches away on the same screen, placeholders
      unfilled — for the one reason a player actually hits. Wiring it without
      fixing it would have shipped the bug. It is
      `event.deadline.blocked_squad_full` now ("No room in the squad — sell
      someone first"), which Deadline Day already uses for the same condition,
      and `no_candidate` returns NULL rather than `settings.comingSoon`: there
      is no honest sentence for an empty scout pool and the catalogues are
      generated, so silence beats claiming a feature is unbuilt.

## Third batch — "more variation in commentary and summary and even 2d pitch scenarios"

Asked for directly, and it splits cleanly into what this container can do and
what it cannot. Both halves are worth stating, because the blocked half looks
like the easy one.

- [x] **He has a word at the final whistle.** NINE `commentary.*` strings
      written for exactly that moment sat translated in ten catalogues with
      nothing able to reach one of them: `thriller_win/draw/loss`,
      `demolition`, `drubbing`, `high_scoring_win/loss`, `nervy_one_nil`,
      `nil_nil`. `match_coach.dart` had a read for every scoreline in progress
      and none for a RESULT, so the one moment those nine were for was the one
      moment he had nothing to say. `fullTimeReactionKey` is the ladder; a test
      walks 0-8 by 0-8 and asserts all nine are reachable and resolve in every
      language.
      **He is quiet after an ordinary afternoon** — a 1-1 gets nothing, because
      a line at every full time is a line nobody reads.
      **And they are HIS, not the feed's — corrected in the fourth batch after
      one reached a player.** See that row.

- [x] **Twelve more passages on the 2D pitch**, taking the set from 35 to 47.
      The claim worth being careful about: the set was NOT meaningfully
      right-handed — measured by mean q it ran 8 left, 10 right, 17 central.
      What it lacked was the OPPOSITE NUMBER of a named move: a cutback off one
      side only, a cut-in off one touchline, a corner from one flag, so a
      passage came round again as itself. Three of the twelve are that missing
      version and nine are shapes the set had none of — a long-throw flick-on, a
      ball driven flat across the six, a knock-down struck first time, a header
      back across goal from open play, a steal off the keeper's feet, a carry
      and a lay-off with the shooter arriving from behind the ball, a diagonal
      met on the volley, a one-two on the D, and an early cross off a left
      overlap.

      The table's existing guards did the checking — every sequence is driven
      through the game for two outcomes and asserted to keep the ball on the
      pitch and every kick on a boot — and all twelve passed first time. A new
      guard pins the WIDTH rather than the count, because the count is not the
      thing: forty passages all down the right would satisfy "there are lots".

      **This batch is port-side only.** The previous set was added to
      `SEQUENCES` in `ChanceCutaway.js` in the same commit, because the JS is
      the spec; that repo is not in a cloud container, so these twelve are a
      divergence until somebody mirrors them. No fixture dumps the sequence
      table, so the suite will not catch the gap — the note in the file is the
      record of it.

- [ ] **MORE COMMENTARY AND REPORT LINES IS BLOCKED, and not by effort.**
      `commentary.*` is 64 keys and 120 lines; `report.*` is 37 keys and 111
      lines. Both are generated into `lib/i18n/locales/*.g.dart` by
      `tool/gen_i18n.mjs` from `../merge-empire-fc/src/i18n/locales/`, which is
      not in a cloud container — so a new line written here would be reverted by
      the next generator run, in ten languages at once, silently.

      **And there is precedent for exactly that going wrong.** Twenty story
      lines were added straight to the catalogues earlier in this queue and all
      twenty were removed again — not because of the generator, but because a
      line picked by bucket and minute cannot know what the cutaway is about to
      draw, so each was a coin flip against the picture. The lesson recorded
      then still stands and is the way in: **pick the line from the PASSAGE.**
      With 47 sequences falling into about six shapes, a pool per shape would
      let the words describe what is actually on screen — and that needs new
      keys in `en.js`, which is the same block.

      So the honest order is: write the shape pools in the spec repo first, then
      port them. Adding lines to the existing pools from here would be work that
      gets thrown away by a generator run nobody would notice.

### Found on the way, not built

- [ ] **THE `hint.*` BANK IS 37 KEYS DEEP, not four.** The four injury ones this
      queue listed were a sample: of 39 `hint.*` keys, 37 have no caller. And
      counting them is not a work queue — `hint.injured_one`,
      `hint.injured_multiple` and `hint.injured_on_grid` turn out to be
      SUPERSEDED rather than missing, because `coach.grid.injury` is pooled,
      reachable, and already says all three things on the same screen. Wiring
      them would have been a second system contradicting the first. The rest of
      the bank wants the same read before any of it is built: which are gaps and
      which were replaced.

- [ ] **A single caution is about a rating point, and sometimes none.**
      `computeSquadRatings` returns whole numbers — the JS's own rounding, held
      there by the parity harness — so ten per cent of one man is about 0.9% of
      eleven. That is the right size for a booking and it means the number on
      the board will not always visibly move for one yellow. Stated rather than
      inflated; if it should be bigger, that is a balance decision.

## Fourth batch — the commentator does not play for us

Two reports, one sentence apart in the same match, and both are the same shape:
a screen speaking in a voice that is not its own.

- [x] **The commentary cannot say "we".** A 4-1 printed `FULL TIME` in the feed
      and under it "4-1 - what a performance! We took West Ham apart." The nine
      result lines above were routed through `feedOf` for a round, on the
      reasoning that the final whistle is the last row of the commentary — and
      every one of them is written in the FIRST PERSON, while that feed is an
      independent commentator describing two clubs. Reported in exactly those
      terms: "in commentary it's independent commentary so it can't be we."
      **The prefix is where a generated catalogue puts a key, not who says the
      line.** They are the manager talking to you about your own team, so they
      are Colin's: `_sayFullTimeWord` puts the reaction in his bubble at the
      bottom-left, a beat after the sting, the shape the rest of his match talk
      already takes. The third-party write-up of the same result is
      `match_report.dart`, still at the head of the feed — two voices on one
      afternoon, each saying the thing only it can say.
      **Not gated on Pro mode**, which is where this parts company with the rest
      of his match talk: that bargain gives up the ADVICE, and this is a remark
      about a result. Gating it would delete nine translated strings for half
      the players in the name of a trade they did not make.

- [x] **A substitution is two players, and the feed drew one.** The row was the
      sentence "{off} off, {on} on." under a single face — the man coming ON —
      so a change read as an arrival with a footnote. Asked for against a
      screenshot of a real commentary feed, which gives a substitution a block
      of its own: both men, a face each, an arrow each. `FeedLine.offId` is what
      was missing; the arrows are glyphs because no new key can be minted here
      and every feed this was modelled on uses them anyway. The sentence goes
      when both faces are drawn — it is the same names a second time — and
      stays as the fallback when one of them cannot be.

- [x] **And an INJURY names the man being replaced.** Reported as the coach
      popup saying "subs" and only the new player, where a standard swap shows
      both. Two paths reach the confirmation and only one of them was right:
      `_pick` had resolved an empty square to the hole's `vacatedById` since
      that card grew two faces, but an injury never goes through `_pick` — it
      arrives with the hole ALREADY preselected, precisely because the manager
      has just been told who went down, and that path handed the bench a null.
      So the one substitution the game makes you make was the one whose card
      could not say who it was for. One line in `initState`, and the feed row
      then names them both as well, because it reads the same field.

## Fifth batch — the write-up knows what happened

- [x] **"Held on to a single goal for longer than was comfortable" — about a
      goal scored in the 88th minute.** The headline was picked off the MARGIN,
      and a margin cannot know when the goal went in; a 1-0 won in the 5th and
      one won in the 88th were the same afternoon to it. Reported with the
      direction that followed: the summary should use everything the match has
      — the stats, the tactics, the goals and who scored them and when, the
      substitutions, the discipline — "a decent live-like summary".
      `ReportFacts` now carries every goal, every card, every substitution,
      every change of tactic and the board at the whistle, and the write-up
      tells them in order: the headline reads the minute of the goal that
      SETTLED it (`deciderMinute`) and from the 80th on the one-goal results
      and the draw get a late-decider sentence, the goals are told one by one
      by what each did to the match, the numbers get a line, every card is a
      name and a minute, every change both names, and the tactic the side
      started with and each switch. The result records two things it did not
      — the kick-off tactic and each substitution's names and minute — because
      the write-up reads the result and nothing else. Twenty-six keys, all in
      `en_copy.dart`; the shape line that would contradict a late headline
      ("ahead early and untroubled") stays out.

- [x] **"Behind early, Iron Stars spent the rest of the afternoon…" — about a
      goal in the 67th minute.** The same fault one line down. Three of the
      seven shape pools say WHEN as well as what — `chasing` and `never_behind`
      are written about an EARLY goal, `rescued` about a LONG spell behind — and
      the two booleans that picked them knew nothing about minutes. The shape
      line is gated on the timeline it claims to describe now: the opener has
      to be inside the first half hour for "early", and the side has to have
      spent thirty minutes behind for "trailing for much of it". When the
      claim would be false the line is simply absent, and the goal-by-goal
      beats tell it with the real minutes.

- [x] **The menu is the manager's PHONE.** Asked for from the couch over a
      dozen messages as it took shape: "change the menu button on the home page
      to a mobile phone… make it look like a mobile phone screen, same buttons
      etc"; three tiles to a row, not two; "dont need to call it Quick Nav
      anymore… make it look like a manager app, give it a name"; a battery that
      mirrors the game's energy, red at a tenth; a clock that reads the real
      time with signal and wifi that vary "only every so often" and keep their
      empty bars showing; raised from the corner, swivelling, and lowered the
      same way without the dip; a phone's proportions; centred; and left open
      under any sheet a tile opens. A deliberate divergence from the JS, whose
      `.qn-menu` is a glass panel of tiles. The dock button is a handset glyph
      and still says Menu — it says what it is FOR. The popup is a black,
      metal-rimmed case with side buttons, a status bar and a home bar, round
      the SAME three groups of tiles sized to an exact third of the row, under
      an app header named **Dugout** (one constant, `dugoutAppName`; a product
      name is not copy, so `quicknav.title` has no caller now — deliberately).
      **A HAND, at the sixth attempt.** Capsules, bezier silhouettes, the
      user's first drawing as a raster and as a trace, and a drawn one in the
      rig's style were all sent back ("get rid of the hand, its awful!"); the
      one that stayed is the user's THIRD drawing, cut out by them and made for
      a wider phone, laid over a case whose size does not change for it and
      tinted to the manager's skin. Drawn to its card the hand was twice the
      phone's width, so it is scaled to 81% about the hole and nudged 15 points
      right (`_HandArt.scale`, `shiftX`); its hole is centred on the case, so the
      case's bottom covers the palm's top and the notch by the little finger,
      and the case sits `bottomInset` above the screen's edge with the wrist
      running off below (pinning the wrist to the edge slid the hand down and
      opened a sliver of pitch under the case; two painted patches for it were
      tried and neither read as palm). A picture of a hand HOLDING a phone was tried after this
      — our screen inside the drawn one — and taken back to this snapshot: at
      the phone's size the whole drawing was twice the display and fitting it
      made the phone too small. Any tap off the glass — bezel, hand, pitch —
      puts the phone away; the glass keeps its own taps. Should a fit ever put
      skin over the glass, the screen lays itself out in three bands round it
      (`phoneThumbZone`, `phoneFingerReach`), and the test checks three screen
      sizes for a tile under a finger. `quick_nav_menu_test` pins the case, the row of three, the
      battery, the raise and that every tile still opens.

- [x] **The write-up's first line "just gives the score (which is already
      visible) and gives a one liner".** Asked to open like the whistle has
      just gone: "the whistle has gone and there was one goal in it", "what a
      thriller of a game, 7 goals between them but it goes to {team}". Every
      generated headline pool leads with `{score}`, so the fourteen are
      REPLACED whole in `enCopy` (the overlay's other job) with three openers
      each, and a THRILLER headline is picked ahead of narrow and late for a
      one-goal result with five or more goals, or a 3-3 — the seven goals are
      the bigger fact. The scoreboard above the card has the score; the opener
      has the moment.

- [x] **"I won 0-6 away… the summary reads 'the whistle has gone on a draw,
      1 apiece'."** The card read the engine's `homeGoals`/`awayGoals` while the
      board above it and the feed count the EVENTS, and on this screen the two
      can part company. The write-up counts its score off the events now, the
      same source as everything else on the page, so they cannot disagree; the
      fields are the fallback for a result with no events on it.

- [x] **And then a 0-1 written up as a 0-3, with two scorers and three
      minutes the player never saw.** Same sitting. The write-up now reads the
      match screen's own FRAME — the events the board, the feed and the stats
      panel are drawn from — rather than `result['events']`, so it cannot tell
      a different match from the one above it. The two sources drifting apart
      is a separate fault, still open below.

- [x] **"That summary is too long… if a team just got one booking, so what?!
      dont even mention it!"** A single booking of ours is not told, theirs
      are told only as reds, our substitutions are ONE sentence with both names
      and the minute each, the opposition's changes are not told, and the
      kick-off tactic is told only when it changed.

---

## Sixth batch — a cup tie with nobody in the other dugout

- [x] **"I got a red card and my score correctly changed… however for some
      reason, their rating went to 0."** Reported with a screenshot of a cup tie
      at full time: our figure reading 78, theirs reading 0, and their ATK and
      DEF beside it perfectly healthy at 85 and 87. The card is not what wiped
      them out — **their rating had been 0 since kick-off, and the sending-off
      is what made it visible**, because a re-simulation fills OUR half of the
      board in from the live squad and nothing ever filled theirs.

      A LEAGUE result carries `effectiveSquadRating` and `effectiveOppRating` —
      what the two sides were worth walking out, after home advantage, the
      relegation lift and the stagnation buff — and the board's two big figures
      are those fields. A CUP tie carried neither: `cup_launcher.dart` builds
      its own result map and stamped `squadRating`/`opponentRating` and the
      ATK/DEF pair, which is why three of the four numbers on that card were
      right. The values are simply the base pair, because `prepareCupRound`
      plays a tie on neutral ground and gives neither side a home bonus, so for
      a cup the effective rating IS the rating.

      **Two other things were reading the same missing fields and saying
      nothing about it.** `match_statboard` defaults a missing rating to 50, so
      every cup tie modelled its possession and its chance weighting as an even
      contest whatever the draw had produced; and `quest_match`'s underdog win
      compares the two, so `0 > 0` meant "beat a stronger side" could never fire
      in a cup — a quest a cup tie is judged against, since `settleCupRound`
      resolves the match track exactly as a league game does. Both come right
      with the fields.

- [x] **And the re-simulation cannot zero an opposition it was handed
      incompletely.** Caught on the way to the above. `reSimulateRemainder`
      reads their ATK and DEF through `effectiveOppRating ?? opponentRating`,
      and wrote the single figure the board prints from `effectiveOppRating`
      alone — so any result reaching it without that field re-rolled the
      opposition down to a flat zero the first time anything re-simulated. Same
      chain for all three now.

---

## Features asked for, not yet built

- [ ] **A NEWS section, Sky Sports style.** Full match reports of the whole
      week's games — every fixture, not only ours — written as if by an
      independent news outlet, for the player to go and read if they want.
      **Explicitly not yet**: "i dont want the sky sports style feature yet".
      What it needs is already the rule for the summary above: everything a
      report says has to be on the RESULT, because an AI-versus-AI fixture will
      have nothing else to read. The known gap is that the sim never names an
      opposition scorer (`ReportGoal.scorer` is null for theirs), so their goals
      can only be told as the club's until it does.

---

## Open

- [ ] **`result['events']` and the match screen's timeline can disagree at
      full time.** Seen twice in one sitting: a 0-6 whose `homeGoals`/
      `awayGoals` read 1-1, and a 0-1 whose events carried three goals at
      56', 58' and 89'. `_resimulate` rewrites the events and every caller
      refreshes `_timeline` after it, so the path that leaves them apart has
      not been found. The write-up reads the frame now, which hides it from the
      player; the saved result may still be the other match. Worth a fixture
      that plays a match with a substitution and compares the two at the
      whistle.


- [ ] **Commentary matched to the CUTAWAY, so a line can describe how a goal
      was scored again.** The contradictions are gone — see the two rows under
      Done — but they went by removing the twenty story lines that described a
      manner, because a line picked by bucket and minute cannot know that the
      clip is about to show a free kick. The richer answer is to pick the line
      from the passage: `cutaway_sequences.dart` has thirty-four of them and
      they fall into about six shapes (header, free kick, solo, cutback, long
      range, one-on-one), so a pool per shape would let the words describe what
      the player is actually watching. Worth doing; it is a feature rather than
      a fix.

- [ ] **A gesture contract for every popup — BUILT AND REVERTED, at the user's
      call.** Swipe up → full screen; swipe down → back to its own size; again →
      close, driven from the drag handle and from the content's own overscroll,
      all of it in `showBottomSheetPopup` rather than in any sheet. It worked
      and it was not liked, and the sizing question underneath it is why: the
      ask was for every popup to open at half the screen, and a sheet's fraction
      turns out not to be decoration — half put the daily reward's claim button
      under the fold and cut the subs panel through the middle of the pitch.
      Reverted whole rather than left half-applied. If it comes back it should
      come back as the gesture ALONE, with every sheet keeping its own resting
      size.


