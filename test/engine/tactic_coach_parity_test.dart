/// Differential test: the Dart tactic coach against the JS it was ported from.
///
/// The coach's whole claim is that it and the simulation cannot disagree — it
/// earns that by computing expected points EXACTLY from the two Poissons the sim
/// samples, with no Monte Carlo anywhere. So every number here is reproducible,
/// and a port that is off by a rounding step is giving different advice from the
/// game it is advising about.
///
/// See `tool/dump_tactic_coach_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/tactic_coach.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/tactic_coach_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final Map<String, dynamic> refSave = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> _baseState() =>
    jsonDecode(jsonEncode(refSave['state'])) as Map<String, dynamic>;

/// The matchups the reference was generated against, by the name it used.
const _matchups = {
  'level': (ourAtk: 60, ourDef: 60, oppAtk: 60, oppDef: 60),
  'favourite': (ourAtk: 78, ourDef: 76, oppAtk: 54, oppDef: 55),
  'underdog': (ourAtk: 41, ourDef: 40, oppAtk: 72, oppDef: 70),
  'lopsided': (ourAtk: 85, ourDef: 35, oppAtk: 62, oppDef: 61),
  'sunday': (ourAtk: 22, ourDef: 24, oppAtk: 23, oppDef: 25),
  'championsCup': (ourAtk: 96, ourDef: 95, oppAtk: 94, oppDef: 97),
};

List<Map<String, dynamic>> _rows(String key) => [
  for (final r in ref[key] as List) r as Map<String, dynamic>,
];

num? _n(Object? v) => v is num ? v : null;

/// The lineup the reference scored a squad-shaped case against.
List<Map<String, dynamic>> _lineup(String label) => [
  for (final s in (ref['lineups'] as Map)[label] as List)
    s as Map<String, dynamic>,
];

/// A squad of `count` cards all at `tier`, matching the dump script's own.
Map<String, dynamic> _tierSquad(int tier, int count) {
  final s = _baseState();
  final cells = (s['grid'] as Map)['cells'] as List;
  for (var i = 0; i < cells.length; i++) {
    final c = cells[i];
    if (c == null || i >= count) {
      cells[i] = null;
      continue;
    }
    final pos = ('${(c as Map)['definitionId']}').split('_').last;
    c['definitionId'] = 'player_t${tier}_$pos';
  }
  return s;
}

Map<String, dynamic> _stateFor(String label) {
  switch (label) {
    case 'refSave':
      return _baseState();
    case 'refSave433':
      final s = _baseState();
      (s['squad'] as Map)['formation'] = '4-3-3';
      (s['squad'] as Map)['lineup'] = _lineup('refSave433');
      return s;
    case 'refSave532':
      final s = _baseState();
      (s['squad'] as Map)['formation'] = '5-3-2';
      (s['squad'] as Map)['lineup'] = _lineup('refSave532');
      return s;
    case 'bareEleven':
      final s = _tierSquad(4, 11);
      (s['squad'] as Map)['formation'] = '4-4-2';
      (s['squad'] as Map)['lineup'] = _lineup('bareEleven');
      return s;
    case 'deepBench':
      final s = _tierSquad(4, 15);
      (s['squad'] as Map)['formation'] = '4-4-2';
      (s['squad'] as Map)['lineup'] = _lineup('deepBench');
      return s;
    case 'noLineup':
      final s = _baseState();
      (s['squad'] as Map)['lineup'] = <Object?>[];
      return s;
  }
  throw ArgumentError('unknown squad label $label');
}

