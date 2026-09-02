/// Idle income, boosts, offline earnings and injury recovery, ported from
/// `../merge-empire-fc/src/engine/idleEngine.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/coin_sink_engine.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/time.dart';

/// An injured player earns this share of normal.
const double injuryIncomeFactor = 0.2;

const int injuryDurationMs = 30 * 60 * 1000;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// The integer tier for a club asset category — zero if not owned.
int _assetTier(Map<String, dynamic>? clubAssets, String key) {
  final a = _map(clubAssets?[key]);
  if (a == null || a['owned'] != true) return 0;
  return _num(a['tier'])?.toInt() ?? 0;
}

/// The tier PLUS how far into the next one the investment has got.
///
/// **EVERY TAP HAS TO BE WORTH SOMETHING.** The whole reward landed at the
/// tier-up, so nineteen of twenty presses bought nothing a player could see and
/// the twentieth bought all of it. Asked for directly: twenty clicks for ten
/// per cent should be half a per cent a click.
///
/// **Only the CONTINUOUS benefits read this.** A percentage can be paid out in
/// twentieths; a squad slot, a minigame and a kit colour cannot — half an
/// unlock is not a thing — so those keep the integer tier and still arrive on
/// the tier-up. That split is the whole design: this is not a fractional tier,
/// it is a fractional PAYMENT against one.
///
/// **The body moved to `data/club_assets.dart`** so the effect helpers there can
/// read it: the Kit Sponsor's fatigue half and the Academy's scout discount were
/// still stepping while everything around them paid per tap. This is the name
/// the rest of the app calls it by, and it stays.
double assetTierProgress(Map<String, dynamic>? clubAssets, String key) =>
    fractionalAssetTier(clubAssets, key);

List<CardInstance?> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [for (final c in cells) CardInstance.from(c)];
}

/// What ONE card earns per second, before club-wide multipliers.
///
/// The single source of truth for a card's income — the grid's on-card rate and
/// its progress bar are both derived from it. Anything reproducing this maths
/// locally drifted out of sync: the card footer used to ignore the income
/// traits, so a Playmaker card understated itself by up to 85%.
///
/// Borrowed cards return zero — they never earn.
double cardBaseIncomePerSec(CardInstance? card) {
  if (card == null || card.raw['borrowed'] == true) return 0;
  final def = getPlayerDef(card.definitionId);
  if (def == null) return 0;

  var income = def.idleIncomePerSec;
  if (card.injured) income *= injuryIncomeFactor;

  final sponsorMult = _num(_map(card.sponsor)?['multiplier']);
  if (sponsorMult != null) income *= sponsorMult;

  final traitIncome = getTraitBonus(card, def.position).incomeBonus;
  if (traitIncome > 0) income *= 1 + traitIncome;

  return income;
}

double computeBaseRate(List<CardInstance?> gridCells) {
  var rate = 0.0;
  for (final card in gridCells) {
    rate += cardBaseIncomePerSec(card);
  }
  return rate;
}

/// Merch Store: +5% idle income per tier, additive, capped at +40%.
///
/// Exported because the HUD breakdown and the Club screen both need to SHOW
/// this factor — when they each reproduced the maths locally they drifted, and
/// the HUD's per-row figure disagreed with the combined multiplier printed
/// underneath it.
/// **Takes a `num`, because the tier it is handed is now FRACTIONAL** — see
/// [assetTierProgress]. The HUD and the Club screen both print this factor and
/// both hand it whatever they read, so widening it here is what keeps the three
/// of them agreeing.
double merchIncomeMultiplier(num? tier) =>
    1.0 + math.min(0.40, 0.05 * (tier ?? 0));

double computeMultiplier(
  Map<String, dynamic>? clubAssets,
  Map<String, dynamic>? boosts,
  Map<String, dynamic>? prestige,
  Map<String, dynamic>? club,
  int? seasonCount,
) {
  var multiplier = merchIncomeMultiplier(
    assetTierProgress(clubAssets, AssetCategory.merch),
  );

  if (boosts?['incomeBoostActive'] == true &&
      (_num(boosts?['incomeBoostEndsAt']) ?? 0) > now()) {
    multiplier *= Idle.boostMultiplier;
  }

  // Kit Sponsor: x1.25 while the bought-for season is current. Match counters
  // were replaced with a season key so buying mid-season expires at the season
  // boundary rather than 14 matches after purchase.
  final kitSeason = _num(boosts?['kitSponsorSeason']);
  if (kitSeason != null && seasonCount != null && kitSeason == seasonCount) {
    multiplier *= 1.25;
  }

  final prestigeMult = _num(prestige?['incomeMultiplier']);
  if (prestigeMult != null && prestigeMult > 1) multiplier *= prestigeMult;

  // VIP Manager Pass: x2 while active.
  if (boosts?['vipActive'] == true &&
      (_num(boosts?['vipExpiresAt']) ?? 0) > now()) {
    multiplier *= 2.0;
  }

  // Trophy Polish: x2 idle income for the bought-for season. The same x2 is
  // applied to match revenue below, so the buff doubles ALL coin income — and
  // both read the one rule rather than restating the stamp comparison.
  multiplier *= trophyPolishMultiplierFor(boosts);

  return multiplier;
}

