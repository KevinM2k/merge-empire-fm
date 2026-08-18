/// The event cup, ported from
/// `../merge-empire-fc/src/engine/eventCupEngine.js`.
///
/// It runs alongside the regular cup rather than instead of it: the run lives at
/// `state.events.progress[eventId].cup`, so a player can hold an active league
/// cup AND an active event cup at once.
///
/// The win probability is the league's — `rating^winProbExponent / sum` — so an
/// event tie feels like a league game, minus the draw, which knockout football
/// does not allow. The one real difference is where the ratings come from: your
/// club does not fly out to the International Cup, your chosen NATION does, at
/// its own strength out of `cupConfig.nationRatings`.
///
/// The bracket resolves round by round rather than up front. Only a player who
/// wins sees the next draw, and only their own next tie — the other fifteen
/// nations are simulated in arrears, in [_advanceBracket], as the player
/// advances past them.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/event_engine.dart' show trackEventAction;
import 'package:merge_empire_fc/engine/squad_rating.dart';
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

/// A slot the JS would have read straight off the array. Out of range reads as
/// null rather than throwing, which is what `undefined` did there — a short
/// opponent pool leaves holes in the bracket and the draw carries on.
Object? _at(List<dynamic> arr, int i) =>
    i >= 0 && i < arr.length ? arr[i] : null;

String? _nationAt(List<dynamic> arr, int i) => _at(arr, i) as String?;

String? _winnerOf(List<dynamic> round, int i) =>
    _map(_at(round, i))?['winner'] as String?;

/// Assign into [arr] at [i], growing it with nulls if it is short.
///
/// The opponents list starts one long — only the first tie is known at draw
/// time — and each round writes one past its end.
void _setAt(List<dynamic> arr, int i, Object? value) {
  while (arr.length <= i) {
    arr.add(null);
  }
  arr[i] = value;
}

/// Goal distribution for the side that wins, shared by player ties and the
/// simulated bracket so both read the same.
const List<double> _winnerGoals = [
  0.05,
  0.22,
  0.30,
  0.22,
  0.12,
  0.06,
  0.02,
  0.01,
];

/// And for the side that loses.
const List<double> _loserGoals = [0.35, 0.36, 0.18, 0.08, 0.02, 0.01];

int _pickWeighted(List<double> w) {
  final total = w.fold<double>(0, (s, x) => s + x);
  var r = seeded.random() * total;
  for (var i = 0; i < w.length; i++) {
    r -= w[i];
    if (r <= 0) return i;
  }
  return w.length - 1;
}

/// One bracket tie between two named nations, on the same win-probability
/// formula as a player tie so the rest of the draw feels like the same
/// tournament.
Map<String, dynamic> _simMatch(
  String? n1,
  String? n2,
  Map<String, int> nationRatings,
) {
  final r1 = nationRatings[n1] ?? 70;
  final r2 = nationRatings[n2] ?? 70;
  final a = math.pow(r1, winProbExponent);
  final b = math.pow(r2, winProbExponent);
  final won1 = seeded.random() < a / (a + b);
  final wg = _pickWeighted(_winnerGoals);
  final lg = _pickWeighted(_loserGoals);
  final g1 = won1 ? math.max(1, wg) : lg;
  final g2 = won1 ? math.min(lg, math.max(0, g1 - 1)) : math.max(g1 + 1, wg);
  // A plain map, not a record: this lands in `cup.bracketRounds`, which is part
  // of the save, and a record does not serialise.
  return <String, dynamic>{
    't1': n1,
    't2': n2,
    'g1': g1,
    'g2': g2,
    'winner': won1 ? n1 : n2,
  };
}

bool _isEventActive(Map<String, dynamic>? state, String eventId) {
  final active = _map(state?['events'])?['active'];
  return active is List && active.contains(eventId);
}

