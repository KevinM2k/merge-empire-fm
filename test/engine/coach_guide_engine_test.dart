/// The onboarding trail's rules, pinned next to the engine.
///
/// **The one that matters is "spent by DOING".** Every other coach surface in
/// this app spends its id when it is SHOWN, which is right for a lesson about
/// something that just happened and wrong for a to-do: a player who found the
/// Shop on their own has been to the Shop, and being sent there afterwards is
/// the app not watching.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/coach_guide_engine.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> _save({
  bool armed = true,
  int matchesPlayed = 1,
  int cards = 3,
}) {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)['done'] = true;
  (s['progression'] as Map<String, dynamic>)['matchesPlayed'] = matchesPlayed;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < cards && i < cells.length; i++) {
    cells[i] = <String, dynamic>{'definitionId': 'player_t1_mid'};
  }
  if (armed) armCoachGuides(s);
  return s;
}

void main() {
  group('arming', () {
    test('a save that never watched the script finish is not on the trail', () {
      // **The case this whole mechanism is defended against.** Every save
      // written before the port had a tutorial reads as `done` — see
      // `settleTutorial` — so keying on the flag would walk a manager fifteen
      // seasons deep through "the Squad tab is where your eleven lives".
      final s = _save(armed: false);
      expect(coachGuidesArmed(s), isFalse);
      expect(nextCoachGuide(s), isNull);
      expect(completeCoachGuides(s, tabTrigger('grid')), isFalse);
    });

    test('finishing the script arms it', () {
      final s = createDefaultState();
      final tut = s['tutorial'] as Map<String, dynamic>;
      tut['step'] = tutorialSteps.length - 1;
      advanceTutorial(s);
      expect(tut['done'], isTrue);
      expect(coachGuidesArmed(s), isTrue);
    });

    test('so does walking out of it', () {
      // Somebody who skipped has been shown less than anybody, not more.
      final s = createDefaultState();
      skipTutorial(s);
      expect(coachGuidesArmed(s), isTrue);
    });

    test('a step in the middle arms nothing', () {
      final s = createDefaultState();
      advanceTutorial(s);
      expect(coachGuidesArmed(s), isFalse);
    });
  });

  group('the trail', () {
    test('the Players tab is the first thing said', () {
      // The hand-off the funnel asked for: the script leaves the player on the
      // home screen and nothing there says the squad is on another tab.
      expect(nextCoachGuide(_save())?.id, 'players_tab');
    });

    test('one at a time, and doing it moves the trail on', () {
      final s = _save();
      expect(completeCoachGuides(s, tabTrigger('grid')), isTrue);
      expect(nextCoachGuide(s)?.id, 'squad_tab');
    });

    test('a marker is never said twice', () {
      final s = _save();
      completeCoachGuides(s, tabTrigger('grid'));
      completeCoachGuides(s, tabTrigger('squad'));
      completeCoachGuides(s, dugoutTrigger);
      completeCoachGuides(s, trainingTrigger);
      completeCoachGuides(s, tabTrigger('club'));
      completeCoachGuides(s, tabTrigger('shop'));
      expect(nextCoachGuide(s), isNull);
      // And it stays null: the trail has no second lap.
      expect(nextCoachGuide(s), isNull);
    });

    test('doing it BEFORE being told spends it just the same', () {
      // A player who wanders into the Shop in their first minute is never
      // afterwards told where the Shop is.
      final s = _save(matchesPlayed: 9);
      expect(completeCoachGuides(s, tabTrigger('shop')), isTrue);
      expect(coachGuideSpent(s, coachGuides.last), isTrue);
      final seen = <String>[];
      for (var i = 0; i < coachGuides.length + 1; i++) {
        final guide = nextCoachGuide(s);
        if (guide == null) break;
        seen.add(guide.id);
        completeCoachGuides(s, guide.trigger);
      }
      expect(seen, isNot(contains('shop_tab')));
    });

    test('a gate not met is skipped, not a stall', () {
      // A player who sold down to two cards still has to hear about the Dugout.
      final s = _save(cards: 1);
      completeCoachGuides(s, tabTrigger('grid'));
      expect(nextCoachGuide(s)?.id, 'dugout');
    });

    test('the later markers wait for a match to have been played', () {
      final s = _save(matchesPlayed: 0);
      completeCoachGuides(s, tabTrigger('grid'));
      completeCoachGuides(s, tabTrigger('squad'));
      expect(nextCoachGuide(s), isNull);
    });
  });

  group('the ledger', () {
    test('lives in seenTips, prefixed, so there is only one of them', () {
      final s = _save();
      completeCoachGuides(s, tabTrigger('grid'));
      expect(s['seenTips'], contains('guide.players_tab'));
      // And it cannot collide with a milestone tip id.
      expect(guideLedgerId('injury'), 'guide.injury');
    });

    test('pending is the same question the write asks', () {
      // The guard that stops a tab change scheduling a save for nothing.
      final s = _save();
      expect(coachGuidePending(s, tabTrigger('grid')), isTrue);
      completeCoachGuides(s, tabTrigger('grid'));
      expect(coachGuidePending(s, tabTrigger('grid')), isFalse);
      expect(coachGuidePending(_save(armed: false), tabTrigger('grid')), false);
    });

    test('every marker names a tab that exists, and a distinct id', () {
      const tabs = {'grid', 'squad', 'home', 'club', 'shop'};
      final ids = <String>{};
      for (final guide in coachGuides) {
        expect(ids.add(guide.id), isTrue, reason: '${guide.id} is duplicated');
        expect(tabs, contains(guide.destination));
        expect(guide.bodyKey, 'guide.${guide.id}');
      }
    });
  });
}
