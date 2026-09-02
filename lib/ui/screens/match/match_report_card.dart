/// The full-time write-up, as the last word in the commentary.
///
/// **On the FEED, not on the summary.** It went on the report screen first and
/// was moved on sight: the commentary is where the match is told, minute by
/// minute, so the paragraph that tells the whole of it belongs at the head of
/// that list rather than in a panel on the page after it. Asked for from the
/// couch in exactly those terms.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/league_table.dart' show LeagueRow;
import 'package:merge_empire_fc/engine/match_report.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show leagueTableProvider;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart'
    show cardDisplayName;
import 'package:merge_empire_fc/ui/screens/match/match_summary.dart'
    show regulationScore;
import 'package:merge_empire_fc/ui/theme/glass.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// **THE FULL-TIME WRITE-UP.**
///
/// Asked for from the couch, at length: a paragraph at the end of a match that
/// tells the story of it rather than listing its numbers — the result, the shape
/// it took, who scored, what the referee did, where it leaves us and who is
/// next. "Obviously a lot of this will have to be contextually aware."
///
/// The sentence-picking lives in `engine/match_report.dart` and is tested as
/// arithmetic. This resolves the beats it hands back and lays them out as one
/// block of prose. **Seeded off the fixture** — every beat draws from a pool of
/// three, and a report that rewrote itself each time the screen rebuilt would
/// be a different match every rebuild.
///
/// **A summary, not a broadcast.** The beats are joined into a single paragraph
/// rather than a list of lines: six bullet points is a scorecard, and a
/// scorecard is what the panels above it already are.
class MatchReportCard extends ConsumerWidget {
  const MatchReportCard({required this.result, super.key});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(gameProvider).state;
    final facts = reportFactsFor(result, save, ref.watch(leagueTableProvider));
    if (facts == null) return const SizedBox.shrink();
    final beats = buildMatchReport(facts);
    if (beats.isEmpty) return const SizedBox.shrink();

    // One seed for the whole report, so the beats do not each pick
    // independently on every rebuild. The fixture key is the match's own name.
    final seed = '${result['fixtureKey'] ?? ''}'
        '-${facts.ours}-${facts.theirs}-${facts.opponentName}';
    final prose = [
      for (final beat in beats) tPoolStable(beat.key, seed, beat.params),
    ].join(' ');

    return GlassPanel(
      key: const ValueKey('summary-report'),
      density: GlassDensity.deep,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // `match.tab.commentary` is what the feed's own heading calls
            // this — the report IS the commentary, told once and in order —
            // and no new copy key can be invented for a heading when a
            // shipped one already names the thing.
            t('match.tab.commentary').toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: glassMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            prose,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: glassInk(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything the report reads, off the settled result and the table the round
/// left behind — or null when there is not enough of a match here to write up.
///
/// **On the screen rather than in the engine**, and for the reason the bookings
/// are: the cards and the scorer names are the port's own, the table is a
/// provider, and `match_orchestration_parity_test` compares what the engine
/// returns field for field. Nothing the harness reads is touched.
ReportFacts? reportFactsFor(
  Map<String, dynamic> result,
  Map<String, dynamic>? save,
  List<LeagueRow> table,
) {
  final events = result['events'];
  if (events is! List) return null;

  final goals = <Map<String, dynamic>>[];
  final scorers = <String>[];
  for (final entry in events) {
    final e = _map(entry);
    if (e == null || e['type'] != 'goal') continue;
    goals.add(e);
    if (e['team'] != 'home') continue;
    // By the card if he is still on the grid, else the name the result
    // recorded — a scorer who has since been sold still scored.
    final name =
        cardDisplayName(save, '${e['scorerInstanceId'] ?? ''}') ??
        '${e['scorer'] ?? ''}';
    if (name.isNotEmpty) scorers.add(name);
  }

  // The cards, counted from the rows the match screen wrote onto the result.
  var ourYellows = 0;
  var ourReds = 0;
  var theirYellows = 0;
  var theirReds = 0;
  final cards = result['bookings'];
  if (cards is List) {
    for (final entry in cards) {
      final b = _map(entry);
      if (b == null) continue;
      final card = '${b['card'] ?? cardYellow}';
      final ours = b['team'] != 'away';
      if (card == cardYellow || card == cardSecondYellow) {
        if (ours) {
          ourYellows++;
        } else {
          theirYellows++;
        }
      }
      if (cardSendsOff(card)) {
        if (ours) {
          ourReds++;
        } else {
          theirReds++;
        }
      }
    }
  }

  final (:wasBehind, :wasAhead) = leadSwings(goals);
  final (ours, theirs) = regulationScore(result);

  // Where the table leaves us. A cup tie has no table to move in, and a save
  // whose season has not begun has no row — both come through as nulls rather
  // than as zeroes, and the report simply leaves the sentence out.
  final at = table.indexWhere((LeagueRow r) => r.isPlayer);
  final row = at < 0 ? null : table[at];
  final was = row?.prevPos;

  final preview = save == null ? null : previewFixture(save);

  return (
    ours: ours,
    theirs: theirs,
    opponentName: '${result['opponentName'] ?? ''}',
    isHome: result['isHome'] == true,
    isCup: result['isCup'] == true,
    scorers: scorers,
    wasBehind: wasBehind,
    wasAhead: wasAhead,
    ourYellows: ourYellows,
    ourReds: ourReds,
    theirYellows: theirYellows,
    theirReds: theirReds,
    position: row == null ? null : at + 1,
    points: row?.pts,
    // Positive is a CLIMB, and a climb is a smaller position number.
    posDelta: was == null || row == null ? null : was - (at + 1),
    nextOpponent: preview?.opponentName,
    nextIsHome: preview?.isHome ?? true,
  );
}
