/// The game's icon set, ported from `ui/icons.js`.
///
/// Fifty-nine monotone glyphs on a 24×24 box at a 1.8 stroke, all inheriting
/// their colour from the caller. The port had been substituting Material icons
/// one at a time, which is why the chrome stopped looking like the same game:
/// Material's weights, corner radii and metrics are a different family, and a
/// screen mixing the two reads as two screens.
///
/// They are kept as the JS's own SVG source rather than retraced as painters —
/// the strings are the artwork, `svg_canvas.dart` already draws this subset, and
/// a transcription is a second copy to keep in step.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

/// `fill="none" stroke="currentColor"`, at the weight the whole set shares.
const _stroke =
    'fill="none" stroke="currentColor" stroke-width="1.8" '
    'stroke-linecap="round" stroke-linejoin="round"';

String _s(String body) => '<svg viewBox="0 0 24 24" $_stroke>$body</svg>';

/// Gold, for every coin figure in the game. `--color-gold` in the JS.
const gameGold = Color(0xFFFFD700);

/// The light theme's gold is a dark bronze: bright gold text on a white page is
/// illegible. `--color-gold` again, from the light block.
const gameGoldLight = Color(0xFF96571B);

Color goldFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light ? gameGoldLight : gameGold;

/// A coin FIGURE — the number, not the glyph.
///
/// **Yellow in both themes; a DIFFERENT yellow in light.** The rule the game
/// runs on is that money is yellow, gems are blue, ads are orange and real
/// money is green — stated directly, and it holds. What does not hold is one
/// literal serving both themes: `#FFD700` is 1.1:1 on a near-white card, and
/// once light mode draws near-white cards that is the biggest number on the
/// full-time report being invisible.
///
/// **The earlier answer was to buy the contrast with the SURFACE**, which is
/// why the money used to sit on a dark plate — and that only worked while the
/// page was dark in both themes. It is not any more. A halo under the digits
/// was tried before that and reads as an outline at any size worth putting
/// money in.
///
/// Pass `color: coinFigureInk(context)` to a [CoinIcon] sitting beside a figure
/// so the pair can never split into two currencies.
Color coinFigureInk(BuildContext context, {bool onGlass = false}) =>
    Theme.of(context).brightness == Brightness.dark || onGlass
    ? gameGold
    // **A DEEP gold on a light pane.** `#FFD700` is 1.1:1 on a near-white card,
    // which is the coin figure — the biggest number on the full-time report —
    // being invisible in light mode. Coins stay YELLOW, which is the currency
    // rule; what changes is the shade, the same way the reds and greens do.
    // `gameGoldLight` is the JS's own light-block `--color-gold`, so this is the
    // shipped value rather than a second one invented here.
    : gameGoldLight;

/// **THE HALO IS BACK, and only on GLASS.**
///
/// Nothing, on the app's own surfaces, in either theme: a halo behind a figure
/// printed on a card reads as an outline at any size worth putting money in, and
/// that is why this seam went quiet in the first place.
///
/// A pane over the pitch is not a card. In light mode the home page's glass is
/// the brightest thing the app draws and the bronze above is what kept the figure
/// readable on it — which is how the coins on the home page came to be reported
/// as "a horrible bronze colour", on the one screen where the backdrop is grass
/// and sky rather than paper. So [onGlass] keeps the gold and buys the contrast
/// from a dark BACKING instead, which is the answer `hud_chip.dart` already
/// reached for the coin, bolt and gem glyphs beside it: you cannot fix a bright
/// hue by darkening it, so darken what is behind it.
///
/// The pair is the HUD's own, so the two clusters cannot drift apart.
List<Shadow> coinFigureShadows(BuildContext context, {bool onGlass = false}) =>
    onGlass && Theme.of(context).brightness == Brightness.light
    ? const [
        Shadow(color: Color(0x59102030), blurRadius: 3),
        Shadow(color: Color(0x33102030), blurRadius: 6),
      ]
    : const [];

