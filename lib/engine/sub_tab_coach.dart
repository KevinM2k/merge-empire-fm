/// Coach Colin's read on whichever LIST you are looking at. Ported from
/// `_leagueTableTip`, `_leagueFixturesTip`, `_leagueMinigamesTip` and
/// `_subTabPriorityTip` in `../merge-empire-fc/src/ui/screens/LeagueScreen.js`.
///
/// **Fifteen `coach.*` strings with nothing able to print one**, and the reason
/// they were stranded is structural rather than an oversight: the JS has these
/// as League SUB-TABS and the port has them as SHEETS, and a sheet is a route —
/// so it covers the floating coach by construction. The line has to be INSIDE
/// the sheet, which is the design call the queue flagged, and this is the
/// engine half of it.
///
/// **Three questions, not one.** The table's read is about standings, the
/// fixtures' is about how the squad compares to the division, and the
/// mini-games' is about nothing at all unless a cup tie is due — which is why
/// the third returns null so often. Each carries its own cup and energy line
/// too: "no energy" on the table should not read the same as on the fixtures,
/// because both have real state to comment on either way.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// One line, with the seed its pool is picked on.
///
/// [priority] marks the cup and energy lines, which jump whatever the sub-tab
/// would otherwise have said — they are the two things a player has to act on
/// before anything on the list matters.
/// A class rather than a record because of [params]: a record compares its
/// fields with `==`, two of the lines below build a fresh map literal, and an
/// identical tip then reported a change on every tick.
class SubTabTip {
  const SubTabTip({
    required this.key,
    required this.seed,
    required this.params,
    required this.priority,
  });

  final String key;
  final String seed;
  final Map<String, Object?> params;
  final bool priority;

