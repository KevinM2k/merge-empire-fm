/// Cup tournaments. Ported from `../merge-empire-fc/src/engine/cupEngine.js`.
///
/// A cup tie runs on the same squad-rating semantics as a league game, but
/// difficulty comes from a real opponent drawn out of the pyramid rather than
/// from a division band — and it is played on neutral ground, so neither side
/// gets home advantage.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

List<dynamic> _list(Map<String, dynamic> owner, String key) {
  final existing = owner[key];
  if (existing is List) return existing;
  final fresh = <dynamic>[];
  owner[key] = fresh;
  return fresh;
}

List<dynamic> _rawCells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

List<CardInstance?> _cells(Map<String, dynamic>? state) => [
  for (final c in _rawCells(state)) CardInstance.from(c),
];

List<Map<String, dynamic>> _lineup(Map<String, dynamic>? state) {
  final raw = _map(state?['squad'])?['lineup'];
  if (raw is! List) return const [];
  return [
    for (final s in raw)
      if (s is Map<String, dynamic>) s,
  ];
}

int _divisionIdx(Map<String, dynamic>? state) {
  final idx = divisions.indexWhere(
    (d) => d.id == _map(state?['progression'])?['currentDivision'],
  );
  return math.max(0, idx);
}

/// The cup unlocked at the player's division, or null.
///
/// Prefers the highest-tier one they have reached — being in the Champions
/// League should surface the World Club Cup, not the Regional.
Cup? cupForDivision(Map<String, dynamic>? state) {
  final idx = _divisionIdx(state);
  Cup? best;
  for (final c in cups) {
    if (idx >= c.unlocksAtDivisionIdx) best = c;
  }
  return best;
}

/// Which adventure is being played, stamped onto every history entry.
///
/// Prestige restarts the season counter at one, so "season 3" alone doesn't
/// identify a season: the run has to come with it, or a cup the previous run
/// entered at that number locks this one out and its results show up in this
/// run's form. An entry written before the stamp existed reads as run zero,
/// which keeps the guard intact for a player who has never prestiged.
int cupRun(Map<String, dynamic>? state) =>
    _num(_map(state?['prestige'])?['level'])?.toInt() ?? 0;

/// Is this history entry from the run currently being played?
bool isCupEntryThisRun(
  Map<String, dynamic>? state,
  Map<String, dynamic>? entry,
) => (_num(entry?['run'])?.toInt() ?? 0) == cupRun(state);

Map<String, dynamic> _ensureCupState(Map<String, dynamic> state) {
  final prog = _branch(state, 'progression');
  final existing = _map(prog['cups']);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{
    'active': null,
    'history': <dynamic>[],
    'availableThisSeason': true,
  };
  prog['cups'] = fresh;
  return fresh;
}

/// Can a cup be entered right now?
///
/// The player has to have reached its unlock division, not already have played
/// one this season, and not have a run in progress.
bool cupAvailable(Map<String, dynamic> state) {
  final cup = cupForDivision(state);
  if (cup == null) return false;
  final cups = _ensureCupState(state);
  if (cups['active'] != null) return false;

  // "One cup run per season" is enforced against the HISTORY, because the flag
  // alone isn't trustworthy — older code flipped it back to true after an
  // elimination, which had the auto-enter re-rolling a fresh bracket on every
  // restart.
  final season = _num(_map(state['progression'])?['seasonCount'])?.toInt() ?? 1;
  final history = cups['history'];
  if (history is List) {
    for (final raw in history) {
      final h = _map(raw);
      if (h == null) continue;
      if (h['season'] == season &&
          h['cupId'] == cup.id &&
          isCupEntryThisRun(state, h)) {
        return false;
      }
    }
  }
  return cups['availableThisSeason'] != false;
}

/// Reset availability when a league season ends.
void refreshCupAvailability(Map<String, dynamic> state) {
  _ensureCupState(state)['availableThisSeason'] = true;
}

/// A club drawn into the bracket.
typedef CupOpponent = ({
  String name,
  String divId,
  num rating,
  double attackRatio,
});

/// How likely a club is to be drawn, by how far below the top available
/// division it sits (index 0 is the top).
///
/// The quarter-final spread is wide and the final is almost exclusively the top
/// flight, which is what makes a bracket read as a real cup rather than a
/// ladder of ever-bigger numbers.
const List<List<int>> _distWeights = [
  [30, 28, 18, 10, 7, 5, 2], // QF — mostly top-two, the occasional giant-killer
  [55, 30, 12, 3, 0, 0, 0], // SF — the top division dominates
  [90, 9, 1, 0, 0, 0, 0], // Final — 90% from the top available division
];