/// The club-wide idle multiplier currently in force.
double stateIncomeMultiplier(Map<String, dynamic>? state) => computeMultiplier(
  _map(state?['clubAssets']),
  _map(state?['boosts']),
  _map(state?['prestige']),
  _map(state?['club']),
  _num(_map(state?['progression'])?['seasonCount'])?.toInt(),
);

/// What one card contributes per second right now, club multipliers included.
/// Summing this over the grid gives exactly what the tick credits, so the
/// numbers on the cards add up to the HUD.
double cardIncomePerSec(Map<String, dynamic>? state, CardInstance? card) =>
    cardBaseIncomePerSec(card) * stateIncomeMultiplier(state);

/// Merge-grid income bar. One fill cycle is one coin payout, and the cycle
/// length derives from what the card actually earns — so bar speed genuinely
/// means how rich the player is, and a sponsor, injury, income trait or boost
/// all visibly change it.
///
/// The speed used to come from a hardcoded per-tier table. Income spans x2460
/// across the tiers while that table spanned x15, so the animation carried no
/// information: it tracked the tier badge the card already showed, not the
/// money.
///
/// The mapping is logarithmic because a linear one pegs everything above about
/// tier 5 to the floor.
class IncomeBar {
  const IncomeBar._();

  static const double minCycleSec = 0.4;

  /// Budget phones get a slower floor. The fill is compositor-only and costs
  /// nothing, but every completed cycle floats a coin label — a forced layout
  /// plus a DOM node. Holding the fastest bar to a second caps a full grid at
  /// about 30 of those a second instead of 75.
  static const double lowEndMinCycleSec = 1.0;

  static const double maxCycleSec = 6;
  static const double loRate = 0.05;
  static const double hiRate = 500;
}

double incomeBarCycleSec(
  double ratePerSec, [
  double minCycleSec = IncomeBar.minCycleSec,
]) {
  const max = IncomeBar.maxCycleSec;
  final min = clamp(minCycleSec, 0.05, max);

  // A rate of zero, or a corrupt one, parks the bar at its slowest rather than
  // dividing by zero into an infinitely fast animation.
  if (!ratePerSec.isFinite || ratePerSec <= 0) return max;

  final u = clamp(
    math.log(ratePerSec / IncomeBar.loRate) /
        math.log(IncomeBar.hiRate / IncomeBar.loRate),
    0.0,
    1.0,
  );
  return max * math.pow(min / max, u);
}

/// [squadMatchRevBonus] is the additive share from the fielded XI's traits,
/// already capped by the trait engine — pass it straight through.
double computeMatchRevenueMultiplier(
  Map<String, dynamic>? clubAssets,
  Map<String, dynamic>? boosts,
  int? seasonCount, [
  double squadMatchRevBonus = 0,
]) {
  // Stadium: x1.10 per tier, multiplicative.
  var mult = math
      .pow(1.10, assetTierProgress(clubAssets, AssetCategory.stadium))
      .toDouble();

  // TV Deal: x1.5 during the bought-for season only.
  final tvSeason = _num(boosts?['matchRevBoostSeason']);
  if (tvSeason != null && seasonCount != null && tvSeason == seasonCount) {
    mult *= 1.5;
  }

  // Trophy Polish mirrors the x2 applied to idle income, off the same rule.
  mult *= trophyPolishMultiplierFor(boosts);

  // Squad traits are additive among themselves and multiplicative with the
  // club and boost stack, so a Commanding keeper is worth more once the Stadium
  // is built — the same as every other revenue source.
  if (squadMatchRevBonus > 0) mult *= 1 + squadMatchRevBonus;

  return mult;
}

