/// The league, derived from the save.
///
/// The table and the schedule are both the engines' own — `buildLeagueTable`
/// and the stored `seasonFixtures` — so nothing here computes a standing or a
/// result.
library;

import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart';
import 'dart:math' as math;

import 'package:merge_empire_fc/engine/match_tactics.dart';

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart' show getSeasonOpponents;
import 'package:merge_empire_fc/engine/weather_engine.dart';
import 'package:merge_empire_fc/providers/weather_providers.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/util/time.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

/// One of OUR fixtures — the season as the manager plays it.
///
/// **The panel was showing the wrong list.** It rendered `seasonFixtures`, the
/// whole division's grid, as neutral "home v away" rows with a round number.
/// That table exists to feed the standings' form dots and nothing else; the
/// source's Fixtures panel is the manager's own fourteen, and every one of them
/// involves us — which is why a row names only the OPPONENT and leads with a
/// venue chip that says whether WE are at home.
typedef OurFixture = ({
  int matchNum,
  String opponent,
  bool isHome,
  bool played,

  /// The one being played next. Exactly one row has it, and only while the
  /// season is still running.
  bool isNext,

  /// Ours and theirs, however the match was played. The row orients them to
  /// physical home and away itself.
  int? ourGoals,
  int? theirGoals,
  bool won,
  bool drawn,

  /// Their squad rating — the division's midpoint until we have actually
  /// played them, which is when it is materialised.
  int rating,
  bool ratingEstimated,
});

/// A cup tie, where it sits in the season.
///
/// **A tie does NOT take a fixture slot.** Cups run BETWEEN league games — the
/// league index does not move for one, which is why a cup season is not a
/// league season one match shorter. So a tie is placed AFTER a league match
/// rather than instead of it, and `afterMatch` is that match's index.
typedef CupTie = ({
  /// The league match this tie follows. The JS's `cupInsertAt` keys: 3, 8, 12.
  int afterMatch,

  String competition,
  String roundName,
  bool played,

  /// The one due next, and only while it actually is.
  bool isNext,

  /// **Who, from the moment the bracket is drawn.** This was null until the
  /// tie had been PLAYED, so the one row on the fixture list a player most
  /// wanted to read — the cup tie that is next — named the competition and the
  /// round and no club at all. Reported from the couch with a screenshot: "my
  /// next match is a cup game vs Everton but if you look at fixtures, you can
  /// see Everton nowhere."
  ///
  /// A played tie still prefers the name in its RESULT: that is who was
  /// actually beaten, and the bracket ahead of it can be re-drawn.
  String? opponent,
  int? ourGoals,
  int? theirGoals,
  bool won,
});

/// The ties in this season's run, in order.
///
/// **Empty when there is no cup for this division**, which is most of the
/// pyramid: a fixture list with a phantom tie in it would be worse than one
/// with none.
final ourCupTiesProvider = savePick<List<CupTie>>((s) {
  final run = activeCup(s);
  final cup = cupForDivision(s);
  if (run == null || cup == null) return const [];
  final at = _int(run['round']);
  final played = _int(_map(s['progression'])?['seasonMatchesPlayed']);
  final results = run['results'];

  return [
    for (var round = 0; round < cup.rounds.length; round++)
      () {
        final result = results is List && round < results.length
            ? _map(results[round])
            : null;
        final names = run['opponents'];
        final drawn = names is List && round < names.length
            ? '${names[round]}'
            : null;
        // `cupDueAfterMatches` is the count of league matches that must be
        // behind you; the tie itself sits after the LAST of them.
        final after = round < cupDueAfterMatches.length
            ? cupDueAfterMatches[round] - 1
            : matchesPerSeason - 1;
        return (
          afterMatch: after,
          competition: t('cup.${cup.id}') == 'cup.${cup.id}'
              ? cup.name
              : t('cup.${cup.id}'),
          roundName: cup.rounds[round],
          played: result != null,
          // Due, and nothing before it still to play.
          isNext: result == null && round == at && played >= after + 1,
          opponent: (result?['opponentName'] as String?) ?? drawn,
          ourGoals: result == null ? null : _int(result['homeGoals']),
          theirGoals: result == null ? null : _int(result['awayGoals']),
          won: result?['won'] == true,
        );
      }(),
  ];
});