/// The set. Keys are the JS's own names so a screen can be diffed against it.
const Map<String, String> gameIcons = {
  'merge':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M4 7h5l3 3 3-3h5"/><path d="M4 17h5l3-3 3 3h5"/></svg>',
  'sound':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M4 9v6h4l5 4V5L8 9H4z"/><path d="M16.5 9a3.5 3.5 0 0 1 0 6"/>'
      '<path d="M19 6.5a7 7 0 0 1 0 11"/></svg>',
  'music':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M9 18V5l10-2v13"/><circle cx="6" cy="18" r="3"/>'
      '<circle cx="16" cy="16" r="3"/></svg>',
  'sun':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="12" cy="12" r="4"/>'
      '<path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 '
      '12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
  'bell':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6z"/>'
      '<path d="M10.5 20a1.8 1.8 0 0 0 3 0"/></svg>',
  'squad':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="9" cy="8" r="3.2"/>'
      '<circle cx="17" cy="9.5" r="2.4"/>'
      '<path d="M3 19c0-3 2.7-5 6-5s6 2 6 5"/>'
      '<path d="M14.5 19c0-2.2 1.8-4 4-4s2.5 1 2.5 1"/></svg>',
  'play':
      '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.25 L8 18.75 '
      'L19 12 Z" stroke="currentColor" stroke-width="1.4" '
      'stroke-linejoin="round"/></svg>',
  'pause':
      '<svg viewBox="0 0 24 24" fill="currentColor">'
      '<rect x="6" y="5" width="4" height="14" rx="1"/>'
      '<rect x="14" y="5" width="4" height="14" rx="1"/></svg>',
  'skip':
      '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4.5 5.5 L4.5 '
      '18.5 L12 12 Z" stroke="currentColor" stroke-width="1.3" '
      'stroke-linejoin="round"/><path d="M11.5 5.5 L11.5 18.5 L19 12 Z" '
      'stroke="currentColor" stroke-width="1.3" stroke-linejoin="round"/>'
      '<rect x="18.7" y="5.2" width="2.5" height="13.6" rx="1.1"/></svg>',
  'club':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M4 20V9l8-5 8 5v11"/>'
      '<path d="M9 20v-6h6v6"/><path d="M4 20h16"/></svg>',
  'shirt':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M8.5 3 L3 6 L4.7 11 L7 10.2 L7 21 L17 21 L17 10.2 L19.3 11 L21 '
      '6 L15.5 3 A4.5 4.5 0 0 1 8.5 3 Z"/></svg>',
  'shop':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M4 8h16l-1.5 10.5a2 2 0 0 1-2 1.5h-9a2 2 0 0 1-2-1.5L4 8z"/>'
      '<path d="M9 8V6a3 3 0 0 1 6 0v2"/></svg>',
  'coin':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="12" cy="12" r="9"/>'
      '<path d="M14.5 9c-.5-1-1.5-1.5-2.5-1.5-1.5 0-3 .8-3 2.2 0 1.3 1.3 1.7 '
      '2.7 2 1.5.35 3 .75 3 2.3 0 1.4-1.5 2.2-3 2.2-1.3 0-2.3-.5-2.8-1.5"/>'
      '<path d="M12 6v1.5M12 16.5V18"/></svg>',
  'trophy':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M7 4h10v4.5a5 5 0 0 1-10 0V4z"/>'
      '<path d="M7 6H4a2 2 0 0 0 0 4h3.2"/><path d="M17 6h3a2 2 0 0 1 0 4h-3.2"/>'
      '<path d="M9.5 14h5l-.5 3h-4z"/><path d="M7.5 20h9"/><path d="M10 17v3"/>'
      '<path d="M14 17v3"/></svg>',
  'cog':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="12" cy="12" r="3"/>'
      '<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 '
      '2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 '
      '1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 '
      '0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 '
      '2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 '
      '2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 '
      '1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 '
      '1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 '
      '1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 '
      '0-1.51 1z"/></svg>',
  'bolt':
      '<svg viewBox="0 0 24 24" fill="currentColor">'
      '<path d="M13 2 L4 14 H11 L10 22 L20 9 H13 L14 2 Z"/></svg>',
  'home':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M3 11 L12 3 L21 11"/>'
      '<path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/></svg>',
  'star':
      '<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" '
      'stroke-width="1.2" stroke-linejoin="round"><polygon points="12,2 14.7,8.6 '
      '22,9.2 16.5,13.9 18.2,21 12,17.2 5.8,21 7.5,13.9 2,9.2 9.3,8.6"/></svg>',
  'video':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<rect x="2.5" y="6" width="19" height="13" rx="2"/>'
      '<path d="M10 10 L15.5 13 L10 16 Z" fill="currentColor"/></svg>',
  'goal':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M3 6h18v12H3z"/>'
      '<path d="M3 10h18M3 14h18"/>'
      '<path d="M7 6v12M11 6v12M15 6v12M19 6v12"/></svg>',
  'stopwatch':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<circle cx="12" cy="14" r="7"/><path d="M12 14V10M12 14l3 2"/>'
      '<path d="M10 3h4M12 3v4"/><path d="M18 6l2 2"/></svg>',
  'target':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="12" cy="12" r="9"/>'
      '<circle cx="12" cy="12" r="5"/>'
      '<circle cx="12" cy="12" r="1.6" fill="currentColor"/></svg>',
  'userAdd':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="9" cy="8" r="3.2"/>'
      '<path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/>'
      '<path d="M19 10v6M16 13h6"/></svg>',
  'megaphone':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M4 10v4a1 1 0 0 0 1 1h2l9 5V4L7 9H5a1 1 0 0 0-1 1Z"/>'
      '<path d="M7 15v4a1 1 0 0 0 1 1h1.5a1 1 0 0 0 1-1v-3"/>'
      '<path d="M19 9.5a3.5 3.5 0 0 1 0 5"/></svg>',
  'sort':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M7 4v16M3 8l4-4 4 4"/>'
      '<path d="M17 20V4M13 16l4 4 4-4"/></svg>',
  'refresh':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M21 12a9 9 0 1 1-2.64-6.36"/><path d="M21 3v6h-6"/></svg>',
  'gem':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M6 3h12l3 6-9 12L3 9z"/>'
      '<path d="M6 3l3 6h6l3-6M9 9l3 12M15 9l-3 12M3 9h18"/></svg>',
  'bank':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M3 10 L12 4 L21 10"/>'
      '<path d="M5 10v8M19 10v8M9 10v8M15 10v8"/>'
      '<path d="M3 20h18M3 18h18"/></svg>',
  'crown':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M3 8 L7 14 L12 6 L17 14 L21 8 L20 18 H4 Z" fill="currentColor" '
      'fill-opacity="0.18"/><path d="M4 20h16"/></svg>',
  'gift':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<rect x="3" y="10" width="18" height="11" rx="1"/>'
      '<path d="M3 13h18M12 10v11"/>'
      '<path d="M8 10c-2 0-3-1-3-2.5S6 5 8 6.5 12 10 12 10s1-2 2.5-3.5S18 5 18 '
      '6.5 17 10 16 10"/></svg>',
  'ticket':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M3 8a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 '
      '1-2 2H5a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-4z"/>'
      '<path d="M9 6v12" stroke-dasharray="2 2"/></svg>',
  'bandage':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<rect x="2" y="8" width="20" height="8" rx="4" '
      'transform="rotate(-20 12 12)"/>'
      '<path d="M10 10v4M14 10v4M10 12h4"/></svg>',
  'clover':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M12 12c-3-2-6-1-6 2s3 4 6 2"/>'
      '<path d="M12 12c3-2 6-1 6 2s-3 4-6 2"/>'
      '<path d="M12 12c-2-3-1-6 2-6s4 3 2 6"/>'
      '<path d="M12 12c0 3 2 5 2 8"/></svg>',
  'handshake':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M3 11l4-4h4l3 2 3-2h4l-3 5-5 5-4-4 2-2-3 2z"/>'
      '<path d="M14 9l-3 3M15 13l-2 2"/></svg>',
  'tv':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<rect x="3" y="6" width="18" height="12" rx="2"/>'
      '<path d="M8 3l4 3 4-3"/><path d="M8 21h8"/></svg>',
  'book':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>'
      '<path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>'
      '<path d="M8 7h8M8 11h6"/></svg>',
  'globe':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="12" cy="12" r="9"/>'
      '<path d="M2 12h20"/><path d="M12 3a14 14 0 0 1 0 18"/>'
      '<path d="M12 3a14 14 0 0 0 0 18"/></svg>',
  'menu':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M4 7h16M4 12h16M4 17h16"/></svg>',
  'lock':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<rect x="4" y="11" width="16" height="10" rx="2"/>'
      '<path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>',
  'tag':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M12 3h7a2 2 0 0 1 2 2v7L11 22 2 13Z"/>'
      '<circle cx="16" cy="8" r="1.5" fill="currentColor"/></svg>',
  'dumbbell':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M6 9v6M10 7v10M14 7v10M18 9v6M3 10v4M21 10v4"/></svg>',
  'bag':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M5 8h14l-1 12a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2z"/>'
      '<path d="M9 8V6a3 3 0 0 1 6 0v2"/></svg>',
  'ball':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="12" cy="12" r="9"/>'
      '<polygon points="12,7 15,10 14,14 10,14 9,10" fill="currentColor" '
      'fill-opacity="0.2"/>'
      '<path d="M12 7L8 5M12 7l4-2M15 10l5-1M9 10l-5-1M14 14l2 5M10 '
      '14l-2 5"/></svg>',
  'keepyUppys':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<circle cx="12" cy="16" r="4"/>'
      '<path d="M8 10 Q12 3 16 10" stroke-dasharray="2 1.5"/>'
      '<path d="M14.5 5 L16 10 L11.5 10" fill="currentColor" '
      'fill-opacity="0.3"/></svg>',
  'invader':
      '<svg viewBox="0 0 24 24" $_stroke><circle cx="14" cy="5" r="2"/>'
      '<path d="M14 7.5l-2.5 4 3 2 1 5"/><path d="M11.5 11.5L8 13l-1 4"/>'
      '<path d="M14.5 13.5L18 12"/>'
      '<path d="M3 19h18" stroke-dasharray="3 2"/></svg>',
  'bootRoom':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<rect x="3" y="3" width="5.5" height="5.5" rx="1.2"/>'
      '<rect x="9.25" y="3" width="5.5" height="5.5" rx="1.2" '
      'fill="currentColor" fill-opacity="0.25"/>'
      '<rect x="15.5" y="3" width="5.5" height="5.5" rx="1.2"/>'
      '<rect x="3" y="9.25" width="5.5" height="5.5" rx="1.2" '
      'fill="currentColor" fill-opacity="0.25"/>'
      '<rect x="9.25" y="9.25" width="5.5" height="5.5" rx="1.2" '
      'fill="currentColor" fill-opacity="0.25"/>'
      '<rect x="15.5" y="9.25" width="5.5" height="5.5" rx="1.2" '
      'fill="currentColor" fill-opacity="0.25"/>'
      '<rect x="3" y="15.5" width="5.5" height="5.5" rx="1.2"/>'
      '<rect x="9.25" y="15.5" width="5.5" height="5.5" rx="1.2" '
      'fill="currentColor" fill-opacity="0.25"/>'
      '<rect x="15.5" y="15.5" width="5.5" height="5.5" rx="1.2"/></svg>',
  'scales':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M12 4v16M5 20h14"/>'
      '<path d="M4 8l4 8H0L4 8z"/><path d="M20 8l4 8h-8l4-8z"/>'
      '<path d="M4 8h16"/></svg>',
  'swords':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M6.5 17.5L3 21"/>'
      '<path d="M3 3l18 18"/><path d="M3 3l5 1 9 9 1 5-5-1L4 8z"/>'
      '<path d="M17.5 6.5L21 3"/>'
      '<path d="M21 3l-5 1-4 4 4-4 5-1z" fill="currentColor" '
      'fill-opacity="0.15"/></svg>',
  'shield':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M12 3L4 7v5c0 5 4 9 8 10 4-1 8-5 8-10V7z" fill="currentColor" '
      'fill-opacity="0.12"/>'
      '<path d="M12 3L4 7v5c0 5 4 9 8 10 4-1 8-5 8-10V7z"/></svg>',
  'sword':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M20.8 3.2 12.4 11.6" stroke-width="3.2"/>'
      '<path d="M8.6 10.6 13.4 15.4"/>'
      '<path d="M11.2 13.2 7.4 17" stroke-width="2.4"/></svg>',
  'cross':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M18 6 6 18M6 6l12 12"/></svg>',
  'check':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M4 12.5l5 5L20 6.5"/></svg>',
  'calendar':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<rect x="3" y="4" width="18" height="17" rx="2"/>'
      '<path d="M16 2v4M8 2v4M3 9.5h18"/>'
      '<path d="M8 14h2M14 14h2M8 17.5h2"/></svg>',
  'chevron': '<svg viewBox="0 0 24 24" $_stroke><path d="M9 5l7 7-7 7"/></svg>',
  'arrowUp':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M12 20V5"/>'
      '<path d="M5.5 11.5L12 5l6.5 6.5"/></svg>',
  'arrowDown':
      '<svg viewBox="0 0 24 24" $_stroke><path d="M12 4v15"/>'
      '<path d="M5.5 12.5L12 19l6.5-6.5"/></svg>',
  'flame':
      '<svg viewBox="0 0 24 24" $_stroke>'
      '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 '
      '2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 '
      '1-3a2.5 2.5 0 0 0 2.5 2.5z" fill="currentColor" '
      'fill-opacity="0.15"/></svg>',
  'chevrons':
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
      'stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M5 13l7-6 7 6"/><path d="M5 19l7-6 7 6"/></svg>',
  'bars':
      '<svg viewBox="0 0 24 24" fill="currentColor">'
      '<rect x="2" y="14" width="5" height="8" rx="1.2"/>'
      '<rect x="9.5" y="9" width="5" height="13" rx="1.2"/>'
      '<rect x="17" y="3" width="5" height="19" rx="1.2"/></svg>',
};