/// A loanee's wage, as a share of what a player of that calibre would earn.
///
/// Wages used to be charged per MATCH, which made them invisible: money left
/// the balance in a lump nobody connected to the player, and between matches a
/// borrowed superstar looked free. As a share of income it is on screen the
/// whole time — the income bar itself slows while you hold one.
///
/// Above 1.0 on purpose: a loanee costs more than they bring in. What you buy
/// is a player a tier above anything your division can sell you, for the
/// matches; the idle income is what you pay for it.
const double loanWageShare = 0.75;

double loanWagePerSec(Map<String, dynamic>? state, CardInstance? card) {
  if (card == null || card.raw['loanMatchesLeft'] == null) return 0;
  final def = getPlayerDef(card.definitionId);
  if (def == null) return 0;

  // Off the DEFINITION, not the card. A borrowed card's own income is zero by
  // design, so a share of what he earns would always be nothing. This is a
  // share of what a player of that calibre WOULD bring in — which means a
  // loanee costs twice: the wage, and the slot he occupies without earning.
  final income = def.idleIncomePerSec * stateIncomeMultiplier(state);
  return income.isFinite ? income * loanWageShare : 0;
}

double totalLoanWagePerSec(Map<String, dynamic>? state) {
  var total = 0.0;
  for (final card in _cells(state)) {
    total += loanWagePerSec(state, card);
  }
  return total.isFinite ? total : 0;
}

/// What the squad earns before wages come out.
double grossIncomePerSec(Map<String, dynamic>? state) =>
    computeBaseRate(_cells(state)) *
    computeMultiplier(
      _map(state?['clubAssets']),
      _map(state?['boosts']),
      _map(state?['prestige']),
      _map(state?['club']),
      _num(_map(state?['progression'])?['seasonCount'])?.toInt(),
    );

/// What actually reaches the wallet.
///
/// FLOORED AT ZERO: wages can wipe out income but never eat the balance itself.
/// An idle game that takes coins off a player who is not playing is a
/// punishment they cannot see coming and cannot stop. Hitting zero is instead
/// the trigger for the loan going back.
double netIncomePerSec(Map<String, dynamic>? state) =>
    math.max(0, grossIncomePerSec(state) - totalLoanWagePerSec(state));

/// True when the squad cannot cover what it has borrowed.
bool loanWagesUnaffordable(Map<String, dynamic>? state) =>
    totalLoanWagePerSec(state) > grossIncomePerSec(state);

double computeIncomeDelta(Map<String, dynamic>? state, num deltaMs) {
  final delta = netIncomePerSec(state) * (deltaMs / 1000);
  // Never let a non-finite value from a corrupt multiplier reach the balance —
  // one NaN would poison every future tick.
  return delta.isFinite ? delta : 0;
}

/// Offline earns a flat share of the live rate, across all divisions.
const double offlineRate = 0.05;

/// Result of an offline-earnings calculation.
typedef OfflineEarnings = ({num earned, int offlineMs});

/// Coins are NOT applied here — the welcome-back modal applies them when the
/// player taps Collect, so the HUD animates at the right moment.
OfflineEarnings processOfflineEarnings(Map<String, dynamic> state) {
  final lastSeen = _num(state['lastSeen']) ?? 0;
  final offlineMs = clamp(now() - lastSeen, 0, Idle.maxOfflineMs).toInt();
  if (offlineMs <= 0) return (earned: 0, offlineMs: 0);

  // Advance the offer cooldown stamps by the offline duration so their timers
  // do not tick while the game is closed. Without this, after any idle longer
  // than the cooldown the offers fire the moment the game opens.
  final tm = _map(state['transferMarket']);
  if (tm != null) {
    final t = now();
    for (final key in ['lastOfferAt', 'lastSponsorAt']) {
      final v = _num(tm[key]);
      if (v != null && v != 0) tm[key] = math.min(t, v + offlineMs);
    }
  }

  final hasPlayers = _cells(state).any((c) => c != null);
  if (!hasPlayers) return (earned: 0, offlineMs: offlineMs);

  // Round to a nice tens value so the modal reads "+190" rather than "+196.47".
  final rawEarned = computeIncomeDelta(state, offlineMs) * offlineRate;
  final earned = rawEarned.abs() < 10
      ? _jsRound(rawEarned)
      : _jsRound(rawEarned / 10) * 10;

  return (earned: earned, offlineMs: offlineMs);
}

int _jsRound(num v) => (v + 0.5).floor();

