/// The ninety minutes, end to end: the outer half of
/// `../merge-empire-fc/src/engine/matchEngine.js`.
///
/// The arithmetic underneath this lives in five already-ported files —
/// `squad_rating`, `match_tactics`, `goal_model`, `match_events` and
/// `match_resolution`. What is left here is the FLOW: assembling both sides'
/// ratings from the save, deciding the injuries before the sim so a skipped
/// match costs the same as a watched one, running either the one-shot casual sim
/// or the Pro-mode per-segment one, building the feed every screen reads, and
/// settling the result into the save afterwards.
///
/// ── The draw order is the specification ───────────────────────────────────
/// Nearly every bug this file has ever had was an ORDERING bug, not a formula
/// one. It draws, in this exact sequence: the opponent's rating (only if unrolled),
/// the first injury's victim, that roll, its minute, the second victim, that roll,
/// its minute, the tactic's swing, the AI rotation plan, then the goals, then the
/// whole event feed. Move any of them and every later number changes.
///
/// It also mixes the two generators. The seeded stream carries gameplay; bare
/// `Math.random` carries team attribution in the feed and the per-match save and
/// tackle counts. That split is preserved rather than tidied — see the header of
/// `match_events.dart` — so [setMatchRandom] exists to make the unseeded half
/// reproducible in a test without pretending it is seeded.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/transfer_market.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/loan_engine.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/engine/tactic_coach.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/sorting.dart';
import 'package:merge_empire_fc/util/time.dart';

/// A match result, as the simulation writes it.
///
/// A raw map for the same reason the save is: it crosses the sim, the match
/// screen and the quest engine, and each of them adds fields the others don't
/// read. Nothing stored on it may be a Dart record — a cup win puts a result
/// into the save, and a record would throw on the first `jsonEncode` after it.
typedef MatchResult = Map<String, dynamic>;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;
bool _flag(Object? v) => v == true;

/// JS `Math.round`: halves go up, not to even.
int _jsRound(num v) => (v + 0.5).floor();

/// The unseeded generator, matching bare `Math.random` in the JS.
math.Random _rng = math.Random();

/// Replaces the unseeded stream. A test pins it to make the feed reproducible;
/// nothing in the app calls it.
void setMatchRandom(math.Random rng) => _rng = rng;

void resetMatchRandom() => _rng = math.Random();

/// Opponent fatigue in Pro mode: both teams tire.
///
/// The AI has no real squad, so its rating decays a fixed amount across the
/// match rather than tracking eleven cards. By full time it is at this share of
/// its starting strength.
const double oppEndFatigue = 0.90;

const int _vipCooldownMs = 10 * 1000;

// ── the Pro-mode segment simulation ──────────────────────────────────────────

/// What a Pro-mode simulation produced.
typedef HardSim = ({
  int homeGoals,
  int awayGoals,
  List<Map<String, dynamic>> segments,
  Map<String, double> startEnergy,
  Map<String, double> minutesPlayed,
  int ourKickoffAtk,
  int ourKickoffDef,
});

/// An injury the simulation has already decided on: who, and when.
typedef PlannedInjury = ({String iid, int minute});

/// One AI substitution: fresh legs, at a minute, worth a small lift.
typedef OppSub = ({int minute, double boostPct});

/// A slot on the pitch, or the hole where one should be.
class _SlotEntry {
  const _SlotEntry(this.card, this.slotPos);
  final CardInstance? card;
  final String slotPos;
}

/// Pro-mode goal simulation with per-player fatigue.
///
/// Splits the match into equal segments; each one recomputes OUR ATK/DEF from
/// the live on-pitch energies (fitness scales a player's whole rating), samples
/// that segment's goals, then drains whoever was on the pitch — so late segments
/// are weaker as the team tires. The opponent decays on a fixed curve, partly
/// offset by its own substitutions.
///
/// Operates on a throwaway energy map representing the TEMPORARY in-match dip.
/// It never mutates a card and is never persisted — the dip rests off at full
/// time. `minutesPlayed` comes back so the caller can charge the small
/// PERSISTENT fitness cost instead.
HardSim _simulateHardGoals({
  required List<CardInstance> cards,
  required List<Map<String, dynamic>> lineup,
  Map<String, dynamic> definitionRatios = const {},
  required String strategyId,
  Map<String, dynamic>? state,
  int ourHomeAdv = 0,
  double stagnation = 0,
  double releg = 0,
  required double oppAttack,
  required double oppDefence,
  double? oppAttackRatio,
  double variance = 1.0,
  List<PlannedInjury> injuries = const [],
  List<OppSub> oppSubs = const [],
}) {
  const seg = PlayerEnergy.segments;
  const minutesPerSeg = 90 / seg;
  final strat = strategies[strategyId] ?? strategies[defaultStrategy];
  final byId = {for (final c in cards) c.instanceId: c};

  // Slot-indexed, so an empty or already-injured slot keeps its place: the team
  // split is always taken over the WHOLE formation, and a hole costs its
  // position's weight rather than quietly shrinking the denominator.
  final bySlot = [
    for (final s in lineup)
      () {
        final iid = s['cardInstanceId'];
        final c = iid is String ? byId[iid] : null;
        final slotPos = s['slotPosition'] as String? ?? 'MID';
        return (c == null || c.injured)
            ? _SlotEntry(null, slotPos)
            : _SlotEntry(c, slotPos);
      }(),
  ];
  final onPitch = [
    for (final e in bySlot)
      if (e.card != null) e,
  ];

  final energy = <String, double>{};
  for (final e in onPitch) {
    energy[e.card!.instanceId] = getEnergy(e.card);
  }
  final startEnergy = Map<String, double>.of(energy);

  // Minutes each starter plays — the full ninety unless this match's injury
  // takes them off early, or a sub changes it later in [hardLiveRatings].
  final minutesPlayed = <String, double>{};
  for (final e in onPitch) {
    minutesPlayed[e.card!.instanceId] = 90;
  }
  final injuryByIid = {for (final inj in injuries) inj.iid: inj};
  for (final inj in injuryByIid.values) {
    if (minutesPlayed[inj.iid] != null) {
      minutesPlayed[inj.iid] = inj.minute.toDouble();
    }
  }

  // A victim's contribution and drain are prorated by how much of each segment
  // they actually play: full weight before their minute, partial in the segment
  // it lands in, zero after.
  double weightAt(CardInstance card, int segIdx) {
    final inj = injuryByIid[card.instanceId];
    if (inj == null) return 1;
    return math.max(
      0.0,
      math.min(1.0, (inj.minute - segIdx * minutesPerSeg) / minutesPerSeg),
    );
  }

  TeamSplit splitNow(({double scale, double weight}) Function(CardInstance) at) =>
      weightedTeamSplit([
        for (final e in bySlot)
          if (e.card == null)
            SplitEntry(slotPosition: e.slotPos, weight: 0)
          else
            () {
              final st = getCardStats(
                e.card,
                slotPosition: e.slotPos,
                definitionRatios: definitionRatios,
              );
              final s = at(e.card!);
              return SplitEntry(
                slotPosition: e.slotPos,
                attack: st.attack * s.scale,
                defence: st.defence * s.scale,
                weight: s.weight,
              );
            }(),
      ]);

  // Kickoff ATK/DEF drive positional drain: their attack against our defence
  // loads defenders, ours against theirs loads forwards. Position-weighted, so
  // these sit on the same scale as the opponent's numbers and as the badge the
  // player was shown before kickoff.
  final kickoff = splitNow((_) => (scale: 1, weight: 1));
  final matchup = (
    ourAtk: kickoff.attack.toDouble(),
    ourDef: kickoff.defence.toDouble(),
    oppAtk: oppAttack,
    oppDef: oppDefence,
  );

  final segments = <Map<String, dynamic>>[];
  var homeGoals = 0;
  var awayGoals = 0;
  for (var s = 0; s < seg; s++) {
    final segSplit = splitNow((card) {
      final max = getMaxEnergy(card);
      final pct = max > 0
          ? math.max(0.0, (energy[card.instanceId] ?? max) / max)
          : 0.0;
      return (scale: fatigueRatingFactor(pct), weight: weightAt(card, s));
    });
    final adjAtk = math.max(
      1.0,
      applyTacticAtk(
        math.min(segSplit.attack + ourHomeAdv, 100) + stagnation + releg,
        strat,
        oppAttackRatio,
      ),
    );
    final adjDef = math.max(
      1.0,
      applyTacticDef(
        math.min(segSplit.defence + ourHomeAdv, 100) + stagnation + releg,
        strat,
        oppAttackRatio,
      ),
    );
    final oppFactor = 1 - (1 - oppEndFatigue) * (s / math.max(1, seg - 1));
    // Substitutions already made by this segment lift the opponent's rating,
    // partly offsetting the fatigue decay above.
    var oppSubBoost = 1.0;
    for (final sub in oppSubs) {
      if (sub.minute <= s * minutesPerSeg) oppSubBoost *= 1 + sub.boostPct;
    }
    final segOppAtk = math.max(1.0, oppAttack * oppFactor * oppSubBoost);
    final segOppDef = math.max(1.0, oppDefence * oppFactor * oppSubBoost);

    const segFrac = 1 / seg;
    final h = poissonGoals(goalRateLambda(adjAtk, segOppDef) * segFrac * variance);
    final a = poissonGoals(goalRateLambda(segOppAtk, adjDef) * segFrac * variance);
    homeGoals += h;
    awayGoals += a;
    segments.add({
      'seg': s,
      'atk': _jsRound(adjAtk),
      'def': _jsRound(adjDef),
      'home': h,
      'away': a,
    });

    for (final e in onPitch) {
      final card = e.card!;
      final w = weightAt(card, s);
      if (w <= 0) continue;
      final d = drainForMinutes(
        card,
        minutesPerSeg * w,
        strategyId,
        state,
        matchup,
      );
      energy[card.instanceId] = math.max(
        0.0,
        (energy[card.instanceId] ?? getMaxEnergy(card)) - d,
      );
    }
  }

  return (
    homeGoals: homeGoals,
    awayGoals: awayGoals,
    segments: segments,
    startEnergy: startEnergy,
    minutesPlayed: minutesPlayed,
    ourKickoffAtk: kickoff.attack,
    ourKickoffDef: kickoff.defence,
  );
}

