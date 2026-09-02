/// The table, moving — what the match just did to the division.
///
/// **A scoreline is only half of what a league match was.** The other half is
/// where it left you, and the other seven clubs played this round too: a table
/// that arrives already settled says the standings are a page you go and look
/// at, when what actually happened is that the division rearranged itself
/// around a result you just watched.
///
/// So the block opens on the table AS IT WAS — every club at the position it
/// held at the end of the previous round — holds there long enough to be read,
/// and then moves. Nothing here decides a position: `buildLeagueTable` already
/// stamps every row with `prevPos` and `posDelta` for the next-match card, and
/// this is the same two figures given the movement they describe.
///
/// **It refuses to animate rather than invent one.** The previous positions are
/// cleared by the engine whenever they cannot honestly be compared — a season
/// rollover, or a round the table was never built during — and a club with no
/// `prevPos` has no "where we were". When any row is missing one the block
/// draws the settled table and claims no movement at all.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsGreenOn, vsRedOn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart' show nightSceneOf;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// How long the old table stays up before the division rearranges itself.
const Duration leagueMoveHold = Duration(milliseconds: 900);

/// How long a club takes to slide to its new place.
const Duration leagueMoveSlide = Duration(milliseconds: 1000);

/// **THE MOVE IS THREE BEATS, and the slide is only the middle one.** It was
/// one 800ms glide with the lift and the slide on top of each other, and it
/// read as a list reordering itself — reported as too fast, and as needing to
/// look like OUR card being pulled out, moved, and put back. So: the row is
/// lifted off the page first (up in scale, into the accent, a shadow under
/// it), THEN carried, THEN set back down — and only once it is down do the
/// arrows say what happened.
const Duration leagueMoveLift = Duration(milliseconds: 520);
const Duration leagueMoveSetDown = Duration(milliseconds: 460);

/// The whole sequence after the hold, as the one clock it runs on.
final Duration leagueMoveTotal =
    leagueMoveLift + leagueMoveSlide + leagueMoveSetDown;

/// Where each beat sits on that clock, 0–1.
double _share(Duration d) => d.inMilliseconds / leagueMoveTotal.inMilliseconds;
final double _liftEnd = _share(leagueMoveLift);
final double _slideEnd = _liftEnd + _share(leagueMoveSlide);

/// One row's height, and the whole block's height is a multiple of it — the
/// rows are POSITIONED rather than laid out in a column, which is what lets two
/// of them pass each other.
const double leagueMoveRowHeight = 34;

/// **THE THREE FIGURE COLUMNS, and one set of widths for the heads and the
/// rows.** They are declared once because a header that is laid out separately
/// from its rows is a header that drifts out of line the first time either side
/// is touched.
const double _colPlayed = 20;
const double _colDiff = 30;
const double _colPts = 26;

/// The gap between the club name and the first figure.
const double _colGap = 6;

/// Wider than the other two: this head is a word in most locales — "GD", but
/// "Diff" in French and "الفارق" in Arabic — and the figure under it carries a
/// sign, so it is the widest thing in the three columns either way.

class LeagueMove extends ConsumerStatefulWidget {
  const LeagueMove({super.key});

  @override
  ConsumerState<LeagueMove> createState() => LeagueMoveState();
}

