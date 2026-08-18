# The differential harness

The eleven per-module fixtures in `test/fixtures/` each pin one engine against
node. This pins the whole thing at once: it plays **entire seasons** through the
JS engines and compares every byte of the save the Dart port produces doing the
same.

The difference matters. A per-module fixture proves a function agrees on the
inputs somebody thought to write down. A season proves the functions agree with
*each other* — that the pyramid the season boundary shuffles is the one the next
season's fixtures are drawn from, that the ratings a match writes are the ones
the table reads, that thirty thousand draws later both runtimes are still on the
same number.

```bash
node tool/difftest/run.mjs > test/fixtures/season_difftest.json
flutter test test/difftest/season_difftest_test.dart
```

## What it does

`run.mjs` plays `SEASONS` whole seasons from a fixed save and a fixed seed:

1. every fixture in the season, through the same sequence the League screen
   uses — `simulateMatch`, the two quest counters, `finalizeMatchOutcome`,
   `resolveMatchQuests`, `applyMatchRewards`;
2. `endSeason` at the whistle on the last one;
3. repeat.

Both random streams are pinned. The seeded one is `setSeed`; the unseeded
`Math.random` is replaced with a second mulberry32, which the Dart side drives
through `setMatchRandom` and `setEventRandom` — the same trick the match
orchestration fixture uses, for the same reason: a third of the feed comes off
that stream and pinning only the seeded half would leave it uncompared.

## What it records

A full save per checkpoint would be a hundred kilobytes times three hundred
checkpoints, so instead:

- **every match** — a 32-bit hash of the canonicalised whole save, plus the
  headline result fields. The hash is what catches a divergence; the result is
  what tells you what kind it was.
- **every season boundary** — the whole save, canonicalised. Something to
  actually diff once a hash has told you which match went wrong.

The canonical form normalises number formatting — JS prints `1`, Dart prints
`1.0`, and the harness would otherwise report every save as different for a
reason that is not a difference. It does NOT normalise key order, because the
save's key order is part of the format.

The int-versus-double rule the canonical form deliberately hides is not lost: it
is asserted separately against the season-boundary saves, which is where it
belongs — one clear failure naming the field, rather than every hash after it
going red at once.
