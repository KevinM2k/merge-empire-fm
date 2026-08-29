/// "+66" rising off a card each time its income bar fills — the JS's
/// `floatCoinTick`, which `Grid.js` fires on every `animationiteration` of the
/// bar. One cycle = one payout, so the label is the money that cycle earned.
///
/// **This is how idle income is SEEN.** The HUD counter climbs, but a number
/// changing in the corner is not the same as coins coming off the players who
/// earn them. The port had the bar and dropped the float.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// The JS's 1200ms ease-out, 44px climb, and its 28px seat above the cell foot.
const Duration coinTickDuration = Duration(milliseconds: 1200);
const double coinTickRise = 44;

/// The JS's `spawnCoinTick` display rule: compact past 1k, two decimals under
/// one, otherwise a whole number or one decimal.
String coinTickLabel(double amount, {bool negative = false}) {
  final sign = negative ? '-' : '+';
  if (amount >= 1000) return '$sign${formatCoinsCompact(amount)}';
  if (amount < 1) return '$sign${amount.toStringAsFixed(2)}';
  final whole = amount == amount.roundToDouble();
  return '$sign${whole ? amount.toInt() : amount.toStringAsFixed(1)}';
}

/// Counts the cycles of the card inside [builder] and floats one label per
/// cycle over it. A [StatefulWidget] so the slot that hosts it can stay
/// stateless; the card only has to say "that was one".
class CoinTickHost extends StatefulWidget {
  const CoinTickHost({
    super.key,
    required this.amount,
    required this.enabled,
    required this.builder,
  });

  /// Coins one bar cycle pays. Zero or less floats nothing.
  final double amount;

  /// Off during a drag, as in the JS: the finger's smoothness beats a label.
  final bool enabled;

  final Widget Function(VoidCallback onCycle) builder;

  @override
  State<CoinTickHost> createState() => _CoinTickHostState();
}

class _CoinTickHostState extends State<CoinTickHost> {
  /// A notifier, not `setState`: a cycle must wake the label, not rebuild
  /// the card under it — a full grid cycles a dozen times a second.
  final ValueNotifier<int> _ticks = ValueNotifier(0);

  void _onCycle() {
    if (!widget.enabled || widget.amount <= 0 || !mounted) return;
    _ticks.value++;
  }

  @override
  void dispose() {
    _ticks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      widget.builder(_onCycle),
      Positioned.fill(
        child: CoinTickFloat(amount: widget.amount, trigger: _ticks),
      ),
    ],
  );
}

/// The label itself. Each change of [trigger] plays it once from the start.
class CoinTickFloat extends StatefulWidget {
  const CoinTickFloat({
    super.key,
    required this.amount,
    required this.trigger,
    this.negative = false,
  });

  final double amount;
  final ValueListenable<int> trigger;
  final bool negative;

  @override
  State<CoinTickFloat> createState() => _CoinTickFloatState();
}

class _CoinTickFloatState extends State<CoinTickFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: coinTickDuration,
  );

  void _play() => _clock.forward(from: 0);

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_play);
  }

  @override
  void didUpdateWidget(CoinTickFloat old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger) {
      old.trigger.removeListener(_play);
      widget.trigger.addListener(_play);
    }
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_play);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = widget.negative ? const Color(0xFFEF5350) : kit.accentBright;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          if (!_clock.isAnimating) return const SizedBox.shrink();
          final t = Curves.easeOut.transform(_clock.value);
          return Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, -15 - coinTickRise * t),
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Text(
                  coinTickLabel(widget.amount, negative: widget.negative),
                  key: const ValueKey('coin-tick'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Color(0xE6000000), blurRadius: 5, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