/// Pro-mode live team ratings partway through a match, for a tactic change or a
/// substitution.
///
/// Computes each on-pitch player's in-match DIP at [fromMinute] — a freshly
/// subbed-on player, who was not in `startEnergy`, enters at their current
/// rested fitness with no dip — scales their ATK/DEF by the dipped fitness, and
/// takes the position-weighted team split the badge and the opponent are on.
///
/// Side effect: rebuilds `hardSim.minutesPlayed` for the new lineup, so the
/// persistent fitness cost charged at full time reflects who actually played and
/// for how long. The dip itself is never persisted.
TeamSplit hardLiveRatings(
  MatchResult result,
  int fromMinute,
  Map<String, dynamic>? state,
  String? strategyId, {
  /// The referee's, by instance id — see [reSimulateRemainder]. Pro mode prices
  /// every man's fitness individually, so a caution belongs beside the fatigue
  /// factor rather than on the team total after it.
  Map<String, double> bookedMultipliers = const {},
}) {
  final hs = _map(result['hardSim']) ?? <String, dynamic>{};
  final cards = _cards(state);
  final byId = {for (final c in cards) c.instanceId: c};
  final lineup = _lineupOf(state) ?? const <Map<String, dynamic>>[];
  final ratios = _map(state?['definitionRatios']) ?? const {};
  final remainMin = math.max(0, 90 - fromMinute).toDouble();
  final startEnergy = _map(hs['startEnergy']) ?? <String, dynamic>{};
  final matchup = (
    ourAtk: (_num(hs['ourKickoffAtk']) ?? 0).toDouble(),
    ourDef: (_num(hs['ourKickoffDef']) ?? 0).toDouble(),
    oppAtk: (_num(hs['oppAttack']) ?? 0).toDouble(),
    oppDef: (_num(hs['oppDefence']) ?? 0).toDouble(),
  );

  // Drain follows the strategy TIMELINE — switching tactics must never reprice
  // fatigue already accrued under the previous one.
  final rawLog = hs['stratLog'];
  final log = <StrategyLogEntry>[
    if (rawLog is List && rawLog.isNotEmpty)
      for (final e in rawLog.whereType<Map<String, dynamic>>())
        (min: (_num(e['min']) ?? 0).toDouble(), id: '${e['id']}')
    else
      (min: 0, id: strategyId ?? defaultStrategy),
  ];

  // One entry per formation slot: an unfilled slot keeps its position weight in
  // the denominator, so a short-handed side reads weaker.
  final entries = [
    for (final slot in lineup)
      SplitEntry(
        slotPosition: slot['slotPosition'] as String? ?? 'MID',
        weight: 0,
      ),
  ];
  final onIds = <String>{};

  double liveFitness(CardInstance c, String iid) {
    final stored = _num(startEnergy[iid]);
    return stored != null
        ? math.max(
            0.0,
            stored - drainForStrategyLog(c, log, fromMinute.toDouble(), 0, state, matchup),
          )
        : getEnergy(c);
  }

  for (var i = 0; i < lineup.length; i++) {
    final iid = lineup[i]['cardInstanceId'];
    if (iid is! String) continue;
    final c = byId[iid];
    if (c == null || c.injured) continue;
    onIds.add(iid);
    final max = getMaxEnergy(c);
    final e = liveFitness(c, iid);
    final fat = fatigueRatingFactor(max > 0 ? e / max : 0);
    final st = getCardStats(
      c,
      slotPosition: lineup[i]['slotPosition'] as String?,
      definitionRatios: ratios,
    );
    final booked = bookedMultipliers[iid] ?? 1.0;
    entries[i] = SplitEntry(
      slotPosition: lineup[i]['slotPosition'] as String? ?? 'MID',
      attack: st.attack * fat * booked,
      defence: st.defence * fat * booked,
    );
  }

  // This match's injury victims: rolled at sim time — flagged, and their slots
  // vacated immediately — but each injury HAPPENS at its event minute. Keep them
  // on the pitch until then, or the badge drops men from kickoff. Skipped once
  // the manager has filled the vacated slots, since eleven are already counted.
  final hsInjuries = _hardSimInjuries(hs);
  var filledSlots = lineup.where((s) => s['cardInstanceId'] != null).length;
  for (final inj in hsInjuries) {
    final iid = '${inj['iid']}';
    final minute = _num(inj['minute']) ?? 0;
    if (!(fromMinute < minute) || filledSlots >= 11 || onIds.contains(iid)) {
      continue;
    }
    final c = byId[iid];
    if (c == null) continue;
    final max = getMaxEnergy(c);
    final fat = fatigueRatingFactor(max > 0 ? liveFitness(c, iid) / max : 0);
    final st = getCardStats(
      c,
      slotPosition: inj['slotPosition'] as String?,
      definitionRatios: ratios,
    );
    // Put them back in the first free slot, standing in their own position —
    // that slot's weight is already in the denominator, so this fills it rather
    // than adding a twelfth man.
    final free = entries.indexWhere((en) => en.weight == 0);
    if (free < 0) continue;
    entries[free] = SplitEntry(
      slotPosition: inj['slotPosition'] as String? ?? entries[free].slotPosition,
      attack: st.attack * fat,
      defence: st.defence * fat,
    );
    filledSlots++;
  }

  // Rebuild minutesPlayed: a starter still on plays the full ninety, a subbed-on
  // player the remaining minutes, and a kickoff starter no longer on — subbed
  // off or injured — is charged only up to fromMinute.
  final minutesPlayed = Map<String, dynamic>.of(
    _map(hs['minutesPlayed']) ?? const {},
  );
  for (final iid in onIds) {
    minutesPlayed[iid] = startEnergy[iid] != null ? 90 : remainMin;
  }
  for (final iid in startEnergy.keys) {
    if (!onIds.contains(iid)) minutesPlayed[iid] = fromMinute;
  }
  // A victim's exit minute is fixed by the injury, not by when the manager
  // happened to change tactics.
  for (final inj in hsInjuries) {
    final iid = '${inj['iid']}';
    if (!onIds.contains(iid) && startEnergy[iid] != null) {
      minutesPlayed[iid] = inj['minute'];
    }
  }
  hs['minutesPlayed'] = minutesPlayed;

  return weightedTeamSplit(entries);
}

// ── the shape that wins the next fixture ─────────────────────────────────────

/// A formation, the XI to play in it, and what it is worth.
typedef FormationPick = ({
  String formationId,
  List<LineupSlot> lineup,
  double points,
});

/// The formation that actually wins the next fixture, with the XI for it.
///
/// The lineup builder's own scoring answers "which shape fits my best players",
/// which is not the question: the sim runs on position-weighted ATK/DEF against
/// a specific opponent, so the shape that fields the highest total can easily be
/// the one that loses. A 4-3-3 packed with forwards outscores a 4-4-2 on raw
/// total while reading far weaker at the back, and nothing in that scoring
/// notices.
///
/// Scored here on expected league points against the fixture in front of you,
/// through the same goal model the match will use — so "best" means best at
/// winning THIS game. Ties break toward the shape already set, because a change
/// the manager didn't ask for should have to earn itself.
/// [banned] is passed by the Auto button so a suspended man is not picked; it
/// defaults empty, which is what the JS does and what the fixtures compare.
FormationPick bestFormationForFixture(
  Map<String, dynamic>? state, {
  String? divisionId,
  Set<String> banned = const {},
}) {
  final cells = _cells(state);
  final ratios = _map(state?['definitionRatios']) ?? const {};
  final squad = _map(state?['squad']);
  final currentFormation = squad?['formation'] as String? ?? defaultFormation;
  final strat = strategies[squad?['strategyId'] ?? defaultStrategy] ??
      strategies[defaultStrategy];

  final div = getDivision(
    '${divisionId ?? _map(state?['progression'])?['currentDivision']}',
  );
  final preview = previewFixture(state, divisionId);
  // An opponent nobody has played has no rating on the save. The division
  // midpoint is the same estimate the fixture list shows, and it keeps the
  // ranking honest rather than silently scoring against a zero-rated side.
  final midRating =
      _jsRound((div.opponentRatingRange.$1 + div.opponentRatingRange.$2) / 2);
  final fallback = opponentAtkDefFromShare(midRating, oppBaseAtkShare);
  final oppAtk = preview?.effOppAttackRating ?? fallback.attack;
  final oppDef = preview?.effOppDefenceRating ?? fallback.defence;
  final ourHomeAdv = (preview?.isHome ?? false)
      ? homeAdvantageFor(fanZoneTier(_map(state?['clubAssets'])))
      : 0;

  // The incumbent is scored first, so the strictly-greater test below leaves it
  // in place on an exact tie.
  final candidates = [
    if (formations.containsKey(currentFormation)) currentFormation,
    for (final f in formations.keys)
      if (f != currentFormation) f,
  ];

  FormationPick? best;
  for (final formationId in candidates) {
    final lineup = buildDefaultLineup(formationId, cells, banned: banned);
    final split = computeSquadRatings(
      cells,
      lineup: [for (final s in lineup) _slotMap(s)],
      definitionRatios: ratios,
    );
    final points = tacticExpectedPoints(
      split.attack + ourHomeAdv,
      split.defence + ourHomeAdv,
      oppAtk,
      oppDef,
      strat,
      oppAttackRatio: preview?.oppAttackRatio,
    );
    if (best == null || points > best.points + 1e-9) {
      best = (formationId: formationId, lineup: lineup, points: points);
    }
  }
  return best ??
      (
        formationId: currentFormation,
        lineup: buildDefaultLineup(currentFormation, cells),
        points: 0,
      );
}

// ── the match ────────────────────────────────────────────────────────────────

/// An injury this match will produce, and the bookkeeping it leaves behind.
class _Injury {
  _Injury(this.card, this.minute);

  final CardInstance card;
  final int minute;

  String? name;
  bool applied = false;
  String? prevSlotId;
  String? replacedBy;
  VacatedSlot? slot;
}

