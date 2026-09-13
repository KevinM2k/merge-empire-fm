/// The match inspector: the positional record, openable and pokeable.
///
/// **This is a debugging and reading surface, not a new mechanic.** The sim
/// already records every duel and shot with the zone it happened in while it
/// settles the score (`attack_sequence.dart`) and `match_analysis.dart` adds
/// that stream up; the summary card shows the headline. This sheet is the rest
/// of it, so that the question "does this behave like football?" can be answered
/// by looking at a match rather than by reading a test.
///
/// What it answers, in the order the sheet lays it out: where the attacks
/// happened, how many and how good they were (the three [ZoneMetric] views),
/// how they split left / centre / right, who was involved and how their duels
/// went, and which attacker met which defender. Tapping a player narrows every
/// one of those to HIM — his own heatmap, his own flanks, his own pairings.
///
/// Frame: our goal at the BOTTOM, attacking UP, low x on screen-LEFT — the
/// squad tab's frame, and `pitch_space.dart`'s. Ours is the kit accent, theirs
/// is [conceded].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/match_analysis.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart'
    show cardDisplayName;
import 'package:merge_empire_fc/ui/screens/match/goal_replay.dart'
    show conceded;
import 'package:merge_empire_fc/ui/screens/match/match_heatmap.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Pairings listed before the list is cut off. Eleven against eleven is up to
/// 121 and the tail is all single meetings; the top of the list is the story.
const int matchupsShown = 8;

/// Opens the inspector over [result], or does nothing for a match that recorded
/// no positional stream — an old save's last match, or a fixed-rating tie.
Future<void> showMatchInspector(
  BuildContext context,
  Map<String, dynamic> result,
) {
  final positional = positionalOf(result);
  if (positional == null) return Future.value();
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.9,
    child: MatchInspector(result: result, positional: positional),
  );
}

/// A player as the inspector lists him: who he is, how his duels went, and
/// what he had at goal.
typedef InspectedPlayer = ({
  String id,
  String name,
  bool ours,
  int won,
  int lost,
  int shots,
  double xg,
});

/// Everyone in the record, our side first, each side most-involved first.
///
/// Names come off the save for our cards; an AI pseudo-player has no card, so
/// he is his SLOT — `ai:lb` reads `LB`, which is what the token would say and
/// what the flank copy means by a left-back.
List<InspectedPlayer> inspectedPlayers(
  Map<String, dynamic>? positional,
  Map<String, dynamic>? save,
) {
  final shooters = positional?['shooters'];
  ({int shots, double xg}) atGoal(String id) {
    final line = shooters is Map ? shooters[id] : null;
    if (line is! Map) return (shots: 0, xg: 0);
    return (
      shots: (line['shots'] as num?)?.toInt() ?? 0,
      xg: (line['xg'] as num?)?.toDouble() ?? 0,
    );
  }

  InspectedPlayer row(DuelRecord d) {
    final ours = !MatchHeatmap.isTheirs(d.id);
    final goal = atGoal(d.id);
    return (
      id: d.id,
      name: ours
          ? (cardDisplayName(save, d.id) ?? d.id)
          : d.id.substring(3).toUpperCase(),
      ours: ours,
      won: d.won,
      lost: d.lost,
      shots: goal.shots,
      xg: goal.xg,
    );
  }

  return [
    for (final d in duelRecords(positional, ours: true)) row(d),
    for (final d in duelRecords(positional, ours: false)) row(d),
  ];
}

class MatchInspector extends ConsumerStatefulWidget {
  const MatchInspector({
    required this.result,
    required this.positional,
    super.key,
  });

  final Map<String, dynamic> result;
  final Map<String, dynamic> positional;

  @override
  ConsumerState<MatchInspector> createState() => _MatchInspectorState();
}

class _MatchInspectorState extends ConsumerState<MatchInspector> {
  ZoneMetric _metric = ZoneMetric.touches;

  /// The one man every view is narrowed to, or null for both whole sides.
  String? _player;

  String _label(ZoneMetric m) => switch (m) {
    ZoneMetric.touches => t('match.inspect.touches'),
    ZoneMetric.shots => t('match.inspect.shots'),
    ZoneMetric.xg => t('match.inspect.xg'),
  };

  /// A grid's total as the view wants it read: a count, or expected goals to
  /// one place.
  String _total(List<double> grid) {
    final sum = grid.fold<double>(0, (a, b) => a + b);
    return _metric == ZoneMetric.xg
        ? sum.toStringAsFixed(1)
        : '${sum.round()}';
  }

