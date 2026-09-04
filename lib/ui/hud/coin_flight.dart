/// Currency flying to its counter.
///
/// **Money that arrives out of nowhere is money nobody notices.** A sale, a
/// match fee, a quest, an achievement — every one of them moved the figure in
/// the HUD and nothing joined the two, so the reward for a thing you just did
/// happened in a corner of the screen you were not looking at.
///
/// **ALL THREE WALLETS, not just the gold one.** It was written for coins and
/// the other two chips sat there while gems and energy landed silently —
/// reported from the couch, and the fix is one track per wallet rather than a
/// second layer: they differ only in where they are going and what the sprite
/// looks like. See [FlightWallet].
///
/// **The exception is anything that TRICKLES**, and it is the reason this
/// cannot simply watch a balance: idle income lands every second and energy
/// regenerates on its own, and a counter that swells every second is furniture
/// rather than a reward. The loop says so itself — `coins:idle` and
/// `energy:idle` in `game_runner.dart` — and the bus is synchronous, so the
/// pair is exact rather than a guess about timing.
///
/// **AND IT FLIES IN THE ROOT OVERLAY, over whatever is on screen.** It used to
/// draw in the shell's own `Stack`, which is under every modal route in the
/// game — so the rewards most worth animating were the ones that could never be
/// seen: the daily reward sheet, the welcome-back card, a shop purchase, an ad
/// payout. All of them hand over money from inside a route, and the coins flew
/// behind it. Same answer, and the same reason, as `toast_host.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart'
    show coinsProvider, energyProvider, gemsProvider;
import 'package:merge_empire_fc/util/event_bus.dart';

/// A handle on the HUD's coin chip, so the flight knows where it is going.
final GlobalKey coinChipKey = GlobalKey();

/// The same, for the other two wallets.
final GlobalKey gemChipKey = GlobalKey();
final GlobalKey energyChipKey = GlobalKey();

/// One wallet's track: where it lands, what tells it money moved, and what a
/// sprite of it looks like in the air.
///
/// [idle] is the event the loop fires immediately before a PASSIVE update — the
/// idle trickle, the energy regen — and null for a wallet that has no such
/// thing. Gems are only ever earned or spent deliberately.
typedef FlightWallet = ({
  GlobalKey chip,
  String updated,
  String? idle,
  List<Color> sprite,
  int sprites,
});

const List<Color> _goldSprite = [Color(0xFFFFE682), Color(0xFFE0A600)];
const List<Color> _gemSprite = [Color(0xFF9BF0FF), Color(0xFF16A8C4)];
const List<Color> _boltSprite = [Color(0xFFBBF7C6), Color(0xFF2FA84F)];

/// **Fewer of the other two, deliberately.** Seven coins reads as a handful of
/// change; seven GEMS reads as a jackpot, and a gem reward is usually one or
/// two. The count is about what the wallet is worth, not about the animation.
List<FlightWallet> flightWallets() => [
  (
    chip: coinChipKey,
    updated: 'coins:updated',
    idle: 'coins:idle',
    sprite: _goldSprite,
    sprites: coinFlightSprites,
  ),
  (
    chip: gemChipKey,
    updated: 'gems:updated',
    idle: null,
    sprite: _gemSprite,
    sprites: 4,
  ),
  (
    chip: energyChipKey,
    updated: 'energy:updated',
    idle: 'energy:idle',
    sprite: _boltSprite,
    sprites: 4,
  ),
];

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

/// The layer the coins fly across. Wraps nothing and draws nothing where it
/// sits: the sprites go up in the ROOT overlay, so a coin passes over the HUD's
/// glass AND over whatever sheet or card handed the money over.
class CoinFlight extends ConsumerStatefulWidget {
  const CoinFlight({super.key});

  @override
  ConsumerState<CoinFlight> createState() => CoinFlightState();
}