class LeagueMoveState extends ConsumerState<LeagueMove>
    with SingleTickerProviderStateMixin {
  /// False while the old table is on screen. **A test seam.**
  bool moved = false;

  Timer? _hold;

  /// The lift, the slide and the set-down, in that order, on one clock.
  late final AnimationController _move;

  /// How far off the page our row is, 0–1: up during the lift, held through
  /// the slide, back down at the end.
  double get lift {
    final t = _move.value;
    if (t <= _liftEnd) return Curves.easeOutBack.transform(t / _liftEnd);
    if (t <= _slideEnd) return 1;
    return 1 -
        Curves.easeInOutCubic.transform((t - _slideEnd) / (1 - _slideEnd));
  }

  /// How far along the slide the rows are, 0–1.
  double get travel {
    final t = _move.value;
    if (t <= _liftEnd) return 0;
    if (t >= _slideEnd) return 1;
    return Curves.easeInOutCubic.transform(
      (t - _liftEnd) / (_slideEnd - _liftEnd),
    );
  }

  @override
  void initState() {
    super.initState();
    _move = AnimationController(vsync: this, duration: leagueMoveTotal);
    _hold = Timer(leagueMoveHold, () {
      if (!mounted) return;
      setState(() => moved = true);
      _move.forward();
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(leagueTableProvider);
    if (rows.isEmpty) return const SizedBox.shrink();

    // Reduced motion gets the answer without the movement: the deltas still
    // say who climbed, which is information rather than decoration.
    final still = MediaQuery.of(context).disableAnimations;
    final from = _previousOrder(rows);

    // **THE TEAM ABOVE AND THE TEAM BELOW, and nobody else.** Twenty rows of a
    // division a player is not in is a table; what they came to see is whether
    // they went up, and past whom. Asked for directly.
    //
    // The window has to hold both ENDS of the move or the slide has nothing to
    // pass: our neighbours as they were, and our neighbours as they are.
    final window = _window(rows, from);
    final beforeSlot = _slots(window, (i) => from?[i] ?? i);
    final afterSlot = _slots(window, (i) => i);

    return GlassPanel(
      // Deep, like every other card on the report: this IS the table's card
      // now — the panel the summary wrapped round it was a card in a card —
      // and on the daylight sky the lighter glass left the points at 2.9:1.
      density: GlassDensity.deep,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // **THE DIVISION AND THE COLUMN HEADS ARE ONE ROW.** Three columns
          // of bare figures is a table nobody can read: the points were the
          // only number here and they were legible because they were the ONLY
          // number. Played and goal difference arrive with the shot asked for
          // from the couch, and a figure column with no head is a riddle.
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ref.watch(divisionNameProvider).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: glassMuted(context),
                    ),
                  ),
                ),
                _Head(width: _colPlayed, label: t('table.col_played')),
                _Head(width: _colDiff, label: t('table.col_gd')),
                _Head(width: _colPts, label: t('table.col_pts')),
              ],
            ),
          ),
          SizedBox(
            height: window.length * leagueMoveRowHeight,
            child: AnimatedBuilder(
              animation: _move,
              builder: (context, _) {
                // Reduced motion, or the clock has run: the settled table.
                final travel = still ? 1.0 : this.travel;
                final lift = still ? 0.0 : this.lift;
                final settled = still || _move.isCompleted;
                // The position counts over as the row crosses the halfway
                // point of its slide.
                final rankNow = travel >= 0.5;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // **OUR ROW IS DRAWN LAST**, so while it is lifted it is
                    // over the rows it passes rather than under them.
                    for (final i in [
                      for (final i in window)
                        if (!rows[i].isPlayer) i,
                      for (final i in window)
                        if (rows[i].isPlayer) i,
                    ])
                      Positioned(
                        key: ValueKey('summary-table-${rows[i].name}'),
                        left: 0,
                        right: 0,
                        height: leagueMoveRowHeight,
                        // From where it WAS to where the result put it — as a
                        // slot in the WINDOW rather than a rank in the
                        // division, so the two or three rows on screen are the
                        // ones that moved past each other.
                        top: lerpDouble(
                          beforeSlot[i]! * leagueMoveRowHeight,
                          afterSlot[i]! * leagueMoveRowHeight,
                          travel,
                        )!,
                        // **OUR ROW IS PICKED UP, CARRIED, AND SET DOWN.** A
                        // table where every row slides the same way is a list
                        // reordering itself; what the player did is move THEIR
                        // club, and the way to say that is to lift it off the
                        // page while the rest of the division shuffles
                        // underneath. Asked for in those words, twice.
                        child: _Lift(
                          lift: rows[i].isPlayer ? lift : 0,
                          child: _MoveRow(
                            row: rows[i],
                            lift: rows[i].isPlayer ? lift : 0,
                            // The number counts with the movement rather than
                            // after it: a club sliding up the block while still
                            // printing the position it is leaving reads as a
                            // rendering fault. It is the DIVISION's rank, not
                            // the window's — the window is a viewport, not a
                            // league.
                            position: (rankNow ? i : from?[i] ?? i) + 1,
                            delta: from == null ? null : (from[i] - i),
                            // No arrow before the row is back down — it would
                            // give away the rearrangement it is meant to
                            // explain.
                            showDelta: settled,
                            still: still,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// **THE CLUB IS PICKED UP, CARRIED, AND SET DOWN.**
///
/// A table where every row slides the same way is a list reordering itself.
/// What the player actually did is move THEIR club, and the way to say that is
/// to lift it off the page while the rest of the division shuffles underneath
/// it — asked for in those words, and the reason it reads is that a raised
/// thing is unambiguously the SUBJECT of the movement rather than one of its
/// participants.
///
/// The scale is small and the shadow does most of it. A row at 1.3 is a row
/// covering its neighbours, which is the opposite of showing what it passed.
class _Lift extends StatelessWidget {
  const _Lift({required this.lift, required this.child});

  /// 0 flat on the page, 1 fully lifted. Driven, not animated here: the
  /// block's one clock decides where in the sequence this is.
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (lift <= 0) return child;
    return Transform.scale(
      scale: 1 + 0.10 * lift,
      child: PhysicalModel(
        // The row draws its own surface; this is only the shadow under it, so
        // the model itself is transparent.
        color: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 14 * lift,
        borderRadius: BorderRadius.circular(9),
        child: child,
      ),
    );
  }
}

/// Which rows are worth drawing: ours, and whoever is beside us at either end
/// of the move.
///
/// **Both ends, or the movement has nothing to happen against.** A window of
/// the FINAL neighbours alone would show our row arriving next to two clubs it
/// never passed; the one it overtook has to be on screen for the overtake to be
/// visible.
///
/// Returned in the settled table's own order, so the after-state reads top to
/// bottom without sorting anything.
List<int> _window(List<LeagueRow> rows, List<int>? from) {
  final ours = rows.indexWhere((r) => r.isPlayer);
  // No player row — a preview, or a division we are not in. Show the lot, which
  // is what this widget did before there was a window at all.
  if (ours < 0) return [for (var i = 0; i < rows.length; i++) i];

  int at(int i) => from?[i] ?? i;
  final ourFrom = at(ours);
  final keep = <int>{ours};
  for (var i = 0; i < rows.length; i++) {
    if ((at(i) - ourFrom).abs() == 1 || (i - ours).abs() == 1) keep.add(i);
  }
  return [
    for (var i = 0; i < rows.length; i++)
      if (keep.contains(i)) i,
  ];
}

/// Where each windowed row sits IN THE WINDOW, given how it is ranked.
///
/// The rows are positioned absolutely so two of them can pass each other, and a
/// window of three cannot use division ranks for that — rank 12 would be twelve
/// rows down a three-row block.
Map<int, int> _slots(List<int> window, int Function(int) rank) {
  final order = [...window]..sort((a, b) => rank(a).compareTo(rank(b)));
  return {for (final (slot, i) in order.indexed) i: slot};
}

/// Where each row sat at the end of the previous round, as an INDEX into the
/// settled table, or null when the movement cannot honestly be drawn.
///
/// Null covers three cases and they are all the same case: the engine cleared
/// the snapshot (a rollover, or a round nobody rendered), a row is new to the
/// division, or the stored positions are not a permutation of this table — a
/// club renamed mid-season, say. Half a movement is worse than none.
List<int>? _previousOrder(List<LeagueRow> rows) {
  final out = <int>[];
  final seen = <int>{};
  for (final row in rows) {
    final was = row.prevPos;
    if (was == null || was < 1 || was > rows.length || !seen.add(was)) {
      return null;
    }
    out.add(was - 1);
  }
  return out;
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({
    required this.row,
    required this.position,
    required this.delta,
    required this.showDelta,
    required this.still,
    this.lift = 0,
  });

  final LeagueRow row;
  final int position;

  /// How far off the page this row is — see `_Lift`. **The colour changes with
  /// it**: a lifted card goes into the club's accent, so what is being carried
  /// is unmistakably the card and not a highlight bar.
  final double lift;

  /// Positive means climbed — a smaller position number is a better one, which
  /// is `LeagueRow.posDelta`'s own sign.
  final int? delta;
  final bool showDelta;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = glassText(context);
    // At rest the mark is neutral, the way the full table marks your row: a
    // hue here would compete with the arrow that is the point of the block.
    // LIFTED, it goes into the accent — that is the card being pulled out.
    // And LIGHTER on a daylight pane at rest: the text ink there is dark, and a
    // dark wash under the gold points took them to 2.9:1 once the table
    // stopped sitting on a second pane.
    final rest = nightSceneOf(context)
        ? ink.withValues(alpha: 0.11)
        : Colors.white.withValues(alpha: 0.45);
    final carried = kit.accent.withValues(alpha: 0.92);
    // **AND THE INK HAS TO COME WITH IT.** The lifted row is painted in the
    // club's own accent at 92%, and its text stayed `accentBright` — a lighter
    // member of the SAME hue — so the one row the block exists to pull out was
    // the one that could go dark-on-dark or light-on-light depending on the
    // kit. Reported from the couch, and in exactly those terms: the font colour
    // has to change as it is pulled out. `kit.accentInk` is what the theme
    // already measured for text on a filled accent, so this is the app's own
    // answer rather than a second one.
    Color lifted(Color atRest) =>
        row.isPlayer ? Color.lerp(atRest, kit.accentInk, lift)! : atRest;
    final nameInk = lifted(
      row.isPlayer ? glassAccent(context, kit.accentBright) : ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // **CLIPPED, because our row wears a bar down its left edge** and a
      // `BoxDecoration` cannot round a corner over a one-sided border — it
      // asserts on it. So the bar is a child painted into the corner instead,
      // and the clip is what rounds it.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: DecoratedBox(
        decoration: BoxDecoration(
          color: !row.isPlayer ? null : Color.lerp(rest, carried, lift),
        ),
        // **EXPANDED, or the row's text rides high in it.** A `Stack` puts a
        // non-positioned child at its TOP-LEFT at that child's own intrinsic
        // size — so the padded row sat eighteen points tall at the top of a
        // thirty-point slot, and every figure in the table was off centre.
        // Reported off the screen the moment the bar went in. `expand` hands
        // the row the whole slot, and the `Row` centres inside it.
        child: Stack(
          fit: StackFit.expand,
          children: [
            // **A BAR, not just a wash.** The tinted row alone is what the
            // table had, and on the lighter panes it is nearly nothing; the
            // shot asked for from the couch marks the club with a rule down
            // the edge, which reads at any opacity. It sits inside the 8-point
            // gutter, so it moves no figure out of its column.
            if (row.isPlayer)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(
                  color: glassAccent(context, kit.accentBright),
                ),
              ),
            Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$position',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: lifted(
                      row.isPlayer
                          ? glassAccent(context, kit.accentBright)
                          : glassMuted(context),
                    ),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: row.isPlayer
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: nameInk,
                  ),
                ),
              ),
              // **THE ARROW STAYS, and it stays LEFT of the figures.** It is
              // the whole point of this block — who the result moved you past
              // — and it is not a column: it appears only once the row has
              // settled. Inside the figure columns it would push them out of
              // line with their heads every time it faded in.
              if (delta != null)
                AnimatedOpacity(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  opacity: showDelta ? 1 : 0,
                  child: _Delta(delta: delta!, isPlayer: row.isPlayer),
                ),
              const SizedBox(width: _colGap),
              _Figure(
                width: _colPlayed,
                text: '${row.played}',
                colour: lifted(glassMuted(context)),
              ),
              _Figure(
                width: _colDiff,
                // Signed, always: a goal difference of 6 and one of −6 are the
                // same digit and opposite seasons, so the sign is the figure.
                text: row.gd > 0 ? '+${row.gd}' : '${row.gd}',
                // The same green-or-red scale the stat rows and the verdict
                // read. Level is neither, so it takes the muted ink.
                // Green and red survive the lift — they are the only two
                // figures on the row whose COLOUR is the information.
                colour: row.gd == 0
                    ? lifted(glassMuted(context))
                    : glassAccent(
                        context,
                        row.gd > 0 ? vsGreenOn(context) : vsRedOn(context),
                      ),
              ),
              _Figure(
                width: _colPts,
                text: '${row.pts}',
                textKey: row.isPlayer
                    ? const ValueKey('summary-table-pts')
                    : null,
                size: 15,
                // **THE PANE'S OWN INK, not the coin gold.** Points are not
                // money, and the gold went bronze on a light pane — reported
                // as not liking the bronze. Bold is what makes them the
                // figure that matters on the row.
                colour: lifted(ink),
              ),
            ],
          ),
        ),
          ],
        ),
        ),
      ),
    );
  }
}

