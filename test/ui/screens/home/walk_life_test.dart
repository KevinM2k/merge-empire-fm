/// The glances between gestures.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/home/walk_life.dart';

void main() {
  test('the cycle is half a minute of uneven beats', () {
    expect(lifeCycleSeconds, greaterThan(25));
    expect(lifeCycleSeconds, lessThan(45));
    final lengths = lifeCycle.map((b) => b.seconds).toSet();
    expect(lengths.length, greaterThan(4), reason: 'a metronome');
  });

  test('he is looking forwards most of the time', () {
    var still = 0;
    const n = 600;
    for (var i = 0; i < n; i++) {
      final at = walkLifeAt(lifeCycleSeconds * i / n);
      if (at.head.abs() < 0.01 && at.gaze.distance < 0.01) still++;
    }
    expect(still / n, greaterThan(0.45));
    expect(still / n, lessThan(0.85), reason: 'he never does anything');
  });

  test('every move is small and comes back to level', () {
    for (var i = 0; i <= 2000; i++) {
      final at = walkLifeAt(lifeCycleSeconds * i / 2000);
      expect(at.head.abs(), lessThanOrEqualTo(9), reason: 'head at $i');
      expect(at.gaze.dx.abs(), lessThanOrEqualTo(1));
      expect(at.gaze.dy.abs(), lessThanOrEqualTo(1));
    }
    // Every beat starts and ends at rest, so consecutive beats cannot jump.
    var t = 0.0;
    for (final beat in lifeCycle) {
      expect(walkLifeAt(t + 0.001).head.abs(), lessThan(0.5), reason: 'start');
      expect(walkLifeAt(t + beat.seconds - 0.001).head.abs(), lessThan(0.5));
      t += beat.seconds;
    }
  });

  test('he looks UP at the stand and DOWN at the grass', () {
    var t = 0.0;
    for (final beat in lifeCycle) {
      final mid = walkLifeAt(t + beat.seconds / 2);
      switch (beat.action) {
        case LifeAction.lookUp || LifeAction.survey:
          expect(mid.head, lessThan(-4), reason: '${beat.action}');
          expect(mid.gaze.dy, lessThan(0), reason: 'eyes go up too');
        case LifeAction.lookDown:
          expect(mid.head, greaterThan(4));
          expect(mid.gaze.dy, greaterThan(0));
        case LifeAction.glanceBack:
          expect(mid.head, 0, reason: 'eyes only');
          expect(mid.gaze.dx, lessThan(-0.5));
        case LifeAction.nod || LifeAction.none:
          break;
      }
      t += beat.seconds;
    }
  });

  test('the eyes lead the head', () {
    // Early in a look-up the gaze is already most of the way there and the
    // head has barely started.
    var t = 0.0;
    for (final beat in lifeCycle) {
      if (beat.action == LifeAction.lookUp) {
        final early = walkLifeAt(t + 0.15);
        expect(early.gaze.dy.abs(), greaterThan(0.4));
        expect(early.head.abs(), lessThan(lifeLookUp.abs() * 0.5));
      }
      t += beat.seconds;
    }
  });

  test('it wraps and survives nonsense', () {
    expect(walkLifeAt(lifeCycleSeconds * 3 + 1.2), walkLifeAt(1.2));
    expect(walkLifeAt(-2), walkLifeAt(lifeCycleSeconds - 2));
    expect(walkLifeAt(double.nan).head, 0);
  });

  test('HE TURNS at the waist to look at the stand', () {
    var t = 0.0;
    for (final beat in lifeCycle) {
      final mid = walkLifeAt(t + beat.seconds / 2);
      switch (beat.action) {
        case LifeAction.lookUp || LifeAction.survey:
          expect(mid.turn, lessThan(-0.3), reason: '${beat.action}');
        case _:
          expect(mid.turn, 0, reason: '${beat.action}');
      }
      // And it starts and ends square, like everything else.
      expect(walkLifeAt(t + 0.001).turn.abs(), lessThan(0.05));
      t += beat.seconds;
    }
    for (var i = 0; i <= 500; i++) {
      expect(walkLifeAt(lifeCycleSeconds * i / 500).turn.abs(), lessThanOrEqualTo(1));
    }
  });
}