  // Hand-rolled: `lib/engine` may not import Flutter's `mapEquals`.
  static bool _sameParams(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubTabTip &&
          other.key == key &&
          other.seed == seed &&
          other.priority == priority &&
          _sameParams(other.params, params);

  @override
  int get hashCode => Object.hash(
    key,
    seed,
    priority,
    Object.hashAllUnordered([
      for (final e in params.entries) Object.hash(e.key, e.value),
    ]),
  );
}

/// Which list is being looked at.
enum SubTab { table, fixtures, minigames }

List<CardInstance> _squad(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [
    for (final c in cells) ?CardInstance.from(c),
  ];
}

/// The cup or the empty tank, which outrank whatever the list says.
///
/// Per SUB-TAB rather than one line for all three: the catalogue ships six
/// strings here, and the JS's own note is that "no energy" on the table should
/// not read the same as on the fixtures.
SubTabTip? _priority(
  Map<String, dynamic>? state,
  SubTab tab, {
  required bool cupIsDue,
}) {
  final name = tab.name;
  if (cupIsDue) {
    return SubTabTip(
      key: 'coach.cup_due.$name',
      seed: 'cup-$name',
      params: const {},
      priority: true,
    );
  }
  final energy = _num(_map(state?['energy'])?['current'])?.toInt() ?? 0;
  if (energy <= 2) {
    return SubTabTip(
      key: 'coach.low_energy.$name',
      seed: 'energy-$name',
      params: const {},
      priority: true,
    );
  }
  return null;
}

/// The standings, as he reads them.
SubTabTip? leagueTableTip(
  Map<String, dynamic>? state, {
  required bool cupIsDue,
}) {
  final priority = _priority(state, SubTab.table, cupIsDue: cupIsDue);
  if (priority != null) return priority;
  final prog = _map(state?['progression']);
  if (state == null || prog == null) return null;

  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  // The counter the WINS were added to — see `squad_state_engine`.
  final played = _num(prog['seasonAwardedPlayed'])?.toInt() ?? 0;
  final wins = _num(prog['seasonWins'])?.toInt() ?? 0;

  SubTabTip tip(String key, [Map<String, Object?> params = const {}]) =>
      SubTabTip(
    key: key,
    seed: 'table-$key-s$season',
    params: params,
    priority: false,
  );

  // **Three matches is when a table starts meaning anything**, which is the
  // JS's own threshold and the reason this branch exists at all: a position
  // read off one result is a position nobody should be told to act on.
  if (played < 3) return tip('coach.table.early');

  final rows = buildLeagueTable(state);
  final pos = rows.indexWhere((r) => r.isPlayer) + 1;
  if (pos <= 0) return tip('coach.table.early');
  final total = rows.length;

  if (pos == total) return tip('coach.table.bottom');
  if (pos == 1 && '${prog['currentDivision']}' == 'champions_cup') {
    return tip('coach.table.champ_top');
  }
  if (pos <= 2) return tip('coach.table.promo_zone');

  final rate = wins / (played < 1 ? 1 : played);
  if (rate >= 0.6) return tip('coach.table.form_good');
  if (rate <= 0.2 && played >= 5) return tip('coach.table.slump');

  return tip('coach.table.mid', {
    'pos': pos,
    'ord': ordinalSuffix(pos),
    'total': total,
  });
}

/// `st`, `nd`, `rd` or `th`.
///
/// The JS's own three cases and no more — it never reads past seven teams, so
/// the eleventh/twelfth/thirteenth exception a general routine needs has never
/// come up. Written out rather than generalised for that reason: a rule this
/// port cannot exercise is a rule nothing can check.
String ordinalSuffix(int n) => switch (n) {
  1 => 'st',
  2 => 'nd',
  3 => 'rd',
  _ => 'th',
};

/// How the squad measures against the division it is in.
SubTabTip? leagueFixturesTip(
  Map<String, dynamic>? state, {
  required bool cupIsDue,
}) {
  final priority = _priority(state, SubTab.fixtures, cupIsDue: cupIsDue);
  if (priority != null) return priority;
  final prog = _map(state?['progression']);
  if (state == null || prog == null) return null;

  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  final squad = _squad(state);
  final injured = squad.where((c) => c.injured).length;

  SubTabTip tip(String key, [Map<String, Object?> params = const {}]) =>
      SubTabTip(
    key: key,
    seed: 'fix-$key-s$season-n$injured',
    params: params,
    priority: false,
  );

  // **The treatment room first**, because it is the one thing on this list the
  // player can do something about before the next fixture.
  if (injured >= 2) return tip('coach.fixtures.injured', {'n': injured});

  final rawLineup = _map(state['squad'])?['lineup'];
  final lineup = (rawLineup is List && rawLineup.length == 11)
      ? [
          for (final s in rawLineup)
            if (s is Map<String, dynamic>) s,
        ]
      : null;
  final rating = computeSquadRating(
    [for (final c in squad) c],
    lineup: lineup?.length == 11 ? lineup : null,
    definitionRatios: _map(state['definitionRatios']) ?? const {},
    fatigue: true,
  );
  // Against the TOP of the division's band, not its middle: "we outgun nearly
  // everyone in here" is a claim about the best of them.
  final gap = rating - getDivision('${prog['currentDivision']}').opponentRatingRange.$2;

  if (gap >= 10) return tip('coach.fixtures.dominant');
  if (gap <= -10) return tip('coach.fixtures.weak');
  return tip('coach.fixtures.even');
}

/// Training is free, so the only thing worth surfacing is an imminent cup tie.
///
/// No energy line: a tank at nought is not a reason to stay off a sheet full of
/// games that cost none — which is why the JS gives this one the cup branch
/// alone and nothing else.
SubTabTip? leagueMinigamesTip(
  Map<String, dynamic>? state, {
  required bool cupIsDue,
}) => cupIsDue
    ? const SubTabTip(
        key: 'coach.cup_due.minigames',
        seed: 'cup-minigames',
        params: {},
        priority: true,
      )
    : null;
