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
import 'package:merge_empire_fc/engine/match_tactics.dart' show defaultStrategy;
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/league_table.dart' show LeagueRow;
import 'package:merge_empire_fc/engine/match_report.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show leagueTableProvider;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart'
    show cardDisplayName;
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart'
    show MatchFrame, frameAt, fullTime;
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart'
    show liveStatsFor;
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
/// **A summary, not a broadcast.** The beats are joined into sentence runs
/// rather than a list of lines: six bullet points is a scorecard, and a
/// scorecard is what the panels above it already are. They do break into
/// PARAGRAPHS, though — see `ReportBeat.para`, which groups them the way a
/// person writing this up would.
class MatchReportCard extends ConsumerWidget {
  const MatchReportCard({required this.result, this.frame, super.key});

  final Map<String, dynamic> result;

  /// **THE MATCH AS THE SCREEN TOLD IT.** The board, the feed and the
  /// statistics all read the match screen's frame; the write-up read
  /// `result['events']`, and twice in one sitting the two disagreed — a 0-6
  /// written up as a draw, then a 0-1 written up as a three-goal win with
  /// scorers and minutes the player never saw. When the screen hands its frame
  /// over, the write-up reads that and nothing else, so it cannot say a
  /// different match from the one above it. Null reads the result, for a
  /// caller with no screen behind it.
  final MatchFrame? frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(gameProvider).state;
    final facts = reportFactsFor(
      result,
      save,
      ref.watch(leagueTableProvider),
      frame: frame,
    );
    if (facts == null) return const SizedBox.shrink();
    final beats = buildMatchReport(facts);
    if (beats.isEmpty) return const SizedBox.shrink();

