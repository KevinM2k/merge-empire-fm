/// The scenario set behind the Dart-owned match goldens — ONE runner, two
/// consumers.
///
/// `tool/dump_positional_golden.dart` calls these to WRITE
/// `test/fixtures/positional_golden.json` and
/// `positional_season_golden.json`; `match_orchestration_parity_test`,
/// `season_difftest_test` and `cup_engine_test` call the same functions and
/// compare. The scenarios live here so the file and the tests cannot drift:
/// a scenario added to the test is a scenario the next dump records.
///
/// These replaced the node-dumped fixtures when the positional sim took over
/// the scoreline (see the header of `engine/match_orchestration.dart`). The JS
/// still draws two Poissons, so it stopped being the reference for a whole
/// match. **A self-generated golden catches regressions, not correctness** —
/// it pins whatever it was handed, bug and all. `positional_balance_test` is
/// the half of the net that asks whether the numbers are RIGHT; this half only
/// asks whether they moved.
///
/// Both random streams are pinned exactly as the node dumps pinned them: the
/// seeded stream through `setSeed`, and the unseeded `Math.random` half of the
/// feed through ONE `JsMathRandom` driven into both injection points — the JS
/// had a single `Math.random`, and the port keeps the split (see the header of
/// `engine/match_events.dart`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/quest_match.dart'
    show resolveMatchQuests;
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import 'canonical.dart';
import 'js_math_random.dart';

const int positionalFixedNow = 1700000000000;

const String positionalGoldenPath = 'test/fixtures/positional_golden.json';
const String positionalSeasonGoldenPath =
    'test/fixtures/positional_season_golden.json';
const String positionalSeasonBasePath =
    'test/fixtures/positional_season_base.json';

