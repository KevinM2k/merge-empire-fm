/// A standing figure out of Kenney's modular character pack (CC0) — the parts
/// `assets/manager/` has carried since the pack went in and nothing drew.
///
/// A paper doll: every part is a PNG placed in a box [height] tall and
/// `0.62 × height` wide, the offsets read off the pack's own instruction sheet.
/// Front-on and still, which is what a spectator at a fence is.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which parts one figure wears. Every field names a file under the layer's
/// folder; [spectatorLook] rolls a plausible set from a seed.
typedef ModularLook = ({
  int skin,
  String shirt,
  int shirtStyle,
  String pants,
  int pantsStyle,
  String shoe,
  int shoeStyle,
  String hair,
  bool woman,
  int hairStyle,
  int face,
});

const List<String> _shirts = ['blue', 'green', 'grey', 'navy', 'pine', 'red'];
const List<String> _pants = ['Blue1', 'Blue2', 'Brown', 'Green', 'Grey'];
const List<String> _shoes = ['black', 'blue', 'brown', 'brown2', 'grey', 'tan'];
const List<String> _hair = ['black', 'blonde', 'brown1', 'brown2', 'grey', 'red'];

/// A fan off a seed — the same seed is the same fan every frame.
ModularLook spectatorLook(int seed) {
  final r = math.Random(seed);
  final woman = r.nextBool();
  return (
    skin: 1 + r.nextInt(6),
    shirt: _shirts[r.nextInt(_shirts.length)],
    shirtStyle: 1 + r.nextInt(5),
    pants: _pants[r.nextInt(_pants.length)],
    pantsStyle: 1 + r.nextInt(3),
    shoe: _shoes[r.nextInt(_shoes.length)],
    shoeStyle: 1 + r.nextInt(5),
    hair: _hair[r.nextInt(_hair.length)],
    woman: woman,
    // Eight men's styles a colour, six women's.
    hairStyle: 1 + r.nextInt(woman ? 6 : 8),
    face: 1 + r.nextInt(4),
  );
}

/// Every file a figure with [look] draws, for a gate that decodes them first.
List<String> spectatorAssets(ModularLook l) => [
  'assets/manager/skin/tint${l.skin}_head.png',
  'assets/manager/skin/tint${l.skin}_neck.png',
  'assets/manager/skin/tint${l.skin}_hand.png',
  'assets/manager/shirts/${l.shirt}Shirt${l.shirtStyle}.png',
  'assets/manager/shirts/${l.shirt}Arm_long.png',
  'assets/manager/pants/pants${l.pants}${l.pantsStyle}.png',
  'assets/manager/pants/pants${l.pants}_long.png',
  'assets/manager/shoes/${l.shoe}Shoe${l.shoeStyle}.png',
  'assets/manager/hair/${l.hair}${l.woman ? 'Woman' : 'Man'}${l.hairStyle}.png',
  'assets/manager/face/face${l.face}.png',
];

class ModularFigure extends StatelessWidget {
  const ModularFigure({
    required this.look,
    required this.height,
    this.phase = 0,
    super.key,
  });

  final ModularLook look;
  final double height;

  /// 0..1 round an idle: a shift of weight, the arms easing, the head turning
  /// a touch. Zero is a figure standing still.
  final double phase;

  static const double aspect = 0.62;

  @override
  Widget build(BuildContext context) {
    final h = height;
    final w = h * aspect;
    const dir = 'assets/manager';
    final l = look;
    final wave = math.sin(phase * 2 * math.pi);
    final bob = wave.abs() * 0.012;
    final sway = wave * 0.10;
    final tilt = math.sin(phase * 2 * math.pi + 1.1) * 0.05;
    Widget part(
      String path,
      double cx,
      double top,
      double partHeight, {
      bool mirror = false,
      double turn = 0,
    }) {
      Widget image = Image.asset(
        path,
        height: h * partHeight,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
      if (mirror) image = Transform.flip(flipX: true, child: image);
      if (turn != 0) {
        // About the top inner corner — a sleeve hangs from its shoulder.
        image = Transform.rotate(
          angle: mirror ? turn : -turn,
          alignment: mirror ? Alignment.topLeft : Alignment.topRight,
          child: image,
        );
      }
      return Positioned(
        left: w * cx,
        top: h * top,
        child: FractionalTranslation(
          translation: const Offset(-0.5, 0),
          child: image,
        ),
      );
    }
    final skin = '$dir/skin/tint${l.skin}';
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Back to front: legs, shoes, hips, arms, torso, hands, neck, head.
          part('$dir/pants/pants${l.pants}_long.png', 0.36, 0.60, 0.32),
          part('$dir/pants/pants${l.pants}_long.png', 0.64, 0.60, 0.32, mirror: true),
          part('$dir/shoes/${l.shoe}Shoe${l.shoeStyle}.png', 0.34, 0.93, 0.07),
          part('$dir/shoes/${l.shoe}Shoe${l.shoeStyle}.png', 0.66, 0.93, 0.07, mirror: true),
          part('$dir/pants/pants${l.pants}${l.pantsStyle}.png', 0.50, 0.57, 0.08),
          part('$dir/shirts/${l.shirt}Arm_long.png', 0.24, 0.33 - bob, 0.24, turn: 0.95 + sway),
          part('$dir/shirts/${l.shirt}Arm_long.png', 0.76, 0.33 - bob, 0.24, mirror: true, turn: 0.95 - sway),
          part('$dir/shirts/${l.shirt}Shirt${l.shirtStyle}.png', 0.50, 0.30 - bob, 0.32),
          part('$skin' '_hand.png', 0.13 + sway * 0.06, 0.57 - bob, 0.08),
          part('$skin' '_hand.png', 0.87 + sway * 0.06, 0.57 - bob, 0.08, mirror: true),
          part('$skin' '_neck.png', 0.50, 0.265 - bob, 0.045),
          Positioned(
            left: 0,
            top: -h * bob,
            width: w,
            height: h,
            child: Transform.rotate(
              angle: tilt,
              alignment: const Alignment(0, -0.45),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  part('$skin' '_head.png', 0.50, 0.03, 0.27),
                  part('$dir/face/face${l.face}.png', 0.50, 0.11, 0.15),
                  part('$dir/hair/${l.hair}${l.woman ? 'Woman' : 'Man'}${l.hairStyle}.png', 0.51, -0.01, 0.20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
