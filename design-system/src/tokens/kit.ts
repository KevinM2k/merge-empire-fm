// Port of lib/util/kit_theme.dart. Values stay in the form that file emits them
// — '#rrggbb', '#rgb' or 'hsl(h,s%,l%)' — so fixtures/kit_tokens.json compares
// byte-exact against Dart and no conversion sits between the two runtimes.

export type Hsl = { h: number; s: number; l: number };

// Dart's num.round() is half-away-from-zero; JS Math.round is half-up. Only the
// negatives differ, and none of the call sites here go negative — but the port
// is worth nothing if it is only accidentally right.
const round = (v: number): number => (v < 0 ? -Math.round(-v) : Math.round(v));

const channel = (hex: string, start: number): number =>
  parseInt(hex.substring(start, start + 2), 16);

export function hexToHsl(hex: string): Hsl {
  const r = channel(hex, 1) / 255;
  const g = channel(hex, 3) / 255;
  const b = channel(hex, 5) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  let s = 0;
  const l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    else if (max === g) h = ((b - r) / d + 2) / 6;
    else h = ((r - g) / d + 4) / 6;
  }
  return { h: round(h * 360), s: round(s * 100), l: round(l * 100) };
}

export function hslToHex(h: number, s: number, l: number): string {
  const sat = s / 100;
  const lig = l / 100;
  const a = sat * Math.min(lig, 1 - lig);
  const f = (n: number): string => {
    const k = (n + h / 30) % 12;
    const colour = lig - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
    return round(255 * colour).toString(16).padStart(2, '0');
  };
  return `#${f(0)}${f(8)}${f(4)}`;
}

const srgbToLinear = (c: number): number =>
  c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);

