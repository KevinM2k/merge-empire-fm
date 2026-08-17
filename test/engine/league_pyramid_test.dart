import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

Map<String, dynamic> _state({
  String division = 'regional_league',
  Map<String, dynamic>? pyramid,
  List<dynamic>? seasonOpponents,
  Map<String, dynamic>? seasonOpponentRatings,
  int seasonCount = 1,
}) => {
  'progression': <String, dynamic>{
    'currentDivision': division,
    'seasonCount': seasonCount,
    'leaguePyramid': pyramid,
    'seasonOpponents': ?seasonOpponents,
    'seasonOpponentRatings': ?seasonOpponentRatings,
  },
};

List<Map<String, dynamic>> _teams(Map<String, dynamic> pyramid, String divId) =>
    [for (final t in pyramid[divId] as List) t as Map<String, dynamic>];

Map<String, dynamic> _team(
  String name,
  int rating, {
  String? formation,
  double? attackRatio,
  double? attackBias,
}) => {
  'name': name,
  'rating': rating,
  'formation': ?formation,
  'attackRatio': ?attackRatio,
  'attackBias': ?attackBias,
};

/// A pyramid with a full complement everywhere, so a test can change one thing.
Map<String, dynamic> _fullPyramid({
  String? tweakDiv,
  List<Map<String, dynamic>>? tweakTeams,
}) {
  final out = <String, dynamic>{};
  for (final div in divisions) {
    if (div.id == tweakDiv && tweakTeams != null) {
      out[div.id] = tweakTeams;
      continue;
    }
    final mid = (div.opponentRatingRange.$1 + div.opponentRatingRange.$2) ~/ 2;
    out[div.id] = [
      for (var i = 0; i < teamsPerLeague; i++)
        _team('${div.id}_$i', mid + i, formation: '4-4-2', attackRatio: 0.402),
    ];
  }
  return out;
}

