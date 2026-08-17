/// Pro-mode per-player fatigue, ported from
/// `../merge-empire-fc/src/engine/playerEnergyEngine.js`.
///
/// In Pro mode each player has an energy bar maxing at their base rating, so a
/// 90-rated player carries a 90-point bar. Their LIVE rating is their current
/// energy, which makes a tired player measurably weaker. Energy drains across a
/// match and recovers over real time.
///
/// BALANCE INVARIANT: total games-per-hour is set by recovery, not drain. A
/// fatigue perk scaling in-match drain by k (below 1) MUST scale recovery by
/// the same k, so the wall-clock to be match-ready again is unchanged. The perk
/// buys in-match strength and back-to-back use of a key player — never more
/// total matches.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

double _clamp(num v, num lo, num hi) =>
    math.max(lo, math.min(hi, v)).toDouble();

/// Wall-clock to recover an empty bar — faster with the Energy Director.
int _fullRegenMs(Map<String, dynamic>? state) {
  final shop = state?['shop'];
  final upgraded = shop is Map && shop['energyUpgraded'] == true;
  return upgraded
      ? PlayerEnergy.fitnessFullRegenMsUpgraded
      : PlayerEnergy.fitnessFullRegenMs;
}

/// Max energy for a card is its base rating. Zero for non-player cards.
int getMaxEnergy(CardInstance? card) {
  if (card == null) return 0;
  final def = getPlayerDef(card.definitionId);
  return def == null ? 0 : getCardRating(def, ratingBonus: card.ratingBonus);
}

/// Current energy, clamped to [0, max]. Un-migrated cards read as full.
double getEnergy(CardInstance? card) {
  final max = getMaxEnergy(card);
  if (max <= 0) return 0;
  final stored = card!.energy;
  return _clamp(stored ?? max, 0, max);
}

/// The live rating ceiling under fatigue — energy is denominated in rating
/// points, so it IS the ceiling.
double liveRating(CardInstance? card) => getEnergy(card);

/// Fraction of energy remaining, 0..1. Caps at 1: a fitness buffer never lifts
/// rating above 100%.
double energyPct(CardInstance? card) {
  final max = getMaxEnergy(card);
  return max <= 0 ? 0 : getEnergy(card) / max;
}

/// Maps a raw fitness fraction to a RATING multiplier with a dead zone: no
/// penalty at all above the dead zone, since mild tiredness should not show in
/// ATK/DEF, then the remaining range is rescaled to 0..1 so the curve stays
/// continuous and still reaches zero at empty.
///
/// Every rating calculation that scales by fitness goes through this, NOT raw
/// [energyPct] — which stays the true reading for bars and fitness gating.
double fatigueRatingFactor(double pct) {
  if (pct >= PlayerEnergy.fatigueDeadZonePct) return 1;
  return math.max(0, pct / PlayerEnergy.fatigueDeadZonePct);
}

double cardFatigueRatingFactor(CardInstance? card) =>
    fatigueRatingFactor(energyPct(card));

/// RAW stored fitness, up to the overfill ceiling. This is the persistent
/// buffer a paid pack banks — it holds a player at full rating for extra
/// matches, draining through the buffer first. Rating maths uses [getEnergy],
/// so a buffer never boosts strength, only endurance.
double rawEnergy(CardInstance? card) {
  final max = getMaxEnergy(card);
  if (max <= 0) return 0;
  final stored = card!.energy;
  return _clamp(stored ?? max, 0, max * PlayerEnergy.overfillMult);
}

/// Raw fitness fraction, up to the overfill multiple. Display only.
double rawEnergyPct(CardInstance? card) {
  final max = getMaxEnergy(card);
  return max <= 0 ? 0 : rawEnergy(card) / max;
}

/// Combined fatigue multiplier for a card — at or below 1 means it tires more
/// slowly. The product of the stamina trait and the team-wide Kit Sponsor
/// conditioning. Both drain AND recovery read this, so throughput stays flat.
double fatigueMult(CardInstance? card, Map<String, dynamic>? state) {
  var k = 1.0;

  // Explicit override, for tests and forced scenarios.
  final override = card?.raw['_staminaDrainMult'];
  if (override is num && override > 0) k *= override;

  // Stamina trait (Iron Lungs) slows this player's drain.
  final pos = getPlayerDef(card?.definitionId)?.position;
  final traitK = getTraitBonus(card, pos).staminaMult;
  if (traitK > 0) k *= traitK;

  final clubAssets = state?['clubAssets'];
  k *= sponsorStaminaMult(
    clubAssets is Map<String, dynamic> ? clubAssets : null,
  );
  return k;
}

