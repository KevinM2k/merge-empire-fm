/// Kenney's background elements (CC0), the sprites the diorama is drawn from.
///
/// Two ways in. A PAINTER asks [Sprites.of] and draws the decoded image, or its
/// own vector while the decode is in flight — the sun, the moon and the clouds.
/// A WIDGET strip that is snapshotted needs the images in the cache before its
/// first paint, or the snapshot is a blank it never retakes; [SpriteGate]
/// builds it with `ready` false until they are, and the strip's `stillKey`
/// carries the flag so the snapshot is taken again once they are.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

const String _dir = 'assets/bg/kenney';

const List<String> kenneyClouds = [
  '$_dir/cloud1.png',
  '$_dir/cloud2.png',
  '$_dir/cloud3.png',
  '$_dir/cloud4.png',
  '$_dir/cloud5.png',
  '$_dir/cloud6.png',
  '$_dir/cloud7.png',
  '$_dir/cloud8.png',
];
const String kenneySun = '$_dir/sun.png';
const String kenneyMoon = '$_dir/moon.png';
const List<String> kenneyTrees = [
  '$_dir/tree.png',
  '$_dir/treePine.png',
  '$_dir/treeLong.png',
];
const List<String> kenneyTreesSmall = [
  '$_dir/treeSmall_green1.png',
  '$_dir/treeSmall_green2.png',
  '$_dir/treeSmall_green3.png',
];
const List<String> kenneyBushes = [
  '$_dir/bush1.png',
  '$_dir/bush2.png',
  '$_dir/bush3.png',
  '$_dir/bush4.png',
];
const List<String> kenneyGrass = ['$_dir/grass1.png', '$_dir/grass2.png'];
const List<String> kenneyHouses = [
  '$_dir/house1.png',
  '$_dir/house2.png',
  '$_dir/houseSmall1.png',
  '$_dir/houseSmall2.png',
];

/// The far ground behind the stand, by how big the ground has grown. Hills at a
/// park, mountains once the stand is tall enough to hide most of them anyway.
///
/// **The REMASTERED pack's, cropped.** Its hills are 1024×400 with a solid
/// body under the ridge and a lighter rim along it, which reads as a slope
/// with light on it where the originals were a flat cut-out; and they tile
/// edge to edge on opaque pixels, so the hairline-of-sky clip the originals
/// needed is gone. `tool/crop_kenney_hills.py` cuts them to the top 240 rows:
/// the strip's bottom sits behind the stand, and the rest of the body would
/// only lift the ridge higher into the sky.
String kenneyHillsFor(int tier) => tier < 2
    ? '$_dir/hillsRedux.png'
    : tier < 4
    ? '$_dir/hillsLargeRedux.png'
    : '$_dir/mountainsRedux.png';

/// Width over height, so a strip can be sized before the image is decoded.
double kenneyHillsAspect(int tier) => 1024 / 240;

/// Everything the park strip and the hills draw as widgets.
List<String> kenneySceneSprites(int tier) => [
  ...kenneyTrees,
  ...kenneyTreesSmall,
  ...kenneyBushes,
  ...kenneyHouses,
  ...kenneyGrass,
  kenneyHillsFor(tier),
];

/// Decoded sprites for painters. [version] moves when one lands, so a painter
/// built with `repaint: Sprites.version` redraws off its vector fallback.
class Sprites {
  static final Map<String, ui.Image> _loaded = {};
  static final Set<String> _pending = {};
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  /// The image, or null while it decodes — which also starts the decode.
  static ui.Image? of(String path) {
    final held = _loaded[path];
    if (held == null && _pending.add(path)) unawaited(_load(path));
    return held;
  }

  static Future<void> _load(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      _loaded[path] = frame.image;
      version.value++;
    } catch (_) {
      // A missing asset: the painter keeps drawing its own.
    }
  }

  /// For tests: forget everything, so a decode can be watched from cold.
  static void reset() {
    _loaded.clear();
    _pending.clear();
  }
}

/// Builds with `ready` false until every path is in the image cache.
class SpriteGate extends StatefulWidget {
  const SpriteGate({required this.paths, required this.builder, super.key});

  final List<String> paths;
  final Widget Function(BuildContext context, bool ready) builder;

  @override
  State<SpriteGate> createState() => _SpriteGateState();
}

class _SpriteGateState extends State<SpriteGate> {
  bool _ready = false;
  List<String> _for = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_for != widget.paths) _warm();
  }

  @override
  void didUpdateWidget(SpriteGate old) {
    super.didUpdateWidget(old);
    if (old.paths.join() != widget.paths.join()) _warm();
  }

  Future<void> _warm() async {
    final paths = widget.paths;
    _for = paths;
    if (mounted && _ready) setState(() => _ready = false);
    try {
      await Future.wait([
        for (final p in paths) precacheImage(AssetImage(p), context),
      ]);
    } catch (_) {
      return;
    }
    if (mounted && _for == paths) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ready);
}
