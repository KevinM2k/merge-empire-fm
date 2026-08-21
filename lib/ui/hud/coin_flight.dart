/// Coins flying to the counter.
///
/// **Money that arrives out of nowhere is money nobody notices.** A sale, a
/// match fee, a quest, an achievement — every one of them moved the figure in
/// the HUD and nothing joined the two, so the reward for a thing you just did
/// happened in a corner of the screen you were not looking at.
///
/// **The one exception is the players' own idle income**, and it is the reason
/// this cannot simply watch the balance: the trickle lands every second, and a
/// counter that swells every second is furniture rather than a reward. The loop
/// says so itself — see `coins:idle` in `game_runner.dart` — and the bus is
/// synchronous, so the pair is exact rather than a guess about timing.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart'
    show coinsProvider;
import 'package:merge_empire_fc/util/event_bus.dart';

/// A handle on the HUD's coin chip, so the flight knows where it is going.
final GlobalKey coinChipKey = GlobalKey();

/// Bumped once per REWARD — never by the idle trickle.
///
/// The counter watches it so the figure swells as it counts up, which is the
/// other half of the same signal: the flight says money is coming and the swell
/// says it landed.
final coinRewardProvider = NotifierProvider<CoinReward, int>(CoinReward.new);

class CoinReward extends Notifier<int> {
  @override
  int build() => 0;

  void land() => state = state + 1;
}

/// How many sprites one reward throws. More than this reads as confetti.
const int coinFlightSprites = 7;

/// How long one coin takes to arrive.
const Duration coinFlightDuration = Duration(milliseconds: 620);

/// The layer the coins fly across. Wraps nothing — it goes in the shell's own
/// `Stack`, above the HUD, so a coin passes over the glass rather than under it.
class CoinFlight extends ConsumerStatefulWidget {
  const CoinFlight({super.key});

  @override
  ConsumerState<CoinFlight> createState() => CoinFlightState();
}

class CoinFlightState extends ConsumerState<CoinFlight>
    with TickerProviderStateMixin {
  final List<_Flight> _flights = [];

  /// The next `coins:updated` is the loop's trickle, not a reward.
  bool _passive = false;

  /// What the balance was last time it was announced.
  ///
  /// `coins:updated` fires on a SPEND as well as on a reward — a signing, a
  /// trait roll, an upgrade — and coins flying INTO the counter as it goes down
  /// is the animation telling the opposite of the truth.
  num _last = 0;

  late final BusHandler _onIdle;
  late final BusHandler _onUpdated;

  /// Test seam: how many coins are in the air.
  int get flying => _flights.length;

  @override
  void initState() {
    super.initState();
    _last = ref.read(coinsProvider);
    _onIdle = (_) => _passive = true;
    _onUpdated = (args) {
      final now = args is num ? args : _last;
      final gained = now > _last;
      _last = now;
      if (_passive) {
        _passive = false;
        return;
      }
      if (!gained) return;
      _launch();
    };
    on('coins:idle', _onIdle);
    on('coins:updated', _onUpdated);
  }

  @override
  void dispose() {
    off('coins:idle', _onIdle);
    off('coins:updated', _onUpdated);
    for (final flight in _flights) {
      flight.controller.dispose();
    }
    super.dispose();
  }

  /// Where a coin is thrown from.
  ///
  /// The middle of the screen, because a reward has no one place it comes from:
  /// a quest completes off a match, an achievement off a merge, a sale off a
  /// sheet that is already closing. What the flight has to say is where the
  /// money WENT, and that end is exact.
  Offset _source(Size screen) => Offset(screen.width / 2, screen.height * 0.52);

  Offset? _target() {
    final box = coinChipKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _launch() {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      ref.read(coinRewardProvider.notifier).land();
      return;
    }
    final to = _target();
    if (to == null) return;
    final from = _source(MediaQuery.sizeOf(context));
    final rng = math.Random();

    for (var i = 0; i < coinFlightSprites; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: coinFlightDuration,
        // Staggered, so they arrive as a handful rather than as one thick coin.
        reverseDuration: Duration.zero,
      );
      final flight = _Flight(
        controller: controller,
        // Thrown out and up before they home in — a straight line from the
        // middle of the screen to the corner reads as a slide rather than as
        // something being collected.
        via:
            from +
            Offset((rng.nextDouble() - 0.5) * 150, -30 - rng.nextDouble() * 90),
        from: from,
        to: to,
        delay: i * 45,
      );
      _flights.add(flight);
      Future<void>.delayed(Duration(milliseconds: flight.delay), () {
        if (!mounted) {
          controller.dispose();
          return;
        }
        controller.forward();
      });
      controller.addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        if (!mounted) return;
        setState(() => _flights.remove(flight));
        controller.dispose();
        // The last one to land is what swells the figure.
        if (_flights.isEmpty) ref.read(coinRewardProvider.notifier).land();
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_flights.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        key: const ValueKey('coin-flight'),
        children: [
          for (final flight in _flights)
            AnimatedBuilder(
              animation: flight.controller,
              builder: (context, _) {
                final t = Curves.easeInCubic.transform(flight.controller.value);
                final at = _bezier(flight.from, flight.via, flight.to, t);
                return Positioned(
                  left: at.dx - 9,
                  top: at.dy - 9,
                  child: Opacity(
                    // Fades only at the very end, so it is a coin landing
                    // rather than one dissolving on the way.
                    opacity: t < 0.85 ? 1 : (1 - t) / 0.15,
                    child: const _Coin(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// One quadratic bezier step — the arc every coin follows.
Offset _bezier(Offset a, Offset b, Offset c, double t) {
  final u = 1 - t;
  return Offset(
    u * u * a.dx + 2 * u * t * b.dx + t * t * c.dx,
    u * u * a.dy + 2 * u * t * b.dy + t * t * c.dy,
  );
}

class _Flight {
  _Flight({
    required this.controller,
    required this.from,
    required this.via,
    required this.to,
    required this.delay,
  });

  final AnimationController controller;
  final Offset from;
  final Offset via;
  final Offset to;
  final int delay;
}

/// The sprite. A disc rather than the glyph: at 18px the stroked coin is a
/// smudge, and this one is in flight.
class _Coin extends StatelessWidget {
  const _Coin();

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE682), Color(0xFFE0A600)],
      ),
      border: Border.all(color: const Color(0xFF8A6400), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFFD700).withValues(alpha: 0.45),
          blurRadius: 8,
        ),
      ],
    ),
  );
}
