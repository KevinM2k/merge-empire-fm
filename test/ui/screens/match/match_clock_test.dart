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
      expect(frame.homeGoals, 0);
      expect(frame.awayGoals, 0);
    });

    test('counts the score from the goals SHOWN, not the result', () {
      // The number on screen must never run ahead of the commentary that
      // explains it.
      final result = resultWith(events: [goal(12, 'home'), goal(80, 'home')]);
      expect(frameAt(result, 11).homeGoals, 0);
      expect(frameAt(result, 12).homeGoals, 1);
      expect(frameAt(result, 79).homeGoals, 1);
      expect(frameAt(result, 80).homeGoals, 2);
    });

    test('keeps the two sides apart', () {
      final result = resultWith(
        events: [goal(10, 'home'), goal(20, 'away'), goal(30, 'away')],
      );
      final frame = frameAt(result, 90);
      expect(frame.homeGoals, 1);
      expect(frame.awayGoals, 2);
    });

    test('a goal with no team is ours', () {
      // The engine omits `team` on some goals; treating that as the opposition
      // would hand the other side a goal the player just scored.
      final result = resultWith(
        events: [
          {'minute': 10, 'type': 'goal', 'scorer': 'X'},
        ],
      );
      expect(frameAt(result, 90).homeGoals, 1);
      expect(frameAt(result, 90).awayGoals, 0);
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
      expect(frame.homeGoals, 0);
      expect(frame.awayGoals, 0);
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
    test('fast mode halves the wait rather than skipping anything', () {
      final normal = minuteDuration(fast: false);
      final fast = minuteDuration(fast: true);
      expect(fast, lessThan(normal));
      // A whole match still fits in something a player will sit through.
      expect(normal * 93, lessThan(const Duration(seconds: 20)));
    });
  });
}