/// A SOLID coin, unlike [gameIcons]'s `coin`.
///
/// The stroked glyph is right beside a number and wrong the moment coins
/// overlap: hollow rings let the coin behind show straight through and the pile
/// turns to wireframe. So the disc is filled, rimmed in translucent black so
/// touching coins still read as separate, and the ¢ drawn on top in the same ink.
const _filledCoin =
    '<svg viewBox="0 0 24 24">'
    '<circle cx="12" cy="12" r="9" fill="currentColor"/>'
    '<circle cx="12" cy="12" r="9" fill="none" stroke="rgba(0,0,0,0.30)" '
    'stroke-width="1.3"/>'
    '<path d="M14.5 9c-.5-1-1.5-1.5-2.5-1.5-1.5 0-3 .8-3 2.2 0 1.3 1.3 1.7 2.7 '
    '2 1.5.35 3 .75 3 2.3 0 1.4-1.5 2.2-3 2.2-1.3 0-2.3-.5-2.8-1.5" '
    'fill="none" stroke="rgba(0,0,0,0.42)" stroke-width="1.7" '
    'stroke-linecap="round"/>'
    '<path d="M12 6.2v1.3M12 16.5V17.8" fill="none" stroke="rgba(0,0,0,0.42)" '
    'stroke-width="1.7" stroke-linecap="round"/></svg>';

