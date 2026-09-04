// The TS palette must agree with lib/util/kit_theme.dart value for value.
// Regenerate the fixture with: npm run tokens > fixtures/kit_tokens.json
import { describe, it, expect } from 'vitest';
import fixture from '../fixtures/kit_tokens.json';
import {
  buildKitSurfaces, hexToHsl, hslToHex, relLuminance, inkFor,
  kitSaturation, kitHueRotate,
} from '../src/tokens/kit';

describe('kit surfaces match the Dart engine', () => {
  for (const [key, expected] of Object.entries(fixture.surfaces)) {
    it(key, () => {
      const [kitId, mode] = key.split('|');
      expect(buildKitSurfaces(kitId, mode === 'light')).toEqual(expected);
    });
  }
});

describe('colour primitives match the Dart engine', () => {
  for (const [hex, expected] of Object.entries(fixture.primitives)) {
    it(hex, () => {
      const hsl = hexToHsl(hex);
      expect([hsl.h, hsl.s, hsl.l]).toEqual(expected.hsl);
      expect(hslToHex(hsl.h, hsl.s, hsl.l)).toBe(expected.roundTrip);
      expect(relLuminance(hex)).toBeCloseTo(expected.relLuminance, 12);
      expect(inkFor(hex)).toBe(expected.inkFor);
      expect(kitSaturation(hsl.s)).toBe(expected.kitSaturation);
      expect(kitHueRotate(hsl.h)).toBe(expected.kitHueRotate);
    });
  }
});