void expireBoosts(Map<String, dynamic> state) {
  final boosts = _map(state['boosts']);
  if (boosts == null) return;

  if (boosts['incomeBoostActive'] == true &&
      now() >= (_num(boosts['incomeBoostEndsAt']) ?? 0)) {
    boosts['incomeBoostActive'] = false;
    boosts['incomeBoostEndsAt'] = 0;
  }

  if (boosts['vipActive'] == true &&
      now() >= (_num(boosts['vipExpiresAt']) ?? 0)) {
    boosts['vipActive'] = false;
    boosts['vipExpiresAt'] = 0;
    final shop = _map(state['shop']);
    if (shop != null) shop['vipExpiresAt'] = 0;
  }
}

/// Cooldown multiplier from Training Ground tier.
double getMiniGameCooldownMult(Map<String, dynamic>? state) =>
    trainingCooldownMult(assetTierProgress(_map(state?['clubAssets']), AssetCategory.training));

/// Coin multiplier for mini-game rewards. Media Centre owns this outright —
/// Training Ground used to stack a second multiplier onto the same number.
double getMiniGameCoinMult(Map<String, dynamic>? state) =>
    mediaPayoutMult(assetTierProgress(_map(state?['clubAssets']), AssetCategory.media));

/// Max players on the grid: +1 per Academy tier, and nothing else. Gems used to
/// sell slots on top, and that ladder was pulled before release.
int getMaxPlayers(Map<String, dynamic>? state) =>
    Grid.maxPlayers + _assetTier(_map(state?['clubAssets']), AssetCategory.academy);

/// Injury recovery speed from Sponsor tier: -5% per tier, floored.
double getInjuryRecoveryMult(Map<String, dynamic>? state) {
  final tier = assetTierProgress(
    _map(state?['clubAssets']),
    AssetCategory.sponsor,
  );
  return math.max(0.60, 1 - 0.05 * tier);
}

/// How long THIS card's current injury actually lasts, after the club-wide
/// Sponsor speed-up and the card's own recovery trait.
///
/// Single source of truth, so the Squad screen's countdown matches the moment
/// the player actually heals — the UI used to show the raw duration and so
/// ignored every speed-up going.
double getEffectiveInjuryDuration(
  Map<String, dynamic>? state,
  CardInstance? card,
) {
  final def = getPlayerDef(card?.definitionId);
  // Floored so stacked recovery bonuses can never make healing instant.
  final traitRecov = math.max(
    0.25,
    1 - getTraitBonus(card, def?.position).recoveryBonus,
  );
  final base = _num(card?.raw['injuryDurationMs'])?.toDouble() ?? injuryDurationMs.toDouble();
  return base * getInjuryRecoveryMult(state) * traitRecov;
}

/// Whole minutes until this player is fit, rounded UP, or 0 when he is fit or
/// due within the minute.
///
/// **The catalogues have been promising this since the generator first ran.**
/// `hint.injured_on_grid` tells the player to "check the Squad tab to see their
/// recovery time" and `squad.badge.injured_min_left` is " ({min}m left)" in ten
/// languages — and nothing in the port could reach either, so the answer to
/// "how long is he out for" was nowhere in the game. Reported from the couch in
/// those words.
///
/// Rounded UP for the same reason [matchCooldownFreeMinsLeft] is: forty seconds
/// left is still a minute to somebody watching a number. Under a minute reads
/// as "soon" rather than as "0m", which is what `squad.badge.injured_soon` is
/// for.
int injuryMinutesLeft(
  Map<String, dynamic>? state,
  CardInstance? card, [
  int? nowMs,
]) {
  if (card == null || !card.injured) return 0;
  final left =
      getEffectiveInjuryDuration(state, card) -
      ((nowMs ?? now()) - (_num(card.raw['injuredAt']) ?? 0));
  if (left <= 0) return 0;
  return (left / 60000).ceil();
}

/// Heals expired injuries, then puts the XI back to eleven — the injury vacated
/// its victim's slot and nothing else refills it, so without this the team keeps
/// kicking off a man short long after everyone is fit again.
///
/// Pass [refillLineup] false while a match is on screen: filling the hole an
/// injury just left would be an auto-sub, and the manager makes that call.
bool processInjuryRecovery(
  Map<String, dynamic> state, {
  bool refillLineup = true,
}) {
  var anyHealed = false;

  for (final card in _cells(state)) {
    if (card == null || !card.injured) continue;
    final elapsed = now() - (_num(card.raw['injuredAt']) ?? 0);
    if (elapsed >= getEffectiveInjuryDuration(state, card)) {
      card.raw['injured'] = false;
      card.raw['injuredAt'] = null;
      card.raw['injuryDurationMs'] = null;
      anyHealed = true;
    }
  }

  if (anyHealed && refillLineup) refillLineupFromBench(state);
  return anyHealed;
}
