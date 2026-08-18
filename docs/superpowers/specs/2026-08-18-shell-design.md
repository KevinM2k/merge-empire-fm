# The app shell — design

**Status:** approved, ready for a plan.
**Builds on:** `2026-08-17-flutter-port-design.md` (rendering and state decisions
stand unchanged) and `2026-08-18-i18n-layer-design.md` (every string here goes
through `t()`).

## Purpose

M3 is the whole of what a player sees, and nothing in it can start until the
scaffold every screen plugs into exists. This module builds that scaffold and
nothing else: the theme, the five-tab shell, the HUD, the popup plumbing and the
Settings screen. The five tab bodies stay placeholders — a screen is its own
module.

The test of whether this module is done is not that it looks like the game. It is
that a screen author has somewhere to put a screen, tokens to paint it with, a
way to navigate to it, and a way to put a popup over it — and does not have to
invent any of those four.

## Where M1 left the seams

Two files were ported with this module explicitly named as their other half.
Neither needs redesigning; both need finishing.

- **`lib/util/kit_theme.dart`** ports the colour arithmetic — hex→HSL, WCAG
  relative luminance, ink picking — and says so: *"the other half of that file is
  a table of CSS custom properties … deciding how a gradient background becomes a
  widget is an M3 decision rather than a translation."*
- **`lib/data/kit_palette.dart`** holds the six pattern kits' stripe pairs and
  keeps `kitSwatchCss` as a CSS string, noting *"a Flutter gradient is a
  rendering decision for M3."*

The split those two chose is the right one and this module keeps it: **the
arithmetic stays Flutter-free and hex-based; `lib/ui/theme/` is the only place
that turns a hex string into a `Color`.**

## What the JS shell does that Flutter does for free

Worth stating plainly, because roughly half of `App.js` is workaround rather than
product, and porting it faithfully would mean porting the workarounds too.

| `App.js` | Why it exists | Flutter |
|---|---|---|
| `screenFreeze.js` — `freezeScreen`, `freezeWhenSettled`, `requestIdleCallback`, the `.screen-frozen *` rule restyling ~1,150 elements | Hidden screens keep running CSS animations, starving the overlay above them | `TickerMode(enabled: false)` |
| `_startEnterAnimation`'s two-frame `requestAnimationFrame` dance | `onShow()` re-renders the DOM synchronously and blocks the slide it just started | No synchronous re-render to block it |
| `SWIPE_NAV_EXCLUDE_SELECTOR`, the `card-dragging` body class, `preventDefault` | Hand-built arbitration between a tab swipe and a card drag | The gesture arena |
| `_openSheet` re-parenting a screen's wrapper into a sheet container, and `nav:back` | One mechanism has to serve tabs, sheets and full-screen overlays | Routes and `showModalBottomSheet` |

**Deleting these is the port working, not the port cutting corners.** What must
survive is every line in that file that encodes a decision rather than a
workaround, and the sections below name those individually.

## Architecture

### `lib/ui/theme/`

A `ThemeExtension<KitTheme>` carrying the derived tokens — surface, surface-alt,
border, accent, accent ink, text, muted — and a background `Decoration`.

`applyKitColor` in the JS branches on six pattern kits (`turf`, `humbug`,
`sunset`, `midnight`, `empire`, `void`) plus any hex, each with a light and a
dark variant, and writes `repeating-linear-gradient` backgrounds. The striped
patterns become a small `CustomPainter`; everything else is a gradient.
`syncSystemBars` becomes `SystemChrome`.

`kitThemeProvider` derives from three values on the save: `club.kitPrimaryColor`,
`settings.lightMode`, and the active event's palette.

**The event override is a property of the EVENT, not of the tab.** A themed event
is a fixed dark "night match" showpiece and forces dark while it is open; an
event with no palette — Deadline Day — must inherit the player's light mode. The
JS carries a comment saying so because forcing dark on the way in once overrode
light mode for an event that never asked for it. Reproduce it as written.

### `lib/ui/shell/`

`IndexedStack` over the five tabs, each child in `TickerMode(enabled: isActive)`.

Tab order is `grid, squad, league, club, shop`, with `league` the raised centre
tab. It is icon-only — the JS deleted its label deliberately, because it was the
one label in the bar telling you nothing its icon didn't — and it keeps its
accessible name. Every other tab keeps its label, because they are all the same
small outline glyph and "Club" versus "Shop" is not obvious without one.

Tapping the Play tab always lands on Overview, even when the player was last on
Table, Fixtures or Training.

Transitions are **enter-only**, matching the JS: the outgoing screen simply
hides. One `AnimationController` drives a `SlideTransition` on the incoming
child, direction taken from the tab-index delta, `up` for the Event.

**Deep links skip the transition.** The JS is explicit that a screen sliding in
from the side while its contents jump to an anchor is two movements fighting and
reads as a glitch; arriving already in the right place reads as going straight
there, which is what the tap asked for. `nav:shop-coins` and `nav:shop-gems` both
depend on this.

Not everything lives in the stack:

- **Settings and Event are routes.** Event enters upward, because the way in is
  the strip pinned to the bottom of the Play screen and the screen rising from
  under it is the movement the tap implies.
- **Trophies, Player Index and Leaderboard are modal bottom sheets**, at 0.75,
  0.92 and 0.92 of the screen height — the JS's `75vh` / `92vh` as
  `DraggableScrollableSheet` fractions. The JS reaches the same result by
  re-parenting, having only one mechanism to hand.