Map<String, dynamic> _ensureEventProgress(
  Map<String, dynamic> state,
  String eventId,
) {
  final progressMap = _branch(_branch(state, 'events'), 'progress');
  final existing = _map(progressMap[eventId]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{
    'score': 0,
    'claimedTiers': <dynamic>[],
    'challenges': <String, dynamic>{},
    'cup': null,
    'activatedAt': now(),
  };
  progressMap[eventId] = fresh;
  return fresh;
}

/// Simulate the rest of a round the player has just won, then reveal who they
/// meet next.
///
/// Called from [commitEventCupRound] the moment the player goes through, which
/// is why a losing player never learns the other results: they are not
/// simulated at all.
void _advanceBracket(
  Map<String, dynamic> cup,
  int completedRound,
  Map<String, int> nationRatings,
) {
  final b = cup['bracket'] is List
      ? cup['bracket'] as List<dynamic>
      : <dynamic>[];
  final br = _list(cup, 'bracketRounds');
  final opponents = _list(cup, 'opponents');

  if (completedRound == 0) {
    // Through the R16. Play out the other seven, then reveal the quarter-final.
    final r16 = <dynamic>[
      _simMatch(_nationAt(b, 2), _nationAt(b, 3), nationRatings),
      _simMatch(_nationAt(b, 4), _nationAt(b, 5), nationRatings),
      _simMatch(_nationAt(b, 6), _nationAt(b, 7), nationRatings),
      _simMatch(_nationAt(b, 8), _nationAt(b, 9), nationRatings),
      _simMatch(_nationAt(b, 10), _nationAt(b, 11), nationRatings),
      _simMatch(_nationAt(b, 12), _nationAt(b, 13), nationRatings),
      _simMatch(_nationAt(b, 14), _nationAt(b, 15), nationRatings),
    ];
    _setAt(br, 0, r16);
    _setAt(opponents, 1, _winnerOf(r16, 0)); // the winner of slots 2 v 3
  } else if (completedRound == 1) {
    final r16 = br.isNotEmpty && br[0] is List
        ? br[0] as List<dynamic>
        : <dynamic>[];
    final qf = <dynamic>[
      _simMatch(_winnerOf(r16, 1), _winnerOf(r16, 2), nationRatings),
      _simMatch(_winnerOf(r16, 3), _winnerOf(r16, 4), nationRatings),
      _simMatch(_winnerOf(r16, 5), _winnerOf(r16, 6), nationRatings),
    ];
    _setAt(br, 1, qf);
    _setAt(opponents, 2, _winnerOf(qf, 0)); // the other side of our half
  } else if (completedRound == 2) {
    final qf = br.length > 1 && br[1] is List
        ? br[1] as List<dynamic>
        : <dynamic>[];
    final sf = <dynamic>[
      _simMatch(_winnerOf(qf, 1), _winnerOf(qf, 2), nationRatings),
    ];
    _setAt(br, 2, sf);
    _setAt(opponents, 3, _winnerOf(sf, 0)); // whoever comes out of the far half
  }
}

/// Draw a fresh bracket for an active event cup.
///
/// The player takes slot 0 and fifteen others are shuffled in around them; the
/// nation the player is leading is kept out of the pool so they cannot be drawn
/// against themselves. Returns the run, or null if the event is not live, has
/// no cup, or already has one going.
Map<String, dynamic>? startEventCup(
  Map<String, dynamic> state,
  String eventId, [
  String? playerNation,
]) {
  if (!_isEventActive(state, eventId)) return null;
  final def = getEventById(eventId);
  final cfg = def?.cupConfig;
  if (cfg == null) return null;
  final progress = _ensureEventProgress(state, eventId);
  final existing = _map(progress['cup']);
  if (existing != null &&
      existing['eliminated'] != true &&
      existing['won'] != true) {
    return existing;
  }

  final pool = [
    for (final n in cfg.opponentPool)
      if (n != playerNation) n,
  ];
  final drawn = seeded.shuffle(pool).take(15);
  final bracket = <dynamic>[playerNation, ...drawn];

  final cup = <String, dynamic>{
    'eventId': eventId,
    'playerNation': playerNation,
    'round': 0,
    'bracket': bracket,
    'bracketRounds': <dynamic>[], // filled in as the player wins each round
    'opponents': <dynamic>[
      _nationAt(bracket, 1),
    ], // only the first tie is known
    'results': <dynamic>[],
    'startedAt': now(),
    'eliminated': false,
    'won': false,
  };
  progress['cup'] = cup;
  if (playerNation != null && playerNation.isNotEmpty) {
    progress['lastPickedNation'] = playerNation;
  }
  emit('event:cup-started', {
    'eventId': eventId,
    'opponents': cup['opponents'],
    'playerNation': playerNation,
  });
  return cup;
}

/// The nation the player most recently led at this event, or null.
String? lastPickedNation(Map<String, dynamic>? state, String eventId) =>
    _map(
          _map(_map(_map(state?['events'])?['progress'])?[eventId]),
        )?['lastPickedNation']
        as String?;

/// A simulated but uncommitted event-cup tie.
typedef PreparedEventCupRound = ({
  String eventId,
  int round,
  String roundName,
  String? opponentName,
  bool won,
  int homeGoals,
  int awayGoals,
  int earned,
  num squadRating,
  num opponentRating,
  bool isFinal,
});

/// Simulate the current round without committing it.
///
/// The split exists for the match popup, which can still flip the result when
/// the player changes strategy mid-tie. Unlike the league cup there is nothing
/// to spend up front: club-side items do not carry into the event cup, so this
/// has no side effects at all.
PreparedEventCupRound? prepareEventCupRound(
  Map<String, dynamic> state,
  String eventId,
) {
  if (!_isEventActive(state, eventId)) return null;
  final def = getEventById(eventId);
  final cfg = def?.cupConfig;
  if (cfg == null) return null;
  final progress = _ensureEventProgress(state, eventId);
  final cup = _map(progress['cup']);
  if (cup == null || cup['eliminated'] == true || cup['won'] == true) {
    return null;
  }

  final round = _num(cup['round'])?.toInt() ?? 0;
  if (round >= cfg.rounds.length) return null;

  final opponents = cup['opponents'];
  final opponentName = opponents is List ? _nationAt(opponents, round) : null;

  // Ratings come from the NATIONS, not the club squad — you are not managing
  // your club here. A player who skipped the picker (a legacy run) falls back
  // to their squad rating so the arithmetic still has something to work with.
  //
  // Club-side items such as the Lucky Boot deliberately do NOT apply: the event
  // cup is its own tournament, and carrying items in would also make the
  // underdog achievement meaningless.
  final ratings = cfg.nationRatings;
  final cells = [
    for (final c in (_map(state['grid'])?['cells'] as List? ?? const []))
      CardInstance.from(c),
  ];
  final fallbackSquadRating = computeSquadRating(cells);
  final playerNation = cup['playerNation'] as String?;
  final leadingANation = playerNation != null && playerNation.isNotEmpty;
  final num ourRating = leadingANation
      ? (ratings[playerNation] ?? 70)
      : fallbackSquadRating;
  final num opponentRating = ratings[opponentName] ?? 70;

  final a = math.pow(math.max(1, ourRating), winProbExponent);
  final b = math.pow(math.max(1, opponentRating), winProbExponent);
  final won = seeded.random() < a / (a + b);

  final winnerGoals = _pickWeighted(_winnerGoals);
  final loserGoals = _pickWeighted(_loserGoals);
  final homeGoals = won ? math.max(1, winnerGoals) : loserGoals;
  final awayGoals = won
      ? math.min(loserGoals, math.max(0, homeGoals - 1))
      : math.max(homeGoals + 1, winnerGoals);

  return (
    eventId: eventId,
    round: round,
    roundName: cfg.rounds[round],
    opponentName: opponentName,
    won: won,
    homeGoals: homeGoals,
    awayGoals: awayGoals,
    // Nothing is paid per round. The whole purse rides on lifting the trophy,
    // and [commitEventCupRound] applies it when the final round flips `won`.
    earned: 0,
    squadRating: ourRating,
    opponentRating: opponentRating,
    isFinal: round == cfg.rounds.length - 1,
  );
}

/// Commit a prepared tie on the popup's final [won], which can differ from
/// `prepared.won` when the player swapped strategy mid-match.
///
/// Returns the result that was pushed onto the run, or null if there was
/// nothing to commit.
Map<String, dynamic>? commitEventCupRound(
  Map<String, dynamic> state,
  String eventId,
  bool won,
  PreparedEventCupRound? prepared,
) {
  if (prepared == null) return null;
  final def = getEventById(eventId);
  final cfg = def?.cupConfig;
  if (cfg == null) return null;
  final progress = _ensureEventProgress(state, eventId);
  final cup = _map(progress['cup']);
  if (cup == null || cup['eliminated'] == true || cup['won'] == true) {
    return null;
  }

  final resources = _branch(state, 'resources');
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + prepared.earned;

  final result = <String, dynamic>{
    'round': prepared.round,
    'roundName': prepared.roundName,
    'opponentName': prepared.opponentName,
    'won': won,
    'homeGoals': prepared.homeGoals,
    'awayGoals': prepared.awayGoals,
    'earned': prepared.earned,
    'squadRating': prepared.squadRating,
    'opponentRating': prepared.opponentRating,
    'isFinal': prepared.isFinal,
  };
  _list(cup, 'results').add(result);
  _branch(state, 'progression')['lastMatchAt'] = now();

  emit('event:cup-round-complete', {'eventId': eventId, 'result': result});
  emit('coins:updated', resources['fanCoins']);

  if (!won) {
    cup['eliminated'] = true;
    emit('event:cup-eliminated', {'eventId': eventId, 'round': prepared.round});
    return result;
  }

  trackEventAction(state, 'event_cup_round', 1);

  // Play out the rest of this round and reveal the next opponent before
  // advancing — but not after the Final, which has nobody left to reveal.
  final completedRound = _num(cup['round'])?.toInt() ?? 0;
  if (completedRound < cfg.rounds.length - 1) {
    _advanceBracket(cup, completedRound, cfg.nationRatings);
  }

  cup['round'] = completedRound + 1;
  if (completedRound + 1 < cfg.rounds.length) return result;

  cup['won'] = true;
  trackEventAction(state, 'event_cup_won', 1);

  // The prize is first-win-only. A later run that lifts the trophy again is
  // still celebrated — `cup.won` stays true so the UI can say so — but the
  // money and the trophy are not handed out twice.
  final progression = _branch(state, 'progression');
  final trophies = _list(progression, 'leagueTrophies');
  final alreadyWon = trophies.any((t) {
    final trophy = _map(t);
    return trophy?['event'] == true && trophy?['eventId'] == eventId;
  });

  // The conditional win actions fire BEFORE that gate, so the count-based
  // challenges keep accruing on repeat wins and a condition met for the first
  // time on a later run still unlocks.
  //
  // Underdog and favourite are strict: the single worst- and best-rated nation
  // in the catalogue, derived from the table rather than written down, so they
  // follow a ratings change on their own.
  final playerNation = cup['playerNation'] as String?;
  String? bestNation;
  String? worstNation;
  num bestRating = double.negativeInfinity;
  num worstRating = double.infinity;
  for (final entry in cfg.nationRatings.entries) {
    if (entry.value > bestRating) {
      bestRating = entry.value;
      bestNation = entry.key;
    }
    if (entry.value < worstRating) {
      worstRating = entry.value;
      worstNation = entry.key;
    }
  }
  final leadingANation = playerNation != null && playerNation.isNotEmpty;
  if (leadingANation && playerNation == worstNation) {
    trackEventAction(state, 'event_cup_won_underdog', 1);
  }
  if (leadingANation && playerNation == bestNation) {
    trackEventAction(state, 'event_cup_won_favourite', 1);
  }
  // A clean run is nothing conceded across the WHOLE bracket, not one tie.
  final concededAny = (cup['results'] as List? ?? const []).any(
    (r) => (_num(_map(r)?['awayGoals']) ?? 0) > 0,
  );
  if (!concededAny) trackEventAction(state, 'event_cup_won_clean', 1);

  // Pin the nation of the first win so the achievement detail can still show it
  // after the player wins again with somebody else.
  if (_map(progress['firstWin']) == null) {
    progress['firstWin'] = <String, dynamic>{
      'playerNation': playerNation,
      'wonAt': now(),
    };
  }

  if (alreadyWon) {
    // Flagged clearly so the UI shows "champions again" rather than staging a
    // fresh-prize celebration.
    result['earned'] = 0;
    emit('event:cup-won', {
      'eventId': eventId,
      'name': def?.name,
      'playerNation': playerNation,
      'bounty': 0,
      'firstWin': false,
    });
    return result;
  }

  // The bounty scales with the player's division so it stays worth winning at
  // every stage: about 3,000 coins at Sunday League, about 3.6M at Champions.
  final div = getDivision('${progression['currentDivision']}');
  final winBounty = roundCoins(div.matchRevenueBase * cfg.winBountyMult);
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + winBounty;
  result['earned'] = winBounty;
  emit('coins:updated', resources['fanCoins']);

  // No trophy card is pushed. Events surface as achievements now, and
  // `leagueTrophies` is left alone so the trophy room does not double up with
  // the achievement tile.
  emit('event:cup-won', {
    'eventId': eventId,
    'name': def?.name,
    'playerNation': playerNation,
    'bounty': winBounty,
    'firstWin': true,
  });
  return result;
}

/// Prepare and commit in one call. The UI drives the two halves separately so
/// the popup can animate between them; everything else uses this.
Map<String, dynamic>? playEventCupRound(
  Map<String, dynamic> state,
  String eventId,
) {
  final prepared = prepareEventCupRound(state, eventId);
  if (prepared == null) return null;
  return commitEventCupRound(state, eventId, prepared.won, prepared);
}

/// Which nation a restart runs with.
///
/// The JS leans on three distinct arguments — absent, a name, and `''` — and
/// Dart has no `undefined`, so the three become cases.
sealed class RestartNation {
  const RestartNation();
}

/// Reuse the nation the last run was played with: the one-tap "go again".
class LastNation extends RestartNation {
  const LastNation();
}

/// Lead [name] on the new run. A null name is the legacy nation-less run, which
/// falls back to the club's squad rating.
class PickedNation extends RestartNation {
  const PickedNation(this.name);

  final String? name;
}

/// Clear the run and do NOT restart, so the picker surfaces again.
class ShowNationPicker extends RestartNation {
  const ShowNationPicker();
}

/// Clear the bracket so the player can take another run, and start the next one
/// unless the picker was asked for.
///
/// Only allowed once the previous attempt is over — events are not
/// single-attempt, but they are not restartable mid-run either. The old run is
/// pushed onto `progress.cupHistory` so the screen can still show it.
Map<String, dynamic>? restartEventCup(
  Map<String, dynamic> state,
  String eventId, [
  RestartNation nation = const LastNation(),
]) {
  if (!_isEventActive(state, eventId)) return null;
  final progress = _ensureEventProgress(state, eventId);
  final old = _map(progress['cup']);
  if (old != null && old['eliminated'] != true && old['won'] != true) {
    return null;
  }
  if (old != null) _list(progress, 'cupHistory').add(old);
  progress['cup'] = null;
  emit('event:cup-restart', {'eventId': eventId});

  if (nation is ShowNationPicker) return null;
  final remembered =
      (old?['playerNation'] as String?) ??
      progress['lastPickedNation'] as String?;
  final next = nation is PickedNation ? nation.name : remembered;
  return startEventCup(state, eventId, next);
}

/// The run in progress at this event, or null.
Map<String, dynamic>? activeEventCup(
  Map<String, dynamic>? state,
  String eventId,
) => _map(_map(_map(_map(state?['events'])?['progress'])?[eventId])?['cup']);