final Map<String, dynamic> _questRef =
    jsonDecode(
          File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Dart values through a JSON round trip, so ints, doubles and nested maps line
/// up with what the file holds.
Object? jsonRoundTrip(Object? v) => jsonDecode(jsonEncode(v));

Map<String, dynamic> cloneMap(Object? v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;

/// The reference save every scenario starts from.
Map<String, dynamic> referenceSave() => cloneMap(_questRef['state']);

// ── league matches ───────────────────────────────────────────────────────────

/// How a scenario's save differs from the reference one.
class Setup {
  const Setup({
    this.hardMode = false,
    this.aged = false,
    this.progression = const {},
    this.squad = const {},
    this.shop = const {},
    this.boosts = const {},
    this.grudges = const {},
  });

  final bool hardMode;

  /// A squad old enough that injuries actually land, in the most physical
  /// league — applied AFTER the overrides, and the XI rebuilt, as the node dump
  /// did it.
  final bool aged;

  final Map<String, dynamic> progression;
  final Map<String, dynamic> squad;
  final Map<String, dynamic> shop;
  final Map<String, dynamic> boosts;
  final Map<String, dynamic> grudges;

  String get divisionId => aged ? 'champions_cup' : 'regional_league';
}

List<Map<String, dynamic>> _lineupMaps(List<LineupSlot> slots) => [
  for (final s in slots)
    {
      'slotId': s.slotId,
      'slotPosition': s.slotPosition,
      'cardInstanceId': s.cardInstanceId,
    },
];

List<CardInstance?> _cellsOf(Map<String, dynamic> s) => [
  for (final c in (s['grid'] as Map)['cells'] as List)
    c is Map<String, dynamic> ? CardInstance(c) : null,
];

/// The save a scenario kicks off from: the reference squad with match counters
/// seeded, a 4-4-2 XI from this port's own builder, then the overrides.
Map<String, dynamic> matchState(Setup setup) {
  final s = referenceSave();
  final prog = s['progression'] as Map<String, dynamic>;
  prog['matchesPlayed'] = 12;
  prog['matchesWon'] = 5;
  prog['matchesDrawn'] = 3;
  prog['seasonWins'] = 2;
  prog['seasonDraws'] = 1;
  prog['seasonLosses'] = 1;
  prog['seasonAwardedPlayed'] = 4;
  prog['trophiesTotal'] = 0;
  prog['lastMatchAt'] = positionalFixedNow - 600000;
  prog['careerWins'] = 5;
  prog['careerDraws'] = 3;
  prog['careerGoalsFor'] = 14;
  s['careerStats'] = {
    'leagueWins': 0,
    'cupWins': 0,
    'matchesWon': 5,
    'totalMerges': 0,
  };

  final squad = s['squad'] as Map<String, dynamic>;
  squad['formation'] = '4-4-2';
  squad['lineup'] = _lineupMaps(buildDefaultLineup('4-4-2', _cellsOf(s)));
  squad['strategyId'] = 'balanced';

  if (setup.hardMode) (s['settings'] as Map)['hardMode'] = true;
  prog.addAll(cloneMap(jsonRoundTrip(setup.progression)));
  squad.addAll(cloneMap(jsonRoundTrip(setup.squad)));
  (s['shop'] as Map).addAll(setup.shop);
  (s['boosts'] as Map).addAll(setup.boosts);
  ((s['transferMarket'] as Map)['grudges'] as Map).addAll(
    cloneMap(jsonRoundTrip(setup.grudges)),
  );

  if (setup.aged) {
    for (final c in (s['grid'] as Map)['cells'] as List) {
      if (c is Map) c['seasonsPlayed'] = 14;
    }
    prog['currentDivision'] = 'champions_cup';
    squad['lineup'] = _lineupMaps(
      buildDefaultLineup(squad['formation'] as String?, _cellsOf(s)),
    );
  }
  return s;
}

/// A squad of [count] cards all at [tier].
Map<String, dynamic> tierSquadState(int tier, int count) {
  final s = matchState(const Setup());
  final cells = (s['grid'] as Map)['cells'] as List;
  for (var i = 0; i < cells.length; i++) {
    final c = cells[i];
    if (c == null || i >= count) {
      cells[i] = null;
      continue;
    }
    final pos = '${(c as Map)['definitionId']}'.split('_').last;
    c['definitionId'] = 'player_t${tier}_$pos';
  }
  return s;
}

/// The fields a match can move on a card.
const _cardKeys = [
  'injured',
  'injuredAt',
  'injuryDurationMs',
  'form',
  'energy',
  'energyUpdatedAt',
  'stats',
];

/// The slice of the save a match writes — the pyramid and the discovered-player
/// log are the bulk of it and a match touches neither.
Map<String, dynamic> saveDigest(Map<String, dynamic> s) {
  final cells = (s['grid'] as Map)['cells'] as List;
  return {
    'cells': {
      for (final c in cells.whereType<Map<String, dynamic>>())
        '${c['instanceId']}': {
          for (final k in _cardKeys)
            if (c.containsKey(k)) k: c[k],
        },
    },
    'lineup': (s['squad'] as Map)['lineup'],
    'progression': {
      for (final e in (s['progression'] as Map).entries)
        if (e.key != 'leaguePyramid' && e.key != 'discoveredPlayers')
          '${e.key}': e.value,
    },
    'resources': s['resources'],
    'careerStats': s['careerStats'],
    'shop': s['shop'],
    'grudges': (s['transferMarket'] as Map)['grudges'],
  };
}

/// Only the fields a re-simulation is allowed to rewrite.
Map<String, dynamic> resultDigest(MatchResult r) => {
  'homeGoals': r['homeGoals'],
  'awayGoals': r['awayGoals'],
  'won': r['won'],
  'drawn': r['drawn'],
  'coinsEarned': r['coinsEarned'],
  'injuryCount': r['injuryCount'],
  'injuredName': r['injuredName'],
  // Cloned, not referenced: a re-simulation PUSHES to the live injuryLog.
  'injuryLog': jsonRoundTrip(r['injuryLog']),
  'hardSimInjuries': jsonRoundTrip((r['hardSim'] as Map?)?['injuries']),
};

/// One league scenario: how the save is set up, both seeds, and what to do.
class MatchScenario {
  MatchScenario(this.name, this.seed, this.mathSeed, this.setup, this.run);

  final String name;
  final int seed;
  final int mathSeed;
  final Setup setup;

  /// Runs the scenario on a prepared save and returns what to record.
  final Map<String, dynamic> Function(Map<String, dynamic> state, Setup setup)
  run;
}

Map<String, dynamic> _sim(Map<String, dynamic> s, Setup setup) => {
  'result': simulateMatch(s, setup.divisionId),
};

Map<String, dynamic> _settle(Map<String, dynamic> s, Setup setup) {
  final result = simulateMatch(s, setup.divisionId);
  finalizeMatchOutcome(s, result);
  // The second call has to be a no-op — full time reaches it from the match
  // screen AND from applyMatchRewards.
  finalizeMatchOutcome(s, result);
  applyMatchRewards(s, result);
  applyMatchRewards(s, result);
  return {'result': result};
}

Map<String, dynamic> Function(Map<String, dynamic>, Setup) _resim(
  int fromMinute,
  String strategyId,
) => (s, setup) {
  final result = simulateMatch(s, setup.divisionId);
  final before = resultDigest(result);
  final newEvents = reSimulateRemainder(
    result,
    fromMinute,
    strategyId,
    result['homeGoals'] as int,
    result['awayGoals'] as int,
    s,
  );
  return {'before': before, 'result': result, 'newEvents': newEvents};
};

/// An event cup: strength is a fixed external rating, never the club squad.
Map<String, dynamic> Function(Map<String, dynamic>, Setup) _resimFixed(
  String strategyId,
) => (s, setup) {
  final result = <String, dynamic>{
    'divisionId': 'regional_league',
    'isCup': true,
    'fixedRating': true,
    'anonymousPlayers': true,
    'squadRating': 74,
    'isHome': true,
    'effOppAttackRating': 70,
    'effOppDefenceRating': 71,
    'opponentRating': 70,
    'addedTime': 3,
    'homeGoals': 0,
    'awayGoals': 0,
    'events': <Object?>[],
    'injuryLog': <Object?>[],
  };
  final newEvents = reSimulateRemainder(result, 0, strategyId, 0, 0, s);
  return {'result': result, 'newEvents': newEvents};
};

/// A level cup tie past the whistle: the only way to the shootout branch.
Map<String, dynamic> _resimCupShootout(Map<String, dynamic> s, Setup setup) {
  final result = <String, dynamic>{
    'divisionId': 'regional_league',
    'isCup': true,
    'isHome': true,
    'squadRating': 60,
    'effOppAttackRating': 60,
    'effOppDefenceRating': 61,
    'opponentRating': 60,
    'addedTime': 2,
    'homeGoals': 1,
    'awayGoals': 1,
    'events': <Object?>[],
    'injuryLog': <Object?>[],
    'oppAttackRatio': 0.45,
  };
  final newEvents = reSimulateRemainder(result, 92, 'balanced', 1, 1, s);
  return {'result': result, 'newEvents': newEvents};
}

Map<String, dynamic> _hardLive(Map<String, dynamic> s, Setup setup) {
  final result = simulateMatch(s, setup.divisionId);
  final at = <String, dynamic>{};
  for (final minute in [0, 20, 45, 70, 90]) {
    final live = hardLiveRatings(result, minute, s, 'balanced');
    at['$minute'] = {'attack': live.attack, 'defence': live.defence};
    at['minutesPlayed_$minute'] = jsonRoundTrip(
      (result['hardSim'] as Map)['minutesPlayed'],
    );
  }
  return {'result': result, 'at': at};
}

/// Every league scenario the golden records, in dump order.
final List<MatchScenario> matchScenarios = [
  for (final seed in [1, 7, 12345, 987654]) ...[
    MatchScenario('easy_s$seed', seed, seed * 3 + 1, const Setup(), _sim),
    MatchScenario(
      'hard_s$seed',
      seed,
      seed * 3 + 1,
      const Setup(hardMode: true),
      _sim,
    ),
  ],
  MatchScenario(
    'forceWin',
    4242,
    99,
    const Setup(),
    (s, setup) => {
      'result': simulateMatch(s, setup.divisionId, forceWin: true),
    },
  ),
  MatchScenario(
    'luckyBoot',
    4242,
    99,
    const Setup(shop: {'luckyBootReady': true}),
    _sim,
  ),
  MatchScenario(
    'grudge',
    4242,
    99,
    const Setup(
      grudges: {
        'regional_league_4': {'boost': 6, 'matches': 2},
      },
    ),
    _sim,
  ),
  // Both sides in the drop zone in the second half of the season — the only
  // state the relegation boost is ever applied in.
  MatchScenario(
    'relegationZone',
    555,
    31,
    const Setup(
      progression: {
        'seasonMatchesPlayed': 9,
        'playerTablePosition': 8,
        'opponentTablePositions': {'regional_league_2': 7},
        'stagnationBuffs': {'regional_league': 3},
      },
    ),
    _sim,
  ),
  // A fixture nobody has played, so the opponent's rating is rolled — the one
  // seeded draw that happens before anything else.
  MatchScenario(
    'unrolledOpponent',
    20250817,
    5,
    const Setup(
      progression: {'seasonCount': 9, 'seasonOpponentRatings': <String, int>{}},
    ),
    _sim,
  ),
  // No XI set: ratings fall back to the healthy top eleven, Pro mode declines
  // its segment sim, and the positional sim has nobody to put on the pitch.
  MatchScenario(
    'noLineup',
    616,
    17,
    const Setup(squad: {'lineup': <Object?>[]}),
    _sim,
  ),
  MatchScenario(
    'noLineupHard',
    616,
    17,
    const Setup(hardMode: true, squad: {'lineup': <Object?>[]}),
    _sim,
  ),
  // An old squad in the most physical division: injuries land, and casual
  // mode plays the post-injury window a man down.
  for (final seed in [3, 11, 29, 64]) ...[
    MatchScenario(
      'injuryEasy_s$seed',
      seed,
      seed + 500,
      const Setup(aged: true),
      _sim,
    ),
    MatchScenario(
      'injuryHard_s$seed',
      seed,
      seed + 500,
      const Setup(aged: true, hardMode: true),
      _sim,
    ),
  ],
  MatchScenario(
    'seasonCloses',
    88,
    88,
    const Setup(progression: {'seasonMatchesPlayed': 13}),
    _sim,
  ),
  for (final seed in [2, 19]) ...[
    MatchScenario('settleEasy_s$seed', seed, seed * 7, const Setup(), _settle),
    MatchScenario(
      'settleHard_s$seed',
      seed,
      seed * 7,
      const Setup(hardMode: true),
      _settle,
    ),
  ],
  MatchScenario('settleWin', 4242, 99, const Setup(), (s, setup) {
    final result = simulateMatch(s, setup.divisionId, forceWin: true);
    applyMatchRewards(s, result);
    return {'result': result};
  }),
  MatchScenario('rewardsOnly', 77, 7, const Setup(), (s, setup) {
    final result = simulateMatch(s, setup.divisionId);
    applyMatchRewards(s, result);
    return {'result': result};
  }),
  for (final (name, setup) in [
    ('resimEasy', const Setup()),
    ('resimHard', const Setup(hardMode: true)),
  ])
    for (final (seed, fromMinute, strategyId) in [
      (5, 45, 'allOutAttack'),
      (5, 20, 'parkTheBus'),
      (5, 80, 'counterAttack'),
      (13, 45, 'highPress'),
      (13, 89, 'balanced'),
    ])
      MatchScenario(
        '${name}_s${seed}_m${fromMinute}_$strategyId',
        seed,
        seed * 11,
        setup,
        _resim(fromMinute, strategyId),
      ),
  for (final seed in [3, 11, 29])
    MatchScenario(
      'resimCancelsInjury_s$seed',
      seed,
      seed + 500,
      const Setup(aged: true),
      _resim(10, 'parkTheBus'),
    ),
  for (final strategyId in ['balanced', 'allOutAttack', 'parkTheBus'])
    MatchScenario(
      'resimFixedRating_$strategyId',
      31337,
      3,
      const Setup(),
      _resimFixed(strategyId),
    ),
  MatchScenario('resimCupShootout', 909, 13, const Setup(), _resimCupShootout),
  MatchScenario(
    'hardLive',
    3,
    503,
    const Setup(aged: true, hardMode: true),
    _hardLive,
  ),
];

MatchScenario matchScenario(String name) =>
    matchScenarios.firstWhere((s) => s.name == name);

/// Seed both streams, build the save, run, and record — the whole scenario,
/// as a JSON-shaped map.
Map<String, dynamic> runMatchScenario(MatchScenario sc) {
  setClock(() => positionalFixedNow);
  final rng = JsMathRandom(sc.mathSeed);
  setEventRandom(rng);
  setMatchRandom(rng);
  seeded.setSeed(sc.seed);
  try {
    final state = matchState(sc.setup);
    final lineupBefore = jsonRoundTrip((state['squad'] as Map)['lineup']);
    final extra = sc.run(state, sc.setup);
    return cloneMap({
      'seed': sc.seed,
      'mathSeed': sc.mathSeed,
      'lineupBefore': lineupBefore,
      ...extra,
      'state': saveDigest(state),
    });
  } finally {
    resetClock();
    resetEventRandom();
    resetMatchRandom();
  }
}

// ── cup runs ─────────────────────────────────────────────────────────────────

/// The reference save with the branches a cup run writes into.
Map<String, dynamic> cupState({
  String division = 'regional_league',
  bool hardMode = false,
  bool strongSquad = false,
  bool luckyBoot = false,
}) {
  final s = referenceSave();
  s['prestige'] = <String, dynamic>{'level': 0};
  s['careerStats'] = <String, dynamic>{'leagueWins': 0, 'cupWins': 0};
  s['club'] = <String, dynamic>{};
  final prog = s['progression'] as Map<String, dynamic>;
  prog['cups'] = <String, dynamic>{
    'active': null,
    'history': <dynamic>[],
    'availableThisSeason': true,
  };
  prog['currentDivision'] = division;
  (s['settings'] as Map<String, dynamic>)['hardMode'] = hardMode;
  if (luckyBoot) (s['shop'] as Map<String, dynamic>)['luckyBootReady'] = true;

  if (strongSquad) {
    // The reference squad is a 27-rated Regional side and the bracket draws
    // from the top of the pyramid, so it loses in the first round on every
    // seed tried. Lifting a trophy needs a squad that could plausibly do it.
    for (final raw in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
      if (raw is! Map<String, dynamic>) continue;
      final pos = (raw['definitionId'] as String).split('_').last;
      raw['definitionId'] = 'player_t8_$pos';
    }
  }
  return s;
}

/// Wall-clock stamps, blanked rather than compared.
const cupTimeKeys = {
  'startedAt',
  'endedAt',
  'lastMatchAt',
  'injuredAt',
  'energyUpdatedAt',
};

Object? stripTimes(Object? v) {
  if (v is List) return [for (final e in v) stripTimes(e)];
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        '${e.key}': cupTimeKeys.contains(e.key) ? null : stripTimes(e.value),
    };
  }
  return v;
}

