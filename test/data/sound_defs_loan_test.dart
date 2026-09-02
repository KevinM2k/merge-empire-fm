/// The loan stars' own cues.
///
/// **A beep per star, rising**, over the arrival the tutorial already animates.
/// The departure has had its `pop` since the cards started coming apart; the
/// arrival, which is the longer and better-looking of the two, had nothing.
/// Asked for from the couch.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/sound_defs.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/ui/screens/grid/loan_arrival.dart';

void main() {
  test('THERE IS A RUNG FOR EVERY STAR THE LOAN CAN LEND', () {
    // The loan fills an eleven-man side and the player always owns at least one
    // by the time it runs, so eleven is the ceiling and the scale must clear it.
    final mostLent = tutorialSquadTarget.values.reduce((a, b) => a + b);
    expect(loanStarScale.length, greaterThanOrEqualTo(mostLent));
  });

  test('AND EVERY ONE OF THEM IS A REAL EFFECT', () {
    // A cue with no recipe is silence, which is what this whole change was
    // about — and `play` swallows a missing name rather than throwing, so
    // nothing else in the game would ever say so.
    for (var i = 0; i < loanStarScale.length; i++) {
      final def = soundDefs[loanStarCue(i)];
      expect(def, isNotNull, reason: 'no recipe for rung $i');
      expect(def!.seconds, greaterThan(0));
    }
  });

  test('THEY RISE, and each is its OWN cue', () {
    // Rising is the whole brief. And they are separate names rather than one
    // retriggered because `retriggerFloor` collapses two requests for the same
    // name inside 70ms — which is exactly what a run up a scale is.
    for (var i = 1; i < loanStarScale.length; i++) {
      expect(
        loanStarScale[i],
        greaterThan(loanStarScale[i - 1]),
        reason: 'rung $i does not rise',
      );
      expect(loanStarCue(i), isNot(loanStarCue(i - 1)));
    }
  });

  /// **THE RUN IS THE ARRIVAL'S OWN LADDER.**
  ///
  /// `_loanArrivals` hands card `i` a delay of `loanArrivalStagger * i` off the
  /// same save write the chime starts on, so the two clocks share a zero. The
  /// first cut waited a whole `loanArrivalDuration` first — 1200ms against a
  /// 500ms stagger, two and a half cards of head start — so the beeps began as
  /// the third gold player came in and the last two sounded after every card had
  /// arrived. Reported from the couch in exactly those terms.
  test('AND IT KEEPS STEP WITH THE CARDS, rather than trailing them', () {
    // Whatever the two numbers become, a lead of more than one card is the
    // defect: the run has to start on the first player, not the third.
    expect(
      loanArrivalStagger.inMilliseconds,
      greaterThan(0),
      reason: 'no ladder to keep step with',
    );
    // Eleven beeps at the stagger fit inside the window the step holds for, so
    // none of them can sound after the whole loan has landed.
    const most = 11;
    expect(
      loanArrivalStagger * most,
      lessThanOrEqualTo(loanArrivalWindow(most)),
      reason: 'the last beeps land after the last card',
    );
  });

  test('and a run past the end sits on the top rung rather than throwing', () {
    expect(loanStarCue(999), loanStarCue(loanStarScale.length - 1));
    expect(loanStarCue(-1), loanStarCue(0));
  });

  test('THE SCALE HAS NO SEMITONE IN IT', () {
    // A major pentatonic, which is the point: any run up it is consonant
    // however far it gets and whatever it is played over. Pitching one cue by a
    // fixed ratio instead is what makes a rising run sound like a modem.
    for (var i = 1; i < loanStarScale.length; i++) {
      // Every step is a whole tone or more — 2^(2/12) = 1.1225.
      final ratio = loanStarScale[i] / loanStarScale[i - 1];
      expect(ratio, greaterThan(1.12), reason: 'step $i is a semitone');
    }
  });

  group('AND THE DEPARTURE IS A SHATTER, not a pop', () {
    // `pop` is a 0.09s sine sweep — the sound of a bubble, right for a tutorial
    // tap and wrong for eleven borrowed players being recalled. The queue read
    // this as needing audio rather than code, and that was the wrong read:
    // every cue in `sound_defs.dart` is SYNTHESISED, so the proper one is a
    // build function like the rest of them.
    test('there is a recipe for it', () {
      final def = soundDefs['shatter'];
      expect(def, isNotNull);
      expect(def!.seconds, greaterThan(0));
    });

    test('and it is a longer, bigger thing than the pop it replaces', () {
      // A break has a tail. A bubble does not — that is the whole difference.
      final shatter = soundDefs['shatter']!;
      final pop = soundDefs['pop']!;
      expect(shatter.seconds, greaterThan(pop.seconds * 3));
    });

    test('and it RENDERS, which is the only proof that matters', () {
      // A recipe that throws or produces nothing is silence, and `play`
      // swallows a missing name rather than saying so.
      final wav = renderAllSounds()['shatter'];
      expect(wav, isNotNull);
      expect(wav!.length, greaterThan(1000));
    });
  });
}
