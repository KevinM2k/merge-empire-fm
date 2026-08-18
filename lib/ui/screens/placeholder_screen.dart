/// Stands in for a real tab body until that screen is built.
///
/// It runs a ticker deliberately: the shell's ticker test needs a child that
/// actually consumes frames, and a stand-in that did nothing would let a broken
/// `TickerMode` pass.
///
/// A raw [Ticker] rather than an `AnimationController` because the test asks
/// "is this screen still being given frames", and only `Ticker.isTicking`
/// answers that — `AnimationController.isAnimating` stays true while the ticker
/// underneath it is merely muted, which is exactly what `TickerMode` does.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class PlaceholderScreen extends StatefulWidget {
  const PlaceholderScreen({super.key, required this.label});

  final String label;

  @override
  State<PlaceholderScreen> createState() => PlaceholderScreenState();
}

class PlaceholderScreenState extends State<PlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Frames this screen has been given.
  int ticks = 0;

  int bumps = 0;

  /// Test seam: proves this screen kept its state across a tab switch.
  void bump() => bumps++;

  /// Test seam: whether TickerMode is letting this screen have frames.
  bool get isTicking => _ticker.isTicking;

  @override
  void initState() {
    super.initState();
    // Created here rather than lazily: a `late` field first touched inside
    // dispose() builds its ticker off a deactivated element, which throws.
    _ticker = createTicker((_) => ticks++)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>();
    return Center(
      child: Text(
        widget.label,
        style: TextStyle(color: kit?.textMuted, fontSize: 20),
      ),
    );
  }
}
