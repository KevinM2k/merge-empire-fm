// Reference output from the pure half of four small utilities: the kit colour
// maths, the ATK/DEF display clamp, the region code, and the low-end device
// policy.
//
// The kit maths is the one with a bug history. `inkFor` used to be an
// HSL-lightness test, which is not perceived brightness — pure yellow sits at
// the same 50% L as a mid green and reflects far more light, so a yellow kit got
// WHITE ink and rendered invisible text on a yellow button. The colours below
// walk the hues either side of that decision, and the round trip through HSL and
// back is pinned too, because both directions round and a port that rounds
// differently shifts every derived surface by a shade.
//
//   node tool/dump_utils_reference.mjs > test/fixtures/utils_reference.json

const kt = await import('../../merge-empire-fc/src/utils/kitTheme.js');
const sd = await import('../../merge-empire-fc/src/utils/statDisplay.js');

const out = {};

// ── The kit colour maths ────────────────────────────────────────────────────
// `hexToHsl`, `hslToHex`, `relLuminance` and `contrastRatio` are not exported —
// only `inkFor` is — so the internals are reproduced here from the source and
// the exported function is compared against the real one. If the two ever
// disagree on the same colour, that IS the failure.
const hexToHsl = (hex) => {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0;
  const l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
      case g: h = ((b - r) / d + 2) / 6; break;
      case b: h = ((r - g) / d + 4) / 6; break;
    }
  }
  return [Math.round(h * 360), Math.round(s * 100), Math.round(l * 100)];
};

const hslToHex = (h, s, l) => {
  s /= 100; l /= 100;
  const a = s * Math.min(l, 1 - l);
  const f = (n) => {
    const k = (n + h / 30) % 12;
    const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
    return Math.round(255 * color).toString(16).padStart(2, '0');
  };
  return `#${f(0)}${f(8)}${f(4)}`;
};

const srgbToLinear = (c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const relLuminance = (hex) => {
  const r = srgbToLinear(parseInt(hex.slice(1, 3), 16) / 255);
  const g = srgbToLinear(parseInt(hex.slice(3, 5), 16) / 255);
  const b = srgbToLinear(parseInt(hex.slice(5, 7), 16) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const contrastRatio = (a, b) => {
  const [hi, lo] = a > b ? [a, b] : [b, a];
  return (hi + 0.05) / (lo + 0.05);
};

const COLOURS = [
  '#4caf50', // the default green — keeps white ink at 2.78
  '#ffd700', // yellow — the case the old lightness test got wrong
  '#ff9800', // orange — just the wrong side of the line too
  '#000000', '#ffffff', '#ff0000', '#00ff00', '#0000ff',
  '#123456', '#abcdef', '#808080', '#7f7f7f', '#010203', '#fefefe',
  '#2e7d32', '#1b1b1b', '#ff6b35', '#4466ff', '#00c8ff', '#9933ff',
  '#d32f2f', '#e64a19', '#3355ee', '#0099cc', '#7733cc',
];

out.kit = { whiteInkMinContrast: 2.2, rows: [] };
for (const hex of COLOURS) {
  const [h, s, l] = hexToHsl(hex);
  out.kit.rows.push({
    hex, hsl: [h, s, l],
    roundTrip: hslToHex(h, s, l),
    luminance: relLuminance(hex),
    contrastWithWhite: contrastRatio(relLuminance(hex), relLuminance('#ffffff')),
    contrastWithBlack: contrastRatio(relLuminance(hex), relLuminance('#111111')),
    ink: kt.inkFor(hex),
    saturation: Math.max(20, Math.min(s, 80)),
    hueRotate: ((h - 123) % 360 + 540) % 360 - 180,
  });
}

// The HSL round trip on its own, walking the wheel.
out.hslToHex = [];
for (let h = 0; h < 360; h += 30) {
  for (const [s, l] of [[0, 0], [0, 50], [0, 100], [60, 36], [90, 70], [54, 46], [80, 7], [100, 50]]) {
    out.hslToHex.push({ h, s, l, hex: hslToHex(h, s, l) });
  }
}

// ── The stat display ────────────────────────────────────────────────────────
out.fifaSplit = [];
for (const [atk, def] of [
  [0, 0], [50, 50], [100, 100], [-10, 120], [49.4, 49.5], [49.6, 50.5],
  [99.5, 0.4], [72.3, 68.8],
]) {
  out.fifaSplit.push({ atk, def, split: sd.fifaSplit(atk, def) });
}

out.fifaSplitTactic = [];
for (const [atk, def] of [[60, 60], [80, 40], [95, 95]]) {
  for (const [atkMult, defMult] of [[1, 1], [1.2, 0.85], [0.7, 1.3], [2, 2], [0, 0]]) {
    out.fifaSplitTactic.push({
      atk, def, atkMult, defMult,
      split: sd.fifaSplitTactic(atk, def, atkMult, defMult),
    });
  }
}
// The multipliers default to 1, which is what a caller with no tactic passes.
out.fifaSplitTacticBare = sd.fifaSplitTactic(61.5, 58.5);

// ── The region code ─────────────────────────────────────────────────────────
// `_detectRegionCode` is private and reads `Intl`, so the tag parsing is
// reproduced here — the table and the fallbacks are what the port has to match.
const LANG_DEFAULT_REGION = {
  en: 'GB', es: 'ES', pt: 'BR', fr: 'FR', de: 'DE',
  it: 'IT', ja: 'JP', ko: 'KR', zh: 'CN', ar: 'SA',
};
const regionFromTag = (tag) => {
  const parts = String(tag ?? '').split('-');
  if (parts.length >= 2) {
    const region = parts[parts.length - 1].toUpperCase();
    if (/^[A-Z]{2}$/.test(region)) return region;
  }
  const lang = parts[0]?.toLowerCase() ?? 'en';
  return LANG_DEFAULT_REGION[lang] ?? 'GB';
};

out.region = { table: LANG_DEFAULT_REGION, rows: [] };
for (const tag of [
  'en-GB', 'en-US', 'en_us', 'fr-CA', 'zh-Hans-CN', 'pt', 'pt-PT', 'ja', 'ko',
  'ar', 'de', 'it', 'es', 'zh', 'en', 'xx', 'xx-YY', 'e', '', 'en-GBR',
  'en-Latn', null, undefined,
]) {
  out.region.rows.push({ tag: tag ?? null, code: regionFromTag(tag) });
}

// ── The device policy ───────────────────────────────────────────────────────
out.device = {
  slowFrameMs: 24, slowFrameRatio: 0.35, sampleMs: 2500,
  firstSampleDelayMs: 5000, secondSampleDelayMs: 25000,
  minSampleFrames: 20, absurdFrameMs: 500,
  hardware: [],
};
for (const [memoryGb, cores] of [
  [null, null], [2, 8], [1, 16], [4, 4], [4, 8], [8, 4], [8, 8],
  [4, null], [null, 4], [3, 2], [5, 2],
]) {
  // The heuristic, reproduced: both signals are absent on iOS, where the
  // hardware copes fine, so missing values mean "not low-end".
  const low = (memoryGb != null && memoryGb <= 2)
    || ((memoryGb != null && memoryGb <= 4) && (cores != null && cores <= 4));
  out.device.hardware.push({ memoryGb, cores, low });
}

process.stdout.write(JSON.stringify(out));
