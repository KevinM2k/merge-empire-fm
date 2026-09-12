/// Where the match was played, drawn from the positional record.
///
/// **The heatmap is a by-product of deciding the score**, not a system of its
/// own: `attack_sequence.dart` records every duel and shot with the zone it
/// happened in while it settles the result, and `match_analysis.dart` adds the
/// stream up. This paints those twenty zone counts over the same pitch the
/// squad tab stands the eleven on — `SquadPitch`, reused rather than copied,
/// so the markings, the turf and the 7:10 box are the ones the player already
/// knows — and puts the flank shares and the busiest duellist beside it.
///
/// Frame: our own goal is at the BOTTOM and we attack UP the screen, exactly
/// as the squad tab draws the formation, so band 0 is the top quarter. Low x
/// is our right, which is screen-LEFT — see the header of `pitch_space.dart`;
/// the labels under the bars are written in each side's own left and right,
/// which is what the report's copy says too.
///
/// Ours is the kit's accent; theirs is [conceded], the red a goal against is
/// drawn in everywhere else.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/match_analysis.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart'
    show cardDisplayName;
import 'package:merge_empire_fc/ui/screens/match/goal_replay.dart'
    show conceded;
import 'package:merge_empire_fc/ui/screens/squad/squad_pitch.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Blocked shots against a side at which the defence gets a line of its own.
const int blockedWorthALine = 3;

/// The positional record, or null when the match recorded none — a match
/// played before the sim existed, or one with no lineup to stand on the pitch.
Map<String, dynamic>? positionalOf(Map<String, dynamic> result) {
  final p = _map(result['positional']);
  if (p == null) return null;
  final ev = p['ev'];
  return ev is List && ev.isNotEmpty ? p : null;
}

/// The twenty zones, painted over the pitch.
class MatchHeatmap extends StatelessWidget {
  const MatchHeatmap({required this.positional, super.key});

  final Map<String, dynamic> positional;

  List<int> _zones(String side) {
    final raw = (positional['zone'] as Map?)?[side];
    return raw is List
        ? [for (final v in raw) (v as num).toInt()]
        : List.filled(pitchZones, 0);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SquadPitch(
      child: CustomPaint(
        key: const ValueKey('match-heatmap'),
        painter: HeatmapPainter(
          ours: _zones('ours'),
          theirs: _zones('theirs'),
          ourInk: kit.accentBright,
          theirInk: conceded,
        ),
      ),
    );
  }
}

/// Two translucent washes per zone, one a side, each as strong as that zone's
/// share of the side's busiest zone.
class HeatmapPainter extends CustomPainter {
  const HeatmapPainter({
    required this.ours,
    required this.theirs,
    required this.ourInk,
    required this.theirInk,
  });

  final List<int> ours;
  final List<int> theirs;
  final Color ourInk;
  final Color theirInk;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / pitchLanes;
    final h = size.height / pitchBands;
    void wash(List<int> zones, Color ink) {
      final peak = zones.fold(0, (a, b) => a > b ? a : b);
      if (peak == 0) return;
      for (var z = 0; z < pitchZones && z < zones.length; z++) {
        if (zones[z] == 0) continue;
        // A gentle curve so the quiet zones still show and the busiest one
        // does not blot out the markings.
        final t = zones[z] / peak;
        final alpha = 0.12 + 0.6 * t * t;
        canvas.drawRect(
          Rect.fromLTWH(zoneLane(z) * w, zoneBand(z) * h, w, h).deflate(1.5),
          Paint()..color = ink.withValues(alpha: alpha),
        );
      }
    }

    wash(theirs, theirInk);
    wash(ours, ourInk);
  }

  @override
  bool shouldRepaint(HeatmapPainter old) =>
      old.ours != ours ||
      old.theirs != theirs ||
      old.ourInk != ourInk ||
      old.theirInk != theirInk;
}