/// Draw [count] distinct clubs out of the pyramid, one per round.
///
/// Returns null when there is no pyramid to draw from, so the caller can wait
/// rather than invent fictional opponents.
List<CupOpponent>? _pickOpponentsFromPyramid(
  Map<String, dynamic> state,
  int count,
  int minDivIdx,
) {
  final pyramid = _map(_map(state['progression'])?['leaguePyramid']);
  if (pyramid == null) return null;

  // Within each division the pool is sorted by rating, so the rank multiplier
  // applied for the later rounds amplifies the front of it.
  Map<int, List<CupOpponent>> poolsFrom(int floor) {
    final byDiv = <int, List<CupOpponent>>{};
    for (final entry in pyramid.entries) {
      final divIdx = divisions.indexWhere((d) => d.id == entry.key);
      if (divIdx < 0 || divIdx < floor) continue;
      final teams = entry.value;
      if (teams is! List) continue;
      final pool = <CupOpponent>[
        for (final raw in teams)
          if (_map(raw) case final t?)
            if (t['name'] case final String name)
              if (name.isNotEmpty)
                (
                  name: name,
                  divId: entry.key,
                  rating: _num(t['rating']) ?? 50,
                  attackRatio:
                      _num(t['attackRatio'])?.toDouble() ?? oppBaseAtkShare,
                ),
      ]..sort((a, b) => b.rating.compareTo(a.rating));
      if (pool.isNotEmpty) byDiv[divIdx] = pool;
    }
    return byDiv;
  }

  // Clubs below the cup's own unlock division cannot qualify — but if that
  // leaves nothing at all, fall back to the whole pyramid so the bracket is
  // still made of real clubs.
  var byDiv = poolsFrom(minDivIdx);
  if (byDiv.isEmpty) byDiv = poolsFrom(0);
  if (byDiv.isEmpty) return null;

  final maxAvailIdx = byDiv.keys.reduce(math.max);
  final used = <String>{};
  final picks = <CupOpponent>[];

  for (var round = 0; round < count; round++) {
    final weights = _distWeights[math.min(round, _distWeights.length - 1)];
    // The later the round, the more the draw favours the strongest clubs — and
    // the fewer of them are eligible at all.
    final ratingBoost = round >= 2 ? 4 : (round >= 1 ? 2 : 1);
    final poolSize = round >= 2 ? 3 : (round >= 1 ? 5 : null);

    final weighted = <({CupOpponent c, double w})>[];
    for (final entry in byDiv.entries) {
      final dist = maxAvailIdx - entry.key;
      final w = weights[math.min(dist, weights.length - 1)];
      if (w <= 0) continue;
      var seen = 0;
      for (final c in entry.value) {
        if (used.contains(c.name)) continue;
        if (poolSize != null && seen >= poolSize) break;
        // Rank-based: first in the pool gets the full boost, last gets one.
        final rankMult = ratingBoost > 1
            ? ratingBoost -
                  (seen *
                      (ratingBoost - 1) /
                      math.max((poolSize ?? entry.value.length) - 1, 1))
            : 1.0;
        weighted.add((c: c, w: w * rankMult));
        seen++;
      }
    }

    if (weighted.isEmpty) return null;

    final total = weighted.fold<double>(0, (s, x) => s + x.w);
    var r = seeded.random() * total;
    var pick = weighted.last.c;
    for (final entry in weighted) {
      r -= entry.w;
      if (r <= 0) {
        pick = entry.c;
        break;
      }
    }

    used.add(pick.name);
    picks.add(pick);
  }

  return picks;
}

String _ordinal(int pos) => switch (pos) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${pos}th',
};

/// The scout report for each opponent, in qualitative language — never a raw
/// rating.
///
/// Derived from real state where there is any: the opponent's division against
/// the player's own, and where they sit in their league. An old save with no
/// opponent metadata falls back to the fictional flavour lines.
List<String> _pickContexts(
  Map<String, dynamic> state,
  List<String> opponents,
  List<CupOpponent>? meta,
  Map<String, dynamic>? pyramid,
  String? curDivId,
) {
  final curDivIdx = math.max(0, divisions.indexWhere((d) => d.id == curDivId));

  return [
    for (var i = 0; i < opponents.length; i++)
      () {
        final name = opponents[i];
        final m = (meta != null && i < meta.length) ? meta[i] : null;
        if (m == null || pyramid == null) {
          final pool = seeded.shuffle([...cupOpponentContext]);
          return (pool.isEmpty
                  ? cupOpponentContext.first
                  : pool[i % pool.length])
              .replaceAll('{team}', name);
        }

        final divName = getDivision(m.divId).name;
        final oppDivIdx = math.max(
          0,
          divisions.indexWhere((d) => d.id == m.divId),
        );
        final divDiff = oppDivIdx - curDivIdx;

        final divTeams = pyramid[m.divId];
        final teamList = divTeams is List ? divTeams : const <dynamic>[];
        // The player's own club is in the same table, so it counts toward the
        // total when the opponent shares their division.
        final totalTeams = teamList.length + (divDiff == 0 ? 1 : 0);

        // For a same-division opponent the cached live table position is right,
        // because it includes the player. For any other division there is no
        // live table, so rank by rating within that slice of the pyramid.
        final cached = _num(
          _map(_map(state['progression'])?['opponentTablePositions'])?[name],
        );
        final int pos;
        if (divDiff == 0 && cached != null) {
          pos = cached.toInt();
        } else {
          final sorted = [for (final t in teamList) ?_map(t)]
            ..sort(
              (a, b) =>
                  (_num(b['rating']) ?? 0).compareTo(_num(a['rating']) ?? 0),
            );
          final idx = sorted.indexWhere((t) => t['name'] == name);
          pos = idx >= 0 ? idx + 1 : teamList.length;
        }
        final isTopHalf = pos <= (totalTeams / 2).ceil();
        final posStr = _ordinal(pos);

        if (divDiff >= 2) {
          return isTopHalf
              ? "$name sit $posStr in the $divName — a much stronger division "
                    "than ours. We'll need to be at our absolute best just to "
                    'keep up.'
              : '$name come from the $divName, a stronger league than ours. '
                    'Even a mid-table side from up there carries serious quality '
                    "— can't afford a slow start.";
        }
        if (divDiff == 1) {
          return isTopHalf
              ? "$name are $posStr in the $divName — a step up from what we're "
                    'used to. Tight, disciplined, no mistakes.'
              : "$name play in a stronger division than us. They won't be an "
                    "easy ride even if they're not flying in their own league.";
        }
        if (divDiff == 0) {
          if (pos == 1) {
            return "$name are top of the $divName — level with us on paper, "
                "but they're firing on all cylinders. No room for complacency.";
          }
          return isTopHalf
              ? '$name sit $posStr in the $divName — similar level to us. '
                    'Expect a tough contest.'
              : '$name are from the $divName, similar level to us. Should be '
                    'an even contest — whoever wants it more on the day wins.';
        }
        if (divDiff == -1) {
          return pos == 1
              ? '$name are leading the $divName — a division below, but cup '
                    'football is a leveller. Expect them to come out fighting.'
              : "$name come from a lower division. We're favourites, but "
                    "they'll be desperate to cause an upset — stay focused from "
                    'the first whistle.';
        }
        return pos == 1
            ? "$name are top of the $divName, but that's a lower division than "
                  'ours. We have the quality edge — use it, but don\'t get '
                  'careless.'
            : '$name are from a much lower division. On paper this should be '
                  'comfortable, but cup runs have ended for less. Take it '
                  'seriously.';
      }(),
  ];
}