double _ageMult(CardInstance? card) =>
    1 + PlayerEnergy.ageDrainPerSeason * (card?.seasonsPlayed ?? 0);

/// Who works hardest in-match: TACTIC bias times MATCHUP bias. Only the
/// temporary in-match dip is positional; the persistent grind stays uniform.
///
/// TACTIC — all-out attack loads the forwards, park the bus the defenders,
/// high press everyone. Overall magnitude is set separately; this only shifts
/// WHICH line tires.
const Map<String, Map<String, double>> _tacticPos = {
  'allOutAttack': {'GK': 0.85, 'DEF': 0.85, 'MID': 1.05, 'FWD': 1.35},
  'parkTheBus': {'GK': 1.00, 'DEF': 1.35, 'MID': 1.00, 'FWD': 0.80},
  'highPress': {'GK': 1.00, 'DEF': 1.12, 'MID': 1.15, 'FWD': 1.12},
  'counterAttack': {'GK': 0.95, 'DEF': 1.05, 'MID': 1.05, 'FWD': 0.95},
  'balanced': {'GK': 0.90, 'DEF': 1.00, 'MID': 1.05, 'FWD': 1.00},
};

/// Rating-points of duel gap that map to the cap.
const double _matchupScale = 25;

double _duelMult(double delta) =>
    1 + math.max(-0.35, math.min(0.35, delta / _matchupScale));

/// A matchup's four ratings, driving who is under pressure.
typedef Matchup = ({double ourAtk, double ourDef, double oppAtk, double oppDef});

const Matchup neutralMatchup = (ourAtk: 0, ourDef: 0, oppAtk: 0, oppDef: 0);

/// MATCHUP — their attack against our defence drives DEFENDER load; our attack
/// against their defence drives FORWARD load. A side outmatched in its duel
/// works harder. Keepers and midfielders take the tactic bias only.
double positionDrainMult(
  String? position, [
  String strategyId = 'balanced',
  Matchup matchup = neutralMatchup,
]) {
  final table = _tacticPos[strategyId] ?? _tacticPos['balanced']!;
  final tac = table[position] ?? 1;

  var mu = 1.0;
  if (position == 'DEF') {
    mu = _duelMult(matchup.oppAtk - matchup.ourDef);
  } else if (position == 'FWD') {
    mu = _duelMult(matchup.ourAtk - matchup.oppDef);
  }
  return tac * mu;
}

/// LAYER 2 — the in-match dip, in fitness POINTS, for playing [minutes].
///
/// Proportional to the player's max so all ratings dip by the same percentage,
/// scaling with strategy, age and the fatigue perk. This is the TEMPORARY
/// weakening the match sim and live badge read; it is never persisted and rests
/// off at full time.
double drainForMinutes(
  CardInstance? card,
  double minutes,
  String? strategyId,
  Map<String, dynamic>? state, [
  Matchup matchup = neutralMatchup,
]) {
  if (card == null || minutes <= 0) return 0;
  final max = getMaxEnergy(card);
  if (max <= 0) return 0;

  final stratMult = PlayerEnergy.strategyDrainMult[strategyId] ?? 1.0;
  final base = (minutes / 90) * PlayerEnergy.inMatchDipPct * max;
  final pos = getPlayerDef(card.definitionId)?.position;

  return base *
      stratMult *
      _ageMult(card) *
      fatigueMult(card, state) *
      positionDrainMult(pos, strategyId ?? 'balanced', matchup);
}

/// One entry in a strategy timeline: the tactic in force from [min] onward.
typedef StrategyLogEntry = ({double min, String id});

