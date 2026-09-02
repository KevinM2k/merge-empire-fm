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
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart'
    show feedInset, feedPlateEdge, feedPlateFill;
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

    // **THE SAME CARD AS THE ROWS UNDER IT.** It arrived as a `GlassPanel` —
    // blurred, rimmed, a component borrowed from the report screen — sitting on
    // top of a list of feed plates. Reported from the couch twice: not the
    // glass, and then the same card the rest of the commentary sits in. So it
    // is literally that plate: `feedPlateFill` over `feedPlateEdge`, at the
    // feed's own inset.
    return Padding(
      key: const ValueKey('summary-report'),
      padding: const EdgeInsets.symmetric(horizontal: feedInset, vertical: 3),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
        decoration: BoxDecoration(
          color: glassInk(context).withValues(alpha: feedPlateFill),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: glassInk(context).withValues(alpha: feedPlateEdge),
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **A CLOCK BESIDE THE HEAD, because every other row has a minute
          // there.** The feed is a column of times down its left edge and this
          // row has none — it is about the whole ninety — so a full-time clock
          // stands where the minute would be and keeps the column reading as a
          // column. Asked for from the couch.
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 13,
                color: glassMuted(context),
              ),
              const SizedBox(width: 5),
              Text(
                t('match.report_head').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: glassMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            prose,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: glassInk(context),
            ),
          ),
        ],
        ),
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
    clubName: '${result['clubName'] ?? ''}',
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
    lateSwitch: _lateSwitchIn(result),
    nextOpponent: preview?.opponentName,
    nextIsHome: preview?.isHome ?? true,
    oppNextOpponent: _nextFor(save, '${result['opponentName'] ?? ''}'),
  );
}

/// Who [club] plays in the next round, out of the season's own schedule.
///
/// **The AI's fixtures are in there too.** `generateSeasonFixtures` writes
/// every pairing in the division, not only ours — the player's own rows are the
/// ones with a null team — so the opponent's next opponent is a lookup rather
/// than a guess. Null when the schedule has run out, which is the last round of
/// a season, and null for a cup tie, which has no league schedule at all.
String? _nextFor(Map<String, dynamic>? save, String club) {
  if (club.isEmpty) return null;
  final prog = save?['progression'];
  if (prog is! Map<String, dynamic>) return null;
  final fixtures = prog['seasonFixtures'];
  if (fixtures is! List) return null;
  final played = (prog['seasonMatchesPlayed'] as num?)?.toInt() ?? 0;
  final ours = save?['clubName'];

  ({int round, String opponent})? best;
  for (final raw in fixtures) {
    final f = _map(raw);
    if (f == null) continue;
    final round = (f['round'] as num?)?.toInt() ?? 0;
    // Rounds are one-based and `seasonMatchesPlayed` counts finished ones, so
    // the next round is the one after the count.
    if (round <= played) continue;
    // A null team is the player's club — that is how the schedule marks it.
    final home = '${f['homeTeam'] ?? ours ?? ''}';
    final away = '${f['awayTeam'] ?? ours ?? ''}';
    final other = home == club ? away : (away == club ? home : null);
    if (other == null || other.isEmpty) continue;
    if (best == null || round < best.round) {
      best = (round: round, opponent: other);
    }
  }
  return best?.opponent;
}

/// The last tactical change, when it came late enough to be about seeing the
/// match out rather than about how to start it.
///
/// **Sixty minutes is the line**, and it is a judgement rather than a
/// measurement: a switch on the hour is a manager reacting to what is in front
/// of him, and one in the twentieth is still the plan. The log is written by
/// the match screen — see `applyStrategy` — because the engine's own result
/// records WHAT was played and never WHEN it changed.
({int minute, String tactic})? _lateSwitchIn(Map<String, dynamic> result) {
  final log = result['strategyLog'];
  if (log is! List) return null;
  ({int minute, String tactic})? best;
  for (final raw in log) {
    final row = _map(raw);
    if (row == null) continue;
    final minute = (row['minute'] as num?)?.toInt() ?? 0;
    final id = '${row['id'] ?? ''}';
    if (minute < lateSwitchFrom || id.isEmpty) continue;
    if (best == null || minute > best.minute) {
      best = (minute: minute, tactic: id);
    }
  }
  return best;
}

/// When a tactical change stops being the plan and starts being a response.
const int lateSwitchFrom = 60;
