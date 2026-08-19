/// The manager, walking. Ported from the rig in `components/PitchScene.js` and
/// its keyframes in `styles/league-scene.css`.
///
/// He is the player's AVATAR, not one of their footballers — the customiser
/// dresses him, and on the scene the ball comes TO him rather than being
/// dribbled by him, so the figure reads as the gaffer the game casts you as.
///
/// **He wears the player's own look now.** The rig is code, because limbs have to
/// turn; everything that does not move — hair, beard, headwear, glasses, the coat
/// or suit over the kit, a scarf — is the JS's OWN artwork out of
/// `data/manager_art.g.dart`, recoloured per look. It was a hand-transcribed
/// crop haircut and a flat kit before, which meant the whole look system (four
/// builds, four outfits, twelve hairstyles, hats, faces, beards, hair colours and
/// the look packs that sell them) rendered as one hardcoded man.
///
/// **Six tracks, one clock.** The JS drives the rig with six CSS keyframe
/// animations sharing a duration: two thighs, two shins, two arms, plus a
/// vertical bob. Every one of them is a rotation about a named joint, so the
/// whole thing is a handful of rotations hung off one `AnimationController`.
///
/// **Linear on the limbs, eased on the bob**, and the CSS says why: `ease-in-out`
/// zeroes velocity at each keyframe, which reads as the leg PAUSING at full
/// extension. A vertical bounce should decelerate at the top; a stride should
/// not.
///
/// Three things the JS does not have, added because the figure is the first thing
/// the game shows and it looked like a paper doll: a ground shadow that tightens
/// as he rises, an ankle that keeps the boot flatter than the shin it hangs off,
/// and a stride-long sway of the whole body. All three are cheap and none of them
/// touch the keyframes.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/manager_art.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

/// The figure's own space, shared with `data/manager_art.g.dart` so a hat lands
/// on the head with no positioning of its own.
const double walkerWidth = managerArtWidth;
const double walkerHeight = managerArtHeight;

/// One full stride, at the NEUTRAL mood. Every other mood has its own tempo —
/// see `walkDurationFor` — and the ground is timed off whichever one is running,
/// so a cheerful stride and the grass under it speed up together.
const Duration walkCycle = Duration(milliseconds: 1800);

double _deg(double d) => d * math.pi / 180;

/// A keyframed track: stops at 0..1 through the cycle, in degrees.
typedef _Track = List<(double at, double deg)>;

/// Read a track at [t], interpolating linearly between its stops.
double _sample(_Track track, double t) {
  for (var i = 0; i < track.length - 1; i++) {
    final (a, from) = track[i];
    final (b, to) = track[i + 1];
    if (t >= a && t <= b) {
      final span = b - a;
      return span <= 0 ? from : from + (to - from) * ((t - a) / span);
    }
  }
  return track.last.$2;
}

// The JS's own keyframes, verbatim.
const _Track _thighNear = [(0, -31), (0.5, 25), (1, -31)];
const _Track _thighFar = [(0, 25), (0.5, -31), (1, 25)];
const _Track _shinNear = [(0, 6), (0.25, 4), (0.5, 13), (0.75, 60), (1, 6)];
const _Track _shinFar = [(0, 13), (0.25, 60), (0.5, 6), (0.75, 4), (1, 13)];
const _Track _armNear = [(0, 27), (0.5, -27), (1, 27)];
const _Track _armFar = [(0, -27), (0.5, 27), (1, -27)];

/// How far the whole figure rises, twice a stride.
const double _bob = 4;

/// How far he sways, once a stride. A walk is not a figure on rails.
const double _sway = 1.6;

/// The look a walker draws when the save has none.
///
/// A real look is generated at boot and stored — see `game_runner.boot` — so this
/// is the shape a widget test gets rather than the shape a player does.
///
/// **Rolled ONCE.** `normalizeAvatar(null)` generates a RANDOM look, and this was
/// a getter that re-rolled on every read: a walker with no stored look changed
/// hair, beard and outfit on every rebuild, which on the home screen is every
/// tick of the clock. It also made anything comparing two reads of it compare two
/// different men.
final ManagerLook defaultManagerLook = normalizeAvatar(null);

class ManagerWalker extends StatefulWidget {
  const ManagerWalker({
    required this.kit,
    required this.skin,
    required this.hair,
    this.look,
    this.mood = Mood.neutral,
    this.walking = true,
    super.key,
  });

  /// The club's colour — he wears the same kit as the side.
  final Color kit;

  /// Fallbacks for a look that does not name its own.
  final Color skin;
  final Color hair;

  /// What he is wearing, from `club.managerAvatar`. Null takes the default.
  final ManagerLook? look;

  /// How the season is going, which is what his mouth says.
  final Mood mood;

  /// Stopped is a real state: the scene freezes when it is not being watched.
  final bool walking;