void main() {
  setUp(() => seeded.setSeed(1234));

  group('aiFormations', () {
    test('every shape carries the attack-share its positions imply', () {
      // Each entry is Σ(position ratio) / 11 for that formation, which is what
      // keeps an AI side on the same ATK/DEF scale as the player's squad.
      for (final f in aiFormations) {
        final positions = aiFormationPositions[f.id];
        expect(positions, isNotNull, reason: f.id);
        expect(positions!.length, 11);
      }
      expect(aiFormations.map((f) => f.id), [
        '3-4-3',
        '4-3-3',
        '4-4-2',
        '5-3-2',
        '5-4-1',
      ]);
    });

    test('the band is narrow enough that rating still dominates', () {
      final shares = aiFormations.map((f) => f.attackRatio);
      expect(shares.reduce((a, b) => a < b ? a : b), 0.348);
      expect(shares.reduce((a, b) => a > b ? a : b), 0.457);
    });

    test('ids are unique', () {
      expect(aiFormations.map((f) => f.id).toSet().length, aiFormations.length);
    });
  });

  group('randomFormation', () {
    test('splits 30 attacking / 40 balanced / 30 defensive', () {
      seeded.setSeed(7);
      final counts = <String, int>{};
      for (var i = 0; i < 20000; i++) {
        final style = randomFormation('regional_league').style;
        counts[style] = (counts[style] ?? 0) + 1;
      }
      expect(counts['attacking']! / 20000, closeTo(0.30, 0.02));
      expect(counts['balanced']! / 20000, closeTo(0.40, 0.02));
      expect(counts['defensive']! / 20000, closeTo(0.30, 0.02));
    });

    test('the top flight never fields the ultra-cautious 5-4-1', () {
      seeded.setSeed(3);
      final seen = {
        for (var i = 0; i < 3000; i++) randomFormation('champions_cup').id,
      };
      expect(seen, isNot(contains('5-4-1')));
      expect(seen, contains('5-3-2'));
    });

    test('every other division can field all five', () {
      seeded.setSeed(11);
      final seen = {
        for (var i = 0; i < 3000; i++) randomFormation('sunday_league').id,
      };
      expect(seen.length, 5);
    });

    test('draws a SECOND number only on the attacking and bottom branches', () {
      // The balanced branch returns without a second draw, and every seeded
      // number after it in the stream depends on that.
      seeded.setSeed(42);
      final probe = List.generate(12, (_) => seeded.random());

      seeded.setSeed(42);
      randomFormation('regional_league');
      final after = seeded.random();

      // r = probe[0]. A balanced roll consumed one number, anything else two.
      final expectedIndex = probe[0] < 0.30 || probe[0] >= 0.70 ? 2 : 1;
      expect(after, probe[expectedIndex]);
    });
  });

  group('formationForRatio', () {
    test('maps a legacy share onto the closest real shape', () {
      expect(formationForRatio(0.62, 'regional_league').id, '3-4-3');
      expect(formationForRatio(0.470, 'regional_league').id, '3-4-3');
      expect(formationForRatio(0.430, 'regional_league').id, '4-3-3');
      expect(formationForRatio(0.402, 'regional_league').id, '4-4-2');
      expect(formationForRatio(0.375, 'regional_league').id, '5-3-2');
      expect(formationForRatio(0.20, 'regional_league').id, '5-4-1');
    });

    test('the old glass cannons all land inside the narrow band', () {
      // A free 0.70 attack-share with a DEF in the twenties is what this exists
      // to tame — it becomes an ordinary attacking side.
      final tamed = formationForRatio(0.70, 'regional_league');
      expect(tamed.attackRatio, lessThan(0.46));
    });

    test('the top flight floors at 5-3-2 rather than 5-4-1', () {
      expect(formationForRatio(0.10, 'champions_cup').id, '5-3-2');
      expect(formationForRatio(0.10, 'elite_league').id, '5-4-1');
    });

    test('a null share rolls a fresh shape', () {
      seeded.setSeed(5);
      final rolled = formationForRatio(null, 'regional_league');
      expect(aiFormations, contains(rolled));
    });
  });

  group('ensureFormation', () {
    test('keeps a valid formation and re-syncs its share', () {
      final t = _team('A', 60, formation: '3-4-3', attackRatio: 0.99);
      ensureFormation(t, 'regional_league');
      expect(t['formation'], '3-4-3');
      expect(t['attackRatio'], 0.457);
    });

    test('derives a shape from a legacy attackRatio', () {
      final t = _team('A', 60, attackRatio: 0.44);
      ensureFormation(t, 'regional_league');
      expect(t['formation'], '4-3-3');
      expect(t['attackRatio'], 0.430);
    });

    test('folds a legacy attackBias onto the same scale', () {
      // attackBias was a signed nudge around the base share, not a share.
      final t = _team('A', 60, attackBias: 1.0);
      ensureFormation(t, 'regional_league');
      expect(t['attackRatio'], isNot(0.402));
      expect(
        aiFormations.map((f) => f.attackRatio),
        contains(t['attackRatio']),
      );
    });

    test('an unrecognised formation is replaced, not kept', () {
      final t = _team('A', 60, formation: 'W-M', attackRatio: 0.402);
      ensureFormation(t, 'regional_league');
      expect(t['formation'], '4-4-2');
    });

    test('mutates in place and returns the same map', () {
      final t = _team('A', 60);
      expect(identical(ensureFormation(t, 'regional_league'), t), isTrue);
    });

    test('does NOT consume a seeded number when the shape is already valid', () {
      seeded.setSeed(99);
      final probe = seeded.random();

      seeded.setSeed(99);
      ensureFormation(_team('A', 60, formation: '4-4-2'), 'regional_league');
      expect(seeded.random(), probe);
    });
  });

  group('splitForTeam', () {
    test('reads a stored formation', () {
      final split = splitForTeam(60, _team('A', 60, formation: '3-4-3'));
      expect(split, opponentAtkDef(60, '3-4-3'));
    });

    test('falls back to a bare attack-share', () {
      final split = splitForTeam(60, _team('A', 60, attackRatio: 0.44));
      expect(split, opponentAtkDefFromShare(60, 0.44));
    });

    test('a corrupt formation string shadows a good attackRatio', () {
      // Faithful to the JS: the nullish chain picks the non-null formation, and
      // an unrecognised one then falls through to the BASE share rather than
      // back to the ratio sitting right beside it.
      final split = splitForTeam(
        60,
        _team('A', 60, formation: 'W-M', attackRatio: 0.348),
      );
      expect(split, opponentAtkDefFromShare(60, oppBaseAtkShare));
      expect(split, isNot(opponentAtkDefFromShare(60, 0.348)));
    });

    test('a missing club is the base share', () {
      expect(splitForTeam(60, null), opponentAtkDefFromShare(60, oppBaseAtkShare));
    });

    test('an attacking shape out-attacks a defensive one at equal rating', () {
      final open = splitForTeam(60, _team('A', 60, formation: '3-4-3'));
      final deep = splitForTeam(60, _team('B', 60, formation: '5-4-1'));
      expect(open.attack, greaterThan(deep.attack));
      expect(open.defence, lessThan(deep.defence));
    });
  });

  group('ensureLeaguePyramid — building fresh', () {
    test('fills every division to eight clubs', () {
      final state = _state();
      final pyramid = ensureLeaguePyramid(state);
      for (final div in divisions) {
        expect(_teams(pyramid, div.id).length, teamsPerLeague, reason: div.id);
      }
    });

    test('names are unique across the WHOLE pyramid, not just per league', () {
      final pyramid = ensureLeaguePyramid(_state());
      final all = [
        for (final div in divisions)
          for (final t in _teams(pyramid, div.id)) t['name'] as String,
      ];
      expect(all.toSet().length, all.length);
    });

    test('ratings land inside each division band', () {
      final pyramid = ensureLeaguePyramid(_state());
      for (final div in divisions) {
        final (lo, hi) = div.opponentRatingRange;
        for (final t in _teams(pyramid, div.id)) {
          expect(t['rating'], inInclusiveRange(lo, hi), reason: div.id);
        }
      }
    });

    test('every club gets a real formation with a matching share', () {
      final pyramid = ensureLeaguePyramid(_state());
      for (final div in divisions) {
        for (final t in _teams(pyramid, div.id)) {
          final f = aiFormations.firstWhere((f) => f.id == t['formation']);
          expect(t['attackRatio'], f.attackRatio);
        }
      }
    });

    test('the clubs are stored on the save', () {
      final state = _state();
      final pyramid = ensureLeaguePyramid(state);
      expect(state['progression']['leaguePyramid'], same(pyramid));
    });

    test('a club serialises to exactly the four fields the JS writes', () {
      final pyramid = ensureLeaguePyramid(_state());
      final first = _teams(pyramid, 'sunday_league').first;
      expect(first.keys.toList(), [
        'name',
        'rating',
        'formation',
        'attackRatio',
      ]);
      expect(() => jsonEncode(first), returnsNormally);
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(88);
      final a = jsonEncode(ensureLeaguePyramid(_state()));
      seeded.setSeed(88);
      final b = jsonEncode(ensureLeaguePyramid(_state()));
      expect(a, b);
    });
  });

  group('ensureLeaguePyramid — legacy carry-over', () {
    test("keeps a save's familiar rivals in the division they were played in", () {
      final state = _state(
        division: 'regional_league',
        seasonOpponents: [
          'Old Rival A',
          'Old Rival B',
          'Old Rival C',
          'Old Rival D',
          'Old Rival E',
          'Old Rival F',
          'Old Rival G',
        ],
        seasonOpponentRatings: {'s1_o0': 61, 's1_o3': 55},
      );
      final pyramid = ensureLeaguePyramid(state);
      final names = _teams(
        pyramid,
        'regional_league',
      ).map((t) => t['name']).toList();
      expect(names.take(7), [
        'Old Rival A',
        'Old Rival B',
        'Old Rival C',
        'Old Rival D',
        'Old Rival E',
        'Old Rival F',
        'Old Rival G',
      ]);
      expect(names.length, teamsPerLeague);
    });

    test('carries the stored ratings across, inventing only the gaps', () {
      final state = _state(
        seasonOpponents: List.generate(7, (i) => 'Rival $i'),
        seasonOpponentRatings: {'s1_o0': 61, 's1_o3': 55},
      );
      final teams = _teams(
        ensureLeaguePyramid(state),
        'regional_league',
      );
      expect(teams[0]['rating'], 61);
      expect(teams[3]['rating'], 55);
      final (lo, hi) = getDivision('regional_league').opponentRatingRange;
      expect(teams[1]['rating'], inInclusiveRange(lo, hi));
    });

    test('a short legacy list is ignored entirely', () {
      final state = _state(seasonOpponents: ['Only One', 'Only Two']);
      final names = _teams(
        ensureLeaguePyramid(state),
        'regional_league',
      ).map((t) => t['name']);
      expect(names, isNot(contains('Only One')));
    });

    test('legacy rivals arrive with real formations', () {
      final state = _state(seasonOpponents: List.generate(7, (i) => 'Rival $i'));
      for (final t in _teams(ensureLeaguePyramid(state), 'regional_league')) {
        expect(aiFormations.map((f) => f.id), contains(t['formation']));
      }
    });
  });

  group('ensureLeaguePyramid — repairing an existing pyramid', () {
    test('leaves a healthy pyramid alone', () {
      final pyramid = _fullPyramid();
      final before = jsonEncode(pyramid);
      ensureLeaguePyramid(_state(pyramid: pyramid));
      expect(jsonEncode(pyramid), before);
    });

    test('tops a short league back up to eight', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [_team('Survivor', 60, formation: '4-4-2', attackRatio: 0.402)],
      );
      ensureLeaguePyramid(_state(pyramid: pyramid));
      final teams = _teams(pyramid, 'regional_league');
      expect(teams.length, teamsPerLeague);
      expect(teams.first['name'], 'Survivor');
    });

    test('rebuilds a division that is missing outright', () {
      final pyramid = _fullPyramid()..remove('national_league');
      ensureLeaguePyramid(_state(pyramid: pyramid));
      expect(_teams(pyramid, 'national_league').length, teamsPerLeague);
    });

    test('rebuilds a division corrupted to a non-list', () {
      final pyramid = _fullPyramid();
      pyramid['elite_league'] = 'tampered';
      ensureLeaguePyramid(_state(pyramid: pyramid));
      expect(_teams(pyramid, 'elite_league').length, teamsPerLeague);
    });

    test('a topped-up name never collides with one already in the pyramid', () {
      final pyramid = _fullPyramid(tweakDiv: 'regional_league', tweakTeams: []);
      ensureLeaguePyramid(_state(pyramid: pyramid));
      final all = [
        for (final div in divisions)
          for (final t in _teams(pyramid, div.id)) t['name'] as String,
      ];
      expect(all.toSet().length, all.length);
    });

    test('migrates a legacy free attackRatio onto a real shape', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [
          for (var i = 0; i < teamsPerLeague; i++)
            _team('Cannon $i', 70, attackRatio: 0.70),
        ],
      );
      ensureLeaguePyramid(_state(pyramid: pyramid));
      for (final t in _teams(pyramid, 'regional_league')) {
        expect(t['formation'], '3-4-3');
        expect(t['attackRatio'], 0.457);
      }
    });

    test('topUp: false leaves a short league short', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [_team('Alone', 60, formation: '4-4-2', attackRatio: 0.402)],
      );
      ensureLeaguePyramid(_state(pyramid: pyramid), topUp: false);
      expect(_teams(pyramid, 'regional_league').length, 1);
    });

    test('topUp: false still repairs a broken formation', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [_team('Legacy', 60, attackRatio: 0.30)],
      );
      ensureLeaguePyramid(_state(pyramid: pyramid), topUp: false);
      expect(_teams(pyramid, 'regional_league').first['formation'], '5-4-1');
    });

    test('is idempotent — a second pass changes nothing', () {
      final state = _state();
      ensureLeaguePyramid(state);
      final once = jsonEncode(state['progression']['leaguePyramid']);
      ensureLeaguePyramid(state);
      expect(jsonEncode(state['progression']['leaguePyramid']), once);
    });
  });

  group('shufflePyramid', () {
    test('every league still holds eight clubs afterwards', () {
      final state = _state(pyramid: _fullPyramid());
      shufflePyramid(state);
      final pyramid = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      for (final div in divisions) {
        expect(_teams(pyramid, div.id).length, teamsPerLeague, reason: div.id);
      }
    });

    test('names stay unique across the pyramid', () {
      final state = _state(pyramid: _fullPyramid());
      shufflePyramid(state);
      final pyramid = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final all = [
        for (final div in divisions)
          for (final t in _teams(pyramid, div.id)) t['name'] as String,
      ];
      expect(all.toSet().length, all.length);
    });

    test('the strongest clubs go up and the weakest come down', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [
          _team('Runaway', 200, formation: '4-4-2', attackRatio: 0.402),
          _team('Chasing', 190, formation: '4-4-2', attackRatio: 0.402),
          for (var i = 2; i < 6; i++)
            _team('Middle $i', 100, formation: '4-4-2', attackRatio: 0.402),
          _team('Struggling', -100, formation: '4-4-2', attackRatio: 0.402),
          _team('Doomed', -200, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      final state = _state(pyramid: pyramid);
      shufflePyramid(state);
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final up = _teams(next, 'national_league').map((t) => t['name']);
      final down = _teams(next, 'amateur_cup').map((t) => t['name']);
      expect(up, containsAll(['Runaway', 'Chasing']));
      expect(down, containsAll(['Struggling', 'Doomed']));
    });

    test('a promoted club gains rating and a relegated one loses it', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [
          _team('Runaway', 200, formation: '4-4-2', attackRatio: 0.402),
          _team('Chasing', 190, formation: '4-4-2', attackRatio: 0.402),
          for (var i = 2; i < 8; i++)
            _team('Middle $i', 100, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      final state = _state(pyramid: pyramid);
      shufflePyramid(state);
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final promoted = _teams(
        next,
        'national_league',
      ).firstWhere((t) => t['name'] == 'Runaway');
      // Clamped into the destination band, which is the point — a 200-rated
      // side can't walk into the league above still rated 200.
      final (lo, hi) = getDivision('national_league').opponentRatingRange;
      expect(promoted['rating'], inInclusiveRange(lo - 4, hi + 4));
    });

    test('a club keeps its shape when it changes division', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [
          _team('Runaway', 200, formation: '3-4-3', attackRatio: 0.457),
          for (var i = 1; i < 8; i++)
            _team('Middle $i', 100, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      final state = _state(pyramid: pyramid);
      shufflePyramid(state);
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final moved = _teams(
        next,
        'national_league',
      ).firstWhere((t) => t['name'] == 'Runaway');
      expect(moved['formation'], '3-4-3');
      expect(moved['attackRatio'], 0.457);
    });

    test('skipDivId sends nobody OUT of that league', () {
      // It still RECEIVES, which is the whole design: the season-end pass has
      // already taken four clubs out of the player's division, and the two up
      // from below and two down from above are what refill it.
      final pyramid = _fullPyramid();
      final before = _teams(
        pyramid,
        'regional_league',
      ).map((t) => t['name'] as String).toSet();
      final state = _state(pyramid: pyramid);
      shufflePyramid(state, skipDivId: 'regional_league');
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final elsewhere = {
        for (final div in divisions)
          if (div.id != 'regional_league')
            for (final t in _teams(next, div.id)) t['name'] as String,
      };
      expect(before.intersection(elsewhere), isEmpty);
    });

    test('a full skipped league is trimmed back to eight after arrivals', () {
      final pyramid = _fullPyramid();
      final state = _state(pyramid: pyramid);
      shufflePyramid(state, skipDivId: 'regional_league');
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      expect(_teams(next, 'regional_league').length, teamsPerLeague);
    });

    test('recentlyMoved clubs are not moved a second time', () {
      // A club relegated by the season-end pass must not bounce straight back
      // up on the shuffle that follows it.
      final pyramid = _fullPyramid(
        tweakDiv: 'amateur_cup',
        tweakTeams: [
          _team('Just Dropped', 500, formation: '4-4-2', attackRatio: 0.402),
          for (var i = 1; i < 8; i++)
            _team('Amateur $i', 40, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      final state = _state(pyramid: pyramid);
      shufflePyramid(state, recentlyMoved: {'Just Dropped'});
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      expect(
        _teams(next, 'amateur_cup').map((t) => t['name']),
        contains('Just Dropped'),
      );
      expect(
        _teams(next, 'regional_league').map((t) => t['name']),
        isNot(contains('Just Dropped')),
      );
    });

    test('nothing promotes out of the top flight', () {
      final pyramid = _fullPyramid();
      final topNames = _teams(
        pyramid,
        'champions_cup',
      ).map((t) => t['name']).toSet();
      final state = _state(pyramid: pyramid);
      shufflePyramid(state);
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final elsewhere = [
        for (final div in divisions)
          if (div.id != 'champions_cup' && div.id != 'continental')
            for (final t in _teams(next, div.id)) t['name'],
      ];
      expect(topNames.intersection(elsewhere.toSet()), isEmpty);
    });

    test('nothing relegates out of the bottom league', () {
      final pyramid = _fullPyramid();
      final state = _state(pyramid: pyramid);
      shufflePyramid(state);
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      expect(_teams(next, 'sunday_league').length, teamsPerLeague);
    });

    test('records the badges each moved club carries into the new season', () {
      final statuses = <String, dynamic>{};
      final state = _state(pyramid: _fullPyramid());
      shufflePyramid(state, statuses: statuses);
      expect(statuses, isNotEmpty);
      for (final entry in statuses.values) {
        expect(
          (entry as Map)['status'],
          anyOf('promoted', 'relegated', 'champion'),
        );
        expect(divisions.map((d) => d.id), contains(entry['division']));
      }
    });

    test("a badge names the division the club moved INTO", () {
      final statuses = <String, dynamic>{};
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [
          _team('Runaway', 200, formation: '4-4-2', attackRatio: 0.402),
          for (var i = 1; i < 8; i++)
            _team('Middle $i', 100, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      shufflePyramid(_state(pyramid: pyramid), statuses: statuses);
      expect(statuses['Runaway'], {
        'status': 'promoted',
        'division': 'national_league',
      });
    });

    test('the top flight gets a champion badge and nobody else does', () {
      final statuses = <String, dynamic>{};
      shufflePyramid(_state(pyramid: _fullPyramid()), statuses: statuses);
      final champions = statuses.entries.where(
        (e) => (e.value as Map)['status'] == 'champion',
      );
      expect(champions.length, 1);
      expect((champions.first.value as Map)['division'], 'champions_cup');
    });

    test('records nothing when no status map is passed', () {
      // A bare shuffle is not a season end and must not badge anybody.
      final state = _state(pyramid: _fullPyramid());
      expect(() => shufflePyramid(state), returnsNormally);
      expect(state['progression'].containsKey('lastSeasonStatus'), isFalse);
    });

    test('does NOT pad the player division before the arrivals land', () {
      // The bug this guards: padding a just-emptied league with invented clubs
      // pushed it over eight, and the trim-by-rating then deleted the sides
      // that had actually earned promotion — a just-promoted club being the
      // weakest thing in its new league.
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [
          for (var i = 0; i < 4; i++)
            _team('Remaining $i', 60, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      final state = _state(pyramid: pyramid);
      shufflePyramid(state, skipDivId: 'regional_league');
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final names = _teams(next, 'regional_league').map((t) => t['name']).toList();
      expect(names.length, teamsPerLeague);
      // The four survivors are still there, plus the arrivals from either side.
      expect(names, containsAll(['Remaining 0', 'Remaining 3']));
    });

    test('a league with more than eight clubs is trimmed to the strongest', () {
      final pyramid = _fullPyramid(
        tweakDiv: 'regional_league',
        tweakTeams: [
          for (var i = 0; i < 12; i++)
            _team('Extra $i', 40 + i, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      final state = _state(pyramid: pyramid);
      shufflePyramid(state, skipDivId: 'regional_league');
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      final teams = _teams(next, 'regional_league');
      expect(teams.length, teamsPerLeague);
      // Extra 0 and Extra 1 are the weakest, so they are the ones cut.
      expect(teams.map((t) => t['name']), isNot(contains('Extra 0')));
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(2026);
      final a = _state(pyramid: _fullPyramid());
      shufflePyramid(a);
      seeded.setSeed(2026);
      final b = _state(pyramid: _fullPyramid());
      shufflePyramid(b);
      expect(
        jsonEncode(a['progression']['leaguePyramid']),
        jsonEncode(b['progression']['leaguePyramid']),
      );
    });

    test('the stored pyramid keys stay in ladder order', () {
      final state = _state(pyramid: _fullPyramid());
      shufflePyramid(state);
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      expect(next.keys.toList(), divisions.map((d) => d.id).toList());
    });

    test('survives ten seasons without the pyramid drifting', () {
      final state = _state(pyramid: _fullPyramid());
      for (var s = 0; s < 10; s++) {
        shufflePyramid(state);
      }
      final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
      for (final div in divisions) {
        expect(_teams(next, div.id).length, teamsPerLeague, reason: div.id);
        final (lo, hi) = div.opponentRatingRange;
        for (final t in _teams(next, div.id)) {
          expect(t['rating'], inInclusiveRange(lo - 4, hi + 4), reason: div.id);
        }
      }
    });

    test('a relegated club can claw its way back up over several seasons', () {
      // The whole point of a persistent pyramid: a 70-rated side dropping into
      // a 50s league is not gone, it is rebuilding.
      final pyramid = _fullPyramid(
        tweakDiv: 'amateur_cup',
        tweakTeams: [
          _team('Fallen Giant', 200, formation: '4-4-2', attackRatio: 0.402),
          for (var i = 1; i < 8; i++)
            _team('Amateur $i', 20, formation: '4-4-2', attackRatio: 0.402),
        ],
      );
      final state = _state(pyramid: pyramid);
      var climbed = false;
      for (var s = 0; s < 6 && !climbed; s++) {
        shufflePyramid(state);
        final next = state['progression']['leaguePyramid'] as Map<String, dynamic>;
        climbed = [
          for (final div in ['national_league', 'elite_league'])
            for (final t in _teams(next, div)) t['name'],
        ].contains('Fallen Giant');
      }
      expect(climbed, isTrue);
    });
  });
}