/// The sponsors a cup run can drop onto a player.
const List<({String name, double multiplier})> cupPlayerSponsors = [
  (name: 'Apex Auto', multiplier: 1.15),
  (name: 'Horizon Tech', multiplier: 1.20),
  (name: 'Meridian Bank', multiplier: 1.25),
  (name: 'Valkyrie Sport', multiplier: 1.30),
  (name: 'Obsidian Wear', multiplier: 1.35),
];

/// A sponsor offer a cup win produced.
typedef CupSponsorDrop = ({
  String kind,
  int cellIdx,
  ({String name, double multiplier}) sponsorData,
  String playerName,
});

CupSponsorDrop? _dropPlayerSponsor(Map<String, dynamic> state) {
  final cells = _rawCells(state);
  final candidates = <int>[
    for (var i = 0; i < cells.length; i++)
      if (_map(cells[i]) case final c?)
        if (c['sponsor'] == null) i,
  ];
  if (candidates.isEmpty) return null;

  final idx = candidates[(seeded.random() * candidates.length).floor()];
  final sponsor =
      cupPlayerSponsors[(seeded.random() * cupPlayerSponsors.length).floor()];
  // Not applied here — the descriptor goes back so the UI can ask first.
  return (
    kind: 'player_sponsor',
    cellIdx: idx,
    sponsorData: sponsor,
    playerName: getCardName(_map(cells[idx]), 'a player'),
  );
}

/// Take up a sponsor a cup win offered.
///
/// Deliberately separate from the roll: [commitCupRound] hands back a descriptor
/// and applies nothing, because the player is being ASKED. A drop nobody answers
/// changes no card.
///
/// Refuses a card that has gone since the tie — sold, merged or auto-sold — and a
/// card that already carries a sponsor, so a second cup win cannot overwrite a
/// deal the player is still living with.
bool acceptCupSponsorDrop(Map<String, dynamic> state, CupSponsorDrop drop) {
  final cells = _rawCells(state);
  if (drop.cellIdx < 0 || drop.cellIdx >= cells.length) return false;
  final card = _map(cells[drop.cellIdx]);
  if (card == null || card['sponsor'] != null) return false;
  card['sponsor'] = <String, dynamic>{
    'name': drop.sponsorData.name,
    'multiplier': drop.sponsorData.multiplier,
    'signedSeason':
        _num(_map(state['progression'])?['seasonCount'])?.toInt() ?? 1,
  };
  emit('cup:sponsor-signed', {
    'player': drop.playerName,
    'sponsor': drop.sponsorData.name,
  });
  return true;
}

/// The save-shaped form of a drop. The history is persisted, so it cannot hold
/// a record.
Map<String, dynamic> _dropToMap(CupSponsorDrop drop) => <String, dynamic>{
  'kind': drop.kind,
  'cellIdx': drop.cellIdx,
  'sponsorData': <String, dynamic>{
    'name': drop.sponsorData.name,
    'multiplier': drop.sponsorData.multiplier,
  },
  'playerName': drop.playerName,
};

/// Roll a post-win sponsor drop. The chance scales by round — a quarter at the
/// quarter-final, certain in the final.
CupSponsorDrop? _rollCupSponsorDrop(
  Map<String, dynamic> state,
  int round,
  int totalRounds,
) {
  final t = totalRounds > 1 ? round / (totalRounds - 1) : 1.0;
  final chance = 0.25 + (1.0 - 0.25) * t;
  if (seeded.random() > chance) return null;
  return _dropPlayerSponsor(state);
}

