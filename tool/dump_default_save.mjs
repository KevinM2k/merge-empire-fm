// Dumps a real default v7 save from the JS source so the Dart codec is tested
// against the actual schema rather than a hand-written approximation.
//
// stateSchema.js reaches browser globals through its import chain (i18n/detect
// reads navigator/localStorage), so shim them before importing.
globalThis.navigator ??= { language: 'en-GB', languages: ['en-GB'] };
globalThis.localStorage ??= {
  getItem: () => null,
  setItem: () => {},
  removeItem: () => {},
};

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const { createDefaultState } = await import(
  '../../merge-empire-fc/src/state/stateSchema.js'
);

const state = createDefaultState();
const out = fileURLToPath(
  new URL('../test/fixtures/default_save_v7.json', import.meta.url),
);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(state, null, 2));

console.log('version:', state.version);
console.log('top-level keys:', Object.keys(state).length);
console.log('grid cells:', state.grid.cells.length);
