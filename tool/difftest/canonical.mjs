// A canonical text form for a save, and a hash of it.
//
// Two runtimes that agree on every value still disagree on how to print one:
// `JSON.stringify(1.0)` is "1" in JS and `jsonEncode(1.0)` is "1.0" in Dart. A
// harness that hashed the raw JSON would report every save as different for a
// reason that is not a difference, so integral numbers are written as integers
// on both sides.
//
// Key ORDER is deliberately NOT normalised. The save's key order is part of the
// format — the schema pins it, and the codec round trip preserves it — so a
// reordering is a real difference and the hash should catch it.
//
// The int-versus-double rule this hides is checked separately, against the
// whole saves the harness keeps at the season boundaries.

/** The canonical text for one value. */
export const canonical = (v) => {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'number') return canonicalNumber(v);
  if (typeof v === 'string') return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(canonical).join(',')}]`;
  return `{${Object.entries(v)
    .map(([k, val]) => `${JSON.stringify(k)}:${canonical(val)}`)
    .join(',')}}`;
};

/** Integral values print as integers; everything else takes its shortest form,
 *  which both runtimes derive the same way from the same IEEE754 double. */
export const canonicalNumber = (n) => {
  if (!Number.isFinite(n)) return 'null';           // JSON has no NaN/Infinity
  return Number.isInteger(n) ? String(n) : String(n);
};

/** FNV-1a over the canonical text. Small, stable, and trivial to reproduce. */
export const hashOf = (v) => {
  const s = canonical(v);
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
};
