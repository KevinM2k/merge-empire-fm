/// The stage's resting state: the numbers the commentary is describing. Ported
/// from `_buildStatboard` / `_computeLiveStats` in `components/MatchPopup.js`.
///
/// **The stage is a PERMANENT band and this is what lives in it.** The port
/// mounted the 2D pitch only when a chance arrived and unmounted it after, which
/// is why the pitch appeared to flicker and jump: the band itself was appearing
/// and disappearing under it. In the JS the band never moves — it holds the
/// pitch's aspect for the whole match — and a chance cuts in ON TOP of this
/// board, at the same inset and the same corner radius, opaque, covering it
/// whole.
///
/// **Every figure is counted off the replayed timeline**, so the board can never
/// disagree with the feed underneath it: a shot in the commentary is a shot on
/// this board, because they are the same event read twice.
///
/// **Nothing here animates on its own.** A shape sliding about under its own
/// steam reads as a simulation, which is exactly what the pitch is not running.
/// The one movement is a figure BUMPING when it goes up, which is how a chance
/// that produced no cutaway still registers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// One side's tallies, home first.
typedef LiveStats = ({
  int possHome,
  int possAway,
  List<({String key, String labelKey, int home, int away})> rows,
});

/// Count the board off the events shown so far.
///
/// **A goal is also a shot, an on-target shot AND a converted big chance.** The
/// JS folds them in for that reason and it is what keeps this consistent with the
/// feed, where a cutaway fires for every goal and every big chance.
LiveStats liveStatsFor({
  required MatchFrame frame,
  required Map<String, dynamic> result,
  required bool isHome,
  required String strategyId,
}) {
  var shotsUs = 0;
  var shotsThem = 0;
  var onTargetUs = 0;
  var onTargetThem = 0;
  var bigUs = 0;
  var bigThem = 0;
  var bigMissedUs = 0;
  var bigMissedThem = 0;
  var cornersUs = 0;
  var cornersThem = 0;
  var goalsUs = 0;
  var goalsThem = 0;
  // How the run of play has gone lately, home-positive. Weighted to the recent
  // end, because possession is a reading of the last ten minutes and not of the
  // whole match.
  var swing = 0.0;

  for (final e in frame.shown) {
    final ours = e.team == 'home'
        ? isHome
        : e.team == 'away'
        ? !isHome
        : null;
    switch (e.type) {
      case 'goal':
        if (ours ?? true) {
          goalsUs++;
        } else {
          goalsThem++;
        }
        swing = swing * 0.7 + ((ours ?? true) == isHome ? 0.3 : -0.3);
      case 'chance':
        if (ours ?? true) {
          shotsUs++;
          if (e.shotResult == 'on_target') {
            onTargetUs++;
          } else {
            bigMissedUs++;
          }
          bigUs++;
        } else {
          shotsThem++;
          if (e.shotResult == 'on_target') {
            onTargetThem++;
          } else {
            bigMissedThem++;
          }
          bigThem++;
        }
        swing = swing * 0.85 + ((ours ?? true) == isHome ? 0.15 : -0.15);
      case 'corner':
        if (ours ?? true) {
          cornersUs++;
        } else {
          cornersThem++;
        }
    }
  }

  num asNum(Object? v) => v is num ? v : 50;
  final ourRating = asNum(result['effectiveSquadRating']);
  final theirRating = asNum(result['effectiveOppRating']);
  final ratingDiffHome = isHome
      ? ourRating - theirRating
      : theirRating - ourRating;

  final strat = strategies[strategyId] ?? strategies[defaultStrategy]!;
  // A tactic that sits deep concedes the ball; one that presses takes it.
  final stratBias = (strat.possession - 50).toDouble();
  final stratBiasHome = (isHome ? 1 : -1) * stratBias;

  final homePct = 50 + ratingDiffHome * 0.3 + stratBiasHome * 0.5 + swing * 22;
  // Clamped hard: a 72/28 split is already a rout, and the numbers stop reading
  // as football past it.
  final possHome = homePct.clamp(28.0, 72.0).round();

  (int, int) pick(int us, int them) => isHome ? (us, them) : (them, us);

  return (
    possHome: possHome,
    possAway: 100 - possHome,
    rows: [
      for (final row in <(String, String, (int, int))>[
        (
          'shots',
          'match.stat.shots',
          pick(shotsUs + goalsUs, shotsThem + goalsThem),
        ),
        (
          'sot',
          'match.stat.on_target',
          pick(onTargetUs + goalsUs, onTargetThem + goalsThem),
        ),
        (
          'big',
          'match.stat.big_chances',
          pick(bigUs + goalsUs, bigThem + goalsThem),
        ),
        ('bigmiss', 'match.stat.big_missed', pick(bigMissedUs, bigMissedThem)),
        ('corners', 'match.stat.corners', pick(cornersUs, cornersThem)),
      ])
        (key: row.$1, labelKey: row.$2, home: row.$3.$1, away: row.$3.$2),
    ],
  );
}

