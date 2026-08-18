# The i18n layer — design

**Status:** approved, ready for a plan.
**Supersedes** the `### i18n` section of
`2026-08-17-flutter-port-design.md`, which chose ARB + `gen_l10n`. See
"Why not ARB" below; that section is amended to point here.

## Purpose

M3 is the UI, and no screen can render a string until `t()` exists. The engines
are already emitting translation KEYS — `commentary.flow.*` from `match_events`,
`ach.title.*` / `ach.desc.*` from the achievements — so the match feed and the
trophy room cannot show anything at all without a lookup layer. This lands it
before the first screen, rather than hardcoding English into 76 screens and
retrofitting.

The side effect is that M5 mostly disappears into this module: the ten catalogues
come across in the same pass, because a generator that converts one converts ten.
What is left of M5 afterwards is checking the long-language layouts.

## What is actually there

Measured, not estimated, from `../merge-empire-fc/src/i18n/locales/`:

| | |
|---|---|
| Keys | 2,652 |
| Locales | 10 — ar, de, en, es, fr, it, ja, ko, pt, zh |
| Key parity | exact: no locale is missing a key or carries an orphan |
| Value types | every value in every catalogue is a string |
| Size | 1.84 MB as JSON, ~180 KB a locale |
| Escaping hazards | none — no value anywhere contains `$`, a backslash or a newline |

Two findings shape the design:

- **30 keys are not valid identifiers.** `event.wc2026.fact.Bosnia and
  Herzegovina.0`, `event.wc2026.fact.Türkiye.1` — spaces and non-ASCII, because
  the key is built from a nation name at runtime.
- **57 keys drop an English placeholder in translation**, all of them `{s}`.
  That is English's plural suffix hack; a language that pluralises by inflection
  has no use for it. This is correct, and it means substitution must tolerate a
  param with nowhere to go.

## Why not ARB / `gen_l10n`

The earlier spec chose it, and the measurement above rules it out:

1. `gen_l10n` emits **one method per key**. The 30 keys with spaces and
   diacritics cannot become method names.
2. The engines resolve keys **at runtime, from strings they computed**.
   `gen_l10n` offers no string → message lookup, so we would carry a
   2,652-entry `Map<String, Function>` beside the generated class — the map,
   with extra steps.
3. `gen_l10n` has **no per-key fallback**. The earlier spec already flagged that
   a custom wrapper would be needed to stop a missing translation rendering as
   blank UI instead of English.

Once the map and the wrapper are both required, `gen_l10n` contributes nothing.
`flutter_localizations` is still added — for Material's own widget strings and
for Arabic `Directionality` — but our catalogue is our own.

## Architecture

### Generated catalogues

`tool/gen_i18n.mjs` imports the ten JS catalogues the same way every
`tool/dump_*_reference.mjs` script does, and writes:

- `lib/i18n/locales/<id>.g.dart` — one `const Map<String, String>` each, keys in
  the source file's insertion order so a regeneration diffs cleanly.
- `lib/i18n/catalogs.g.dart` — the `{id: catalog}` registry.

Generated, not hand-maintained: English is still authored in the JS repo until
cutover, and hand-editing 26,520 entries is not a thing anyone should do.

### The lookup layer

`lib/i18n/i18n.dart`, hand-written and Flutter-free, so it runs under plain
`dart test` and the architecture test stays green:

```dart
void   setLocale(String id);          // unknown id → English
String getLocale();
String t(String key, [Map<String, Object?> params = const {}]);
String tName(String prefix, Object idOrObj);
```

`t()` is **synchronous**, and that is the load-bearing decision. It is called
from `build` methods and from formatters next to the engines; an async lookup
would poison every call site. The cost is that all ten catalogues are compiled
into the binary rather than loaded on demand — 1.84 MB, against a boot step and
an async API. Worth it.

### The contract, faithful to the JS

- **Three-step fallback**: active catalogue → English → *the raw key*. A missing
  translation surfaces as `ach.title.foo`, never as empty UI. This is the
  behaviour the earlier spec warned about losing.
- **Substitution is literal `split`/`join`.** A param with no placeholder is
  silently ignored (the 57 `{s}` cases). A placeholder with no param is left
  standing. Neither throws.
- **`setLocale` with an unknown or retired id lands on English**, so a corrupt
  save or a dropped catalogue cannot leave the app without strings.
- **`tName(prefix, idOrObj)`** resolves `<prefix>.<id>` and falls back to the
  object's English `name` field, then the id.
- The JS also sets `document.documentElement.dir`. That half is dropped:
  `flutter_localizations` gives Arabic RTL through `Directionality`.

### Reactivity

The same shape the save already uses in `providers/game_providers.dart`: a
module-scope singleton keeps `t()` synchronous and reachable from engines and
tests, and a `localeProvider` sets it and bumps a revision so a Settings change
rebuilds the tree. `MaterialApp.locale` follows the provider, which is what
turns Arabic RTL on.

Boot is already half-built: `state_schema.dart` writes `'locale':
detectLocale()`, and `i18n/detect.dart` is ported with the device locale
injected rather than read off the binding. `main.dart` injects
`PlatformDispatcher.instance.locales`, then `setLocale(save['locale'])`.

## Testing

The JS guard suite (`src/i18n/i18n.test.js`) is ported nearly whole. It is
better than its size suggests, and one of its guards is a reason to do this
module now rather than later.

- **Key parity** — all ten catalogues against English, no missing, no orphans.
- **No invented placeholders** — a translation may drop one of English's, but
  may not introduce one English does not define. An unknown placeholder renders
  literally as `{x}`.
- **No duplicate keys** in any catalogue.
- **Call-site scan: every static `t('literal')` in `lib/` exists in English.**
  This is the test that stops a screen shipping a raw key, and it wants to exist
  *before* the 76 screens do. Ported to scan `lib/**.dart` and skip the
  generated catalogues.
- **Runtime-built keys**, which the call-site scan cannot see, checked against
  the Dart data tables that are already ported: every quest in `data/quests`
  has a `quest.<id>` string; every hair, beard, hat, face, colour, build,
  outfit and emote id in `data/manager_looks` and `data/manager_mood` has a
  `customise.*` name; skin tones stay numbered via `{n}` rather than named.
- **Gendered pronouns** — English only. About half the players in the game are
  women, so a string saying "he" is wrong half the time it renders; this caught
  nine such strings in the JS. Deliberately not run against the gendered
  languages, where agreement lives in inflection and the check returns dozens of
  legitimate hits.
- **A `test/fixtures/i18n_reference.json`** from the live JS, matching the
  established fixture pattern: resolutions through `t()` and `tName()` including
  the fallback chain, the ignored-param case and the unfilled-placeholder case,
  so a bad regeneration is caught rather than assumed.

One guard does **not** port yet: the JS asserts that the Settings language
picker lists exactly `SUPPORTED_LOCALES`. There is no Settings screen until
later in M3, so that check lands with it.

## Scope

In: the generator, the ten catalogues, the lookup layer, the provider, boot
wiring, the tests above, and amending the superseded spec section.

Out: the Settings language picker, RTL layout polish beyond `Directionality`,
and any screen. Long-language layout checking (German is the measured worst
case) stays in M5, because it needs screens to check.
