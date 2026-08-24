/// The nine steps, and the two players the club lends you for one match.
///
/// **The copy was never the blocker; the CHOREOGRAPHY was** — which key is
/// which step, what each anchors to, and when the borrowed players come and go.
/// None of it was recoverable from this repo, and all of it is in
/// `../merge-empire-fc/src/ui/components/Tutorial.js`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> save({int step = 0, bool done = false, int cards = 0}) {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)
    ..['step'] = step
    ..['done'] = done;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < cards; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': 'player_t1_mid',
      'instanceId': 'own$i',
      'variant': 0,
    };
  }
  return s;
}

List<dynamic> cellsOf(Map<String, dynamic> s) =>
    (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;

int coinsOf(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

void main() {
  group('the script', () {
    test('IS NINE STEPS, in the JS\'s own order', () {
      expect(
        tutorialSteps.map((s) => s.id),
        [
          'welcome',
          'scout_1',
          'scout_2',
          'loan_boost',
          'play_match',
          'play_match_action',
          'match_result_reaction',
          'loan_depart',
          'done',
        ],
      );
    });

    test('AND EVERY STEP ENDS ONE WAY, never both', () {
      // Either a button the player taps or a condition the save satisfies —
      // that is the whole state machine, and a step with both would be a step
      // that can finish twice.
      for (final step in tutorialSteps) {
        expect(
          (step.buttonKey == null) != (step.condition == null),
          isTrue,
          reason: step.id,
        );
      }
    });

    test('and every key it names is in the catalogue', () {
      for (final step in tutorialSteps) {
        expect(t(step.titleKey), isNot(step.titleKey), reason: step.id);
        expect(t(step.bodyKey), isNot(step.bodyKey), reason: step.id);
        if (step.buttonKey case final key?) {
          expect(t(key), isNot(key), reason: step.id);
        }
      }
    });

    test('THE SCOUT STEPS WAIT ON THE GRID, one card then three', () {
      expect(tutorialSteps[1].condition!(save(cards: 0)), isFalse);
      expect(tutorialSteps[1].condition!(save(cards: 1)), isTrue);
      expect(tutorialSteps[2].condition!(save(cards: 2)), isFalse);
      expect(tutorialSteps[2].condition!(save(cards: 3)), isTrue);
    });

    test('and the match step waits on a SETTLED one', () {
      // `seasonAwardedPlayed`, not `seasonMatchesPlayed`: the counter the
      // rewards move, which is the JS's own choice.
      final s = save();
      expect(tutorialSteps[5].condition!(s), isFalse);
      (s['progression'] as Map<String, dynamic>)['seasonAwardedPlayed'] = 1;
      expect(tutorialSteps[5].condition!(s), isTrue);
    });
  });

  group('where it is', () {
    test('reads the step off the save, and stops when it is done', () {
      expect(tutorialStepFor(save())?.id, 'welcome');
      expect(tutorialStepFor(save(step: 3))?.id, 'loan_boost');
      expect(tutorialStepFor(save(done: true)), isNull);
      expect(tutorialStepFor(null), isNull);
    });

    test('A STEP PAST THE END IS NOT A CRASH', () {
      // `migration.dart` inserted two steps at old indices, so a save part-way
      // through an older script can land anywhere.
      expect(tutorialStepFor(save(step: 99)), isNull);
      expect(tutorialStepFor(save(step: -1)), isNull);
    });

    test('and advancing off the end finishes it', () {
      final s = save(step: tutorialSteps.length - 1);
      advanceTutorial(s);
      expect((s['tutorial'] as Map)['done'], isTrue);
    });
  });

  group('THE PLAYERS THE CLUB LENDS YOU', () {
    test('fill the holes in a SIDE, not a flat eleven', () {
      // The player has scouted three of their own by now and they could be
      // anything; what the next step needs is a side that can take the field.
      final s = save(cards: 3);
      final lent = lendTutorialPlayers(s);
      final squad = <String, int>{};
      for (final raw in cellsOf(s)) {
        final card = CardInstance.from(raw);
        if (card == null) continue;
        final position = getPlayerDef(card.definitionId)!.position;
        squad[position] = (squad[position] ?? 0) + 1;
      }
      for (final entry in tutorialSquadTarget.entries) {
        expect(
          squad[entry.key] ?? 0,
          greaterThanOrEqualTo(entry.value),
          reason: entry.key,
        );
      }
      expect(lent, greaterThan(0));
    });

    test('AND THEY ARE BETTER THAN WHAT YOU OWN, which is the point', () {
      final s = save(cards: 3);
      lendTutorialPlayers(s);
      for (final raw in cellsOf(s)) {
        final card = CardInstance.from(raw);
        if (card == null || card.raw['borrowed'] != true) continue;
        expect(getPlayerDef(card.definitionId)!.tier, greaterThanOrEqualTo(5));
      }
    });

    test('a double tap does not lend twice', () {
      final s = save(cards: 3);
      final first = lendTutorialPlayers(s);
      expect(lendTutorialPlayers(s), 0);
      expect(
        cellsOf(s).where((c) => (c as Map?)?['borrowed'] == true).length,
        first,
      );
    });

    test('THEY GO BACK, and the club pays for the trouble', () {
      final s = save(cards: 3);
      lendTutorialPlayers(s);
      final before = coinsOf(s);
      final taken = returnTutorialPlayers(s);
      expect(taken, greaterThan(0));
      expect(coinsOf(s) - before, tutorialFarewellCoins);
      expect(
        cellsOf(s).where((c) => (c as Map?)?['borrowed'] == true),
        isEmpty,
      );
    });

    test('and YOUR OWN players are untouched', () {
      final s = save(cards: 3);
      lendTutorialPlayers(s);
      returnTutorialPlayers(s);
      final mine = [
        for (final raw in cellsOf(s))
          if (CardInstance.from(raw) case final c?) c.instanceId,
      ];
      expect(mine, containsAll(['own0', 'own1', 'own2']));
    });

    test('THE LINEUP LOSES THE SLOTS THEY WERE IN, and nothing else', () {
      final s = save(cards: 3);
      lendTutorialPlayers(s);
      returnTutorialPlayers(s);
      final lineup = (s['squad'] as Map<String, dynamic>)['lineup'] as List;
      final live = {
        for (final raw in cellsOf(s))
          if (CardInstance.from(raw) case final c?) c.instanceId,
      };
      for (final raw in lineup) {
        final id = (raw as Map)['cardInstanceId'];
        if (id != null) expect(live, contains(id));
      }
    });

    test('and taking them back twice pays once', () {
      final s = save(cards: 3);
      lendTutorialPlayers(s);
      returnTutorialPlayers(s);
      final after = coinsOf(s);
      expect(returnTutorialPlayers(s), 0);
      expect(coinsOf(s), after);
    });
  });

  group('SKIPPING', () {
    test('finishes it and LEAVES WHAT WAS LENT', () {
      // The step that takes them back also pays the 500, and a player who
      // skips between the two has been lent eleven men rather than robbed of
      // them. The JS does the same by never reaching `loan_depart`.
      final s = save(cards: 3, step: 4);
      lendTutorialPlayers(s);
      final lent =
          cellsOf(s).where((c) => (c as Map?)?['borrowed'] == true).length;
      skipTutorial(s);
      expect((s['tutorial'] as Map)['done'], isTrue);
      expect(
        cellsOf(s).where((c) => (c as Map?)?['borrowed'] == true).length,
        lent,
      );
    });
  });

  group('the four reactions to a match', () {
    test('and `first` is NO match rather than the first one', () {
      // Which a tutorial resumed on a fresh save can be sitting in.
      expect(matchReactionKind(save()), 'first');
      final s = save();
      final prog = s['progression'] as Map<String, dynamic>;
      prog['lastMatchResult'] = <String, dynamic>{'won': true};
      expect(matchReactionKind(s), 'win');
      prog['lastMatchResult'] = <String, dynamic>{'drawn': true};
      expect(matchReactionKind(s), 'draw');
      prog['lastMatchResult'] = <String, dynamic>{'won': false};
      expect(matchReactionKind(s), 'loss');
    });

    test('and all eight of its strings are in the catalogue', () {
      for (final kind in ['first', 'win', 'draw', 'loss']) {
        for (final part in ['title', 'body']) {
          final key = 'tut.match_reaction.${kind}_$part';
          expect(t(key), isNot(key), reason: key);
        }
      }
    });
  });

  group('what satisfies a step', () {
    // **`condition` had no caller in `lib/` at all**, so the three steps that
    // end this way were each a dead end: the card said go and do it, the
    // player went and did it, and the script sat where it was.
    Map<String, dynamic> at(int step, {int cards = 0, int played = 0}) {
      final s = createDefaultState();
      (s['tutorial'] as Map<String, dynamic>)
        ..['step'] = step
        ..['done'] = false;
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      for (var i = 0; i < cards; i++) {
        cells[i] = <String, dynamic>{
          'definitionId': 'player_t1_mid',
          'instanceId': 'c$i',
          'variant': 0,
        };
      }
      (s['progression'] as Map<String, dynamic>)['seasonAwardedPlayed'] = played;
      return s;
    }

    test('scouting one clears the first scout step and not before', () {
      expect(tutorialConditionMet(at(1)), isFalse);
      expect(tutorialConditionMet(at(1, cards: 1)), isTrue);
    });

    test('the second wants THREE, which is what its copy says', () {
      expect(tutorialConditionMet(at(2, cards: 2)), isFalse);
      expect(tutorialConditionMet(at(2, cards: 3)), isTrue);
    });

    test('the match step waits on a SETTLED result', () {
      // `seasonAwardedPlayed`, not `seasonMatchesPlayed`: the JS waits for the
      // rewards to have moved, which is the counter they move.
      expect(tutorialConditionMet(at(5)), isFalse);
      expect(tutorialConditionMet(at(5, played: 1)), isTrue);
    });

    test('a step that waits on its BUTTON is never satisfied by the save', () {
      // Either a button or a condition, never both — so nothing may advance
      // one of these behind the player's back.
      expect(tutorialConditionMet(at(0, cards: 9, played: 5)), isFalse);
      expect(tutorialConditionMet(at(3, cards: 9, played: 5)), isFalse);
    });

    test('and a finished script satisfies nothing', () {
      final done = at(1, cards: 9);
      (done['tutorial'] as Map<String, dynamic>)['done'] = true;
      expect(tutorialConditionMet(done), isFalse);
    });
  });
}