class CupScenario {
  const CupScenario(
    this.label,
    this.seed,
    this.division, {
    this.hardMode = false,
    this.strong = false,
  });

  final String label;
  final int seed;
  final String division;
  final bool hardMode;
  final bool strong;
}

const List<CupScenario> cupScenarios = [
  CupScenario('runA', 31337, 'regional_league'),
  CupScenario('runB', 555, 'champions_cup'),
  CupScenario('runPro', 8080, 'elite_league', hardMode: true),
  CupScenario('runWinner', 7, 'regional_league', strong: true),
];

CupScenario cupScenario(String label) =>
    cupScenarios.firstWhere((s) => s.label == label);

Map<String, dynamic> _preparedDigest(PreparedCupRound p) => {
  'cupId': p.cupId,
  'round': p.round,
  'roundName': p.roundName,
  'opponentName': p.opponentName,
  'won': p.won,
  'homeGoals': p.homeGoals,
  'awayGoals': p.awayGoals,
  'earned': p.earned,
  'squadRating': p.squadRating,
  'opponentRating': p.opponentRating,
  'ourAttackRating': p.ourAttackRating,
  'ourDefenceRating': p.ourDefenceRating,
  'effOppAttackRating': p.effOppAttackRating,
  'effOppDefenceRating': p.effOppDefenceRating,
  'isFinal': p.isFinal,
  'penaltyShootout': p.penaltyShootout == null
      ? null
      : {
          'playerWins': p.penaltyShootout!.playerWins,
          'homeScore': p.penaltyShootout!.homeScore,
          'awayScore': p.penaltyShootout!.awayScore,
          'kicks': p.penaltyShootout!.kicks.length,
        },
  'injuries': [
    for (final inj in p.injuries)
      {'iid': inj.card.instanceId, 'minute': inj.minute},
  ],
  // The positional record's headline, so a run that changes WHERE it was
  // decided is caught as well as one that changes the score.
  'shots': p.positional['shots'],
  'positionalGoals': p.positional['goals'],
  'events': (p.positional['ev'] as List).length,
};