/// The manager's own season, all fourteen, in order.
final ourFixturesProvider = savePick<List<OurFixture>>((s) {
  final prog = _map(s['progression']);
  if (prog == null) return const [];
  final season = _int(prog['seasonCount'], 1);
  final played = _int(prog['seasonMatchesPlayed']);
  final opponents = prog['seasonOpponents'];
  // A season that has not been drawn yet has no fixtures to show. Fourteen rows
  // against "Opponent" is not a schedule, it is a placeholder pretending to be
  // one — the panel says it is still loading instead.
  if (opponents is! List || opponents.isEmpty) return const [];
  final results = _map(prog['fixtureResults']) ?? const {};
  final ratings = _map(prog['seasonOpponentRatings']) ?? const {};
  final div = getDivision('${prog['currentDivision']}');
  final midpoint =
      ((div.opponentRatingRange.$1 + div.opponentRatingRange.$2) / 2).round();

  return [
    for (var m = 0; m < matchesPerSeason; m++)
      () {
        final oppIdx = m % opponentsPerSeason;
        final result = _map(results['s${season}_m$m']);
        final stored = ratings['s${season}_o$oppIdx'];
        return (
          matchNum: m,
          opponent: oppIdx < opponents.length
              ? '${opponents[oppIdx]}'
              : t('common.opponent'),
          isHome: fixtureIsHome(season, oppIdx, m),
          played: m < played,
          isNext: m == played && played < matchesPerSeason,
          // `homeGoals` in a stored result is OURS whatever the venue was.
          ourGoals: m < played ? _int(result?['homeGoals']) : null,
          theirGoals: m < played ? _int(result?['awayGoals']) : null,
          won: result?['won'] == true,
          drawn: result?['drawn'] == true,
          rating: stored is num ? stored.round() : midpoint,
          ratingEstimated: stored is! num,
        );
      }(),
  ];
});

/// One line of the schedule.
typedef FixtureRow = ({
  int round,
  String homeTeam,
  String awayTeam,
  int? homeGoals,
  int? awayGoals,
  bool involvesPlayer,
  bool played,
});

final leagueTableProvider = savePick<List<LeagueRow>>((s) {
  // buildLeagueTable writes back into the save (it tracks movement between
  // renders), so it is given the live map exactly as the JS gives it.
  return buildLeagueTable(s);
});

/// What each club DID last season, by division and then by club name.
///
/// **`season_end` has written `lastSeasonStatus` every rollover since M1 and
/// nothing has ever read it.** `seasonStatusFor` is the engine's own accessor
/// and had no caller either, while seven `table.*` strings sat translated in
/// ten languages with nothing able to print one — the marker's three labels,
/// its three long forms and the legend's heading.
///
/// **Keyed by division because the table browses all seven.** The record stamps
/// each club with the league its move landed IN, so a promotion badge lights up
/// where the club arrived and never where it left; indexing by division is that
/// rule made structural, and it also means one pass over the record serves
/// every page of the pager.
///
/// Only the moves themselves are here — a club that stayed put has no entry
/// rather than a null one, so `isNotEmpty` is the question the legend asks.
final lastSeasonStatusProvider = savePick<Map<String, Map<String, String>>>((
  s,
) {
  final rec = _map(_map(s['progression'])?['lastSeasonStatus']);
  if (rec == null) return const {};

  final byDivision = <String, Map<String, String>>{};
  void note(String? divId, String? name, String? status) {
    if (divId == null || name == null || status == null) return;
    (byDivision[divId] ??= <String, String>{})[name] = status;
  }

  final teams = _map(rec['teams']);
  if (teams != null) {
    for (final entry in teams.entries) {
      final e = _map(entry.value);
      note(e?['division'] as String?, entry.key, e?['status'] as String?);
    }
  }
  // The player's own move is recorded apart from the AI clubs, under the
  // division they landed in and the club name they were carrying at the time.
  note(
    rec['playerDivision'] as String?,
    _map(s['club'])?['name'] as String? ?? 'Your Club',
    rec['player'] as String?,
  );
  return byDivision;
});