/// In-match dip accrued by game-minute [uptoMin] under a strategy TIMELINE, so
/// a mid-match tactic switch changes the drain rate only from the switch minute
/// onward — it never reprices fatigue already accrued under the old tactic.
///
/// [graceMins] shifts the drain window: minutes before it drain nothing.
double drainForStrategyLog(
  CardInstance? card,
  List<StrategyLogEntry> log,
  double uptoMin,
  double graceMins,
  Map<String, dynamic>? state, [
  Matchup matchup = neutralMatchup,
]) {
  if (card == null || log.isEmpty) return 0;

  double eff(double m) => math.max(0, m - graceMins);

  var total = 0.0;
  for (var i = 0; i < log.length; i++) {
    final end = i + 1 < log.length ? math.min(log[i + 1].min, uptoMin) : uptoMin;
    final span = eff(end) - eff(log[i].min);
    if (span > 0) {
      total += drainForMinutes(card, span, log[i].id, state, matchup);
    }
  }
  return total;
}

/// LAYER 1 — the persistent fitness cost, in fitness POINTS, for actually
/// playing [minutesPlayed]. The fatigue perk applies here AND to recovery by
/// the same factor, so throughput is unchanged.
double persistentMatchCost(
  CardInstance? card,
  double minutesPlayed,
  String? strategyId,
  Map<String, dynamic>? state,
) {
  if (card == null || minutesPlayed <= 0) return 0;
  final max = getMaxEnergy(card);
  if (max <= 0) return 0;

  final stratMult = PlayerEnergy.strategyDrainMult[strategyId] ?? 1.0;
  final base = (minutesPlayed / 90) * PlayerEnergy.matchFitnessCostPct * max;
  return base * stratMult * _ageMult(card) * fatigueMult(card, state);
}

/// Applies a drain, eating any overfill buffer first. Mutates and returns the
/// card.
CardInstance? applyDrain(CardInstance? card, double points) {
  if (card == null) return card;
  final max = getMaxEnergy(card);
  card.raw['energy'] = _clamp(
    rawEnergy(card) - points,
    0,
    max * PlayerEnergy.overfillMult,
  );
  return card;
}

/// Recovers every player card by real time elapsed since its
/// `energyUpdatedAt`. Pro mode only — called from the idle tick. Mutates state
/// in place and returns the total points recovered.
double processPlayerEnergyRegen(Map<String, dynamic>? state, int nowMs) {
  final settings = state?['settings'];
  if (settings is! Map || settings['hardMode'] != true) return 0;

  final grid = state?['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  if (cells is! List) return 0;

  var recovered = 0.0;
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card == null) continue;

    final max = getMaxEnergy(card);
    if (max <= 0) continue;

    // Raw, so an overfill buffer is not clamped away.
    final cur = rawEnergy(card);
    final last = (card.raw['energyUpdatedAt'] as num?)?.toInt() ?? nowMs;
    final elapsed = nowMs - last;

    if (elapsed <= 0) {
      card.raw['energyUpdatedAt'] = nowMs;
      card.raw['energy'] ??= cur;
      continue;
    }

    // At or above full, including a paid buffer: natural regen never adds and
    // never clamps the buffer down — it only drains through play.
    if (cur >= max) {
      card.raw['energyUpdatedAt'] = nowMs;
      continue;
    }

    // PROPORTIONAL recovery: a fraction of max per ms, times the same fatigue
    // factor as the persistent cost, so throughput is unchanged.
    final gained =
        (elapsed / _fullRegenMs(state)) * max * fatigueMult(card, state);
    final next = _clamp(cur + gained, 0, max);
    recovered += next - cur;
    card.raw['energy'] = next;
    card.raw['energyUpdatedAt'] = nowMs;
  }
  return recovered;
}

/// Match-fit while the energy fraction is above the threshold, and not injured.
bool isFit(CardInstance? card) =>
    card != null && !card.injured && energyPct(card) > PlayerEnergy.fitThresholdPct;