/// A whole cup run, round for round: prepare, commit, and everything the save
/// ends up holding.
Map<String, dynamic> runCupScenario(CupScenario sc) {
  setClock(() => positionalFixedNow);
  seeded.setSeed(sc.seed);
  try {
    final state = cupState(
      division: sc.division,
      hardMode: sc.hardMode,
      strongSquad: sc.strong,
    );
    startCup(state);
    final rounds = <Map<String, dynamic>>[];
    for (var i = 0; i < 5; i++) {
      final prepared = prepareCupRound(state);
      if (prepared == null) break;
      final drop = commitCupRound(state, prepared.won, prepared);
      rounds.add({
        'prepared': _preparedDigest(prepared),
        'sponsorDrop': drop == null
            ? null
            : {
                'kind': drop.kind,
                'cellIdx': drop.cellIdx,
                'sponsorData': {
                  'name': drop.sponsorData.name,
                  'multiplier': drop.sponsorData.multiplier,
                },
              },
        'coins': (state['resources'] as Map)['fanCoins'],
        'activeRound': activeCup(state)?['round'],
      });
      if (activeCup(state) == null) break;
    }
    final cups = (state['progression'] as Map)['cups'] as Map;
    return cloneMap({
      'seed': sc.seed,
      'rounds': rounds,
      'history': stripTimes(cups['history']),
      'gems': (state['resources'] as Map)['gems'],
      'careerStats': state['careerStats'],
      'cupLooksWon': (state['club'] as Map)['cupLooksWon'] ?? <dynamic>[],
      'leagueTrophies':
          (state['progression'] as Map)['leagueTrophies'] ?? <dynamic>[],
      'lineup': (state['squad'] as Map)['lineup'],
      'energies': [
        for (final c in (state['grid'] as Map)['cells'] as List)
          if (c != null) (c as Map)['energy'],
      ],
    });
  } finally {
    resetClock();
  }
}

