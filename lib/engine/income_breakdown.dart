/// Where the idle rate comes from. Ported from `_showIncomeBreakdown` in
/// `../merge-empire-fc/src/ui/components/HUD.js`.
///
/// **It answers "is my boost actually doing anything?" at a glance** — and, more
/// to the point here, why the number is LOWER than the multipliers promise. A
/// loaned-in player costs money every second, and until this landed the only
/// sign of it in the port was the idle bar quietly running backwards.
///
/// **Eighteen `hud.income.*` strings sat translated in all ten catalogues with
/// nothing able to reach one**, which is the same tell that found the artwork
/// and the penalty copy: where the shipped copy and the port disagree about how
/// much a screen says, the copy is right.
///
/// **Every figure comes from `idle_engine.dart`, none is recomputed here.** The
/// JS learned that the hard way and says so: reproducing the per-card maths
/// locally made an income trait invisible, because a Crowd Pleaser II card read
/// its pre-trait rate in this list while the squad sheet showed the higher one
/// and neither summed to the total underneath.
///
/// Deliberately Flutter-free: it is arithmetic about the save.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _list(Object? v) => v is List ? v : const [];
num? _num(Object? v) => v is num ? v : null;

/// One player's contribution.
typedef IncomeRow = ({
  String name,
  double perSec,
  bool sponsored,
  bool injured,
});

/// One multiplier, and what it is called.
///
/// The key and its params rather than resolved text, so the engine stays out of
/// the i18n layer and the card does the talking.
typedef IncomeFactor = ({String key, Map<String, Object?> params, double x});

typedef IncomeBreakdown = ({
  /// What the squad earns before any multiplier.
  double base,
  List<IncomeRow> players,

  /// The club-wide multiplier, and the parts it is made of.
  double multiplier,
  List<IncomeFactor> factors,

  /// Base times the multiplier, before wages.
  double gross,

  /// What is going out, and to whom.
  double wages,
  List<IncomeRow> loans,

  /// **What the wallet actually sees**, and the headline.
  ///
  /// Wages come off AFTER the multiplier, so a gross figure with a wage line
  /// under it would print a number that never arrives. Floored at zero, like
  /// the engine: wages can wipe out income but never eat the balance.
  double net,

  /// The squad cannot cover what it has borrowed. Worth saying out loud —
  /// nothing is coming in, and the loan goes back if it stays that way.
  bool capped,
});

/// Read the books.
IncomeBreakdown incomeBreakdown(Map<String, dynamic>? state) {
  final cards = [
    for (final raw in _list(_map(state?['grid'])?['cells']))
      CardInstance.from(raw),
  ];

  final players = <IncomeRow>[];
  final loans = <IncomeRow>[];
  for (final card in cards) {
    if (card == null) continue;
    final def = getPlayerDef(card.definitionId);
    if (def == null) continue;
    players.add((
      name: card.name(def.name),
      // The engine's own figure, traits, injuries, sponsor and all.
      perSec: cardBaseIncomePerSec(card),
      sponsored: card.raw['sponsor'] != null,
      injured: card.injured,
    ));
    if (card.raw['loanMatchesLeft'] != null) {
      loans.add((
        name: card.name(def.name),
        perSec: loanWagePerSec(state, card),
        sponsored: false,
        injured: false,
      ));
    }
  }
  players.sort((a, b) => b.perSec.compareTo(a.perSec));
  loans.sort((a, b) => b.perSec.compareTo(a.perSec));

  final base = computeBaseRate(cards);
  final multiplier = stateIncomeMultiplier(state);
  final gross = base * multiplier;
  final wages = totalLoanWagePerSec(state);

  return (
    base: base,
    players: players,
    multiplier: multiplier,
    factors: _factorsOf(state),
    gross: gross,
    wages: wages,
    loans: loans,
    net: math.max(0, gross - wages),
    capped: gross - wages <= 0 && wages > 0,
  );
}

/// The multiplier broken into what a player can recognise.
///
/// Same order and the same tests as `computeMultiplier`, because a list that
/// does not multiply out to the combined figure printed under it is worse than
/// no list.
List<IncomeFactor> _factorsOf(Map<String, dynamic>? state) {
  final assets = _map(state?['clubAssets']);
  final boosts = _map(state?['boosts']);
  final prestige = _map(state?['prestige']);
  final season = _num(_map(state?['progression'])?['seasonCount'])?.toInt();
  final out = <IncomeFactor>[];

  final merch = _map(assets?[AssetCategory.merch]);
  final merchTier = _num(merch?['tier'])?.toInt() ?? 0;
  if (merch?['owned'] == true && merchTier > 0) {
    out.add((
      key: 'hud.income.merch',
      params: {'name': 'asset.${AssetCategory.merch}.name', 'tier': merchTier},
      x: merchIncomeMultiplier(merchTier),
    ));
  }
  final kitSeason = _num(boosts?['kitSponsorSeason']);
  if (kitSeason != null && season != null && kitSeason == season) {
    out.add((key: 'hud.income.kit_sponsor', params: const {}, x: 1.25));
  }
  if (boosts?['incomeBoostActive'] == true &&
      (_num(boosts?['incomeBoostEndsAt']) ?? 0) > now()) {
    out.add((key: 'hud.income.boost_2x', params: const {}, x: 2));
  }
  if (boosts?['vipActive'] == true &&
      (_num(boosts?['vipExpiresAt']) ?? 0) > now()) {
    out.add((key: 'hud.income.vip_pass', params: const {}, x: 2));
  }
  final prestigeMult = _num(prestige?['incomeMultiplier']) ?? 1;
  if (prestigeMult > 1) {
    out.add((
      key: 'hud.income.prestige',
      params: {'n': _num(prestige?['level'])?.toInt() ?? 0},
      x: prestigeMult.toDouble(),
    ));
  }
  final polishSeason = _num(boosts?['trophyPolishSeason']);
  if (polishSeason != null && season != null && polishSeason == season) {
    out.add((key: 'hud.income.trophy_polish', params: const {}, x: 2));
  }
  return out;
}

/// How many player rows the card shows before it summarises the rest.
const int incomeRowsShown = 8;
