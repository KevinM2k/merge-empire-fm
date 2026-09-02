# Android playthrough 2

The rows a player wrote down playing the build on an Android phone. A row is
ticked when it is fixed **and** pinned by a test; the note after it is what was
actually wrong, because that is the part worth keeping.

## Where this queue stands

**13 done, 8 open.** The nine that are done were each a real defect with a
mechanism behind it, and three of them were shipped code doing nothing: a
`strategyId` nothing ever wrote, a `skyPaneTint` with no caller, and a turf band
whose whole job was hiding a seam it was itself making.

The eight still open split into two piles and the split is worth keeping. Five
are **one job**: the scene is painted by a handful of very large `paint()`
methods, and animating hair, stopping the customiser stuttering and fixing the
dugout's hanging arms are all downstream of taking that apart into layers — with
the Spine question sitting on top of the same work. The other three are
ordinary and independent, and two of those need a device or a recording rather
than a change.

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
      colour are fine; the rest lag. Same cause, most likely: every tab rebuild
      repaints the whole rig.
- [ ] **The dugout manager has hanging arms between transitions** — one behind,
      one in front, as if a forward walk were paused mid-stride.

### Independent

- [ ] **Native bounce missing on the Players tab.** The scroll view already
      forces `AlwaysScrollable(Bouncing(RangeMaintaining))` and the app sets
      `BouncingScrollPhysics` app-wide, so the physics are not it. The structural
      difference left is that the `ScoutActionBar` sits OUTSIDE the scroller, so
      the top of the tab does not respond to a drag at all. Wants a device to
      confirm before moving the bar.
- [ ] **A poof/tap sound worth having.** Carried over from `REMAINING.md` — `pop`
      is a 0.1s blip doing the job of a shatter cue. Needs audio, not code.

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
