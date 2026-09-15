/// The trait reel — the two-column window a roll is watched in.
///
/// **ONE MACHINE, TWO SLOTS.** This was the inside of `TraitBlock` on the player
/// sheet. The second slot needed the same reel with a different pool and a
/// different cost, and the rule on this repo is that a second spinner is a
/// spec change: the two would disagree within a week about how long a spin is
/// or where the answer stops. So the machine moved here and both blocks turn
/// it. Ported from `mountTraitRoulette` in `ui/components/TraitRoulette.js`.
///
/// The JS builds two reels out of DOM strips — a column of names and a column
/// of levels — repeated seven times so a spin can run past them, with a pull
/// lever at the side. **Flutter has that widget**: `ListWheelScrollView` with a
/// looping delegate IS a reel, and a `FixedExtentScrollController` can be told
/// to land on an item over a duration and a curve. So the spin here is three
/// revolutions and a stop, with no clock and no repeated strips.
///
/// The reel knows nothing about traits. It is handed the rows to show and told
/// where to stop; deciding and PAYING for the outcome is the block's, and it
/// happens before the reel moves — a spin that decided at the end would have
/// to be unwound when the debit turned out to be refused.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The LEVEL REEL's rows — the three numerals, and the dash a lost roll lands
/// on.
///
/// **The fourth row is not decoration.** `none` sits in the first slot's pool
/// on both sides (`traits.dart`, `traits.js`), so a roll can come back with
/// nothing — that is the downside of the gamble. A three-row reel had nowhere
/// to put it, so a lost spin stopped on a numeral and read as a win.
/// `TraitRoulette.js` carries `{ label: '—', level: 0 }` for exactly this.
///
/// The metals are the JS's `LEVEL_COLORS`, unchanged. They are not kit colours
/// and must not be: bronze, silver and gold are what a LEVEL is, the same
/// ladder the club's facilities are tinted by.
const List<({String label, Color ink})> levelRows = [
  (label: 'I', ink: Color(0xFFCD7F32)),
  (label: 'II', ink: Color(0xFFAAAAAA)),
  (label: 'III', ink: Color(0xFFFFD700)),
  (label: '-', ink: Color(0xFF999999)),
];

/// The row a lost roll stops on.
const int noneRow = 3;

/// Row height, and the reel shows three rows: the one either side is what
/// makes it a wheel rather than a label.
const double reelRowHeight = 26;

/// The spec's spin easing, which `Curves` has no member for.
///
/// `TraitRoulette.js` runs the whole spin through `1 - Math.pow(1 - t, 2.5)`;
/// the nearest built-in either side is `easeOutQuad` (2) or `easeOutCubic` (3),
/// and the difference between 2.5 and 3 is the difference between a reel that
/// is still turning at three seconds and one that is not.
///
/// **`Curves.easeOutCubic` is pow 3 and it is why the reel crept.** At the
/// halfway mark a cubic is 87.5% of the way home, so seven eighths of the
/// travel happened in the first second and the remaining four were a reel
/// inching onto its stop. Pow 2.5 is 82% at the half — still a decelerating
/// reel, but one that is visibly turning for most of the spin.
class EaseOutPow extends Curve {
  const EaseOutPow(this.power);

  final double power;

  @override
  double transformInternal(double t) => 1 - math.pow(1 - t, power).toDouble();
}

class TraitReel extends ConsumerStatefulWidget {
  const TraitReel({
    super.key,
    required this.names,
    required this.initialName,
    required this.initialLevel,
    this.keyPrefix = 'trait-reel',
  });

  /// The name column's rows, in pool order.
  final List<Widget> names;

  /// **They start on what the card ALREADY has**, which is the JS's own first
  /// act — it sets both strips to the current trait before anything spins. A
  /// reel parked on the top of the pool tells the player their man has whatever
  /// happens to sort first, and the answer only becomes true after they pay.
  final int initialName;
  final int initialLevel;

  /// `<prefix>-name`, `<prefix>-level` and `<prefix>-fade` — so two reels on
  /// one sheet can be told apart in a test.
  final String keyPrefix;

  @override
  ConsumerState<TraitReel> createState() => TraitReelState();
}