class MatchStatboard extends StatelessWidget {
  const MatchStatboard({super.key, required this.stats, required this.isHome});

  final LiveStats stats;

  /// Which column is OURS. Fixed for the whole match, so the accent goes on once.
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('match-statboard'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: const Alignment(-0.5, -1),
          end: const Alignment(0.5, 1),
          colors: [
            kit.surface2.withValues(alpha: 0.96),
            kit.bg.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Expanded(
                child: _TeamLabel(
                  text: t('match.momentum.home'),
                  ours: isHome,
                  align: TextAlign.left,
                ),
              ),
              Text(
                t('match.stats_label'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: kit.textMuted,
                ),
              ),
              Expanded(
                child: _TeamLabel(
                  text: t('match.momentum.away'),
                  ours: !isHome,
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
          // Possession leads, and it is the one row with a bar: it is a SHARE of
          // one quantity, where the others are two independent counts.
          _StatRow(
            label: t('match.stat.possession'),
            home: '${stats.possHome}%',
            away: '${stats.possAway}%',
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(
                    flex: stats.possHome,
                    child: ColoredBox(color: kit.accentBright),
                  ),
                  Expanded(
                    flex: stats.possAway,
                    child: ColoredBox(color: kit.border),
                  ),
                ],
              ),
            ),
          ),
          for (final row in stats.rows)
            _StatRow(
              label: t(row.labelKey),
              home: '${row.home}',
              away: '${row.away}',
            ),
        ],
      ),
    );
  }
}

class _TeamLabel extends StatelessWidget {
  const _TeamLabel({
    required this.text,
    required this.ours,
    required this.align,
  });

  final String text;
  final bool ours;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: ours ? kit.accentBright : kit.textMuted,
      ),
    );
  }
}

/// One row: a figure each side of a centred label. A figure that has gone UP
/// since the last paint bumps, which is the whole of the movement on this board.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.home, required this.away});

  final String label;
  final String home;
  final String away;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;
    Widget figure(String v, TextAlign align) => Expanded(
      child: _Bumping(
        value: v,
        child: Text(
          v,
          textAlign: align,
          style: TextStyle(
            fontSize: 13,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );

    return Row(
      children: [
        figure(home, TextAlign.left),
        Expanded(
          flex: 3,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kit.textMuted,
            ),
          ),
        ),
        figure(away, TextAlign.right),
      ],
    );
  }
}

/// A quick swell when the figure changes.
class _Bumping extends StatefulWidget {
  const _Bumping({required this.value, required this.child});

  final String value;
  final Widget child;

  @override
  State<_Bumping> createState() => _BumpingState();
}

class _BumpingState extends State<_Bumping>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(_Bumping old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value &&
        !MediaQuery.of(context).disableAnimations) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    // Out and BACK on one pass — a tween to 1.35 swells and then holds big until
    // the next change, which leaves the last figure that moved permanently
    // larger than the rest of the column.
    builder: (context, child) => Transform.scale(
      scale: 1 + 0.35 * math.sin(_c.value * math.pi),
      child: child,
    ),
    child: widget.child,
  );
}
