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
/// The one movement is a figure PULSING in the kit colour when it goes up, which
/// is how a chance that produced no cutaway still registers. It used to SWELL,
/// and a number that changes size shoves the row it sits in about.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart' show minFontSize;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// One side's tallies, home first.
typedef LiveStats = ({
  int possHome,
  int possAway,

  /// **Where the chances are coming from, 0..100 home-positive.** Not the same
  /// question as possession, and that was the bug: the momentum arrow read the
  /// possession figure — rating gap, TACTIC and swing — while the engine
  /// attributes chances on the RATINGS alone, so the arrow could point hard one
  /// way because of a tactic the events knew nothing about.
  ///
  /// Weighting the CHANCES on possession instead broke thirty-two rows of
  /// `match_orchestration_parity_test`, which compares the feed against the
  /// JS's own — the harness doing its job. So the arrow moved, not the engine.
  double dangerHome,
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

  // **THE SAME FORMULA THE CHANCES ARE WEIGHTED ON.** It was written out here
  // and the chance attribution used the RATINGS alone, so the arrow could point
  // hard one way — because of a tactic it knew about — while the chances went
  // on falling the other. `restingPossessionHome` is the one of it; the swing
  // is what this caller knows and the kickoff weighting cannot.
  final resting = restingPossessionHome(
    ratingDiffHome: ratingDiffHome.toDouble(),
    possessionBiasHome: stratBiasHome,
  );
  final homePct = resting + swing * 22;

  // **THE ARROW'S OWN FIGURE, off the same ratings the chances are.** Plus the
  // counter exception, which is what stops it reading as a foregone
  // conclusion: only the side with LESS of the ball can counter, and how much
  // it is worth to them is how far they are set up for it. So the side with the
  // run of play takes most of the chances — just not all of them.
  final rating = 50 + ratingDiffHome * 0.5;
  final ourCounter = counterLeanFor(strategyId);
  final theirRatio =
      (result['oppAttackRatio'] as num?)?.toDouble() ?? oppBaseAtkShare;
  final theirCounter = ((oppBaseAtkShare - theirRatio) / 0.2).clamp(0.0, 1.0);
  final danger = chanceWeightsFor(
    possHome: rating.clamp(0.0, 100.0).toDouble(),
    counterHome: isHome ? ourCounter : theirCounter,
    counterAway: isHome ? theirCounter : ourCounter,
  );
  // **AND THE TACTIC HAS TO BE IN IT, or the arrow cannot answer the one
  // question it is on the pitch to answer.** The chance weights come off the
  // RATINGS and the counter lean alone, so switching between High Press and
  // Park the Bus moved possession by twenty points and moved the arrow by
  // almost nothing — reported from the couch as the pressure arrow not making
  // sense and giving no read on whether the tactics are working.
  //
  // Weighting the CHANCES on possession is the change that broke thirty-two
  // rows of `match_orchestration_parity_test`, and that is still off the table:
  // the feed is the JS's. This is the ARROW's own figure and nothing else reads
  // it — the statboard prints possession, shots and corners, not this — so the
  // blend lives here, which is what this file's own note above meant by "the
  // arrow moved, not the engine".
  //
  // Two thirds chances, one third territory: where the ball is IS pressure, and
  // it is the half a manager can change in the next ten seconds. `resting` is
  // the possession picture without the swing, so the run of play is still
  // counted once.
  final chanceShare = danger.home / (danger.home + danger.away) * 100;
  final dangerHome = (chanceShare * 0.68 + resting * 0.32 + swing * 14).clamp(
    20.0,
    80.0,
  );
  // Clamped hard: a 72/28 split is already a rout, and the numbers stop reading
  // as football past it.
  final possHome = homePct.clamp(28.0, 72.0).round();

  (int, int) pick(int us, int them) => isHome ? (us, them) : (them, us);

  return (
    possHome: possHome,
    possAway: 100 - possHome,
    dangerHome: dangerHome,
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
                  fontSize: 12,
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
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: ours ? kit.accentBright : kit.textMuted,
      ),
    );
  }
}