  @override
  State<ManagerWalker> createState() => _ManagerWalkerState();
}

class _ManagerWalkerState extends State<ManagerWalker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: walkDurationFor(widget.mood),
  );

  /// Whether he should be moving at all.
  ///
  /// Honours the platform's reduce-motion setting: he is decoration on the
  /// screen the app OPENS on, which is exactly the kind of perpetual movement
  /// that setting exists to stop. It is also what lets a widget test settle —
  /// a looping animation never does.
  bool _shouldWalk(BuildContext context) =>
      widget.walking && !MediaQuery.of(context).disableAnimations;

  void _sync(BuildContext context) {
    // His TEMPO is his mood. A retime carries the phase across so a result
    // landing mid-stride does not snap his legs back to the start of the cycle —
    // and the grass, which is timed off the same figure, retimes with him.
    // His TEMPO is his mood, and the grass is timed off the same figure — so a
    // result that cheers him up speeds both up together. The stride restarts from
    // the top rather than carrying its phase across: `repeat` cannot resume
    // mid-cycle, and a mood only changes at full time, where the scene is not
    // what anybody is looking at.
    final want = walkDurationFor(widget.mood);
    if (_clock.duration != want) {
      final running = _clock.isAnimating;
      _clock.stop();
      _clock.duration = want;
      if (running) _clock.repeat();
    }
    if (_shouldWalk(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else if (_clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(context);
  }

  @override
  void didUpdateWidget(ManagerWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(context);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look ?? defaultManagerLook;
    final parts = managerPartsFor(
      look,
      kit: widget.kit,
      skin: widget.skin,
      hair: widget.hair,
      mood: widget.mood,
    );

    return AspectRatio(
      aspectRatio: walkerWidth / walkerHeight,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value;
          // Twice a stride, and eased — a vertical bounce should decelerate at
          // the top, unlike the limbs.
          final rise =
              _bob *
              math.sin(Curves.easeInOut.transform((t * 2) % 1) * math.pi).abs();

          return Stack(
            fit: StackFit.expand,
            children: [
              // The shadow does NOT bob: it is on the ground, and it tightens as
              // he leaves it, which is the whole of the depth in the figure.
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  widthFactor: 0.34 - rise / walkerHeight,
                  heightFactor: 0.035,
                  child: const _GroundShadow(),
                ),
              ),
              Transform.translate(
                offset: Offset(math.sin(t * 2 * math.pi) * _sway, -rise),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The rig: everything that turns.
                    CustomPaint(
                      key: const ValueKey('manager-walker'),
                      painter: _WalkerPainter(
                        t: t,
                        kit: widget.kit,
                        skin: parts.skin,
                      ),
                    ),
                    // Then the look, in the JS's own layering: what goes over the
                    // torso, then the head's own furniture. Hair is TWO layers
                    // with the skull between them, which is what stops a mohawk's
                    // fin coming out of the face.
                    for (final svg in parts.overTorso) SvgArt(svg: svg),
                    for (final svg in parts.behindHead) SvgArt(svg: svg),
                    CustomPaint(painter: _HeadPainter(skin: parts.skin)),
                    for (final svg in parts.overHead) SvgArt(svg: svg),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The parts one look draws, already recoloured and in layer order.
typedef ManagerParts = ({
  Color skin,
  List<String> overTorso,
  List<String> behindHead,
  List<String> overHead,
});

/// Resolve a look into drawable, recoloured fragments.
///
/// Pure, and public, because the layering is the part worth pinning in a test:
/// hair behind the skull, the skull, hair in front of it, then beard, glasses and
/// hat over the lot.
ManagerParts managerPartsFor(
  ManagerLook look, {
  required Color kit,
  required Color skin,
  required Color hair,
  Mood mood = Mood.neutral,
}) {
  final hairColour = '${look['hair'] ?? ''}'.isEmpty
      ? hexOf(hair.toARGB32())
      : '${look['hair']}';
  final skinColour = '${look['skin'] ?? ''}'.isEmpty
      ? hexOf(skin.toARGB32())
      : '${look['skin']}';
  final shade = '${look['skinShade'] ?? ''}'.isEmpty
      ? null
      : '${look['skinShade']}';

  String paint(String svg) => recolourManagerArt(
    svg,
    hair: hairColour,
    skin: skinColour,
    skinShade: shade,
    kit: hexOf(kit.toARGB32()),
    kitDark: hexOf(Color.lerp(kit, Colors.black, 0.32)!.toARGB32()),
    kitLight: hexOf(Color.lerp(kit, Colors.white, 0.22)!.toARGB32()),
  );

  List<String> present(Iterable<String?> raw) => [
    for (final svg in raw)
      if (svg != null && svg.trim().isNotEmpty) paint(svg),
  ];

  final (hairBack, hairFront) =
      managerHair['${look['style']}'] ?? managerHair['crop']!;

  return (
    skin: _colourOf(skinColour) ?? skin,
    overTorso: present([
      managerOutfits['${look['outfit']}'],
      managerNeck['${look['neck']}'],
    ]),
    behindHead: present([hairBack]),
    overHead: present([
      hairFront,
      managerBeards['${look['beard']}'],
      managerFaces['${look['face']}'],
      managerHats['${look['hat']}'],
      // The mouth is the manager's MOOD, and `manager_mood.dart` was ported with
      // nothing to draw it: how the gaffer feels about the season was a value
      // nobody could see. Last, so a beard cannot cover it.
      managerMouths[mood.name],
    ]),
  );
}

Color? _colourOf(String hex) {
  final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

/// The ground he walks on.
class _GroundShadow extends StatelessWidget {
  const _GroundShadow();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.all(Radius.elliptical(60, 6)),
      gradient: RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.34),
          Colors.black.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

/// The skull, which the two hair layers are drawn either side of.
class _HeadPainter extends CustomPainter {
  const _HeadPainter({required this.skin});

  final Color skin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);
    canvas.drawCircle(const Offset(62, 48.5), 12.5, Paint()..color = skin);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeadPainter old) => old.skin != skin;
}

class _WalkerPainter extends CustomPainter {
  const _WalkerPainter({
    required this.t,
    required this.kit,
    required this.skin,
  });

  final double t;
  final Color kit;
  final Color skin;

  /// The far side of the body, darkened. This is the whole of the depth cue.
  Color _shade(Color c) => Color.lerp(c, Colors.black, 0.28)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);

    // FAR limbs first, so the near ones overlap them.
    _leg(canvas, near: false);
    _arm(canvas, near: false);
    _body(canvas);
    _leg(canvas, near: true);
    _arm(canvas, near: true);

    canvas.restore();
  }

  /// Rotate about a joint, run [draw], and put the canvas back.
  void _about(Canvas canvas, Offset joint, double degrees, VoidCallback draw) {
    canvas.save();
    canvas.translate(joint.dx, joint.dy);
    canvas.rotate(_deg(degrees));
    canvas.translate(-joint.dx, -joint.dy);
    draw();
    canvas.restore();
  }

  void _leg(Canvas canvas, {required bool near}) {
    final legs = near ? kit : _shade(kit);
    final flesh = near ? skin : _shade(skin);
    final boot = near ? const Color(0xFF141414) : const Color(0xFF0B0B0B);
    final thigh = _sample(near ? _thighNear : _thighFar, t);
    final shin = _sample(near ? _shinNear : _shinFar, t);

    _about(canvas, const Offset(58, 96), thigh, () {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(53.5, 96, 9, 30),
          const Radius.circular(4.5),
        ),
        Paint()..color = legs,
      );
      _about(canvas, const Offset(58, 126), shin, () {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(54.5, 126, 7, 24),
            const Radius.circular(3.5),
          ),
          Paint()..color = flesh,
        );
        // The ankle takes back most of the shin's swing, so the boot stays
        // nearer the ground than the leg above it. Without it the foot pointed
        // wherever the shin did, which is the one thing that made the figure
        // read as a puppet.
        _about(canvas, const Offset(58, 149), -shin * 0.72, () {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(54.5, 147, 15, 5),
              const Radius.circular(3),
            ),
            Paint()..color = boot,
          );
        });
      });
    });
  }

  void _arm(Canvas canvas, {required bool near}) {
    final sleeve = near ? kit : _shade(kit);
    final flesh = near ? skin : _shade(skin);
    _about(
      canvas,
      const Offset(56, 62),
      _sample(near ? _armNear : _armFar, t),
      () {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(52.5, 62, 7, 19),
            const Radius.circular(3.5),
          ),
          Paint()..color = sleeve,
        );
        // The forearm hangs at a fixed break from the upper arm — the JS gives it
        // a static -52° rather than a track of its own.
        _about(canvas, const Offset(56, 80), -52, () {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(53, 80, 6, 17),
              const Radius.circular(3),
            ),
            Paint()..color = flesh,
          );
          canvas.drawCircle(const Offset(56, 96), 3.8, Paint()..color = flesh);
        });
      },
    );
  }

  void _body(Canvas canvas) {
    // Shorts a shade darker than the shirt: one flat block from collar to knee
    // read as a romper suit.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(50.5, 88, 15, 15),
        const Radius.circular(4),
      ),
      Paint()..color = Color.lerp(kit, Colors.black, 0.22)!,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(50.5, 58, 15, 32),
        const Radius.circular(5),
      ),
      Paint()..color = kit,
    );
  }

  @override
  bool shouldRepaint(_WalkerPainter old) =>
      old.t != t || old.kit != kit || old.skin != skin;
}