  List<double> _grid(String side) {
    final held = _player;
    if (held == null) return zoneGrid(widget.positional, side, _metric);
    final mine = MatchHeatmap.isTheirs(held) ? 'theirs' : 'ours';
    return side == mine
        ? playerZoneGrid(widget.positional, held, _metric)
        : List<double>.filled(pitchZones, 0);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final text = Theme.of(context).textTheme;
    final muted = text.labelSmall?.copyWith(color: kit.textMuted);
    final save = ref.watch(gameProvider).state;
    final players = inspectedPlayers(widget.positional, save);
    final held = _player;
    final ourGrid = _grid('ours');
    final theirGrid = _grid('theirs');
    final ourFlanks = gridFlankShares(ourGrid, theirs: false);
    final theirFlanks = gridFlankShares(theirGrid, theirs: true);
    final pairs = matchups(
      widget.positional,
      side: held == null
          ? null
          : MatchHeatmap.isTheirs(held)
          ? 'theirs'
          : 'ours',
    ).where((m) => held == null || m.attacker == held || m.defender == held);
    final selected = players.where((p) => p.id == held).firstOrNull;

    return Column(
      key: const ValueKey('match-inspector'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Text(
            t('match.inspect.title').toUpperCase(),
            style: text.labelMedium?.copyWith(letterSpacing: 1.2),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in ZoneMetric.values)
                    _Chip(
                      cardKey: 'inspect-metric-${m.name}',
                      label: _label(m),
                      active: m == _metric,
                      accent: kit.accent,
                      ink: kit.accentBright,
                      border: kit.border,
                      onTap: m == _metric
                          ? null
                          : () => setState(() => _metric = m),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 210,
                    child: MatchHeatmap(
                      positional: widget.positional,
                      metric: _metric,
                      playerId: held,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HeatmapLegend(
                          ourName: '${widget.result['clubName'] ?? ''}',
                          theirName: '${widget.result['opponentName'] ?? ''}',
                          ourInk: kit.accentBright,
                          theirInk: conceded,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t('match.inspect.total', {
                            'metric': _label(_metric),
                            'ours': _total(ourGrid),
                            'theirs': _total(theirGrid),
                          }),
                          key: const ValueKey('inspect-total'),
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(t('match.analysis.flanks'), style: muted),
                        const SizedBox(height: 4),
                        for (final flank in Flank.values)
                          FlankRow(
                            label: t('match.analysis.${flank.name}'),
                            ours: ourFlanks[flank]!,
                            theirs: theirFlanks[flank]!,
                            ourInk: kit.accentBright,
                            theirInk: conceded,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (selected != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('match.inspect.showing', {'name': selected.name}),
                        key: const ValueKey('inspect-showing'),
                        style: text.bodySmall,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('inspect-clear'),
                      onPressed: () => setState(() => _player = null),
                      child: Text(t('match.inspect.whole_team')),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(t('match.inspect.players'), style: muted),
              const SizedBox(height: 4),
              for (final p in players)
                _PlayerRow(
                  player: p,
                  selected: p.id == held,
                  accent: kit.accent,
                  ink: p.ours ? kit.accentBright : conceded,
                  muted: kit.textMuted,
                  onTap: () =>
                      setState(() => _player = p.id == held ? null : p.id),
                ),
              const SizedBox(height: 12),
              Text(t('match.inspect.matchups'), style: muted),
              const SizedBox(height: 4),
              for (final m in pairs.take(matchupsShown))
                _MatchupRow(
                  attacker: _nameOf(players, m.attacker),
                  defender: _nameOf(players, m.defender),
                  won: m.won,
                  lost: m.lost,
                  muted: kit.textMuted,
                ),
              const SizedBox(height: 12),
              Text(t('match.inspect.hint'), style: muted),
            ],
          ),
        ),
      ],
    );
  }
}

/// A player's name from the list, falling back to his id — an id only shows up
/// for a card the save has since let go, which is better than a blank row.
String _nameOf(List<InspectedPlayer> players, String id) =>
    players.where((p) => p.id == id).firstOrNull?.name ?? id;

/// One view's chip. Not a Material button on purpose: a moulded button's face
/// is painted in a `backgroundBuilder`, so an active-state fill has to come
/// from `mouldedButtonStyle(face:)` or not at all — see CLAUDE.md. This wants a
/// tinted surface, which is a `Material`'s job.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.cardKey,
    required this.label,
    required this.active,
    required this.accent,
    required this.ink,
    required this.border,
    this.onTap,
  });

  final String cardKey;
  final String label;
  final bool active;
  final Color accent;
  final Color ink;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      key: ValueKey(cardKey),
      color: active ? accent.withValues(alpha: 0.16) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: active ? accent : border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: text.labelMedium?.copyWith(
              color: active ? ink : null,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One player: his name, his duel record and what he had at goal.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.selected,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.onTap,
  });

  final InspectedPlayer player;
  final bool selected;
  final Color accent;
  final Color ink;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rate = duelWinRate((
      id: player.id,
      won: player.won,
      lost: player.lost,
    ));
    return Material(
      key: ValueKey('inspect-player-${player.id}'),
      color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  player.name,
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                t('match.inspect.duel_line', {
                  'won': player.won,
                  'lost': player.lost,
                  'pct': rate == null ? 0 : (rate * 100).round(),
                }),
                style: text.labelSmall,
              ),
              if (player.shots > 0) ...[
                const SizedBox(width: 8),
                Text(
                  t('match.inspect.shot_line', {
                    'shots': player.shots,
                    'xg': player.xg.toStringAsFixed(1),
                  }),
                  style: text.labelSmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One pairing: who met whom and how it went, the attacker's way round.
class _MatchupRow extends StatelessWidget {
  const _MatchupRow({
    required this.attacker,
    required this.defender,
    required this.won,
    required this.lost,
    required this.muted,
  });

  final String attacker;
  final String defender;
  final int won;
  final int lost;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t('match.inspect.versus', {
                'attacker': attacker,
                'defender': defender,
              }),
              style: text.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            t('match.inspect.duel_line', {
              'won': won,
              'lost': lost,
              'pct': won + lost == 0 ? 0 : (100 * won / (won + lost)).round(),
            }),
            style: text.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