/// **Through the catalogue, not off the record.**
///
/// `Division.name` is the English literal on the data object, and all seven
/// division names have shipped translated in ten catalogues the whole time —
/// German reads Sonntagsliga, Regionalliga, Champions-Liga. `tName` exists for
/// exactly this and its own doc names divisions first; the trophy room and the
/// pyramid editor already went through it, and everything else — this header,
/// the season-end card, the match clock — printed English at every player in
/// the world.
final divisionNameProvider = savePick<String>((s) {
  final id = _map(s['progression'])?['currentDivision'] as String?;
  final div = getDivision(id ?? divisions.first.id);
  return tName('division', {'id': div.id, 'name': div.name});
});

final seasonNumberProvider = savePick<int>(
  (s) => _int(_map(s['progression'])?['seasonCount'], 1),
);

final fixturesProvider = savePick<List<FixtureRow>>((s) {
  final prog = _map(s['progression']);
  final raw = prog?['seasonFixtures'];
  final clubName = s['clubName'] is String ? s['clubName'] as String : '';
  if (raw is! List) return const [];

  return [
    for (final row in raw)
      if (row is Map<String, dynamic>)
        () {
          final home = row['homeTeam'] as String? ?? '';
          final away = row['awayTeam'] as String? ?? '';
          final hg = row['homeGoals'];
          final ag = row['awayGoals'];
          return (
            round: _int(row['round']),
            homeTeam: home,
            awayTeam: away,
            homeGoals: hg is num ? hg.toInt() : null,
            awayGoals: ag is num ? ag.toInt() : null,
            involvesPlayer: home == clubName || away == clubName,
            played: hg is num && ag is num,
          );
        }(),
  ]..sort((a, b) => a.round.compareTo(b.round));
});

/// Which match of the season is next, clamped to the last one.
///
/// The home screen reads "Sunday League · Match 7". The clamp matters at the
/// season boundary: every match is played, `matchesPlayed` reaches the total,
/// and without it the header advertises a fifteenth match in a fourteen-match
/// season.
final nextMatchNumberProvider = savePick<int>((s) {
  final prog = s['progression'];
  final played = prog is Map<String, dynamic> && prog['matchesPlayed'] is num
      ? (prog['matchesPlayed'] as num).toInt()
      : 0;
  return math.min(played + 1, matchesPerSeason);
});

/// The manager's stored look, or the default until boot has written one.
final managerLookProvider = savePick<ManagerLook?>((s) {
  final club = s['club'];
  final look = club is Map ? club['managerAvatar'] : null;
  // A COPY, because the save's own map is one mutable instance — a look edited
  // in place would never look changed. `savePick` compares the copy by VALUE
  // and hands back the previous one when it matches, so the copy is free: this
  // used to report a change every tick and rebuild the whole diorama with it.
  return look is Map<String, dynamic> ? <String, dynamic>{...look} : null;
});

/// How the season is going, which is what the walker's mouth says.
///
/// `manager_mood.dart` derives it from the last result, the table and the season,
/// and had no caller at all: the gaffer's mood was a value nobody could see.
final managerMoodProvider = savePick<Mood>((s) => deriveMood(s, now()).mood);

/// How the manager is coping with the weather in what the player put him in:
/// `cold` when he is underdressed in the cold, `hot` when he is wrapped up in
/// the heat, `ok` the rest of the time.
///
/// **The last link in a chain that was built, tested and unreachable.** The
/// service fetches a reading, the engine turns it into a temperature and
/// `comfortFor` compares that against [garmentWarmth] — and nothing read the
/// answer, so the manager stood in a February sleet shower in shorts looking
/// perfectly content.
///
/// **Both inputs move independently**, which is why this is derived rather than
/// stored: the weather changes on its own, and the player can change his clothes
/// at any moment through the customiser. The sky is the reason it recomputes on a
/// clock at all — the temperature is read at the moment the condition changes,
/// which in seasonal mode is every thirty to ninety seconds.
final managerComfortProvider = Provider<String>((ref) {
  ref.watch(saveRevisionProvider);
  final save = ref.watch(gameProvider).state;
  final condition = ref.watch(weatherProvider).condition;
  return comfortFor(
    estimatedTempC(save, now(), condition),
    garmentWarmth(normalizeAvatar(_map(save?['club'])?['managerAvatar'])),
  );
});

