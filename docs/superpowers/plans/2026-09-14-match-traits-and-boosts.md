# Match Traits and Manager Boosts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a gem-gated second trait slot rolling from a pool of twelve
conditional match traits, and four gem-bought consumable manager boosts — two
tapped from the live match screen, two from the bench.

**Architecture:** Both features reach the simulation through
`computeSquadRatings`'s existing `ratingMultipliers` map, so the rating engine
itself does not change. Nothing is stamped on the match `result` object, which
the parity harness compares field-for-field against a node dump. Windowed
boosts end via a timed re-simulation, and the minute-gated traits ride on the
same timer.

**Tech Stack:** Flutter 3.44.9 / Dart 3.12.2, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-14-match-traits-and-boosts-design.md`

## Global Constraints

- **Flutter 3.44.9 / Dart 3.12.2**, pinned in `.fvmrc` and CI. The same suite
  fails 34 tests on 3.47. Verify with `flutter --version` before trusting any
  green — a half-extracted SDK prints a `shared.sh: No such file` error and
  **still exits 0**.
- **`flutter analyze` must be clean before any commit.**
- **Never run `dart format`,** on the repo or on individual files. It reflows
  pre-existing long lines and trips
  `curly_braces_in_flow_control_structures` in about ten files. Match the
  surrounding style by hand.
- **The bottom half may not import Flutter.** `lib/engine/`, `lib/data/`,
  `lib/i18n/`, `lib/state/`, `lib/util/` are pure Dart, enforced by
  `test/architecture_test.dart`.
- **Nothing may be added to the match `result` map.**
  `match_orchestration_parity_test` compares it field-for-field against a node
  dump. New values leave through out-parameters or through `state`.
- **Every user-facing string goes through `t()`**, and the key must exist in
  `en` or `test/i18n/call_sites_test.dart` fails the build.
- **A new key needs all ten locales.** English in `lib/i18n/en_copy.dart`, the
  other nine in `lib/i18n/copy/<id>_copy.dart`. `t()` falls back to English,
  which is wrong for a screen built out of pools.
- **Hot restart, not hot reload, after editing `en_copy.dart`** —
  `englishCatalog` is a lazily-initialised top-level `final`.
- **Nothing ending `.g.dart` is edited by hand.**
- **Colours come from `Theme.of(context).extension<KitTheme>()!`.** A hardcoded
  colour is a bug.
- **A button's face is set through `mouldedButtonStyle(face:, edge:, …)`,**
  never `styleFrom(backgroundColor:)` or `side:`, which fail silently and are
  caught by `architecture_test.dart`.
- **Commit messages carry no Claude attribution trailer** (user's global
  CLAUDE.md), and prose stays tiny: subject plus at most two or three short
  lines.
- **A stale `build/unit_test_assets` fails widget tests that have nothing wrong
  with them** — the symptom is an `ink_sparkle.frag` manifest decode error from
  `FragmentProgram.fromAsset`. `rm -rf build/unit_test_assets` and re-run.
- Run only the test files a task touches. Ask before running the full ~4,420
  test suite.

---

## File Structure

**New, pure Dart (no Flutter import):**

| File | Responsibility |
|---|---|
| `lib/data/match_traits.dart` | The twelve trait definitions and their level ladders. Data only. |
| `lib/engine/match_trait_engine.dart` | Slot unlock, rolling, and turning a lineup plus a match context into a multiplier map. |
| `lib/data/boosts.dart` | The four boost definitions: id, gem cost, pack size, kind. |
| `lib/engine/boost_engine.dart` | Inventory: owning, granting, spending. No match knowledge. |
| `lib/engine/match_boost_state.dart` | Live windows during one match: what is active, until when, what multiplier it contributes. |

**New, Flutter:**

| File | Responsibility |
|---|---|
| `lib/ui/screens/match/boost_strip.dart` | The two proactive tiles under the tactic strip. |
| `lib/ui/screens/match/boost_bar_paint.dart` | The animated flame/wash bands on the scoreboard progress bar. |
| `lib/ui/screens/match/bench_boost_row.dart` | The VAR and Physio row inside the subs panel. |
| `lib/ui/screens/squad/match_trait_block.dart` | The locked/unlocked second slot, wrapping the existing reel. |

**Modified:**

| File | Change |
|---|---|
| `lib/engine/squad_rating.dart` | **None.** Stated so nobody adds one. |
| `lib/engine/match_orchestration.dart` | One new named parameter on `reSimulateRemainder` for the goal-rate damping. |
| `lib/data/sound_defs.dart` | The ported crowd synth plus three boost cues. |
| `lib/util/audio_render.dart` | A convolution primitive, or the delay-wash fallback. |
| `lib/engine/daily_reward_engine.dart` | A `boost` field on the `DailyReward` typedef, and day 4. |
| `lib/ui/screens/shop/shop_spend.dart` | Four boost tiles on the existing boosts shelf. |
| `lib/ui/screens/match/match_screen.dart` | Boost strip, window timer, VAR/Physio application, feed notes, per-player locks. |
| `lib/ui/screens/match/subs_panel.dart` | Host the bench boost row. |
| `lib/ui/screens/squad/player_detail_sheet.dart` | Host the second trait slot. |
| `lib/i18n/en_copy.dart`, `lib/i18n/copy/*_copy.dart` | All new copy, ten locales. |

---

## Task 1: The match trait pool

**Files:**
- Create: `lib/data/match_traits.dart`
- Test: `test/data/match_traits_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class MatchTraitLevel { final int level; final String label; final double mult; }`,
  `class MatchTrait { final String id, name, icon, desc; final MatchTraitCondition condition; final List<MatchTraitLevel> levels; }`,
  `enum MatchTraitCondition { home, away, strongerOpponent, firstTwenty, relegationZone, lastFifteen, cupTie, superSub, derby, tenMen, booked, injuryShrug }`,
  `const Map<String, MatchTrait> matchTraits`, `final List<MatchTrait> matchTraitList`,
  `MatchTrait? getMatchTrait(String? id)`,
  `MatchTraitLevel? getMatchTraitLevel(MatchTrait?, int)`,
  `const double matchTraitSquadCap = 0.12`.

For the three that do not take a plain rating multiplier — `tenMen`, `booked`,
`injuryShrug` — `MatchTraitLevel.mult` carries the axis value instead: the
per-head multiplier for Ten Man Wall, the *replacement* for the yellow-card
multiplier for Ice Veins, and the shrug probability for Warrior. The condition
enum is what tells a reader which.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/match_traits_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/match_traits.dart';

void main() {
  group('the match trait pool', () {
    test('IS TWELVE, AND EVERY ONE IS CONDITIONAL', () {
      expect(matchTraitList.length, 12);
      // The whole balance argument: a trait that fires in every match would
      // move the baseline squad star the division bands are tuned against.
      for (final t in matchTraitList) {
        expect(t.condition, isNotNull, reason: '${t.id} has no condition');
      }
    });

    test('every trait has three levels, labelled I / II / III', () {
      for (final t in matchTraitList) {
        expect(t.levels.map((l) => l.level), [1, 2, 3], reason: t.id);
        expect(t.levels.map((l) => l.label), ['I', 'II', 'III'], reason: t.id);
      }
    });

    test('ids are unique and match their map key', () {
      for (final e in matchTraits.entries) {
        expect(e.value.id, e.key);
      }
    });

    // **THE LADDER IS THE BALANCE, so it is asserted rather than commented.**
    // A rarer condition must be worth more at every level, or the common
    // traits are strictly better and the rare ones are dead rolls.
    test('A RARER CONDITION CARRIES A BIGGER NUMBER AT EVERY LEVEL', () {
      const ordered = ['fortress', 'away_day', 'big_game', 'fast_starter',
                       'relegation_scrapper', 'last_gasp', 'cup_fighter'];
      for (var i = 1; i < ordered.length; i++) {
        final prev = matchTraits[ordered[i - 1]]!;
        final cur = matchTraits[ordered[i]]!;
        for (var l = 0; l < 3; l++) {
          expect(
            cur.levels[l].mult,
            greaterThanOrEqualTo(prev.levels[l].mult),
            reason: '${cur.id} L${l + 1} must not be under ${prev.id}',
          );
        }
      }
    });

    test('a level III is always worth more than its own level I', () {
      for (final t in matchTraitList) {
        if (t.condition == MatchTraitCondition.booked) continue; // see below
        expect(t.levels[2].mult, greaterThan(t.levels[0].mult), reason: t.id);
      }
    });

    // Ice Veins REPLACES the 0.9 rather than adding to it, so its ladder runs
    // up toward 1.0 and its level III is a man who plays exactly as he did.
    test('Ice Veins climbs to exactly 1.0', () {
      final ice = matchTraits['ice_veins']!;
      expect(ice.levels.map((l) => l.mult), [0.94, 0.97, 1.00]);
    });

    test('Ten Man Wall is squad-wide, so it is capped', () {
      expect(matchTraitSquadCap, 0.12);
      expect(matchTraits['ten_man_wall']!.levels[2].mult, lessThan(matchTraitSquadCap));
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/data/match_traits_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:merge_empire_fc/data/match_traits.dart'`.

- [ ] **Step 3: Write the pool**

```dart
/// The MATCH trait pool — the second, gem-gated slot.
///
/// **EVERY TRAIT HERE IS CONDITIONAL, and that is not a theme.** `gem_engine`
/// states the catalogue's law: "NEVER RAW RATING. The division bands are tuned
/// against a no-trait maxed squad with a shrinking edge per division; anything
/// that adds ★ punches straight through the curve." A slot bought with a gem
/// that handed out flat stat would break it outright. A trait that is dark in
/// most matches does not move the baseline the bands are tuned against — so
/// the condition IS the licence, and a later trait that fires always would
/// invalidate the whole argument.
///
/// **Rarer condition, bigger number**, asserted in `match_traits_test.dart`
/// rather than left as a comment. That ladder is what stops the common traits
/// dominating the rare ones.
///
/// Values are multipliers on the player's contribution to the squad rating —
/// the same channel and the same units as `yellowCardRatingMult = 0.9`, which
/// the couch reported as clearly noticeable at ten per cent.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// What has to be true for a trait to pay.
enum MatchTraitCondition {
  home,
  away,
  strongerOpponent,
  firstTwenty,
  relegationZone,
  lastFifteen,
  cupTie,
  superSub,
  derby,

  /// Squad-wide while we are down to ten. Capped by [matchTraitSquadCap].
  tenMen,

  /// Replaces the yellow-card rating multiplier rather than adding to it.
  booked,

  /// A probability, not a multiplier: the chance of shrugging off an injury.
  injuryShrug,
}

class MatchTraitLevel {
  const MatchTraitLevel({
    required this.level,
    required this.label,
    required this.mult,
  });

  final int level;
  final String label;

  /// A rating multiplier for most conditions. For `booked` it is the
  /// REPLACEMENT yellow-card multiplier, and for `injuryShrug` a probability.
  /// The condition says which.
  final double mult;
}

class MatchTrait {
  const MatchTrait({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.condition,
    required this.levels,
  });

  final String id;
  final String name;
  final String icon;
  final String desc;
  final MatchTraitCondition condition;
  final List<MatchTraitLevel> levels;
}

MatchTraitLevel _l(int level, String label, double mult) =>
    MatchTraitLevel(level: level, label: label, mult: mult);

/// The most Ten Man Wall may add across the whole side, however many carry it.
/// The same shape as `maxSquadInjuryReduction` in `trait_engine.dart`, and for
/// the same reason: a grid stuffed with one trait must not trivialise a state.
const double matchTraitSquadCap = 0.12;

const Map<String, MatchTrait> matchTraits = {
  'fortress': MatchTrait(
    id: 'fortress', name: 'Fortress', icon: '🏰',
    desc: 'Immovable at home — but only at home',
    condition: MatchTraitCondition.home,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.04),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.07),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.11),
    ],
  ),
  'away_day': MatchTrait(
    id: 'away_day', name: 'Away Day Hero', icon: '✈️',
    desc: 'Loves a hostile ground — thrives on the road',
    condition: MatchTraitCondition.away,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.04),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.07),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.11),
    ],
  ),
  'big_game': MatchTrait(
    id: 'big_game', name: 'Big Game Player', icon: '🎩',
    desc: 'Turns up against the better side',
    condition: MatchTraitCondition.strongerOpponent,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.05),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.09),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.14),
    ],
  ),
  'fast_starter': MatchTrait(
    id: 'fast_starter', name: 'Fast Starter', icon: '🚀',
    desc: 'Out of the blocks — huge for the opening twenty',
    condition: MatchTraitCondition.firstTwenty,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.07),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.13),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.20),
    ],
  ),
  'relegation_scrapper': MatchTrait(
    id: 'relegation_scrapper', name: 'Relegation Scrapper', icon: '🛟',
    desc: 'Fights hardest when the drop is real',
    condition: MatchTraitCondition.relegationZone,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.07),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.13),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.20),
    ],
  ),
  'last_gasp': MatchTrait(
    id: 'last_gasp', name: 'Last Gasp', icon: '⏱',
    desc: 'Finds something in the closing minutes',
    condition: MatchTraitCondition.lastFifteen,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.08),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.15),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.23),
    ],
  ),
  'cup_fighter': MatchTrait(
    id: 'cup_fighter', name: 'Cup Fighter', icon: '🏆',
    desc: 'Made for the cup — nothing else brings it out of him',
    condition: MatchTraitCondition.cupTie,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.08),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.15),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.23),
    ],
  ),
  'super_sub': MatchTrait(
    id: 'super_sub', name: 'Super Sub', icon: '🔄',
    desc: 'Devastating off the bench in the closing twenty',
    condition: MatchTraitCondition.superSub,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.12),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.20),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.30),
    ],
  ),
  'derby_devil': MatchTrait(
    id: 'derby_devil', name: 'Derby Devil', icon: '😈',
    desc: 'Lives for the grudge match',
    condition: MatchTraitCondition.derby,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.10),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.18),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.28),
    ],
  ),

  // ── The three that own an axis outright ──────────────────────────────────
  'ten_man_wall': MatchTrait(
    id: 'ten_man_wall', name: 'Ten Man Wall', icon: '🧱',
    desc: 'Rallies the ten — lifts EVERY man left on the pitch',
    condition: MatchTraitCondition.tenMen,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 1.03),
      MatchTraitLevel(level: 2, label: 'II', mult: 1.05),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.08),
    ],
  ),
  'ice_veins': MatchTrait(
    id: 'ice_veins', name: 'Ice Veins', icon: '🧊',
    desc: 'Plays the same booked — the coolest head in the game',
    condition: MatchTraitCondition.booked,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 0.94),
      MatchTraitLevel(level: 2, label: 'II', mult: 0.97),
      MatchTraitLevel(level: 3, label: 'III', mult: 1.00),
    ],
  ),
  'warrior': MatchTrait(
    id: 'warrior', name: 'Warrior', icon: '🦿',
    desc: 'Plays through it — may shrug off a knock and carry on',
    condition: MatchTraitCondition.injuryShrug,
    levels: [
      MatchTraitLevel(level: 1, label: 'I', mult: 0.25),
      MatchTraitLevel(level: 2, label: 'II', mult: 0.45),
      MatchTraitLevel(level: 3, label: 'III', mult: 0.70),
    ],
  ),
};

final List<MatchTrait> matchTraitList = List.unmodifiable(matchTraits.values);

MatchTrait? getMatchTrait(String? id) => id == null ? null : matchTraits[id];

MatchTraitLevel? getMatchTraitLevel(MatchTrait? trait, int level) {
  if (trait == null) return null;
  for (final l in trait.levels) {
    if (l.level == level) return l;
  }
  return null;
}
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/data/match_traits_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze
git add lib/data/match_traits.dart test/data/match_traits_test.dart
git commit -m "Add the conditional match trait pool

Every trait is condition-gated so the gem-bought slot never moves the
baseline squad star the division bands are tuned against."
```

---

## Task 2: The match trait engine

**Files:**
- Create: `lib/engine/match_trait_engine.dart`
- Test: `test/engine/match_trait_engine_test.dart`

**Interfaces:**
- Consumes: `matchTraits`, `getMatchTrait`, `getMatchTraitLevel`, `matchTraitSquadCap`, `MatchTraitCondition` (Task 1); `CardInstance` from `lib/state/card_instance.dart`; `getGems`/`spendGems` from `lib/engine/gem_engine.dart`; `traitRollCost` from `lib/engine/trait_engine.dart`.
- Produces:
  - `typedef MatchContext = ({bool isHome, bool isCup, bool isDerby, bool inRelegationZone, bool oppStronger, bool tenMen, int minute, int fullTime, Set<String> subbedOnLate, Set<String> cautioned});`
  - `bool hasMatchSlot(CardInstance?)`, `Map<String, dynamic>? matchTraitOf(CardInstance?)`
  - `int matchSlotGemCost = 1`
  - `({bool ok, String? reason}) unlockMatchSlot(Map<String,dynamic> state, String? instanceId)`
  - `MatchTraitRoll rollMatchTrait()` where `typedef MatchTraitRoll = ({String id, int level});`
  - `({bool ok, String? reason, MatchTraitRoll? roll, bool replaced, num cost}) rollMatchTraitForCard(Map<String,dynamic> state, String? instanceId)`
  - `Map<String, double> matchTraitMultipliers(List<CardInstance?> cells, List<Map<String,dynamic>>? lineup, MatchContext ctx)`
  - `double warriorShrugChance(CardInstance?)`
  - `void setMatchTraitRandom(math.Random)`, `void resetMatchTraitRandom()`

`matchTraitMultipliers` returns multipliers **only for players it changes**, so
merging it over the booking map is a plain `addAll` on a copy — except for
`ice_veins`, which must be composed against the booking entry rather than
replace it blindly.

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/match_trait_engine_test.dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

MatchContext _ctx({
  bool isHome = false,
  bool isCup = false,
  bool isDerby = false,
  bool inRelegationZone = false,
  bool oppStronger = false,
  bool tenMen = false,
  int minute = 40,
  Set<String> subbedOnLate = const {},
  Set<String> cautioned = const {},
}) => (
  isHome: isHome, isCup: isCup, isDerby: isDerby,
  inRelegationZone: inRelegationZone, oppStronger: oppStronger,
  tenMen: tenMen, minute: minute, fullTime: 90,
  subbedOnLate: subbedOnLate, cautioned: cautioned,
);

Map<String, dynamic> _card(String id, {String? trait, int level = 3}) => {
  'instanceId': id,
  'definitionId': 'p1',
  if (trait != null) 'matchSlot': true,
  if (trait != null) 'matchTrait': {'id': trait, 'level': level},
};

List<CardInstance?> _cells(List<Map<String, dynamic>> raw) =>
    [for (final r in raw) CardInstance.from(r)];

List<Map<String, dynamic>> _lineup(List<String> ids) =>
    [for (final id in ids) {'cardInstanceId': id, 'slotPosition': 'MID'}];

void main() {
  group('matchTraitMultipliers', () {
    test('A DARK CONDITION PAYS NOTHING', () {
      final cells = _cells([_card('a', trait: 'fortress')]);
      final out = matchTraitMultipliers(cells, _lineup(['a']), _ctx(isHome: false));
      expect(out, isEmpty);
    });

    test('a lit condition pays its level', () {
      final cells = _cells([_card('a', trait: 'fortress')]);
      final out = matchTraitMultipliers(cells, _lineup(['a']), _ctx(isHome: true));
      expect(out['a'], closeTo(1.11, 1e-9));
    });

    test('a locked slot pays nothing even with a trait in the map', () {
      final raw = _card('a', trait: 'fortress')..remove('matchSlot');
      final out = matchTraitMultipliers(_cells([raw]), _lineup(['a']), _ctx(isHome: true));
      expect(out, isEmpty);
    });

    // **ONLY THE ELEVEN.** A Cup Fighter sat on the bench does not fight.
    test('a man not in the lineup pays nothing', () {
      final cells = _cells([_card('a', trait: 'cup_fighter'), _card('b', trait: 'cup_fighter')]);
      final out = matchTraitMultipliers(cells, _lineup(['a']), _ctx(isCup: true));
      expect(out.keys, ['a']);
    });

    test('Super Sub pays only the men who came on late', () {
      final cells = _cells([_card('a', trait: 'super_sub'), _card('b', trait: 'super_sub')]);
      final out = matchTraitMultipliers(
        cells, _lineup(['a', 'b']), _ctx(subbedOnLate: {'b'}),
      );
      expect(out.keys, ['b']);
      expect(out['b'], closeTo(1.30, 1e-9));
    });

    test('Fast Starter is lit before minute 20 and dark after', () {
      final cells = _cells([_card('a', trait: 'fast_starter')]);
      expect(matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 5))['a'],
          closeTo(1.20, 1e-9));
      expect(matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 25)), isEmpty);
    });

    test('Last Gasp is lit from 76 to the whistle', () {
      final cells = _cells([_card('a', trait: 'last_gasp')]);
      expect(matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 75)), isEmpty);
      expect(matchTraitMultipliers(cells, _lineup(['a']), _ctx(minute: 76))['a'],
          closeTo(1.23, 1e-9));
    });

    // **SQUAD-WIDE, AND CAPPED.** Two carriers must not be twice as good.
    test('TEN MAN WALL LIFTS EVERY MAN AND IS CAPPED', () {
      final cells = _cells([
        _card('a', trait: 'ten_man_wall'),
        _card('b', trait: 'ten_man_wall'),
        _card('c'),
      ]);
      final out = matchTraitMultipliers(
        cells, _lineup(['a', 'b', 'c']), _ctx(tenMen: true),
      );
      expect(out.keys.toSet(), {'a', 'b', 'c'});
      // 0.08 + 0.08 = 0.16, over the 0.12 cap.
      expect(out['c'], closeTo(1.12, 1e-9));
    });

    test('Ten Man Wall pays nothing at eleven men', () {
      final cells = _cells([_card('a', trait: 'ten_man_wall')]);
      expect(matchTraitMultipliers(cells, _lineup(['a']), _ctx(tenMen: false)), isEmpty);
    });

    // Ice Veins REPLACES the caution penalty, so it only exists for a booked
    // man and its value is the multiplier the booking map should end up with.
    test('ICE VEINS REPLACES THE CAUTION PENALTY, NOT THE RATING', () {
      final cells = _cells([_card('a', trait: 'ice_veins')]);
      expect(matchTraitMultipliers(cells, _lineup(['a']), _ctx()), isEmpty);
      final booked = matchTraitMultipliers(
        cells, _lineup(['a']), _ctx(cautioned: {'a'}),
      );
      expect(booked['a'], closeTo(1.00, 1e-9));
    });
  });

  group('warriorShrugChance', () {
    test('is zero without the trait and its level with it', () {
      expect(warriorShrugChance(CardInstance.from(_card('a'))), 0);
      expect(
        warriorShrugChance(CardInstance.from(_card('a', trait: 'warrior', level: 2))),
        closeTo(0.45, 1e-9),
      );
    });
  });

  group('unlockMatchSlot', () {
    Map<String, dynamic> stateWith(int gems) => {
      'resources': {'gems': gems, 'fanCoins': 999999},
      'grid': {'cells': [_card('a')]},
    };

    test('debits exactly one gem and opens the slot', () {
      final s = stateWith(3);
      expect(unlockMatchSlot(s, 'a').ok, isTrue);
      expect((s['resources'] as Map)['gems'], 2);
      expect((((s['grid'] as Map)['cells'] as List).first as Map)['matchSlot'], isTrue);
    });

    test('refuses without the gem, and takes nothing', () {
      final s = stateWith(0);
      expect(unlockMatchSlot(s, 'a').reason, 'insufficient_gems');
      expect((((s['grid'] as Map)['cells'] as List).first as Map)['matchSlot'], isNull);
    });

    test('refuses a second unlock rather than charging twice', () {
      final s = stateWith(3);
      unlockMatchSlot(s, 'a');
      expect(unlockMatchSlot(s, 'a').reason, 'already_unlocked');
      expect((s['resources'] as Map)['gems'], 2);
    });

    test('refuses an unknown card', () {
      expect(unlockMatchSlot(stateWith(3), 'nope').reason, 'unknown_card');
    });
  });

  group('rollMatchTraitForCard', () {
    test('REFUSES A LOCKED SLOT AND CHARGES NOTHING', () {
      final s = {
        'resources': {'gems': 9, 'fanCoins': 999999},
        'grid': {'cells': [_card('a')]},
      };
      final r = rollMatchTraitForCard(s, 'a');
      expect(r.reason, 'locked');
      expect((s['resources'] as Map)['fanCoins'], 999999);
    });

    test('rolls into an unlocked slot and debits coins', () {
      setMatchTraitRandom(math.Random(1));
      addTearDown(resetMatchTraitRandom);
      final s = {
        'resources': {'gems': 9, 'fanCoins': 999999},
        'grid': {'cells': [{'instanceId': 'a', 'definitionId': 'p1', 'matchSlot': true}]},
      };
      final r = rollMatchTraitForCard(s, 'a');
      expect(r.ok, isTrue);
      expect(matchTraits.containsKey(r.roll!.id), isTrue);
      expect((s['resources'] as Map)['fanCoins'], lessThan(999999));
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/engine/match_trait_engine_test.dart`
Expected: FAIL — the engine file does not exist.

- [ ] **Step 3: Write the engine**

Key points for the implementer:

- Import `package:merge_empire_fc/data/match_traits.dart`, `players.dart`,
  `card_instance.dart`, `gem_engine.dart`, `trait_engine.dart` (for
  `traitRollCost`) and `util/event_bus.dart`. **No Flutter import.**
- `rollMatchTrait` uses its own `math.Random`, unseeded, for the same reason
  `trait_engine.dart` does — drawing from the shared seeded stream would shift
  every later gameplay draw. Reuse the level weights `[70, 26.2, 3.8]`.
- The pool for a roll is **every** match trait; unlike the first slot there is
  no position gating, because a match trait is about the situation rather than
  the position.
- `matchTraitMultipliers` walks the lineup, skips anyone without
  `matchSlot == true`, resolves the trait and level, and writes an entry only
  when the condition is lit. Ten Man Wall sums each carrier's `mult - 1` across
  the fielded eleven, clamps the total at `matchTraitSquadCap`, and writes
  `1 + total` for **every** man in the lineup.
- Emit `match_trait:unlocked` and `match_trait:rolled` on the bus. Grep
  `lib/util/event_bus.dart` first — these are new names, so add them to the
  documented list there.

```dart
/// Turn the fielded eleven and the state of the match into rating multipliers.
///
/// **THE ONE DOOR INTO THE SIM.** `computeSquadRatings` already takes a
/// `ratingMultipliers` map by instance id, applied as a scalar on
/// `effectiveRating` — `booking_engine` is its only caller today. A match
/// trait is another contributor to that same map, which is why the rating
/// engine does not change for this feature at all.
///
/// Only players it CHANGES appear in the result, so merging over the booking
/// map is an `addAll` on a copy — except `ice_veins`, whose value is the
/// booking multiplier it replaces.
Map<String, double> matchTraitMultipliers(
  List<CardInstance?> cells,
  List<Map<String, dynamic>>? lineup,
  MatchContext ctx,
) {
  final out = <String, double>{};
  final fielded = _fielded(cells, lineup);
  if (fielded.isEmpty) return out;

  // Ten Man Wall is squad-wide, so it is summed over the carriers and capped
  // before anything is written — the same shape as `maxSquadInjuryReduction`.
  var wall = 0.0;

  for (final card in fielded) {
    final ref = matchTraitOf(card);
    if (ref == null) continue;
    final trait = getMatchTrait(ref['id'] as String?);
    final level = getMatchTraitLevel(trait, (ref['level'] as num?)?.toInt() ?? 0);
    if (trait == null || level == null) continue;

    switch (trait.condition) {
      case MatchTraitCondition.home:
        if (ctx.isHome) out[card.instanceId] = level.mult;
      case MatchTraitCondition.away:
        if (!ctx.isHome) out[card.instanceId] = level.mult;
      case MatchTraitCondition.cupTie:
        if (ctx.isCup) out[card.instanceId] = level.mult;
      case MatchTraitCondition.derby:
        if (ctx.isDerby) out[card.instanceId] = level.mult;
      case MatchTraitCondition.relegationZone:
        if (ctx.inRelegationZone) out[card.instanceId] = level.mult;
      case MatchTraitCondition.strongerOpponent:
        if (ctx.oppStronger) out[card.instanceId] = level.mult;
      case MatchTraitCondition.firstTwenty:
        if (ctx.minute <= 20) out[card.instanceId] = level.mult;
      case MatchTraitCondition.lastFifteen:
        if (ctx.minute >= 76) out[card.instanceId] = level.mult;
      case MatchTraitCondition.superSub:
        if (ctx.subbedOnLate.contains(card.instanceId)) {
          out[card.instanceId] = level.mult;
        }
      case MatchTraitCondition.booked:
        // Only means anything to a man the referee has actually cautioned.
        if (ctx.cautioned.contains(card.instanceId)) {
          out[card.instanceId] = level.mult;
        }
      case MatchTraitCondition.tenMen:
        if (ctx.tenMen) wall += level.mult - 1;
      case MatchTraitCondition.injuryShrug:
        break; // not a rating — see [warriorShrugChance]
    }
  }

  if (wall > 0) {
    final lift = 1 + math.min(matchTraitSquadCap, wall);
    for (final card in fielded) {
      // Multiplies rather than overwrites: a Fortress who is also one of the
      // ten keeps both.
      out[card.instanceId] = (out[card.instanceId] ?? 1) * lift;
    }
  }

  return out;
}
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/engine/match_trait_engine_test.dart`
Expected: PASS.

- [ ] **Step 5: Check the architecture boundary still holds**

Run: `flutter test test/architecture_test.dart`
Expected: PASS — `lib/engine` must not import Flutter.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/engine/match_trait_engine.dart test/engine/match_trait_engine_test.dart lib/util/event_bus.dart
git commit -m "Add the match trait engine

Slot unlock, rolling, and a multiplier map that merges into the one
computeSquadRatings already takes, so the rating engine is untouched."
```

---

## Task 3: Feed the multipliers into the match screen

**Files:**
- Modify: `lib/ui/screens/match/match_screen.dart` — `_resimulate` and the `_MatchScreenState` fields
- Test: `test/ui/match/match_trait_wiring_test.dart` (create)

**Interfaces:**
- Consumes: `matchTraitMultipliers`, `MatchContext` (Task 2).
- Produces: a private `Map<String, double> _liveMultipliers()` on `_MatchScreenState`, and `Set<String> _subbedOnLate` tracked from `_onSub`.

- [ ] **Step 1: Read the two call sites before changing anything**

Run: `grep -n "bookedRatingMultipliers\|_resimulate(" lib/ui/screens/match/match_screen.dart`

Every `_resimulate` call currently passes the booking map. All of them must go
through the new composed map instead, or a trait will fire on some
re-simulations and not others.

- [ ] **Step 2: Write the failing test**

```dart
// test/ui/match/match_trait_wiring_test.dart
//
// **THIS IS THE REACHABILITY TEST, not a maths test.** The arithmetic is
// pinned in match_trait_engine_test; what this proves is that a trait on a
// card in the save actually reaches the sim when the screen re-simulates.
// A widget test constructing the state is exactly the gap `tool/unreached.sh`
// exists to find, so it plays a real match and reads the result back.
```

Model it on the existing match widget tests — `ls test/ui/match/` and copy the
harness from the closest one. The assertion: play a fixture at home with a
`fortress` III on a lineup card, force a tactic switch to trigger a re-sim, and
assert `liveAttackRating` is above the same fixture played with the trait
absent.

**Answer the post-match card.** `_afterMatch` rolls for a transfer bid and then
a sponsor on `Math.random`, so both are there on some runs and not others, and
`_playFixture` does not return until one is answered. A Coach Colin card has no
barrier, so `tapAt(Offset(5, 5))` walks past it — dismiss with the card's own
`coach-action-common.decline`. Do **not** wrap the dismissal in
`if (…isNotEmpty)`: that turns a missed control into a failure forty lines
later in an assertion about something else.

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/ui/match/match_trait_wiring_test.dart`
Expected: FAIL — the ratings are equal, because nothing merges the map yet.

- [ ] **Step 4: Compose the map**

```dart
  /// Everyone brought on inside the last twenty — Super Sub's condition.
  /// Screen-owned, like [_withdrawn]: the panel forgets and this must not.
  final Set<String> _subbedOnLate = <String>{};

  /// **THE BOOKING MAP AND THE TRAIT MAP, COMPOSED ONCE.**
  ///
  /// Every re-simulation has to see both or a trait fires on a tactic switch
  /// and not on a substitution. Ice Veins is the reason this is a compose
  /// rather than an `addAll`: its value REPLACES the caution multiplier, so it
  /// is written after the bookings and deliberately wins.
  Map<String, double> _liveMultipliers() {
    final out = Map<String, double>.from(
      bookedRatingMultipliers(_cautioned),
    );
    final traits = matchTraitMultipliers(
      ref.read(gridCellsProvider),
      _lineupNow(),
      _matchContext(),
    );
    for (final e in traits.entries) {
      final trait = getMatchTrait(
        (matchTraitOf(cardById(ref.read(gameProvider).state, e.key))
            ?['id']) as String?,
      );
      out[e.key] = trait?.condition == MatchTraitCondition.booked
          ? e.value
          : (out[e.key] ?? 1) * e.value;
    }
    return out;
  }
```

Then replace every `bookedRatingMultipliers(_cautioned)` argument at the
`_resimulate` call sites with `_liveMultipliers()`, and add to `_onSub`:

```dart
    // Super Sub's window. `_end` is the full-time minute including stoppage.
    if (sub.onId != null && _minute >= _end - 20) _subbedOnLate.add(sub.onId!);
```

- [ ] **Step 5: Run the test and watch it pass**

Run: `flutter test test/ui/match/match_trait_wiring_test.dart`
Expected: PASS.

- [ ] **Step 6: Confirm parity is untouched**

Run: `flutter test test/engine/match_orchestration_parity_test.dart`
Expected: PASS — nothing was stamped on `result`.

- [ ] **Step 7: Analyze and commit**

```bash
flutter analyze
git add lib/ui/screens/match/match_screen.dart test/ui/match/match_trait_wiring_test.dart
git commit -m "Carry match traits into every re-simulation

Composed with the booking map at one place so a trait cannot fire on a
tactic switch and not on a substitution."
```

---

## Task 4: The timed re-simulation

**Files:**
- Modify: `lib/ui/screens/match/match_screen.dart`
- Test: `test/ui/match/timed_resim_test.dart` (create)

**Interfaces:**
- Consumes: `_resimulate` (existing).
- Produces: `void _scheduleResimAt(int minute, String reason)` on `_MatchScreenState`, and a `List<({int minute, String reason})> _pendingResims` drained by the per-minute tick.

This is the shared plumbing. Fast Starter and Last Gasp need a re-sim at
minutes 21 and 76; the boost windows need one at their end minute. One
mechanism serves all of them.

- [ ] **Step 1: Write the failing test**

Assert that a match containing a `fast_starter` III re-simulates exactly once
at minute 21 without any manager input, and that `liveAttackRating` drops when
it does.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/match/timed_resim_test.dart`
Expected: FAIL — no re-simulation happens.

- [ ] **Step 3: Implement**

```dart
  /// Minutes at which the remainder must be re-decided with no manager input.
  ///
  /// **Boost windows and minute-gated traits are the same problem.** A Crowd
  /// Roar that ends at 65 and a Fast Starter that stops paying at 21 both need
  /// the remainder re-rolled at a minute nobody taps, so they share one queue
  /// rather than growing two timers that can disagree about ordering.
  ///
  /// Drained in the per-minute tick rather than on a `Timer`, so it obeys the
  /// speed toggle, the auto-slow and a paused match for free — a wall-clock
  /// timer would fire during a bottom sheet.
  final List<({int minute, String reason})> _pendingResims = [];

  void _scheduleResimAt(int minute, String reason) {
    if (minute >= _end || minute <= _minute) return;
    _pendingResims.add((minute: minute, reason: reason));
    _pendingResims.sort((a, b) => a.minute.compareTo(b.minute));
  }

  void _drainResims(int minute) {
    while (_pendingResims.isNotEmpty && _pendingResims.first.minute <= minute) {
      _pendingResims.removeAt(0);
      // Never re-rolls injuries: a window closing is not a change of approach,
      // the same reasoning a substitution passes `rerollInjuries: false`.
      _resimulate(minute, _strategy, rerollInjuries: false);
    }
  }
```

Call `_drainResims(_minute)` from the per-minute tick, **before** the events of
that minute are dispatched, and seed the two trait minutes at kickoff:

```dart
    // The minute-gated traits, queued once at kickoff. Cheap when nobody in
    // the eleven carries one: `_resimulate` is what costs, and an empty queue
    // never reaches it.
    if (_hasTraitWithCondition(MatchTraitCondition.firstTwenty)) {
      _scheduleResimAt(21, 'fast_starter');
    }
    if (_hasTraitWithCondition(MatchTraitCondition.lastFifteen)) {
      _scheduleResimAt(76, 'last_gasp');
    }
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/ui/match/timed_resim_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the scoreline invariants**

Run: `flutter test test/ui/match/ --name "WHAT WAS WATCHED"`
Run: `flutter test test/ui/match/ --name "ABANDONED"`
Expected: PASS. A new re-simulation source must refresh the fixture row the
same way every other one does — `_resimulate` already calls
`recordFixtureResult`, so this should hold, but these two groups are the reason
to check rather than assume.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/ui/screens/match/match_screen.dart test/ui/match/timed_resim_test.dart
git commit -m "Re-decide the remainder at a scheduled minute

One queue for boost windows and minute-gated traits. Drained on the match
tick so it obeys the speed toggle and a paused match."
```

---

## Task 5: The boost catalogue and inventory

**Files:**
- Create: `lib/data/boosts.dart`, `lib/engine/boost_engine.dart`
- Test: `test/data/boosts_test.dart`, `test/engine/boost_engine_test.dart`

**Interfaces:**
- Produces:
  - `enum BoostKind { proactive, retrospective }`
  - `class Boost { final String id, icon; final BoostKind kind; final int gemCost, packSize; final int windowMinutes; }`
  - `const Map<String, Boost> boosts`, `final List<Boost> boostList`, `Boost? getBoost(String?)`
  - `int boostCount(Map<String,dynamic>? state, String id)`
  - `void grantBoost(Map<String,dynamic> state, String id, int n)`
  - `bool spendBoost(Map<String,dynamic> state, String id)`
  - `({bool ok, String? reason}) buyBoostPack(Map<String,dynamic> state, String id)`

Inventory lives at `state['matchBoosts']` as `{id: count}`. **Deliberately not
`state['boosts']`,** which is already taken by the season flags — kit sponsor,
TV deal, trophy polish.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/boosts_test.dart
void main() {
  test('four boosts, two of each kind', () {
    expect(boostList.length, 4);
    expect(boostList.where((b) => b.kind == BoostKind.proactive).length, 2);
    expect(boostList.where((b) => b.kind == BoostKind.retrospective).length, 2);
  });

  test('a pack is three for two gems', () {
    for (final b in boostList) {
      expect(b.packSize, 3);
      expect(b.gemCost, 2);
    }
  });

  // A retrospective boost is taken at the bench in front of the consequence;
  // it has no window because the match is paused while it is offered.
  test('only the proactive pair carry a window', () {
    for (final b in boostList) {
      expect(b.windowMinutes > 0, b.kind == BoostKind.proactive, reason: b.id);
    }
  });

  test('the window is twenty-five in-game minutes', () {
    expect(boosts['crowd_roar']!.windowMinutes, 25);
    expect(boosts['park_the_bus']!.windowMinutes, 25);
  });
}
```

```dart
// test/engine/boost_engine_test.dart — the shape that matters
void main() {
  test('DOES NOT USE THE SEASON BOOST KEY', () {
    final s = <String, dynamic>{'boosts': {'trophyPolishUntil': 123}};
    grantBoost(s, 'crowd_roar', 1);
    // The season flags are untouched; the inventory is its own branch.
    expect((s['boosts'] as Map)['trophyPolishUntil'], 123);
    expect(s['matchBoosts'], {'crowd_roar': 1});
  });

  test('spending decrements, and refuses at zero without going negative', () {
    final s = <String, dynamic>{};
    grantBoost(s, 'crowd_roar', 1);
    expect(spendBoost(s, 'crowd_roar'), isTrue);
    expect(spendBoost(s, 'crowd_roar'), isFalse);
    expect(boostCount(s, 'crowd_roar'), 0);
  });

  test('a pack costs its gems and delivers its three', () {
    final s = <String, dynamic>{'resources': {'gems': 5}};
    expect(buyBoostPack(s, 'crowd_roar').ok, isTrue);
    expect((s['resources'] as Map)['gems'], 3);
    expect(boostCount(s, 'crowd_roar'), 3);
  });

  test('REFUSES WITHOUT THE GEMS AND DELIVERS NOTHING', () {
    final s = <String, dynamic>{'resources': {'gems': 1}};
    expect(buyBoostPack(s, 'crowd_roar').reason, 'insufficient_gems');
    expect(boostCount(s, 'crowd_roar'), 0);
  });
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/data/boosts_test.dart test/engine/boost_engine_test.dart`
Expected: FAIL — neither file exists.

- [ ] **Step 3: Implement both**

`buyBoostPack` goes through `spendGems(state, cost, 'boost:$id')` from
`gem_engine.dart` so the gem ledger records it like every other spend. Emit
`boosts:changed` after a grant or a spend — grep `lib/util/event_bus.dart`
first and document the new name there.

- [ ] **Step 4: Run and watch them pass**

Run: `flutter test test/data/boosts_test.dart test/engine/boost_engine_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze
git add lib/data/boosts.dart lib/engine/boost_engine.dart test/data/boosts_test.dart test/engine/boost_engine_test.dart lib/util/event_bus.dart
git commit -m "Add the boost catalogue and inventory

Inventory sits at state['matchBoosts']; state['boosts'] is already the
season flags."
```

---

## Task 6: Park the Bus — goal-rate damping in the sim

**Files:**
- Modify: `lib/engine/match_orchestration.dart` — `reSimulateRemainder`
- Test: `test/engine/match_orchestration_test.dart` (add a group)

**Interfaces:**
- Produces: a new named parameter `double goalRateMult = 1.0` on
  `reSimulateRemainder`, applied to both sides' Poisson rates.

- [ ] **Step 1: Write the failing test**

```dart
  group('goalRateMult', () {
    test('DAMPS BOTH SIDES, NOT JUST THEIRS', () {
      // Park the Bus kills the game for everyone — that is what makes it
      // distinct from the ultra-defensive tactic already on the strip, which
      // only makes us harder to score against.
      var ourTotal = 0, theirTotal = 0, dampOurs = 0, dampTheirs = 0;
      for (var seed = 0; seed < 400; seed++) {
        final a = _freshResult(seed);
        reSimulateRemainder(a, 20, 'balanced', 0, 0, _state());
        ourTotal += a['homeGoals'] as int;
        theirTotal += a['awayGoals'] as int;

        final b = _freshResult(seed);
        reSimulateRemainder(b, 20, 'balanced', 0, 0, _state(), goalRateMult: 0.45);
        dampOurs += b['homeGoals'] as int;
        dampTheirs += b['awayGoals'] as int;
      }
      expect(dampOurs, lessThan(ourTotal));
      expect(dampTheirs, lessThan(theirTotal));
    });

    test('defaults to 1.0, so nothing changes for every existing caller', () {
      final a = _freshResult(7);
      final b = _freshResult(7);
      reSimulateRemainder(a, 20, 'balanced', 0, 0, _state());
      reSimulateRemainder(b, 20, 'balanced', 0, 0, _state(), goalRateMult: 1.0);
      expect(a['homeGoals'], b['homeGoals']);
      expect(a['awayGoals'], b['awayGoals']);
    });
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/engine/match_orchestration_test.dart --name goalRateMult`
Expected: FAIL — no such named parameter.

- [ ] **Step 3: Implement**

Find the two `poissonGoals` lines in `reSimulateRemainder` and multiply the
rate:

```dart
  final remainHome = poissonGoals(
    goalRateLambda(adjAttack, oppDefence) * fraction * variance * goalRateMult,
  );
  final remainAway = poissonGoals(
    goalRateLambda(oppAttack, adjDefence) * fraction * variance * goalRateMult,
  );
```

with the parameter documented in the same voice as its neighbours:

```dart
  /// **KILLS THE GAME FOR BOTH SIDES**, which is what makes Park the Bus a
  /// different thing from the ultra-defensive tactic on the strip: a tactic
  /// makes us harder to score against, this makes the next twenty-five minutes
  /// a non-event for everyone. 1.0 is an ordinary remainder, and every caller
  /// that does not pass it gets exactly the arithmetic it had before.
  double goalRateMult = 1.0,
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/engine/match_orchestration_test.dart --name goalRateMult`
Expected: PASS.

- [ ] **Step 5: Run parity**

Run: `flutter test test/engine/match_orchestration_parity_test.dart`
Expected: PASS — a defaulted named parameter changes no output.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/engine/match_orchestration.dart test/engine/match_orchestration_test.dart
git commit -m "Let a re-simulation damp the goal rate

Park the Bus suppresses both sides, which no tactic does. Defaults to 1.0
so every existing caller is unchanged."
```

---

## Task 7: Live boost windows

**Files:**
- Create: `lib/engine/match_boost_state.dart`
- Test: `test/engine/match_boost_state_test.dart`

**Interfaces:**
- Produces:
  - `class LiveBoost { final String id; final int fromMinute, toMinute; }`
  - `class MatchBoostState { List<LiveBoost> get live; void start(String id, int minute, int windowMinutes); void expireThrough(int minute); double ratingMultAt(int minute); double goalRateMultAt(int minute); }`
  - `const double crowdRoarMult = 1.10`, `const double parkTheBusGoalRate = 0.45`
  - `const double maxCrowdRoarStack = 1.25`

- [ ] **Step 1: Write the failing test**

```dart
void main() {
  group('MatchBoostState', () {
    test('a window runs from its start for its length', () {
      final s = MatchBoostState()..start('crowd_roar', 40, 25);
      expect(s.ratingMultAt(40), closeTo(1.10, 1e-9));
      expect(s.ratingMultAt(64), closeTo(1.10, 1e-9));
      expect(s.ratingMultAt(65), 1.0);
    });

    // The user's own note: boosts stack, they are not one-at-a-time.
    test('TWO ROARS STACK, UNDER A CAP', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('crowd_roar', 45, 25);
      // 1.10 * 1.10 = 1.21, under the 1.25 cap.
      expect(s.ratingMultAt(50), closeTo(1.21, 1e-9));
    });

    test('the cap holds however many are stacked', () {
      final s = MatchBoostState();
      for (var i = 0; i < 6; i++) {
        s.start('crowd_roar', 40, 25);
      }
      expect(s.ratingMultAt(50), closeTo(maxCrowdRoarStack, 1e-9));
    });

    test('Roar and Bus are different axes and do not interfere', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('park_the_bus', 40, 25);
      expect(s.ratingMultAt(50), closeTo(1.10, 1e-9));
      expect(s.goalRateMultAt(50), closeTo(0.45, 1e-9));
    });

    test('expireThrough reports the windows that just closed', () {
      final s = MatchBoostState()..start('crowd_roar', 40, 25);
      expect(s.expireThrough(64), isEmpty);
      expect(s.expireThrough(65).map((b) => b.id), ['crowd_roar']);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/engine/match_boost_state_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`expireThrough` returns `List<LiveBoost>` so the screen can post the `.over`
feed line for each. Pure Dart, no Flutter import.

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/engine/match_boost_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze
git add lib/engine/match_boost_state.dart test/engine/match_boost_state_test.dart
git commit -m "Track live boost windows

Windows stack and overlap, under a cap, so the strip cannot be emptied
into one unbeatable ten minutes."
```

---

## Task 8: VAR and Physio — the undo mechanics

**Files:**
- Modify: `lib/ui/screens/match/match_screen.dart`
- Test: `test/ui/match/retrospective_boosts_test.dart` (create)

**Interfaces:**
- Produces on `_MatchScreenState`: `Map<String, PitchSlot> _injurySlots`,
  `Set<String> _physioSpent`, `Set<String> _varSpent`,
  `void applyVar(String instanceId)`, `void applyPhysio(String instanceId)`,
  `bool canVar(String instanceId)`, `bool canPhysio(String instanceId)`.

Both are the reverse of `_playerSentOff`, which already banks
`_sentOffSlots[slotId] = was` precisely so a man can be drawn back into the
square he was taken from.

- [ ] **Step 1: Write the failing test**

Four assertions, each a separate `test`:

1. A red card, VAR applied → the man is back in **his own** slot, off
   `_bookings` and off `_bookingRecords`, and `liveAttackRating` has risen.
2. **The re-simulation ran from the CURRENT minute, not the incident's.** Play
   to minute 85 after a minute-20 red, apply VAR, and assert the goals scored
   before 85 are unchanged. Overturning a 20th-minute red by re-simulating from
   minute 20 would rewrite sixty-five minutes of a match the player has already
   watched — the thing the 13 Sep audit exists to prevent.
3. An injury with **subs spent and nobody fit**, Physio held → the panel opens
   anyway. This is the path the old guard closed, and it is the case where a
   Physio is worth most.
4. The per-player lock: dismiss without using it, reopen the bench, and the
   tile is dead for that man — but a *second* casualty later in the same match
   is still offered one.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/match/retrospective_boosts_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
  /// Slot id → the man an INJURY took out of it, so a Physio can put him back.
  ///
  /// The mirror of [_sentOffSlots], and it has to be its own map: the sim
  /// vacates an injured man's square before the screen ever sees the event,
  /// so by the time a Physio is reachable there is nothing left on the pitch
  /// to read his position off.
  final Map<String, PitchSlot> _injurySlots = <String, PitchSlot>{};

  /// **ONE OFFER PER MAN PER MATCH.** Replace him, or close the bench without
  /// using it, and that is the decision — he does not come back. A second
  /// casualty later gets its own offer; this man does not get a second one.
  final Set<String> _physioSpent = <String>{};
  final Set<String> _varSpent = <String>{};

  /// Undo a sending-off: he returns NOW, at the minute on the clock.
  ///
  /// **Never from the incident's minute.** Overturning a 20th-minute red at 85
  /// by re-simulating from 20 would rewrite sixty-five minutes of a match the
  /// player has already watched. The goals stand; he simply comes back on.
  /// That is the contract a substitution already plays by, and it means a late
  /// VAR is worth less, which is the right way for it to balance.
  void applyVar(String instanceId) {
    if (!spendBoost(ref.read(gameProvider).state!, 'var_review')) return;
    _varSpent.add(instanceId);
    _restoreToSlot(instanceId, _sentOffSlots);
    _sentOff.remove(instanceId);
    // Off BOTH lists: `_bookings` feeds the feed, the skip's catch-up and the
    // ban the whistle writes; `_bookingRecords` is the red on his career card.
    _dropBookingsAfter(instanceId, 0);
    _dropBookingRecordFor(instanceId, cardRed);
    _note('boost.var.overturned', {'player': _nameOf(instanceId)});
    _resimulate(_minute, _strategy, rerollInjuries: false);
  }
```

`applyPhysio` is the same shape against `_injurySlots`, additionally clearing
`injured` on the card and removing the `no_sub` marker for that minute.

Move the injury guard:

```dart
    // **UNLESS A PHYSIO IS HELD.** The panel with nobody to bring on is
    // pointless, which is why this guard exists — and with a sponge in hand it
    // is the one place the boost can be taken, so the guard would have hidden
    // it in the exact case it is worth most.
    if ((spent || nobody) && !canPhysio(casualtyId)) return;
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/ui/match/retrospective_boosts_test.dart`
Expected: PASS. If it fails with an `ink_sparkle.frag` manifest error,
`rm -rf build/unit_test_assets` and re-run — that is a stale bundle, not this
change.

- [ ] **Step 5: Run the scoreline invariants again**

Run: `flutter test test/ui/match/ --name "WHAT WAS WATCHED"`
Expected: PASS.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/ui/screens/match/match_screen.dart test/ui/match/retrospective_boosts_test.dart
git commit -m "Undo a red card or an injury from the bench

Both re-simulate from the current minute, never the incident's — a late
overturn must not rewrite minutes already watched."
```

---

## Task 9: The crowd synth

**Files:**
- Modify: `lib/util/audio_render.dart`, `lib/data/sound_defs.dart`
- Test: `test/util/audio_render_test.dart`, `test/data/sound_defs_test.dart`

**Interfaces:**
- Produces: `crowdCheerSmall`, `crowdCheerMid`, `crowdCheerRoar`, `boostVar`,
  `boostPhysio` entries in `DEFS`; a `convolve` or `roomWash` primitive in
  `audio_render.dart`.

Source: `../merge-empire-fc/src/utils/sound.js`, `_voice` (line ~173),
`_roomImpulse` (~204), `_crowd` (~218), and the three `crowdCheer*` entries
(~485). **Read all four in full before porting** — the comments carry the
reasoning, particularly why each voice gets its own random vibrato rate.

- [ ] **Step 1: Measure the convolution before committing to it**

Write a throwaway benchmark that convolves 1.05s of noise at 44.1kHz against a
0.34s impulse and prints the elapsed time.

Run: `dart run tool/bench_convolve.dart` (create it, delete it after)

**Decision rule:** under ~2s, port `_roomImpulse` and a direct FIR `convolve`
faithfully. Over that, implement `roomWash` — a handful of decaying taps into a
lowpass — and say so in a comment naming this measurement. Sounds render once
in a background isolate and cache as WAV bytes, so this cost lands on warm-up,
not on playback.

- [ ] **Step 2: Write the failing test**

```dart
  test('the crowd renders, and the three sizes differ', () {
    final small = renderDef('crowdCheerSmall');
    final roar = renderDef('crowdCheerRoar');
    expect(small, isNotEmpty);
    expect(roar, isNotEmpty);
    expect(roar.length, greaterThan(small.length)); // 1.05s vs 0.75s
    expect(roar, isNot(equals(small)));
  });

  // The JS's own note: loudness is NOT the tier cue, because the master chain
  // compresses at ratio 6 over -18dB and a 6dB gap comes out about 1dB apart.
  // Voices, density, reverb and sub carry it instead. So the assertion is that
  // they are DIFFERENT, never that one is louder.
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/data/sound_defs_test.dart --name crowd`
Expected: FAIL — no such def.

- [ ] **Step 4: Port `_voice` and `_crowd`**

`Biquad.bandpass` in `audio_render.dart:114` is already the
constant-0dB-peak-gain form Web Audio uses, which is the one `_voice` needs —
do not write a second bandpass.

Replace the note at the top of `sound_defs.dart` that says the cheers are not
here. It is now wrong, and the reason it was right is worth keeping:

```dart
/// **The crowd cheers are here now, and the deferral is why they look like
/// this.** This file used to record that the JS's three were unwired, that two
/// hundred lines of DSP for a call nobody makes is what the standing rules say
/// not to port, and that a real cheer would be a sample. Crowd Roar is the
/// caller that made it wanted — so the synth was ported rather than sampled,
/// because it exists, it is documented, and `Biquad.bandpass` was already the
/// exact filter `_voice` needs. The tier→size ladder came with it.
```

- [ ] **Step 5: Add the other two cues**

```dart
  // A decision being checked, then given. The drama is the PAUSE, so the drone
  // is most of the length and the resolve is a bright pair on top of its tail.
  'boostVar': ( … ),
  // A spray and a chime — short, because he is up and play restarts.
  'boostPhysio': ( … ),
```

- [ ] **Step 6: Run the tests and watch them pass**

Run: `flutter test test/data/sound_defs_test.dart test/util/audio_render_test.dart`
Expected: PASS.

- [ ] **Step 7: Analyze and commit**

```bash
flutter analyze
git add lib/util/audio_render.dart lib/data/sound_defs.dart test/util/audio_render_test.dart test/data/sound_defs_test.dart
git commit -m "Port the crowd cheer synth from the spec

Crowd Roar is the caller the parked synth was waiting for. Brings the
small/mid/roar tier ladder with it."
```

---

## Task 10: The second trait slot on the player sheet

**Files:**
- Create: `lib/ui/screens/squad/match_trait_block.dart`
- Modify: `lib/ui/screens/squad/player_detail_sheet.dart`
- Test: `test/ui/squad/match_trait_block_test.dart`

**Interfaces:**
- Consumes: `unlockMatchSlot`, `rollMatchTraitForCard`, `hasMatchSlot` (Task 2); `TraitBlockState` patterns from `player_detail_sheet.dart:1466`.
- Produces: `class MatchTraitBlock extends ConsumerStatefulWidget`.

- [ ] **Step 1: Write the failing widget test**

Three tests: a locked slot shows `matchslot-unlock` with the gem cost; tapping
it with a gem opens the slot and reveals the reel; tapping it without gems
leaves the slot locked and takes nothing.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/squad/match_trait_block_test.dart`

- [ ] **Step 3: Implement**

Reuse the existing reel rather than writing a second one. `TraitBlock` in
`player_detail_sheet.dart` already carries the looping `ListWheelScrollView`,
the `_EaseOutPow(2.5)` easing the spec specifies, the `rouletteClick` ratchet
and the pay-before-it-spins rule. Extract the reel into a shared widget if that
is cleaner than parameterising it — but **do not build a second spinner.**

The unlock button uses `mouldedButtonStyle(face:, edge:)`, never
`styleFrom(backgroundColor:)`, which fails silently and is caught by
`architecture_test.dart`.

- [ ] **Step 4: Run and watch it pass**

Run: `flutter test test/ui/squad/match_trait_block_test.dart`

- [ ] **Step 5: Warn on selling an unlocked card**

Add the warning to the existing sell confirm in `player_detail_sheet.dart` —
`squad.detail.sell_burns_slot`. A gem spent on a card the player then sells is
a gem gone, and the confirm is the only place to say so.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/ui/screens/squad/match_trait_block.dart lib/ui/screens/squad/player_detail_sheet.dart test/ui/squad/match_trait_block_test.dart
git commit -m "Add the second trait slot to the player sheet

Reuses the existing reel rather than building a second spinner."
```

---

## Task 11: The match-screen boost strip and the burning bar

**Files:**
- Create: `lib/ui/screens/match/boost_strip.dart`, `lib/ui/screens/match/boost_bar_paint.dart`
- Modify: `lib/ui/screens/match/match_screen.dart` — `_MatchLayout`, `_Scoreboard`
- Test: `test/ui/match/boost_strip_test.dart`

**Interfaces:**
- Consumes: `boostCount`, `spendBoost` (Task 5), `MatchBoostState` (Task 7).
- Produces: `class BoostStrip extends ConsumerWidget`, `class BoostBands extends StatelessWidget`.

- [ ] **Step 1: Write the failing test**

Owned boosts show a count and are tappable; an unowned one is greyed with its
gem price and routes to the shop through `shellControllerProvider` — never by
emitting a bus event by hand.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/match/boost_strip_test.dart`

- [ ] **Step 3: Implement the strip**

**Only the two proactive boosts.** `_MatchLayout` grows a `hasBoostStrip` beside
its `hasTacticStrip`; the strip is 34px against the tactic strip's 46. This
screen has no height to spare — `feedMinHeight` is what pays for anything added
here.

- [ ] **Step 4: Implement the bands**

The progress bar is a 3px `LinearProgressIndicator` at `minute / 90`, clipped
into the scoreboard card's bottom corners. A window is a *segment* of it:
`fromMinute / 90` to `toMinute / 90`. While any boost is live the bar grows to
6px and each window draws its own band — flame for Roar, a slow grey wash for
Bus — so the player sees when it started and when it ends.

Use **one** `AnimationController`, and stop it when nothing is live. A
repeating controller that never settles means no widget test in the suite can
`pumpAndSettle` this screen again — the same trap `TraitBlockState._flash`
documents.

- [ ] **Step 5: Run and watch it pass**

Run: `flutter test test/ui/match/boost_strip_test.dart`

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/ui/screens/match/boost_strip.dart lib/ui/screens/match/boost_bar_paint.dart lib/ui/screens/match/match_screen.dart test/ui/match/boost_strip_test.dart
git commit -m "Add the proactive boost strip and the live-window bands

The window burns across the progress bar, which already means match time,
so the player sees when it started and when it ends."
```

---

## Task 12: The bench boost row

**Files:**
- Create: `lib/ui/screens/match/bench_boost_row.dart`
- Modify: `lib/ui/screens/match/subs_panel.dart`, `lib/ui/screens/match/match_screen.dart`
- Test: `test/ui/match/bench_boost_row_test.dart`

**Interfaces:**
- Consumes: `canVar`, `canPhysio`, `applyVar`, `applyPhysio` (Task 8).
- Produces: `class BenchBoostRow extends ConsumerWidget`; new `showSubsPanel` parameters `onVar`, `onPhysio`, `varTarget`, `physioTarget`.

- [ ] **Step 1: Write the failing test**

A red card opens the bench with VAR lit; using it puts the man back; a locked
tile shows its **reason**, not just a dead control.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/match/bench_boost_row_test.dart`

- [ ] **Step 3: Implement**

The panel is a `heightFraction: 0.92` bottom sheet and already takes
`sentOff`, `sentOffSlots` and `cautioned`, so the row is an addition to a
surface that already carries the state.

A locked tile reads `boost.locked.too_late` — "too late, play has restarted" —
rather than going silently dead. A greyed control with no explanation is what
generates "is this broken?" reports.

- [ ] **Step 4: Signpost it from the coach card**

Add a line to the red-card and injury coach card **text** — not an action
button. The card shows only once ever for a red
(`hasSeenTip(state, redCardTipId)`), so it can introduce the door but must
never be the only one.

- [ ] **Step 5: Run and watch it pass**

Run: `flutter test test/ui/match/bench_boost_row_test.dart`

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/ui/screens/match/bench_boost_row.dart lib/ui/screens/match/subs_panel.dart lib/ui/screens/match/match_screen.dart test/ui/match/bench_boost_row_test.dart
git commit -m "Offer VAR and the sponge at the bench

The red-card coach card shows only once ever, so the panel is the only
surface that can carry these reliably."
```

---

## Task 13: The shop shelf and the daily reward

**Files:**
- Modify: `lib/ui/screens/shop/shop_spend.dart`, `lib/engine/daily_reward_engine.dart`
- Test: `test/ui/shop/boost_tiles_test.dart`, `test/engine/daily_reward_engine_test.dart`

- [ ] **Step 1: Write the failing daily-reward test**

```dart
  test('DAY 4 PAYS A BOOST AS WELL AS ITS COINS', () {
    // The engine's own comment calls day 4 flat since the Scout Voucher left.
    expect(dailyRewards[4]!.boost, 'crowd_roar');
    expect(dailyRewards[4]!.coinsMult, 3); // unchanged
  });

  test('claiming day 4 puts the boost in the inventory', () {
    final s = _stateOnDay(4);
    claimDailyReward(s, now());
    expect(boostCount(s, 'crowd_roar'), 1);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/engine/daily_reward_engine_test.dart --name "DAY 4"`

- [ ] **Step 3: Add the field and the day**

`DailyReward` already carries `freeScout` and `healOne` unused — the typedef
was built for exactly this kind of addition. Add `String? boost`, default null,
grant it in the claim path beside the energy and the gems.

- [ ] **Step 4: Add the shop tiles**

Four `ShopTile`s on the existing `BoostsSection` shelf through `ShopGrid`,
`StoreTone.gem`. Four tiles wrap 3 + 1. Route the buy through
`offerToBuy(context, ref, …)` like every other row on that shelf, so the
confirm and the "can't afford" copy are the shelf's own.

- [ ] **Step 5: Run both suites**

Run: `flutter test test/engine/daily_reward_engine_test.dart test/ui/shop/boost_tiles_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/ui/screens/shop/shop_spend.dart lib/engine/daily_reward_engine.dart test/ui/shop/boost_tiles_test.dart test/engine/daily_reward_engine_test.dart
git commit -m "Sell boosts in the shop and seed one on day 4

Day 4 lost the Scout Voucher and has read flat since."
```

---

## Task 14: Copy, in ten locales

**Files:**
- Modify: `lib/i18n/en_copy.dart`, `lib/i18n/copy/{ar,de,es,fr,it,ja,ko,pt,zh}_copy.dart`
- Test: `test/i18n/call_sites_test.dart`, `test/i18n/en_copy_test.dart`

**Read the headers of `en_copy.dart` and one `copy/*_copy.dart` before adding
anything.** `enMore` APPENDS to an existing pool; `enCopy` REPLACES a key or
adds a new one. Everything in this task is new, so it all goes in `enCopy` and
in each locale's own map.

Keys required:

| Group | Keys |
|---|---|
| Traits | `matchtrait.<id>.name` and `.desc` × 12 |
| Slot | `squad.detail.matchslot.locked`, `.unlock`, `.unlock_confirm`, `squad.detail.sell_burns_slot` |
| Boost names | `boost.<id>.name`, `.desc` × 4 |
| Shop | `shop.boost.pack`, `shop.boost.owned` |
| Bench | `boost.bench.var`, `boost.bench.physio`, `boost.locked.too_late` |
| Feed | `boost.var.overturned`, `boost.physio.recovered`, `boost.roar.live`, `boost.roar.over`, `boost.bus.live`, `boost.bus.over` |
| Coach | `coach.red_card.var_hint`, `coach.injury.physio_hint` |

The six feed keys are **pools**, `|`-separated, at least two variants each — the
feed rebuilds on every tick of the clock and repeats are read.

- [ ] **Step 1: Add every key to `en_copy.dart`'s `enCopy`**

- [ ] **Step 2: Run the call-sites gate**

Run: `flutter test test/i18n/call_sites_test.dart test/i18n/en_copy_test.dart`
Expected: PASS. A `t()` key missing from `en` fails the build.

- [ ] **Step 3: Add all nine translations**

**Every key in all ten, not English plus a fallback.** `t()` falls back to
English, which is right for one string and wrong for a paragraph built out of
pools — the match report shipped thirty English-only keys and a French write-up
read French, then four sentences of English, then French again. The feed lines
are the same shape: a French player would get a French commentary feed with an
English VAR line in the middle of it.

Mind the placeholders: `{player}` must survive every translation.

- [ ] **Step 4: Run the locale matrix**

Run: `flutter test test/i18n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/i18n/
git commit -m "Add match trait and boost copy in all ten locales"
```

---

## Task 15: Reachability and the final gate

**Files:** none — this task verifies.

- [ ] **Step 1: Sweep the engines**

Run: `bash tool/unreached.sh`
Expected: no new rows for `match_trait_engine`, `boost_engine` or
`match_boost_state`. **A high `test-files=` count is the interesting row, not
the safe one** — it means the only thing calling a function is its own test.
Read the script's header before acting on a row; it lists four kinds of hit
that are expected and are not bugs.

- [ ] **Step 2: Sweep the UI**

Run: `bash tool/unreached_ui.sh`
Expected: every new widget file has a `lib/` importer. A test is not a caller.
**`round=2` is where the bodies are.**

- [ ] **Step 3: Check the shipped-copy tell**

Run: `grep -c "matchtrait\." lib/i18n/locales/en.g.dart` — expect 0, since this
copy lives in `en_copy.dart` rather than the generated catalogue. Then grep
`lib/` for a caller of each new key group. A translated string nothing can
print is a feature the port dropped, named and counted in ten languages.

- [ ] **Step 4: Full analyze**

Run: `flutter analyze`
Expected: clean. Not "clean apart from" — clean.

- [ ] **Step 5: Ask before the full suite, then run it**

The full run is ~4,420 tests. Ask first, then:

Run: `TZ=UTC flutter test`
Expected: PASS. `TZ=UTC` because `test/data/events_test.dart` and
`test/engine/event_engine_test.dart` skip themselves outside UTC.

If widget tests fail with an `ink_sparkle.frag` manifest decode error,
`rm -rf build/unit_test_assets` and re-run — that is a stale bundle from an
older engine, not this change.

- [ ] **Step 6: Confirm no stray formatting**

Run: `git diff main --stat`
Expected: only the files this plan names. If a file shows far more changed
lines than the task touched, `dart format` was run — `git diff` it and revert
every hunk that is not yours before the PR. A reviewer cannot find a four-line
change inside forty lines of reflow.

- [ ] **Step 7: Update the queue**

Add both features to `docs/REMAINING.md` as done, with a line each on what was
tested.

```bash
git add docs/REMAINING.md
git commit -m "Tick match traits and manager boosts"
```

---

## Self-review notes

**Spec coverage.** Every section of the spec maps to a task: the pool → 1, the
engine and economy → 2, the sim wiring → 3, the timed re-sim → 4, inventory and
pricing → 5, Park the Bus → 6, windows and stacking → 7, VAR/Physio and the
per-player lock → 8, sound → 9, the trait UI → 10, the strip and the burning
bar → 11, the bench row → 12, shop and dailies → 13, commentary and copy → 14,
reachability → 15.

**Deliberately out of scope**, per the spec: 👑 Comeback King and any
scoreline-conditional trait, a third trait slot, boosts in the IAP shelf, and a
sustained crowd bed under the window.

**The three riskiest tasks**, in order: Task 8 (touches the scoreline
invariants the 13 Sep audit protects), Task 9 (the convolution cost is measured
rather than known), Task 11 (40px off a screen that has none spare).
