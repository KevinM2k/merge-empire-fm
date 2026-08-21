/// Coach Colin, for the ninety minutes he is on the touchline.
///
/// Twenty-four pooled `coach.match.*` strings were translated into ten
/// catalogues with nothing able to reach one of them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_coach.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

void main() {
  tearDown(resetLocale);

  group('his read of the game', () {
    test('half time has its own five', () {
      String ht(int margin) =>
          coachReadKey(halftime: true, margin: margin, minute: 45);
      expect(ht(0), 'coach.match.ht.level');
      expect(ht(1), 'coach.match.ht.lead_one');
      expect(ht(3), 'coach.match.ht.lead_big');
      expect(ht(-1), 'coach.match.ht.behind_one');
      expect(ht(-4), 'coach.match.ht.behind_big');
    });

    test('and the same scoreline reads differently late', () {
      // "Still level" at 20 minutes is patience and at 70 it is a warning; the
      // whole point of the pools is that the two are different moments.
      String at(int minute, int margin) =>
          coachReadKey(halftime: false, margin: margin, minute: minute);
      expect(at(20, 0), 'coach.match.level_early');
      expect(at(70, 0), 'coach.match.level_late');
      expect(at(20, 1), 'coach.match.lead_one_early');
      expect(at(70, 1), 'coach.match.lead_one_late');
      expect(at(20, -1), 'coach.match.behind_one_early');
      expect(at(70, -1), 'coach.match.behind_one_late');
    });

    test('the first quarter of hour at 0-0 is its own line', () {
      expect(
        coachReadKey(halftime: false, margin: 0, minute: 5),
        'coach.match.early_level',
      );
    });

    test('and two down is the same emergency whenever it happens', () {
      for (final minute in [10, 45, 88]) {
        expect(
          coachReadKey(halftime: false, margin: -2, minute: minute),
          'coach.match.battered',
        );
      }
    });

    test('every key it names is in the catalogue', () {
      for (final halftime in [true, false]) {
        for (var margin = -3; margin <= 3; margin++) {
          for (final minute in [5, 20, 45, 70, 89]) {
            final key = coachReadKey(
              halftime: halftime,
              margin: margin,
              minute: minute,
            );
            expect(t(key), isNot(key), reason: '$key has no copy');
          }
        }
      }
    });
  });

  group('when he speaks', () {
    bool speak({
      int minute = 50,
      int last = 10,
      String? suggestion = 'highPress',
      String? lastSuggestion,
      String active = 'balanced',
      bool force = false,
    }) => coachShouldSpeak(
      minute: minute,
      lastSpokeMinute: last,
      activeStrategy: active,
      suggestion: suggestion,
      lastSuggestion: lastSuggestion,
      force: force,
    );

    test('he holds the floor after speaking', () {
      // A coach who revises his read every other minute is noise.
      expect(speak(minute: 20, last: 10), isFalse);
      expect(speak(minute: 36, last: 10), isTrue);
    });

    test('his first word waits, and has to be worth saying', () {
      expect(speak(minute: 3, last: -1), isFalse, reason: 'too early');
      expect(
        speak(minute: 30, last: -1, suggestion: 'balanced'),
        isFalse,
        reason: 'he is agreeing with the dial',
      );
      expect(speak(minute: 30, last: -1), isTrue);
    });

    test('and he does not repeat the same ask', () {
      expect(
        speak(minute: 40, last: 10, lastSuggestion: 'highPress'),
        isFalse,
      );
      // ...until it has been long enough that saying nothing is worse.
      expect(
        speak(minute: 60, last: 10, lastSuggestion: 'highPress'),
        isTrue,
      );
    });

    test('the whistle jumps the queue', () {
      expect(speak(minute: 45, last: 44, force: true), isTrue);
    });
  });

  group('the line he gives', () {
    test('is a greeting, a read, and the switch he wants', () {
      final line = matchCoachOpinion(
        halftime: false,
        margin: -1,
        minute: 70,
        activeStrategy: 'balanced',
        seed: 'coach-70',
        suggestion: 'allOutAttack',
      );
      expect(line, contains(t('strategy.allOutAttack.name')));
      expect(line.split(' ').length, greaterThan(6));
      // Nothing raw from the catalogue, and no unfilled placeholder.
      expect(line, isNot(contains('coach.match')));
      expect(line, isNot(contains('{')));
    });

    test('and drops the ask when he agrees with the dial', () {
      final line = matchCoachOpinion(
        halftime: false,
        margin: 0,
        minute: 30,
        activeStrategy: 'balanced',
        seed: 'coach-30',
        suggestion: 'balanced',
      );
      expect(line, isNot(contains(t('strategy.balanced.name'))));
    });

    test('the same minute gives the same sentence', () {
      // The screen rebuilds on every simulated minute; an unseeded pick would
      // rewrite his sentence under the reader.
      String say() => matchCoachOpinion(
        halftime: false,
        margin: 1,
        minute: 55,
        activeStrategy: 'balanced',
        seed: 'coach-55',
        suggestion: 'parkTheBus',
      );
      expect(say(), say());
    });
  });

  group('what he would play', () {
    test('is nothing once the match is over', () {
      expect(
        matchCoachSuggestion(
          ourAttack: 50,
          ourDefence: 50,
          theirAttack: 50,
          theirDefence: 50,
          activeStrategy: 'balanced',
          minute: 90,
          duration: 90,
          margin: 0,
        ),
        isNull,
      );
    });

    test('and he will not tell you to keep parking the bus at 0-2', () {
      // Chasing is not a special case bolted on: league points already encode
      // it, because a draw is worth 1 and a defeat 0 — see `suggestTactic`.
      expect(
        matchCoachSuggestion(
          ourAttack: 50,
          ourDefence: 50,
          theirAttack: 50,
          theirDefence: 50,
          activeStrategy: 'parkTheBus',
          minute: 60,
          duration: 90,
          margin: -2,
        ),
        isNot('parkTheBus'),
      );
    });

    test('he agrees with the dial rather than nagging over noise', () {
      // The switch has to be worth `coachMinTacticGain`; below it he names the
      // tactic already set, which the caller reads as nothing to say.
      final pick = matchCoachSuggestion(
        ourAttack: 50,
        ourDefence: 50,
        theirAttack: 50,
        theirDefence: 50,
        activeStrategy: 'balanced',
        minute: 10,
        duration: 90,
        margin: 0,
      );
      expect(pick, isNotNull);
    });
  });
}
