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
            height: rows.length * leagueMoveRowHeight,
            child: Stack(
              children: [
                for (var i = 0; i < rows.length; i++)
                  AnimatedPositioned(
                    key: ValueKey('summary-table-${rows[i].name}'),
                    duration: still ? Duration.zero : leagueMoveSlide,
                    curve: Curves.easeInOutCubic,
                    left: 0,
                    right: 0,
                    height: leagueMoveRowHeight,
                    // Where it WAS until the hold is up, then where the result
                    // put it. `from` is null when there is nothing honest to
                    // move from, and then every row starts where it ends.
                    top: ((settled ? i : from?[i] ?? i) * leagueMoveRowHeight)
                        .toDouble(),
                    child: _MoveRow(
                      row: rows[i],
                      // The number counts with the movement rather than after
                      // it: a club sliding up the block while still printing
                      // the position it is leaving reads as a rendering fault.
                      position: (settled ? i : from?[i] ?? i) + 1,
                      delta: from == null ? null : (from[i] - i),
                      // No arrow before the table has moved — it would give
                      // away the rearrangement it is meant to explain.
                      showDelta: settled,
                      still: still,
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
    final colour = up ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
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
