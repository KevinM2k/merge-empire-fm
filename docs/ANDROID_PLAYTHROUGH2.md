# Android playthrough 2

The rows a player wrote down playing the build on an Android phone. A row is
ticked when it is fixed **and** pinned by a test; the note after it is what was
actually wrong, because that is the part worth keeping.

## Where this queue stands

**9 done, 11 open.** The nine that are done were each a real defect with a
mechanism behind it, and three of them were shipped code doing nothing: a
`strategyId` nothing ever wrote, a `skyPaneTint` with no caller, and a turf band
whose whole job was hiding a seam it was itself making.

The eleven still open split into two piles and the split is worth keeping. Five
are **one job**: the scene is painted by a handful of very large `paint()`
methods, and animating hair, stopping the customiser stuttering and fixing the
dugout's hanging arms are all downstream of taking that apart into layers. The
other six are ordinary and independent.

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

---

## Open

### One job: the scene is one big `paint()`

These five are the same piece of work seen from five angles, and doing them
separately would mean doing the hard part five times.

- [ ] **Draw the background in LAYERS, not one `paint()`.** Stadium tiers want
      to be layer 1 (nearest), 2, 3 — each a little smaller and further away —
      rather than one flat painting. Split the manager the same way:
      body/torso/clothes, head, hair, eyes/mouth, accessories, as a stack.
      `RepaintBoundary` per layer, pass the `Listenable` to the painter, cache
      the expensive work, use `canvas.save`/`restore` sparingly and no
      `saveLayer` every frame. Converting the SVGs to Dart `Path`s to skip
      parsing belongs here too. Spine is a later question, not this one.
- [ ] **Animate the hair** — which is what the split is for, and it has to cost
      nothing.
- [ ] **The manager customiser stutters on most tabs.** Skin colour and hair
      colour are fine; the rest lag. Same cause, most likely: every tab rebuild
      repaints the whole rig.
- [ ] **The dugout manager has hanging arms between transitions** — one behind,
      one in front, as if a forward walk were paused mid-stride.
- [ ] **The goalkeeper's arms bend the wrong way at the elbow** in Goalkeeper
      Practice.

### Independent

- [ ] **Does the arrow point the right way?** Reported as pointing RIGHT while
      dominating away. The logic is correct end to end and now says so: the
      scoreboard is home-left, `ourSideLeft = isHome`, and the clips and the
      arrow agree. **The bug is that nothing on the pitch says which goal is
      whose** — the markings are symmetric, so "pointing right" carries no
      meaning unless you already know which end you are attacking. Needs an end
      marker, not a sign flip.
- [ ] **Native bounce missing on the Players tab.** The scroll view already
      forces `AlwaysScrollable(Bouncing(RangeMaintaining))` and the app sets
      `BouncingScrollPhysics` app-wide, so the physics are not it. The structural
      difference left is that the `ScoutActionBar` sits OUTSIDE the scroller, so
      the top of the tab does not respond to a drag at all. Wants a device to
      confirm before moving the bar.
- [ ] **The end-of-season screen needs work** — it is vertically centred, which
      is wrong. Use the end-of-match screen for layout and style.
- [ ] **The welcome-back card fires after an ad break.** Should want ~30 minutes
      away, not seconds. (Asked as a question: what do other games do? The
      common shape is a threshold on real elapsed time, plus a rule that time
      inside the app's own modal flows does not count.)
- [ ] **A poof/tap sound worth having.** Carried over from `REMAINING.md` — `pop`
      is a 0.1s blip doing the job of a shatter cue. Needs audio, not code.