    // One seed for the whole report, so the beats do not each pick
    // independently on every rebuild. The fixture key is the match's own name.
    final seed = '${result['fixtureKey'] ?? ''}'
        '-${facts.ours}-${facts.theirs}-${facts.opponentName}';
    // **AND THE BEAT'S OWN KEY IN IT, or every sentence is the same variant.**
    // [stableIndex] hashes the seed and takes it modulo the pool's length, so
    // one seed across pools that are all the same length picks the SAME index
    // in each — the whole write-up was variant 0, or variant 1, all the way
    // down. Six sentences drawn from six pools of five have 15,625 shapes; the
    // shared seed was giving five. Folding the key in keeps the report stable
    // per fixture, which is the point of seeding it at all, and lets the beats
    // differ from each other.
    //
    // **PARAGRAPHS, and they come from the engine rather than from here.** This
    // was one block on the reasoning that six bullet points is a scorecard —
    // still true of bullets, and never true of paragraphs. A person writing
    // this up breaks after the result, again after the performances, and again
    // before what it means for the table, and asked for from the couch in
    // those terms. `ReportBeat.para` says which is which; consecutive beats
    // sharing one are joined into a sentence run.
    final paragraphs = <String>[];
    var current = <String>[];
    int? para;
    for (final beat in beats) {
      if (para != null && beat.para != para) {
        paragraphs.add(current.join(' '));
        current = [];
      }
      para = beat.para;
      current.add(tPoolStable(beat.key, '$seed-${beat.key}', beat.params));
    }
    if (current.isNotEmpty) paragraphs.add(current.join(' '));

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
          for (var i = 0; i < paragraphs.length; i++) ...[
            // A visible blank line, not a nudge — asked for from the couch.
            // The type runs at 12.5/1.45, so a line box is a shade over 18 and
            // this is most of one: the break reads as a paragraph rather than
            // as loose leading.
            if (i > 0) const SizedBox(height: 13),
            Text(
              paragraphs[i],
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: glassInk(context),
              ),
            ),
          ],
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
  List<LeagueRow> table, {
  MatchFrame? frame,
}) {
  // The screen's frame when there is one — see [MatchReportCard.frame] — else
  // the result's own events.
  final events = frame != null
      ? [
          for (final e in frame.shown)
            <String, dynamic>{
              'minute': e.minute,
              'type': e.type,
              'team': e.team,
              'scorer': e.scorer,
              'scorerInstanceId': e.scorerId,
            },
        ]
      : result['events'];
  if (events is! List) return null;

  final goals = <Map<String, dynamic>>[];
  final scorers = <String>[];
  final timeline = <ReportGoal>[];
  var theirSubs = 0;
  for (final entry in events) {
    final e = _map(entry);
    if (e == null) continue;
    // The AI's rotation, one event per change — see `match_clock.dart`.
    if (e['type'] == 'opp_sub') theirSubs++;
    if (e['type'] != 'goal') continue;
    goals.add(e);
    final minute = (e['minute'] as num?)?.toInt() ?? 0;
    if (e['team'] != 'home') {
      // The sim does not name their scorers; a name, if one ever arrives,
      // is used.
      final theirs = '${e['scorer'] ?? ''}';
      timeline.add((
        minute: minute,
        ours: false,
        scorer: theirs.isEmpty ? null : theirs,
      ));
      continue;
    }
    // By the card if he is still on the grid, else the name the result
    // recorded — a scorer who has since been sold still scored.
    final name =
        cardDisplayName(save, '${e['scorerInstanceId'] ?? ''}') ??
        '${e['scorer'] ?? ''}';
    if (name.isNotEmpty) scorers.add(name);
    timeline.add((
      minute: minute,
      ours: true,
      scorer: name.isEmpty ? null : name,
    ));
  }

  final isHome = result['isHome'] == true;

  // The cards, from the rows the match screen wrote onto the result. A
  // second yellow is one row and it sends off; the first yellow is its own.
  final cards = <ReportCard>[];
  final bookings = result['bookings'];
  if (bookings is List) {
    for (final entry in bookings) {
      final b = _map(entry);
      if (b == null) continue;
      final card = '${b['card'] ?? cardYellow}';
      final player = '${b['player'] ?? ''}';
      cards.add((
        minute: (b['minute'] as num?)?.toInt() ?? 0,
        ours: b['team'] != 'away',
        player: player.isEmpty ? null : player,
        red: cardSendsOff(card),
      ));
    }
  }

  // Our substitutions, as `_onSub` records them.
  final subs = <ReportSub>[];
  final subRows = result['subs'];
  if (subRows is List) {
    for (final entry in subRows) {
      final row = _map(entry);
      if (row == null) continue;
      final off = '${row['off'] ?? ''}';
      subs.add((
        minute: (row['minute'] as num?)?.toInt() ?? 0,
        on: '${row['on'] ?? ''}',
        off: off.isEmpty ? null : off,
      ));
    }
  }

  // Every change of tactic, in the order they were made — see `applyStrategy`.
  final switches = <ReportSwitch>[];
  final log = result['strategyLog'];
  if (log is List) {
    for (final raw in log) {
      final row = _map(raw);
      if (row == null) continue;
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      switches.add((minute: (row['minute'] as num?)?.toInt() ?? 0, tactic: id));
    }
  }
  final kickoff = result['kickoffStrategy'];
  final startTactic = kickoff is String && kickoff.isNotEmpty ? kickoff : null;

  // The board at the whistle, counted the way the statistics tab counts it —
  // same function, so the two cannot disagree. The possession figure leans on
  // the tactic the side FINISHED with, which is what the tab showed last.
  final finished = result['finalStrategy'];
  final live = liveStatsFor(
    frame:
        frame ??
        frameAt(result, fullTime((result['addedTime'] as num?)?.toInt() ?? 0)),
    result: result,
    isHome: isHome,
    strategyId: finished is String && finished.isNotEmpty
        ? finished
        : startTactic ?? defaultStrategy,
  );
  int ourRow(String key) {
    final row = live.rows.firstWhere((r) => r.key == key);
    return isHome ? row.home : row.away;
  }
  int theirRow(String key) {
    final row = live.rows.firstWhere((r) => r.key == key);
    return isHome ? row.away : row.home;
  }
  final ReportStats stats = (
    possession: isHome ? live.possHome : live.possAway,
    shots: ourRow('shots'),
    theirShots: theirRow('shots'),
    onTarget: ourRow('sot'),
    theirOnTarget: theirRow('sot'),
    corners: ourRow('corners'),
    theirCorners: theirRow('corners'),
  );

  final (:wasBehind, :wasAhead) = leadSwings(goals);
  // **THE SCORE IS COUNTED OFF THE EVENTS, like the scoreboard's.** It read the
  // engine's `homeGoals`/`awayGoals`, and a 0-6 away win was written up as "a
  // draw, 1 apiece" while the board above it said 0-6 and the feed had all six
  // goals — the fields and the events can part company on this screen, and the
  // feed and the board only ever read the events. So does this now; the fields
  // are the fallback for a result with no events on it (a shootout's goals are
  // in neither, so the two agree on a cup tie too).
  final (ours, theirs) = timeline.isEmpty
      ? regulationScore(result)
      : (
          timeline.where((g) => g.ours).length,
          timeline.where((g) => !g.ours).length,
        );

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
    isHome: isHome,
    isCup: result['isCup'] == true,
    scorers: scorers,
    wasBehind: wasBehind,
    wasAhead: wasAhead,
    goals: timeline,
    cards: cards,
    subs: subs,
    theirSubs: theirSubs,
    startTactic: startTactic,
    switches: switches,
    stats: stats,
    position: row == null ? null : at + 1,
    points: row?.pts,
    // Positive is a CLIMB, and a climb is a smaller position number.
    posDelta: was == null || row == null ? null : was - (at + 1),
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
