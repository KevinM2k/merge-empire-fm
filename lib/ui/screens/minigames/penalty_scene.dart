/// The goalmouth you shoot at. Ported from `ui/components/PenaltyGame.js`.
///
/// **The goal IS the target.** The JS says so where it builds the scene — "no
/// corner buttons, the goal itself is the target" — and the shipped instruction
/// line says the same thing to the player: "Tap anywhere — aim for corners or
/// risk hitting the woodwork!". A grid of four buttons cannot produce a shot
/// that goes wide or clips the bar, so with buttons that copy described an
/// interaction the screen did not have.
///
/// Everything here is in PERCENTAGES of the scene box, which is locked to the
/// artwork's own 600×408. The four numbers in [goalFrame] are the posts, the
/// crossbar and the goal line in `penalty_goal.jpeg`; swap the photo for a
/// differently-framed one and these are what to retune.
///
/// The painted fallback is drawn to those SAME numbers rather than to its own,
/// so a missing photo changes how the goal looks and not where it is. The JS
/// carries two sets that quietly disagree; one set is the fix.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/penalty_game_engine.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keeper_figure.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// The artwork's aspect, so a percentage means the same thing at every width.
const double penaltySceneAspect = 600 / 408;

/// The goalmouth inside the scene box, in percent.
typedef GoalFrame = ({double left, double right, double top, double bottom});

const GoalFrame goalFrame = (left: 11, right: 89, top: 6, bottom: 47);

/// How close to a post or the bar still counts as hitting it.
const double woodworkMargin = 2;

/// What a tap produced.
enum ShotResult {
  goal,
  saved,

  /// Off target. Two ways to miss that a corner button could never express.
  wideLeft,
  wideRight,
  overTheBar,
  post,
  crossbar,
}

extension ShotResultCopy on ShotResult {
  /// The shipped line for each outcome. `penalty.*` has had all of these since
  /// before the port — they were simply unreachable.
  String get copyKey => switch (this) {
    ShotResult.goal => 'mg.goal',
    ShotResult.saved => 'mg.saved',
    ShotResult.wideLeft => 'penalty.wide_left',
    ShotResult.wideRight => 'penalty.wide_right',
    ShotResult.overTheBar => 'penalty.over_the_bar',
    ShotResult.post => 'penalty.post',
    ShotResult.crossbar => 'penalty.crossbar',
  };

  bool get scored => this == ShotResult.goal;
}

/// Where a tap landed, and what it means.
typedef Aim = ({double x, double y, PenaltyCorner? corner, ShotResult? miss});

/// Resolve a tap in scene percentages.
///
/// Returns the corner to put to the engine, or the miss that never reaches it —
/// woodwork and wayward shots are the player's own doing and the keeper has no
/// say in them.
Aim resolveAim(double x, double y) {
  if (x < goalFrame.left) {
    return (x: x, y: y, corner: null, miss: ShotResult.wideLeft);
  }
  if (x > goalFrame.right) {
    return (x: x, y: y, corner: null, miss: ShotResult.wideRight);
  }
  if (y < goalFrame.top || y > goalFrame.bottom) {
    return (x: x, y: y, corner: null, miss: ShotResult.overTheBar);
  }
  if (x <= goalFrame.left + woodworkMargin ||
      x >= goalFrame.right - woodworkMargin) {
    return (x: x, y: y, corner: null, miss: ShotResult.post);
  }
  if (y <= goalFrame.top + woodworkMargin) {
    return (x: x, y: y, corner: null, miss: ShotResult.crossbar);
  }

  // On target: the quadrant is the corner.
  final midX = (goalFrame.left + goalFrame.right) / 2;
  final midY = (goalFrame.top + goalFrame.bottom) / 2;
  final corner = y < midY
      ? (x < midX ? PenaltyCorner.topLeft : PenaltyCorner.topRight)
      : (x < midX ? PenaltyCorner.bottomLeft : PenaltyCorner.bottomRight);
  return (x: x, y: y, corner: corner, miss: null);
}