/// The card on the summary: heatmap, flank shares, the busiest duellist.
///
/// Renders nothing for a result with no positional record, so an old save's
/// last match and a fixed-rating cup tie lose nothing but this panel.
class PositionalCard extends ConsumerWidget {
  const PositionalCard({required this.result, super.key});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positional = positionalOf(result);
    if (positional == null) return const SizedBox.shrink();
    final kit = Theme.of(context).extension<KitTheme>()!;
    final text = Theme.of(context).textTheme;
    final ourName = '${result['clubName'] ?? ''}';
    final theirName = '${result['opponentName'] ?? ''}';
    final ours = flankShares(positional, 'ours');
    final theirs = flankShares(positional, 'theirs');
    final shots = _map(positional['shots']) ?? const {};
    final xg = _map(positional['xg']) ?? const {};
    final save = ref.watch(gameProvider).state;
    final busiest = busiestDuellist(positional);
    final duellist = busiest == null ? null : cardDisplayName(save, busiest.id);
    // The shipped pool for a shot charged down, wired here: the defence that
    // blocked the most gets the sentence, seeded on the fixture so it holds.
    final blocked = _blockedAgainst(positional);
    final blockedLine =
        blocked.ours >= blockedWorthALine && blocked.ours >= blocked.theirs
        ? tPoolStable('commentary.blocked', '${result['fixtureKey']}', {
            'who': ourName,
          })
        : blocked.theirs >= blockedWorthALine
        ? tPoolStable('commentary.blocked', '${result['fixtureKey']}', {
            'who': theirName,
          })
        : null;

    final muted = text.labelSmall?.copyWith(color: kit.textMuted);
    return GlassPanel(
      key: const ValueKey('summary-positional'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('match.analysis.title').toUpperCase(),
            style: text.labelMedium?.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 168,
                child: MatchHeatmap(positional: positional),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Legend(
                      ourName: ourName,
                      theirName: theirName,
                      ourInk: kit.accentBright,
                      theirInk: conceded,
                    ),
                    const SizedBox(height: 8),
                    Text(t('match.analysis.flanks'), style: muted),
                    const SizedBox(height: 4),
                    for (final flank in Flank.values)
                      _FlankRow(
                        label: t('match.analysis.${flank.name}'),
                        ours: ours[flank]!,
                        theirs: theirs[flank]!,
                        ourInk: kit.accentBright,
                        theirInk: conceded,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${t('match.analysis.shots', {'shots': shots['ours'] ?? 0, 'xg': _xg(xg['ours'])})} · ${t('match.analysis.shots', {'shots': shots['theirs'] ?? 0, 'xg': _xg(xg['theirs'])})}',
                      style: muted,
                      key: const ValueKey('summary-positional-shots'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (duellist != null && duellist.isNotEmpty && busiest != null) ...[
            const SizedBox(height: 8),
            Text(
              t('match.analysis.duel_record', {
                'name': duellist,
                'won': busiest.won,
                'total': busiest.won + busiest.lost,
              }),
              key: const ValueKey('summary-positional-duel'),
              style: text.bodySmall,
            ),
          ],
          if (blockedLine != null) ...[
            const SizedBox(height: 4),
            Text(
              blockedLine,
              key: const ValueKey('summary-positional-blocked'),
              style: text.bodySmall?.copyWith(color: kit.textMuted),
            ),
          ],
          const SizedBox(height: 6),
          Text(t('match.analysis.hint'), style: muted),
        ],
      ),
    );
  }
}

String _xg(Object? v) => v is num ? v.toStringAsFixed(1) : '0.0';

/// Shots blocked by each side's defence: a blocked shot of theirs is a block
/// of ours.
({int ours, int theirs}) _blockedAgainst(Map<String, dynamic> positional) {
  var ours = 0;
  var theirs = 0;
  for (final e in positional['ev'] as List) {
    if (e is! Map || e['t'] != 'shot' || e['o'] != 'blocked') continue;
    if (e['s'] == 'ours') {
      theirs++;
    } else {
      ours++;
    }
  }
  return (ours: ours, theirs: theirs);
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.ourName,
    required this.theirName,
    required this.ourInk,
    required this.theirInk,
  });

  final String ourName;
  final String theirName;
  final Color ourInk;
  final Color theirInk;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    Widget swatch(Color c, String name) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(name, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [swatch(ourInk, ourName), swatch(theirInk, theirName)],
    );
  }
}

/// One flank: our share against theirs, as two bars meeting in the middle.
class _FlankRow extends StatelessWidget {
  const _FlankRow({
    required this.label,
    required this.ours,
    required this.theirs,
    required this.ourInk,
    required this.theirInk,
  });

  final String label;
  final double ours;
  final double theirs;
  final Color ourInk;
  final Color theirInk;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kit = Theme.of(context).extension<KitTheme>()!;
    String pct(double v) => '${(v * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(pct(ours), style: text.labelSmall)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: ours.clamp(0.0, 1.0),
                      child: Container(height: 6, color: ourInk),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: text.labelSmall?.copyWith(color: kit.textMuted),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: theirs.clamp(0.0, 1.0),
                      child: Container(height: 6, color: theirInk),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              pct(theirs),
              style: text.labelSmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