int countFitPlayers(Map<String, dynamic>? state) {
  final grid = state?['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  if (cells is! List) return 0;
  return cells.where((c) => isFit(CardInstance.from(c))).length;
}

/// Fatigue NEVER blocks play. Like Casual mode you can field as few as three
/// players; the universal minimum-squad gate still applies in both modes.
/// Tired players just make the team weaker, so you lose more — you are never
/// locked out. Kept as a function for call-site compatibility.
bool canFieldTeam(Map<String, dynamic>? state) => true;

/// Average persistent fitness of the players who actually play, 0..100.
///
/// Reads the XI — bench players sit fresh and would otherwise inflate it.
/// Falls back to the whole squad when no lineup is set.
int averageFitnessPct(Map<String, dynamic>? state) {
  final grid = state?['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  if (cells is! List) return 100;

  final all = [for (final c in cells) CardInstance.from(c)].nonNulls.toList();
  final byId = {for (final c in all) c.instanceId: c};

  final squad = state?['squad'];
  final lineup = squad is Map ? squad['lineup'] : null;

  var chosen = <CardInstance>[];
  if (lineup is List) {
    chosen = [
      for (final slot in lineup)
        if (slot is Map && slot['cardInstanceId'] is String)
          if (byId[slot['cardInstanceId']] case final card?) card,
    ];
  }
  if (chosen.isEmpty) chosen = all;

  var sum = 0.0;
  var n = 0;
  for (final c in chosen) {
    if (getMaxEnergy(c) <= 0) continue;
    // Raw, so a paid overfill buffer shows above 100%.
    sum += rawEnergyPct(c);
    n++;
  }
  return n == 0 ? 100 : ((sum / n) * 100 + 0.5).floor();
}

/// Live fitness and regen detail for a card, for the squad-page tap view.
///
/// Projects the stored fitness forward by real time elapsed, then reports the
/// percentage and progress toward the next whole fitness point.
({
  int pct,
  double current,
  int max,
  bool full,
  double msToNextPoint,
  double msToFull,
  double pointFraction,
})
fitnessRegenInfo(
  CardInstance? card,
  Map<String, dynamic>? state,
  int nowMs,
) {
  final max = getMaxEnergy(card);
  if (max <= 0) {
    return (
      pct: 0,
      current: 0.0,
      max: 0,
      full: true,
      msToNextPoint: 0.0,
      msToFull: 0.0,
      pointFraction: 1.0,
    );
  }

  final k = fatigueMult(card, state);
  final ratePerMs = (max / _fullRegenMs(state)) * k;
  final last = (card!.raw['energyUpdatedAt'] as num?)?.toInt() ?? nowMs;
  final elapsed = math.max(0, nowMs - last);
  final raw = rawEnergy(card);

  // At or above full, including a paid buffer up to the overfill ceiling: no
  // regen, and report the real raw percentage.
  if (raw >= max) {
    return (
      pct: ((raw / max) * 100 + 0.5).floor(),
      current: raw,
      max: max,
      full: true,
      msToNextPoint: 0.0,
      msToFull: 0.0,
      pointFraction: 1.0,
    );
  }

  final current = _clamp(raw + ratePerMs * elapsed, 0, max);
  if (current >= max) {
    return (
      pct: 100,
      current: max.toDouble(),
      max: max,
      full: true,
      msToNextPoint: 0.0,
      msToFull: 0.0,
      pointFraction: 1.0,
    );
  }

  final nextPoint = math.min(max, current.floor() + 1);
  final pointsRemaining = nextPoint - current;

  return (
    pct: ((current / max) * 100 + 0.5).floor(),
    current: current,
    max: max,
    full: false,
    msToNextPoint: ratePerMs > 0 ? pointsRemaining / ratePerMs : double.infinity,
    msToFull: ratePerMs > 0 ? (max - current) / ratePerMs : double.infinity,
    pointFraction: current - current.floorToDouble(),
  );
}

/// Refills every player card to full. A plain full reset.
void refillAllEnergy(Map<String, dynamic>? state, int nowMs) =>
    topUpAllEnergy(state, nowMs, 1);

/// Tops up every player's fitness by [frac] of their max.
///
/// With [overfill] false — the rewarded-ad refill — it caps at 100%. With it
/// true — a paid pack — it banks up to the overfill buffer. Reads raw fitness
/// so a paid pack stacks on whatever they already have.
void topUpAllEnergy(
  Map<String, dynamic>? state,
  int nowMs,
  double frac, {
  bool overfill = false,
}) {
  final grid = state?['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  if (cells is! List) return;

  for (final rawCard in cells) {
    final card = CardInstance.from(rawCard);
    if (card == null) continue;
    final max = getMaxEnergy(card);
    if (max <= 0) continue;

    final ceiling = overfill ? max * PlayerEnergy.overfillMult : max;
    card.raw['energy'] = _clamp(rawEnergy(card) + frac * max, 0, ceiling);
    card.raw['energyUpdatedAt'] = nowMs;
  }
}