/// Plays the whole ninety minutes and writes the result the screens read.
///
/// Mutates [state]: it seeds the opponent's rating on first meeting, spends the
/// Lucky Boot and the grudge, flags the injured, vacates their lineup slots, and
/// advances the match counters. Coins, the win/draw/loss counters and per-player
/// form are NOT applied here — see [finalizeMatchOutcome].
MatchResult simulateMatch(
  Map<String, dynamic> state,
  String? divisionId, {
  bool forceWin = false,
}) {
  final prog = state['progression'] as Map<String, dynamic>;
  final div = getDivision('${divisionId ?? prog['currentDivision']}');
  final lineup = _lineupOf(state);
  final squad = _map(state['squad']);
  final ratios = _map(state['definitionRatios']) ?? const {};

  // Pro mode folds persistent-fitness fatigue into these so they match the squad
  // screen, the pre-match preview AND the live in-match badge at kickoff — the
  // live badge applies fatigue from minute zero, so an unfatigued base here
  // would make the rating visibly drop the instant the match starts.
  final fatigue = _flag(_map(state['settings'])?['hardMode']);
  final cells = _cells(state);
  final baseRating = computeSquadRating(
    cells,
    lineup: lineup,
    definitionRatios: ratios,
    fatigue: fatigue,
  );
  final baseRatings = computeSquadRatings(
    cells,
    lineup: lineup,
    definitionRatios: ratios,
    fatigue: fatigue,
  );

  // Hidden per-division stagnation buff, in the lower leagues only. The
  // Champions League has no promotion to escape by, so it would accumulate
  // indefinitely and invisibly inflate results.
  final currentDiv = '${prog['currentDivision']}';
  final stagnationBuff = currentDiv == 'champions_cup'
      ? 0
      : _num(_map(prog['stagnationBuffs'])?[currentDiv])?.toInt() ?? 0;

  final matchNum = _num(prog['seasonMatchesPlayed'])?.toInt() ?? 0;
  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  final opponents = prog['seasonOpponents'];
  final oppIdx = matchNum % opponentsPerSeason;
  final isHome = fixtureIsHome(season, oppIdx, matchNum);
  final opponentName = (opponents is List && oppIdx < opponents.length)
      ? '${opponents[oppIdx]}'
      : 'Opponent';

  // Deterministic per opponent per season, and rolled here on first meeting.
  final ratingsByKey = _map(prog['seasonOpponentRatings']) ??
      (prog['seasonOpponentRatings'] = <String, dynamic>{});
  final oppRatingKey = 's${season}_o$oppIdx';
  if (ratingsByKey[oppRatingKey] == null) {
    ratingsByKey[oppRatingKey] = seeded.randomInt(
      div.opponentRatingRange.$1,
      div.opponentRatingRange.$2,
    );
  }
  var opponentRating = math.min(100, _num(ratingsByKey[oppRatingKey])!);

  // The boot lands on the overall rating BEFORE ATK/DEF are split from it, so
  // both are lowered proportionally.
  final shop = _map(state['shop']);
  if (_flag(shop?['luckyBootReady'])) {
    opponentRating = applyLuckyBoot(opponentRating);
    shop!['luckyBootReady'] = false;
  }

  final tablePos = _num(_map(prog['opponentTablePositions'])?[opponentName]);
  final secondHalf = matchNum >= opponentsPerSeason;
  final oppInRelegationZone = secondHalf && tablePos != null && tablePos >= 7;
  final playerTablePos = _num(prog['playerTablePosition']);
  // Sunday League has nowhere to drop to, so only dead last gets the boost.
  final playerRelegThreshold = div.id == 'sunday_league' ? 8 : 7;
  final playerInRelegationZone = secondHalf &&
      playerTablePos != null &&
      playerTablePos >= playerRelegThreshold;

  // Home advantage scales with the crowd: the player's own Fan Zone tier at
  // home, the division's implied support for an AI host.
  final ourFanZoneTier = fanZoneTier(_map(state['clubAssets']));
  final ourHomeAdvBonus = homeAdvantageFor(ourFanZoneTier);
  final theirHomeAdvBonus = homeAdvantageFor(div.maxAssetTier);

  final effectiveSquadRating = effectiveMatchRating(
        baseRating,
        isHome: isHome,
        relegationZone: playerInRelegationZone,
        homeAdvDisplay: homeAdvantageDisplayFor(ourFanZoneTier),
      ) +
      stagnationBuff;
  var effectiveOppRating = effectiveMatchRating(
    opponentRating,
    isHome: !isHome,
    relegationZone: oppInRelegationZone,
    homeAdvDisplay: homeAdvantageDisplayFor(div.maxAssetTier),
  );
  final grudgeBoost = consumeGrudge(state, opponentName);
  if (grudgeBoost > 0) effectiveOppRating += grudgeBoost;

  final ourHomeAdv = isHome ? ourHomeAdvBonus : 0;
  final theirHomeAdv = isHome ? 0 : theirHomeAdvBonus;

  final relegationLift = playerInRelegationZone ? relegationBoost : 0;
  final effAttack =
      math.min(baseRatings.attack + ourHomeAdv, 100) + stagnationBuff + relegationLift;
  final effDefence =
      math.min(baseRatings.defence + ourHomeAdv, 100) + stagnationBuff + relegationLift;

  // The AI has no real squad, so its split is modelled from an attack SHARE
  // around a typical one's, tilted by its stored personality. A like-rated
  // balanced AI therefore reads the same ATK/DEF a human squad would.
  final oppAttackRatio = getOpponentAttackRatio(state, opponentName);
  final oppBase = opponentAtkDefFromShare(opponentRating, oppAttackRatio);
  var effOppAttack = math.min(100, oppBase.attack + theirHomeAdv).toDouble();
  var effOppDefence =
      math.max(10, math.min(100, oppBase.defence + theirHomeAdv)).toDouble();
  if (oppInRelegationZone) {
    effOppAttack += relegationBoost;
    effOppDefence += relegationBoost;
  }
  if (grudgeBoost > 0) {
    effOppAttack += grudgeBoost;
    effOppDefence += grudgeBoost;
  }

  final strategyId = squad?['strategyId'] as String? ?? defaultStrategy;
  final preMatchStrat = strategies[strategyId] ?? strategies[defaultStrategy]!;
  final adjAttack =
      math.max(1.0, applyTacticAtk(effAttack, preMatchStrat, oppAttackRatio));
  final adjDefence =
      math.max(1.0, applyTacticDef(effDefence, preMatchStrat, oppAttackRatio));

  final playerCards = _cards(state);

  // The injury DECISION comes before the sim so Pro mode can play the
  // post-injury segments a man down — a skipped match then costs the same as a
  // watched one. The MUTATIONS land after, so kickoff ratings and the sim's
  // starting lineup still reflect the full XI.
  //
  // Up to TWO per match: the second is rolled on a different player at HALF
  // chance and always lands later in the game. Bad days happen, but never worse
  // than two.
  final injuries = <_Injury>[];
  {
    final rawLineup = _lineupOf(state) ?? const <Map<String, dynamic>>[];
    final injLineupIds = {
      for (final s in rawLineup)
        if (s['cardInstanceId'] != null) s['cardInstanceId'],
    };
    var pool = [
      for (final c in playerCards)
        if (!c.injured &&
            (injLineupIds.isEmpty || injLineupIds.contains(c.instanceId)))
          c,
    ];
    final divIdx = math.max(0, divisions.indexWhere((d) => d.id == div.id));
    // Sweeper's squad-wide cut applies to EVERY roll, not just its own card —
    // the one trait not diluted by the one-in-eleven chance of being drawn.
    final squadInjRed =
        computeSquadTraitTotals(cells, _lineupOf(state)).teamInjuryReduction;

    bool injuryRoll(CardInstance candidate, double mult) {
      // The tactic's multiplier prices risky tactics at kickoff, and
      // [reSimulateRemainder] applies it the same way.
      var chance =
          getInjuryChance(candidate.seasonsPlayed, divIdx) * preMatchStrat.injMod;
      chance += sponsorDrawback(_map(candidate.sponsor)).injuryPenalty;
      chance -= getTraitBonus(
        candidate,
        getPlayerDef(candidate.definitionId)?.position,
      ).injuryReduction;
      chance -= squadInjRed;
      if (grudgeBoost > 0) {
        chance = math.min(0.65, chance * grudgeInjuryMultiplier);
      }
      return seeded.random() < chance * mult;
    }

    if (pool.isNotEmpty) {
      final c1 = pool[seeded.randomInt(0, pool.length - 1)];
      if (injuryRoll(c1, 1)) {
        // The same window the feed places an unscheduled injury in.
        final m1 = seeded.randomInt(20, 85);
        injuries.add(_Injury(c1, m1));
        pool = [
          for (final c in pool)
            if (!identical(c, c1)) c,
        ];
        if (pool.isNotEmpty) {
          final c2 = pool[seeded.randomInt(0, pool.length - 1)];
          if (injuryRoll(c2, 0.5)) {
            injuries.add(
              _Injury(c2, seeded.randomInt(math.min(m1 + 5, 87), 88)),
            );
          }
        }
      }
    }
  }

  // variance is tempo (an open game versus a strangled one); swing is the
  // mean-preserving hot/cold lottery, rolled once per match.
  final matchVariance =
      (preMatchStrat.variance) * rollSwingFactor(preMatchStrat);

  // AI rotation, decided BEFORE the sim so fresh legs actually enter the maths.
  // One or two substitutions in the closing stages, each a small lift that
  // partly offsets their fatigue decay. The same plan drives the feed events and
  // the live badge, so what you see is what was simulated.
  //
  // The count is drawn ONCE, before the loop. Drawing it in the loop condition
  // instead costs an extra number per iteration, which shifts every later draw
  // in the match — the addedTime on the final whistle is where it shows up.
  final aiSubCount =
      (fatigue && lineup != null) ? 1 + (seeded.random() < 0.5 ? 1 : 0) : 0;
  final aiSubPlan = <OppSub>[
    for (var i = 0; i < aiSubCount; i++)
      (
        minute: 55 + (seeded.random() * 30).floor(),
        boostPct: 0.04 + seeded.random() * 0.03,
      ),
  ];

  // Per-entry and call-once, so the CASUAL path can apply each injury between
  // its sim windows while the PRO path applies them all after its segment sim,
  // which handles them internally.
  void applyInjuryEntry(_Injury entry) {
    if (entry.applied) return;
    entry.applied = true;
    final card = entry.card;
    entry.name = card.name('A player');
    card.raw['injured'] = true;
    card.raw['injuredAt'] = now();
    card.raw['injuryDurationMs'] = getInjuryDuration(card.seasonsPlayed);
    // Remember the slot the victim occupied so a mid-match tactic change can
    // cancel a not-yet-shown injury and restore the lineup.
    final prevSlot = _findSlot(state, (s) => s['cardInstanceId'] == card.instanceId);
    entry.prevSlotId = prevSlot?['slotId'] as String?;
    // No automatic replacement in EITHER mode — pull them off to the bench and
    // let the manager sub manually. A null slot means a `no_sub` event, which is
    // what opens the subs panel.
    entry.slot = removeInjuredFromLineup(state, card.instanceId);
    // Whatever occupies the slot NOW — which is nothing, because the line above
    // just vacated it, and this deliberately reads the mutated slot rather than
    // a snapshot. The cancel path only restores the victim if the slot still
    // holds what the injury left there, so a manual sub since keeps its own
    // occupant.
    entry.replacedBy = prevSlot?['cardInstanceId'] as String?;
  }

  Map<String, dynamic>? hardSim;
  int homeGoals;
  int awayGoals;
  if (fatigue && lineup != null) {
    final sim = _simulateHardGoals(
      cards: playerCards,
      lineup: lineup,
      definitionRatios: ratios,
      strategyId: strategyId,
      state: state,
      ourHomeAdv: ourHomeAdv,
      stagnation: stagnationBuff.toDouble(),
      releg: playerInRelegationZone ? relegationBoost : 0,
      oppAttack: effOppAttack,
      oppDefence: effOppDefence,
      oppAttackRatio: oppAttackRatio,
      variance: matchVariance,
      injuries: [
        for (final e in injuries) (iid: e.card.instanceId, minute: e.minute),
      ],
      oppSubs: aiSubPlan,
    );
    homeGoals = sim.homeGoals;
    awayGoals = sim.awayGoals;
    hardSim = {
      'segments': sim.segments,
      'startEnergy': sim.startEnergy,
      'minutesPlayed': sim.minutesPlayed,
      'ourKickoffAtk': sim.ourKickoffAtk,
      'ourKickoffDef': sim.ourKickoffDef,
    };
  } else if (injuries.isNotEmpty) {
    // CASUAL mode with an injury: a full-strength window up to each injury
    // minute, apply it — the victim leaves a hole in the XI — recompute, and
    // continue. Mirrors Pro mode's man-down segments.
    var curAtk = adjAttack;
    var curDef = adjDefence;
    var prevMin = 0;
    homeGoals = 0;
    awayGoals = 0;

    void sampleWindow(int upTo) {
      final frac = math.max(0.0, (upTo - prevMin) / 90);
      homeGoals +=
          poissonGoals(goalRateLambda(curAtk, effOppDefence) * frac * matchVariance);
      awayGoals +=
          poissonGoals(goalRateLambda(effOppAttack, curDef) * frac * matchVariance);
      prevMin = upTo;
    }

    for (final entry in injuries) {
      sampleWindow(entry.minute);
      applyInjuryEntry(entry);
      final postBase = computeSquadRatings(
        cells,
        lineup: lineup,
        definitionRatios: ratios,
        fatigue: fatigue,
      );
      final postReleg = playerInRelegationZone ? relegationBoost : 0;
      curAtk = math.max(
        1.0,
        applyTacticAtk(
          math.min(postBase.attack + ourHomeAdv, 100) + stagnationBuff + postReleg,
          preMatchStrat,
          oppAttackRatio,
        ),
      );
      curDef = math.max(
        1.0,
        applyTacticDef(
          math.min(postBase.defence + ourHomeAdv, 100) + stagnationBuff + postReleg,
          preMatchStrat,
          oppAttackRatio,
        ),
      );
    }
    sampleWindow(90);
  } else {
    homeGoals = simulateGoals(adjAttack, effOppDefence, matchVariance);
    awayGoals = simulateGoals(effOppAttack, adjDefence, matchVariance);
  }

  // The tutorial's guaranteed first win, applied before events are generated so
  // commentary and player stats stay consistent with the final score. homeGoals
  // is always the player's, whatever the venue.
  if (forceWin && homeGoals <= awayGoals) homeGoals = awayGoals + 1;

  final won = homeGoals > awayGoals;
  final drawn = homeGoals == awayGoals;

  // No-op where the sim path already applied them.
  for (final e in injuries) {
    applyInjuryEntry(e);
  }

  final revenueMultiplier = computeMatchRevenueMultiplier(
    _map(state['clubAssets']),
    _map(state['boosts']),
    _num(prog['seasonCount'])?.toInt(),
    computeSquadTraitTotals(cells, _lineupOf(state)).matchRevBonus,
  );

  final coinsEarned = won
      ? roundCoins(div.matchRevenueBase * revenueMultiplier)
      : drawn
          ? roundCoins(div.matchRevenueBase * 0.4 * revenueMultiplier)
          : roundCoins(div.matchRevenueBase * 0.1 * revenueMultiplier);

  const trophiesEarned = 0;

  // The scorer pool, built AFTER the injury mutations so a goal scored once a
  // player has been taken off is credited to whoever actually replaced them.
  final lineupIdSet = lineup == null
      ? null
      : {
          for (final s in lineup)
            if (s['cardInstanceId'] != null) s['cardInstanceId'],
        };
  // Scorer odds follow the SLOT a player is fielded in, not the position on
  // their card. A striker parked at centre-back should not keep scoring like a
  // striker — and, deliberately, a keeper pushed up front should. That is what
  // makes "score with a goalkeeper" a real tactical choice rather than a
  // one-in-three-hundred fluke: you pay the off-position penalty and an empty
  // goal, and in exchange they shoot like whatever slot you gave them.
  //
  // Credit only. This decides WHO is named on a goal, never how many there are,
  // so nothing here touches match balance.
  final slotByInstance = <String, String>{};
  for (final slot in lineup ?? const <Map<String, dynamic>>[]) {
    final iid = slot['cardInstanceId'];
    final pos = slot['slotPosition'];
    if (iid is String && pos is String) slotByInstance[iid] = pos;
  }
  final playerData = <ScorerCandidate>[
    for (final c in playerCards)
      if (!c.injured &&
          (lineupIdSet == null || lineupIdSet.contains(c.instanceId)))
        if (getPlayerDef(c.definitionId) case final def?)
          ScorerCandidate(
            name: c.name(),
            position: slotByInstance[c.instanceId] ?? def.position,
            instanceId: c.instanceId,
          ),
  ];

  // **THE CHANCE ATTRIBUTION IS THE JS'S AND STAYS THE JS'S.** Weighting it on
  // possession instead — so the momentum arrow could be believed — broke
  // thirty-two rows of `match_orchestration_parity_test`, which compares the
  // event feed against the JS's own. That failure is the harness doing its job:
  // the arrow was the thing disagreeing, and the arrow is the port's, so the
  // arrow is what moved. See `dangerHome` in `match_statboard.dart`.
  final chanceWeights = isHome
      ? (home: effectiveSquadRating, away: effectiveOppRating)
      : (home: effectiveOppRating, away: effectiveSquadRating);
  final events = [
    for (final e in generateMatchEvents(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      playerData: playerData,
      injuries: [
        for (final e in injuries) (name: e.name ?? '', minute: e.minute),
      ],
      chanceWeights: chanceWeights,
    ))
      e.toMap(),
  ];
  final addedTime = _num(
        events.firstWhere(
          (e) => e['type'] == 'fulltime',
          orElse: () => const {},
        )['addedTime'],
      )?.toInt() ??
      0;

  // A sub / no-sub marker right after each injury. The popup reads slotId and
  // slotPosition to preselect the vacated slot.
  for (final entry in injuries) {
    final injuryIdx = events.indexWhere(
      (e) =>
          e['type'] == 'injury' &&
          e['player'] == entry.name &&
          e['minute'] == entry.minute,
    );
    final insertAt = injuryIdx >= 0 ? injuryIdx + 1 : events.length;
    final injMin =
        injuryIdx >= 0 ? events[injuryIdx]['minute'] : entry.minute;
    events.insert(insertAt, {
      'minute': injMin,
      'type': 'no_sub',
      'player': entry.name,
      'instanceId': entry.card.instanceId,
      'slotId': entry.slot?.slotId,
      'slotPosition': entry.slot?.slotPosition,
    });
  }

  final resultKey = 's${season}_m$matchNum';

  final result = <String, dynamic>{
    'divisionId': div.id,
    'divisionName': div.name,
    'clubName': (state['clubName'] as String?)?.isNotEmpty == true
        ? state['clubName']
        : 'Your Club',
    'opponentName': opponentName,
    'isHome': isHome,
    'homeGoals': homeGoals,
    'awayGoals': awayGoals,
    'won': won,
    'drawn': drawn,
    'squadRating': baseRating,
    'opponentRating': opponentRating,
    'effectiveSquadRating': effectiveSquadRating,
    'effectiveOppRating': effectiveOppRating,
    // Dual-sim fields, read by the re-simulation and the coach tips.
    'ourAttackRating': baseRatings.attack,
    'ourDefenceRating': baseRatings.defence,
    'effOppAttackRating': effOppAttack,
    'effOppDefenceRating': effOppDefence,
    'oppAttackRatio': oppAttackRatio,
    'stagnationBuff': stagnationBuff,
    'playerInRelegationZone': playerInRelegationZone,
    'coinsEarned': coinsEarned,
    'trophiesEarned': trophiesEarned,
    'injuredName': injuries.isNotEmpty ? injuries.first.name : null,
    'injuryCount': injuries.length,
    // Per-injury metadata, so a tactic change can cancel a pending injury and
    // re-roll at the new tactic's rate.
    'injuryLog': <Map<String, dynamic>>[
      for (final e in injuries)
        {
          'iid': e.card.instanceId,
          'minute': e.minute,
          'name': e.name,
          'prevSlotId': e.prevSlotId,
          'replacedBy': e.replacedBy,
        },
    ],
    'addedTime': addedTime,
    'events': events,
    'grudgeBoost': grudgeBoost,
    // The composite star's home bonus for OUR side, stadium-tier scaled —
    // display code reads this instead of the flat legacy constant.
    'homeAdvDisplay': homeAdvantageDisplayFor(ourFanZoneTier),
    'fixtureKey': resultKey,
    'playedAt': now(),
    // Strategy tracking, filled in by the match screen during play.
    'strategyChanged': false,
    'strategiesUsed': [strategyId],
    'followedCoachSuggestion': false,
    // What the coach last recommended, or null if it never offered anything —
    // read by the defy-the-coach quest, which must not fire when there was no
    // advice to ignore.
    'coachSuggestedStrategy': null,
  };

  // Pro mode: stash the fitness trajectory and the sim inputs so the match
  // screen can show the dip ticking down and re-simulate the remainder when the
  // manager subs. At full time only the PERSISTENT cost is charged; the dip
  // rests off.
  if (hardSim != null) {
    result['hardSim'] = hardSim
      ..addAll({
        'subsUsed': 0,
        // The strategy timeline for piecewise fatigue drain — a switch changes
        // the drain rate from its minute onward only.
        'stratLog': <Map<String, dynamic>>[
          {'min': 0, 'id': strategyId},
        ],
        // Injuries are ROLLED now, with cards flagged and slots vacated, but
        // each HAPPENS at its event minute. Live ratings keep victims on the
        // pitch until then, or the badge drops men instantly.
        'injuries': <Map<String, dynamic>>[
          for (final e in injuries)
            if (e.slot != null)
              {
                'iid': e.card.instanceId,
                'slotPosition': e.slot!.slotPosition.isEmpty
                    ? 'MID'
                    : e.slot!.slotPosition,
                'minute': e.minute,
              },
        ],
        // What a mid-match sub needs to resume the sim.
        'ourHomeAdv': ourHomeAdv,
        'stagnation': stagnationBuff,
        'releg': playerInRelegationZone ? relegationBoost : 0,
        'oppAttack': effOppAttack,
        'oppDefence': effOppDefence,
        'variance': matchVariance,
      });
    // The rotation events come from the SAME plan the sim consumed, so the feed
    // line, the badge bump and the maths all describe one reality.
    for (final sub in aiSubPlan) {
      events.add({
        'minute': sub.minute,
        'type': 'opp_sub',
        'boostPct': sub.boostPct,
        'textKey': 'commentary.opp_sub',
        'textParams': {'opp': opponentName},
      });
    }
    _sortByMinute(events);
  }

  // A grudge in play gets a kick-off line so the player sees the thread.
  if (grudgeBoost > 0) {
    events.insert(0, {
      'minute': 1,
      'type': 'commentary',
      'textKey': 'commentary.snub',
      'textParams': {'opp': opponentName},
    });
  }

  // Immediate bookkeeping only. The match count and the timestamp are needed for
  // cooldowns and fixture indexing while the popup animates; the win/draw/loss
  // counters wait for [finalizeMatchOutcome] so the league table does not shift
  // until the match is settled.
  prog['matchesPlayed'] = (_num(prog['matchesPlayed']) ?? 0) + 1;
  prog['lastMatchAt'] = now();
  prog['seasonMatchesPlayed'] = matchNum + 1;
  if (matchNum + 1 >= matchesPerSeason) prog['seasonComplete'] = true;

  // A placeholder so the fixtures list can show a score during the animation.
  // [finalizeMatchOutcome] overwrites it, because a tactic change rewrites the
  // scoreline on the result object.
  final fixtureResults = _map(prog['fixtureResults']) ??
      (prog['fixtureResults'] = <String, dynamic>{});
  fixtureResults[resultKey] = {
    'homeGoals': homeGoals,
    'awayGoals': awayGoals,
    'won': won,
    'drawn': drawn,
    'isHome': isHome,
    'opponentName': opponentName,
  };

  // **`match_played`, the JS's own event, at the JS's own moment.** It is
  // logged at KICK-OFF rather than at full time, which looks like the wrong
  // end and is deliberate: this is the one function every match goes through,
  // league and cup alike, and the counters it has just written are exactly the
  // fields the event carries. The full-time path is a screen, and a screen can
  // be left.
  //
  // The consequence, which the JS shares: a tactic change re-simulates the
  // remainder, so `outcome` is the scoreline as it stood when the whistle blew
  // to START. Both apps report it the same way, so the series is comparable
  // with itself — which is what a funnel is for.
  logAppEvent('match_played', {
    'division': '${prog['currentDivision'] ?? 'unknown'}',
    'outcome': won ? 'win' : (drawn ? 'draw' : 'loss'),
    'is_home': isHome,
    'season_match': matchNum + 1,
  });

  // `match:complete` is deliberately NOT emitted here — the UI fires it at full
  // time, after the animation, so achievement banners and sound effects don't
  // trigger the instant the Play button is pressed.
  return result;
}