/// The one-shot path, which must match a prepare-and-commit pair.
Map<String, dynamic> runCupOneShot() {
  setClock(() => positionalFixedNow);
  seeded.setSeed(31337);
  try {
    final state = cupState();
    startCup(state);
    final r = playCupRound(state)!;
    return cloneMap({
      'won': r.prepared.won,
      'homeGoals': r.prepared.homeGoals,
      'awayGoals': r.prepared.awayGoals,
      'coins': (state['resources'] as Map)['fanCoins'],
    });
  } finally {
    resetClock();
  }
}

// ── whole seasons ────────────────────────────────────────────────────────────

final Map<String, dynamic> _seasonBase =
    jsonDecode(File(positionalSeasonBasePath).readAsStringSync())
        as Map<String, dynamic>;

/// How many seasons one run plays. Long enough that a divergence in the season
/// boundary has somewhere to grow, short enough to stay a fixture.
const int seasonsPerRun = 6;

/// The runs, by label: seed, unseeded seed, hard mode.
Map<String, Map<String, dynamic>> seasonRuns() => {
  for (final e in (_seasonBase['runs'] as Map).entries)
    '${e.key}': e.value as Map<String, dynamic>,
};

/// The save a run starts from — a default save with the reference squad, as
/// the node harness built it, frozen as an input the day the Dart golden took
/// over. Whether the two `createDefaultState`s agree is the schema fixture's
/// question, not this one's.
Map<String, dynamic> seasonBaseState(String label) =>
    cloneMap((_seasonBase['base'] as Map)[label]);

