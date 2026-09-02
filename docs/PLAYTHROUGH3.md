# Playthrough 3 — the referee, the write-up, and everything the couch found after

Reported live while playing the build, newest batch last. A row is ticked when it
is fixed **and** pinned by a test; the note after it is what was actually wrong,
because that is the part worth keeping.

## Where this queue stands

**27 done, 3 open.** Two of the open five are features rather than faults — a
gesture contract for every popup, and a commentary pass — and the other three are
small.

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

- [x] **The MAX ribbon holds the type floor.** (It moved into the gap between
      the rating and position chips, and the `FittedBox` that let it give way to
      them was scaling it below anything readable. It ellipsises now, which is
      what the chips beside it do.)

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

---

## Open

- [ ] **The write-up still reads short-handed.** Asked for in those terms: it
      "doesn't read as if someone is writing independently about the two teams
      to give information to people who didn't watch the game." The score
      orientation, the vacuous clauses and the two-club close are fixed; what is
      left is the register. The beats are correct and clipped, and they want to
      be joined into prose that names both sides and explains rather than
      labels. **English first**; the nine locales inherit the shape afterwards.

- [ ] **The commentary contradicts the match.** Two reports, one cause: a goal
      line said "not had a shot in twenty minutes" when they had scored seven
      minutes earlier, and a line describing a keeper spilling it played over a
      free-kick cutaway. The pools are picked by BUCKET and minute and know
      nothing about what has actually happened, so a line can assert a drought
      that did not happen or a manner of goal the cutaway then contradicts.
      The half of it that WAS a lookup is done — see "an atmosphere line may not
      claim a booking" under Done.

- [ ] **A gesture contract for every popup.** Swipe up → full screen; swipe up
      again → scroll. Swipe down → scroll to the top; again → back to the small
      size; again → close. Asked for as "the same on ALL popups", which is the
      hard half: it belongs in `showBottomSheetPopup` rather than in each sheet.


