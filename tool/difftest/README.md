# The season golden

The per-module fixtures in `test/fixtures/` each pin one engine. This pins the
whole thing at once: it plays **entire seasons** through the Dart engines and
compares every byte of the save at every step against a recorded run.

```bash
dart run tool/dump_positional_golden.dart        # regenerate (also the match golden)
flutter test test/difftest/season_difftest_test.dart
```

## History

Until the positional sim took over the scoreline this compared against the JS
(`run.mjs` here played the same seasons through `../merge-empire-fc`). The JS
still decides a match with two Poisson draws, so it stopped being a reference
for one, and the recorded run is now the Dart port's own. That makes it a
**golden**, not a differential test: it catches a change that moved a number,
and says nothing about whether the number was right. `positional_balance_test`
is the half that asks that.

## What it records

`test/fixtures/positional_season_base.json` holds the two starting saves as
the node harness built them, frozen as an input. From each, for six seasons,
every fixture goes through the sequence the League screen uses — `simulateMatch`,
the two quest counters, `finalizeMatchOutcome`, `resolveMatchQuests`,
`applyMatchRewards` — then `endSeason`.

- **every match** — a 32-bit hash of the canonicalised whole save, plus the
  headline result fields. The hash is what catches a divergence; the result is
  what tells you what kind it was.
- **every season boundary** — the whole save, canonicalised. Something to
  actually diff once a hash has told you which match went wrong.

The canonical form (`test/support/canonical.dart`) normalises number formatting
so `1` and `1.0` hash alike, and does NOT normalise key order, because the
save's key order is part of the format. The int-versus-double rule it hides is
asserted separately against the finished saves, where it belongs.

Both random streams are pinned: the seeded one through `setSeed`, and the
unseeded `Math.random` half of the feed through one `JsMathRandom` driven into
`setMatchRandom` and `setEventRandom` — a third of the feed comes off that
stream and pinning only the seeded half would leave it uncompared.
