/// The manager walks on something.
///
/// A walk cycle with nothing moving under it is a man treading air, so the
/// scene's job is the GROUND: mown lanes travelling at his stride, tufts at the
/// speed of the turf they stand in, and a stand behind them that barely moves.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

void main() {
  Future<void> pumpScene(
    WidgetTester tester, {
    Mood mood = Mood.neutral,
    int tier = 1,
    Brightness brightness = Brightness.dark,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          disableAnimations: true,
        ),
        // An inner `Theme` rather than `MaterialApp.theme`: the app's own is
        // wrapped in an `AnimatedTheme`, which LERPS to a new one over 200ms —
        // so a re-pump with the other brightness read back as the old one and
        // "the sky follows the theme" passed while the sky had not moved.
        child: Theme(
          data: ThemeData(brightness: brightness),
          child: Scaffold(
            body: PitchScene(
              mood: mood,
              tier: tier,
              walkerBottom: 150 + walkerBottomClearance,
              // The scene hands the ball to the walker now, so a stand-in has to
              // take it — see `ManagerWalker.ballLayer`.
              walkerBuilder: (ball) =>
                  Stack(children: [const SizedBox(width: 120, height: 170), ball]),
            ),
          ),
        ),
      ),
    ),
  );

  group('the ground', () {
    testWidgets('paints, and takes real room on screen', (tester) async {
      await pumpScene(tester);
      final turf = find.byKey(const ValueKey('pitch-turf'));
      expect(turf, findsOneWidget, reason: 'no turf at all');
      final box = tester.getRect(turf);
      // Better than half the scene is ground — the horizon sits at 46%.
      expect(
        box.height,
        greaterThan(tester.getRect(find.byType(PitchScene)).height * 0.5),
      );
      expect(box.width, tester.getRect(find.byType(PitchScene)).width);
    });

    testWidgets('and the mown surface fills it', (tester) async {
      await pumpScene(tester);
      final mow = find.byKey(const ValueKey('pitch-mown'));
      expect(mow, findsOneWidget, reason: 'nothing mows the pitch');
      final turf = tester.getRect(find.byKey(const ValueKey('pitch-turf')));
      final box = tester.getRect(mow);
      expect(box.height, closeTo(turf.height, 1));
      expect(box.width, closeTo(turf.width, 1));
    });

    testWidgets('and the thing that actually PAINTS has height too', (
      tester,
    ) async {
      // A box measuring right is not the same claim as the pitch being on
      // screen, and the difference is exactly how this shipped broken: the
      // lanes were `Expanded` `ColoredBox`es under a Row whose default centre
      // alignment handed them LOOSE heights, so they came out 42x0. Every box
      // above them measured correctly and the player saw sky.
      await pumpScene(tester);
      final painters = find.descendant(
        of: find.byKey(const ValueKey('pitch-mown')),
        matching: find.byType(CustomPaint),
      );
      expect(painters, findsWidgets, reason: 'nothing paints the turf');
      for (final element in painters.evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(
          size.height,
          greaterThan(8),
          reason: 'the painted surface collapsed to ${size.height}px',
        );
      }
    });

    testWidgets('and the stand is behind it, not over it', (tester) async {
      await pumpScene(tester);
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      final turf = tester.getRect(find.byKey(const ValueKey('pitch-turf')));
      expect(stand.bottom, lessThanOrEqualTo(turf.top + 1));
    });

    testWidgets('and the crowd is a terrace, not a quarter of the page', (
      tester,
    ) async {
      // At `h * 0.24` the stand was a 200px bank with a hundred 1px dots in it,
      // which is the shape of a crowd without being one. It is the TERRACE's own
      // height — the rows this tier has, and a fascia.
      await pumpScene(tester, tier: 4);
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      expect(stand.height, closeTo(standHeightFor(4), 0.5));
      expect(stand.height, lessThan(120));
    });
  });

  group('THE GROUND IS TIERED, and the port had one ground', () {
    // Six rows in one deck at every tier, so a Sunday League pitch and an
    // empire mega-stadium were the same place with a different sky. Ported from
    // `_deckPlan` — asked for directly, with the spec named.
    test('a park has NO STAND, and stands start at tier 2', () {
      expect(firstStandTier, 2);
      for (final tier in [0, 1]) {
        expect(standHeightFor(tier), parkHeight, reason: 'tier $tier');
      }
      expect(standHeightFor(2), greaterThan(0));
    });

    test('and it grows hard: one shallow row to seven packed ones', () {
      expect(deckPlan(2).rows, 1);
      expect(deckPlan(8).rows, 7);
      // Monotonic FROM THE FIRST STAND UP, so no ground a player climbed to is
      // a step backwards. Not across the park boundary: a tree line is taller
      // than a one-row terrace, and that is the right way round — tier 2 is the
      // first ground rather than a bigger park.
      for (var tier = firstStandTier + 1; tier < 9; tier++) {
        expect(
          standHeightFor(tier),
          greaterThanOrEqualTo(standHeightFor(tier - 1)),
          reason: 'tier $tier is smaller than tier ${tier - 1}',
        );
      }
    });

    test('THE DECKS STACK past tier 6, which is what makes it a stadium', () {
      // One long terrace reads as a non-league bank of seats however many rows
      // you give it.
      for (var tier = 2; tier < 6; tier++) {
        expect(deckPlan(tier).decks, 1, reason: 'tier $tier');
      }
      expect(deckPlan(6).decks, 2);
      expect(deckPlan(7).decks, 2);
      expect(deckPlan(8).decks, 3);
    });

    test('and the FRONT deck is the deepest, as a real ground is', () {
      for (final tier in [6, 7, 8]) {
        final plan = deckPlan(tier);
        expect(plan.perDeck.reduce((a, b) => a + b), plan.rows, reason: '$tier');
        expect(plan.perDeck.first, greaterThanOrEqualTo(plan.perDeck.last));
        expect(plan.perDeck.every((n) => n >= 1), isTrue);
      }
    });

    testWidgets('AND A PARK SELLS NO PERIMETER SPACE', (tester) async {
      // Nobody advertises at a ground with no stand — the fence is the boundary
      // down there. Same tier the stand arrives at, deliberately: the two come
      // together and tier 2 reads as the first real GROUND.
      expect(firstHoardingTier, firstStandTier);
      for (final tier in [0, 1]) {
        await pumpScene(tester, tier: tier);
        expect(
          find.byKey(const ValueKey('pitch-hoardings')),
          findsNothing,
          reason: 'tier $tier is advertising',
        );
      }
      await pumpScene(tester, tier: 2);
      expect(find.byKey(const ValueKey('pitch-hoardings')), findsOneWidget);
    });

    test('and the boards carry the GAME\'S OWN NAME, not a t() key', () {
      // A brand mark on a prop, the same class of thing as a badge — the
      // display name from `CFBundleDisplayName` and `android:label`. Which is
      // just as well: the catalogues are generated from the JS and no new key
      // can be added from this repo.
      expect(hoardingText, contains('MERGE EMPIRE'));
      expect(hoardingText, hoardingText.toUpperCase());
    });

    test('AND IT IS ONE LINE, whatever font the platform hands back', () {
      // 29 characters at 5.5 in the pale half of a 240 panel, which is 120
      // wide. Not enough in every face — the test binding's own fallback wants
      // 179.8 and wraps it over two six-unit lines inside a 13-unit board. It
      // scales the type down to fit rather than breaking.
      const panel = hoardingSegmentWidth / 2;
      final mark = hoardingLettering(panel, hoardingHeight);
      expect(mark.text.computeLineMetrics(), hasLength(1));
      expect(mark.text.longestLine, lessThanOrEqualTo(panel + 0.01));
      // Still lettering rather than a hairline: whatever it had to give up to
      // fit, the board is 13 tall and the mark is a real proportion of it.
      expect(mark.text.height, greaterThan(hoardingHeight * 0.25));
    });

    test('AND THE LETTERING IS CENTRED ON THE LETTERS', () {
      // Reported as needing to come down slightly. It was centred on the LINE
      // BOX, whose descent no capital ever reaches into — a quarter of the box
      // counted as ink, which pushed the mark about 0.8 units up on a 13-unit
      // board. The inked block runs from the cap line to the baseline.
      final mark = hoardingLettering(hoardingSegmentWidth / 2, hoardingHeight);
      final line = mark.text.computeLineMetrics().first;
      final baseline = mark.top + line.baseline;
      final gapAbove = mark.top;
      final gapBelow = hoardingHeight - baseline;
      // The board's own centre, and the block that is drawn in it. Equal to
      // within a rounding error rather than the descent's worth out.
      expect((gapAbove - gapBelow).abs(), lessThan(0.01));
      // Which is BELOW where the old arithmetic put it — the whole of the fix.
      expect(mark.top, greaterThan((hoardingHeight - mark.text.height) / 2));
    });

    test('AND THE PITCH IS A FIELD AT THE BOTTOM', () {
      // The port drew the same kept turf at every rank. The spec scales it hard
      // and says why — nobody mows a Sunday League pitch — so the bottom of the
      // pyramid gets far more clumps, bigger and longer in the blade, and a top
      // flight ground gets almost none.
      expect(tuftsPerBand(0), greaterThan(tuftsPerBand(1)));
      expect(tuftsPerBand(1), greaterThan(tuftsPerBand(3)));
      expect(tuftsPerBand(8), 0, reason: 'moss at the top flight');
      expect(tuftSizeBoost(0), greaterThan(tuftSizeBoost(1)));
      expect(tuftSizeBoost(1), greaterThan(tuftSizeBoost(3)));
      expect(tuftLengthBoost(0), greaterThan(tuftLengthBoost(3)));
    });

    test('and mud, ruts and water stop at tier 2', () {
      // The groundsman has been by then. Below it, "a battered pitch" is the
      // whole art brief and the port had left every part of it out.
      expect(firstKeptPitchTier, 2);
    });

    test('and the support grows with you', () {
      // 12 fans a row at tier 1, 33 at tier 8.
      expect(fansPerRow(1), 12);
      expect(fansPerRow(8), 33);
    });
  });

  group('the floodlights', () {
    const pylons = ValueKey('pitch-floodlights');
    const wash = ValueKey('pitch-floodlight-wash');

    testWidgets('a park ground has none, at either hour', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpScene(tester, tier: 1, brightness: brightness);
        expect(find.byKey(pylons), findsNothing);
        expect(find.byKey(wash), findsNothing);
      }
    });

    testWidgets('they are BUILT by the tier, so they stand in daylight too', (
      tester,
    ) async {
      await pumpScene(tester, tier: 5, brightness: Brightness.light);
      expect(find.byKey(pylons), findsOneWidget);
      // Standing, and unlit: nothing washes the pitch in the afternoon.
      expect(find.byKey(wash), findsNothing);
    });

    testWidgets('and they are LIT by the theme', (tester) async {
      await pumpScene(tester, tier: 5, brightness: Brightness.dark);
      expect(find.byKey(pylons), findsOneWidget);
      expect(find.byKey(wash), findsOneWidget);
    });

    testWidgets('they rise clear of the roof and stay inside the frame', (
      tester,
    ) async {
      await pumpScene(tester, tier: 8, brightness: Brightness.dark);
      final scene = tester.getRect(find.byType(PitchScene));
      final pylon = tester.getRect(find.byKey(pylons));
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      // Taller than the terrace — a floodlight that stops at the fascia is a
      // post.
      expect(pylon.height, greaterThan(stand.height * 1.5));
      // And its head is on screen. The strip is a fraction of the scene capped
      // by the sky above the horizon, so a short scene must clamp rather than
      // push the lamps out through the top.
      expect(pylon.top, greaterThanOrEqualTo(scene.top - 0.5));
      // Planted at the stand's foot — which is the BACK of the hoardings, so
      // the boards run in front of the pole exactly as they run in front of the
      // front row.
      expect(pylon.bottom, closeTo(stand.bottom, 1));
    });

    testWidgets('and they scroll with the stand, not against it', (
      tester,
    ) async {
      // A pylon is planted in the ground the terrace sits on. Same period and
      // same segment width is the only way they cannot drift apart.
      await pumpScene(tester, tier: 8, brightness: Brightness.dark);
      final pylon = tester.getRect(find.byKey(pylons));
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      expect(pylon.width, stand.width);
    });
  });

  group('the sky', () {
    testWidgets('follows the THEME', (tester) async {
      await pumpScene(tester, brightness: Brightness.light);
      final day = _skyOf(tester);
      await pumpScene(tester, brightness: Brightness.dark);
      final night = _skyOf(tester);
      expect(day, isNot(night));
      expect(
        day.colors.first.r + day.colors.first.g + day.colors.first.b,
        greaterThan(
          night.colors.first.r + night.colors.first.g + night.colors.first.b,
        ),
      );
    });

    testWidgets('and the TIER inside it', (tester) async {
      await pumpScene(tester, tier: 1, brightness: Brightness.light);
      final park = _skyOf(tester);
      await pumpScene(tester, tier: 8, brightness: Brightness.light);
      expect(_skyOf(tester), isNot(park));
    });

    testWidgets('and the GRASS is lit by the same decision', (tester) async {
      // A sunlit pitch under a night sky was the thing that gave away that the
      // two halves of the diorama were each deciding their own light. There is
      // one answer to "is it night" now, so they can only agree.
      await pumpScene(tester, brightness: Brightness.light);
      final day = _turfOf(tester);
      await pumpScene(tester, brightness: Brightness.dark);
      final night = _turfOf(tester);
      expect(day, isNot(night));
      for (var i = 0; i < day.colors.length; i++) {
        expect(
          day.colors[i].g,
          greaterThan(night.colors[i].g),
          reason: 'stop $i is no brighter in daylight than under the lamps',
        );
      }
    });

    testWidgets('and it is the sky the sky file says it is', (tester) async {
      // One source, because the match page stands on the same one and arriving
      // at a match must not be arriving in a different world.
      await pumpScene(tester, tier: 6, brightness: Brightness.dark);
      expect(
        _skyOf(tester).colors,
        skyGradient(brightness: Brightness.dark, tier: 6).colors,
      );
    });
  });

  group('the speeds', () {
    test('the grass is timed off HIS STRIDE, not off a number', () {
      // A fixed ground speed could only plant his feet in one of five moods; in
      // the others he skated, forwards when cheerful and backwards when fed up.
      for (final mood in Mood.values) {
        final stride = walkDurationFor(mood).inMicroseconds;
        final grass = grassDuration(mood).inMicroseconds;
        expect(
          grass / stride,
          closeTo(2.7778, 0.001),
          reason: '$mood: the grass came loose from the stride',
        );
      }
      // A cheerful manager walks faster AND the ground moves faster with him.
      expect(grassDuration(Mood.elated) < grassDuration(Mood.crushed), isTrue);
    });

    test('EVERY layer on the turf travels at the fan\'s speed for its own row', () {
      // **The one thing that has to be true, and it was not.** The tuft bands used
      // to carry ratios measured against BAND 0 rather than against his contact
      // row, and the whole layer ran 17.7% slower than the stripes it grows in — a
      // moonwalk between two layers of the same grass, on every screen.
      //
      // Checked as the ratio of each layer's own speed to the fan's at that row,
      // which has to be 1 for all of them.
      const turfHeight = 320.0;
      const contact = 114.0;
      const mood = Mood.neutral;
      final ground = groundSpeedPxPerSec(mood);
      // The fan is solved at his row, so that is the reference.
      final contactDepth = 0.58 * turfHeight + contact;

      double speedOf(Duration d, double segment) =>
          segment / (d.inMicroseconds / 1e6);

      for (var band = 0; band < 3; band++) {
        final fraction = tuftBandFraction(band);
        final rowDepth = 0.58 * turfHeight + (1 - fraction) * turfHeight;
        final fanSpeed = ground * rowDepth / contactDepth;
        final tuftSpeed = speedOf(
          turfScroll(
            segmentWidth: groundSegmentWidth,
            fraction: fraction,
            turfHeight: turfHeight,
            contactBelowHorizon: contact,
            mood: mood,
          ),
          groundSegmentWidth,
        );
        expect(
          tuftSpeed / fanSpeed,
          closeTo(1, 0.001),
          reason: 'band $band slides against the stripes it grows in',
        );
      }

      // And the boards, which are planted on the horizon.
      final boardDepth = 0.58 * turfHeight;
      final boardSpeed = speedOf(
        turfScroll(
          segmentWidth: hoardingSegmentWidth,
          fraction: 1,
          turfHeight: turfHeight,
          contactBelowHorizon: contact,
          mood: mood,
        ),
        hoardingSegmentWidth,
      );
      expect(
        boardSpeed / (ground * boardDepth / contactDepth),
        closeTo(1, 0.001),
        reason: 'the advertising crawls against the grass at its feet',
      );
    });

    test('THE GROUND MOVES AT THE FOOT\'S OWN RATE, not at an average of it', () {
      // **No constant speed can do this.** The JS's tracks are linear in angle, so
      // the supporting ankle's rate swings from -17 to +173 art units per cycle
      // across one stance. A ground running at the mean sat at 119: 45% slow at
      // mid-stance, and briefly going the wrong way at heel strike. That is the
      // slip, and it is in the poses rather than in the speed.
      double sole(double t, bool near) =>
          walkerBootSoleY(t, near: near) - walkerHipRise(t);

      // 256 steps, the same grid the table is built on. It matters: at the
      // support HAND-OVER the two ankles are half a stride apart in x, so a step
      // that classifies the supporting foot differently from the table compares
      // one boot against the other and reports a ~50-unit slip that is not there.
      const n = 256;
      var worst = 0.0;
      var worstAt = 0.0;
      for (var i = 0; i < n; i++) {
        final t = i / n * 0.5, t2 = (i + 1) / n * 0.5;
        // Whichever boot is lower is the one carrying him.
        final near = sole(t, true) >= sole(t, false);
        // Skip the hand-over itself: which foot is measured changes there, and
        // that is a discontinuity in the measurement rather than in the world.
        if (near != (sole(t2, true) >= sole(t2, false))) continue;
        final foot =
            walkerAnkle(t, near: near).x - walkerAnkle(t2, near: near).x;
        final ground =
            (groundEase(t2 / 0.5) - groundEase(t / 0.5)) *
            groundHalfStrideArtUnits;
        final slip = (foot - ground).abs() * n * 2; // units per cycle
        if (slip > worst) {
          worst = slip;
          worstAt = t;
        }
      }
      // **WHAT IS LEFT IS A DELIBERATE TRADE**, and it was 15 before it was 46.
      // The clamp on the support foot's backward creep left the curve with a
      // genuine standstill in it, so twice a stride the whole diorama stopped
      // dead and surged out of it — which is what was being reported as the walk
      // stuttering. `groundEaseFloor` blends a constant rate in to kill that, and
      // the slip is the price. Still comfortably better than the 78 a wholly
      // constant ground was rejected for: a planted foot creeping a little is a
      // much smaller lie than a pitch stalling under a man mid-stride.
      // **The guard was 55, and the world stalled to earn it.** Peak slip and a
      // world that never stops are the same number seen from two sides: at the
      // hand-over the supporting foot creeps BACKWARDS for a few per cent, so
      // any ground still moving forwards there counts as slip. The player
      // reported the stall ("he freezes, background and all, on every step"),
      // so `groundEaseMinRate` fills that hole and the peak slip at it is what
      // it is — 86 at t≈0.10, on the three samples of the hand-over, and the
      // foot's own everywhere else. The stall guard below is the one that
      // matters now, and it is tight.
      expect(
        worst,
        lessThan(90),
        reason:
            'slip of ${worst.toStringAsFixed(1)} at t=$worstAt — a constant '
            'ground was 78 out at its worst',
      );
    });

    test('AND IT NEVER STOPS MID-STRIDE, which is what the floor is for', () {
      // The reported stutter. Measured over a half-stride the rate used to run
      // 0.36, 0.21, 0.06, 0.00 and then jump to 1.11 — a standstill and a surge,
      // twice a stride, on every step he took.
      const n = 400;
      var slowest = double.infinity;
      var slowestAt = 0.0;
      var fastest = 0.0;
      for (var i = 0; i < n; i++) {
        // Normalised so the mean rate over the half-stride is exactly 1.
        final rate = (groundEase((i + 1) / n) - groundEase(i / n)) * n;
        if (rate < slowest) {
          slowest = rate;
          slowestAt = i / n;
        }
        if (rate > fastest) fastest = rate;
      }
      // Measured before the hand-over was filled: 0.34 against a peak of 1.47,
      // a fourfold swing that read as a stall twice a stride. Now 0.68 to 1.36.
      expect(
        slowest,
        greaterThan(0.6),
        reason: 'the world stalls at u=$slowestAt, rate $slowest',
      );
      // And the surge out of it is bounded too: a rate that swings twenty to one
      // reads as a stutter even without ever reaching zero.
      expect(fastest / slowest, lessThan(2.2));
    });

    test('and the ease is a distance, so it never goes backwards', () {
      var last = -1.0;
      for (var i = 0; i <= 100; i++) {
        final v = groundEase(i / 100);
        expect(v, greaterThanOrEqualTo(last), reason: 'the world reversed');
        last = v;
      }
      expect(groundEase(0), 0);
      expect(groundEase(1), closeTo(1, 1e-9));
    });

    test('the trim is the ONE knob, and everything follows it', () {
      // It exists because the JS's poses have no single planted-foot rate to
      // derive from — see `groundSpeedTrim`. What matters is that it is not a
      // fudge on one layer: move it and every strip on the turf moves with it,
      // which is what stops someone speeding up the stripes and leaving the
      // tufts behind.
      expect(
        halfStridePx(),
        closeTo(groundSpeedTrim * groundHalfStrideArtUnits * walkerScale, 1e-9),
      );
      // The SUPPORTING foot's own distance, not the near ankle's nominal stance:
      // the foot carrying him changes hands part way through, and the two differ
      // by 2.3% — a systematic error smeared over every step if the warp and the
      // scale disagree about which one they mean.
      expect(groundHalfStrideArtUnits, lessThan(walkerStrideArtUnits));
      // And it is 1: it was 1.12 while the ground ran at a constant speed, which
      // was covering for the varying rate that [groundEase] now matches outright.
      expect(groundSpeedTrim, 1);
    });

    test(
      'and further up the pitch is slower, which is what perspective IS',
      () {
        const turfHeight = 320.0;
        var last = Duration.zero;
        for (var band = 0; band < 3; band++) {
          final d = turfScroll(
            segmentWidth: groundSegmentWidth,
            fraction: tuftBandFraction(band),
            turfHeight: turfHeight,
            contactBelowHorizon: 114,
            mood: Mood.neutral,
          );
          expect(d, greaterThan(last), reason: 'band $band is not slower');
          last = d;
        }
      },
    );
  });

  group('AND IT DOES NOT WASH THE SKY ABOVE IT', () {
    // **THE LINE, reported nine times.** The aerial haze at the foot of
    // `ParkPainter` was a `drawRect` over the WHOLE strip at 22% of the sky's
    // own horizon colour. On the terrace that is right — a stand fills its
    // strip and the haze lands on seats. A park does not: the trees, the hedge
    // and the fence are the bottom third of it and the rest is sky, so the wash
    // painted a hard-edged rectangle of slightly lighter sky across the
    // diorama, its top edge exactly `parkHeight` above the horizon.
    //
    // Every previous pass read that edge as the BACKDROP being cropped and went
    // after the Kenney plate — its scale, its crop, its knocked-out sky, its
    // dark-theme dimming, and finally the plate itself. The plate never drew the
    // line; it only hid some of it, which is why the line outlived it.
    //
    // Nothing about this is visible from outside the painter, so the pixels are
    // what is checked. Painted over solid black: any pixel that is not still
    // black is something the painter put there.
    Future<({List<int> px, int w, int h})> parkOver(
      WidgetTester tester,
      Color under,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: const ValueKey('park-ink'),
              child: ColoredBox(
                color: under,
                child: const SizedBox(
                  width: farSegmentWidth,
                  height: parkHeight,
                  child: CustomPaint(
                    // A LIGHT haze, so a wash over the sky could not hide in
                    // the background it was painted on.
                    painter: ParkPainter(haze: Color(0xFFBFD8FF), tier: 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          tester.renderObject(find.byKey(const ValueKey('park-ink')))
              as RenderRepaintBoundary;
      var out = <int>[];
      var w = 0;
      var h = 0;
      await tester.runAsync(() async {
        // `toImage` is 1:1 with logical pixels by default, so the image's own
        // dimensions are the only safe index — not the view's ratio.
        final image = await boundary.toImage();
        w = image.width;
        h = image.height;
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        out = bytes!.buffer.asUint8List().toList();
      });
      return (px: out, w: w, h: h);
    }

    /// How many pixels in row [y] are not still the background.
    int touched(List<int> px, int width, int y) {
      var n = 0;
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (px[i] != 0 || px[i + 1] != 0 || px[i + 2] != 0) n++;
      }
      return n;
    }

    testWidgets('no row above the fence is painted from edge to edge', (
      tester,
    ) async {
      // **A WASH COVERS EVERY PIXEL IN ITS ROW; A TREE DOES NOT.** That is the
      // whole distinction, and it is what makes this robust against the trees
      // and the hedge moving: measured over the strip, the busiest row above the
      // fence touches 127 of 480 pixels, and the full-strip haze touched 480 of
      // 480 on every row of it.
      //
      // The fence's rail is the one thing that legitimately spans the width, and
      // it is at the very bottom — see the test below, which is the other half
      // of this one.
      final img = await parkOver(tester, const Color(0xFF000000));
      for (var y = 0; y < img.h * 0.6; y++) {
        expect(
          touched(img.px, img.w, y),
          lessThan(img.w ~/ 2),
          reason: 'row $y of the strip is painted across its whole width — the '
              'haze is a rectangle over the sky again, and that rectangle is '
              'the line',
        );
      }
    });

    testWidgets('but the park itself is still drawn, and still hazed', (
      tester,
    ) async {
      // The other half of it: a fix that painted NOTHING would sail through the
      // test above. The fence's rail is the one thing that legitimately runs the
      // full width, so it has to still be there — and it has to be down at the
      // horizon rather than up in the sky, which is what tells a rail apart from
      // a wash.
      final img = await parkOver(tester, const Color(0xFF000000));
      final full = [
        for (var y = 0; y < img.h; y++)
          if (touched(img.px, img.w, y) == img.w) y,
      ];
      expect(
        full,
        isNotEmpty,
        reason: 'the fence rail is gone — the park is not being drawn at all',
      );
      expect(
        full.first,
        greaterThan(img.h * 0.6),
        reason: 'something spans the full width up in the sky, which is where '
            'the haze rectangle used to be',
      );
      // And the trees and posts are there either side of it.
      expect(touched(img.px, img.w, img.h ~/ 2), greaterThan(0));
      expect(touched(img.px, img.w, img.h - 2), greaterThan(0));
    });
  });

  group('THE PARK DRAWS ITSELF', () {
    // **Five reports, and the answer to the fifth was to take it out.** A
    // Kenney plate behind the park was scaled by the wrong axis, then cropped
    // to its treeline, then had its sky knocked out, then dimmed for the dark
    // theme — and still read as a pasted rectangle in both. `_ParkPainter` was
    // drawing the whole horizon in front of it the entire time.
    testWidgets('and there is no photographic plate behind it', (tester) async {
      await pumpScene(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'pitch-park-backdrop-',
              ),
        ),
        findsNothing,
        reason: 'the Kenney plate is back behind the park',
      );
    });

    testWidgets('and the horizon strip is still there and still full', (
      tester,
    ) async {
      // The strip is what the pitch meets, so losing the plate must not lose
      // the segment: every element the painter draws stands on its bottom edge.
      await pumpScene(tester);
      final strip = find.byKey(const ValueKey('pitch-stand-segment'));
      expect(strip, findsWidgets);
      expect(tester.getRect(strip.first).height, greaterThan(0));
    });
  });

}

/// The gradient the scene actually painted its sky with — the first full-bleed
/// `DecoratedBox` in the stack.
LinearGradient _skyOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(PitchScene),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

/// The grass's own gradient — the first `DecoratedBox` inside the turf box.
LinearGradient _turfOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(const ValueKey('pitch-turf')),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}
