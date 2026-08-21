/// The coin figure, counting up rather than snapping — and swelling when what
/// moved it was something the player DID.
///
/// The JS runs its own requestAnimationFrame loop lerping `_displayCoins`
/// toward `_targetCoins`; a tween does the same job and stops itself.
///
/// The swell is deliberately NOT driven by the value changing: the players' idle
/// income moves it every second, and a counter that pulses every second is
/// furniture. It is driven by [reward], which only the reward path bumps — see
/// `coin_flight.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/util/format.dart';

class CoinCounter extends StatefulWidget {
  const CoinCounter({
    super.key,
    required this.value,
    this.style,
    this.reward = 0,
  });

  final num value;
  final TextStyle? style;

  /// A counter that goes up once per reward. Its VALUE means nothing; that it
  /// changed is the whole signal.
  final int reward;

  @override
  State<CoinCounter> createState() => _CoinCounterState();
}

class _CoinCounterState extends State<CoinCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swell = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(CoinCounter old) {
    super.didUpdateWidget(old);
    if (old.reward != widget.reward &&
        !MediaQuery.of(context).disableAnimations) {
      _swell.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _swell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _swell,
      // Out and BACK on one pass — a tween that only went out would leave the
      // counter permanently larger after the first reward of the session. Small
      // with it: this is a figure in a bar, and anything that shoves its
      // neighbours about is worse than no swell at all.
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.16 * math.sin(_swell.value * math.pi),
        child: child,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.value.toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (context, v, _) =>
            Text(formatCoinsCompact(v), style: widget.style),
      ),
    );
  }
}
