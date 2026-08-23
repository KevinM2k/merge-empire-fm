/// When the game asks to be rated — and, mostly, when it does not.
///
/// **The restraint is the whole feature.** There is no custom dialog any more
/// (the JS dropped it), so nothing between this engine and Apple's own sheet —
/// and Apple silently declines to show it when asked too often, which means a
/// game that over-asks is not told it has stopped working.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/rating_prompt.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

const int _t0 = 1700000000000;

Map<String, dynamic> _save({
  String status = 'pending',
  int promptCount = 0,
  int nextPromptAt = 0,
  int matchesPlayed = 20,
}) {
  final s = createDefaultState();
  (s['rating'] as Map<String, dynamic>)
    ..['status'] = status
    ..['promptCount'] = promptCount
    ..['nextPromptAt'] = nextPromptAt;
  (s['progression'] as Map<String, dynamic>)['matchesPlayed'] = matchesPlayed;
  return s;
}

bool _afterWin(
  Map<String, dynamic> s, {
  int home = 3,
  int away = 0,
  bool won = true,
}) => shouldPromptRating(
  s,
  won: won,
  homeGoals: home,
  awayGoals: away,
  now: _t0,
);

void main() {
  group('after a match', () {
    test('A GOOD WIN, and a good win is two goals clear', () {
      expect(_afterWin(_save()), isTrue);
      expect(_afterWin(_save(), home: 2, away: 0), isTrue);
      expect(_afterWin(_save(), home: 1, away: 0), isFalse);
      expect(_afterWin(_save(), home: 3, away: 2), isFalse);
    });

    test('and a defeat or a draw is never the moment', () {
      expect(_afterWin(_save(), won: false), isFalse);
      expect(_afterWin(_save(), won: false, home: 0, away: 3), isFalse);
    });

    test('the goals are OURS, whichever ground it was on', () {
      // `homeGoals` is our goals in the sim engine regardless of the fixture —
      // the JS says so in a comment, and reading it as the home side's would
      // ask for a review after a 0–3 away thrashing.
      expect(_afterWin(_save(), home: 3, away: 0), isTrue);
    });

    test('NOT UNTIL EIGHT MATCHES have been played', () {
      // A player who has not finished eight games has not seen enough of it to
      // have a view worth asking for.
      expect(_afterWin(_save(matchesPlayed: 7)), isFalse);
      expect(_afterWin(_save(matchesPlayed: 8)), isTrue);
    });
  });

  group('going up', () {
    test('needs no win threshold — the promotion IS the good news', () {
      expect(shouldPromptRatingOnPromotion(_save(), now: _t0), isTrue);
      // And it does not care how many matches: a promotion cannot happen in
      // fewer than a season's worth anyway.
      expect(
        shouldPromptRatingOnPromotion(_save(matchesPlayed: 0), now: _t0),
        isTrue,
      );
    });
  });

  group('the three that stop both of them', () {
    test('an opt-out is FOREVER', () {
      for (final status in ['never', 'done']) {
        expect(_afterWin(_save(status: status)), isFalse, reason: status);
        expect(
          shouldPromptRatingOnPromotion(_save(status: status), now: _t0),
          isFalse,
          reason: status,
        );
      }
      // 'later' is not an opt-out — it is a cooldown, which the next test owns.
      expect(_afterWin(_save(status: 'later')), isTrue);
    });

    test('the cooldown is a week and it is checked against NOW', () {
      expect(_afterWin(_save(nextPromptAt: _t0 + 1)), isFalse);
      expect(_afterWin(_save(nextPromptAt: _t0)), isTrue);
    });

    test('AND THE CAP IS A LIFETIME ONE, five asks ever', () {
      // Apple rate-limits the sheet to about three a year and shows nothing
      // when it declines, so over-asking fails silently. This is the only thing
      // that stops it.
      expect(_afterWin(_save(promptCount: 4)), isTrue);
      expect(_afterWin(_save(promptCount: 5)), isFalse);
      expect(
        shouldPromptRatingOnPromotion(_save(promptCount: 5), now: _t0),
        isFalse,
      );
    });
  });

  group('recording it', () {
    test('SHOWN spends a prompt and starts the week', () {
      // On the asking rather than on the answer, because the OS never tells us
      // what the player chose.
      final s = _save();
      recordRatingShown(s, now: _t0);
      final r = s['rating'] as Map<String, dynamic>;
      expect(r['promptCount'], 1);
      expect(r['lastPromptAt'], _t0);
      expect(r['nextPromptAt'], _t0 + ratingCooldownMs);
      expect(_afterWin(s), isFalse, reason: 'asked twice in one moment');
    });

    test('and a decision is one of three', () {
      final later = _save();
      recordRatingDecision(later, 'later', now: _t0);
      expect((later['rating'] as Map)['status'], 'later');
      expect((later['rating'] as Map)['nextPromptAt'], _t0 + ratingCooldownMs);

      final never = _save();
      recordRatingDecision(never, 'never', now: _t0);
      expect((never['rating'] as Map)['status'], 'never');

      final done = _save();
      recordRatingDecision(done, 'done', now: _t0);
      expect((done['rating'] as Map)['status'], 'done');
    });

    test('and a save with no rating block grows one rather than throwing', () {
      // A save from before the block existed, which migration may not have
      // reached yet.
      final s = createDefaultState()..remove('rating');
      expect(_afterWin(s), isFalse, reason: 'nothing to decide with');
      recordRatingShown(s, now: _t0);
      expect((s['rating'] as Map)['promptCount'], 1);
    });
  });
}