/// The facts a DRAW needs in order to mean anything: who we played, where, and
/// which way the night swung.
///
/// `led` and `trailed` are replayed from the goal events rather than tracked
/// during the sim, because a tactic change re-simulates the remainder and
/// rewrites them — the event list is the only version that is always the match
/// that actually happened. Engine events are us-centric: team `home` is always
/// our goal, whichever ground it was played on.
///
/// `isHome` is deliberately null for a cup tie: they are always played at home,
/// so the venue carries none of the meaning it does in the league.
Map<String, dynamic> _drawContextOf(MatchResult? result) {
  var ours = 0;
  var theirs = 0;
  var led = false;
  var trailed = false;
  final events = result?['events'];
  if (events is List) {
    for (final raw in events) {
      final ev = _map(raw);
      if (ev?['type'] != 'goal') continue;
      if (ev!['team'] == 'home') {
        ours++;
      } else {
        theirs++;
      }
      if (ours > theirs) led = true;
      if (theirs > ours) trailed = true;
    }
  }
  final ourRating = _num(result?['squadRating']);
  final theirRating = _num(result?['opponentRating']);
  return {
    'led': led,
    'trailed': trailed,
    'ratingGap': _finite(ourRating) && _finite(theirRating)
        ? theirRating! - ourRating!
        : 0,
    if (_flag(result?['isCup'])) 'isHome': null,
  };
}

