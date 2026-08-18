// Reference palettes from the JS kit theme.
//
// applyKitColor writes CSS custom properties onto <html> and <body> rather than
// returning anything, so the DOM it touches is stubbed and the writes recorded.
// Three surfaces are all it uses: documentElement.style, body.style, and
// body.classList, plus a body.background setter.
//
//   node tool/dump_kit_theme_reference.mjs > test/fixtures/kit_theme_reference.json

const makeStyle = (sink) => ({
  setProperty: (k, v) => {
    sink[k] = v;
  },
  set background(v) {
    sink.background = v;
  },
  get background() {
    return sink.background;
  },
  set backgroundAttachment(v) {
    sink['background-attachment'] = v;
  },
  get backgroundAttachment() {
    return sink['background-attachment'];
  },
});

let light = false;
const rootVars = {};
const bodyVars = {};

globalThis.document = {
  documentElement: { style: makeStyle(rootVars) },
  body: {
    style: makeStyle(bodyVars),
    classList: { contains: (c) => c === 'light-mode' && light },
  },
};

const { applyKitColor } = await import('../../merge-empire-fc/src/utils/kitTheme.js');

// The six pattern names, plus hexes chosen to cover the ink decision: yellow and
// cyan are the two the JS dark path gets wrong, green and red the two it gets
// right, and black/white are the ends of the lightness range.
const KITS = [
  'turf', 'humbug', 'sunset', 'midnight', 'empire', 'void',
  '#4caf50', '#ffd700', '#00c8ff', '#e53935', '#1a237e', '#ffffff', '#000000',
];

const out = { dark: {}, light: {} };
for (const mode of ['dark', 'light']) {
  light = mode === 'light';
  for (const kit of KITS) {
    for (const k of Object.keys(rootVars)) delete rootVars[k];
    for (const k of Object.keys(bodyVars)) delete bodyVars[k];
    applyKitColor(kit);
    out[mode][kit] = { ...bodyVars, '--kit-hue-rotate': rootVars['--kit-hue-rotate'] };
  }
}

process.stdout.write(JSON.stringify(out, null, 2));