/// One glyph from the set, tinted by [color].
///
/// `currentColor` is substituted for a literal before parsing rather than
/// threaded through the painter: the painter takes colours off the markup, and
/// a rewrite is one string operation against a change to every draw call.
class GameIcon extends StatelessWidget {
  const GameIcon(this.name, {super.key, this.size = 18, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink =
        color ?? DefaultTextStyle.of(context).style.color ?? Colors.white;
    return _RawSvgIcon(markup: gameIcons[name] ?? _s(''), size: size, ink: ink);
  }
}

/// The coin chip that sits beside every currency figure — gold, and the same
/// gold on both themes.
class CoinIcon extends StatelessWidget {
  const CoinIcon({
    super.key,
    this.size = 13,
    this.color,
    this.solid = false,
    this.onGlass = false,
  });

  /// On a translucent pane rather than on the app's own surface, where the
  /// light theme's bronze gold reads as a different currency from the yellow
  /// figure beside it — see [coinFigureInk].
  final bool onGlass;

  final double size;
  final Color? color;

  /// Filled rather than stroked — for piles, where rings show through.
  final bool solid;

  @override
  Widget build(BuildContext context) => _RawSvgIcon(
    markup: solid ? _filledCoin : gameIcons['coin']!,
    size: size,
    // A filled disc carries its own contrast through the black rim, so it stays
    // actual gold on a white page where the stroked glyph has to go bronze. On
    // GLASS the stroked one goes yellow too — the figure beside it is
    // [coinFigureInk] and a bronze ring next to a yellow number is two
    // currencies in one pair.
    //
    // **The glyph takes no halo where the figure does.** That is the HUD's own
    // split and not an oversight: a coin is a coin at whatever luminance,
    // because what identifies it is its SHAPE, and the number beside it is the
    // part that has to be READ. See [coinFigureShadows].
    ink:
        color ??
        (solid
            ? gameGold
            : onGlass
            ? coinFigureInk(context, onGlass: true)
            : goldFor(context)),
  );
}

/// **THE SLOT A COIN GLYPH GOES INTO, inside a sentence.**
///
/// Some copy names the currency mid-line rather than in front of it —
/// `club.need_more` is "Need {coin} {amount} more" — and WHERE it names it
/// moves with the language: first word in English and German, mid-sentence in
/// Portuguese, Japanese and Chinese. So there is no fixed position on the
/// control for a leading widget to take, and a `String` cannot carry a widget.
/// That is the same limit `t()` states about `<strong>`, and it is why the
/// button wore a 💰 while every other priced control in the app wore the set's
/// own coin.
///
/// Fill the placeholder with this instead of an emoji, then hand the line to
/// [withCoinGlyph]. A NUL cannot appear in translated copy, so the split can
/// never cut a sentence in the wrong place.
const String coinSlot = '\u0000';

/// That line as spans, with the app's coin where the translator put it.
///
/// The plain-text reading is [withoutCoinGlyph], which is what a control's
/// semantics and a `find.text` want.
List<InlineSpan> withCoinGlyph(String line, {double size = 11}) {
  final parts = line.split(coinSlot);
  return [
    for (var i = 0; i < parts.length; i++) ...[
      if (i > 0)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          // No colour: `GameIcon` falls back to the ambient text style, so the
          // glyph takes whatever ink the control prints its label in.
          child: CoinIcon(size: size),
        ),
      if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
    ],
  ];
}

