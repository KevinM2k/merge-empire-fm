# Merge Empire FM — building with this kit

This is the chrome of a football-manager game: a dark, saturated, slightly
arcade UI whose entire palette is derived from **the club's kit colour**. Every
surface, border and accent in a screen comes out of one input.

## Wrap everything in `<KitProvider>` — nothing is styled without it

`KitProvider` writes the whole palette as CSS custom properties on its own
element. Outside one, every component renders with the stylesheet's fallback
values (the turf kit in dark) and no theme switching works at all.

```jsx
<KitProvider kit="turf" light={false}>
  <GlassPanel style={{ padding: 16 }}>
    <SectionHeading title="Next match" icon="⚽" />
    <Button>Play match</Button>
  </GlassPanel>
</KitProvider>
```

- `kit` — one of `turf`, `humbug`, `sunset`, `midnight`, `empire`, `void`, or
  any `#rrggbb` club colour. Unknown values fall back to the default green.
- `light` — light mode takes the kit too. It is not a neutral card stack with
  the accent moved; it is the same ramp read from the other end.

`useKit()` returns the resolved `{ surfaces, light }` if a component needs the
raw values.

## Style your own layout with the tokens, never with literals

There are **no utility classes**. Components are styled internally; anything you
add around them should read the same custom properties they do:

| Family | Tokens |
|---|---|
| Ground | `--color-bg`, `--color-surface`, `--color-surface-2`, `--color-border` |
| Ink | `--color-text`, `--color-text-muted` |
| Club accent | `--color-accent`, `--color-accent-ink`, `--color-accent-bright`, `--color-accent-bright-ink`, `--color-accent-edge` |
| Fixed meaning | `--color-danger`, `--color-warning`, `--color-gold`, `--color-silver`, `--color-bronze`, `--color-legendary`, `--card-yellow`, `--card-red` |
| Tactics | `--tactic-attack`, `--tactic-defence`, `--tactic-counter`, `--tactic-press`, `--tactic-ink` |
| Type | `--font-ui` (Barlow), `--font-display` (Lilita One), `--weight-base`, `--font-size-min` |
| Shape | `--radius-control`, `--radius-panel`, `--radius-pill`, `--control-lift` |
| Motion | `--transition-fast`, `--transition-med` |

Three rules that matter:

- **`--color-accent-ink` is the only safe ink on `--color-accent`.** It is
  measured, not guessed — on a yellow kit it flips to near-black, because white
  on yellow is invisible. Never hardcode white on the accent.
- **`--color-danger` and the tier/medal colours are fixed on every kit.** Danger
  has to mean danger in a club that plays in red.
- **Nothing is smaller than `--font-size-min` (12px).** A tight slot shrinks its
  content at draw time; it does not take a point off the type.

## Composition notes

- **`Button`** is moulded: it has a hard bottom edge and answers a press by
  dropping. `variant="outline"` is the cancel — a solid face on a decline
  out-shouts the button beside it. There is no ripple.
- **`GlassPanel`** needs something behind it for `backdrop-filter` to bite. Put
  it on a scene, not on flat `--color-bg`. Set `sheen={false}` on a tall panel:
  the highlight is for a small surface, and on a big one it reads as a band
  across the middle. `shadow={false}` when it already sits on chrome.
- **`CoachCard` has no barrier**, so it must always carry its own dismissal —
  give it a decline action, not just an accept. Use `CoachLine` for emphasis
  inside its text rather than `<strong>`.
- **`HudChip`** takes a `fill`: the three resources are colour-coded and their
  hues are fixed on every kit (coin gold, energy blue, gem cyan). Omit `fill`
  and it takes the club accent — right for the cog, wrong for a resource. Group
  them in `HudCluster`; `HudPlus` is the buy affordance.
- **`PlayerCard`** is driven by `tier` (1–9, Bronze to Icon), which picks the
  body gradient and the chip colours from the shipped catalogue. `TierBadge`
  and `tierThemes`/`tierGradientCss` expose the same palette.
- **`PitchBoard`** positions slots on formation percentages, centred. The caller
  brings the token to render in each slot.

## Where the truth is

`_ds/<folder>/styles.css` and its imports are the real stylesheet — read them
before styling. Each component's `.prompt.md` and `.d.ts` in
`components/<group>/<Name>/` carry its exact API.
