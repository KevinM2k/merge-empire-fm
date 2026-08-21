/// The 2D cutaway's geometry and its script table.
///
/// Both halves are pure arithmetic and pure data, which is exactly where a
/// mirroring bug hides: a sequence that reads correctly attacking right and
/// puts the ball in our own net attacking left costs nothing at compile time
/// and is invisible until someone watches a match from the other end.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';

/// **The real shape, not a stub.** It was declared locally so this file did not
/// need a whole match result to test one mapping — and then the timeline grew a
/// field and the two silently stopped being the same thing.
TimelineEvent _event(String type, {String? shotResult}) => (
  minute: 10,
  type: type,
  team: 'home',
  scorer: null,
  textKey: null,
  shotResult: shotResult,
  big: false,
  xg: 0,
  player: null,
);

void main() {
  group('attack space', () {
    test('the goal being attacked is at the far end, both ways', () {
      // p = 1.05 IS the goal line. Attacking right it is x = 200; attacking
      // left it is x = 0. Getting this backwards scores every chance at the
      // wrong end.
      final right = toPitch((p: 1.05, q: 0.5), attackingRight: true);
      final left = toPitch((p: 1.05, q: 0.5), attackingRight: false);
      expect(right.x, closeTo(pitchWidth, 0.01));
      expect(left.x, closeTo(0, 0.01));
    });

    test('own goal is the near end, both ways', () {
      expect(toPitch((p: 0, q: 0.5), attackingRight: true).x, closeTo(0, 0.01));
      expect(
        toPitch((p: 0, q: 0.5), attackingRight: false).x,
        closeTo(pitchWidth, 0.01),
      );
    });

    test('the centre is the centre whichever way you shoot', () {
      final right = toPitch((p: 0.525, q: 0.5), attackingRight: true);
      final left = toPitch((p: 0.525, q: 0.5), attackingRight: false);
      expect(right.x, closeTo(pitchWidth / 2, 0.01));
      expect(left.x, closeTo(pitchWidth / 2, 0.01));
      expect(right.y, closeTo(pitchHeight / 2, 0.01));
      expect(left.y, closeTo(pitchHeight / 2, 0.01));
    });

    test('lateral flips with the direction, so left wing stays left wing', () {
      // q is the ATTACKER's left-to-right, so mirroring p has to mirror q with
      // it — otherwise a script's inside-right channel becomes inside-left the
      // moment the teams change ends.
      final right = toPitch((p: 0.5, q: 0.2), attackingRight: true);
      final left = toPitch((p: 0.5, q: 0.2), attackingRight: false);
      expect(right.y + left.y, closeTo(pitchHeight, 0.01));
    });
  });

  group('the script table', () {
    test('every sequence starts somewhere and ends in a shot or a foul', () {
      for (final seq in cutawaySequences) {
        expect(seq.play.first, isA<Start>(), reason: seq.id);
        final last = seq.play.last;
        if (seq.freeKick) {
          expect(last, isA<Dribble>(), reason: seq.id);
          expect((last as Dribble).fouled, isTrue, reason: seq.id);
        } else {
          expect(last, isA<Finish>(), reason: seq.id);
        }
      }
    });

    test('every beat stays on the pitch', () {
      // A p past 1.05 is behind the goal line and a q outside 0..1 is off the
      // park — either is a body or a ball leaving the frame.
      for (final seq in cutawaySequences) {
        for (final beat in seq.play) {
          final points = <AttackPoint>[
            if (beat is Start) beat.at,
            if (beat is Pass) beat.to,
            if (beat is Pass && beat.run != null) beat.run!,
            if (beat is Dribble) beat.to,
          ];
          for (final at in points) {
            expect(at.p, inInclusiveRange(0, 1.05), reason: seq.id);
            expect(at.q, inInclusiveRange(0, 1), reason: seq.id);
          }
        }
      }
    });

    test('every finish names a style the game knows how to strike', () {
      for (final seq in cutawaySequences) {
        for (final beat in seq.play) {
          if (beat is Finish) {
            expect(finishStyles, contains(beat.style), reason: seq.id);
          }
          if (beat is Pass) {
            expect(passStyles, contains(beat.kind), reason: seq.id);
          }
        }
      }
    });

    test('a one-two re-targets somebody who has already touched it', () {
      for (final seq in cutawaySequences) {
        for (var i = 0; i < seq.play.length; i++) {
          final beat = seq.play[i];
          if (beat is Pass && beat.who != null) {
            // `who: 0` is the original carrier, so any index up to the number of
            // attackers named so far is reachable.
            expect(beat.who, greaterThanOrEqualTo(0), reason: seq.id);
            expect(i, greaterThan(0), reason: seq.id);
          }
        }
      }
    });

    test('ids are unique', () {
      final ids = cutawaySequences.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('a steal is played the other way, toward their own goal', () {
      // The whole point of a turnover: they carry it toward THEIR end, so `to`
      // must be a lower p than `from`. Reversed, the clip opens with the
      // opponent attacking our goal and giving it away for no reason.
      for (final seq in cutawaySequences) {
        final steal = seq.steal;
        if (steal == null) continue;
        expect(steal.to.p, lessThan(steal.from.p), reason: seq.id);
        expect(steal.cut, inInclusiveRange(0, 1), reason: seq.id);
      }
    });
  });

  group('picking one', () {
    test('a roll at either extreme still returns a sequence', () {
      expect(pickSequence(0), isNotNull);
      expect(pickSequence(1), isNotNull);
      expect(pickSequence(0.999999), isNotNull);
    });

    test('the same roll picks the same passage', () {
      // A replay has to reproduce the chance it is replaying.
      expect(pickSequence(0.42).id, pickSequence(0.42).id);
    });

    test(
      'weight is respected — a heavier sequence covers more of the range',
      () {
        final counts = <String, int>{};
        for (var i = 0; i < 1000; i++) {
          final id = pickSequence(i / 1000).id;
          counts[id] = (counts[id] ?? 0) + 1;
        }
        // `cross_right_header` is the heaviest at 2.0; `fk_edge` the lightest at
        // 0.5. The order has to follow the weights.
        expect(counts['cross_right_header']!, greaterThan(counts['fk_edge']!));
      },
    );
  });

  group('what a feed event looks like on the pitch', () {
    test('a goal is a goal', () {
      expect(outcomeForEvent(_event('goal')), CutawayOutcome.goal);
    });

    test('an on-target chance is a save, and anything else is a miss', () {
      expect(
        outcomeForEvent(_event('chance', shotResult: 'on_target')),
        CutawayOutcome.saved,
      );
      expect(
        outcomeForEvent(_event('chance', shotResult: 'off')),
        CutawayOutcome.wide,
      );
    });

    test('a whistle is not something you watch', () {
      // Half time and full time have no passage of play, and a clip for one
      // would be a chance the match never had.
      expect(outcomeForEvent(_event('halftime')), isNull);
      expect(outcomeForEvent(_event('fulltime')), isNull);
      expect(outcomeForEvent(_event('commentary')), isNull);
    });
  });
}
