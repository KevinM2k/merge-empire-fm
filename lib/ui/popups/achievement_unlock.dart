/// The banner an achievement arrives on. Ported from
/// `ui/components/AchievementUnlock.js`.
///
/// **It was a toast.** One line — "Achievement Unlocked!" — at the bottom of the
/// screen, in the same slot and the same shape as a refused merge and a lapsed
/// loan. It never said WHICH achievement, never showed the art that was drawn
/// for it, and never mentioned the coins it paid. A reward that arrives in the
/// place errors arrive is not a reward.
///
/// So: the JS's own banner. Image-dominant, at the TOP of the screen, sliding
/// down with an overshoot, art popping in behind it, a gold rim that breathes
/// and one pass of a diagonal sheen. Four and a bit seconds, then it leaves the
/// way it came; a tap or a swipe up sends it early.
///
/// **Its own host, not a fourth popup shape and not the toast layer.** It
/// interrupts nothing and answers nothing, like a toast — but it is a
/// celebration, and the toast layer is one line at the bottom by design. Two of
/// them at once would be two celebrations fighting, so they QUEUE: several
/// achievements can land on one match, and each gets its own moment.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

/// How long a banner is held before it leaves. The JS's `UNLOCK_DISPLAY_MS`.
const Duration achievementUnlockHold = Duration(milliseconds: 4200);

const Duration _slideIn = Duration(milliseconds: 520);
const Duration _slideOut = Duration(milliseconds: 380);

/// The sheen crosses once, shortly after the banner lands.
const Duration _sheenDelay = Duration(milliseconds: 220);
const Duration _sheen = Duration(milliseconds: 1400);

/// Gold, literally. This banner is its own thing whatever the club's kit —
/// an achievement is not a league fixture, and every colour in it is the JS's.
const Color _gold = Color(0xFFFFD700);
const Color _goldInk = Color(0xFFE8D090);

/// What one unlock says.
typedef AchievementUnlock = ({
  String id,
  String title,
  String description,
  String? icon,
  int coinsRewarded,
  int count,
  bool isReUnlock,
});

/// Read an unlock off the bus, or null when the payload is not one.
///
/// The localised title and description come from the catalogue, with the
/// definition's English fields as the fallback — the same order `pName` uses in
/// the shop, and for the same reason.
AchievementUnlock? achievementUnlockFrom(Object? args) {
  if (args is! Map<String, dynamic>) return null;
  final id = args['id'];
  if (id is! String || id.isEmpty) return null;
  String copy(String key, Object? fallback) {
    final hit = t(key);
    return hit == key ? '${fallback ?? ''}' : hit;
  }

  final coins = args['coinsRewarded'];
  final count = args['count'];
  return (
    id: id,
    title: copy('ach.title.$id', args['title']),
    description: copy('ach.desc.$id', args['description']),
    icon: args['icon'] is String ? args['icon'] as String : null,
    coinsRewarded: coins is num ? coins.toInt() : 0,
    count: count is num ? count.toInt() : 1,
    isReUnlock: args['isReUnlock'] == true,
  );
}

class AchievementUnlockHost extends StatefulWidget {
  const AchievementUnlockHost({super.key, required this.child});

  final Widget child;

  @override
  State<AchievementUnlockHost> createState() => AchievementUnlockHostState();
}

