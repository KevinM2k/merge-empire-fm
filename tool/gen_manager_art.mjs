// Captures the manager avatar's parts as data.
//
// `data/managerAvatar.js` holds every hairstyle, beard, hat, outfit overlay and
// neck item as an SVG FRAGMENT — a bare `<path>` or two with no wrapper — all
// drawn in one shared space so they stack into a figure. Same kind of port as
// the club art and the i18n catalogues: the strings come across verbatim and
// `ui/widgets/svg_canvas.dart` draws them, rather than thirty-odd shapes being
// transcribed into Dart by eye.
//
// TWO THINGS ARE RESOLVED on the way out, and both have to be:
//
//   * CSS custom properties become their fallbacks. The fragments paint with
//     `var(--hair, #3a2a1c)` so the live figure can be recoloured from the
//     club's kit; the painter has no CSS, and the fallback IS the colour the JS
//     shows before a kit is applied, so nothing is invented. Recolouring is
//     done at draw time instead — see `manager_art.dart`.
//   * `currentColor` becomes the skin tone, for the same reason.
//
// HAIR COMES IN TWO LAYERS. A style is either one string or `{back, front}`:
// the mass behind the skull and the part that falls over it. They are kept
// apart because the head is drawn BETWEEN them, and flattening the two would
// put a mohawk's fin behind the face.
//
//   node tool/gen_manager_art.mjs

import { writeFileSync } from 'node:fs';

const av = await import('../../merge-empire-fc/src/data/managerAvatar.js');

// The figure's own space. Every fragment is drawn against it, which is what
// keeps a hat on the head without any nudging.
const VIEWBOX = '0 0 120 170';

// The defaults the fragments already carry. Listed rather than scraped from
// each `var()` so a fragment that forgot its fallback fails loudly here rather
// than generating an unpainted shape.
const VARS = {
  '--hair': '#3a2a1c',
  '--kit': '#4caf50',
  '--kit-dark': '#2e6b30',
  '--kit-light': '#6fbf73',
  '--trim': '#2e6b30',
  '--skin': '#e8b48c',
  '--skin-shade': '#c9946f',
  '--coat': '#2f3a4a',
  '--suit': '#26303d',
  '--shirt': '#f2f2f2',
};

const resolveVars = (markup) =>
  String(markup).replace(
    /var\(\s*(--[a-z-]+)\s*(?:,\s*([^)]+))?\)/gi,
    (_, name, fallback) => {
      const value = (fallback ?? '').trim() || VARS[name];
      if (!value) throw new Error(`no fallback and no default for ${name}`);
      return value;
    },
  );

/** One fragment, wrapped so the painter can read it on its own. */
const wrap = (markup) => {
  const body = resolveVars(markup).replace(/currentColor/g, VARS['--skin']);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${VIEWBOX}">${body}</svg>`;
};

const lit = (s) =>
  "'''" + String(s).replace(/\\/g, '\\\\').replace(/\$/g, '\\$') + "'''";

/** A style is one string, or a back/front pair. Normalised to the pair. */
const layers = (value) =>
  typeof value === 'string'
    ? { back: '', front: value }
    : { back: value.back ?? '', front: value.front ?? '' };

// HAIR IS NOT A BLOCK. The JS draws each style as one filled silhouette, which at
// this size reads as a helmet — a shape the right colour with nothing happening
// inside it. Three passes over the SAME path fix it without a line of new
// geometry, which matters because there are twelve styles and the painter
// supports neither clip paths nor scale transforms, so anything hand-drawn would
// have to be drawn twelve times and checked twelve times.
//
//   1. a soft white rim along the outline — hair catches light on its edge, and
//      the notches every one of these silhouettes already has at the temple and
//      the parting are exactly where it shows;
//   2. a darker line just inside it, in the hair's OWN slot colour so it follows
//      whatever colour the player picked;
//   3. a highlight on the crown, for the styles with a solid cap. Skipped on the
//      spiky ones, where a blob would land in the gaps between the spikes.
//
// White at low alpha rather than a second slot: a sheen has to read on black hair
// and on blonde, and only white does both.
const CAPPED = new Set([
  'crop', 'afro', 'pony', 'bun', 'flow', 'mullet', 'curtains',
]);

// Styles that are SHADING ON A SCALP rather than a mass of hair, and which get
// none of the three passes.
//
// A buzz cut in the JS is one path at `opacity: 0.42` — the shape hair would
// occupy, tinted, with nothing else on it, because that is what a buzz cut is.
// Giving it a lit rim, an outline and two crown strands turns it into an
// outlined blob with a swoosh across it: a cap of hair drawn on a shaved head.
// The passes exist to make a MASS of hair read as hair; there is no mass here.
const SCALP = new Set(['buzz']);

/** Every `d` in a fragment, so the passes can re-use the silhouette. */
const pathsOf = (markup) => [...markup.matchAll(/\sd="([^"]+)"/g)].map((m) => m[1]);

const strands = (markup, id) => {
  if (SCALP.has(id)) return '';
  const ds = pathsOf(markup);
  if (ds.length === 0) return '';
  const rim = ds
    .map(
      (d) =>
        `<path d="${d}" fill="none" stroke="#ffffff" stroke-opacity="0.22" ` +
        `stroke-width="1.6" stroke-linejoin="round"/>`,
    )
    .join('');
  const inner = ds
    .map(
      (d) =>
        `<path d="${d}" fill="none" stroke="${VARS['--hair']}" ` +
        `stroke-opacity="0.55" stroke-width="0.7" stroke-linejoin="round"/>`,
    )
    .join('');
  // The crown, where the light lands. Two thin arcs rather than an ellipse: a
  // blob reads as plastic and a pair of strokes reads as strands.
  const crown = CAPPED.has(id)
    ? '<path d="M53.5 40.5 C55 35.5 59 33 63.5 33" fill="none" ' +
      'stroke="#ffffff" stroke-opacity="0.3" stroke-width="1.5" ' +
      'stroke-linecap="round"/>' +
      '<path d="M57 45 C58 41 61 38.5 64.5 37.5" fill="none" ' +
      'stroke="#ffffff" stroke-opacity="0.18" stroke-width="1.2" ' +
      'stroke-linecap="round"/>'
    : '';
  return rim + inner + crown;
};