/// Start the available cup run, building the bracket. Null when there is
/// nothing to start, or no pyramid to draw opponents from yet.
Map<String, dynamic>? startCup(Map<String, dynamic> state) {
  if (!cupAvailable(state)) return null;
  final cup = cupForDivision(state)!;
  final cups = _ensureCupState(state);

  final picks = _pickOpponentsFromPyramid(
    state,
    cup.rounds.length,
    cup.unlocksAtDivisionIdx,
  );
  if (picks == null) return null;

  final opponents = [for (final o in picks) o.name];
  final prog = _map(state['progression']);
  final active = <String, dynamic>{
    'cupId': cup.id,
    // Zero-indexed; the round's name is `cup.rounds[round]`.
    'round': 0,
    'opponents': opponents,
    'opponentMeta': [
      for (final o in picks)
        <String, dynamic>{
          'divId': o.divId,
          'rating': o.rating,
          'attackRatio': o.attackRatio,
        },
    ],
    'contexts': _pickContexts(
      state,
      opponents,
      picks,
      _map(prog?['leaguePyramid']),
      prog?['currentDivision'] as String?,
    ),
    'results': <dynamic>[],
    'startedAt': now(),
    'startedSeason': _num(prog?['seasonCount'])?.toInt() ?? 1,
  };

  cups['active'] = active;
  cups['availableThisSeason'] = false;
  emit('cup:started', {'cupId': cup.id, 'opponents': opponents});
  return active;
}

/// An injury rolled for a cup tie.
class CupInjury {
  CupInjury({required this.card, required this.minute});

  final CardInstance card;
  final int minute;
  String? name;
  String? subName;
  VacatedSlot? slot;
  bool applied = false;
}

/// A simulated but uncommitted cup round.
typedef PreparedCupRound = ({
  String cupId,
  int round,
  String roundName,
  String opponentName,
  bool won,
  int homeGoals,
  int awayGoals,
  num earned,
  int squadRating,
  num opponentRating,
  bool isCup,
  int ourAttackRating,
  int ourDefenceRating,
  int effOppAttackRating,
  int effOppDefenceRating,
  bool isFinal,
  Shootout? penaltyShootout,
  List<CupInjury> injuries,
  String? injuredName,
});

/// Who the due cup tie is against, and how good they are — WITHOUT playing it.
///
/// **[prepareCupRound] is not a preview, and two home-screen providers were
/// calling it as one.** Reported from the couch as three separate faults that
/// turned out to be one: players going injured while the manager sat on the
/// Squad page watching, an entire squad injured after a single cup week, and
/// the team ratings then reading 0 — which is exactly what
/// [computeSquadRatings] returns when all eleven are hurt.
///
/// `prepareCupRound` simulates the tie. It rolls injuries and APPLIES them
/// (`_applyInjury` sets `injured` and vacates the man's slot), it spends the
/// Lucky Boot, and it draws from the seeded stream. Both providers that named
/// the cup opponent are `savePick`s, so every save mutation re-ran them and
/// each run injured up to two more men — a feedback loop, because injuring
/// somebody is itself a save mutation.
///
/// So the caption gets its own read of the bracket. Nothing here writes: the
/// cup map is read rather than ensured, the Lucky Boot is applied to the number
/// on show without clearing the flag (the same trick `previewFixture` uses for
/// a league game), and the rating comes off `opponentMeta` — the club drawn
/// into the bracket — rather than being re-drawn.
///
/// The one number this cannot promise is a legacy run with no `opponentMeta`:
/// the tie jitters that rating by ±4 on a seeded draw, and a preview may not
/// draw. It shows the unjittered midpoint, which is what the jitter is centred
/// on.
typedef CupTiePreview = ({
  String cupId,
  int round,
  String roundName,
  String opponentName,
  num opponentRating,
  double oppAttackRatio,
});

CupTiePreview? previewCupTie(Map<String, dynamic> state) {
  final run = activeCup(state);
  if (run == null) return null;
  final cup = getCupById(run['cupId'] as String?);
  final round = _num(run['round'])?.toInt() ?? 0;
  if (cup == null || round >= cup.rounds.length) return null;

  final opponentList = run['opponents'];
  final opponentName = (opponentList is List && round < opponentList.length)
      ? '${opponentList[round]}'
      : 'Opponent';

  final metaRaw = run['opponentMeta'];
  final meta = (metaRaw is List && round < metaRaw.length)
      ? _map(metaRaw[round])
      : null;
  final realRating = _num(meta?['rating']);
  final bump = round < cup.opponentRatingBump.length
      ? cup.opponentRatingBump[round]
      : 10;

  // The squad rating the tie would be pitched against, read exactly as
  // `prepareCupRound` reads it — Pro mode plays at current fitness.
  final fatigue = _map(state['settings'])?['hardMode'] == true;
  final lineupRaw = _lineup(state);
  final squadRating = computeSquadRating(
    _cells(state),
    lineup: lineupRaw.length == 11 ? lineupRaw : null,
    definitionRatios: _map(state['definitionRatios']) ?? const {},
    fatigue: fatigue,
  );

  var opponentRating = realRating != null
      ? math.min(100, math.max(20, realRating))
      : math.min(100, math.max(20, squadRating + bump));

  // Applied, not spent — see the note above.
  if (_map(state['shop'])?['luckyBootReady'] == true) {
    opponentRating = applyLuckyBoot(opponentRating);
  }

  return (
    cupId: cup.id,
    round: round,
    roundName: cup.rounds[round],
    opponentName: opponentName,
    opponentRating: opponentRating,
    oppAttackRatio:
        _num(meta?['attackRatio'])?.toDouble() ?? oppBaseAtkShare,
  );
}

