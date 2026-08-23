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
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsGreenOn, vsRedOn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// How long the old table stays up before the division rearranges itself.
const Duration leagueMoveHold = Duration(milliseconds: 900);

/// How long a club takes to slide to its new place.
const Duration leagueMoveSlide = Duration(milliseconds: 800);

/// One row's height, and the whole block's height is a multiple of it — the
/// rows are POSITIONED rather than laid out in a column, which is what lets two
/// of them pass each other.
const double leagueMoveRowHeight = 34;

class LeagueMove extends ConsumerStatefulWidget {
  const LeagueMove({super.key});

  @override
  ConsumerState<LeagueMove> createState() => LeagueMoveState();
}

class LeagueMoveState extends ConsumerState<LeagueMove> {
  /// False while the old table is on screen. **A test seam**, and the whole
  /// state this widget has.
  bool moved = false;

  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _hold = Timer(leagueMoveHold, () {
      if (mounted) setState(() => moved = true);
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(leagueTableProvider);
    if (rows.isEmpty) return const SizedBox.shrink();

    // Reduced motion gets the answer without the movement: the deltas still
    // say who climbed, which is information rather than decoration.
    final still = MediaQuery.of(context).disableAnimations;
    final settled = moved || still;
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
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
          SizedBox(
            height: window.length * leagueMoveRowHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final i in window)
                  AnimatedPositioned(
                    key: ValueKey('summary-table-${rows[i].name}'),
                    duration: still ? Duration.zero : leagueMoveSlide,
                    curve: Curves.easeInOutCubic,
                    left: 0,
                    right: 0,
                    height: leagueMoveRowHeight,
                    // Where it WAS until the hold is up, then where the result
                    // put it — as a slot in the WINDOW rather than a rank in
                    // the division, so the two or three rows on screen are the
                    // ones that moved past each other.
                    top:
                        ((settled ? afterSlot[i]! : beforeSlot[i]!) *
                                leagueMoveRowHeight)
                            .toDouble(),
                    // **OUR ROW IS PICKED UP, CARRIED, AND SET DOWN.** A table
                    // where every row slides the same way is a list reordering
                    // itself; what the player did is move THEIR club, and the
                    // way to say that is to lift it off the page while the rest
                    // of the division shuffles underneath. Asked for in those
                    // words.
                    child: _Lift(
                      // Only ours, and only while it is travelling.
                      lifted: rows[i].isPlayer && !settled && !still,
                      still: still,
                      child: _MoveRow(
                        row: rows[i],
                        // The number counts with the movement rather than after
                        // it: a club sliding up the block while still printing
                        // the position it is leaving reads as a rendering
                        // fault. It is the DIVISION's rank, not the window's —
                        // the window is a viewport, not a league.
                        position: (settled ? i : from?[i] ?? i) + 1,
                        delta: from == null ? null : (from[i] - i),
                        // No arrow before the table has moved — it would give
                        // away the rearrangement it is meant to explain.
                        showDelta: settled,
                        still: still,
                      ),
                    ),
                  ),
              ],
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
  const _Lift({required this.lifted, required this.still, required this.child});

  final bool lifted;

  /// Reduced motion gets the answer without the movement: the deltas still say
  /// who climbed, so there is nothing to lift.
  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (still) return child;
    return AnimatedScale(
      scale: lifted ? 1.06 : 1,
      duration: leagueMoveSlide,
      curve: Curves.easeInOutCubic,
      child: AnimatedPhysicalModel(
        duration: leagueMoveSlide,
        curve: Curves.easeInOutCubic,
        // The row draws its own surface; this is only the shadow under it, so
        // the model itself is transparent.
        color: Colors.transparent,
        shadowColor: Colors.black,
        elevation: lifted ? 12 : 0,
        borderRadius: BorderRadius.circular(8),
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
  });

  final LeagueRow row;
  final int position;

  /// Positive means climbed — a smaller position number is a better one, which
  /// is `LeagueRow.posDelta`'s own sign.
  final int? delta;
  final bool showDelta;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = glassText(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          // The lift is neutral, the way the full table marks your row: a hue
          // here would compete with the arrow that is the point of the block.
          color: row.isPlayer ? ink.withValues(alpha: 0.11) : null,
        ),
        child: Padding(
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
                    color: row.isPlayer
                        ? kit.accentBright
                        : glassMuted(context),
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
                    color: row.isPlayer ? kit.accentBright : ink,
                  ),
                ),
              ),
              if (delta != null)
                AnimatedOpacity(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  opacity: showDelta ? 1 : 0,
                  child: _Delta(delta: delta!, isPlayer: row.isPlayer),
                ),
              const SizedBox(width: 8),
              Text(
                '${row.pts}',
                key: row.isPlayer ? const ValueKey('summary-table-pts') : null,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        '–',
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