void main() {
  group('tacticExpectedPoints', () {
    test('matches the JS on every matchup, tactic and mid-match state', () {
      final rows = _rows('expectedPoints');
      expect(rows, hasLength(180));
      for (final row in rows) {
        final m = _matchups['${row['matchup']}']!;
        final got = tacticExpectedPoints(
          m.ourAtk,
          m.ourDef,
          m.oppAtk,
          m.oppDef,
          strategies['${row['strategyId']}'],
          fraction: (row['fraction'] as num).toDouble(),
          margin: (row['margin'] as num).toInt(),
          oppAttackRatio: _n(row['oppAttackRatio'])?.toDouble(),
        );
        expect(
          got,
          closeTo(row['points'] as num, 1e-12),
          reason: '${row['matchup']} / ${row['strategyId']} / $row',
        );
      }
    });

    test('scores a swing as its two branches, not at its mean', () {
      // Averaging first would price Counter Attack as if its gamble never
      // happened, which is the whole identity of the tactic.
      final expected = ref['swingBranching'] as Map<String, dynamic>;
      final counter = strategies['counterAttack']!;
      expect(
        tacticExpectedPoints(73, 72, 60, 61, counter),
        closeTo(expected['scored'] as num, 1e-12),
      );
      expect(
        tacticExpectedPoints(
          73,
          72,
          60,
          61,
          Strategy(
            id: counter.id,
            name: counter.name,
            shortName: counter.shortName,
            icon: counter.icon,
            atkMult: counter.atkMult,
            defMult: counter.defMult,
            injMod: counter.injMod,
            possession: counter.possession,
            variance: counter.variance,
            swing: 0,
            commitmentGain: counter.commitmentGain,
            hint: counter.hint,
          ),
        ),
        closeTo(expected['atMean'] as num, 1e-12),
      );
    });
  });

  group('suggestTactic', () {
    test('picks the same tactic and the same ranking as the JS', () {
      final rows = _rows('suggest');
      expect(rows, hasLength(60));
      for (final row in rows) {
        final m = _matchups['${row['matchup']}']!;
        final opts = row['opts'] as Map<String, dynamic>;
        final got = suggestTactic(
          m.ourAtk,
          m.ourDef,
          m.oppAtk,
          m.oppDef,
          // The JS default is Infinity; JSON cannot hold it, so the dump writes
          // null and it means the same thing — no depth limit at all.
          benchCover: _n(opts['benchCover'])?.toDouble() ?? double.infinity,
          fraction: _n(opts['fraction'])?.toDouble() ?? 1,
          margin: _n(opts['margin'])?.toInt() ?? 0,
          injuryRisk: _n(opts['injuryRisk'])?.toDouble() ?? 0,
          injuryCost: _n(opts['injuryCost'])?.toDouble() ?? 0,
          oppAttackRatio: _n(opts['oppAttackRatio'])?.toDouble(),
        );
        final why = '${row['matchup']} / $opts';
        expect(got.id, row['id'], reason: why);
        expect(
          got.expectedPoints,
          closeTo(row['expectedPoints'] as num, 1e-12),
          reason: why,
        );
        expect(got.thinSquad, row['thinSquad'], reason: why);
        expect(
          got.heldOffSittingBack,
          row['heldOffSittingBack'],
          reason: why,
        );

        final wantRanked = [
          for (final e in row['ranked'] as List) e as Map<String, dynamic>,
        ];
        expect(got.ranked.map((e) => e.id).toList(), [
          for (final e in wantRanked) e['id'],
        ], reason: 'ranking order — $why');
        for (var i = 0; i < wantRanked.length; i++) {
          expect(
            got.ranked[i].points,
            closeTo(wantRanked[i]['points'] as num, 1e-12),
            reason: why,
          );
          expect(
            got.ranked[i].injuryPenalty,
            closeTo(wantRanked[i]['injuryPenalty'] as num, 1e-12),
            reason: why,
          );
          expect(
            got.ranked[i].expectedPoints,
            closeTo(wantRanked[i]['expectedPoints'] as num, 1e-12),
            reason: why,
          );
        }
      }
    });
  });

  group('baselineInjuryRisk', () {
    test('matches the JS across divisions and squad age', () {
      final rows = _rows('baselineInjuryRisk');
      expect(rows, hasLength(16));
      for (final row in rows) {
        final s = _baseState();
        for (final c in (s['grid'] as Map)['cells'] as List) {
          if (c is Map) c['seasonsPlayed'] = row['seasons'];
        }
        expect(
          baselineInjuryRisk(s, row['divisionId'] as String?),
          closeTo(row['risk'] as num, 1e-12),
          reason: '${row['divisionId']} / ${row['seasons']} seasons',
        );
      }
    });
  });

  group('injuryCostPoints', () {
    test('matches the JS for every squad shape and match state', () {
      final rows = _rows('injuryCostPoints');
      expect(rows, hasLength(12));
      for (final row in rows) {
        expect(
          injuryCostPoints(
            _stateFor('${row['label']}'),
            60,
            61,
            fraction: (row['fraction'] as num).toDouble(),
            margin: (row['margin'] as num).toInt(),
          ),
          closeTo(row['cost'] as num, 1e-12),
          reason: '${row['label']} / f=${row['fraction']} m=${row['margin']}',
        );
      }
    });

    test('a knock costs a bare eleven more than a squad with cover', () {
      // The point of computing the cost rather than assuming it: a deep bench
      // makes a knock nearly free, eleven players and nothing behind them makes
      // the same knock ruinous.
      final bare = injuryCostPoints(_stateFor('bareEleven'), 60, 61);
      final deep = injuryCostPoints(_stateFor('deepBench'), 60, 61);
      expect(bare, greaterThan(deep));
    });
  });

  group('constants', () {
    test('match the JS', () {
      final c = ref['constants'] as Map<String, dynamic>;
      expect(tacticMinBenchCover, c['tacticMinBenchCover']);
      expect(leadProtectFraction, closeTo(c['leadProtectFraction'] as num, 1e-15));
      expect(injuryFutureMatches, closeTo(c['injuryFutureMatches'] as num, 1e-15));
    });
  });
}