/// Simulate — but do not commit — the current cup round.
///
/// The only side effect applied up front is spending the Lucky Boot, which is a
/// one-shot consumable: taking it now is what stops it being replayed by
/// cancelling the popup. Everything else — coins, the bracket, the history, the
/// sponsor drop, the announcements — waits for [commitCupRound], because the
/// player can still change tactics and change the result.
PreparedCupRound? prepareCupRound(Map<String, dynamic> state) {
  final cups = _ensureCupState(state);
  final run = _map(cups['active']);
  if (run == null) return null;
  final cup = getCupById(run['cupId'] as String?);
  final round = _num(run['round'])?.toInt() ?? 0;
  if (cup == null || round >= cup.rounds.length) return null;

  final opponentList = run['opponents'];
  final opponentName = (opponentList is List && round < opponentList.length)
      ? '${opponentList[round]}'
      : 'Opponent';

  // The same rules as a league game: Pro mode plays a cup tie at CURRENT
  // fitness — no free full-strength matches for a knackered squad — and the
  // rating on show reflects the actual lineup.
  final fatigue = _map(state['settings'])?['hardMode'] == true;
  final lineupRaw = _lineup(state);
  final lineup = lineupRaw.length == 11 ? lineupRaw : null;
  final cells = _cells(state);
  final ratios = _map(state['definitionRatios']) ?? const {};

  final squadRating = computeSquadRating(
    cells,
    lineup: lineup,
    definitionRatios: ratios,
    fatigue: fatigue,
  );

  final metaRaw = run['opponentMeta'];
  final meta = (metaRaw is List && round < metaRaw.length)
      ? _map(metaRaw[round])
      : null;
  final realRating = _num(meta?['rating']);
  final bump = round < cup.opponentRatingBump.length
      ? cup.opponentRatingBump[round]
      : 10;

  var opponentRating = realRating != null
      ? math.min(100, math.max(20, realRating))
      : math.min(
          100,
          math.max(20, squadRating + bump + seeded.randomInt(-4, 4)),
        );

  // The Lucky Boot weakens them before the split into ATK and DEF.
  final shop = _map(state['shop']);
  if (shop?['luckyBootReady'] == true) {
    opponentRating = applyLuckyBoot(opponentRating);
    shop!['luckyBootReady'] = false;
  }

  final baseRatings = computeSquadRatings(
    cells,
    lineup: lineup,
    definitionRatios: ratios,
    fatigue: fatigue,
  );
  final strat =
      strategies[_map(state['squad'])?['strategyId'] as String?] ??
      strategies[defaultStrategy]!;

  // Their ATK and DEF are computed BEFORE our tactic is applied, because
  // Counter Attack's multiplier reads how committed forward they are. A cup tie
  // is no different.
  final oppAttackRatio =
      _num(meta?['attackRatio'])?.toDouble() ?? oppBaseAtkShare;
  final oppSplit = opponentAtkDefFromShare(opponentRating, oppAttackRatio);

  final adjAttack = math.max(
    1.0,
    applyTacticAtk(baseRatings.attack, strat, oppAttackRatio),
  );
  final adjDefence = math.max(
    1.0,
    applyTacticDef(baseRatings.defence, strat, oppAttackRatio),
  );

  final injuries = _rollCupInjuries(state, cells);

  // Neutral ground — no home advantage for either side. The tactic's tempo and
  // its hot-or-cold swing apply exactly as in a league game.
  final cupVariance = strat.variance * rollSwingFactor(strat);

  int homeGoals;
  int awayGoals;

  if (injuries.isNotEmpty) {
    // One window per injury: full strength up to its minute, apply it, then
    // recompute and carry on. The same shape as a league match.
    var curAtk = adjAttack;
    var curDef = adjDefence;
    var prevMin = 0;
    homeGoals = 0;
    awayGoals = 0;

    void sampleWindow(int upTo) {
      final frac = math.max(0, (upTo - prevMin) / 90);
      homeGoals += sampleWindowGoals(
        curAtk,
        oppSplit.defence,
        frac.toDouble(),
        cupVariance,
      );
      awayGoals += sampleWindowGoals(
        oppSplit.attack,
        curDef,
        frac.toDouble(),
        cupVariance,
      );
      prevMin = upTo;
    }

    for (final entry in injuries) {
      sampleWindow(entry.minute);
      _applyInjury(state, entry);
      final postBase = computeSquadRatings(
        _cells(state),
        lineup: _lineup(state).length == 11 ? _lineup(state) : null,
        definitionRatios: ratios,
        fatigue: fatigue,
      );
      curAtk = math.max(
        1.0,
        applyTacticAtk(postBase.attack, strat, oppAttackRatio),
      );
      curDef = math.max(
        1.0,
        applyTacticDef(postBase.defence, strat, oppAttackRatio),
      );
    }
    sampleWindow(90);
  } else {
    homeGoals = simulateGoals(adjAttack, oppSplit.defence, cupVariance);
    awayGoals = simulateGoals(oppSplit.attack, adjDefence, cupVariance);
  }

  Shootout? penaltyShootout;
  if (homeGoals == awayGoals) {
    penaltyShootout = simulatePenaltyShootout(
      adjAttack,
      adjDefence,
      oppSplit.attack,
      oppSplit.defence,
    );
    if (penaltyShootout.playerWins) {
      homeGoals += 1;
    } else {
      awayGoals += 1;
    }
  }

  final won = homeGoals > awayGoals;
  final earned = _roundPrize(state, cup, round, won);

  return (
    cupId: cup.id,
    round: round,
    roundName: cup.rounds[round],
    opponentName: opponentName,
    won: won,
    homeGoals: homeGoals,
    awayGoals: awayGoals,
    earned: earned,
    squadRating: squadRating,
    opponentRating: opponentRating,
    isCup: true,
    ourAttackRating: baseRatings.attack,
    ourDefenceRating: baseRatings.defence,
    effOppAttackRating: oppSplit.attack,
    effOppDefenceRating: oppSplit.defence,
    isFinal: round == cup.rounds.length - 1,
    penaltyShootout: penaltyShootout,
    injuries: injuries,
    injuredName: injuries.isEmpty ? null : injuries.first.name,
  );
}