bool _finite(num? v) => v != null && v.isFinite;

/// Settles everything about a match except crediting coins and trophies.
///
/// Called at full time, as soon as the animation reaches the final whistle, so
/// it cannot be skipped by backgrounding the app while the Continue screen sits
/// open. Crediting stays in [applyMatchRewards], deferred until the player
/// actually dismisses the popup, since the double-up needs a live choice.
void finalizeMatchOutcome(Map<String, dynamic> state, MatchResult? result) {
  if (result == null || _flag(result['_outcomeFinalized'])) return;
  final prog = state['progression'] as Map<String, dynamic>;
  final won = _flag(result['won']);
  final drawn = _flag(result['drawn']);
  final homeGoals = _num(result['homeGoals'])?.toInt() ?? 0;
  final awayGoals = _num(result['awayGoals'])?.toInt() ?? 0;
  final isHome = result['isHome'];
  final cells = _cells(state);

  // Pro mode: charge each player who played the small PERSISTENT fitness cost,
  // proportional to minutes played. The temporary dip is not persisted — it
  // rests off. Players who didn't play keep their fitness and their recovery
  // timestamp untouched; stamping the timestamp here means recovery resumes from
  // full time.
  final mins = _map(_map(result['hardSim'])?['minutesPlayed']);
  if (mins != null) {
    final strat = result['strategyId'] as String? ??
        _map(state['squad'])?['strategyId'] as String? ??
        defaultStrategy;
    final tNow = now();
    for (final card in cells) {
      if (card == null) continue;
      final played = _num(mins[card.instanceId]);
      if (played == null) continue;
      final cost = persistentMatchCost(card, played.toDouble(), strat, state);
      final max = getMaxEnergy(card);
      // Subtracted from RAW fitness so a paid overfill buffer is eaten first —
      // the player stays at full rating until the buffer is gone.
      card.raw['energy'] = math.max(
        0.0,
        math.min(max * PlayerEnergy.overfillMult, rawEnergy(card) - cost),
      );
      card.raw['energyUpdatedAt'] = tNow;
    }
  }

  // These apply now, not when simulateMatch ran, so an achievement like First
  // Win only unlocks at full time.
  if (won) prog['matchesWon'] = (_num(prog['matchesWon']) ?? 0) + 1;
  if (drawn) prog['matchesDrawn'] = (_num(prog['matchesDrawn']) ?? 0) + 1;
  // Lifetime mirrors. These survive prestige, so the all-time leaderboard is
  // never zeroed by a soft reset.
  if (won) prog['careerWins'] = (_num(prog['careerWins']) ?? 0) + 1;
  if (drawn) prog['careerDraws'] = (_num(prog['careerDraws']) ?? 0) + 1;
  prog['careerGoalsFor'] = (_num(prog['careerGoalsFor']) ?? 0) + homeGoals;
  if (won) {
    final career = _map(state['careerStats']) ??
        (state['careerStats'] = <String, dynamic>{
          'leagueWins': 0,
          'cupWins': 0,
          'matchesWon': 0,
          'totalMerges': 0,
        });
    career['matchesWon'] = (_num(career['matchesWon']) ?? 0) + 1;
    if (_flag(_map(state['settings'])?['hardMode'])) {
      career['hardModeWins'] = (_num(career['hardModeWins']) ?? 0) + 1;
    }
  }
  if (won) prog['seasonWins'] = (_num(prog['seasonWins']) ?? 0) + 1;
  if (drawn) prog['seasonDraws'] = (_num(prog['seasonDraws']) ?? 0) + 1;
  if (!won && !drawn) {
    prog['seasonLosses'] = (_num(prog['seasonLosses']) ?? 0) + 1;
  }
  // The table-facing played counter moves now, so the league table only updates
  // once the match is fully settled.
  prog['seasonAwardedPlayed'] = (_num(prog['seasonAwardedPlayed']) ?? 0) + 1;

  // A score is always shown home-team-first, so it flips when we are away —
  // in the engine homeGoals is always ours.
  final displayHome = isHome == true ? homeGoals : awayGoals;
  final displayAway = isHome == true ? awayGoals : homeGoals;
  prog['lastMatchResult'] = {
    'coinsEarned': result['coinsEarned'],
    'trophiesEarned': result['trophiesEarned'],
    'won': won,
    'drawn': drawn,
    'score': '$displayHome–$displayAway',
    // Ours and theirs are stored raw so the manager commentary can reason about
    // the shape of the score without parsing the display string.
    'ourGoals': homeGoals,
    'theirGoals': awayGoals,
    'opponentName': result['opponentName'],
    'isHome': isHome,
    // A 1-1 tells you nothing on its own — a point away at a much better side is
    // a good night, the same point at home against a worse one is two dropped.
    // The walker on the diorama needs the same three facts the dugout cam's
    // full-time shot reads live, or the two disagree about the same draw seconds
    // apart. Only meaningful on a draw; harmless, and cheap, always.
    ..._drawContextOf(result),
    'playedAt': now(),
  };

  // Overwrite the fixture entry with the final result. simulateMatch wrote a
  // placeholder so the list showed a score during the animation, but a tactic
  // change rewrites the scoreline, so the stored fixture has to be corrected.
  final fixtureKey = result['fixtureKey'] as String?;
  final fixtureResults = _map(prog['fixtureResults']);
  if (fixtureKey != null && fixtureResults?[fixtureKey] != null) {
    fixtureResults![fixtureKey] = {
      'homeGoals': result['homeGoals'],
      'awayGoals': result['awayGoals'],
      'won': result['won'],
      'drawn': result['drawn'],
      'isHome': result['isHome'],
      'opponentName': result['opponentName'],
      'playedAt': result['playedAt'],
    };
  }

  // Per-player form, updated here and not in simulateMatch so a mid-match tactic
  // change that flips the outcome is reflected correctly — and so the rating
  // shown during the animation is not yet penalised for a loss that hasn't
  // happened.
  final formLineupIds = _lineupIds(state);
  final playingCards = [
    for (final c in cells)
      if (c != null &&
          !c.injured &&
          (formLineupIds == null ||
              formLineupIds.isEmpty ||
              formLineupIds.contains(c.instanceId)))
        c,
  ];
  if (won) {
    for (final card in playingCards) {
      card.raw['form'] = math.max(
        Form.min,
        math.min(Form.max, (_num(card.raw['form']) ?? 0) + 1),
      );
    }
  } else if (!drawn) {
    final goalMargin = (homeGoals - awayGoals).abs();
    final baseProbability = math.min(0.75, 0.4 + (goalMargin - 1) * 0.1);
    final avgRating = playingCards.isNotEmpty
        ? playingCards.fold<double>(
              0,
              (s, c) => s + (getPlayerDef(c.definitionId)?.rating ?? 50),
            ) /
            playingCards.length
        : 50.0;
    for (final card in playingCards) {
      final rating =
          getPlayerDef(card.definitionId)?.rating.toDouble() ?? avgRating;
      final ratingFactor =
          (avgRating - rating) / math.max(1, avgRating) * 0.25;
      final probability =
          math.max(0.15, math.min(0.85, baseProbability + ratingFactor));
      if (seeded.random() < probability) {
        card.raw['form'] = math.max(Form.min, (_num(card.raw['form']) ?? 0) - 1);
      }
    }
  }

  // Per-player career stats. Goals are attributed to the scorer by instance id
  // from the goal events; tackles and saves are simulated per-match totals by
  // position; everyone on the pitch gets an appearance.
  final cardById = {
    for (final c in cells.whereType<CardInstance>()) c.instanceId: c,
  };

  final events = result['events'];
  if (events is List) {
    for (final raw in events) {
      final ev = _map(raw);
      if (ev == null) continue;
      if (ev['type'] != 'goal' || ev['team'] != 'home') continue;
      final id = ev['scorerInstanceId'];
      if (id == null) continue;
      final sc = cardById[id];
      if (sc == null) continue;
      final stats = _statsOf(sc);
      stats['goals'] = (_num(stats['goals']) ?? 0) + 1;
    }
  }

  final lineupIds = _lineupIds(state);
  for (final card in cells) {
    if (card == null) continue;
    if (lineupIds != null &&
        lineupIds.isNotEmpty &&
        !lineupIds.contains(card.instanceId)) {
      continue;
    }
    final stats = _statsOf(card);
    stats['matchesPlayed'] = (_num(stats['matchesPlayed']) ?? 0) + 1;
    final def = getPlayerDef(card.definitionId);
    if (def == null) continue;
    if (def.position == 'GK') {
      // Saves are the goals conceded plus a few that didn't become goals.
      final saves = awayGoals + (_rng.nextDouble() * 4).floor();
      stats['saves'] = (_num(stats['saves']) ?? 0) + saves;
    } else if (def.position == 'DEF') {
      stats['tackles'] =
          (_num(stats['tackles']) ?? 0) + 2 + (_rng.nextDouble() * 4).floor();
    } else if (def.position == 'MID') {
      stats['tackles'] =
          (_num(stats['tackles']) ?? 0) + 1 + (_rng.nextDouble() * 3).floor();
    }
  }

  result['_outcomeFinalized'] = true;
}

