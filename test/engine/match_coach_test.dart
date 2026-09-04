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
      String? declined,
      bool force = false,
    }) => coachShouldSpeak(
      minute: minute,
      lastSpokeMinute: last,
      activeStrategy: active,
      suggestion: suggestion,
      lastSuggestion: lastSuggestion,
      declinedAtKickoff: declined,
      force: force,
    );

    test('he holds the floor after speaking', () {
      // A coach who revises his read every other minute is noise.
      expect(speak(minute: 20, last: 10), isFalse);
      expect(speak(minute: 36, last: 10), isTrue);
    });

    test('his first word waits, and has to be worth saying', () {
      expect(
        speak(minute: 3, last: coachNeverSpoke),
        isFalse,
        reason: 'too early',
      );
      expect(
        speak(minute: 30, last: coachNeverSpoke, suggestion: 'balanced'),
        isFalse,
        reason: 'he is agreeing with the dial',
      );
      expect(speak(minute: 30, last: coachNeverSpoke), isTrue);
    });

    test('AND IT IS NOT HELD BY THE STICKY WINDOW, which it was', () {
      // **-1 WAS TWENTY-FOUR MINUTES OF SILENCE.** The sticky check runs
      // before the first-word check — the JS's order — so a `lastSpokeMinute`
      // of -1 makes `since` equal `minute + 1` and holds every word until
      // minute 24. `MatchPopup.js` initialises `_lastBubbleMin` to -999 for
      // exactly this reason. Reported from the couch as the coach not advising
      // a tactic change at all.
      expect(
        speak(minute: coachFirstWordMinute, last: coachNeverSpoke),
        isTrue,
        reason: 'his first word is still behind the sticky window',
      );
      expect(
        speak(minute: coachFirstWordMinute, last: -1),
        isFalse,
        reason: 'this is the bug, and it is what the constant is for',
      );
    });

    group('BUT HE DOES NOT NAG ABOUT A TACTIC ALREADY TURNED DOWN', () {
      // **Asked for from the couch, as the one thing not wanted.** The
      // pre-match tip names a tactic; a manager who kicks off playing
      // something else has read it and declined it, and being told the same
      // thing again at minute five is the game arguing with a decision that
      // was just made.
      test('so the declined ask waits for the half-hour', () {
        expect(
          speak(
            minute: coachFirstWordMinute,
            last: coachNeverSpoke,
            declined: 'highPress',
          ),
          isFalse,
          reason: 'he restated the tip the manager had just declined',
        );
        expect(
          speak(
            minute: coachDeclinedHoldMinutes - 1,
            last: coachNeverSpoke,
            declined: 'highPress',
          ),
          isFalse,
        );
        // By then the scoreline and the clock are part of his case rather than
        // it being the same read again.
        expect(
          speak(
            minute: coachDeclinedHoldMinutes,
            last: coachNeverSpoke,
            declined: 'highPress',
          ),
          isTrue,
        );
      });

      test('and it holds ONE tactic, not his mouth', () {
        // Any other ask is a fresh case and lands on the usual cadence.
        expect(
          speak(
            minute: coachFirstWordMinute,
            last: coachNeverSpoke,
            suggestion: 'parkTheBus',
            declined: 'highPress',
          ),
          isTrue,
        );
      });

      test('and half time is a moment, so it says its piece', () {
        expect(
          speak(
            minute: 45,
            last: coachNeverSpoke,
            declined: 'highPress',
            force: true,
          ),
          isTrue,
        );
      });
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

  group('HIS WORD AT THE WHISTLE', () {
    // Nine more shipped strings with no caller — `thriller_*`, `demolition`,
    // `drubbing`, `high_scoring_*`, `nervy_one_nil`, `nil_nil`. They are his
    // read of a RESULT, and `coachReadKey` stops at the 89th minute, so the one
    // moment they were written for was the one moment he had nothing to say.

    test('the two scorelines the copy names outright', () {
      // Both are also "not many goals", so a general rule would swallow them —
      // which is why they are tested first in the function too.
      expect(fullTimeReactionKey(ours: 0, theirs: 0), 'commentary.nil_nil');
      expect(
        fullTimeReactionKey(ours: 1, theirs: 0),
        'commentary.nervy_one_nil',
      );
      // And 0-1 is NOT the one-nil line from the other end: the copy is "three
      // points is three points".
      expect(fullTimeReactionKey(ours: 0, theirs: 1), isNull);
    });

    test('three clear is a hiding, however many were scored', () {
      for (final (o, t) in const [(3, 0), (4, 1), (5, 2), (7, 0)]) {
        expect(fullTimeReactionKey(ours: o, theirs: t), 'commentary.demolition',
            reason: '$o-$t');
      }
      for (final (o, t) in const [(0, 3), (1, 4), (2, 5)]) {
        expect(fullTimeReactionKey(ours: o, theirs: t), 'commentary.drubbing',
            reason: '$o-$t');
      }
    });

    test('A THRILLER IS CLOSE FIRST AND HIGH-SCORING SECOND', () {
      // 3-3 has six goals in it, and "goals everywhere but we got the result"
      // is not a thing to say about a draw — which is why the close test runs
      // before the high-scoring one.
      expect(fullTimeReactionKey(ours: 3, theirs: 3), 'commentary.thriller_draw');
      expect(fullTimeReactionKey(ours: 2, theirs: 2), 'commentary.thriller_draw');
      expect(fullTimeReactionKey(ours: 2, theirs: 1), 'commentary.thriller_win');
      expect(fullTimeReactionKey(ours: 4, theirs: 3), 'commentary.thriller_win');
      expect(fullTimeReactionKey(ours: 1, theirs: 2), 'commentary.thriller_loss');
    });

    test('and only a two-goal margin reaches the high-scoring pair', () {
      expect(
        fullTimeReactionKey(ours: 4, theirs: 2),
        'commentary.high_scoring_win',
      );
      expect(
        fullTimeReactionKey(ours: 2, theirs: 4),
        'commentary.high_scoring_loss',
      );
    });

    test('HE IS QUIET AFTER AN ORDINARY ONE, which is most of them', () {
      // A line on every full time is a line nobody reads — the rule
      // `squadStateHint` follows when it stays quiet.
      for (final (o, t) in const [(1, 1), (2, 0), (0, 2), (0, 1)]) {
        expect(fullTimeReactionKey(ours: o, theirs: t), isNull, reason: '$o-$t');
      }
    });

    test('EVERY KEY IT CAN RETURN EXISTS, in every language', () {
      // The whole point of this is reaching copy that already ships. A key that
      // resolves to itself is a sentence nobody wrote.
      final reached = <String>{};
      for (var o = 0; o <= 8; o++) {
        for (var t = 0; t <= 8; t++) {
          final key = fullTimeReactionKey(ours: o, theirs: t);
          if (key != null) reached.add(key);
        }
      }
      expect(reached, hasLength(9), reason: 'one of the nine is unreachable');
      for (final locale in localeIds) {
        setLocale(locale);
        addTearDown(resetLocale);
        for (final key in reached) {
          final line = t(key, const {'us': 1, 'them': 0, 'opp': 'Ayton'});
          expect(line, isNot(key), reason: '$key missing in $locale');
          expect(line, isNot(contains('{')), reason: '$key unfilled in $locale');
        }
      }
    });
  });


}