/// What tells you WHAT went wrong, once a hash says something did.
Map<String, dynamic> seasonResultDigest(MatchResult r) => {
  'homeGoals': r['homeGoals'],
  'awayGoals': r['awayGoals'],
  'won': r['won'] == true,
  'drawn': r['drawn'] == true,
  'isHome': r['isHome'] == true,
  'coinsEarned': r['coinsEarned'] ?? 0,
  'trophiesEarned': r['trophiesEarned'] ?? 0,
  'opponentName': r['opponentName'],
  'squadRating': r['squadRating'],
  'opponentRating': r['opponentRating'],
  'injuryCount': r['injuryCount'] ?? 0,
  'events': (r['events'] as List?)?.length ?? 0,
  'shots': (r['positional'] as Map?)?['shots'],
};

Map<String, dynamic> seasonEndDigest(SeasonOutcome o) => {
  'outcome': o.outcome,
  'position': o.position,
  'oldDivision': o.oldDivision,
  'newDivision': o.newDivision,
  'payout': o.payout,
  'gemsAwarded': o.gemsAwarded,
  'ageing': o.ageingReport.length,
  'injuryRecovered': o.injuryReport.recovered,
  'injuryShortened': o.injuryReport.shortened,
  'sponsorsExpired': o.sponsorReport.expired,
};