class AchievementUnlockHostState extends State<AchievementUnlockHost>
    with TickerProviderStateMixin {
  /// Waiting their turn. Several achievements can land on one match, and
  /// stacking them would be four celebrations in one place.
  final List<AchievementUnlock> _queue = [];
  AchievementUnlock? _current;

  /// Built in `initState` rather than lazily: a host that never showed a banner
  /// would otherwise CREATE them in `dispose`, where there is no ticker left to
  /// attach to.
  late final AnimationController _move;

  /// Drives the sheen and the rim's pulse, which run while the banner is up.
  late final AnimationController _life;

  Timer? _hold;
  late final BusHandler _handler;

  /// Test seams.
  AchievementUnlock? get current => _current;
  int get queued => _queue.length;

  @override
  void initState() {
    super.initState();
    _move = AnimationController(
      vsync: this,
      duration: _slideIn,
      reverseDuration: _slideOut,
    );
    _life = AnimationController(vsync: this, duration: achievementUnlockHold);
    _handler = (args) {
      final unlock = achievementUnlockFrom(args);
      if (unlock != null) show(unlock);
    };
    on('achievement:unlocked', _handler);
  }

  @override
  void dispose() {
    off('achievement:unlocked', _handler);
    _hold?.cancel();
    _move.dispose();
    _life.dispose();
    super.dispose();
  }

  void show(AchievementUnlock unlock) {
    if (!mounted) return;
    if (_current != null) {
      _queue.add(unlock);
      return;
    }
    setState(() => _current = unlock);
    _move.forward(from: 0);
    _life.forward(from: 0);
    _hold = Timer(achievementUnlockHold, _dismiss);
  }

  void _dismiss() {
    if (_current == null) return;
    _hold?.cancel();
    _move.reverse().then((_) {
      if (!mounted) return;
      setState(() => _current = null);
      if (_queue.isNotEmpty) show(_queue.removeAt(0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlock = _current;
    final media = MediaQuery.of(context);

    return Stack(
      children: [
        widget.child,
        if (unlock != null)
          Positioned(
            top: media.padding.top + 12,
            left: 0,
            right: 0,
            child: Align(
              child: AnimatedBuilder(
                animation: Listenable.merge([_move, _life]),
                builder: (context, _) => _Banner(
                  unlock: unlock,
                  arrival: media.disableAnimations ? 1 : _move.value,
                  life: media.disableAnimations ? 1 : _life.value,
                  reverse: _move.status == AnimationStatus.reverse,
                  onDismiss: _dismiss,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.unlock,
    required this.arrival,
    required this.life,
    required this.reverse,
    required this.onDismiss,
  });

  final AchievementUnlock unlock;

  /// 0 off the top of the screen, 1 in place.
  final double arrival;

  /// How far through its stay the banner is — the sheen and the pulse.
  final double life;
  final bool reverse;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // `min(360px, 92vw)`.
    final w = width * 0.92 < 360 ? width * 0.92 : 360.0;

    // In on a spring that overshoots to 10% and settles; out is a plain ease.
    final at = reverse
        ? Curves.easeIn.transform(arrival)
        : const Cubic(0.22, 1.2, 0.36, 1).transform(arrival);

    // The rim breathes: `ach-unlock-glow`, 1.8s in and out.
    final pulse = (Curves.easeInOut.transform(
      ((life * achievementUnlockHold.inMilliseconds / 1800) % 1 * 2 - 1).abs(),
    ));

    return Transform.translate(
      offset: Offset(0, -(1 - at) * 1.2 * 96),
      child: Opacity(
        opacity: at.clamp(0.0, 1.0),
        child: GestureDetector(
          key: const ValueKey('achievement-unlock'),
          onTap: onDismiss,
          // Swiped UP, the way it came. Down is the direction a notification is
          // pulled open, and there is nothing here to open.
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -120) onDismiss();
          },
          child: SizedBox(
            width: w,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.7),
                    width: 2,
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment(-0.7, -1),
                    end: Alignment(0.7, 1),
                    colors: [
                      Color(0xFF2A1A00),
                      Color(0xFF3D2800),
                      Color(0xFF2A1A00),
                    ],
                  ),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.35 + 0.35 * pulse),
                      blurRadius: 20 + 16 * pulse,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _Art(unlock: unlock, arrival: arrival),
                          const SizedBox(width: 10),
                          Expanded(child: _Words(unlock: unlock)),
                        ],
                      ),
                      // One diagonal pass of light across the whole banner.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _Sheen(life: life, width: w),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The achievement's own art, on a soft gold disc — the same PNGs the Trophy
/// Room draws, with the definition's glyph behind them for an achievement that
/// has no art yet.
class _Art extends StatelessWidget {
  const _Art({required this.unlock, required this.arrival});

  final AchievementUnlock unlock;
  final double arrival;

  @override
  Widget build(BuildContext context) {
    // Pops in 120ms behind the banner, overshooting to 1.18 and untwisting.
    final t = const Cubic(0.22, 1.4, 0.36, 1).transform(
      ((arrival * _slideIn.inMilliseconds - 120) / _slideIn.inMilliseconds)
          .clamp(0.0, 1.0),
    );
    return Transform.scale(
      scale: 0.2 + 0.8 * t,
      child: Transform.rotate(
        angle: (1 - t) * -0.26,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.4),
              colors: [
                _gold.withValues(alpha: 0.35),
                _gold.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ArtImage(
              path: achievementArtPath(unlock.id),
              fallback: Center(
                child: Text(
                  unlock.icon ?? '🏅',
                  style: const TextStyle(fontSize: 44, height: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({required this.unlock});

  final AchievementUnlock unlock;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '🏆 ${t('ach.unlocked').toUpperCase()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: _gold,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        unlock.title,
        key: const ValueKey('achievement-unlock-title'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      if (unlock.description.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          unlock.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, height: 1.35, color: _goldInk),
        ),
      ],
      if (unlock.coinsRewarded > 0) ...[
        const SizedBox(height: 4),
        Text(
          '+${formatCoins(unlock.coinsRewarded)} 💰',
          key: const ValueKey('achievement-unlock-reward'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _gold,
          ),
        ),
      ],
      // A repeat unlock says how many times, but only once there are two: "×1"
      // is noise on the first.
      //
      // The count alone, where the JS writes "×3 unlocks". There is no catalogue
      // key for that word — the JS hardcodes the English — and the catalogues
      // here are generated from the JS, so a new key would be wiped on the next
      // run. A bare multiplier beside the title reads in every language.
      if (unlock.isReUnlock && unlock.count >= 2) ...[
        const SizedBox(height: 3),
        Text(
          '×${unlock.count}',
          key: const ValueKey('achievement-unlock-count'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _gold,
          ),
        ),
      ],
    ],
  );
}

class _Sheen extends StatelessWidget {
  const _Sheen({required this.life, required this.width});

  final double life;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ms = life * achievementUnlockHold.inMilliseconds;
    final t = ((ms - _sheenDelay.inMilliseconds) / _sheen.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    final at = Curves.easeInOut.transform(t);
    return Transform.translate(
      // `-150%` to `250%` of its own 30% width, skewed.
      offset: Offset(width * 0.3 * (-1.5 + 4 * at), 0),
      child: Transform(
        transform: Matrix4.skewX(-0.35),
        child: FractionallySizedBox(
          widthFactor: 0.3,
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
