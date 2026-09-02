/// The 2D cutaway's geometry and its script table.
///
/// Both halves are pure arithmetic and pure data, which is exactly where a
/// mirroring bug hides: a sequence that reads correctly attacking right and
/// puts the ball in our own net attacking left costs nothing at compile time
/// and is invisible until someone watches a match from the other end.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/idle_pitch_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';

/// **The real shape, not a stub.** It was declared locally so this file did not
/// need a whole match result to test one mapping — and then the timeline grew a
/// field and the two silently stopped being the same thing.
TimelineEvent _event(
  String type, {
  String? shotResult,
  int minute = 10,
  bool big = false,
  double xg = 0,
}) => (
  minute: minute,
  type: type,
  team: 'home',
  scorer: null,
  scorerId: null,
  textKey: null,
  shotResult: shotResult,
  big: big,
  xg: xg,
  player: null,
  params: const {},
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

    test('EVERY PASS HAS SOMEBODY TO RECEIVE IT', () {
      // The ghost hits. A pass that named no `run` got no BODY — but it still
      // got a receiver index, and the index landed on whoever was nearest the
      // end of the list, which is very often the man doing the passing. He was
      // then told to run onto his own pass, so the ball crossed the pitch to a
      // patch of empty grass and waited there for him. `tiki_box` was one man
      // passing to himself three times.
      for (final seq in cutawaySequences) {
        final cast = castFor(seq);
        var carrier = 0;
        for (var i = 0; i < seq.play.length; i++) {
          final beat = seq.play[i];
          if (beat is! Pass) continue;
          final receiver = cast.receiverAt[i];
          expect(
            receiver,
            greaterThanOrEqualTo(0),
            reason: '${seq.id} beat $i: nobody was assigned the ball',
          );
          expect(
            receiver,
            lessThan(cast.starts.length),
            reason: '${seq.id} beat $i: receiver $receiver has no body',
          );
          expect(
            receiver,
            isNot(carrier),
            reason: '${seq.id} beat $i: he passed it to himself',
          );
          carrier = receiver;
        }
      }
    });

    test('and a receiver RUNS ONTO it rather than standing on it', () {
      // A receiver already on the spot makes the ball arrive at a statue, which
      // is what the `run` field is for. A pass that names none gets the same
      // treatment rather than none at all.
      for (final seq in cutawaySequences) {
        final cast = castFor(seq);
        for (var i = 0; i < seq.play.length; i++) {
          final beat = seq.play[i];
          if (beat is! Pass || beat.who != null) continue;
          final start = cast.starts[cast.receiverAt[i]];
          expect(
            start.p == beat.to.p && start.q == beat.to.q,
            isFalse,
            reason: '${seq.id} beat $i: the receiver starts on the ball',
          );
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

    test('AND THE POST GETS HIT — on the JS\'s own odds', () {
      // `_resolveOutcome` in `ChanceCutaway.js`: on target, 58% saved, 18%
      // over, the rest woodwork. Off target it is wide, over, woodwork, and a
      // block the port folds into wide. It used to be a save or wide and
      // nothing else, so `woodwork` never had a picture to play under.
      final on = _event('chance', shotResult: 'on_target');
      expect(outcomeForEvent(on, roll: 0.5), CutawayOutcome.saved);
      expect(outcomeForEvent(on, roll: 0.6), CutawayOutcome.over);
      expect(outcomeForEvent(on, roll: 0.8), CutawayOutcome.post);
      final off = _event('chance', shotResult: 'off');
      expect(outcomeForEvent(off, roll: 0.1), CutawayOutcome.wide);
      expect(outcomeForEvent(off, roll: 0.4), CutawayOutcome.over);
      expect(outcomeForEvent(off, roll: 0.7), CutawayOutcome.post);
      expect(outcomeForEvent(off, roll: 0.9), CutawayOutcome.wide);
      // A goal is a goal whatever the roll.
      expect(outcomeForEvent(_event('goal'), roll: 0.99), CutawayOutcome.goal);
    });

    test('and the feed line follows the ending', () {
      expect(commentaryKeyFor(CutawayOutcome.post), 'commentary.hit_post');
      expect(commentaryKeyFor(CutawayOutcome.over), 'commentary.shot_over');
      expect(commentaryKeyFor(CutawayOutcome.wide), 'commentary.shot_wide');
      expect(
        commentaryKeyFor(CutawayOutcome.tackled),
        'commentary.dispossessed',
      );
      expect(commentaryKeyFor(CutawayOutcome.saved), 'commentary.forces_save');
    });

    test('a whistle is not something you watch', () {
      // Half time and full time have no passage of play, and a clip for one
      // would be a chance the match never had.
      expect(outcomeForEvent(_event('halftime')), isNull);
      expect(outcomeForEvent(_event('fulltime')), isNull);
      expect(outcomeForEvent(_event('commentary')), isNull);
    });
  });

  group('WHEN THE PITCH COMES ON, and when it does not', () {
    CutawayClip? cut(
      TimelineEvent e, {
      bool ours = true,
      bool ourTeamOn = true,
      bool opponentOn = true,
      int? last,
    }) => clipFor(
      e,
      ourSideLeft: true,
      ours: ours,
      seed: 7,
      ourTeamOn: ourTeamOn,
      opponentOn: opponentOn,
      lastCutawayMinute: last,
    );

    test('THE TWO SWITCHES ON THE SETTINGS SCREEN DID NOTHING', () {
      // `cutawayOurTeam` and `cutawayOpponent` are in the schema, in the
      // migration and on Settings as two INDEPENDENT flags — the cutaway can be
      // on for both sides, one, or neither — and nothing here read either.
      expect(cut(_event('goal'), ourTeamOn: false), isNull);
      expect(cut(_event('goal'), ours: false, opponentOn: false), isNull);
      // Independent: our side off does not silence theirs.
      expect(cut(_event('goal'), ours: false, ourTeamOn: false), isNotNull);
    });

    test('and a SMALL chance is a statistic, not a passage of play', () {
      // The engine makes one about every seven minutes. Cutting to all of them
      // is a cutaway with a match happening somewhere behind it.
      expect(cut(_event('chance', xg: 0.1, shotResult: 'on_target')), isNull);
      expect(
        cut(_event('chance', xg: 0.25, shotResult: 'on_target')),
        isNotNull,
      );
      expect(cut(_event('chance', big: true, shotResult: 'off')), isNotNull);
    });

    test('and there is a GAP between chances, which a goal is exempt from', () {
      final big = _event('chance', minute: 20, big: true);
      expect(cut(big, last: 12), isNull, reason: 'eight minutes is too soon');
      expect(cut(big, last: 8), isNotNull, reason: 'twelve minutes is enough');
      // A goal is always worth showing.
      expect(cut(_event('goal', minute: 20), last: 19), isNotNull);
    });
  });
  group('THE BALL HAS TO ARRIVE AT SOMEBODY', () {
    // **A receiver is a body steering at his own pace; the ball is a tween on a
    // fixed duration.** Two clocks with nothing keeping them together, so a
    // through ball outran its runner and landed on empty grass — and a
    // `firstTime` finish then fired from a spot with no player on it. Watched
    // from the couch that is "the ball goes to an invisible player who scores".

    test('a run he cannot make at his own pace speeds him up', () {
      final pace = meetPace(distance: 30, seconds: 0.6, basePace: 1);
      expect(pace, greaterThan(1));
    });

    test('and a short square ball does NOT make him amble', () {
      // Never slower than his own legs: the floor is his pace, not the
      // arithmetic's answer.
      expect(meetPace(distance: 1, seconds: 3, basePace: 1.1), 1.1);
    });

    test('IT IS CAPPED, because a blink across the pitch is worse', () {
      // A runner who cannot make it in time is a script asking for a run
      // nobody could make; arriving a beat late reads better than teleporting.
      expect(meetPace(distance: 400, seconds: 0.2, basePace: 1), 2.6);
    });

    test('a flight with no length or no time is his own pace', () {
      expect(meetPace(distance: 0, seconds: 1, basePace: 0.9), 0.9);
      expect(meetPace(distance: 10, seconds: 0, basePace: 0.9), 0.9);
    });

    test('THE MARGIN PAYS FOR THE EASING, so he is early rather than late', () {
      // `Mover` slows over the last `arriveRadius` and accelerates into the
      // first stride, so the straight-line average is below the cruise it is
      // set to. Without the margin he is always a little short.
      final exact = 30 / 0.6 / MoverTuning.baseSpeed;
      expect(
        meetPace(distance: 30, seconds: 0.6, basePace: 0.1),
        greaterThan(exact),
      );
    });
  });

  group('THE PITCH IS FLAT, for now, and everything on it with it', () {
    // The perspective was dropped at the player's request until it works;
    // the projection stays in place at zero so it can come back as two consts.
    test('THE TOUCHLINES ARE THE SAME WIDTH', () {
      // **The sign was wrong and it is the only thing that matters here.**
      // Flutter's +y is DOWN, so a positive `rotateX` pushes the BOTTOM away
      // and pulls the top toward the viewer — the far touchline came out at the
      // bottom of the band, which is a camera lying on the grass behind the
      // near goal. Asserted on the PROJECTION rather than on the constant,
      // because the constant's sign is exactly what nobody can read off.
      const box = Size(300, 160);
      final m = Matrix4.identity()
        ..translateByDouble(box.width / 2, box.height / 2, 0, 1)
        ..setEntry(3, 2, pitchVanish)
        ..rotateX(pitchTilt)
        ..translateByDouble(-box.width / 2, -box.height / 2, 0, 1);
      double widthAt(double y) =>
          MatrixUtils.transformPoint(m, Offset(box.width, y)).dx -
          MatrixUtils.transformPoint(m, Offset(0, y)).dx;
      expect(widthAt(0), closeTo(widthAt(box.height), 0.001));
      expect(pitchVanish, 0);
    });

    test('THE WHOLE PITCH STAYS IN THE BOX, near corners included', () {
      // **A perspective divide makes the near edge WIDER than the box it came
      // from**, so tilting about the centre and stopping there runs both near
      // corners off the sides — and the stronger the tilt, the more of the
      // touchline goes with them. Reported with a screenshot: the near side has
      // to be fully visible and the FAR side is the one that narrows.
      for (final size in const [
        Size(320, 74),
        Size(390, 90),
        Size(600, 138),
      ]) {
        final m = fittedTilt(size);
        final quad = MatrixUtils.transformRect(m, Offset.zero & size);
        expect(quad.left, greaterThan(-0.5), reason: '$size ran off the left');
        expect(
          quad.right,
          lessThan(size.width + 0.5),
          reason: '$size ran off the right',
        );
        expect(quad.top, greaterThan(-0.5), reason: '$size ran off the top');
        expect(
          quad.bottom,
          lessThan(size.height + 0.5),
          reason: '$size ran off the bottom',
        );

        // And the FAR edge is the narrow one, which is the whole shape.
        double widthAt(double y) =>
            MatrixUtils.transformPoint(m, Offset(size.width, y)).dx -
            MatrixUtils.transformPoint(m, Offset(0, y)).dx;
        expect(widthAt(0), closeTo(widthAt(size.height), 0.001), reason: '$size');
      }
    });

    test('AND THE TOUCHLINES ARE INSIDE THE BOX, not on its edge', () {
      // A line on the clip boundary is a line that is not there: the fit put
      // the quad's corners at 0 and at the band's exact height, so the far and
      // near touchlines — one antialiased pixel each — landed half on the
      // `ClipRRect` and half off it. Reported as the pitch missing its top and
      // bottom.
      for (final band in const [Size(360, 130), Size(390, 96), Size(740, 270)]) {
        final plane = Size(band.width, band.width / pitchAspect);
        final quad = MatrixUtils.transformRect(
          fittedTilt(plane, into: band),
          Offset.zero & plane,
        );
        expect(quad.top, greaterThan(1), reason: '$band top');
        expect(quad.bottom, lessThan(band.height - 1), reason: '$band bottom');
        expect(quad.left, greaterThan(1), reason: '$band left');
        expect(quad.right, lessThan(band.width - 1), reason: '$band right');
      }
    });

    test('and an empty box does not divide by zero', () {
      expect(fittedTilt(Size.zero), Matrix4.identity());
    });

    test('and the camera is straight overhead, for now', () {
      expect(pitchTilt, 0, reason: 'the perspective is off until it works');
    });

    testWidgets('AND NOBODY DRIFTS ABOUT BETWEEN CHANCES', (tester) async {
      // **This reverses "the match, between the chances".** The bodies were
      // added because ninety minutes was a green rectangle with an arrow on it
      // — which was true, and the answer turned out to be worse than the
      // problem: twenty-two figures drifting through a passage nobody is being
      // told about is motion carrying no information. Asked for directly.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CutawayStage(clip: null))),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('cutaway-idle')), findsOneWidget,
          reason: 'the markings went with them');
      expect(find.byKey(const ValueKey('cutaway-idle-game')), findsNothing);
    });

    testWidgets('ONE TRANSFORM over the markings AND the game', (tester) async {
      // **The reason it could not be a photograph in a trapezoid.** Everything
      // on the grass has to sit in the same projection, and the only way to get
      // that without teaching each of them about it is to apply the projection
      // once, to all of them together.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CutawayStage(clip: null)),
        ),
      );
      await tester.pump();
      final tilted = find.ancestor(
        of: find.byKey(const ValueKey('cutaway-idle')),
        matching: find.byType(Transform),
      );
      expect(tilted, findsWidgets);
    });

    testWidgets('AND THE LAYERS ARE LAID OUT AT THE PITCH\'S OWN SHAPE', (
      tester,
    ) async {
      // **This is the two-pitches bug, and it is a LAYOUT one.** The band is a
      // wide shallow strip; the plane the tilt is fitted from keeps the pitch's
      // aspect. The layers were inside a `SizedBox` under a tight expand, which
      // a `SizedBox` cannot widen — so the markings stretched to the band while
      // Flame, fitting `visibleGameSize` preserving aspect, letterboxed itself
      // inside them. A small pitch of players in a wide pitch of markings.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 130,
                child: CutawayStage(clip: null),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final size = tester.getSize(find.byKey(const ValueKey('cutaway-idle')));
      expect(size.width, closeTo(360, 0.5));
      expect(
        size.height,
        closeTo(360 / pitchAspect, 0.5),
        reason: 'the band is 130 tall; the PLANE is not',
      );
    });
  });

  group('THE MATCH, BETWEEN THE CHANCES', () {
    // The twenty-two bodies used to exist only for the two or three seconds of
    // a scripted chance, so ninety minutes of football was a green rectangle
    // with an arrow on it and a clip arrived out of an empty field. Reported
    // three times across three sittings.

    test('THE SHAPE SLIDES WITH THE MOMENTUM, both ways', () {
      const base = (p: 0.5, q: 0.5);
      final up = idleSpotFor(base, bias: 1, wobble: 0);
      final back = idleSpotFor(base, bias: -1, wobble: 0);
      expect(up.p, greaterThan(base.p));
      expect(back.p, lessThan(base.p));
      expect(up.p - base.p, closeTo(idleLineTravel, 1e-9));
    });

    test('and it never leaves the pitch, however hard it is pushed', () {
      for (final spot in idleShape) {
        for (final bias in [-4.0, -1.0, 0.0, 1.0, 4.0]) {
          for (final wobble in [-1.0, 0.0, 1.0]) {
            final out = idleSpotFor(spot, bias: bias, wobble: wobble);
            expect(out.p, inInclusiveRange(0, 1));
            expect(out.q, inInclusiveRange(0, 1));
          }
        }
      }
    });

    test('ELEVEN A SIDE, in the same space the sequences use', () {
      // A body drifting here and a body in a clip are on the same pitch, which
      // is what makes the handover cost nothing.
      expect(idleShape, hasLength(11));
      for (final spot in idleShape) {
        expect(spot.p, inInclusiveRange(0, 1));
        expect(spot.q, inInclusiveRange(0, 1));
      }
    });

    testWidgets('IT IS OFF UNDER REDUCED MOTION, and the markings are not', (
      tester,
    ) async {
      // Policy rather than a test convenience: a pitch of drifting bodies is
      // motion and nothing on it is information.
      final momentum = ValueNotifier<double>(0);
      addTearDown(momentum.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: CutawayStage(clip: null, momentum: momentum)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('cutaway-idle')), findsOneWidget);
      expect(find.byKey(const ValueKey('cutaway-idle-game')), findsNothing);
    });

    testWidgets('and a stage with no momentum draws the markings alone', (
      tester,
    ) async {
      // Which is what every test that is not about the idle pitch wants.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CutawayStage(clip: null))),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('cutaway-idle')), findsOneWidget);
      expect(find.byKey(const ValueKey('cutaway-idle-game')), findsNothing);
    });
  });

}
