import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The same realistic save the parity fixture ships — a full squad, a set XI,
/// a league four matches in.
Map<String, dynamic> _state({
  String? division,
  int? seasonMatchesPlayed,
  bool hardMode = false,
}) {
  final state = jsonDecode(jsonEncode(_ref['state'])) as Map<String, dynamic>;
  final prog = state['progression'] as Map<String, dynamic>;
  if (division != null) prog['currentDivision'] = division;
  if (seasonMatchesPlayed != null) {
    prog['seasonMatchesPlayed'] = seasonMatchesPlayed;
  }
  (state['settings'] as Map<String, dynamic>)['hardMode'] = hardMode;
  return state;
}

List<Map<String, dynamic>> _track(Map<String, dynamic> state, String scope) {
  final q = state['quests'] as Map<String, dynamic>;
  final raw = scope == 'season'
      ? q['season']
      : (q['match'] as Map<String, dynamic>)['active'];
  return [for (final c in raw as List) c as Map<String, dynamic>];
}

void main() {
  setUp(() {
    setClock(() => 1700000000000);
    seeded.setSeed(1234);
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('ensureQuests', () {
    test('builds the whole branch on a save that has none', () {
      final state = <String, dynamic>{};
      final q = ensureQuests(state);
      expect(q['season'], isEmpty);
      expect((q['match'] as Map)['active'], isEmpty);
      expect((q['match'] as Map)['fixtureKey'], isNull);
      expect(q['recent'], isEmpty);
      expect(q['lastRolledSeason'], 0);
      expect(q['seasonFreeRerollsUsed'], 0);
      expect(q['streaks'], {
        'cleanSheet': 0,
        'win': 0,
        'unbeaten': 0,
        'scoring': 0,
      });
      expect(state['gemGrants']['questDivisionFirsts'], isEmpty);
    });

    test('is idempotent', () {
      final state = _state();
      ensureQuests(state);
      final once = jsonEncode(state['quests']);
      ensureQuests(state);
      expect(jsonEncode(state['quests']), once);
    });

    test('converts the old boolean free-reroll flag rather than resetting it', () {
      // Resetting would hand a player mid-season back a free reroll they had
      // already spent.
      final state = _state();
      state['quests'] = <String, dynamic>{'seasonFreeRerollUsed': true};
      final q = ensureQuests(state);
      expect(q['seasonFreeRerollsUsed'], 1);
      expect(q.containsKey('seasonFreeRerollUsed'), isFalse);
      expect(freeRerollsLeft(state), freeRerollsPerSeason - 1);
    });

    test('an unspent old flag converts to zero used', () {
      final state = _state();
      state['quests'] = <String, dynamic>{'seasonFreeRerollUsed': false};
      expect(ensureQuests(state)['seasonFreeRerollsUsed'], 0);
    });

    test('a negative reroll count is repaired', () {
      final state = _state();
      state['quests'] = <String, dynamic>{'seasonFreeRerollsUsed': -3};
      expect(ensureQuests(state)['seasonFreeRerollsUsed'], 0);
    });

    test('drops a quest whose definition has left the bank', () {
      // The bank is data and it changes between releases; a save holding a
      // retired id used to render a row with no text, no reward and a fallback
      // icon. Better to lose the row than to show a broken one.
      final state = _state();
      state['quests'] = <String, dynamic>{
        'season': <dynamic>[
          <String, dynamic>{'id': 'season_wins', 'target': 6, 'progress': 0},
          <String, dynamic>{'id': 'season_retired_thing', 'target': 1},
        ],
        'match': <String, dynamic>{
          'fixtureKey': 'x',
          'active': <dynamic>[
            <String, dynamic>{'id': 'match_gone', 'target': 1},
          ],
        },
      };
      final q = ensureQuests(state);
      expect((q['season'] as List).length, 1);
      expect((q['match'] as Map)['active'], isEmpty);
    });

    test('rebuilds the season tally from what the fixtures can prove', () {
      // Only goals, clean sheets, wins and away wins are recorded; a comeback
      // or a hat-trick isn't in there, and merges and scouts are lifetime
      // totals — those start at zero on an upgraded save and are right again
      // from the next season.
      final state = _state(seasonMatchesPlayed: 3);
      (state['progression'] as Map<String, dynamic>)['fixtureResults'] = {
        's3_m0': {'homeGoals': 2, 'awayGoals': 0, 'won': true, 'isHome': true},
        's3_m1': {'homeGoals': 1, 'awayGoals': 1, 'won': false},
        's3_m2': {'homeGoals': 3, 'awayGoals': 0, 'won': true, 'isHome': false},
      };
      final q = ensureQuests(state);
      expect(q['seasonTally'], {
        QuestAction.goalsSeason: 6,
        QuestAction.cleanSheetsSeason: 2,
        QuestAction.matchWin: 2,
        QuestAction.awayWins: 1,
      });
    });

    test('the backfill only reads the matches actually played', () {
      // Keys are season-scoped but not RUN-scoped, so a prestige can leave a
      // previous run's results sitting above the mark.
      final state = _state(seasonMatchesPlayed: 1);
      (state['progression'] as Map<String, dynamic>)['fixtureResults'] = {
        's3_m0': {'homeGoals': 1, 'awayGoals': 0, 'won': true},
        's3_m9': {'homeGoals': 9, 'awayGoals': 0, 'won': true},
      };
      expect(
        (ensureQuests(state)['seasonTally'] as Map)[QuestAction.goalsSeason],
        1,
      );
    });

    test('an existing tally is left alone', () {
      final state = _state();
      state['quests'] = <String, dynamic>{
        'seasonTally': <String, dynamic>{QuestAction.goalsSeason: 42},
      };
      expect(
        (ensureQuests(state)['seasonTally'] as Map)[QuestAction.goalsSeason],
        42,
      );
    });
  });

  group('eligibleQuests', () {
    test('only offers what the division reaches', () {
      final sunday = eligibleQuests(_state(division: 'sunday_league'), 'match');
      expect(sunday.map((q) => q.id), isNot(contains('match_gk_scores')));
      final champions = eligibleQuests(_state(division: 'champions_cup'), 'match');
      expect(champions.map((q) => q.id), contains('match_gk_scores'));
    });

    test('Pro mode drops the coach quest', () {
      // There are no tactic suggestions there, so it would be undefeatable
      // rather than merely hard.
      final casual = eligibleQuests(_state(division: 'elite_league'), 'match');
      expect(casual.map((q) => q.id), contains('match_defy_coach'));
      final pro = eligibleQuests(
        _state(division: 'elite_league', hardMode: true),
        'match',
      );
      expect(pro.map((q) => q.id), isNot(contains('match_defy_coach')));
    });

    test('a scope never leaks into the other', () {
      for (final scope in ['match', 'season']) {
        for (final q in eligibleQuests(_state(), scope)) {
          expect(q.scope, scope);
        }
      }
    });
  });

  group('rollQuests', () {
    test('fills the track with distinct quests', () {
      final state = _state();
      final rolled = rollQuests(state, 'match', 3);
      expect(rolled.length, 3);
      expect(rolled.map((c) => c['id']).toSet().length, 3);
    });

    test('never two quests from the same FAMILY', () {
      // "Keep a clean sheet", "shut out a stronger attack" and "win away
      // without conceding" are three actions and one objective.
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        for (final scope in ['match', 'season']) {
          final rolled = rollQuests(_state(), scope, 3);
          final seen = <String>{};
          for (final inst in rolled) {
            final tags = questTags(getQuest(inst['id'] as String));
            expect(
              tags.any(seen.contains),
              isFalse,
              reason: 'seed $seed $scope ${inst['id']}',
            );
            seen.addAll(tags);
          }
        }
      }
    });

    test('holds recently-used quests back', () {
      final state = _state();
      final first = rollQuests(state, 'match', 3);
      final second = rollQuests(state, 'match', 3);
      expect(
        second.map((c) => c['id']).toSet().intersection(
              first.map((c) => c['id']).toSet(),
            ),
        isEmpty,
      );
    });

    test('the no-repeat window is capped at its size', () {
      final state = _state();
      for (var i = 0; i < 10; i++) {
        rollQuests(state, 'match', 3);
      }
      expect(
        (state['quests']['recent'] as List).length,
        lessThanOrEqualTo(noRepeatWindow),
      );
    });

    test('one ask per roll OUTRANKS the no-repeat window', () {
      // A quest the player saw two fixtures ago is invisible; two "score N
      // goals" side by side is not. Sunday League is the case that forced it —
      // few enough eligible quests that the window alone could starve the roll
      // into a duplicate family.
      final state = _state(division: 'sunday_league');
      for (var i = 0; i < 12; i++) {
        final rolled = rollQuests(state, 'match', 3);
        final seen = <String>{};
        for (final inst in rolled) {
          final tags = questTags(getQuest(inst['id'] as String));
          expect(tags.any(seen.contains), isFalse, reason: 'pass $i');
          seen.addAll(tags);
        }
      }
    });

    test('respects the excluded ids and their families', () {
      final state = _state();
      final rolled = rollQuests(state, 'match', 2, ['match_clean_sheet']);
      for (final inst in rolled) {
        expect(inst['id'], isNot('match_clean_sheet'));
        expect(
          questTags(getQuest(inst['id'] as String)),
          isNot(contains(QuestTag.shutout)),
        );
      }
    });

    test('an empty pool returns nothing rather than throwing', () {
      final state = _state();
      expect(rollQuests(state, 'not_a_scope', 3), isEmpty);
    });

    test('a season instance starts from what the season has already done', () {
      // Rolling one at match 10 used to hand over a fourteen-match objective
      // with four matches to do it in.
      final state = _state(seasonMatchesPlayed: 10);
      ensureQuests(state);
      state['quests']['seasonTally'] = <String, dynamic>{
        QuestAction.goalsSeason: 34,
      };
      final rolled = rollQuests(state, 'season', 3);
      final goals = rolled.where((c) => c['id'] == 'season_goals');
      if (goals.isNotEmpty) expect(goals.first['progress'], 34);
    });

    test('a streak instance starts from the live run, not the season total', () {
      // Five wins in a ROW is not the same as five wins.
      final state = _state();
      ensureQuests(state);
      state['quests']['streaks'] = <String, dynamic>{
        'cleanSheet': 0,
        'win': 2,
        'unbeaten': 4,
        'scoring': 0,
      };
      state['quests']['seasonTally'] = <String, dynamic>{
        QuestAction.matchWin: 9,
      };
      final def = getQuest('season_win_run')!;
      expect(seasonProgressSoFar(def, state), 2);
    });
  });

  group('rollMatchQuests', () {
    test('the same fixture gets the same three back', () {
      // A re-render or a screen remount must not silently redraw them under
      // the player.
      final state = _state();
      final first = rollMatchQuests(state, 's3_m4');
      expect(rollMatchQuests(state, 's3_m4'), first);
    });

    test('a new fixture rolls a fresh three', () {
      final state = _state();
      final first = rollMatchQuests(state, 's3_m4').map((c) => c['id']).toList();
      final second = rollMatchQuests(state, 's3_m5').map((c) => c['id']).toList();
      expect(second, isNot(first));
    });

    test('a short track is topped up rather than redrawn', () {
      final state = _state();
      final first = rollMatchQuests(state, 's3_m4');
      final kept = first.first['id'];
      state['quests']['match']['active'] = [first.first];
      final topped = rollMatchQuests(state, 's3_m4');
      expect(topped.length, matchQuestCount);
      expect(topped.first['id'], kept);
    });

    test('announces the roll', () {
      Object? announced;
      on('quests:rolled', (v) => announced = v);
      rollMatchQuests(_state(), 's3_m4');
      expect((announced as Map)['scope'], 'match');
    });
  });

  group('rollSeasonQuests', () {
    test('does not re-roll mid-season, which would wipe progress', () {
      final state = _state();
      final first = rollSeasonQuests(state, 3);
      expect(rollSeasonQuests(state, 3), first);
    });

    test('a new season redraws', () {
      final state = _state();
      final first = rollSeasonQuests(state, 3).map((c) => c['id']).toList();
      final second = rollSeasonQuests(state, 4).map((c) => c['id']).toList();
      expect(second, isNot(first));
    });

    test('clears the tally and the streaks BEFORE the draw', () {
      // Otherwise the new campaign's quests arrive pre-loaded with the last
      // one's goals, and a run carries over a summer.
      final state = _state();
      ensureQuests(state);
      state['quests']['seasonTally'] = <String, dynamic>{
        QuestAction.goalsSeason: 40,
      };
      state['quests']['streaks'] = <String, dynamic>{
        'cleanSheet': 3,
        'win': 3,
        'unbeaten': 5,
        'scoring': 6,
      };
      rollSeasonQuests(state, 4);
      expect(state['quests']['seasonTally'], isEmpty);
      expect(state['quests']['streaks'], {
        'cleanSheet': 0,
        'win': 0,
        'unbeaten': 0,
        'scoring': 0,
      });
      for (final inst in _track(state, 'season')) {
        expect(inst['progress'], 0, reason: '${inst['id']}');
      }
    });

    test('refreshes the free rerolls', () {
      final state = _state();
      rollSeasonQuests(state, 3);
      rerollQuests(state);
      expect(freeRerollsLeft(state), lessThan(freeRerollsPerSeason));
      rollSeasonQuests(state, 4);
      expect(freeRerollsLeft(state), freeRerollsPerSeason);
    });

    test('snapshots a baseline for EVERY delta quest, not just the three drawn', () {
      // The point of the snapshot is to be there for a quest rolled later in
      // the season, which by definition isn't on the track yet.
      final state = _state();
      rollSeasonQuests(state, 4);
      final baselines = state['quests']['seasonBaselines'] as Map;
      final deltaQuests = questBank.where(
        (q) => q.scope == 'season' && q.progress != null && q.baseline,
      );
      expect(deltaQuests, isNotEmpty);
      for (final q in deltaQuests) {
        expect(baselines.containsKey(q.id), isTrue, reason: q.id);
      }
    });

    test('sweeps an unclaimed quest on the way out', () {
      final state = _state();
      rollSeasonQuests(state, 3);
      final inst = _track(state, 'season').first;
      inst['completed'] = true;
      inst['progress'] = inst['target'];
      final before = state['resources']['fanCoins'] as num;
      rollSeasonQuests(state, 4);
      expect(state['resources']['fanCoins'], greaterThan(before));
    });

    test('a short track is topped up rather than redrawn', () {
      final state = _state();
      final first = rollSeasonQuests(state, 3);
      state['quests']['season'] = [first.first];
      final topped = rollSeasonQuests(state, 3);
      expect(topped.length, seasonQuestCount);
      expect(topped.first['id'], first.first['id']);
    });
  });

  group('advanceQuest', () {
    Map<String, dynamic> tracked(String questId) {
      final state = _state();
      ensureQuests(state);
      final def = getQuest(questId)!;
      state['quests']['season'] = <dynamic>[
        <String, dynamic>{
          'id': questId,
          'target': resolveTarget(def, 2),
          'progress': 0,
          'completed': false,
          'claimedAt': null,
          'baseline': 0,
        },
      ];
      return state;
    }

    test('advances a matching quest and stops at the target', () {
      final state = tracked('season_merge');
      final target = _track(state, 'season').first['target'] as int;
      advanceQuest(state, QuestAction.mergeCount, target + 10);
      final inst = _track(state, 'season').first;
      expect(inst['progress'], target);
      expect(inst['completed'], isTrue);
    });

    test('keeps the season tally whether or not a quest is watching', () {
      // That is the point of it: a quest rolled at match 10 needs to know what
      // the first nine did, and by definition it wasn't on the track.
      final state = _state();
      ensureQuests(state);
      advanceQuest(state, QuestAction.scoutCount, 7);
      expect(
        (state['quests']['seasonTally'] as Map)[QuestAction.scoutCount],
        7,
      );
    });

    test('a MAX action takes the highest seen, never a sum', () {
      // Merging three tier-3 cards would otherwise read as "tier 9".
      final state = tracked('season_reach_tier');
      advanceQuest(state, QuestAction.reachTier, 3);
      advanceQuest(state, QuestAction.reachTier, 2);
      expect(_track(state, 'season').first['progress'], 3);
      expect(
        (state['quests']['seasonTally'] as Map)[QuestAction.reachTier],
        3,
      );
    });

    test('a streak action is ignored here — a run is not a total', () {
      final state = _state();
      ensureQuests(state);
      advanceQuest(state, QuestAction.winRun, 5);
      expect(
        (state['quests']['seasonTally'] as Map).containsKey(QuestAction.winRun),
        isFalse,
      );
    });

    test('a completed quest stops counting', () {
      final state = tracked('season_merge');
      final target = _track(state, 'season').first['target'] as int;
      advanceQuest(state, QuestAction.mergeCount, target);
      advanceQuest(state, QuestAction.mergeCount, 5);
      expect(_track(state, 'season').first['progress'], target);
    });

    test('announces a completion once', () {
      final state = tracked('season_merge');
      var completions = 0;
      on('quest:completed', (_) => completions++);
      final target = _track(state, 'season').first['target'] as int;
      advanceQuest(state, QuestAction.mergeCount, target);
      advanceQuest(state, QuestAction.mergeCount, target);
      expect(completions, 1);
    });
  });

  group('setStreakProgress', () {
    Map<String, dynamic> withRun() {
      final state = _state();
      ensureQuests(state);
      state['quests']['season'] = <dynamic>[
        <String, dynamic>{
          'id': 'season_win_run',
          'target': 4,
          'progress': 0,
          'completed': false,
          'claimedAt': null,
          'baseline': 0,
        },
      ];
      return state;
    }

    test('tracks the current run up and back down', () {
      final state = withRun();
      setStreakProgress(state, QuestAction.winRun, 3);
      expect(_track(state, 'season').first['progress'], 3);
      setStreakProgress(state, QuestAction.winRun, 0);
      expect(_track(state, 'season').first['progress'], 0);
    });

    test('a completed streak stays completed when the run breaks', () {
      // Losing a match must not retract a reward the player has earned, and
      // possibly already claimed.
      final state = withRun();
      setStreakProgress(state, QuestAction.winRun, 4);
      expect(_track(state, 'season').first['completed'], isTrue);
      setStreakProgress(state, QuestAction.winRun, 0);
      final inst = _track(state, 'season').first;
      expect(inst['completed'], isTrue);
      expect(inst['progress'], 4);
    });

    test('a negative run floors at zero', () {
      final state = withRun();
      setStreakProgress(state, QuestAction.winRun, -3);
      expect(_track(state, 'season').first['progress'], 0);
    });
  });

  group('refreshDerivedQuests', () {
    Map<String, dynamic> derived(String questId, {num baseline = 0}) {
      final state = _state();
      ensureQuests(state);
      final def = getQuest(questId)!;
      state['quests']['season'] = <dynamic>[
        <String, dynamic>{
          'id': questId,
          'target': resolveTarget(def, 2),
          'progress': 0,
          'completed': false,
          'claimedAt': null,
          'baseline': baseline,
        },
      ];
      return state;
    }

    test('reads the save', () {
      final state = derived('season_rename');
      (state['grid']['cells'] as List)[0]['customName'] = 'Bomber';
      refreshDerivedQuests(state);
      expect(_track(state, 'season').first['completed'], isTrue);
    });

    test('a delta quest measures from its baseline', () {
      final state = derived('season_minigames', baseline: 5);
      (state['stats'] as Map<String, dynamic>)['penaltyRounds'] = 7;
      refreshDerivedQuests(state);
      expect(_track(state, 'season').first['progress'], 2);
    });

    test('completion is STICKY when the value falls back', () {
      // Selling the sponsored player must not retract a finished quest.
      final state = derived('season_rename');
      (state['grid']['cells'] as List)[0]['customName'] = 'Bomber';
      refreshDerivedQuests(state);
      (state['grid']['cells'] as List)[0].remove('customName');
      refreshDerivedQuests(state);
      expect(_track(state, 'season').first['completed'], isTrue);
    });

    test('every tracked action keeps the derived quests honest', () {
      // The cheapest place to do it: they have no call site of their own.
      final state = derived('season_rename');
      (state['grid']['cells'] as List)[0]['customName'] = 'Bomber';
      advanceQuest(state, QuestAction.scoutCount);
      expect(_track(state, 'season').first['completed'], isTrue);
    });
  });

  group('questTarget', () {
    test('a LEVEL quest asks for one above what the club already holds', () {
      // Owning tier 3 and being asked to reach tier 3 is a quest that was
      // finished before it was handed out.
      final state = _state();
      final def = getQuest('season_asset_tier')!;
      (state['clubAssets'] as Map<String, dynamic>)['TRAINING'] = {
        'owned': true,
        'tier': 5,
      };
      expect(questTarget(def, state, 0), 6);
    });

    test('and never past the ceiling the level can reach', () {
      final state = _state();
      final def = getQuest('season_asset_tier')!;
      (state['clubAssets'] as Map<String, dynamic>)['TRAINING'] = {
        'owned': true,
        'tier': 8,
      };
      expect(questTarget(def, state, 6), 8);
    });

    test('an ordinary quest just takes the division target', () {
      final def = getQuest('season_wins')!;
      expect(questTarget(def, _state(), 3), resolveTarget(def, 3));
    });
  });

  group('fitsInSeason', () {
    test('a once-per-match ask needs one match each', () {
      final def = getQuest('season_wins')!;
      expect(fitsInSeason(def, 6, 0, 6), isTrue);
      expect(fitsInSeason(def, 6, 0, 5), isFalse);
      expect(fitsInSeason(def, 6, 2, 4), isTrue);
    });

    test('an already-cleared ask always fits', () {
      final def = getQuest('season_wins')!;
      expect(fitsInSeason(def, 6, 6, 0), isTrue);
    });

    test('goals are measured against the fastest rate the sim can run', () {
      // The sampler is Poisson and has no hard ceiling on one scoreline, so an
      // exact per-match bound would be wrong in both directions.
      final def = getQuest('season_goals')!;
      expect(fitsInSeason(def, 10, 0, 4), isTrue);
      expect(fitsInSeason(def, 400, 0, 4), isFalse);
    });

    test('anything not paced by the fixture list is never blocked', () {
      // Merges and scouts are bounded by cards and energy; a player can do
      // sixty of either in one sitting.
      final def = getQuest('season_merge')!;
      expect(fitsInSeason(def, 999, 0, 0), isTrue);
    });

    test('a match quest is never blocked', () {
      expect(fitsInSeason(getQuest('match_clean_sheet'), 1, 0, 0), isTrue);
    });

    test('an unknown number of matches left is not a reason to refuse', () {
      expect(fitsInSeason(getQuest('season_wins'), 99, 0, null), isTrue);
    });

    test('the roll refuses an arithmetically dead quest late in a season', () {
      // Six more wins with four to play isn't hard, it's impossible.
      final state = _state(seasonMatchesPlayed: 13);
      ensureQuests(state);
      final ids = rollableQuests(state, 'season').map((d) => d.id);
      for (final id in ids) {
        final def = getQuest(id)!;
        expect(
          fitsInSeason(
            def,
            questTarget(def, state, 2),
            seasonProgressSoFar(def, state),
            1,
          ),
          isTrue,
          reason: id,
        );
      }
    });
  });

  group('rollableQuests', () {
    test('never hands out a quest the save already satisfies', () {
      // A quest that is already finished isn't a quest, it's a payout.
      final state = _state();
      ensureQuests(state);
      final divIdx = divisionIndex('regional_league');
      for (final def in rollableQuests(state, 'season')) {
        expect(
          seasonProgressSoFar(def, state) < questTarget(def, state, divIdx),
          isTrue,
          reason: def.id,
        );
      }
    });

    test('drops an away quest in a home fixture', () {
      final state = _state();
      final ctx = questContext(state);
      final ids = rollableQuests(state, 'match', ctx).map((d) => d.id);
      if (ctx.quest.isHome == true) {
        expect(ids, isNot(contains('match_away_win')));
      } else {
        expect(ids, contains('match_away_win'));
      }
    });

    test('drops a substitution quest for a squad with no bench', () {
      final state = _state();
      // Cut the squad to exactly the eleven in the XI.
      final cells = state['grid']['cells'] as List;
      final lineupIds = {
        for (final s in state['squad']['lineup'] as List) s['cardInstanceId'],
      };
      state['grid']['cells'] = [
        for (final c in cells)
          if (c != null && lineupIds.contains(c['instanceId'])) c,
      ];
      final ids = rollableQuests(state, 'match').map((d) => d.id);
      expect(ids, isNot(contains('match_use_subs')));
      expect(ids, isNot(contains('match_sub_scores')));
    });

    test('drops an arcade quest whose game the Training tier has not opened', () {
      final state = _state();
      (state['clubAssets'] as Map<String, dynamic>)['TRAINING'] = {
        'owned': false,
        'tier': 0,
      };
      final ids = rollableQuests(state, 'season').map((d) => d.id);
      expect(ids, isNot(contains('season_boot_room')));
      expect(ids, isNot(contains('season_pairs')));
      // Penalty Training needs no facility.
      expect(ids, contains('season_minigames'));
    });

    test('a feasibility check that throws is treated as infeasible', () {
      // A predicate that can't be evaluated is not a licence to hand out a
      // quest that might be impossible. Nothing in the bank throws, so this
      // asserts the contract through a context with no fixture at all.
      final state = _state();
      state['progression'] = <String, dynamic>{
        'currentDivision': 'regional_league',
        'seasonCount': 1,
        'seasonMatchesPlayed': 0,
      };
      final ids = rollableQuests(state, 'match').map((d) => d.id);
      // With no opponent rating rolled, the underdog quests hold back.
      expect(ids, isNot(contains('match_underdog_win')));
    });
  });

  group('the reward', () {
    test('scales with the division', () {
      // The bank's number is a percentage of one league win, never a literal:
      // the base spans 100 to 120,000.
      expect(
        questRewardCoins(_state(division: 'champions_cup'), 25),
        greaterThan(questRewardCoins(_state(division: 'sunday_league'), 25)),
      );
    });

    test('is a quarter of a win at 25, at every division', () {
      for (final div in divisions) {
        expect(
          questRewardCoins(_state(division: div.id), 100),
          div.matchRevenueBase,
          reason: div.id,
        );
      }
    });

    test('never rounds a real reward away to nothing', () {
      expect(questRewardCoins(_state(division: 'sunday_league'), 1), 1);
    });

    test('no multiplier pays nothing', () {
      expect(questRewardCoins(_state(), 0), 0);
      expect(questRewardCoins(_state(), null), 0);
    });
  });

  group('claiming', () {
    Map<String, dynamic> readyToClaim() {
      final state = _state();
      rollSeasonQuests(state, 3);
      final inst = _track(state, 'season').first;
      inst['completed'] = true;
      inst['progress'] = inst['target'];
      return state;
    }

    test('pays out and stamps the claim', () {
      final state = readyToClaim();
      final id = _track(state, 'season').first['id'] as String;
      final result = claimQuest(state, id);
      expect(result.ok, isTrue);
      expect(result.granted!.coins, greaterThan(0));
      expect(_track(state, 'season').first['claimedAt'], isNotNull);
    });

    test('a second claim is refused and pays nothing', () {
      final state = readyToClaim();
      final id = _track(state, 'season').first['id'] as String;
      claimQuest(state, id);
      final before = state['resources']['fanCoins'];
      final second = claimQuest(state, id);
      expect(second.ok, isFalse);
      expect(second.reason, 'already_claimed');
      expect(state['resources']['fanCoins'], before);
    });

    test('an incomplete quest cannot be claimed', () {
      final state = _state();
      rollSeasonQuests(state, 3);
      final id = _track(state, 'season').first['id'] as String;
      expect(claimQuest(state, id).reason, 'not_complete');
    });

    test('an unknown quest is refused', () {
      expect(claimQuest(_state(), 'nope').reason, 'unknown_quest');
    });

    test('the badge counts what is waiting', () {
      final state = readyToClaim();
      expect(unclaimedCount(state), 1);
      claimQuest(state, _track(state, 'season').first['id'] as String);
      expect(unclaimedCount(state), 0);
    });
  });

  group('sweeping', () {
    test('nobody loses coins for not tapping a button', () {
      // The claim is there as a reason to come back, not as a deadline.
      final state = _state();
      rollSeasonQuests(state, 3);
      for (final inst in _track(state, 'season')) {
        inst['completed'] = true;
        inst['progress'] = inst['target'];
      }
      final swept = sweepUnclaimedSeasonQuests(state);
      expect(swept.count, seasonQuestCount);
      expect(swept.coins, greaterThan(0));
      expect(state['resources']['fanCoins'], swept.coins);
    });

    test('an already-claimed quest is not paid twice', () {
      final state = _state();
      rollSeasonQuests(state, 3);
      final inst = _track(state, 'season').first;
      inst['completed'] = true;
      inst['claimedAt'] = now();
      expect(sweepUnclaimedSeasonQuests(state).count, 0);
    });

    test('is idempotent', () {
      final state = _state();
      rollSeasonQuests(state, 3);
      for (final inst in _track(state, 'season')) {
        inst['completed'] = true;
      }
      sweepUnclaimedSeasonQuests(state);
      expect(sweepUnclaimedSeasonQuests(state).count, 0);
    });

    test('does NOT settle the capstone', () {
      // That is credited to a specific division, and the season end changes the
      // division on promotion BEFORE the new quests roll — so the caller runs
      // the check itself, while the division is still the one that was played.
      final state = _state();
      rollSeasonQuests(state, 3);
      for (final inst in _track(state, 'season')) {
        inst['completed'] = true;
      }
      final gemsBefore = state['resources']['gems'];
      sweepUnclaimedSeasonQuests(state);
      expect(state['resources']['gems'], gemsBefore);
    });
  });

  group('the division capstone', () {
    Map<String, dynamic> cleared({String division = 'regional_league'}) {
      final state = _state(division: division);
      rollSeasonQuests(state, 3);
      for (final inst in _track(state, 'season')) {
        inst['completed'] = true;
        inst['claimedAt'] = now();
      }
      return state;
    }

    test('pays one gem for clearing a division', () {
      final state = cleared();
      final before = state['resources']['gems'] as num;
      expect(checkDivisionCapstone(state)?.gems, capstoneGems);
      expect(state['resources']['gems'], before + capstoneGems);
    });

    test('and never a second time for the same division', () {
      final state = cleared();
      checkDivisionCapstone(state);
      final after = state['resources']['gems'];
      expect(checkDivisionCapstone(state), isNull);
      expect(state['resources']['gems'], after);
    });

    test('a different division still pays', () {
      final state = cleared();
      checkDivisionCapstone(state);
      state['progression']['currentDivision'] = 'national_league';
      expect(checkDivisionCapstone(state)?.divisionId, 'national_league');
    });

    test('an unclaimed quest is not a cleared division', () {
      final state = cleared();
      _track(state, 'season').first['claimedAt'] = null;
      expect(checkDivisionCapstone(state), isNull);
    });

    test('an empty track is not a cleared division', () {
      final state = _state();
      ensureQuests(state);
      expect(checkDivisionCapstone(state), isNull);
    });

    test('the whole ladder is worth seven gems, ever', () {
      // Cosmetics are safe to farm, but the gem sinks are power items — a
      // renewable faucet would be a renewable pipeline into squad strength.
      final state = _state();
      var total = 0;
      for (final div in divisions) {
        state['progression']['currentDivision'] = div.id;
        state['quests'] = <String, dynamic>{};
        rollSeasonQuests(state, divisions.indexOf(div) + 10);
        for (final inst in _track(state, 'season')) {
          inst['completed'] = true;
          inst['claimedAt'] = now();
        }
        total += checkDivisionCapstone(state)?.gems ?? 0;
      }
      expect(total, divisions.length * capstoneGems);
      expect(total, 7);
    });

    test('the ledger survives where a per-run flag would not', () {
      final state = cleared();
      checkDivisionCapstone(state);
      expect(state['gemGrants']['questDivisionFirsts'], ['regional_league']);
    });
  });

  group('rerolling', () {
    test('refuses when there is nothing unfinished to swap', () {
      // Charging for that would be theft.
      final state = _state();
      rollSeasonQuests(state, 3);
      for (final inst in _track(state, 'season')) {
        inst['completed'] = true;
      }
      expect(canReroll(state), isFalse);
      expect(rerollQuests(state).reason, 'nothing_to_reroll');
    });

    test('never swaps a COMPLETED quest', () {
      // It is holding an unclaimed reward, and swapping it out would destroy
      // coins the player has already earned.
      final state = _state();
      rollSeasonQuests(state, 3);
      final keeper = _track(state, 'season').first;
      keeper['completed'] = true;
      final keptId = keeper['id'];
      rerollQuests(state);
      expect(
        _track(state, 'season').map((c) => c['id']),
        contains(keptId),
      );
    });

    test('always visibly changes something', () {
      // **SOMETHING, which is what the name says.** This asserted that EVERY
      // slot changed, and that was luck rather than a rule: the replacements
      // are drawn from the eligible pool and nothing stops one of them landing
      // on a quest that is already on the track. Adding one quest to the bank
      // moved the seeded draw and a repeat appeared — the parity harness agrees
      // with the JS on the same reroll, so the behaviour is right and the
      // expectation was over-tight.
      //
      // What a player must never see is a reroll they paid for that changed
      // nothing, and that is the assertion.
      final state = _state();
      rollSeasonQuests(state, 3);
      final before = _track(state, 'season').map((c) => c['id']).toList();
      final result = rerollQuests(state);
      expect(result.ok, isTrue);
      final after = _track(state, 'season').map((c) => c['id']).toList();
      expect(after, isNot(before));
    });

    test('the replacements keep the one-ask-per-roll rule', () {
      for (var seed = 0; seed < 25; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        rollSeasonQuests(state, 3);
        rerollQuests(state);
        final seen = <String>{};
        for (final inst in _track(state, 'season')) {
          final tags = questTags(getQuest(inst['id'] as String));
          expect(tags.any(seen.contains), isFalse, reason: 'seed $seed');
          seen.addAll(tags);
        }
      }
    });

    test('refuses when the wallet cannot cover it', () {
      final state = _state();
      state['resources']['gems'] = 0;
      rollSeasonQuests(state, 3);
      rerollQuests(state);
      rerollQuests(state);
      expect(canReroll(state), isFalse);
      expect(rerollQuests(state).reason, 'not_enough_gems');
    });

    test('a refused reroll takes nothing', () {
      final state = _state();
      state['resources']['gems'] = 0;
      rollSeasonQuests(state, 3);
      rerollQuests(state);
      rerollQuests(state);
      final before = _track(state, 'season').map((c) => c['id']).toList();
      rerollQuests(state);
      expect(_track(state, 'season').map((c) => c['id']), before);
      expect(state['resources']['gems'], 0);
    });

    test('a replacement is never already finished', () {
      // The player has just spent a gem on it.
      for (var seed = 0; seed < 25; seed++) {
        seeded.setSeed(seed);
        final state = _state();
        rollSeasonQuests(state, 3);
        rerollQuests(state);
        for (final inst in _track(state, 'season')) {
          expect(inst['completed'], isFalse, reason: 'seed $seed ${inst['id']}');
        }
      }
    });
  });
}