/// One league match, in the order the League screen runs it: simulate, count
/// it for the quests, commit the outcome at full time, resolve the match track,
/// and credit the payout on close.
MatchResult playSeasonMatch(Map<String, dynamic> state) {
  final division = (state['progression'] as Map)['currentDivision'] as String;
  final result = simulateMatch(state, division);
  trackEvent(state, QuestAction.playMatches);
  if (result['won'] == true) trackEvent(state, QuestAction.matchWin);
  finalizeMatchOutcome(state, result);
  resolveMatchQuests(state, result);
  applyMatchRewards(state, result);
  return result;
}

/// Seeds both streams and hands back the run's starting save with its first
/// season's fixtures drawn.
Map<String, dynamic> beginSeasonRun(String label) {
  final run = seasonRuns()[label]!;
  seeded.setSeed(run['seed'] as int);
  // ONE instance for both injection points — see the library header.
  final unseeded = JsMathRandom(run['mathSeed'] as int);
  setMatchRandom(unseeded);
  setEventRandom(unseeded);
  final state = seasonBaseState(label);
  ensureLeaguePyramid(state);
  initSeasonOpponents(state);
  generateSeasonFixtures(state);
  return state;
}

/// A whole run: a hash of the canonical save after every match plus the
/// headline result, and the whole save at every season boundary.
///
/// [onStep] and [onSeasonEnd] let the test compare as it goes, so a failure
/// names the first match that moved rather than the last.
Map<String, dynamic> runSeasonRun(
  String label, {
  void Function(int step, Map<String, dynamic> record)? onStep,
  void Function(int season, Map<String, dynamic> record)? onSeasonEnd,
}) {
  setClock(() => positionalFixedNow);
  try {
    final run = seasonRuns()[label]!;
    final state = beginSeasonRun(label);
    final steps = <Map<String, dynamic>>[];
    final seasonEnds = <Map<String, dynamic>>[];
    for (var season = 0; season < seasonsPerRun; season++) {
      final fixtures =
          (state['progression'] as Map)['seasonFixtures'] as List? ?? const [];
      for (var i = 0; i < fixtures.length; i++) {
        final result = playSeasonMatch(state);
        final record = <String, dynamic>{
          'season': season,
          'match': i,
          'hash': hashOf(state),
          'result': jsonRoundTrip(seasonResultDigest(result)),
          // The very first match carries its whole save: a run that diverges
          // immediately has nowhere else to look.
          if (season == 0 && i == 0) 'save': canonical(state),
        };
        onStep?.call(steps.length, record);
        steps.add(record);
      }
      final ended = endSeason(state);
      final record = <String, dynamic>{
        'season': season,
        'hash': hashOf(state),
        'ended': jsonRoundTrip(seasonEndDigest(ended)),
        // The whole save, so a hash mismatch has something to diff against.
        'save': canonical(state),
      };
      onSeasonEnd?.call(season, record);
      seasonEnds.add(record);
    }
    return {
      'seed': run['seed'],
      'mathSeed': run['mathSeed'],
      'hardMode': run['hardMode'] == true,
      'steps': steps,
      'seasonEnds': seasonEnds,
    };
  } finally {
    resetClock();
    resetMatchRandom();
    resetEventRandom();
  }
}
