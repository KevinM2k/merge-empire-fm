/// The playback clock.
///
/// `simulateMatch` decides the whole match up front; this only decides when an
/// already-decided event appears. The tests are mostly about that boundary.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';

Map<String, dynamic> resultWith({
  int addedTime = 3,
  List<Map<String, dynamic>> events = const [],
}) => {'addedTime': addedTime, 'events': events};

Map<String, dynamic> goal(int minute, String team) => {
  'minute': minute,
  'type': 'goal',
  'team': team,
  'scorer': 'Scorer $minute',
};

void main() {
  group('the timeline', () {
    test('is sorted by minute however it arrives', () {
      final result = resultWith(
        events: [goal(70, 'home'), goal(12, 'away'), goal(45, 'home')],
      );
      expect(timelineOf(result).map((e) => e.minute), [12, 45, 70]);
    });

    test('survives a result with no events at all', () {
      expect(timelineOf(resultWith()), isEmpty);
      expect(timelineOf(<String, dynamic>{}), isEmpty);
    });

    test('carries the commentary key through', () {
      final result = resultWith(
        events: [
          {
            'minute': 20,
            'type': 'commentary',
            'team': 'home',
            'textKey': 'commentary.flow.midfield.0',
          },
        ],
      );
      expect(timelineOf(result).single.textKey, 'commentary.flow.midfield.0');
    });
  });

  group('the frame', () {
    test('shows nothing at kickoff', () {
      final result = resultWith(events: [goal(12, 'home')]);
      final frame = frameAt(result, 0);
      expect(frame.shown, isEmpty);
      expect(frame.ourGoals, 0);
      expect(frame.theirGoals, 0);
    });

    test('counts the score from the goals SHOWN, not the result', () {
      // The number on screen must never run ahead of the commentary that
      // explains it.
      final result = resultWith(events: [goal(12, 'home'), goal(80, 'home')]);
      expect(frameAt(result, 11).ourGoals, 0);
      expect(frameAt(result, 12).ourGoals, 1);
      expect(frameAt(result, 79).ourGoals, 1);
      expect(frameAt(result, 80).ourGoals, 2);
    });

    test('keeps the two sides apart', () {
      final result = resultWith(
        events: [goal(10, 'home'), goal(20, 'away'), goal(30, 'away')],
      );
      final frame = frameAt(result, 90);
      expect(frame.ourGoals, 1);
      expect(frame.theirGoals, 2);
    });

    test('a goal with no team is ours', () {
      // The engine omits `team` on some goals; treating that as the opposition
      // would hand the other side a goal the player just scored.
      final result = resultWith(
        events: [
          {'minute': 10, 'type': 'goal', 'scorer': 'X'},
        ],
      );
      expect(frameAt(result, 90).ourGoals, 1);
      expect(frameAt(result, 90).theirGoals, 0);
    });

    test('non-goal events never move the score', () {
      final result = resultWith(
        events: [
          {'minute': 10, 'type': 'corner', 'team': 'home'},
          {'minute': 45, 'type': 'halftime'},
          {'minute': 60, 'type': 'commentary', 'team': 'away'},
        ],
      );
      final frame = frameAt(result, 90);
      expect(frame.shown.length, 3);
      expect(frame.ourGoals, 0);
      expect(frame.theirGoals, 0);
    });

    test('finishes at ninety plus added time, not at ninety', () {
      final result = resultWith(addedTime: 4);
      expect(frameAt(result, 90).finished, isFalse);
      expect(frameAt(result, 93).finished, isFalse);
      expect(frameAt(result, 94).finished, isTrue);
    });

    test('a negative added time is treated as none', () {
      expect(fullTime(-5), 90);
      expect(frameAt(resultWith(addedTime: -5), 90).finished, isTrue);
    });

    test('the final frame shows everything', () {
      final result = resultWith(
        events: [goal(1, 'home'), goal(93, 'away')],
        addedTime: 5,
      );
      final frame = frameAt(result, fullTime(5));
      expect(frame.shown.length, 2);
      expect(frame.finished, isTrue);
    });
  });

  group('the pace', () {
    test('fast mode HALVES the wait rather than skipping anything', () {
      // Exactly half, which is what the ×2 on the button says.
      expect(minuteDuration(fast: true) * 2, minuteDuration(fast: false));
    });

    test('AND THE PACE IS THE SPEC\'S, not a third of it', () {
      // `MatchPopup.js` ticks one minute per `TICK_MS = 350`, halved to 175.
      // The port had 120 and 60, so a ninety-minute match went by in eleven
      // seconds and the ×2 was six — reported as "1× seems to have gone fast
      // and 2× is far too fast".
      expect(matchMinuteMs, 350);
      expect(matchMinuteMsFast, 175);
      // A whole match is about half a minute, which is what the commentary was
      // written to be read at — and still something a player will sit through.
      final whole = minuteDuration(fast: false) * 93;
      expect(whole, greaterThan(const Duration(seconds: 25)));
      expect(whole, lessThan(const Duration(seconds: 40)));
    });
  });

  group('THE FEED', () {
    TimelineEvent ev(
      String type, {
      int minute = 10,
      String team = 'home',
      String? shotResult,
      bool big = false,
      double xg = 0,
      String? scorer,
      String? scorerId,
      String? player,
      String? textKey,
    }) => (
      minute: minute,
      type: type,
      team: team,
      scorer: scorer,
      scorerId: scorerId,
      textKey: textKey,
      shotResult: shotResult,
      big: big,
      xg: xg,
      player: player,
    );

    List<FeedLine> feed(List<TimelineEvent> events, {bool isHome = true}) =>
        feedOf(events, ourName: 'Us', theirName: 'Them', isHome: isHome);

    test('AND A GOAL KNOWS WHOSE IT WAS', () {
      // The feed printed the scorer's NAME and carried nothing else, so a row
      // that wanted his face had a string to work from. The engine has written
      // `scorerInstanceId` all along — `finalizeMatchOutcome` attributes career
      // goals by it — and the line carries it now.
      final ours = feed([ev('goal', scorer: 'Bobby', scorerId: 'c7')]);
      expect(ours.single.aboutId, 'c7');

      // An opponent goal is nobody's, and it has to be: the engine picks
      // scorers from OUR squad, so a face for one of theirs cannot be drawn.
      final theirs = feed([ev('goal', team: 'away')]);
      expect(theirs.single.aboutId, isNull);

      // And a goal with no scorer at all — an own goal, an older save — is a
      // line without a face rather than a line without a goal.
      expect(feed([ev('goal')]).single.aboutId, isNull);
    });

    test('A CORNER SAYS NOTHING, and neither does full time', () {
      // The port fell through to printing `event.type`, so a corner read as the
      // word "corner" and full time as "fulltime" — raw, untranslated strings
      // from the engine on the one screen a player watches for ninety minutes.
      // A corner is a momentum nudge; it is not news.
      expect(feed([ev('corner'), ev('fulltime', minute: 90)]), isEmpty);
    });

    test('and a chance only earns a line if it was BIG and ON TARGET', () {
      // There is a chance about every seven minutes. Without both filters the
      // feed is nothing else.
      expect(feed([ev('chance', xg: 0.1, shotResult: 'on_target')]), isEmpty);
      expect(feed([ev('chance', big: true, shotResult: 'off')]), isEmpty);
      final one = feed([ev('chance', big: true, shotResult: 'on_target')]);
      expect(one, hasLength(1));
      expect(one.single.key, 'commentary.forces_save');
      expect(one.single.params['who'], 'Us');
    });

    test('and the second one inside ten minutes is held back', () {
      final lines = feed([
        ev('chance', minute: 10, big: true, shotResult: 'on_target'),
        ev('chance', minute: 15, big: true, shotResult: 'on_target'),
        ev('chance', minute: 22, big: true, shotResult: 'on_target'),
      ]);
      expect([for (final l in lines) l.minute], [10, 22]);
    });

    test('THE SIDE IS NAMED FROM THE PLAYER\'S POINT OF VIEW', () {
      final away = feed([
        ev('chance', team: 'away', big: true, shotResult: 'on_target'),
      ], isHome: true);
      expect(away.single.params['who'], 'Them');
      final ours = feed([
        ev('chance', team: 'away', big: true, shotResult: 'on_target'),
      ], isHome: false);
      expect(ours.single.params['who'], 'Us');
    });

    test('A GOAL IS DESCRIBED BY WHAT IT DID TO THE SCORE', () {
      // Eight `commentary.goal.*` pools sat translated in ten catalogues with
      // nothing able to reach one: the feed printed the scorer's name alone. But
      // equalising, pulling one back, going ahead and stretching a lead are four
      // different moments and the feed should not read the same for all four.
      final lines = feed([
        ev('goal', minute: 5, team: 'away'),
        ev('goal', minute: 20, team: 'home', scorer: 'Ada'),
        ev('goal', minute: 30, team: 'home', scorer: 'Ada'),
        ev('goal', minute: 40, team: 'home', scorer: 'Ada'),
      ]);
      expect(lines[0].key, 'commentary.opp_goal');
      expect(lines[0].params['them'], 'Them');
      expect(lines[1].key, 'commentary.goal.equalise.with_scorer');
      expect(lines[2].key, 'commentary.goal.lead.with_scorer');
      expect(lines[3].key, 'commentary.goal.extend.with_scorer');
    });

    test('and pulling one back is not the same as equalising', () {
      final lines = feed([
        ev('goal', minute: 5, team: 'away'),
        ev('goal', minute: 6, team: 'away'),
        ev('goal', minute: 20, team: 'home'),
      ]);
      expect(lines.last.key, 'commentary.goal.pullback.no_scorer');
    });

    test('and the POOL PICK IS STABLE, because the feed rebuilds', () {
      // Every tick of the clock rebuilds it, and a sentence that rerolls under
      // the reader is worse than one sentence.
      final a = feed([ev('goal', minute: 20, scorer: 'Ada')]).single;
      final b = feed([ev('goal', minute: 20, scorer: 'Ada')]).single;
      expect(a.seed, b.seed);
    });

    test('an injury names who went down', () {
      final line = feed([ev('injury', player: 'Ada')]).single;
      expect(line.key, 'commentary.injury');
      expect(line.params['player'], 'Ada');
    });
  });
}
