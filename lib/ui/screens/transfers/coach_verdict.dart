/// Colin's answer to an offer, before his reasons.
///
/// **A read that ends in "your call" every time is not a read.** The bid card
/// had thirteen lines of reasoning and the sponsor card had none, and neither
/// said the one thing a player asks a coach about an offer: would you take it?
/// Asked for from the couch — he should be telling us whether to go ahead. So
/// every branch of both reads now carries one of three answers, and the chip
/// wears it above the sentence that explains it.
///
/// Shared by the bid and the sponsor cards, which is the point of it being a
/// file: two chips that agreed about nothing is how the two coaches came about.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsGreenOn, vsRedOn;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// Where the club stands, once the table means anything.
///
/// **Null before three matches**, which is `leagueTableTip`'s own threshold and
/// for the same reason: a position read off one result is not one a coach
/// should be pricing a player against.
({int pos, int total})? clubStanding(Map<String, dynamic> state) {
  final prog = _map(state['progression']);
  if (_num(prog?['seasonAwardedPlayed']) < 3) return null;
  final rows = buildLeagueTable(state);
  final pos = rows.indexWhere((r) => r.isPlayer) + 1;
  if (pos <= 0) return null;
  return (pos: pos, total: rows.length);
}

/// Bottom two — what the club would be relegated from.
bool inDropZone(({int pos, int total})? standing) =>
    standing != null && standing.total >= 4 && standing.pos >= standing.total - 1;

/// Is this card in the eleven that takes the field?
bool inStartingEleven(Map<String, dynamic> state, String? instanceId) {
  if (instanceId == null) return false;
  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is! List) return false;
  return lineup.any((row) => _map(row)?['instanceId'] == instanceId);
}

/// Cards on the grid, which is the squad the eleven are picked from.
int squadSize(Map<String, dynamic> state) =>
    (_map(state['grid'])?['cells'] as List?)?.nonNulls.length ?? 0;

enum CoachVerdict { accept, decline, yourCall }

/// The chip's label, resolved.
String coachVerdictLabel(CoachVerdict v) => switch (v) {
  CoachVerdict.accept => t('coach.verdict.accept'),
  CoachVerdict.decline => t('coach.verdict.decline'),
  CoachVerdict.yourCall => t('coach.verdict.your_call'),
};

/// One read: what he thinks, and why.
typedef CoachRead = ({CoachVerdict verdict, String text});

/// The verdict as a pill, and the reason under it.
class CoachVerdictLine extends StatelessWidget {
  const CoachVerdictLine({
    required this.read,
    this.textKey,
    this.chipKey,
    super.key,
  });

  final CoachRead read;

  /// Names the reason, for a caller whose test asks for it.
  final Key? textKey;
  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    // The same green and red the bid's band wears, so "take it" and "great
    // deal" are one colour; amber for the shrug, as the fair band is.
    final colour = switch (read.verdict) {
      CoachVerdict.accept => vsGreenOn(context),
      CoachVerdict.decline => vsRedOn(context),
      CoachVerdict.yourCall => const Color(0xFFFBBF24),
    };
    final icon = switch (read.verdict) {
      CoachVerdict.accept => Icons.thumb_up_alt_rounded,
      CoachVerdict.decline => Icons.thumb_down_alt_rounded,
      CoachVerdict.yourCall => Icons.balance_rounded,
    };
    final muted = Theme.of(context).extension<KitTheme>()!.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: chipKey ?? ValueKey('coach-verdict-${read.verdict.name}'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colour.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colour),
              const SizedBox(width: 6),
              Text(
                coachVerdictLabel(read.verdict),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          read.text,
          key: textKey,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.5, color: muted),
        ),
      ],
    );
  }
}