/// Coins for a round. A defeat still pays a share — a cup run is worth
/// something even when it ends.
num _roundPrize(Map<String, dynamic> state, Cup cup, int round, bool won) {
  final div = getDivision('${_map(state['progression'])?['currentDivision']}');
  final prizeMult = round < cup.roundPrizeMult.length
      ? cup.roundPrizeMult[round]
      : 1.0;
  return roundCoins(div.matchRevenueBase * prizeMult * (won ? 1.0 : 0.4));
}

/// Roll this tie's injuries.
///
/// The same decision model as a league game: up to TWO, the second on a
/// different player at half the chance, and always later in the match.
List<CupInjury> _rollCupInjuries(
  Map<String, dynamic> state,
  List<CardInstance?> cells,
) {
  final injuries = <CupInjury>[];
  final lineupIds = <String>{
    for (final s in _lineup(state))
      if (s['cardInstanceId'] case final String id) id,
  };

  var pool = <CardInstance>[
    for (final c in cells)
      if (c != null && !c.injured)
        if (lineupIds.isEmpty || lineupIds.contains(c.instanceId)) c,
  ];
  if (pool.isEmpty) return injuries;

  final squadInjRed = computeSquadTraitTotals(
    cells,
    _lineup(state),
  ).teamInjuryReduction;

  bool injuryRoll(CardInstance candidate, double mult) {
    var chance = getInjuryChance(candidate.seasonsPlayed, _divisionIdx(state));
    chance += sponsorDrawback(_map(candidate.raw['sponsor'])).injuryPenalty;
    chance -= getTraitBonus(
      candidate,
      getPlayerDef(candidate.definitionId)?.position,
    ).injuryReduction;
    chance -= squadInjRed;
    return seeded.random() < chance * mult;
  }

  final c1 = pool[seeded.randomInt(0, pool.length - 1)];
  if (!injuryRoll(c1, 1)) return injuries;

  final m1 = seeded.randomInt(20, 85);
  injuries.add(CupInjury(card: c1, minute: m1));
  pool = [
    for (final c in pool)
      if (!identical(c, c1)) c,
  ];
  if (pool.isEmpty) return injuries;

  final c2 = pool[seeded.randomInt(0, pool.length - 1)];
  if (injuryRoll(c2, 0.5)) {
    injuries.add(
      CupInjury(card: c2, minute: seeded.randomInt(math.min(m1 + 5, 87), 88)),
    );
  }
  return injuries;
}

void _applyInjury(Map<String, dynamic> state, CupInjury entry) {
  if (entry.applied) return;
  entry.applied = true;
  final card = entry.card;
  entry.name = getCardName(card.raw, 'A player');
  card.raw['injured'] = true;
  card.raw['injuredAt'] = now();
  card.raw['injuryDurationMs'] = getInjuryDuration(card.seasonsPlayed);
  // The same as a league game in both modes: vacate the slot, no automatic
  // replacement.
  entry.slot = removeInjuredFromLineup(state, card.instanceId);
  entry.subName = null;
}