/// Credits a match's coins and trophies.
///
/// Called once the player dismisses the match popup, which is the only part of
/// settlement that genuinely needs a live choice. Finalizes the outcome first if
/// that hasn't happened, so this stays a complete, idempotent "settle
/// everything" entry point on its own.
void applyMatchRewards(Map<String, dynamic> state, MatchResult? result) {
  if (result == null || _flag(result['_rewardsApplied'])) return;
  finalizeMatchOutcome(state, result);

  final resources = state['resources'] as Map<String, dynamic>;
  final prog = state['progression'] as Map<String, dynamic>;
  final coins = _num(result['coinsEarned']) ?? 0;
  final trophies = _num(result['trophiesEarned']) ?? 0;
  resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + coins;
  resources['trophies'] = (_num(resources['trophies']) ?? 0) + trophies;
  prog['trophiesTotal'] = (_num(prog['trophiesTotal']) ?? 0) + trophies;

  // Loan wages come out of the payout that just landed, and this match burns a
  // game off every live loan. Settling AFTER the credit is the point: the wage
  // is felt against the winnings, and a payout that cannot cover it ends the
  // loan rather than pushing the balance negative.
  final report = settleLoanMatch(state);
  // Stored as a plain map, never the record itself: a cup result goes into the
  // save, and a record would throw on the first encode after it.
  result['loanReport'] = {
    'wagesPaid': report.wagesPaid,
    'departed': [
      for (final d in report.departed)
        {'name': d.name, 'reason': d.reason, 'card': d.card.raw},
    ],
    'feesEarned': report.feesEarned,
    'returned': [
      for (final r in report.returned)
        {'name': r.name, 'toTeam': r.toTeam, 'card': r.card.raw},
    ],
  };

  result['_rewardsApplied'] = true;
}

