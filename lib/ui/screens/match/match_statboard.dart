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
import 'package:merge_empire_fc/ui/screens/match/boost_bar_paint.dart' show liveBoostColour;
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart' show benchCardAspect;
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart' show vsGreenOn, vsRedOn;
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
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
    // **THE ENGINE'S `home` MEANS US, whatever the venue.** This read it as
    // the VENUE and folded [isHome] in, so every counter on this board —
    // shots, on target, big chances missed, corners, goals — was swapped with
    // the opposition's at every away fixture. Found alongside the same mistake
    // in the commentary's chance line (`match_clock.dart`), which was reported
    // from the couch; this one says nothing out loud and just reports the
    // wrong numbers.
    //
    // The swing below looked wrong and was not: `ours == isHome` XORed a
    // second time and cancelled it, so momentum was right while the figures
    // beside it were inverted. Both are stated plainly now.
    // **AND A CHANCE IS NOT A GOAL ABOUT THIS.** See [eventIsOurs]: the engine
    // lists goals ours-first and ROLLS chances and corners venue-first, so the
    // fix below only ever got the goal counter right. Away from home the
    // shots, the on-target count, the big chances missed and the corners were
    // still swapped with the opposition's — which is the same 2-0 away defeat
    // showing more shots that the note above is about, in the half of it that
    // survived.
    final ours = e.team == null ? null : eventIsOurs(e, isHome: isHome);
    switch (e.type) {
      case 'goal':
        if (ours ?? true) {
          goalsUs++;
        } else {
          goalsThem++;
        }
        swing = swing * 0.7 + ((ours ?? true) ? 0.3 : -0.3);
      // **A CHANCE IS NOT AUTOMATICALLY A BIG ONE, and this counted every one
      // of them as one.** `bigUs++` sat on the same branch as `shotsUs++`,
      // unconditionally, so the Shots row and the Big Chances row were the same
      // number in every match ever played — two of a five-row board saying one
      // thing. Reported from the couch off a goalless home win that read
      // "Shots 14 / Big Chances 14" and looked like a robbery rather than a
      // quiet afternoon.
      //
      // The flag was already there and already travelling: the engine marks
      // `big` at xG 0.22 (`match_events.dart`) and `MatchClockEvent` carries it
      // — `chanceFeedBigXg`'s note in `match_clock.dart` says in as many words
      // that the engine's flag "marks what the match statistics count as a big
      // chance", and the statistics were the one reader that ignored it.
      //
      // **And Big Missed was off-target shots**, which is a different stat
      // wearing this one's name — a scuffed half-chance dragged wide counted,
      // and a one-on-one saved did not. A `chance` event is a NON-goal by
      // construction (the engine lists goals separately), so a big chance in
      // this list is exactly a big chance missed. That leaves the board
      // internally consistent for the first time: big chances = big missed +
      // goals, which is what the goal folding below has always claimed.
      //
      // The JS could not be consulted — `../merge-empire-fc` is not in this
      // container — so this follows the port's own flag rather than the
      // spec's wording.
      case 'chance':
        if (ours ?? true) {
          shotsUs++;
          if (e.shotResult == 'on_target') onTargetUs++;
          if (e.big) {
            bigUs++;
            bigMissedUs++;
          }
        } else {
          shotsThem++;
          if (e.shotResult == 'on_target') onTargetThem++;
          if (e.big) {
            bigThem++;
            bigMissedThem++;
          }
        }
        swing = swing * 0.85 + ((ours ?? true) ? 0.15 : -0.15);
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
  // **[swing] IS OUR-POSITIVE AND EVERYTHING BELOW IS HOME-POSITIVE.**
  // `resting`, `possHome` and `dangerHome` are all stated about the HOME side —
  // they come off `ratingDiffHome` and `stratBiasHome` — and the swing counted
  // up from the events is about US. Those are the same thing at home and
  // opposite numbers away, and the conversion was missing: away from home the
  // swing was added with the wrong sign, so a side being battered saw the
  // possession bar and the momentum arrow both leaning ITS way.
  //
  // That is the other half of the venue mix-up in the loop above, and the pair
  // of them is why a 2-0 away defeat could show 67% possession and more shots.
  // Reported from the couch as exactly that scoreline.
  final swingHome = isHome ? swing : -swing;
  final homePct = resting + swingHome * 22;

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
  final dangerHome =
      (chanceShare * 0.68 + resting * 0.32 + swingHome * 14).clamp(20.0, 80.0);
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

/// One thing lifting the side right now — a boost window or a lit match
/// trait. [until] is the minute a window closes, null for a trait.
/// One thing lifting the side, and — the part the list did not say — WHAT
/// it does: a boost's copy, a trait's own figure at its level.
typedef ActiveLift = ({
  String id,
  String icon,
  String label,
  String effect,
  int? until,

  /// The man carrying it, for a trait — drawn as his card. Null for a boost.
  CardView? card,
});

class MatchStatboard extends StatelessWidget {
  const MatchStatboard({
    super.key,
    required this.stats,
    required this.isHome,
    this.active = const [],
  });

  final LiveStats stats;

  /// **Everything running, which the one-at-a-time pill deliberately cannot
  /// say.** Five lifts can hold at once; this is the only surface that lists
  /// them all, and it costs the match screen no height because this sheet is
  /// already the details door behind the board.
  final List<ActiveLift> active;

  /// Which column is OURS. Fixed for the whole match, so the accent goes on once.
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **EVERY ROW IS A BAR, not a pair of numbers with a word between.** The
    // board was three columns of 12pt text, which is a spreadsheet; a match
    // stat is a SHARE of one afternoon, and the possession bar was the only
    // row that said so. Each row now runs a two-tone bar under its figures,
    // ours in the kit, theirs in the quiet ink — so 4 shots to 2 is read as
    // a shape before it is read as a sum. Reported from the couch as ugly.
    return Container(
      key: const ValueKey('match-statboard'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: kit.surface2.withValues(alpha: 0.9),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                t('match.stats_label').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
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
          const SizedBox(height: 10),
          _StatRow(
            label: t('match.stat.possession'),
            home: '${stats.possHome}%',
            away: '${stats.possAway}%',
            homeShare: stats.possHome,
            awayShare: stats.possAway,
            homeOurs: isHome,
          ),
          for (final row in stats.rows)
            _StatRow(
              label: t(row.labelKey),
              home: '${row.home}',
              away: '${row.away}',
              homeShare: row.home,
              awayShare: row.away,
              homeOurs: isHome,
            ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              t('match.active.title').toUpperCase(),
              key: const ValueKey('match-active'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: kit.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            // **EACH LIFT SAYS WHAT IT DOES.** A row that read "🎩 Big Game
            // Player" named the thing and not the effect — reported from
            // the couch. The figure sits beside the name, in the colour of
            // whatever is lifting, with the window's end where there is one.
            for (final lift in active)
              if (lift.card == null)
              Container(
                key: ValueKey('match-active-${lift.id}'),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: liftColour(kit, lift.id).withValues(alpha: 0.14),
                  border: Border.all(color: liftColour(kit, lift.id).withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    GlyphOrIcon(lift.icon, size: 16, color: liftColour(kit, lift.id)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lift.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (lift.effect.isNotEmpty)
                      Text(
                        lift.effect,
                        key: ValueKey('match-active-effect-${lift.id}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: liftColour(kit, lift.id),
                        ),
                      ),
                    if (lift.until != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        t('match.active.until', {'minute': '${lift.until}'}),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kit.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // **THE MEN WHOSE TRAIT IS LIT, AS THEIR CARDS.** A row that
            // said "🎩 Big Game Player" named the trait and not the man; the
            // card is who is doing it, the name and figure under it what.
            // Off the list the moment he is off, hurt or sent off, because
            // the list is built from the lineup every tick. Asked for from
            // the couch, with the column count left to the width.
            // **AND THEY COME AND GO, rather than blink.** The sheet
            // follows the match, so a man's card leaves when he does — a
            // fade and a shrink, keyed on who is listed. Asked for.
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                // The switcher's own stack centres, which centred a short
                // row of cards; the list starts at the left like every row
                // above it. Reported from the couch.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(anim), child: child),
                ),
                child: !active.any((l) => l.card != null)
                    ? const SizedBox(width: double.infinity)
                    : LayoutBuilder(
                key: ValueKey('match-active-cards-${[for (final l in active) if (l.card != null) l.id].join(',')}'),
                builder: (context, box) {
                  // Three at least: two made the cards the size of the
                  // sheet's own header. Asked for from the couch.
                  final columns = benchColumns(box.maxWidth).clamp(3, 4);
                  const gap = 8.0;
                  final width = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    key: const ValueKey('match-active-cards'),
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final lift in active)
                        if (lift.card case final view?)
                          SizedBox(
                            key: ValueKey('match-active-${lift.id}'),
                            width: width,
                            child: Column(
                              children: [
                                // A card fills its box, so the bench's shape.
                                AspectRatio(
                                  aspectRatio: benchCardAspect,
                                  child: PlayerCard(view: view),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${lift.icon} ${lift.label}',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: kit.accentBright,
                                  ),
                                ),
                                if (lift.effect.isNotEmpty)
                                  Text(
                                    lift.effect,
                                    key: ValueKey('match-active-effect-${lift.id}'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: kit.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    ],
                  );
                },
              ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A boost's own colour; a trait takes the kit's.
  static Color liftColour(KitTheme kit, String id) => switch (id) {
    'crowd_roar' || 'sharp_shooting' || 'park_the_bus' => liveBoostColour(id),
    _ => kit.accentBright,
  };
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

/// One row: a figure each side of a centred label, and a two-tone bar under
/// them sharing the row by the two figures. A figure that has gone UP since
/// the last paint pulses.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.home,
    required this.away,
    required this.homeShare,
    required this.awayShare,
    required this.homeOurs,
  });

  final String label;
  final String home;
  final String away;
  final int homeShare;
  final int awayShare;
  final bool homeOurs;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final total = homeShare + awayShare;
    // An empty row — no shots yet either side — is a bar at rest, half each,
    // in the quiet ink: nothing to compare is not the same as home ahead.
    final h = total == 0 ? 1 : homeShare;
    final a = total == 0 ? 1 : awayShare;
    // Ours green, theirs red — the pair the full-time pitch draws, so the
    // sheet and the grass read the same way. Asked for from the couch.
    final ours = vsGreenOn(context);
    final theirs = vsRedOn(context);
    Widget figure(String v, TextAlign align) => Expanded(
      child: _Pulsing(value: v, align: align),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              // Stretched, or a `ColoredBox` with nothing in it is laid out
              // at no height and the bar is invisible — which is what the
              // old possession bar had been all along.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: h,
                    child: ColoredBox(color: total == 0 ? theirs : (homeOurs ? ours : theirs)),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: a,
                    child: ColoredBox(color: total == 0 ? theirs : (homeOurs ? theirs : ours)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          fontSize: 16,
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
        // ten more a side put the grass back round it.
        //
        // **And then wider still, to clear the goalmouths.** `MomentumArrow`
        // paints HOME and AWAY on the grass at either end — the two words that
        // say which way the match was being played — and the panel was sitting
        // over both of them. Asked for from the couch: enough margin that the
        // labels come through, and then ten back the other way once they did.
        // The vertical went up with it, because a panel that has stopped being
        // full-width should not still be full-height.
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
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
                    vertical: 8,
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
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: _PitchStatRow(
                            label: row.label,
                            home: row.home,
                            away: row.away,
                            suffix: row.suffix,
                            isHome: isHome,
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

/// One row of [PitchStatOverlay].
///
/// **THE SHEET'S SHAPE, NOT A ROW OF ITS OWN.** It was `home · bar · STAT ·
/// bar · away` on one line, two bars growing away from a label; the stats
/// sheet draws a figure each side of a centred label with ONE two-tone bar
/// under them, and that is the shape asked for from the couch. OUR half of
/// the bar is always green and THEIRS always red — it was won/lost/level by
/// row for a round, and a fixed pair per side was asked for as the easier
/// read. Fixed members rather than `vsGreenOn`/`vsRedOn`, because this is
/// laid over grass, which is a mid green in both themes.
class _PitchStatRow extends StatelessWidget {
  const _PitchStatRow({
    required this.label,
    required this.home,
    required this.away,
    required this.suffix,
    required this.isHome,
  });

  final String label;
  final int home;
  final int away;
  final String? suffix;
  final bool isHome;

  static const Color ours = Color(0xFF4ADE80);
  static const Color theirs = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFF2F5F3);
    // An empty pair is a bar at rest, half each: nothing to compare is not
    // the same as one side ahead.
    final total = home + away;
    final h = total == 0 ? 1 : home;
    final a = total == 0 ? 1 : away;

    Widget figure(int n, TextAlign align) => Expanded(
      child: Text(
        '$n${suffix ?? ''}',
        key: ValueKey('pitch-stat-${align == TextAlign.left ? 'home' : 'away'}-$label'),
        textAlign: align,
        maxLines: 1,
        // 13, not 16: six rows have to stand on the grass at FULL size, and
        // the block's `FittedBox` is an escape hatch, not a layout. Asked for
        // from the couch: never small type in the stats.
        style: const TextStyle(
          fontSize: 13,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: ink,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              figure(home, TextAlign.left),
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: minFontSize,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xCCF2F5F3),
                  ),
                ),
              ),
              figure(away, TextAlign.right),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: h,
                    child: ColoredBox(
                      key: ValueKey('pitch-stat-bar-home-$label'),
                      color: isHome ? ours : theirs,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: a,
                    child: ColoredBox(
                      key: ValueKey('pitch-stat-bar-away-$label'),
                      color: isHome ? theirs : ours,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
