/// The coin figure, counting up rather than snapping.
///
/// The JS runs its own requestAnimationFrame loop lerping `_displayCoins`
/// toward `_targetCoins`; a tween does the same job and stops itself.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/util/format.dart';

class CoinCounter extends StatelessWidget {
  const CoinCounter({super.key, required this.value, this.style});

  final num value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, v, _) => Text(formatCoinsCompact(v), style: style),
    );
  }
}
