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
  - [ ] Rename (`.detail-rename-btn`)
  - [ ] The trait wheel
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
- [x] **The Leaderboard tile**, with the signed-out and offline states the JS
      really shows. The ranked list needs `leaderboardService` (M4).
- [ ] The parallax scene behind him, evolving with the division
- [ ] **CUSTOMISE badge** → the manager customiser. Its parts are generated
      already (`data/manager_art.g.dart`): hair, beard, hat, outfit, neck.
- [ ] Prestige orb, when a prestige is available
- [ ] Daily-reward orb with its streak count
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
- [ ] In-match subs
- [ ] In-match tactic changes
- [ ] Stats tab
- [ ] Tactics tab
- [ ] The doubling offer on the closing screen (the rewards are already deferred
      for it — see `play_button.dart`)

## Settings — `screens/SettingsScreen.js`

52 interactive elements in the JS, the most of any screen after the events.
Not yet diffed control by control.

- [ ] Diff it

## Mini-games

- [x] Penalty Training (the goal is the target)
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