/// Re-simulates the remaining minutes under a new tactic.
///
/// Rewrites the result's scoreline, outcome and payout in place, and returns the
/// feed for `[fromMinute + 1, 90]`. A tactic change also re-rolls injury risk:
/// any injury decided at kickoff whose minute has not been reached on screen is
/// CANCELLED here — the card healed and the slot restored — and the remainder
/// rolls fresh at the new tactic's multiplier, so dropping out of High Press
/// genuinely lowers the risk and switching into it raises it.
List<Map<String, dynamic>> reSimulateRemainder(
  MatchResult result,
  int fromMinute,
  String strategyId,
  int currentOurGoals,
  int currentTheirGoals,
  Map<String, dynamic>? state, {
  /// Whether the remaining injuries are thrown away and rolled again.
  ///
  /// **True for a TACTIC change and false for anything else.** Re-rolling is
  /// the whole point there — the multiplier is the tactic's, so dropping out of
  /// High Press has to genuinely lower the risk and switching into it has to
  /// raise it.
  ///
  /// A SUBSTITUTION is a different thing entirely: it changes who is on the
  /// pitch, not how dangerously the side is playing. Left on, it made a sub a
  /// way to cancel an injury that was already coming and re-roll for a better
  /// one — an exploit, and one the suite found rather than reasoning: with
  /// subs re-rolling, a re-simulated remainder injured a bench player between
  /// two substitutions and the cap test could not bring him on.
  bool rerollInjuries = true,

  /// What the referee has cost OUR side, by instance id — see
  /// `booking_engine.bookedRatingMultipliers`.
  ///
  /// **A yellow used to be worth nothing to the maths.** The ten per cent came
  /// off the number on the pitch token and off the number the bench compared
  /// against, and stopped there: the scoreline was still being rolled by a side
  /// nobody had booked. Reported from the couch — "that player's rating drop
  /// should also affect the team rating and ATK/DEF on the main card at the top
  /// of the match popup, and the new number should be what the SIM rerolls
  /// with."
  ///
  /// A sending-off is NOT in here: he leaves the lineup, and the hole is what
  /// the rating engine scores.
  Map<String, double> bookedMultipliers = const {},

  /// The same, for a side that exists only as a rating —
  /// `booking_engine.oppTeamRatingMult`. 1.0 is a clean opposition.
  double oppRatingMult = 1.0,

  /// **WHERE THE LIVE RATINGS GO, and it is deliberately NOT the result.**
  ///
  /// The board at the top of the match popup needs the numbers the remainder
  /// was actually rolled with — a caution and the opponent's red both move
  /// them, and until they did the card looked like theatre. The first attempt
  /// wrote them onto `result` beside the kickoff pair, and
  /// `match_orchestration_parity_test` refused it: it compares the whole result
  /// object against a node dump field for field, so a field the JS has never
  /// heard of cannot live there. Which is right — bookings are the port's own
  /// mechanic, and this repo's rule is that a divergence belongs on the SCREEN.
  ///
  /// So the caller passes a map to be filled. Null, and nothing is written and
  /// the result is byte-for-byte what the JS produces.
  Map<String, dynamic>? liveRatingsOut,
}) {
  final strat = strategies[strategyId] ?? strategies[defaultStrategy];
  final addedTime = _num(result['addedTime'])?.toInt() ?? 0;
  final matchDuration = 90 + addedTime;
  final fraction = math.max(0.0, (matchDuration - fromMinute) / matchDuration);
  final hardMode = _flag(_map(state?['settings'])?['hardMode']);
  final hardSim = _map(result['hardSim']);
  final fixedRating = _flag(result['fixedRating']);
  final isCup = _flag(result['isCup']);
  final oppAttackRatio = _num(result['oppAttackRatio'])?.toDouble();

  // The opponent's ratings, unchanged by our tactic.
  final fallbackOpp = _num(result['effectiveOppRating']) ??
      _num(result['opponentRating']) ??
      0;
  var oppAttack =
      (_num(result['effOppAttackRating']) ?? fallbackOpp).toDouble();
  var oppDefence =
      (_num(result['effOppDefenceRating']) ?? fallbackOpp).toDouble();
  // Pro mode: the opponent has tired too — the kickoff sim decays them per
  // segment, so the re-simulated remainder must not face a fresh side.
  // Approximated with the decay factor at the midpoint of the remaining window.
  if (hardMode && hardSim != null && !fixedRating) {
    final midMin = (fromMinute + 90) / 2;
    final decay = 1 - (1 - oppEndFatigue) * math.min(1, midMin / 90);
    oppAttack *= decay;
    oppDefence *= decay;
  }
  // And what their own referee has cost them. Applied after the fatigue decay
  // for the same reason our booking is applied inside the rating rather than
  // after the tactic: both are facts about the players, and the tactic and the
  // clock are what act on the result of them.
  oppAttack *= oppRatingMult;
  oppDefence *= oppRatingMult;

  double adjAttack;
  double adjDefence;
  double adjSquad;
  // The live pair on the SAME basis as `ourAttackRating`: straight off
  // `computeSquadRatings`, before home advantage, stagnation or the tactic. The
  // board applies the tactic itself, so handing it a post-tactic figure would
  // apply the multipliers twice.
  double liveBaseAttack;
  double liveBaseDefence;
  if (fixedRating) {
    // An event cup: team strength is a fixed external rating — the chosen
    // nation — NOT the player's club squad. Tactics still bias the match, so the
    // multipliers land directly on that rating rather than pulling the (often
    // weaker) club squad into an international tournament.
    final fixedBase = (_num(result['squadRating']) ?? 70).toDouble();
    adjAttack = math.max(1.0, applyTacticAtk(fixedBase, strat, oppAttackRatio));
    adjDefence = math.max(1.0, applyTacticDef(fixedBase, strat, oppAttackRatio));
    adjSquad = math.max(1.0, fixedBase);
    liveBaseAttack = fixedBase;
    liveBaseDefence = fixedBase;
  } else {
    final liveLineup = _lineupOf(state);
    final liveHomeAdv = (!isCup && _flag(result['isHome']))
        ? homeAdvantageFor(fanZoneTier(_map(state?['clubAssets'])))
        : 0;
    final prog = _map(state?['progression']);
    final liveStag =
        _num(_map(prog?['stagnationBuffs'])?['${prog?['currentDivision']}']) ?? 0;

    if (hardMode && hardSim != null) {
      // Record the switch in the strategy timeline, so fatigue accrued so far
      // stays priced at the tactic it was played under.
      final rawLog = hardSim['stratLog'];
      final log = rawLog is List
          ? rawLog
          : (hardSim['stratLog'] = <Map<String, dynamic>>[
              {
                'min': 0,
                'id': (result['strategiesUsed'] is List &&
                        (result['strategiesUsed'] as List).isNotEmpty)
                    ? (result['strategiesUsed'] as List).first
                    : strategyId,
              },
            ]) as List;
      if (_map(log.last)?['id'] != strategyId) {
        log.add({'min': fromMinute, 'id': strategyId});
      }
    }
    final liveRatings = (hardMode && hardSim != null)
        ? hardLiveRatings(
            result,
            fromMinute,
            state,
            strategyId,
            bookedMultipliers: bookedMultipliers,
          )
        // A cup tie in Pro mode carries no per-minute sim — still price in the
        // squad's persistent fitness, so a tired team cannot re-sim at full
        // strength.
        : computeSquadRatings(
            _cells(state),
            lineup: liveLineup,
            definitionRatios: _map(state?['definitionRatios']) ?? const {},
            fatigue: hardMode,
            ratingMultipliers: bookedMultipliers,
          );
    final liveAttack =
        math.min(liveRatings.attack + liveHomeAdv, 100) + liveStag;
    final liveDefence =
        math.min(liveRatings.defence + liveHomeAdv, 100) + liveStag;

    adjAttack = math.max(1.0, applyTacticAtk(liveAttack, strat, oppAttackRatio));
    adjDefence = math.max(1.0, applyTacticDef(liveDefence, strat, oppAttackRatio));
    liveBaseAttack = liveRatings.attack.toDouble();
    liveBaseDefence = liveRatings.defence.toDouble();

    // A combined figure for the possession display. The multipliers are
    // near-zero-sum on the composite, so the tactic leaves it unchanged.
    final liveBase = computeSquadRating(
      _cells(state),
      lineup: liveLineup,
      definitionRatios: _map(state?['definitionRatios']) ?? const {},
      fatigue: hardMode,
      ratingMultipliers: bookedMultipliers,
    );
    adjSquad =
        math.max(1.0, (math.min(liveBase + liveHomeAdv, 100) + liveStag).toDouble());
  }

  // Each side sampled at the goal RATE for the remaining minutes rather than a
  // full match floored down — otherwise a two-goal burst in a short window is
  // structurally impossible and a tactic switch never visibly changes anything.
  // Tempo times a FRESH hot/cold roll: Counter Attack's gamble re-rolls with the
  // remainder.
  final variance = (strat?.variance ?? 1.0) * rollSwingFactor(strat);
  final remainHome =
      poissonGoals(goalRateLambda(adjAttack, oppDefence) * fraction * variance);
  final remainAway =
      poissonGoals(goalRateLambda(oppAttack, adjDefence) * fraction * variance);

  // **WHAT THE REMAINDER WAS ROLLED WITH, so the board can print it.**
  //
  // Reported from the couch about a caution and again about the opponent's red:
  // the numbers at the top of the match popup never moved, so a card looked
  // like theatre even once it was not. They could not move — every rating on
  // that board came off the fields `buildMatchResult` wrote at KICKOFF, and
  // nothing has ever written a second set.
  //
  // Handed OUT rather than stamped on the result — see [liveRatingsOut]. The
  // kickoff pair stays exactly as it was: it is what the side was worth when it
  // walked out, and `quest_match` reads it to judge "beat a stronger side",
  // which is a question about the fixture rather than about the 73rd minute.
  if (liveRatingsOut != null) {
    liveRatingsOut
      ..['liveAttackRating'] = liveBaseAttack
      ..['liveDefenceRating'] = liveBaseDefence
      ..['liveSquadRating'] = adjSquad
      ..['liveOppAttackRating'] = oppAttack
      ..['liveOppDefenceRating'] = oppDefence
      // The opponent's single figure is the kickoff one scaled by what their
      // own referee cost them — there is no squad of theirs to re-rate.
      ..['liveOppRating'] =
          (_num(result['effectiveOppRating']) ?? 0) * oppRatingMult;
  }

  result['homeGoals'] = currentOurGoals + remainHome;
  result['awayGoals'] = currentTheirGoals + remainAway;
  result['won'] = result['homeGoals'] > result['awayGoals'];
  result['drawn'] = result['homeGoals'] == result['awayGoals'];
  result['strategyId'] = strategyId;
  // Cleared, and re-set below only if the tie is still level.
  result['penaltyShootout'] = null;

  // A cup knockout cannot end level. `isHome` is true for every cup round, so
  // "home" is always the player's team.
  if (isCup && _flag(result['drawn'])) {
    final shootout =
        simulatePenaltyShootout(adjAttack, adjDefence, oppAttack, oppDefence);
    result['penaltyShootout'] = {
      'playerWins': shootout.playerWins,
      'kicks': [
        for (final k in shootout.kicks)
          {
            'team': k.team,
            'scored': k.scored,
            'homeTotal': k.homeTotal,
            'awayTotal': k.awayTotal,
            if (k.suddenDeath) 'suddenDeath': true,
          },
      ],
      'homeScore': shootout.homeScore,
      'awayScore': shootout.awayScore,
    };
    if (shootout.playerWins) {
      result['homeGoals'] = (result['homeGoals'] as int) + 1;
      result['won'] = true;
    } else {
      result['awayGoals'] = (result['awayGoals'] as int) + 1;
      result['won'] = false;
    }
    result['drawn'] = false;
  }

  // Recalculated from the FINAL outcome: the initial payout came from the
  // pre-change simulation and would be wrong if the result flipped.
  final div = getDivision(
    '${result['divisionId'] ?? _map(state?['progression'])?['currentDivision']}',
  );
  if (!isCup) {
    final finalMult = computeMatchRevenueMultiplier(
      _map(state?['clubAssets']),
      _map(state?['boosts']),
      _num(_map(state?['progression'])?['seasonCount'])?.toInt(),
      computeSquadTraitTotals(_cells(state), _lineupOf(state)).matchRevBonus,
    );
    result['coinsEarned'] = _flag(result['won'])
        ? roundCoins(div.matchRevenueBase * finalMult)
        : _flag(result['drawn'])
            ? roundCoins(div.matchRevenueBase * 0.4 * finalMult)
            : roundCoins(div.matchRevenueBase * 0.1 * finalMult);
  }

  // Cancel any injury whose minute is still in the future. Their feed events are
  // discarded by the match screen's kept-events split, so nothing visible
  // disappears.
  final rawLog = result['injuryLog'];
  final injuryLog = rawLog is List ? rawLog : <Object?>[];
  if (rerollInjuries) {
    var cancelled = 0;
    for (final raw in injuryLog) {
      final entry = _map(raw);
      if (entry == null) continue;
      if (_flag(entry['cancelled']) ||
          (_num(entry['minute']) ?? 0) <= fromMinute) {
        continue;
      }
      final card = _cardById(state, entry['iid']);
      if (card == null || !card.injured) continue;
      card.raw['injured'] = false;
      card.raw.remove('injuredAt');
      card.raw.remove('injuryDurationMs');
      final slot = _findSlot(state, (s) => s['slotId'] == entry['prevSlotId']);
      // Only restore the victim if the slot still holds what the injury left
      // there — a manual sub since wins.
      if (slot != null && slot['cardInstanceId'] == entry['replacedBy']) {
        slot['cardInstanceId'] = entry['iid'];
      }
      entry['cancelled'] = true;
      cancelled++;
    }
    if (cancelled > 0) {
      result['injuryCount'] = math.max(
        0,
        (_num(result['injuryCount']) ?? cancelled) - cancelled,
      );
      result['injuredName'] = injuryLog
          .map(_map)
          .firstWhere(
            (e) => e != null && !_flag(e['cancelled']),
            orElse: () => null,
          )?['name'];
      final hardInjuries = hardSim?['injuries'];
      if (hardInjuries is List) {
        hardSim!['injuries'] = <Object?>[
          for (final raw in hardInjuries)
            if (!injuryLog.map(_map).any(
              (e) =>
                  e != null &&
                  _flag(e['cancelled']) &&
                  e['iid'] == _map(raw)?['iid'] &&
                  e['minute'] == _map(raw)?['minute'],
            ))
              raw,
        ];
      }
    }
  }

  // An injury roll for the remaining portion, capped at two per MATCH across the
  // kickoff sim and every re-sim — repeated tactic changes must never grind the
  // squad down past that.
  final divIdx = math.max(0, divisions.indexWhere((d) => d.id == div.id));
  final playerCards = _cards(state);
  final reSimLineupIds = _lineupIds(state) ?? const <Object>{};
  final healthyCards = [
    for (final c in playerCards)
      if (!c.injured &&
          (reSimLineupIds.isEmpty || reSimLineupIds.contains(c.instanceId)))
        c,
  ];
  String? injuredName;
  var remainderInjury = false;
  String? injuredInstanceId;
  VacatedSlot? injuredSlot;
  final priorInjuryCount = _num(result['injuryCount'])?.toInt() ??
      (hardSim?['injuries'] is List
          ? (hardSim!['injuries'] as List).length
          : (result['injuredName'] != null ? 1 : 0));
  // And a fresh roll is the other half of the same decision: a substitution
  // does not invent an injury either, it just changes who is on the pitch.
  if (rerollInjuries &&
      !fixedRating &&
      priorInjuryCount < 2 &&
      healthyCards.isNotEmpty &&
      fraction > 0.15) {
    final candidate = healthyCards[seeded.randomInt(0, healthyCards.length - 1)];
    var chance = getInjuryChance(candidate.seasonsPlayed, divIdx) *
        (strat?.injMod ?? 1) *
        fraction;
    chance += sponsorDrawback(_map(candidate.sponsor)).injuryPenalty;
    // Trait reductions apply exactly as they do at kickoff. The re-sim path used
    // to ignore them, so a tactic change quietly voided Tough.
    chance -= getTraitBonus(
      candidate,
      getPlayerDef(candidate.definitionId)?.position,
    ).injuryReduction;
    chance -= computeSquadTraitTotals(
      _cells(state),
      _lineupOf(state),
    ).teamInjuryReduction;
    if (seeded.random() < chance) {
      result['injuryCount'] = priorInjuryCount + 1;
      candidate.raw['injured'] = true;
      candidate.raw['injuredAt'] = now();
      candidate.raw['injuryDurationMs'] =
          getInjuryDuration(candidate.seasonsPlayed);
      injuredName = candidate.name('A player');
      injuredInstanceId = candidate.instanceId;
      final prevSlot =
          _findSlot(state, (s) => s['cardInstanceId'] == candidate.instanceId);
      injuredSlot = state == null
          ? null
          : removeInjuredFromLineup(state, candidate.instanceId);
      remainderInjury = true;
      // Logged like a kickoff injury so a LATER tactic change can cancel it too
      // if its event minute is still ahead. The minute is stamped below, once
      // the event has landed in the feed.
      injuryLog.add({
        'iid': candidate.instanceId,
        'minute': 91,
        'name': injuredName,
        'prevSlotId': prevSlot?['slotId'],
        'replacedBy': prevSlot?['cardInstanceId'],
      });
      result['injuryLog'] = injuryLog;
    }
  }

  // An event-cup match never credits a goal to a club player — the nation's
  // players are not the club squad. An empty pool means no scorer names.
  final playerData = <ScorerCandidate>[
    if (!_flag(result['anonymousPlayers']))
      for (final c in playerCards)
        if (!c.injured &&
            (reSimLineupIds.isEmpty || reSimLineupIds.contains(c.instanceId)))
          if (getPlayerDef(c.definitionId) case final def?)
            ScorerCandidate(
              name: c.name(),
              position: def.position,
              instanceId: c.instanceId,
            ),
  ];

  final isHome = result['isHome'] != false;
  final chanceWeights = isHome
      ? (home: adjSquad, away: oppAttack)
      : (home: oppAttack, away: adjSquad);
  final newEvents = [
    for (final e in generateMatchEvents(
      homeGoals: remainHome,
      awayGoals: remainAway,
      playerData: playerData,
      injuries: [
        if (injuredName != null) (name: injuredName, minute: null),
      ],
      minMin: fromMinute + 1,
      chanceWeights: chanceWeights,
      addedTime: _num(result['addedTime'])?.toInt(),
    ))
      e.toMap(),
  ];

  if (remainderInjury) {
    final injuryIdx = newEvents.indexWhere((e) => e['type'] == 'injury');
    final insertAt = injuryIdx >= 0 ? injuryIdx + 1 : newEvents.length;
    final injMin =
        injuryIdx >= 0 ? newEvents[injuryIdx]['minute'] : fromMinute + 1;
    for (final raw in injuryLog) {
      final e = _map(raw);
      if (e?['iid'] == injuredInstanceId && e?['minute'] == 91) {
        e!['minute'] = injMin;
      }
    }
    newEvents.insert(insertAt, {
      'minute': injMin,
      'type': 'no_sub',
      'player': injuredName,
      'instanceId': injuredInstanceId,
      'slotId': injuredSlot?.slotId,
      'slotPosition': injuredSlot?.slotPosition,
    });
    // Stamped on the Pro-mode sim so live ratings keep the victim on the pitch
    // until its minute — the same rule as a kickoff injury.
    if (hardSim != null) {
      final existing = hardSim['injuries'];
      final list = existing is List ? existing : <Map<String, dynamic>>[];
      hardSim['injuries'] = list
        ..add({
          'iid': injuredInstanceId,
          'slotPosition': (injuredSlot?.slotPosition.isNotEmpty ?? false)
              ? injuredSlot!.slotPosition
              : 'MID',
          'minute': injMin,
        });
    }
  }

  return newEvents;
}

