# Playthrough 3 — the referee, the write-up, and everything the couch found after

Reported live while playing the build, newest batch last. A row is ticked when it
is fixed **and** pinned by a test; the note after it is what was actually wrong,
because that is the part worth keeping.

## Where this queue stands

**43 done, 2 open.** Both open rows are features rather than faults, and one of
them is a feature that was built, tried and turned down — which is written up
where it happened rather than quietly dropped.

The pattern in this batch is worth naming: **almost every "the game said X"
report was a claim the game itself contradicted.** Copy that asserted "ten
against ten" when eleven were playing eleven, a score printed in our order rather
than the reader's, a coach reading a league fixture on a cup week, a trait badge
announcing that a card has no trait. None of them were rendering faults; all of
them were something being said that was not true.

---

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

---

## Open


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