/// Where the keeper ends up when they dive to a corner, in scene percent.
({double x, double y}) keeperLanding(PenaltyCorner corner) => switch (corner) {
  PenaltyCorner.topLeft => (x: 22, y: 14),
  PenaltyCorner.topRight => (x: 78, y: 14),
  PenaltyCorner.bottomLeft => (x: 22, y: 40),
  PenaltyCorner.bottomRight => (x: 78, y: 40),
};

/// The scene: the goal, the keeper, the ball, and the tap target over all three.
class PenaltyScene extends StatelessWidget {
  const PenaltyScene({
    required this.onShoot,
    required this.ball,
    required this.keeper,
    required this.keeperTier,
    required this.keeperPose,
    required this.ballVisible,
    super.key,
  });

  /// A tap, in scene percentages.
  final void Function(double x, double y) onShoot;

  /// Where the ball is now, in scene percent.
  final ({double x, double y}) ball;

  /// Where the keeper is now, in scene percent.
  final ({double x, double y}) keeper;

  /// Which kit he is in — the division's, so the opposition visibly improves.
  final int keeperTier;

  /// Which way he went, if he has gone.
  final KeeperPose keeperPose;

  final bool ballVisible;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: penaltySceneAspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          Offset at(({double x, double y}) p) =>
              Offset(w * p.x / 100, h * p.y / 100);

          return GestureDetector(
            key: const ValueKey('penalty-goal'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => onShoot(
              details.localPosition.dx / w * 100,
              details.localPosition.dy / h * 100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ArtImage(
                      path: 'assets/bg/penalty_goal.jpeg',
                      fallback: CustomPaint(painter: _GoalPainter()),
                    ),
                  ),
                  // The keeper is drawn rather than photographed: there is no
                  // keeper sprite in the shipped assets — the Kenney pack is
                  // top-down and this is the view from the penalty spot — and one
                  // drawn to the same frame moves with the goal instead of
                  // floating over it.
                  //
                  // `keeper_figure.dart` is the JS's own illustration, rigged and
                  // posed with Flutter's animated transforms. What was here was
                  // five rectangles with the arms permanently out.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    left: at(keeper).dx - w * 0.075,
                    top: at(keeper).dy - h * 0.13,
                    child: SizedBox(
                      width: w * 0.15,
                      height: h * 0.26,
                      child: KeeperFigure(tier: keeperTier, pose: keeperPose),
                    ),
                  ),
                  if (ballVisible)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      left: at(ball).dx - w * 0.03,
                      top: at(ball).dy - w * 0.03,
                      child: SizedBox(
                        width: w * 0.06,
                        height: w * 0.06,
                        child: const ArtImage(
                          key: ValueKey('penalty-ball'),
                          path: 'assets/penalty/ball.png',
                          fit: BoxFit.contain,
                          fallback: Icon(Icons.sports_soccer, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The goal, when the photo is missing.
///
/// Drawn to [goalFrame] exactly, so the target a player taps is in the same
/// place whichever of the two is on screen.
class _GoalPainter extends CustomPainter {
  const _GoalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    double px(double pct) => w * pct / 100;
    double py(double pct) => h * pct / 100;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBFE0FF), Color(0xFF7DC0FF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, py(goalFrame.bottom), w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7BCA6A), Color(0xFF2E7D32)],
        ).createShader(Rect.fromLTRB(0, py(goalFrame.bottom), w, h)),
    );

    final frame = Rect.fromLTRB(
      px(goalFrame.left),
      py(goalFrame.top),
      px(goalFrame.right),
      py(goalFrame.bottom),
    );
    // The net, as a grid — enough to read as a goal without pretending to be
    // the photograph.
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 16; i++) {
      final x = frame.left + frame.width * i / 16;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), net);
    }
    for (var i = 1; i < 9; i++) {
      final y = frame.top + frame.height * i / 9;
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), net);
    }

    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = px(1.4)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(frame.topLeft, frame.bottomLeft, post);
    canvas.drawLine(frame.topRight, frame.bottomRight, post);
    canvas.drawLine(frame.topLeft, frame.topRight, post);
  }

  @override
  bool shouldRepaint(_GoalPainter oldDelegate) => false;
}