/// Last-five league form per club, oldest to newest.
///
/// Walks the pre-simulated fixtures so the AI clubs and the player share ONE
/// source of truth — a form line derived separately for each would disagree with
/// the table it sits in. Cup rounds are excluded: the dots track LEAGUE form, and
/// the standings they annotate are league standings.
///
/// Empty for a save that predates the schedule; callers just draw no dots.
final leagueFormProvider = savePick<Map<String, List<String>>>((s) {
  final prog = _map(s['progression']);
  final fixtures = prog?['seasonFixtures'];
  if (fixtures is! List || fixtures.isEmpty) return const {};

  final season = _int(prog?['seasonCount'], 1);
  final currentRound = _int(prog?['seasonAwardedPlayed']);
  final results = _map(prog?['fixtureResults']) ?? const {};
  final playerName =
      s['clubName'] is String && (s['clubName'] as String).isNotEmpty
      ? s['clubName'] as String
      : t('common.your_club');

  final seq = <String, List<String>>{};
  final played = [
    for (final f in fixtures)
      if (f is Map<String, dynamic> && _int(f['round']) <= currentRound) f,
  ]..sort((a, b) => _int(a['round']).compareTo(_int(b['round'])));

  for (final fix in played) {
    int? hg;
    int? ag;
    final playerMatch = fix['playerMatchNum'];
    if (playerMatch != null) {
      final r = _map(results['s${season}_m$playerMatch']);
      if (r == null) continue;
      // `homeGoals` in a stored result is the PLAYER'S goals whichever ground it
      // was on, so it has to be oriented to physical home/away before it can be
      // read as a fixture.
      if (fix['homeTeam'] == null) {
        hg = _int(r['homeGoals']);
        ag = _int(r['awayGoals']);
      } else {
        hg = _int(r['awayGoals']);
        ag = _int(r['homeGoals']);
      }
    } else {
      if (fix['homeGoals'] == null) continue;
      hg = _int(fix['homeGoals']);
      ag = _int(fix['awayGoals']);
    }

    final home = fix['homeTeam'] as String? ?? playerName;
    final away = fix['awayTeam'] as String? ?? playerName;
    (seq[home] ??= []).add(
      hg > ag
          ? 'W'
          : hg == ag
          ? 'D'
          : 'L',
    );
    (seq[away] ??= []).add(
      ag > hg
          ? 'W'
          : ag == hg
          ? 'D'
          : 'L',
    );
  }

  return {
    for (final e in seq.entries)
      e.key: e.value.length <= 5
          ? e.value
          : e.value.sublist(e.value.length - 5),
  };
});

/// **WHAT EACH CLUB IN THE TABLE IS WORTH**, by club name.
///
/// Asked for from the couch, and the second time in the words that pinned it
/// down: "i dont mean a position i mean team rank i.e the fifa score." A table
/// of points says who is winning; the rating says who is DANGEROUS, and it is
/// the number every other screen in the game argues about.
///
/// **Read out of the save rather than added to `LeagueRow`.** That record is
/// built by `buildLeagueTable`, which is pinned field for field by the season
/// differential harness and writes back into the progression branch as it goes;
/// this is a read, and a read belongs beside the screen that wants it.
///
/// The opponents' figures are the ones the sim itself uses —
/// `seasonOpponentRatings`, keyed `s<season>_o<index>` against the season's own
/// opponent list, which is exactly how `previewFixture` finds the one it is
/// about to play. The player's own club is its effective squad rating, so the
/// row a manager cares about is measured the same way the fixture card measures
/// it.
final leagueRatingsProvider = savePick<Map<String, int>>((s) {
  final prog = s['progression'];
  if (prog is! Map<String, dynamic>) return const {};
  final divId = '${prog['currentDivision']}';
  final season = (prog['seasonCount'] as num?)?.toInt() ?? 1;
  final stored = prog['seasonOpponentRatings'];
  final ratings = stored is Map<String, dynamic>
      ? stored
      : const <String, dynamic>{};
  final names = getSeasonOpponents(divId, season, s);

  final out = <String, int>{};
  for (var i = 0; i < names.length; i++) {
    final value = ratings['s${season}_o$i'];
    if (value is num) out[names[i]] = value.round();
  }
  final clubName = s['clubName'];
  if (clubName is String && clubName.isNotEmpty) {
    out[clubName] = previewFixture(s)?.effectiveSquadRating.round() ?? 0;
  }
  return out;
});