/// Commit a cup round with the FINAL result, which can differ from the prepared
/// one when the player changed tactics on the way through.
///
/// Applies the coins, the sponsor drop and the fitness cost, then advances or
/// eliminates. Returns the sponsor drop so the UI can offer it.
/// **The goals are OVERRIDABLE because the screen can change them.** An
/// in-match tactic change re-simulates the remainder and rewrites the result's
/// scoreline in place — `reSimulateRemainder` says so in its own first line —
/// and `PreparedCupRound` is a record, so the figure this was given at kickoff
/// cannot be updated. Without the override the cup's history recorded the
/// pre-match simulation while the player watched a different score: a tie the
/// screen ended 3-1 went into the bracket as 2-1.
///
/// `won` has always been passed separately for the same reason, which is the
/// half that was already right.
CupSponsorDrop? commitCupRound(
  Map<String, dynamic> state,
  bool won,
  PreparedCupRound? prepared, {
  int? homeGoals,
  int? awayGoals,
}) {
  final cups = _ensureCupState(state);
  final run = _map(cups['active']);
  if (run == null || prepared == null) return null;
  final cup = getCupById(prepared.cupId);
  if (cup == null) return null;

  // Recalculated from the ACTUAL outcome: the prepared figure came from the
  // pre-popup simulation and would be wrong if a tactic change turned a
  // simulated win into a defeat, or the other way about.
  final actualEarned = _roundPrize(state, cup, prepared.round, won);
  final resources = _branch(state, 'resources');
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + actualEarned;
  // The same omission the league fee had — see `applyMatchRewards`. A round
  // prize was credited in silence, so nothing flew to the counter and the
  // lifetime high-water mark `game_wiring` keeps never counted a cup run.
  if (actualEarned > 0) emit('coins:updated', resources['fanCoins']);

  _chargeCupFitness(state, prepared);

  final sponsorDrop = won
      ? _rollCupSponsorDrop(state, prepared.round, cup.rounds.length)
      : null;

  final result = <String, dynamic>{
    'round': prepared.round,
    'roundName': prepared.roundName,
    'opponentName': prepared.opponentName,
    'won': won,
    'homeGoals': homeGoals ?? prepared.homeGoals,
    'awayGoals': awayGoals ?? prepared.awayGoals,
    'earned': prepared.earned,
    // Stored as a plain map, not the record: this result goes into the cup
    // history, which is part of the save, and a record cannot be serialised.
    'sponsorDrop': sponsorDrop == null ? null : _dropToMap(sponsorDrop),
    'squadRating': prepared.squadRating,
    'opponentRating': prepared.opponentRating,
    'isFinal': prepared.isFinal,
  };
  _list(run, 'results').add(result);
  _branch(state, 'progression')['lastMatchAt'] = now();

  emit('cup:round-complete', {'cupId': cup.id, 'result': result});
  if (sponsorDrop != null) emit('cup:sponsor-drop', sponsorDrop);

  final season = _num(_map(state['progression'])?['seasonCount'])?.toInt() ?? 1;

  if (!won) {
    _list(cups, 'history').add(<String, dynamic>{
      'cupId': cup.id,
      'season': season,
      'run': cupRun(state),
      'outcome': 'eliminated',
      'roundReached': prepared.round,
      'opponents': [...(run['opponents'] as List? ?? const [])],
      'results': [...(run['results'] as List? ?? const [])],
      'endedAt': now(),
    });
    cups['active'] = null;
    emit('cup:eliminated', {'cupId': cup.id, 'round': prepared.round});
    return sponsorDrop;
  }

  run['round'] = (_num(run['round'])?.toInt() ?? 0) + 1;
  if ((_num(run['round'])?.toInt() ?? 0) >= cup.rounds.length) {
    _liftTheTrophy(state, cups, run, cup, season);
  }
  return sponsorDrop;
}

/// Pro mode grinds persistent fitness on a cup tie the same way a league game
/// does, charged by MINUTES PLAYED: an injury victim pays up to their own
/// minute, whoever stands in the vacated slot at full time pays the rest, and
/// everybody else pays the full ninety.
///
/// There is no per-minute simulation in a cup, so the in-match dip doesn't
/// apply here.
void _chargeCupFitness(Map<String, dynamic> state, PreparedCupRound prepared) {
  if (_map(state['settings'])?['hardMode'] != true) return;

  final stratId =
      _map(state['squad'])?['strategyId'] as String? ?? defaultStrategy;
  final tNow = now();
  final victimIds = {for (final inj in prepared.injuries) inj.card.instanceId};

  final minutesByIid = <String, int>{};
  for (final inj in prepared.injuries) {
    minutesByIid[inj.card.instanceId] = inj.minute;
    final slotId = inj.slot?.slotId;
    if (slotId == null) continue;
    for (final s in _lineup(state)) {
      if (s['slotId'] != slotId) continue;
      final filler = s['cardInstanceId'];
      if (filler is String) minutesByIid[filler] = 90 - inj.minute;
    }
  }

  final onIds = <String>{
    for (final s in _lineup(state))
      if (s['cardInstanceId'] case final String id) id,
    // A victim played their own minutes, even though their slot is now empty.
    ...victimIds,
  };

  for (final card in _cells(state)) {
    if (card == null || !onIds.contains(card.instanceId)) continue;
    if (card.injured && !victimIds.contains(card.instanceId)) continue;
    final max = getMaxEnergy(card);
    final cost = persistentMatchCost(
      card,
      (minutesByIid[card.instanceId] ?? 90).toDouble(),
      stratId,
      state,
    );
    card.raw['energy'] = math.max(0, math.min(max, getEnergy(card) - cost));
    card.raw['energyUpdatedAt'] = tNow;
  }
}

void _liftTheTrophy(
  Map<String, dynamic> state,
  Map<String, dynamic> cups,
  Map<String, dynamic> run,
  Cup cup,
  int season,
) {
  _list(cups, 'history').add(<String, dynamic>{
    'cupId': cup.id,
    'season': season,
    'run': cupRun(state),
    'outcome': 'won',
    'roundReached': cup.rounds.length,
    'opponents': [...(run['opponents'] as List? ?? const [])],
    'results': [...(run['results'] as List? ?? const [])],
    'endedAt': now(),
  });

  _list(_branch(state, 'progression'), 'leagueTrophies').add(<String, dynamic>{
    'season': season,
    'division': cup.id,
    'position': 1,
    'cup': true,
    'cupName': cup.name,
  });

  final career = _branch(state, 'careerStats');
  career['leagueWins'] = _num(career['leagueWins'])?.toInt() ?? 0;
  career['cupWins'] = (_num(career['cupWins'])?.toInt() ?? 0) + 1;

  // A permanent record of which cups unlocked a manager look. The trophy
  // cabinet is session-only and wiped by a soft reset, and a cosmetic earned by
  // lifting a trophy has to outlive it.
  final looks = _list(_branch(state, 'club'), 'cupLooksWon');
  if (!looks.contains(cup.id)) looks.add(cup.id);

  // Gems — the earned route to hard currency, and deliberately rare: cups start
  // at Regional League and run at most once a season.
  final gems = awardCupGems(state, cup.id);
  cups['active'] = null;
  emit('cup:won', {'cupId': cup.id, 'cupName': cup.name, 'gems': gems});
}