class CoinFlightState extends ConsumerState<CoinFlight>
    with TickerProviderStateMixin {
  final List<_Flight> _flights = [];

  /// The next `<wallet>:updated` is the loop's trickle, not a reward. Per
  /// wallet, because one loop tick can announce both coins and energy.
  final Set<String> _passive = {};

  /// What each balance was last time it was announced.
  ///
  /// An `:updated` fires on a SPEND as well as on a reward — a signing, a trait
  /// roll, an upgrade — and money flying INTO the counter as it goes down is
  /// the animation telling the opposite of the truth.
  final Map<String, num> _last = {};

  final List<(String, BusHandler)> _subs = [];

  /// The layer's own overlay entry, or null while nothing is in the air.
  OverlayEntry? _entry;

  /// Test seam: how many sprites are in the air.
  int get flying => _flights.length;

  @override
  void initState() {
    super.initState();
    // **ALL THREE BALANCES ARE SEEDED, from the save.** Only coins used to be,
    // and the other two started unknown — so the FIRST announcement of each
    // seeded instead of launching. Coins and energy get away with it because
    // the loop announces them within a second of boot; gems do not move at all
    // until something hands some over, which meant the first gem payout of
    // every session was the one that flew nowhere.
    _last['coins:updated'] = ref.read(coinsProvider);
    _last['gems:updated'] = ref.read(gemsProvider);
    _last['energy:updated'] = ref.read(energyProvider);
    for (final wallet in flightWallets()) {
      final idle = wallet.idle;
      if (idle != null) {
        listen(idle, (_) => _passive.add(wallet.updated));
      }
      listen(wallet.updated, (args) {
        final seen = _last[wallet.updated];
        final now = args is num ? args : seen;
        _last[wallet.updated] = now ?? 0;
        final wasPassive = _passive.remove(wallet.updated);
        if (wasPassive || seen == null || now == null) return;
        if (now <= seen) return;
        _launch(wallet);
      });
    }
  }

  /// Subscribe, and remember it so `dispose` can undo it.
  void listen(String event, BusHandler handler) {
    _subs.add((event, handler));
    on(event, handler);
  }

  @override
  void dispose() {
    for (final (event, handler) in _subs) {
      off(event, handler);
    }
    for (final flight in _flights) {
      flight.controller.dispose();
    }
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  /// Put the sprites up, or tell the layer they moved.
  ///
  /// **Inserted fresh per throw rather than kept in place**, because `insert`
  /// appends: an entry raised now sits above whatever routes are open NOW,
  /// which is the whole point — the sheet handing the money over was opened
  /// after the shell was built. The entry only exists while coins are in the
  /// air, so the next throw gets a new one over whatever is open by then.
  void _sync() {
    if (!mounted) return;
    if (_flights.isEmpty) {
      _entry?.remove();
      _entry = null;
      setState(() {});
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // No Navigator above us — a widget test pumping this layer bare. Fall
      // back to drawing in place so the sprites are still findable.
      setState(() {});
      return;
    }
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    _entry = OverlayEntry(builder: (context) => _sprites());
    overlay.insert(_entry!);
  }

  /// Where a coin is thrown from.
  ///
  /// The middle of the screen, because a reward has no one place it comes from:
  /// a quest completes off a match, an achievement off a merge, a sale off a
  /// sheet that is already closing. What the flight has to say is where the
  /// money WENT, and that end is exact.
  Offset _source(Size screen) => Offset(screen.width / 2, screen.height * 0.52);

  Offset? _target(GlobalKey chip) {
    final box = chip.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// Only the coin counter swells; the other two chips are plain figures.
  bool _swells(FlightWallet wallet) => wallet.chip == coinChipKey;

  void _launch(FlightWallet wallet) {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      if (_swells(wallet)) ref.read(coinRewardProvider.notifier).land();
      return;
    }
    // A chip that is not on screen — the HUD is hidden on some routes — has no
    // target, and a flight to nowhere is worse than none.
    final to = _target(wallet.chip);
    if (to == null) return;
    final from = _source(MediaQuery.sizeOf(context));
    final rng = math.Random();

    for (var i = 0; i < wallet.sprites; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: coinFlightDuration,
        // Staggered, so they arrive as a handful rather than as one thick coin.
        reverseDuration: Duration.zero,
      );
      final flight = _Flight(
        controller: controller,
        colours: wallet.sprite,
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
        _flights.remove(flight);
        _sync();
        controller.dispose();
        // The last one to land is what swells the figure.
        if (_flights.isEmpty && _swells(wallet)) {
          ref.read(coinRewardProvider.notifier).land();
        }
      });
    }
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    // The sprites live in the overlay — see [_sync]. Drawing in place is only
    // ever the fallback for a test pumping this layer with no Navigator above.
    if (_entry != null || _flights.isEmpty) return const SizedBox.shrink();
    return _sprites();
  }

  Widget _sprites() {
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
                    child: _Coin(colours: flight.colours),
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
    required this.colours,
    required this.from,
    required this.via,
    required this.to,
    required this.delay,
  });

  final AnimationController controller;

  /// The wallet's own two-stop gradient — see [FlightWallet].
  final List<Color> colours;
  final Offset from;
  final Offset via;
  final Offset to;
  final int delay;
}

/// The sprite. A disc rather than the glyph: at 18px a stroked coin is a
/// smudge, and this one is in flight — what has to read is the COLOUR, which is
/// the same thing that identifies the chip it is heading for.
class _Coin extends StatelessWidget {
  const _Coin({required this.colours});

  final List<Color> colours;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colours,
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
