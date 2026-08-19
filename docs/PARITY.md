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

**A caveat on "layout".** Where the note says the layout differs, that is not a
control gap and it is not in this list — it needs the two put side by side on a
device. Those are collected at the bottom rather than guessed at.

---

## Players (grid) — `screens/GridScreen.js`, `components/Grid.js`

- [x] Add Player (scout), priced on the button
- [x] Scout batch ×1 / ×2 / ×4, offering only what the save can pay for and house
- [x] Merge All, carrying the pair count
- [x] Sort by tier, hidden when already sorted
- [x] Drag to merge, drag to move
- [x] Tap a card for the sell sheet
- [ ] **The scout REVEAL.** A signing drops into the grid with no reveal at all.
      The JS holds the batch back and turns the cards over together, with a
      new-discovery badge and an auto-sell marker. `_revealing` gates the Scout
      button for the duration, which is also what stops a double-tap.
- [ ] Lazy card mounting — only if a profile run asks for it

## Squad — `screens/SquadScreen.js`

- [x] The eleven by formation, drag to pick or swap
- [x] Bench under the pitch
- [x] Formation picker
- [x] Tactic picker
- [x] Rating / ATK / DEF header
- [ ] **Auto-fill / auto-rotate** (`.auto-lineup-btn`). Two different jobs
      behind one button: casual picks the shape that wins the NEXT FIXTURE
      (`bestFormationForFixture`), Pro rotates personnel to the freshest fit
      within the manager's chosen shape and never switches tactics under them.
- [ ] **Clear lineup** (`.clear-lineup-btn`)
- [ ] **The player detail sheet** — the biggest single gap on this screen, and
      everything below is inside it:
  - [ ] Career stats grid, rating and income header
  - [ ] Fitness bar with the next-recovery readout (Pro)
  - [ ] Rename (`.detail-rename-btn`)
  - [ ] Sell, with its own confirm — refused below `minSquadPlayers`, and for a
        loanee or anyone out on loan
  - [ ] Recall from loan (`.detail-recall`)
  - [ ] Send back early (`.detail-sendback`)
  - [ ] Swap into the XI / send to the bench (`.detail-xi-btn`)

## Home — `screens/LeagueScreen.js`, `components/PitchScene.js`

- [x] Coach Colin bottom left, burger bottom right
- [x] Play button in the sticky footer
- [x] Event strip
- [x] Table / fixtures / index / quests / training / trophies behind the burger
- [ ] **The next-match card.** Who, home or away, their rating against ours,
      the competition and the match number. It is the one thing on the screen
      that says what the Play button is going to do.
- [ ] **The walker.** The manager walk-cycles in place while the world scrolls
      behind him. The parts are now data (`data/manager_art.g.dart`); the rig
      and the cycle are not. Rive was considered and dropped — it is paid.
- [ ] The parallax scene behind him, evolving with the division
- [ ] **CUSTOMISE badge** → the manager customiser
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

All seven shelves are present and in the JS's own order. What is missing is
inside them:

- [x] Offers, Gems, Coins, Boosts, Vouchers, Free, Looks
- [x] Restore Purchases (present, disabled — needs the billing bridge)
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

## Not control gaps — needs a device

Collected rather than guessed at. Each wants the JS and the port side by side.

- Club screen layout
- Shop screen layout

---

## Method note

Three engines were found with no caller at all — `recordDiscovery`,
`maybeGenerateOffer`, and the idle `transfer:offered` listener. A control audit
does not catch those, because the control is not missing; nothing calls the
engine behind it. **Grep for who calls an engine, not just for who reaches a
screen.**