/// The one-shot path: simulate and commit in a single call.
///
/// The interactive popup uses [prepareCupRound] and [commitCupRound]
/// separately, so a tactic change can still affect the result.
({PreparedCupRound prepared, CupSponsorDrop? sponsorDrop})? playCupRound(
  Map<String, dynamic> state,
) {
  final prepared = prepareCupRound(state);
  if (prepared == null) return null;
  return (
    prepared: prepared,
    sponsorDrop: commitCupRound(state, prepared.won, prepared),
  );
}

Map<String, dynamic>? activeCup(Map<String, dynamic>? state) =>
    _map(_map(_map(state?['progression'])?['cups'])?['active']);

/// How good the club in one round of a run is, and whether that is an estimate.
///
/// **The fixture list had no number for a cup tie at all.** Every league row
/// carries the opponent's rating — it is the column a manager reads down to see
/// where the season gets hard — and the cup rows in the same list carried a
/// round name, a club and nothing else, on the fixtures a player is most likely
/// to be worried about. Reported from the couch.
///
/// Three sources, in the order they become true:
///   • A PLAYED round stores what it was actually played at, jitter and Lucky
///     Boot and all. That is the honest number and it outranks the bracket.
///   • An unplayed round drawn since `startCup` has `opponentMeta` — the real
///     club, pulled out of the pyramid, exactly as [previewCupTie] reads it.
///   • A legacy run drawn before `opponentMeta` existed has neither, so the
///     tie's own `squadRating + bump` is all there is. That is jittered by ±4
///     on a seeded draw at kickoff and this may not draw, so it reports the
///     midpoint the jitter is centred on and flags itself an ESTIMATE.
///
/// The Lucky Boot is deliberately NOT applied to an unplayed round: a schedule
/// says who you are drawn against, and the league rows beside it read
/// `seasonOpponentRatings` raw for the same reason.
({int rating, bool estimated})? cupRoundOpponentRating(
  Map<String, dynamic>? state,
  Map<String, dynamic>? run,
  Cup cup,
  int round,
) {
  if (state == null || run == null || round < 0) return null;

  final results = run['results'];
  final played = (results is List && round < results.length)
      ? _map(results[round])
      : null;
  final actual = _num(played?['opponentRating']);
  if (actual != null) return (rating: actual.round(), estimated: false);

  final metaRaw = run['opponentMeta'];
  final meta = (metaRaw is List && round < metaRaw.length)
      ? _map(metaRaw[round])
      : null;
  final real = _num(meta?['rating']);
  if (real != null) {
    return (rating: math.min(100, math.max(20, real.round())), estimated: false);
  }

  final bump = round < cup.opponentRatingBump.length
      ? cup.opponentRatingBump[round]
      : 10;
  final lineup = _lineup(state);
  final squadRating = computeSquadRating(
    _cells(state),
    lineup: lineup.length == 11 ? lineup : null,
    definitionRatios: _map(state['definitionRatios']) ?? const {},
    fatigue: _map(state['settings'])?['hardMode'] == true,
  );
  return (
    rating: math.min(100, math.max(20, squadRating + bump)),
    estimated: true,
  );
}

List<dynamic> cupHistory(Map<String, dynamic>? state) {
  final history = _map(_map(state?['progression'])?['cups'])?['history'];
  return history is List ? history : const [];
}

/// This season's finished cup run, in full — the bracket it was drawn against
/// and every result it produced.
///
/// **The HISTORY, not the active run.** A run still open has not finished
/// telling its story and one that ended is already filed — the JS's own
/// reasoning, and the reason the season-end page can print a cup line at all.
/// The last matching entry wins: a season can only hold one run, but a save
/// that has been through a migration can hold two rows for it.
///
/// **AND THE WHOLE ROW, because an elimination is not an erasure.** `active` is
/// nulled the moment a run ends and the run is moved here intact — so anything
/// that reads only `activeCup` loses every tie the player actually PLAYED the
/// instant they go out. That is what emptied the cup section of the fixture
/// list, rounds already won included; see `ourCupTiesProvider`. [seasonCupRun]
/// is the same lookup asking a smaller question.
Map<String, dynamic>? seasonCupRunRow(Map<String, dynamic>? state) {
  if (state == null) return null;
  final cup = cupForDivision(state);
  if (cup == null) return null;
  final season = _num(_map(state['progression'])?['seasonCount'])?.toInt() ?? 1;
  // `progression.cups.history`, which is where `_ensureCupState` puts it.
  final rows = _map(_map(state['progression'])?['cups'])?['history'];
  if (rows is! List) return null;
  Map<String, dynamic>? found;
  for (final raw in rows) {
    final h = _map(raw);
    if (h == null) continue;
    if (h['season'] == season && h['cupId'] == cup.id) found = h;
  }
  return found;
}

/// This season's finished cup run, or null when there was not one.
({String cupId, String outcome, int roundReached})? seasonCupRun(
  Map<String, dynamic>? state,
) {
  final found = seasonCupRunRow(state);
  if (found == null) return null;
  return (
    cupId: '${found['cupId']}',
    outcome: '${found['outcome']}',
    roundReached: _num(found['roundReached'])?.toInt() ?? 0,
  );
}
