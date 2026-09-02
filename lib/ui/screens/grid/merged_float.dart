/// "✨ Legend!" rising off the square a merge landed in — the JS's
/// `floatIncomeLabel`, called with `grid.merged_into`.
///
/// **The burst says something happened; this says WHAT.** They are two halves
/// of one moment and the port only had the first, so a merge that produced a
/// Gold and a merge that produced a Bronze were the same event with different
/// colours — and `grid.merged_into` sat generated in ten catalogues with
/// nothing able to print it.
///
/// **It is a LABEL, not a toast.** It belongs at the square, because the square
/// is what the player is looking at and what changed; a message at the top of
/// the screen makes them look away from the thing they did.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';

/// The JS's own 1.4 seconds, its 40px climb and its `ease-out`.
const Duration mergedFloatDuration = Duration(milliseconds: 1400);
const double mergedFloatRise = 40;

/// The JS's `#76e876`. Green whatever the kit is: it is the same "you gained
/// something" green the income floats use, and a label that changed colour with
/// the club would stop meaning that.
const Color mergedFloatInk = Color(0xFF76E876);

class MergedFloat extends StatefulWidget {
  const MergedFloat({super.key, required this.tier, required this.playing});

  /// The tier the merge PRODUCED, which is what gets named.
  final int tier;

  /// Flipped true for one merge.
  final bool playing;

  @override
  State<MergedFloat> createState() => _MergedFloatState();
}

class _MergedFloatState extends State<MergedFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: mergedFloatDuration,
  );

  /// Held for the length of the float, so a second merge landing elsewhere
  /// cannot rewrite the name half way up.
  int _named = 1;

  @override
  void initState() {
    super.initState();
    if (widget.playing) _start();
  }

  @override
  void didUpdateWidget(MergedFloat old) {
    super.didUpdateWidget(old);
    if (widget.playing && !old.playing) _start();
  }

  void _start() {
    _named = widget.tier;
    _clock.forward(from: 0);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **Reduce motion keeps the WORDS and drops the climb.** What the merge
    // produced is information; the rise is not. That is the same call the burst
    // makes about itself.
    final still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          if (_clock.value == 0 || _clock.isCompleted) {
            return const SizedBox.shrink();
          }
          final t = Curves.easeOut.transform(_clock.value);
          return Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, still ? 4 : 4 - mergedFloatRise * t),
              child: Transform.scale(
                scale: still ? 1 : 1 - t * 0.2,
                child: Opacity(
                  opacity: still ? 1 : (1 - t).clamp(0.0, 1.0),
                  child: Text(
                    mergedIntoLine(_named),
                    key: const ValueKey('merged-float'),
                    maxLines: 1,
                    // The square is 84 points wide and "Continental" is not, so
                    // it is allowed out over its neighbours rather than being
                    // cut in half — the JS sets `white-space: nowrap` for the
                    // same reason.
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: const TextStyle(
                      color: mergedFloatInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Color(0xCC000000), blurRadius: 6),
                      ],
                    ),
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

/// The sentence, for one tier. Public so a test can ask for it by name rather
/// than rebuilding the substitution.
String mergedIntoLine(int tier) =>
    t('grid.merged_into', {'name': tierName(tier)});
