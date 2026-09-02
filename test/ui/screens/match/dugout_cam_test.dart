/// The dugout cam — the picture, not the policy. `dugout_cam_policy_test.dart`
/// holds when it may come up and what he plays into the lens.
///
/// Three things here are worth a test and nothing else on the screen is:
///
/// **The crop**, because it is four derived numbers and the bounds are what
/// hold the gestures. Tighten it and the emote somebody paid for is the thing
/// that gets cropped — which looks, on screen, like a manager who does not
/// react.
///
/// **The idle**, because it is a pixel and a half of movement and the only way
/// to see it fail is that he stops looking alive. The tuning table is five
/// moods of nine numbers and a transposed column would be the right tempo for
/// the wrong mood.
///
/// **How long the shot lives**, because the float and the inline are the same
/// widget with different lifetimes, and the inline one runs forever on purpose.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart'
    show managerArtHeight, managerArtWidth;
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_idle.dart';
import 'package:merge_empire_fc/ui/screens/match/dugout_cam.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

const Color _kit = Color(0xFF4CAF50);

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

Future<void> pumpCam(
  WidgetTester tester, {
  Mood mood = Mood.neutral,
  Gesture? gesture,
  String? minute = "62'",
  CamTone tone = CamTone.flat,
  CamVariant variant = CamVariant.float,
  CamRota? rota,
  VoidCallback? onDone,
  double width = 180,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DugoutCam(
              mood: mood,
              kit: _kit,
              skin: const Color(0xFFEEBB8C),
              hair: const Color(0xFF3A2A1C),
              gesture: gesture,
              minute: minute,
              tone: tone,
              variant: variant,
              rota: rota,
              onDone: onDone,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The walker the cam is drawing, as it was handed to it.
ManagerWalker walkerOf(WidgetTester tester) =>
    tester.widget<ManagerWalker>(find.byType(ManagerWalker));

Gesture gestureById(String id) => gestures.firstWhere((g) => g.id == id);

void main() {
  tearDown(resetLocale);

  testWidgets('THE BENCH AND THE STAND MOVE ON THEIR OWN CLOCK', (tester) async {
    // They were painted once per tone: four men frozen with their arms up
    // behind a manager who was the only living thing in the shot. Reported as
    // the cam needing to be much more animated.
    await pumpCam(tester, tone: CamTone.good);
    double benchPhase() => tester
        .widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is BenchPainter,
          ),
        )
        .painter!
        .let((p) => (p as BenchPainter).phase);
    double crowdPhase() => tester
        .widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is CrowdPainter,
          ),
        )
        .painter!
        .let((p) => (p as CrowdPainter).phase);
    final bench0 = benchPhase();
    final crowd0 = crowdPhase();
    await tester.pump(camLife ~/ 4);
    expect(benchPhase(), isNot(bench0));
    expect(crowdPhase(), isNot(crowd0));
    // And it repaints for it, or the clock is running to nobody.
    expect(
      const BenchPainter(tone: CamTone.good, kit: _kit, phase: 0.2)
          .shouldRepaint(
            const BenchPainter(tone: CamTone.good, kit: _kit, phase: 0.7),
          ),
      isTrue,
    );
  });

  group('the figure', () {
    testWidgets('is the SAME rig, with its legs planted', (tester) async {
      await pumpCam(tester);
      final walker = walkerOf(tester);
      // Standing is not `walking: false`: that is a scene nobody is watching
      // and stops him dead, blink and all.
      expect(walker.standing, isTrue);
      expect(walker.walking, isFalse);
      // And he is never still: the idle is what stops him being a photograph.
      expect(walker.idle, isNotNull);
    });

    testWidgets('is cropped chest-up, at the crop the gestures need', (
      tester,
    ) async {
      await pumpCam(tester, width: 180);
      final view = tester.getSize(
        find.byKey(const ValueKey('dugout-cam-view')),
      );
      // The figure's own box, NOT its bounding rect: it is inside a rotation
      // (the lean and the weight rock), so `getRect` would report the box that
      // rotation sweeps rather than the one the crop is measured against.
      final rig = tester.getSize(find.byType(ManagerWalker));
      final placed = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byType(ManagerWalker),
              matching: find.byType(Positioned),
            )
            .first,
      );

      // The frame is landscape, which is what makes it a broadcast window.
      expect(view.width / view.height, closeTo(camViewAspect, 0.01));

      // One art unit, and it is UNIFORM — the four percentages in the
      // stylesheet are this one number written four ways, and a rig scaled
      // differently in x and y is a man who has been squashed.
      final unit = view.width / camCropWidth;
      expect(rig.width, closeTo(managerArtWidth * unit, 0.5));
      expect(rig.height, closeTo(managerArtHeight * unit, 0.5));

      // x 23 and y 22 of the rig's own box sit at the frame's top-left corner.
      expect(placed.left, closeTo(-camCropLeft * unit, 0.5));
      expect(placed.top, closeTo(-camCropTop * unit, 0.5));

      // **The bounds are what hold the emotes.** The fist pump's hand tops out
      // at y≈26, the point throws a hand to x≈90, the wave reaches (73,29) and
      // the bow swings his head to (71,50) — every one of them inside the
      // window, or the thing somebody bought is what gets cropped.
      final window = Offset.zero & view;
      for (final (x, y) in const [
        (58.0, 26.0),
        (90.0, 40.0),
        (73.0, 29.0),
        (71.0, 50.0),
      ]) {
        expect(
          window.contains(
            Offset(placed.left! + x * unit, placed.top! + y * unit),
          ),
          isTrue,
          reason: 'art ($x, $y) is outside the crop',
        );
      }
    });
  });

  group('standing still, not stood still', () {
    test('the idle is four tracks against the mood\'s own amplitudes', () {
      final tune = camIdle[Mood.neutral]!;
      // Breath: in quickly at 38%, out slowly, and UP — the lift is added to a
      // y that grows downward.
      expect(
        camIdleAt(tune, breath: 0.38, weight: 0, sway: 0, scan: 0).pose.bodyLift,
        closeTo(-tune.breathUnits, 0.001),
      );
      expect(
        camIdleAt(tune, breath: 0, weight: 0, sway: 0, scan: 0).pose.bodyLift,
        closeTo(0, 0.001),
      );
      // **The arms drift about the angles a STANDING man holds them at — and
      // it used to be the WALK's.** `gesture_poses.dart` says what
      // `armNearRest`/`armFarRest` are in as many words: the walk cycle's own
      // mid-swing values, +27 and −27. So the planted figure stood in a walk
      // pose with the clock stopped, one arm forward and one back by fifty-four
      // degrees, and the sway's 1.6 on top of that changed nothing. Reported
      // from the couch: "weird hanging arms, one behind and one in front,
      // almost like it's a pause of him walking forwards."
      final arms = camIdleAt(tune, breath: 0, weight: 0, sway: 0.5, scan: 0).pose;
      expect(arms.armNear, closeTo(camArmNearRest + tune.swayDegrees, 0.001));
      // And slightly out of phase, so the two do not move as one piece: at 44%
      // the far arm is at its own extreme while the near one is still on its
      // way to its.
      final far = camIdleAt(tune, breath: 0, weight: 0, sway: 0.44, scan: 0).pose;
      expect(far.armFar, closeTo(camArmFarRest - tune.swayDegrees * 0.7, 0.001));
      // The scan, which the walker ADDS to the mood's own head carriage.
      expect(
        camIdleAt(tune, breath: 0, weight: 0, sway: 0, scan: 0.3).pose.head,
        closeTo(tune.scanDegrees * 0.85, 0.001),
      );
    });

    test('AND HE IS NOT PAUSED MID-STRIDE — the arms HANG', () {
      // The whole of the report, as the quantity that produces it: the gap
      // between the two arms. The walk's rest pair is 54 degrees apart, which
      // IS a stride; a man standing and watching holds them together, with
      // just enough between them for the far one to read behind the near one.
      for (final mood in Mood.values) {
        final tune = camIdle[mood] ?? camIdle[Mood.neutral]!;
        for (final sway in [0.0, 0.25, 0.44, 0.5, 0.75, 1.0]) {
          final pose = camIdleAt(
            tune,
            breath: 0,
            weight: 0,
            sway: sway,
            scan: 0,
          ).pose;
          final split = (pose.armNear! - pose.armFar!).abs();
          expect(
            split,
            lessThan(18),
            reason: '$mood at sway $sway: the arms are $split degrees apart',
          );
          // But not zero, or the far arm draws inside the near one and he has
          // one arm.
          expect(split, greaterThan(4), reason: '$mood at sway $sway');
        }
      }
    });

    test('and the lean and the weight rock are ONE rotation', () {
      // Both turn about the boots in the stylesheet, so nesting two boxes to
      // do it would be the same rotation written twice.
      final tune = camIdle[Mood.crushed]!;
      expect(
        camIdleAt(tune, breath: 0, weight: 0.5, sway: 0, scan: 0).tilt,
        closeTo(tune.lean + tune.weightDegrees, 0.001),
      );
      expect(
        camIdleAt(tune, breath: 0, weight: 0, sway: 0, scan: 0).tilt,
        closeTo(tune.lean - tune.weightDegrees, 0.001),
      );
    });

    test('a beaten man is slower, smaller — and breathes DEEPER', () {
      // The amplitude goes back UP at crushed on purpose: that is the sigh,
      // and it is the one number in the table that does not run monotonically.
      final moods = [
        Mood.elated,
        Mood.pleased,
        Mood.neutral,
        Mood.glum,
        Mood.crushed,
      ];
      for (var i = 1; i < moods.length; i++) {
        final quick = camIdle[moods[i - 1]]!;
        final slow = camIdle[moods[i]]!;
        for (final pair in [
          (quick.breath, slow.breath),
          (quick.sway, slow.sway),
          (quick.weight, slow.weight),
          (quick.scan, slow.scan),
        ]) {
          expect(
            pair.$2,
            greaterThan(pair.$1),
            reason: '${moods[i]} should idle slower than ${moods[i - 1]}',
          );
        }
        expect(slow.swayDegrees, lessThan(quick.swayDegrees));
        expect(slow.lean, greaterThan(quick.lean));
      }
      expect(
        camIdle[Mood.crushed]!.breathUnits,
        greaterThan(camIdle[Mood.glum]!.breathUnits),
      );
      // Chest out on a good night, head down on a bad one.
      expect(camIdle[Mood.elated]!.lean, lessThan(0));
      expect(camIdle[Mood.crushed]!.lean, greaterThan(0));
    });

    test('every mood has a tuning, so none of them falls back', () {
      for (final mood in Mood.values) {
        expect(camIdle[mood], isNotNull, reason: mood.name);
      }
    });

    testWidgets('and he actually moves — the four clocks are running', (
      tester,
    ) async {
      await pumpCam(tester, mood: Mood.neutral);
      final first = walkerOf(tester).idle!;
      await tester.pump(const Duration(milliseconds: 700));
      final later = walkerOf(tester).idle!;
      expect(later.bodyLift, isNot(closeTo(first.bodyLift!, 0.0001)));
      expect(later.armNear, isNot(closeTo(first.armNear!, 0.0001)));
      expect(later.head, isNot(closeTo(first.head!, 0.0001)));
    });
  });

  group('a gesture over the idle', () {
    test('takes the joints it drives and leaves the rest looping', () {
      // A fist pump is one arm, and the far one should still be drifting.
      const idle = (
        armNear: 20.0,
        armFar: -20.0,
        foreNear: null,
        foreFar: null,
        head: 1.0,
        body: null,
        bodyLift: -0.5,
        legs: null,
        kickThigh: null,
        kickShin: null,
        finger: 0.0,
      );
      const playing = (
        armNear: 80.0,
        armFar: null,
        foreNear: -100.0,
        foreFar: null,
        head: null,
        body: null,
        bodyLift: null,
        legs: null,
        kickThigh: null,
        kickShin: null,
        finger: 1.0,
      );
      final over = poseOverIdle(playing, idle)!;
      expect(over.armNear, 80.0, reason: 'the gesture owns the arm it drives');
      expect(over.armFar, -20.0, reason: 'and the other one keeps drifting');
      expect(over.foreNear, -100.0);
      expect(over.head, 1.0, reason: 'the scan is nobody else\'s business');
      expect(over.bodyLift, -0.5, reason: 'and so is the breath');
      // The finger is an appearance rather than a joint: an idle has no reason
      // to put one out, so it is the gesture's alone.
      expect(over.finger, 1.0);
    });

    test('and with nothing playing the idle IS the pose', () {
      const idle = (
        armNear: 20.0,
        armFar: -20.0,
        foreNear: null,
        foreFar: null,
        head: 1.0,
        body: null,
        bodyLift: -0.5,
        legs: null,
        kickThigh: null,
        kickShin: null,
        finger: 0.0,
      );
      expect(poseOverIdle(null, idle), idle);
    });

    test('with no idle at all it is whatever was playing', () {
      // Every caller but the cam, and the shape the walker was written for.
      expect(poseOverIdle(null, null), isNull);
    });

    testWidgets('the cam hands the walker the gesture it was given', (
      tester,
    ) async {
      final fistpump = gestureById('fistpump');
      await pumpCam(tester, mood: Mood.elated, gesture: fistpump);
      expect(walkerOf(tester).gesture?.gesture.id, 'fistpump');
    });

    testWidgets('and he just stands there when the player owns nothing', (
      tester,
    ) async {
      // A real outcome rather than a failure: `camGesture` only rolls emotes
      // the player OWNS, and that ownership being visible is the point.
      await pumpCam(tester, gesture: null);
      expect(walkerOf(tester).gesture, isNull);
      expect(walkerOf(tester).idle, isNotNull);
    });
  });

  group('how long the shot lives', () {
    testWidgets('a floating window plays one gesture and goes', (tester) async {
      var done = false;
      final applaud = gestureById('applaud');
      await pumpCam(
        tester,
        gesture: applaud,
        onDone: () => done = true,
      );
      // **The whole window is [camWindow] to the millisecond**, because the
      // policy decides whether a late goal gets the camera at all by asking
      // how long this will be up — see `camFitsBeforeFullTime`.
      //
      // Pumped in steps rather than in one jump: a single `pump` of the whole
      // window elapses the fake clock BEFORE it draws, so the exit would be
      // asked to reverse an entry that had never been given a frame to run in,
      // and would find itself already at the start.
      await tester.pump(camIn);
      await tester.pump(
        Duration(milliseconds: applaud.ms) + camHold - const Duration(milliseconds: 1),
      );
      expect(done, isFalse, reason: 'it has not started leaving yet');
      await tester.pump(const Duration(milliseconds: 1));
      expect(done, isFalse, reason: 'and it is still on its way out');
      await tester.pump(camOut);
      await tester.pump(const Duration(milliseconds: 16));
      expect(done, isTrue);
      expect(
        camWindow(Duration(milliseconds: applaud.ms)),
        camIn + Duration(milliseconds: applaud.ms) + camHold + camOut,
      );
    });

    testWidgets('and an inline one does not leave at all', (tester) async {
      var done = false;
      final applaud = gestureById('applaud');
      await pumpCam(
        tester,
        variant: CamVariant.inline,
        gesture: applaud,
        minute: null,
        onDone: () => done = true,
      );
      await tester.pump(
        camWindow(Duration(milliseconds: applaud.ms)) * 3,
      );
      expect(done, isFalse);
      expect(find.byType(ManagerWalker), findsOneWidget);
    });

    testWidgets('the rota keeps him reacting, chained from the END of each '
        'pose', (tester) async {
      final played = <String>[];
      final recents = <List<String>>[];
      await pumpCam(
        tester,
        mood: Mood.crushed,
        variant: CamVariant.inline,
        minute: null,
        gesture: gestureById('handsonhead'),
        rota: (recent) {
          recents.add(List.of(recent));
          return (
            gesture: gestureById(
              recents.length.isOdd ? 'armsfolded' : 'handsonhips',
            ),
            gap: const Duration(milliseconds: 1200),
          );
        },
      );
      played.add(walkerOf(tester).gesture!.gesture.id);

      // The gap is measured from the end of the pose that just played, so a
      // 2.4s pose and a 1.5s one leave the same pause behind them.
      await tester.pump(
        Duration(milliseconds: gestureById('handsonhead').ms) +
            const Duration(milliseconds: 1200),
      );
      played.add(walkerOf(tester).gesture!.gesture.id);
      await tester.pump(
        Duration(milliseconds: gestureById('armsfolded').ms) +
            const Duration(milliseconds: 1200),
      );
      played.add(walkerOf(tester).gesture!.gesture.id);

      expect(played, ['handsonhead', 'armsfolded', 'handsonhips']);
      // And it is told what he has just done, newest first, capped at the
      // memory — avoiding only the previous one leaves A-B-A-B.
      expect(recents.first, ['handsonhead']);
      expect(recents[1], ['armsfolded', 'handsonhead']);
      expect(recents[2].length, camRotaMemory);
      expect(recents[2].first, 'handsonhips');
    });

    testWidgets('a rota with nothing to offer leaves him standing', (
      tester,
    ) async {
      // The pre-rota behaviour, and what a save owning no emotes gets.
      await pumpCam(
        tester,
        variant: CamVariant.inline,
        minute: null,
        gesture: null,
        rota: (_) => (gesture: null, gap: const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(walkerOf(tester).gesture, isNull);
      expect(find.byType(ManagerWalker), findsOneWidget);
    });
  });

  group('the frame', () {
    testWidgets('says what the SCORELINE did, not what he thinks of it', (
      tester,
    ) async {
      // Pulling one back at 1-3 is a goal for us and still a bad night, so the
      // two disagree on purpose.
      Color borderOf(WidgetTester tester) {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(DugoutCam),
                matching: find.byType(Container),
              )
              .first,
        );
        return ((box.decoration! as BoxDecoration).border! as Border).top.color;
      }

      await pumpCam(tester, mood: Mood.crushed, tone: CamTone.good);
      final good = borderOf(tester);
      await pumpCam(tester, mood: Mood.crushed, tone: CamTone.bad);
      final bad = borderOf(tester);
      await pumpCam(tester, mood: Mood.elated, tone: CamTone.flat);
      final flat = borderOf(tester);
      expect({good, bad, flat}.length, 3);
    });

    testWidgets('carries the clock stamp, and nothing at full time', (
      tester,
    ) async {
      await pumpCam(tester, minute: "62'");
      expect(find.text("62'"), findsOneWidget);
      expect(find.text(t('match.dugout_cam')), findsOneWidget);

      // Full time is a reaction to the whole match, not to a minute of it.
      await pumpCam(tester, minute: null, variant: CamVariant.inline);
      expect(find.text("62'"), findsNothing);
      expect(find.text(t('match.dugout_cam')), findsOneWidget);
    });
  });

  group('reduced motion', () {
    testWidgets('is belt and braces: the shot is already refused before it '
        'mounts, and it stands still if it ever is not', (tester) async {
      // `shouldCutIn` is the real gate. This holds the day that gate moves —
      // the idle is the one part of the picture that runs forever.
      expect(
        shouldCutIn(trigger: CamTrigger.fullTime, reducedFx: true),
        isFalse,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 180,
                  child: DugoutCam(
                    mood: Mood.neutral,
                    kit: _kit,
                    skin: Color(0xFFEEBB8C),
                    hair: Color(0xFF3A2A1C),
                    variant: CamVariant.inline,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // It settles, which a live idle never does.
      await tester.pumpAndSettle();
      final first = walkerOf(tester).idle!;
      await tester.pump(const Duration(seconds: 3));
      expect(walkerOf(tester).idle!.bodyLift, first.bodyLift);
      expect(walkerOf(tester).idle!.head, first.head);
    });
  });
}