/// One row: a figure each side of a centred label. A figure that has gone UP
/// since the last paint pulses, which is the whole of the movement on this
/// board.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.home, required this.away});

  final String label;
  final String home;
  final String away;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    Widget figure(String v, TextAlign align) => Expanded(
      child: _Pulsing(value: v, align: align),
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
              fontSize: 12,
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

/// A quick PULSE in the kit colour when the figure changes.
///
/// It used to swell — `Transform.scale` out to 1.35 and back — and a number that
/// changes size shoves its neighbours about, on a board whose whole job is
/// holding still while the commentary moves. The colour carries the same "this
/// one just went up" and costs the layout nothing.
class _Pulsing extends StatefulWidget {
  const _Pulsing({required this.value, required this.align});

  final String value;
  final TextAlign align;

  @override
  State<_Pulsing> createState() => _PulsingState();
}

class _PulsingState extends State<_Pulsing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didUpdateWidget(_Pulsing old) {
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
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      // Up and BACK on one pass. A tween that only went out would leave the last
      // figure that moved lit for the rest of the match.
      builder: (context, _) => Text(
        widget.value,
        textAlign: widget.align,
        style: TextStyle(
          fontSize: 13,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: Color.lerp(
            ink,
            kit.accentBright,
            math.sin(_c.value * math.pi),
          ),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// **WHAT THE NINETY MINUTES CAME TO, ON THE GRASS THAT PLAYED THEM.**
///
/// The page holds at full time now rather than leaving on a timer — see the
/// footer's CONTINUE — which means the stage has a job it never had before: at
/// the whistle it is a pitch with nothing happening on it. The statistics were
/// behind the board, one tap away, on a screen the player was about to be taken
/// off. Asked for from the couch: show them ON the pitch, in transparent boxes.
///
/// The row shape is the couch's too — `<home> <bar> STAT <bar> <away>` — and it
/// is the right one for this: two counts of the same thing read as a contest
/// when the bars grow away from a shared label, and as two unrelated numbers
/// when they sit in columns. It is the same idea `MatchStatRows` draws on the
/// next-match card, in the one shape that survives being laid over grass.
class PitchStatOverlay extends StatelessWidget {
  const PitchStatOverlay({
    super.key,
    required this.stats,
    required this.isHome,
  });

  final LiveStats stats;

  /// Which column is OURS, so the accent goes on the right side of the row.
  final bool isHome;

  /// The bar's own share of the row, per side. The label sits between them.
  static const double _barFlex = 3;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, int home, int away, String? suffix})>[
      (
        label: t('match.stat.possession'),
        home: stats.possHome,
        away: stats.possAway,
        suffix: '%',
      ),
      for (final row in stats.rows)
        (label: t(row.labelKey), home: row.home, away: row.away, suffix: null),
    ];
    // **THE BAND IS A FIXED HEIGHT and the list is not.** Six rows of statistics
    // do not fit the pitch on a short phone, and a stat that has overflowed off
    // the bottom is worse than a small one — so the whole block scales to the
    // grass it is laid on, which is what `FittedBox` is for and what the type
    // floor's own note names as the escape hatch. `Center` first, or the fitted
    // child is pinned to the top-left of the band.
    // **THE BAND IS A FIXED HEIGHT and the list is not.** Six rows of statistics
    // do not fit the pitch on a short phone, and a stat that has overflowed off
    // the bottom is worse than a small one — so the whole block scales to the
    // grass it is laid on, which is what `FittedBox` is for and what the type
    // floor's own note names as the escape hatch.
    //
    // **ONE scale for the whole block, and that is the point.** Every row is
    // laid out at the SAME size and the fit is applied to all of them at once,
    // so no figure and no label is ever a different size from the one beside
    // it. Asked for from the couch: do not change font sizes in the stats. The
    // width is measured rather than left unbounded, because a `FittedBox` hands
    // its child infinity and a `Row` with flexible children cannot lay out in
    // it.
    // **`IgnorePointer`, because nothing on it is a control.** A row of replay
    // buttons lived here for one round; they belong on the COMMENTARY LINE that
    // describes the moment, which is where a player is already reading about it
    // — asked for from the couch. See `_FeedLine.onReplay`.
    return IgnorePointer(
      child: Padding(
        // **THE BOXES USE THE PITCH.** They were inset a token 8 points and sat
        // as a narrow stack in the middle of the grass with air all round them;
        // asked for from the couch to fill the band out. The rows are wider and
        // the gaps between them are bigger, so the panel reads as the pitch's
        // own scoreboard rather than as a note left on it.
        //
        // **And then not quite so wide.** At 14 the rows ran almost to the
        // touchlines and the panel stopped reading as something ON the pitch;
        // ten more a side puts the grass back round it. Reported from the couch
        // in exactly that measure.
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: LayoutBuilder(
          builder: (context, box) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: box.maxWidth,
                // **ONE CARD, not one per row.** Six plates stacked with air
                // between them read as six separate notices laid on the grass;
                // asked for from the couch to be one. The rows keep their own
                // rhythm inside it and the panel is a single object on the
                // pitch, which is what a scoreboard is.
                child: Container(
                  key: const ValueKey('pitch-stats'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: pitchStatPlate,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final row in rows)
                        Padding(
                          // A bit more air between the rows than the first
                          // cut had: asked for from the couch, and the panel
                          // has the room now that it is one card.
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: _PitchStatRow(
                            label: row.label,
                            home: row.home,
                            away: row.away,
                            suffix: row.suffix,
                            isHome: isHome,
                            barFlex: _barFlex,
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

/// The panel's ground.
///
/// **A DARK PLATE, whatever theme the app is in.** It is laid over grass, and
/// grass is a mid green in both — so what the figures stand on is decided
/// against the PITCH rather than against the page.
///
/// **And far more transparent than a panel off the pitch.** It began at 80% —
/// the opacity a panel wants when it is the thing you are reading — and on
/// grass that is a black slab with a football pitch showing round the edges.
/// Reported from the couch, then reported again as having gone too far the
/// other way; this is where the two landed. It sits ON the picture rather than
/// over it: enough ground to hold white figures and no more.
const Color pitchStatPlate = Color(0x733A4A42);

/// The slot the stat's NAME sits in, so the bars either side of it start at the
/// same place on every row.
///
/// Wide enough for the longest label in the set at [minFontSize] — the block's
/// own `FittedBox` takes care of a language where it is not, by scaling every
/// row together rather than this one on its own.
const double pitchStatLabelWidth = 96;

/// One row of [PitchStatOverlay].
class _PitchStatRow extends StatelessWidget {
  const _PitchStatRow({
    required this.label,
    required this.home,
    required this.away,
    required this.suffix,
    required this.isHome,
    required this.barFlex,
  });

  final String label;
  final int home;
  final int away;
  final String? suffix;
  final bool isHome;
  final double barFlex;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFF2F5F3);

    // A share of the pair, so the two bars are one comparison. Nil-nil gives
    // both of them nothing rather than half each, which is honest: neither side
    // did anything.
    final total = home + away;
    final homeShare = total == 0 ? 0.0 : home / total;
    final awayShare = total == 0 ? 0.0 : away / total;

    // **THE BIGGER BAR IS GREEN AND THE SMALLER ONE RED**, whoever they belong
    // to. It was the club's accent against a white wash — which says whose row
    // it is, and this row already says that: the figures sit under the score,
    // home on the left. What a manager is reading here is who WON each of these
    // contests, and the app has a green and a red for exactly that. Asked for
    // from the couch. Level is neither, because level is not a win.
    //
    // Fixed members rather than `vsGreenOn`/`vsRedOn`: this is laid over grass,
    // which is a mid green in both themes, so the pair is chosen against the
    // pitch rather than against the page.
    const won = Color(0xFF4ADE80);
    const lost = Color(0xFFF87171);
    const level = Color(0x8AFFFFFF);
    final mine = home == away
        ? level
        : home > away
        ? won
        : lost;
    final theirs = home == away
        ? level
        : away > home
        ? won
        : lost;

    Widget figure(int n, TextAlign align) => SizedBox(
      width: 34,
      child: Text(
        '$n${suffix ?? ''}',
        textAlign: align,
        maxLines: 1,
        style: const TextStyle(
          fontSize: minFontSize,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: ink,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );

    // **THE TRACK IS THE WHOLE HALF, and the fill is this side's share of the
    // pair.** Eight shots to two is a bar at 80% and one at 20%, each in an
    // outline the size it COULD have been — asked for from the couch in exactly
    // those terms, and the outline is what makes the empty part of a bar mean
    // something: a side that had one shot to nine reads as nearly empty rather
    // than as a short mark floating in space.
    //
    // Each bar grows AWAY from the label, so the pair reads out from the middle
    // rather than both running the same way.
    Widget bar(double share, Color colour, {required bool fromRight}) =>
        Expanded(
          flex: barFlex.round(),
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x33FFFFFF)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: fromRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: share.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        );

    // No plate of its own any more: the panel above is one card and this is a
    // row inside it.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          figure(home, TextAlign.left),
          const SizedBox(width: 6),
          bar(homeShare, mine, fromRight: true),
          const SizedBox(width: 6),
          // **THE LABEL AS THE CATALOGUE WRITES IT, at the row's own size, in a
          // column of its own WIDTH.**
          //
          // It was uppercased and wrapped in a `FittedBox` of its own, so a
          // long stat shrank while a short one beside it did not — three rows
          // at three sizes down one panel. Asked for from the couch: no caps,
          // and no changing sizes.
          //
          // And then the bars still started somewhere different on every row,
          // because a centred label sized to its own text is what decides where
          // they begin — "Shots" and "Big Chances" are not the same width, so
          // the two columns of bars were not columns. Reported next, and
          // [pitchStatLabelWidth] is the answer: one slot, so the bars line up
          // down the panel whatever the words are.
          SizedBox(
            width: pitchStatLabelWidth,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: minFontSize,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
          ),
          const SizedBox(width: 6),
          bar(awayShare, theirs, fromRight: false),
          const SizedBox(width: 6),
          figure(away, TextAlign.right),
        ],
      ),
    );
  }
}