class TraitReelState extends ConsumerState<TraitReel>
    with SingleTickerProviderStateMixin {
  /// How long the reels run. **The spec's own `ANIM_MS`, which is 5000** —
  /// 900ms was a flick, 1900 was a guess, and neither is what the JS does. The
  /// name reel stops at 58% of it, so the answer lands at 2.9s and the level
  /// follows it two seconds later, which is the ~3s that was asked for.
  static const Duration spin = Duration(milliseconds: 5000);

  /// How long the answer flash runs. The JS's `0.45s ease 2` — two pulses.
  static const Duration flash = Duration(milliseconds: 900);

  /// How many times round before it lands — `BASE_NAME = 3 * nameItems.length`
  /// in `TraitRoulette.js`, which then searches FORWARD for the outcome, so a
  /// spin is three laps plus wherever it comes up. The looping delegate is what
  /// makes the laps free.
  static const int _revolutions = 3;

  static const Curve _ease = EaseOutPow(2.5);

  late final FixedExtentScrollController _names = FixedExtentScrollController(
    initialItem: widget.initialName,
  );
  late final FixedExtentScrollController _levels = FixedExtentScrollController(
    initialItem: widget.initialLevel,
  );

  bool _spinning = false;

  /// Test seam.
  bool get spinning => _spinning;

  /// The band's answer flash — see the band in `build`. One shot, so it
  /// settles: a repeating controller would keep asking for frames and no
  /// widget test in the suite could ever `pumpAndSettle` this sheet again.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: flash,
  );

  /// Green when the roll paid, red when it did not. Null outside a flash.
  Color? _flashInk;

  @override
  void dispose() {
    _flash.dispose();
    _names.dispose();
    _levels.dispose();
    super.dispose();
  }

  /// Where a looping reel has to be told to stop so that it always SPINS.
  ///
  /// **`animateToItem` takes an ABSOLUTE index, and the target was written as
  /// one.** `pool.length * _revolutions + landing` is three laps from the reel's
  /// STARTING position, so it is three laps only on the first roll — after that
  /// the reel is already parked out there, and the second and third rolls asked
  /// it to travel the handful of rows between the old trait and the new one. The
  /// spin turned into a nudge, on exactly the rolls a player has paid for and is
  /// watching. Reported from the couch.
  ///
  /// So it is measured from where the reel IS: [laps] full turns, plus however
  /// far round the pool the answer happens to sit from here. Always forward,
  /// because a reel that can run backwards is a reel that sometimes reads as
  /// undoing the last roll.
  static int _reelTarget({
    required FixedExtentScrollController from,
    required int rows,
    required int landing,
    required int laps,
  }) {
    final at = from.hasClients ? from.selectedItem : from.initialItem;
    final ahead = ((landing - at) % rows + rows) % rows;
    return at + laps * rows + ahead;
  }

  /// **The ratchet.** `rouletteClick` shipped with the port and NOTHING played
  /// it — a reel that turns in silence is the largest part of why a spin does
  /// not feel like one. The JS fires a click every time a tile boundary passes;
  /// `retriggerFloor` in `sound_service.dart` is 70ms, so the fast head of the
  /// spin thins itself out rather than machine-gunning, which is the exact job
  /// that floor was put there to do.
  ///
  /// Returns the detach, because a listener outliving the spin would click
  /// every time the reel was nudged.
  VoidCallback _ratchet(FixedExtentScrollController controller) {
    var last = 0;
    void onScroll() {
      if (!controller.hasClients) return;
      final tile = (controller.offset / reelRowHeight).floor();
      if (tile == last) return;
      last = tile;
      unawaited(ref.read(soundServiceProvider).play('rouletteClick'));
    }

    controller.addListener(onScroll);
    return () => controller.removeListener(onScroll);
  }

  /// Turn both reels and stop the name on [nameIndex], the level on
  /// [levelRow]. Resolves when the level reel has stopped.
  ///
  /// Both reels animate at once and the LEVEL is the one that stops last,
  /// which is the JS's arrangement and the reason it has any suspense: the name
  /// tells you what you won and the level tells you how much, so the second
  /// answer has to arrive after the first. `TraitRoulette.js` stops the name
  /// reel at 58% of the spin; the port had it 120ms early, which is not a
  /// beat, it is a rounding error.
  Future<void> spinTo({required int nameIndex, required int levelRow}) async {
    if (_spinning || !mounted) return;
    final rows = widget.names.length;
    if (rows == 0) return;
    setState(() => _spinning = true);
    final stopRatchets = [_ratchet(_names), _ratchet(_levels)];
    // **THE SAME DISTANCE, not the same number of revolutions.** The level reel
    // has four rows to the name reel's pool, so `_revolutions` laps of it
    // travelled a fraction as far and barely moved — it read as one reel
    // spinning beside a number that changed. Matching the ROW COUNT is what
    // makes both sides visibly roll.
    final levelLaps = _revolutions * (rows / levelRows.length).ceil();
    await Future.wait([
      _names.animateToItem(
        _reelTarget(
          from: _names,
          rows: rows,
          landing: nameIndex,
          laps: _revolutions,
        ),
        duration: spin * 0.58,
        curve: _ease,
      ),
      _levels.animateToItem(
        _reelTarget(
          from: _levels,
          rows: levelRows.length,
          landing: levelRow,
          laps: levelLaps,
        ),
        duration: spin,
        curve: _ease,
      ),
    ]);
    for (final stop in stopRatchets) {
      stop();
    }
    if (!mounted) return;
    setState(() => _spinning = false);
  }

  /// Flash the lit band [ink] — green for a win, red for a loss. The JS
  /// flashes twice over 0.9s; without it a lost roll and a won one look
  /// identical the moment the reels stop, which is the one frame the player is
  /// actually watching.
  Future<void> flashAnswer(Color ink) async {
    if (!mounted) return;
    setState(() => _flashInk = ink);
    await _flash.forward(from: 0);
    if (!mounted) return;
    setState(() => _flashInk = null);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **THE TWO REELS ARE ONE MACHINE, and it looks like one now.** They were
    // two bare `ListWheelScrollView`s eight points apart, which is a pair of
    // scrolling lists rather than a roller — reported as the spinner not
    // looking impressive. What makes a roller read as a roller is a WINDOW:
    // one frame round both columns, a rule between them so the numeral has its
    // own cell, and a lit band across the middle marking the row that counts.
    // The reference shot draws it the same way, and it needed no new copy.
    //
    // **THE HANDLE IS GONE, and that is a divergence from the spec.**
    // `TraitRoulette.js` puts a rod-and-ball lever beside the face and the port
    // had ported it. Asked for directly: the gold pill under the window is the
    // only control a roll needs, and it is the one that says what one costs.
    return Container(
      height: reelRowHeight * 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: kit.surface2,
        border: Border.all(color: kit.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The band the answer stops on. Under the reels, so a name scrolling
          // past is lit by it rather than hidden behind it.
          Positioned(
            left: 0,
            right: 0,
            top: reelRowHeight,
            height: reelRowHeight,
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                final ink = _flashInk ?? kit.accent;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.14 + 0.24 * _flash.value),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: ink.withValues(alpha: 0.45 + 0.55 * _flash.value),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ReelColumn(
                  reelKey: '${widget.keyPrefix}-name',
                  controller: _names,
                  children: widget.names,
                ),
              ),
              // The rule that gives the numeral its own cell.
              Container(width: 1, color: kit.border),
              Expanded(
                child: ReelColumn(
                  reelKey: '${widget.keyPrefix}-level',
                  controller: _levels,
                  children: [
                    for (final row in levelRows)
                      Text(
                        row.label,
                        textAlign: TextAlign.center,
                        // Its own metal, which beats the reel's default ink —
                        // an explicit colour wins over `DefaultTextStyle`.
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: row.ink,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // **THE EDGE FADE, and the spec has always had one.** `.tr2` ends
          // with a `linear-gradient(180deg, surface 0%, transparent 10%,
          // transparent 90%, surface 100%)` laid over the whole face, and the
          // port drew neither it nor anything in its place: the rows above and
          // below the answer were as solid as the answer, so three equally-lit
          // lines read as a list with a stripe on it rather than as a drum with
          // a face. Last in the stack, which is the JS's order too: it
          // dissolves the lit band's own top and bottom edges into the frame.
          Positioned.fill(
            key: ValueKey('${widget.keyPrefix}-fade'),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kit.surface2,
                      kit.surface2.withValues(alpha: 0),
                      kit.surface2.withValues(alpha: 0),
                      kit.surface2,
                    ],
                    stops: const [0, 0.1, 0.9, 1],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One column of the machine.
class ReelColumn extends StatelessWidget {
  const ReelColumn({
    super.key,
    required this.reelKey,
    required this.controller,
    required this.children,
  });

  final String reelKey;
  final FixedExtentScrollController controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **NO FRAME OF ITS OWN.** This drew a second `surface2` box with a second
    // border inside the window's, so the machine had a box round it and two
    // more inside it. The window is the frame; the reel is only the strip
    // turning behind it. The lit band belongs to the window too — one `hl`
    // spanning the whole face, as the JS has it, because it is the band that
    // has to flash the answer and a per-reel copy could not.
    return ListWheelScrollView.useDelegate(
      key: ValueKey(reelKey),
      controller: controller,
      itemExtent: reelRowHeight,
      // A reel the player cannot flick: the roll is bought, not spun by hand.
      physics: const NeverScrollableScrollPhysics(),
      // The drum. `diameterRatio` is the cylinder's width against the viewport
      // — smaller is a tighter barrel — and 1.6 was near enough flat to read as
      // three stacked labels. 1.1 turns the rows either side visibly away from
      // the reader, and the perspective is what stops that being a plain scale.
      perspective: 0.006,
      diameterRatio: 1.1,
      // And they dim. The answer is the only row at full strength, so the eye
      // has somewhere to land the moment the reel stops.
      overAndUnderCenterOpacity: 0.42,
      childDelegate: ListWheelChildLoopingListDelegate(
        children: [
          for (final child in children)
            Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: kit.accentBright),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}
