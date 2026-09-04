# design-sync notes

The synced package is `design-system/`, a React mirror of the Flutter app's
chrome. It is NOT the app — `lib/ui` is, and the two are kept honest in the one
place it is possible to be honest: the palette.

## What is verified, and what is eyeballed

- **The kit ramp is generated, not transcribed.** `design-system/src/tokens/kit.ts`
  is a port of `lib/util/kit_theme.dart`, and `test/tokens.parity.test.ts` asserts
  it against `fixtures/kit_tokens.json`, dumped from Dart by
  `tool/dump_kit_tokens.dart`. 17 kits x 2 themes plus the colour primitives.
  **Regenerate the fixture whenever the Dart engine changes** — a drifting palette
  is the one failure this package can catch by itself.
- **The tier palette is generated too**, from `lib/data/card_theme.dart` via the
  same dump and `tool/gen_tiers.mjs`. `src/tokens/tiers.gen.ts` is output; edit
  the generator.
- **Everything else is hand-authored from the Dart and verified by eye.** The
  geometry literals came from the widgets (the button's radius 10 / lift 3 /
  9x16 padding, the sheet header's 15px w900 +0.8, the trait badge's size ratios),
  but no test binds them.

## Known divergences from the app

- **`--color-text` is the port's own value**, not the app's. Flutter derives body
  ink from `ColorScheme.fromSeed`, and matching that means porting Material's
  tonal palette — out of proportion. Near-white dark / near-black light instead.
- **`GlassPanel` is an approximation.** `backdrop-filter: blur(20px) saturate(1.4)`
  stands in for the sigma-20 pane, but `_GlassEdge` is a `CustomPainter` and CSS
  has no equivalent; the rim is a plain 1px border.
- **The rigs are out of scope** — `ManagerWalker`, `PitchScene`, `PlayerHeroArt`,
  the gesture poses. Those are joint-solved painters. `PitchBoard` ships the
  board and the slot geometry; the caller brings the token.
- **`PlayerCard` is the card shell**, not the 54k-line widget: body gradient,
  rating chip, plate, traits. No hero art, no bench columns.

## Re-sync risks

- **The woff2 faces are derived and checked in; the .ttf are not duplicated.**
  `design-system/tool/gen_fonts.py` regenerates them from `assets/fonts/*.ttf`
  (needs `fontTools`). If a face changes in the app, re-run it.
- Fonts ship as files, not base64: Vite's library mode force-inlines assets, so
  the `@font-face` block lives in `src/styles/fonts.css` and is copied to
  `dist/fonts.css` by `tool/bundle_styles.mjs`, which rewrites `../fonts/` to
  `./fonts/` on the way. If the faces ever come back as a 485kB `style.css`,
  that copy step stopped running.
- `design-system/.shots/` is a local eyeball aid (`tool/shots.mjs`), not part of
  the sync and not the compare harness's reference.
