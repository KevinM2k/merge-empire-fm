import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/quests.dart';

Map<String, dynamic> get _ref =>
    jsonDecode(File('test/fixtures/quest_bank_reference.json').readAsStringSync())
        as Map<String, dynamic>;

QuestContext _ctx({
  bool? isHome,
  num? oppRating,
  num ourRating = 60,
  num? oppAttack,
  num ourDefence = 60,
  bool defInLineup = true,
  bool midInLineup = true,
  bool hasGK = true,
  int oldestSeasons = 0,
  int fitCount = 11,
  int undiscovered = 20,
  List<String> minigames = const [],
  int benchCount = 5,
}) => (
  isHome: isHome,
  oppRating: oppRating,
  ourRating: ourRating,
  oppAttack: oppAttack,
  ourDefence: ourDefence,
  defInLineup: defInLineup,
  midInLineup: midInLineup,
  hasGK: hasGK,
  oldestSeasons: oldestSeasons,
  fitCount: fitCount,
  undiscovered: undiscovered,
  minigames: minigames,
  benchCount: benchCount,
);

void main() {
  group('parity with the JS bank', () {
    test('holds exactly the same quests, in the same order', () {
      final expected = (_ref['quests'] as List).cast<Map<String, dynamic>>();
      expect(questBank.map((q) => q.id), expected.map((q) => q['id']));
    });

    test('every field on every quest matches', () {
      // One mistyped tag welds two families together and a whole slot on the
      // track quietly disappears, so this checks all of them rather than a
      // sample.
      final expected = (_ref['quests'] as List).cast<Map<String, dynamic>>();
      for (final want in expected) {
        final q = getQuest(want['id'] as String);
        expect(q, isNotNull, reason: '${want['id']}');
        final id = q!.id;
        expect(q.scope, want['scope'], reason: id);
        expect(q.action, want['action'], reason: id);
        expect(q.minDiv, want['minDiv'], reason: id);
        expect(q.maxDiv, want['maxDiv'], reason: id);
        expect(q.tags, want['tags'], reason: id);
        expect(questTags(q), want['familySlots'], reason: id);
        expect(q.reward.coins, want['coins'], reason: id);
        expect(q.icon, want['icon'], reason: id);
        expect(q.strategy, want['strategy'], reason: id);
        expect(q.baseline, want['baseline'], reason: id);
        expect(q.lift, want['lift'], reason: id);
        expect(isDerived(q), want['derived'], reason: id);
        expect(q.feasible != null, want['hasFeasible'], reason: id);
      }
    });

    test('every target curve produces the same numbers at every division', () {
      // Evaluated rather than described — a curve is far easier to mistranscribe
      // than to check.
      final expected = (_ref['quests'] as List).cast<Map<String, dynamic>>();
      for (final want in expected) {
        final q = getQuest(want['id'] as String)!;
        final targets = [
          for (var d = 0; d < divisions.length; d++) resolveTarget(q, d),
        ];
        expect(targets, want['targets'], reason: q.id);
      }
    });

    test('eligibility matches at every division', () {
      final expected = (_ref['quests'] as List).cast<Map<String, dynamic>>();
      for (final want in expected) {
        final q = getQuest(want['id'] as String)!;
        final eligible = [
          for (var d = 0; d < divisions.length; d++) isEligible(q, d),
        ];
        expect(eligible, want['eligible'], reason: q.id);
      }
    });

    test('the action and tag vocabularies match', () {
      final actions = (_ref['actions'] as Map<String, dynamic>).values.toSet();
      final tags = (_ref['tags'] as Map<String, dynamic>).values.toSet();
      // Every string the JS knows is one this port knows, and nothing in the
      // bank uses a string outside them.
      for (final q in questBank) {
        expect(actions, contains(q.action), reason: q.id);
        for (final tag in q.tags) {
          expect(tags, contains(tag), reason: '${q.id}/$tag');
        }
      }
    });

    test('the action sets match', () {
      expect(perMatchActions, (_ref['perMatchActions'] as List).toSet());
      expect(matchPacedActions, (_ref['matchPacedActions'] as List).toSet());
      expect(maxActions, (_ref['maxActions'] as List).toSet());
      expect(streakStateKey, _ref['streakStateKey']);
    });

    test('the track sizes match', () {
      expect(matchQuestCount, _ref['matchQuestCount']);
      expect(seasonQuestCount, _ref['seasonQuestCount']);
      expect(noRepeatWindow, _ref['noRepeatWindow']);
    });
  });

  group('the bank as a whole', () {
    test('ids are unique', () {
      final ids = questBank.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every quest is match or season, nothing else', () {
      for (final q in questBank) {
        expect(['match', 'season'], contains(q.scope), reason: q.id);
      }
    });

    test('both scopes have more than enough to fill a track', () {
      // Three slots each, drawn without repeating a family, and the roll also
      // holds back recently-used ids.
      for (final scope in ['match', 'season']) {
        final count = questBank.where((q) => q.scope == scope).length;
        expect(count, greaterThan(noRepeatWindow + matchQuestCount));
      }
    });

    test('every quest is available at SOME division', () {
      for (final q in questBank) {
        final any = [
          for (var d = 0; d < divisions.length; d++) isEligible(q, d),
        ].any((e) => e);
        expect(any, isTrue, reason: q.id);
      }
    });

    test('a maxDiv is never below its minDiv', () {
      for (final q in questBank) {
        final maxDiv = q.maxDiv;
        if (maxDiv == null) continue;
        expect(
          divisionIndex(maxDiv),
          greaterThanOrEqualTo(divisionIndex(q.minDiv)),
          reason: q.id,
        );
      }
    });

    test('every division has at least three families to draw from, per scope', () {
      // Otherwise a track physically cannot be filled without repeating a
      // family, which is the rule the roll is built on.
      for (var d = 0; d < divisions.length; d++) {
        for (final scope in ['match', 'season']) {
          final families = <String>{};
          for (final q in questBank) {
            if (q.scope != scope || !isEligible(q, d)) continue;
            families.addAll(questTags(q));
          }
          expect(
            families.length,
            greaterThanOrEqualTo(3),
            reason: '${divisions[d].id}/$scope',
          );
        }
      }
    });
  });

  group('the reward budget', () {
    test('a match quest is 15 to 45 per cent of one win', () {
      // All three is about one extra win, and you will not land all three.
      for (final q in questBank.where((q) => q.scope == 'match')) {
        expect(q.reward.coins, inInclusiveRange(15, 45), reason: q.id);
      }
    });

    test('a season quest is 60 to 150 per cent of one win', () {
      // Spread over a fourteen-match campaign, all three is about 20 per cent
      // on top of match income.
      for (final q in questBank.where((q) => q.scope == 'season')) {
        expect(q.reward.coins, inInclusiveRange(60, 150), reason: q.id);
      }
    });

    test('coins are the only reward the bank can express', () {
      // Energy is monetised and a scout voucher is priced in gems; either would
      // give away the thing the shop charges for, or leak past the lifetime gem
      // ceiling the division capstone exists to enforce.
      for (final q in questBank) {
        expect(q.reward.coins, greaterThan(0), reason: q.id);
      }
    });
  });

  group('the rules the bank has to keep', () {
    test('no participation quests', () {
      // "Play 8 matches" completes itself over any season, so it is a receipt
      // for existing rather than a reward for doing.
      for (final q in questBank) {
        expect(q.action, isNot(QuestAction.playMatches), reason: q.id);
        expect(q.action, isNot(QuestAction.winThisMatch), reason: q.id);
      }
    });

    test('nothing is keyed to the unwired coins action', () {
      // It is kept for the event reward track. No call site sends it, so a
      // quest keyed to it could never progress.
      for (final q in questBank) {
        expect(q.action, isNot(QuestAction.coinsEarned), reason: q.id);
      }
    });

    test('every derived quest carries at least one family tag', () {
      // `derived` is a MECHANISM marker, not a family — treating it as one
      // capped the season track at a single save-reading quest, which is what
      // kept two of the three slots permanently stocked with win counters.
      for (final q in questBank.where(isDerived)) {
        expect(q.tags, isNotEmpty, reason: q.id);
        expect(questTags(q), isNot(contains(QuestAction.derived)), reason: q.id);
      }
    });

    test('and every derived quest declares itself as such on the action', () {
      for (final q in questBank) {
        expect(isDerived(q), q.action == QuestAction.derived, reason: q.id);
      }
    });

    test('a non-derived quest never carries a progress reader', () {
      for (final q in questBank.where((q) => q.action != QuestAction.derived)) {
        expect(q.progress, isNull, reason: q.id);
      }
    });

    test('only match quests name a tactic', () {
      for (final q in questBank.where((q) => q.strategy != null)) {
        expect(q.scope, 'match', reason: q.id);
        expect(q.action, QuestAction.tacticWin, reason: q.id);
      }
    });

    test('a streak action is always a season quest', () {
      for (final q in questBank.where((q) => streakActions.contains(q.action))) {
        expect(q.scope, 'season', reason: q.id);
      }
    });

    test('every per-match action belongs to a season quest', () {
      // The whole point of the set is answering "can this still be finished in
      // the fixtures left", which is a season question.
      final used = questBank
          .where((q) => perMatchActions.contains(q.action))
          .toList();
      expect(used, isNotEmpty);
      for (final q in used) {
        expect(q.scope, 'season', reason: q.id);
      }
    });

    test('the WINS family holds every win-flavoured season quest', () {
      // "Win 8", "win 4 away", "beat 2 better sides" and "win 2 from behind"
      // are one ask wearing four hats, and a track filled from that set is a
      // season of the thing the player was doing anyway.
      const winFlavoured = {
        QuestAction.matchWin,
        QuestAction.awayWins,
        QuestAction.homeWins,
        QuestAction.underdogWins,
        QuestAction.comebackWins,
        QuestAction.winRun,
        QuestAction.unbeatenRun,
      };
      for (final q in questBank.where((q) => winFlavoured.contains(q.action))) {
        expect(q.tags, contains(QuestTag.wins), reason: q.id);
      }
    });

    test('a scoring run is NOT in the wins family', () {
      // A beaten team can extend one, so it is pointedly not a winning run.
      final q = getQuest('season_scoring_run')!;
      expect(q.tags, isNot(contains(QuestTag.wins)));
      expect(q.tags, contains(QuestTag.goals));
    });

    test('every arcade quest measures a delta and gates on its own game', () {
      final arcade = questBank.where((q) => q.tags.contains(QuestTag.arcade));
      expect(arcade, isNotEmpty);
      for (final q in arcade) {
        expect(q.baseline, isTrue, reason: q.id);
      }
    });

    test('arcade targets are FLAT — a promotion does not make the day longer', () {
      // Every other season target climbs with the division because the squad
      // does; these are capped by the wall clock, since each game sits behind a
      // cooldown and a whole season takes well under an hour to play.
      for (final q in questBank.where((q) => q.tags.contains(QuestTag.arcade))) {
        final targets = {
          for (var d = 0; d < divisions.length; d++)
            if (isEligible(q, d)) resolveTarget(q, d),
        };
        // The one exception is the cumulative penalty count, which replaces the
        // perfect-round lottery at the top of the ladder.
        if (q.id == 'season_penalties_scored') continue;
        expect(targets.length, 1, reason: q.id);
      }
    });

    test('a family never welds the whole bank into one slot', () {
      // Families are connected groups and merge transitively, so a tag added to
      // be "helpful" on an unrelated pair is the mistake this guards.
      for (final scope in ['match', 'season']) {
        final scoped = questBank.where((q) => q.scope == scope).toList();
        final parent = <String, String>{};
        String find(String x) => parent[x] == null || parent[x] == x
            ? (parent[x] = x)
            : (parent[x] = find(parent[x]!));
        void union(String a, String b) => parent[find(a)] = find(b);

        for (final q in scoped) {
          final slots = questTags(q);
          for (final s in slots) {
            find(s);
          }
          for (var i = 1; i < slots.length; i++) {
            union(slots[0], slots[i]);
          }
        }
        final groups = <String, int>{};
        for (final q in scoped) {
          final root = find(questTags(q).first);
          groups[root] = (groups[root] ?? 0) + 1;
        }
        // No family may hold more than half the scope's quests.
        for (final entry in groups.entries) {
          expect(
            entry.value,
            lessThan(scoped.length / 2),
            reason: '$scope family ${entry.key}',
          );
        }
        expect(groups.length, greaterThanOrEqualTo(3), reason: scope);
      }
    });
  });

  group('resolveTarget', () {
    test('a curve is evaluated at the division index', () {
      final q = getQuest('season_wins')!;
      expect(resolveTarget(q, 0), 4);
      expect(resolveTarget(q, 6), 10);
    });

    test('never returns less than one', () {
      // A curve must not be able to produce an instantly-complete quest at the
      // bottom of the ladder.
      for (final q in questBank) {
        for (var d = -2; d < divisions.length + 2; d++) {
          expect(resolveTarget(q, d), greaterThanOrEqualTo(1), reason: q.id);
        }
      }
    });

    test('a ceiling-shaped target stays flat across divisions', () {
      // Scaling "concede at most one" would make the quest EASIER as you climb.
      final q = getQuest('match_concede_max_one')!;
      expect({for (var d = 0; d < divisions.length; d++) resolveTarget(q, d)}, {1});
    });

    test('the asset-tier quest tracks the division and stops at the ceiling', () {
      final q = getQuest('season_asset_tier')!;
      expect(resolveTarget(q, 0), 2);
      expect(resolveTarget(q, 6), 8);
      expect(q.lift, 8);
    });

    test('the tier quest asks for the best card its league can produce', () {
      final q = getQuest('season_reach_tier')!;
      for (var d = 0; d < divisions.length; d++) {
        expect(resolveTarget(q, d), divisions[d].maxPlayerTier, reason: '$d');
      }
    });

    test('the all-categories quest asks for every category there is', () {
      expect(
        resolveTarget(getQuest('season_all_categories')!, 0),
        AssetCategory.all.length,
      );
    });
  });

  group('isEligible', () {
    test('refuses an unknown division outright', () {
      expect(isEligible(questBank.first, -1), isFalse);
    });

    test('honours a minimum', () {
      final q = getQuest('match_late_winner')!; // National League and up
      expect(isEligible(q, divisionIndex('regional_league')), isFalse);
      expect(isEligible(q, divisionIndex('national_league')), isTrue);
    });

    test('honours a maximum', () {
      final q = getQuest('match_score_2')!; // up to Amateur
      expect(isEligible(q, divisionIndex('amateur_cup')), isTrue);
      expect(isEligible(q, divisionIndex('regional_league')), isFalse);
    });

    test('a capped quest hands over to its successor with no gap', () {
      // The two penalty quests split the ladder between them; a division with
      // neither would lose the objective entirely.
      final capped = getQuest('season_perfect_penalty')!;
      final successor = getQuest('season_penalties_scored')!;
      for (var d = 0; d < divisions.length; d++) {
        expect(
          isEligible(capped, d) || isEligible(successor, d),
          isTrue,
          reason: divisions[d].id,
        );
      }
    });
  });

  group('feasibility', () {
    test('away wants an away fixture', () {
      final q = getQuest('match_away_win')!;
      expect(q.feasible!(_ctx(isHome: false), 1), isTrue);
      expect(q.feasible!(_ctx(isHome: true), 1), isFalse);
    });

    test('an unknown venue is refused — better a quest that waits', () {
      final q = getQuest('match_away_win')!;
      expect(q.feasible!(_ctx(), 1), isFalse);
    });

    test('underdog wants them rated above us', () {
      final q = getQuest('match_underdog_win')!;
      expect(q.feasible!(_ctx(ourRating: 60, oppRating: 70), 1), isTrue);
      expect(q.feasible!(_ctx(ourRating: 70, oppRating: 60), 1), isFalse);
      expect(q.feasible!(_ctx(ourRating: 60, oppRating: 60), 1), isFalse);
      expect(q.feasible!(_ctx(ourRating: 60), 1), isFalse);
    });

    test('the weak-defence shutout wants their attack above our defence', () {
      final q = getQuest('match_weak_def_clean_sheet')!;
      expect(q.feasible!(_ctx(ourDefence: 50, oppAttack: 70), 1), isTrue);
      expect(q.feasible!(_ctx(ourDefence: 80, oppAttack: 70), 1), isFalse);
      expect(q.feasible!(_ctx(ourDefence: 50), 1), isFalse);
    });

    test('a keeper only has to be OWNED, not already up front', () {
      // Fielding him there IS the quest; anything the player can still change
      // after reading it is feasible.
      final q = getQuest('match_gk_scores')!;
      expect(q.feasible!(_ctx(hasGK: true), 1), isTrue);
      expect(q.feasible!(_ctx(hasGK: false), 1), isFalse);
    });

    test('the veteran quest reads the target, not a fixed age', () {
      final q = getQuest('match_veteran_scores')!;
      expect(q.feasible!(_ctx(oldestSeasons: 3), 3), isTrue);
      expect(q.feasible!(_ctx(oldestSeasons: 2), 3), isFalse);
    });

    test('N different scorers needs N fit players', () {
      final q = getQuest('match_three_scorers')!;
      expect(q.feasible!(_ctx(fitCount: 3), 3), isTrue);
      expect(q.feasible!(_ctx(fitCount: 2), 3), isFalse);
    });

    test('discovery refuses a save that has met nearly everyone', () {
      // The index is finite and a long-running save fills it.
      final q = getQuest('season_discover')!;
      expect(q.feasible!(_ctx(undiscovered: 8), 8), isTrue);
      expect(q.feasible!(_ctx(undiscovered: 2), 8), isFalse);
    });

    test('a substitution quest needs somebody on the bench', () {
      final q = getQuest('match_use_subs')!;
      expect(q.feasible!(_ctx(benchCount: 2), 2), isTrue);
      expect(q.feasible!(_ctx(benchCount: 1), 2), isFalse);
      expect(q.feasible!(_ctx(benchCount: 0), 2), isFalse);
    });

    test('a sub scoring needs at least one, whatever the target', () {
      final q = getQuest('match_sub_scores')!;
      expect(q.feasible!(_ctx(benchCount: 1), 1), isTrue);
      expect(q.feasible!(_ctx(benchCount: 0), 1), isFalse);
    });

    test('an arcade quest refuses a game the Training tier has not opened', () {
      // The division a quest is gated to says nothing about it — the Training
      // facility is bought with coins whenever the player fancies it.
      final q = getQuest('season_boot_room')!;
      expect(q.feasible!(_ctx(minigames: ['boot_room']), 1), isTrue);
      expect(q.feasible!(_ctx(minigames: ['pairs']), 1), isFalse);
      expect(q.feasible!(_ctx(), 1), isFalse);
    });

    test('each arcade quest gates on its OWN game', () {
      const pairs = [
        ('season_through_ball', 'through_ball'),
        ('season_keepy_uppys', 'keepy_uppys'),
        ('season_pairs', 'pairs'),
        ('season_whack', 'whack'),
        ('season_boot_room', 'boot_room'),
        ('season_perfect_training', 'training'),
      ];
      for (final (id, game) in pairs) {
        final q = getQuest(id)!;
        expect(q.feasible!(_ctx(minigames: [game]), 1), isTrue, reason: id);
        expect(q.feasible!(_ctx(minigames: ['nothing']), 1), isFalse, reason: id);
      }
    });

    test('Penalty Training is NOT gated — it needs no facility', () {
      expect(getQuest('season_minigames')!.feasible, isNull);
      expect(getQuest('season_perfect_penalty')!.feasible, isNull);
      expect(getQuest('season_penalties_scored')!.feasible, isNull);
    });
  });

  group('the derived readers', () {
    Map<String, dynamic> save({
      List<dynamic>? cells,
      Map<String, dynamic>? clubAssets,
      List<dynamic>? lineup,
      List<dynamic>? discovered,
      Map<String, dynamic>? stats,
    }) => {
      'grid': <String, dynamic>{'cells': cells ?? <dynamic>[]},
      'clubAssets': clubAssets ?? <String, dynamic>{},
      'squad': <String, dynamic>{'lineup': lineup ?? <dynamic>[]},
      'progression': <String, dynamic>{'discoveredPlayers': discovered ?? <dynamic>[]},
      'stats': stats ?? <String, dynamic>{},
    };

    num read(String questId, Map<String, dynamic>? state) =>
        getQuest(questId)!.progress!(state);

    test('renamed counts the cards with a custom name', () {
      final state = save(cells: [
        <String, dynamic>{'customName': 'Bomber'},
        <String, dynamic>{},
        null,
      ]);
      expect(read('season_rename', state), 1);
    });

    test('sponsored counts the cards with a deal', () {
      final state = save(cells: [
        <String, dynamic>{'sponsor': <String, dynamic>{'id': 'x'}},
        <String, dynamic>{},
      ]);
      expect(read('season_sponsor', state), 1);
    });

    test('squad size ignores the empty cells', () {
      final state = save(cells: [<String, dynamic>{}, null, <String, dynamic>{}, null]);
      expect(read('season_squad_depth', state), 2);
    });

    test('the best asset tier skips the club grid cells array', () {
      // `clubAssets` also holds a `cells` list, which is what filtering on
      // `owned` is for.
      final state = save(clubAssets: {
        'cells': <dynamic>[1, 2, 3],
        'TRAINING': <String, dynamic>{'owned': true, 'tier': 3},
        'MERCH': <String, dynamic>{'owned': false, 'tier': 7},
      });
      expect(read('season_asset_tier', state), 3);
    });

    test('owned categories counts only real categories', () {
      final state = save(clubAssets: {
        'cells': <dynamic>[],
        AssetCategory.training: <String, dynamic>{'owned': true},
        AssetCategory.merch: <String, dynamic>{'owned': true},
        'NOT_A_CATEGORY': <String, dynamic>{'owned': true},
      });
      expect(read('season_all_categories', state), 2);
    });

    test('the filled lineup counts occupied slots', () {
      final state = save(lineup: [
        <String, dynamic>{'cardInstanceId': 'a'},
        <String, dynamic>{'cardInstanceId': null},
        <String, dynamic>{'cardInstanceId': 'b'},
      ]);
      expect(read('season_full_lineup', state), 2);
    });

    test('discovery counts the index', () {
      expect(read('season_discover', save(discovered: ['a', 'b', 'c'])), 3);
    });

    test('facility taps add up across every facility', () {
      final state = save(clubAssets: {
        'cells': <dynamic>[],
        'TRAINING': <String, dynamic>{'tapCount': 4},
        'MERCH': <String, dynamic>{'tapCount': 6},
        'STADIUM': <String, dynamic>{},
      });
      expect(read('season_facility_invest', state), 10);
    });

    test('a stat reader answers zero for a stat that is not there', () {
      expect(read('season_transfer_accept', save()), 0);
    });

    test('every reader survives a half-built save without throwing', () {
      // A reader that throws simply stops its quest ever progressing, which is
      // worse than returning zero.
      for (final q in questBank.where(isDerived)) {
        for (final state in <Map<String, dynamic>?>[
          null,
          <String, dynamic>{},
          {'grid': 'tampered', 'clubAssets': 7, 'squad': null, 'stats': <dynamic>[]},
        ]) {
          expect(() => q.progress!(state), returnsNormally, reason: q.id);
          expect(q.progress!(state), isA<num>(), reason: q.id);
        }
      }
    });
  });

  group('getQuest', () {
    test('finds a quest by id', () {
      expect(getQuest('season_wins')?.scope, 'season');
    });

    test('and answers null for anything else', () {
      expect(getQuest('nope'), isNull);
      expect(getQuest(null), isNull);
    });
  });

  group('divisionIndex', () {
    test('walks the ladder', () {
      expect(divisionIndex('sunday_league'), 0);
      expect(divisionIndex('champions_cup'), divisions.length - 1);
    });

    test('an unknown id is -1', () {
      expect(divisionIndex('nope'), -1);
      expect(divisionIndex(null), -1);
    });
  });
}