Routes also give Android back for free, replacing the hand-rolled `nav:back`
which has to ask whether a sheet is open before deciding what "back" means.

Swipe between tabs is a `GestureDetector`, 60px threshold, no wrap at the ends.

### `lib/ui/shell/shell_controller.dart`

The engines emit onto the event bus, so the bus stays the transport. Screens
should not hand-roll event names against it.

A `ShellController` (a Riverpod `Notifier`) exposes typed methods — `goTab`,
`openSettings({tab, highlight})`, `openSheet`, `deepLinkShop(section)`,
`openEvent` — and thin bus listeners adapt the engine-emitted events onto it. One
place knows what navigation means; `providers/bus_providers.dart` already
republishes the bus and is untouched.

A takeover screen must still set `tickGatesProvider` while it is up, per M2. The
shell does not do this for them — the gates are a record precisely so the screen
that knows it has taken over is the one that says so.

### `lib/ui/hud/`

A floating overlay in a `Stack` above the body, not a bar: the JS removed the
header background so the scene shows through, and each stat is its own chip.

- Coins lerp toward their target rather than snapping — a `TweenAnimationBuilder`
  where the JS runs its own `requestAnimationFrame` loop.
- Energy reads `current / getEnergyMax(state)`, so the Energy Director upgrade's
  15 shows as 15. (The mini-games engine clamps against the un-upgraded 10; that
  is a carried JS bug already recorded in `REMAINING.md` and not this module's to
  fix.)
- The chips deep-link: coin `+` → Shop coins, energy `+` → the energy popup, the
  whole gem chip → Shop gems, cog → Settings.
- The HUD drops behind the card-reveal overlay between `reveal:start` and
  `reveal:end`, or it punches through the dim.

### `lib/util/popup_queue.dart`

`popupQueue.js` is pure logic and ports as pure logic — Flutter-free, in
`lib/util/`, under the architecture test. It is one of the highest-stakes files
in the port and the reasoning is in its own header:

**Nothing here may time out or discard.** `saveState()` stamps `lastSeen` during
boot, so by the time the welcome-back card is queued the offline window has
already been consumed. Drop that entry and the player's overnight earnings are
gone, with nothing anywhere else holding them. A blocked queue waits; it does not
expire.

Carried across exactly: priority order with ties broken by insertion sequence,
dedupe by id, blockers that hold everything back until released, a `canShow`
re-check at show time for state that moved while an entry waited, and the guard
against a double `done()` draining two entries onto the screen at once.

`queueMicrotask` becomes `scheduleMicrotask`, and it matters for the same reason
the JS gives: draining inline makes priority almost meaningless, because the
first caller into an empty queue opens immediately and anything higher-priority
can only queue behind it.

### `lib/ui/popups/`

Three shapes, and only three: the bottom sheet, the Coach Colin card, and the
quick-nav menu. A fourth is not to be invented — the rule already exists in
`REMAINING.md` and this module is where it starts being enforceable.

### `lib/ui/screens/settings.dart`

Four tabs — general, audio, match, account — carrying eleven settings
(`soundEnabled`, `musicEnabled`, `soundVolume`, `musicVolume`,
`notificationsEnabled`, `locale`, `matchSpeedFast`, `lightMode`,
`cutawayOurTeam`, `cutawayOpponent`, `hardMode`), the language picker, the saved
pyramid presets, and two destructive reset flows behind confirmation.

Sign-in, cloud save and feedback depend on M4. They land **disabled with a
visible reason**, not hidden: a control that vanishes reads as a missing feature,
one that explains itself reads as a feature that is coming.

This also closes the guard the i18n module deferred — the JS asserts the picker
lists exactly `supportedLocales`, and there is now a picker to assert against.

## Testing

- **Theme** — the arithmetic is already covered, in
  `test/util/utils_parity_test.dart` against a node fixture rather than in a file
  of its own; add that the extension resolves, that light and dark differ, that each of the
  six pattern kits produces a decoration, and that the event override forces dark
  only for an event carrying a palette.
- **Shell** — tab switching; state preserved across a switch (the `IndexedStack`
  contract); **offscreen tabs' tickers actually stop** (the one load-bearing
  assumption in this design, so it is asserted rather than believed); swipe past
  and under the threshold; no wrap at the ends; deep links arriving with no
  transition; Play always landing on Overview; sheets opening and closing; the
  Android back button closing a sheet before leaving a route.
- **HUD** — each chip reads its provider and rebuilds only for its own value;
  energy shows the upgraded max; each deep link fires the right controller call.
- **Popup queue** — pure unit tests, and the thorough ones: priority order,
  sequence tie-break, dedupe, blocker held then released, `canShow` false at show
  time, double `done()`, and an entry that waits through a blocker rather than
  expiring.
- **Settings** — every control writes its save key; the resets confirm first; the
  locale picker lists exactly `supportedLocales`.

## Scope

In: the theme layer, the shell, the HUD, the popup queue and the three popup
shapes, the Settings screen, and five placeholder tab bodies.

Out: all five real tab bodies, the match page, mini-games, the manager rig, the
diorama, `manager_avatar`'s SVG geometry, and the non-player SVG art. Out too:
anything Settings needs from M4 — those controls ship disabled.