const lines = [
  '// GENERATED by tool/gen_manager_art.mjs — do not edit.',
  '// Source: ../merge-empire-fc/src/data/managerAvatar.js',
  '',
  "/// The manager avatar's parts, as the SVG fragments the JS composes.",
  '///',
  '/// Every part is drawn in the same `0 0 120 170` space, so a hat lands on the',
  '/// head with no positioning of its own. Drawn by',
  '/// `ui/widgets/svg_canvas.dart`; recoloured at draw time by',
  '/// `data/manager_art.dart`, which is also where the layering is explained.',
  'library;',
  '',
  '/// The space every part is drawn in.',
  'const double managerArtWidth = 120;',
  'const double managerArtHeight = 170;',
  '',
  '/// Hair, as the mass BEHIND the skull and the part that falls over it. The',
  '/// head is drawn between the two.',
  'const Map<String, (String back, String front)> managerHair = {',
];

for (const [id, value] of Object.entries(av.HAIR_STYLES)) {
  const { back, front } = layers(value);
  lines.push(`  '${id}': (`);
  // The back mass gets the rim and the inner line but no crown — the crown is
  // behind the skull there and would never be seen.
  lines.push(`    ${back ? lit(wrap(back + strands(back, ''))) : "''"},`);
  lines.push(`    ${front ? lit(wrap(front + strands(front, id))) : "''"},`);
  lines.push('  ),');
}
lines.push('};', '');

// **STUBBLE HAS TO READ AS A CHOICE, and at the JS's own alpha it does not.**
//
// `FACIAL_HAIR.stubble` is the beard's jaw path at `opacity="0.42"` — right in
// a DOM, where the avatar is drawn large and the tint sits over a flat CSS
// skin fill. The port draws the same figure into a painter at chip size, on a
// shaded face, and 0.42 of it disappears: reported from the couch as stubble
// and NONE looking almost the same, which is the one comparison that has to be
// obvious because they are neighbours in the picker.
//
// Raised here rather than in the spec, which is where this generator already
// makes the port's own medium work — see `strands` and `SCALP`, neither of
// which has a counterpart in the JS. `none` stays empty; the fix is stubble
// being visible, not none growing any.
const STUBBLE_ALPHA = 0.72;

const readable = (id, markup) => id !== 'stubble'
  ? markup
  : markup.replace(/opacity="0\.42"/, `opacity="${STUBBLE_ALPHA}"`);

const flatTables = {
  managerBeards: ['FACIAL_HAIR', "Facial hair, over the jaw."],
  managerFaces: [
    'FACE_ITEMS',
    'On the face — spectacles, shades, goggles. Its own slot rather than part of'
      + ' the headwear, which is what lets a manager wear a cap AND glasses:'
      + ' the two were one `acc` field and could not be worn together.',
  ],
  managerHats: ['HATS', 'Headwear, over everything on the head.'],
  managerOutfits: [
    'OUTFIT_OVERLAYS',
    'What he is wearing, over the torso. Most of the tracksuit is palette rather'
      + ' than shape, so several of these are a collar line and nothing else.',
  ],
  managerNeck: [
    'NECK_ITEMS',
    'Round the throat — drawn UNDER the head and OVER the torso, which is why it'
      + ' is its own slot rather than part of the outfit.',
  ],
};

for (const [name, [source, doc]] of Object.entries(flatTables)) {
  lines.push(`/// ${doc}`);
  lines.push(`const Map<String, String> ${name} = {`);
  for (const [id, raw] of Object.entries(av[source])) {
    const markup = name === 'managerBeards' ? readable(id, raw) : raw;
    lines.push(`  '${id}': ${markup ? lit(wrap(markup)) : "''"},`);
  }
  lines.push('};', '');
}

// ── Mouths ──────────────────────────────────────────────────────────────────
// The mouth is COMPUTED from five numbers per mood rather than drawn, so the
// five paths are generated by asking the module for them. `manager_mood.dart` is
// ported and had nothing to draw with: the mood a manager is in was a number
// nobody could see.
lines.push(
  "/// The mouth for each mood, which is how a manager's mood becomes visible.",
  '///',
  '/// Computed by the JS from five numbers per mood (`MOOD_MOUTHS` plus',
  '/// `mouthPath`), so these are the RESULTS of asking it, not a transcription of',
  '/// the maths. The ids are `Mood`\'s own names — see `data/manager_mood.dart`.',
  'const Map<String, String> managerMouths = {',
);
for (const mood of av.MOOD_MOUTH_IDS) {
  lines.push(`  '${mood}': ${lit(wrap(av.moodMouthMarkup(mood)))},`);
}
lines.push('};', '');

writeFileSync('lib/data/manager_art.g.dart', lines.join('\n'), 'utf8');

const count = Object.keys(av.HAIR_STYLES).length
  + Object.keys(av.FACIAL_HAIR).length
  + Object.keys(av.FACE_ITEMS).length
  + Object.keys(av.HATS).length
  + Object.keys(av.OUTFIT_OVERLAYS).length
  + Object.keys(av.NECK_ITEMS).length
  + av.MOOD_MOUTH_IDS.length;
console.log(`wrote lib/data/manager_art.g.dart — ${count} parts`);