/// One column head, over the figures it names — see [_colPlayed].
class _Head extends StatelessWidget {
  const _Head({required this.width, required this.label});

  final double width;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      label.toUpperCase(),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
        color: glassMuted(context),
      ),
    ),
  );
}

/// One figure in a fixed column, right-aligned and tabular.
///
/// **Tabular is what makes it a column.** These are stacked four deep and slide
/// past each other; proportional digits would have the ones column wandering as
/// a 1 replaced a 9.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.width,
    required this.text,
    required this.colour,
    this.size = 12,
    this.textKey,
  });

  final double width;
  final String text;
  final Color colour;
  final double size;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      text,
      key: textKey,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: colour,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Climbed, fell or held — the green-amber-red scale the form dots read, so a
/// glance at the block says which without a number being parsed.
class _Delta extends StatelessWidget {
  const _Delta({required this.delta, required this.isPlayer});

  final int delta;
  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) {
      return Text(
        '-',
        key: isPlayer ? const ValueKey('summary-table-held') : null,
        style: TextStyle(fontSize: 12, color: glassMuted(context)),
      );
    }
    final up = delta > 0;
    final colour = up ? vsGreenOn(context) : vsRedOn(context);
    return Row(
      key: isPlayer
          ? ValueKey(up ? 'summary-table-climbed' : 'summary-table-fell')
          : null,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: 18,
          color: colour,
        ),
        Text(
          '${delta.abs()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colour,
          ),
        ),
      ],
    );
  }
}