export function relLuminance(hex: string): number {
  const r = srgbToLinear(channel(hex, 1) / 255);
  const g = srgbToLinear(channel(hex, 3) / 255);
  const b = srgbToLinear(channel(hex, 5) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function contrastRatio(a: number, b: number): number {
  const hi = a > b ? a : b;
  const lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

export const INK_DARK = '#111111';
export const INK_LIGHT = '#ffffff';

// Not "whichever contrasts more" — dark ink wins that on most mid-tones and
// would throw away the white-on-accent look. 2.2 only catches the kits where
// white genuinely disappears. See the Dart for the measured cases.
export const WHITE_INK_MIN_CONTRAST = 2.2;

export function inkFor(hex: string): string {
  const white = contrastRatio(relLuminance(hex), relLuminance(INK_LIGHT));
  return white >= WHITE_INK_MIN_CONTRAST ? INK_LIGHT : INK_DARK;
}

export const kitSaturation = (s: number): number => Math.max(20, Math.min(s, 80));

export const kitHueRotate = (h: number): number => (((h - 123) % 360) + 540) % 360 - 180;

export const patternHueRotate: Record<string, number> = {
  turf: 0, humbug: 180, sunset: 30, midnight: -90, empire: -120, void: 150,
};

export interface KitSurfaces {
  bg: string;
  surface: string;
  surface2: string;
  border: string;
  textMuted: string;
  accent: string;
  accentBright: string;
  accentBrightInk: string;
  accentInk: string;
  hueRotate: number;
}

const patternLightAccent: Record<string, string> = {
  turf: '#2e7d32', humbug: '#d32f2f', sunset: '#e64a19',
  midnight: '#3355ee', empire: '#0099cc', void: '#7733cc',
};

// Neutral on purpose: hue is not free at a fixed lightness, and a green-tinted
// grey at 39% lands under 3:1 on the pale panels. Boxes take the club, small
// grey text does not.
const LIGHT_TEXT_MUTED = '#5b616b';

function lightFrom(accentHex: string, hueRotate: number): KitSurfaces {
  const hsl = hexToHsl(accentHex);
  const h = hsl.h;
  const sat = kitSaturation(hsl.s);
  return {
    bg: `hsl(${h},${sat}%,99%)`,
    surface: `hsl(${h},${round(sat * 0.75)}%,95%)`,
    surface2: `hsl(${h},${round(sat * 0.65)}%,90%)`,
    border: `hsl(${h},${round(sat * 0.55)}%,84%)`,
    textMuted: LIGHT_TEXT_MUTED,
    accent: accentHex,
    accentBright: `hsl(${hsl.h},60%,36%)`,
    accentBrightInk: inkFor(hslToHex(hsl.h, 60, 36)),
    accentInk: inkFor(accentHex),
    hueRotate,
  };
}

export const DARK_MODE_INK_DARK = '#0d0d0d';

function darkFrom(
  accentHex: string,
  hueRotate: number,
  opts: { mutedSat?: number; mutedLightness?: number; ink?: string } = {},
): KitSurfaces {
  const { mutedSat = 0.4, mutedLightness = 55, ink } = opts;
  const hsl = hexToHsl(accentHex);
  const h = hsl.h;
  const sat = kitSaturation(hsl.s);
  return {
    bg: `hsl(${h},${sat}%,7%)`,
    surface: `hsl(${h},${round(sat * 0.75)}%,12%)`,
    surface2: `hsl(${h},${round(sat * 0.65)}%,16%)`,
    border: `hsl(${h},${round(sat * 0.55)}%,22%)`,
    textMuted: `hsl(${h},${round(sat * mutedSat)}%,${mutedLightness}%)`,
    accent: accentHex,
    accentBright: `hsl(${h},90%,70%)`,
    accentBrightInk: '#0d0d0d',
    accentInk: ink ?? (inkFor(accentHex) === INK_DARK ? DARK_MODE_INK_DARK : INK_LIGHT),
    hueRotate,
  };
}

// The five whose dark theme is a hand-picked table rather than a derivation.
const patternDark: Record<string, KitSurfaces> = {
  humbug: { bg: '#111', surface: '#1a1a1a', surface2: '#222', border: '#3a3a3a',
    textMuted: '#d0d0d0', accent: '#d32f2f', accentBright: '#ff5c5c',
    accentBrightInk: '#0d0d0d', accentInk: '#ffffff', hueRotate: 180 },
  sunset: { bg: '#1a0800', surface: '#2a1008', surface2: '#3a1a0c', border: '#5a2a14',
    textMuted: '#d4956a', accent: '#ff6b35', accentBright: '#ffb347',
    accentBrightInk: '#0d0d0d', accentInk: '#0d0d0d', hueRotate: 30 },
  midnight: { bg: '#03030f', surface: '#08081e', surface2: '#0e0e2c', border: '#1a1a44',
    textMuted: '#7070b0', accent: '#4466ff', accentBright: '#88aaff',
    accentBrightInk: '#0d0d0d', accentInk: '#ffffff', hueRotate: -90 },
  empire: { bg: '#001418', surface: '#001e24', surface2: '#002830', border: '#00404e',
    textMuted: '#4aa8c0', accent: '#00c8ff', accentBright: '#7ee8fa',
    accentBrightInk: '#0d0d0d', accentInk: '#001418', hueRotate: -120 },
  void: { bg: '#030006', surface: '#09000f', surface2: '#100018', border: '#220030',
    textMuted: '#7a50a0', accent: '#9933ff', accentBright: '#cc88ff',
    accentBrightInk: '#0d0d0d', accentInk: '#ffffff', hueRotate: 150 },
};

const TURF_GREEN = '#2e7d32';
export const DEFAULT_KIT_COLOR = '#4caf50';

/** The palette for a kit id — one of the six pattern names, or a '#rrggbb'.
 *  Anything unrecognised lands on the default green: the id comes off a save,
 *  so a future build's kit must not brick an older one. */
export function buildKitSurfaces(kitId: string, light: boolean): KitSurfaces {
  const patternAccent = patternLightAccent[kitId];
  const known = patternAccent !== undefined || kitId.startsWith('#');
  const hueRotate = patternHueRotate[kitId];

  if (light) {
    const accent = patternAccent ?? (known ? kitId : DEFAULT_KIT_COLOR);
    return lightFrom(accent, hueRotate ?? kitHueRotate(hexToHsl(accent).h));
  }

  const table = patternDark[kitId];
  if (table) return table;
  if (kitId === 'turf') {
    return darkFrom(TURF_GREEN, hueRotate ?? 0,
      { mutedSat: 0.3, mutedLightness: 82, ink: INK_LIGHT });
  }
  const accent = known ? kitId : DEFAULT_KIT_COLOR;
  return darkFrom(accent, kitHueRotate(hexToHsl(accent).h));
}