/// The same line with the slot taken out and the space it left closed up.
String withoutCoinGlyph(String line) =>
    line.replaceAll(coinSlot, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

/// A cluster of [n] coins, for the shop's coin-bundle tiles.
///
/// The four bundles used to carry a bag, a gem, a bank and a crown, which said
/// nothing about how much each gives — and one advertised a coin pack with the
/// icon of a different currency. A count of coins is the one visual that scales
/// with what is being bought.
class CoinCluster extends StatelessWidget {
  const CoinCluster({super.key, required this.n, this.size = 30});

  final int n;
  final double size;

  /// `[dx, dy, scale]` per coin, hand-placed so each tier reads as a pile
  /// rather than a grid. Back coins are smaller and lower to fake depth.
  static const _layouts = <int, List<(double, double, double)>>{
    1: [(0, 0, 1)],
    2: [(-5, 3, 0.88), (5, -3, 1)],
    3: [(-7, 5, 0.8), (7, 5, 0.8), (0, -4, 1)],
    5: [
      (-10, 7, 0.66),
      (0, 8, 0.7),
      (10, 7, 0.66),
      (-5, -1, 0.86),
      (6, -4, 0.94),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final coins = _layouts[n] ?? _layouts[1]!;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (final (dx, dy, s) in coins)
            Transform.translate(
              offset: Offset(dx, dy),
              child: CoinIcon(size: size * s, solid: true),
            ),
        ],
      ),
    );
  }
}

/// Parses once per (markup, ink) pair. The set is small and the same dozen
/// glyphs redraw every frame on the HUD, so the parse is memoised rather than
/// repeated per build.
class _RawSvgIcon extends StatelessWidget {
  const _RawSvgIcon({
    required this.markup,
    required this.size,
    required this.ink,
  });

  final String markup;
  final double size;
  final Color ink;

  static final _cache = <String, List<SvgNode>>{};

  @override
  Widget build(BuildContext context) {
    final hex = ink.toARGB32().toRadixString(16).padLeft(8, '0');
    final key = '#${hex.substring(2)}${hex.substring(0, 2)}';
    final resolved = markup.replaceAll('currentColor', key);
    final nodes = _cache.putIfAbsent(resolved, () => parseSvg(resolved));
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SvgPainter(nodes: nodes, viewBox: viewBoxOf(markup)),
      ),
    );
  }
}