// ── the cooldown between matches ─────────────────────────────────────────────

/// How long the Play button stays gated after a match.
///
/// The VIP pass and the Quick Fire Matches ad both cut it to ten seconds; that
/// is the whole of what they sell.
int effectiveCooldownMs(Map<String, dynamic> state) {
  final boosts = _map(state['boosts']);
  final freeUntil = _num(boosts?['matchCooldownFreeUntil']) ?? 0;
  if (freeUntil > now()) return _vipCooldownMs;
  final isVip =
      _flag(boosts?['vipActive']) && (_num(boosts?['vipExpiresAt']) ?? 0) > now();
  return isVip
      ? _vipCooldownMs
      : getDivision('${_map(state['progression'])?['currentDivision']}')
          .matchCooldownMs;
}

bool canPlayMatch(Map<String, dynamic> state) {
  final prog = _map(state['progression']);
  if (_flag(prog?['seasonComplete'])) return false;
  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is List) {
    final filledSlots =
        lineup.where((s) => _map(s)?['cardInstanceId'] != null).length;
    if (filledSlots < minSquadPlayers) return false;
  }
  return (now() - (_num(prog?['lastMatchAt']) ?? 0)) >=
      effectiveCooldownMs(state);
}

int matchCooldownRemaining(Map<String, dynamic> state) {
  final lastMatchAt =
      _num(_map(state['progression'])?['lastMatchAt']) ?? 0;
  return math.max(0, effectiveCooldownMs(state) - (now() - lastMatchAt)).toInt();
}

/// Restarts the cooldown from this moment.
///
/// Called when the player is actually back on the Play screen — from the match
/// popup's close, not at kick-off. The stamps made during the match stay put as a
/// floor, so the button is still gated if the app dies while the popup is open;
/// this only ever pushes the clock LATER.
///
/// Without it the cooldown ran down DURING the match feed, so anyone who watched
/// a match waited zero seconds and only skippers ever felt it — which also made
/// the two things sold against it worthless to watchers.
void startMatchCooldown(Map<String, dynamic>? state) {
  final prog = _map(state?['progression']);
  if (prog == null) return;
  prog['lastMatchAt'] = math.max(_num(prog['lastMatchAt']) ?? 0, now());
}

// ── shared plumbing ──────────────────────────────────────────────────────────

/// Stable, so two events on the same minute keep the order they were built in —
/// which JS `Array.sort` guarantees and Dart's `List.sort` does not.
void _sortByMinute(List<Map<String, dynamic>> events) => stableSort(
  events,
  (a, b) => (_num(a['minute']) ?? 0).compareTo(_num(b['minute']) ?? 0),
);

List<CardInstance?> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [for (final c in cells) CardInstance.from(c)];
}

List<CardInstance> _cards(Map<String, dynamic>? state) =>
    _cells(state).whereType<CardInstance>().toList();

CardInstance? _cardById(Map<String, dynamic>? state, Object? iid) {
  if (iid == null) return null;
  for (final c in _cards(state)) {
    if (c.instanceId == iid) return c;
  }
  return null;
}

/// The set XI, or null when there isn't one of exactly eleven slots.
List<Map<String, dynamic>>? _lineupOf(Map<String, dynamic>? state) {
  final raw = _map(state?['squad'])?['lineup'];
  if (raw is! List) return null;
  final slots = [
    for (final s in raw)
      if (s is Map<String, dynamic>) s,
  ];
  return slots.length == 11 ? slots : null;
}

/// Every card id in the XI, or null when no lineup is set at all. Distinct from
/// an EMPTY set, which means a lineup exists with nobody in it.
Set<Object>? _lineupIds(Map<String, dynamic>? state) {
  final raw = _map(state?['squad'])?['lineup'];
  if (raw is! List) return null;
  return {
    for (final s in raw)
      if (_map(s)?['cardInstanceId'] case final Object id) id,
  };
}

Map<String, dynamic>? _findSlot(
  Map<String, dynamic>? state,
  bool Function(Map<String, dynamic>) test,
) {
  final raw = _map(state?['squad'])?['lineup'];
  if (raw is! List) return null;
  for (final s in raw) {
    final slot = _map(s);
    if (slot != null && test(slot)) return slot;
  }
  return null;
}

/// A card's career stats, created on first use with every key present.
Map<String, dynamic> _statsOf(CardInstance card) {
  final existing = _map(card.raw['stats']);
  if (existing != null) return existing;
  final stats = <String, dynamic>{
    'goals': 0,
    'assists': 0,
    'tackles': 0,
    'saves': 0,
    'matchesPlayed': 0,
  };
  card.raw['stats'] = stats;
  return stats;
}

/// The Pro-mode sim's injury list, tolerating the single-injury shape an older
/// save wrote.
List<Map<String, dynamic>> _hardSimInjuries(Map<String, dynamic> hs) {
  final list = hs['injuries'];
  if (list is List) {
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e,
    ];
  }
  final single = _map(hs['injury']);
  return single != null ? [single] : const [];
}

Map<String, dynamic> _slotMap(LineupSlot s) => {
  'slotId': s.slotId,
  'slotPosition': s.slotPosition,
  'cardInstanceId': s.cardInstanceId,
};
