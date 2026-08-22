/// Coach Colin's read on YOUR SQUAD, when he has nothing to say about theirs.
///
/// **Thirteen `squadstate.*` keys, three or four pooled sentences each, shipped
/// in ten languages with nothing in `lib/` so much as mentioning the prefix** —
/// the largest block of unreachable copy this queue has found outside the
/// tutorial. The keys name their conditions and not one of them names its
/// THRESHOLD, which is why this sat blocked rather than guessed at: "six in ten
/// isn't bad" is a number somebody chose, and so are the twelve beside it.
///
/// This is a port of `_squadStateTip` in
/// `../merge-empire-fc/src/ui/screens/LeagueScreen.js`, thresholds and ORDER
/// both. The order is as much of the spec as the numbers are — every condition
/// below the first true one is a thing he could also have said, so moving a
/// branch changes what he talks about far more often than it looks like it
/// would.
///
/// **He is allowed to say nothing.** The last branch returns null rather than
/// reaching for filler, and the JS's own comment is the reason: the floating
/// coach appears when there is real advice, and a head that always has an
/// opinion is one nobody reads.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart' show getMaxPlayers;
import 'package:merge_empire_fc/engine/match_tactics.dart'
    show matchesPerSeason, opponentsPerSeason;
import 'package:merge_empire_fc/engine/scout_signing_engine.dart' show scoutCost;
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/i18n/i18n.dart' show tName;
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// One read, with the seed the pool is picked on.
///
/// The seed comes out of the engine rather than being rebuilt at the call site
/// because it is part of the rule: `state-s{season}-m{n}` holds Colin's wording
/// still for a whole match week, and a caller inventing its own would have him
/// rephrasing himself on every idle tick.
typedef SquadStateHint = ({
  String key,
  String seed,
  Map<String, Object?> params,
});

List<CardInstance> _squad(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  return [
    for (final c in cells) ?CardInstance.from(c),
  ];
}

/// What the coach says about the state of the club, or null when the honest
/// answer is nothing.
SquadStateHint? squadStateHint(Map<String, dynamic>? state) {
  final prog = _map(state?['progression']);
  if (state == null || prog == null) return null;

  final season = _num(prog['seasonCount'])?.toInt() ?? 1;
  final matchesPlayed = _num(prog['seasonMatchesPlayed'])?.toInt() ?? 0;
  final matchesLeft = matchesPerSeason - matchesPlayed;
  // `seasonAwardedPlayed` rather than `seasonMatchesPlayed`, matching the JS:
  // the win RATE has to be read off the same counter the wins were added to.
  final played = _num(prog['seasonAwardedPlayed'])?.toInt() ?? 0;
  final wins = _num(prog['seasonWins'])?.toInt() ?? 0;
  final energy = _num(_map(state['energy'])?['current'])?.toInt() ?? 0;

  final squad = _squad(state);
  final poorForm = squad.where((c) => c.form <= -1).length;
  final squadSize = squad.length;

  final div = getDivision('${prog['currentDivision']}');
  final seed = 'state-s$season-m$matchesPlayed';

  // **A squad that cannot field an XI, with the coin to fix it.** Ahead of
  // everything else and outside the chain, because it is the only branch that
  // asks whether the player can ACT on the advice — telling someone to scout
  // when they cannot afford to is the coach naming a problem twice.
  if (squadSize < 3 &&
      (_num(_map(state['resources'])?['fanCoins']) ?? 0) >= scoutCost(state)) {
    return (key: 'squadstate.few_players', seed: seed, params: const {});
  }

  // Fatigue is ON here whatever the difficulty, which is the JS's call and not
  // `previewFixture`'s: this is a read on the squad as it stands rather than a
  // fixture's arithmetic, and a knackered side is a knackered side in either
  // mode.
  final rawLineup = _map(state['squad'])?['lineup'];
  final lineup = (rawLineup is List && rawLineup.length == 11)
      ? [
          for (final s in rawLineup)
            if (s is Map<String, dynamic>) s,
        ]
      : null;
  final squadRating = computeSquadRating(
    [for (final c in squad) c],
    lineup: lineup?.length == 11 ? lineup : null,
    definitionRatios: _map(state['definitionRatios']) ?? const {},
    fatigue: true,
  );

  // The ratings the season actually DREW, and the division's advertised band
  // only as a fallback — a save whose opponents have been rolled knows exactly
  // what it is up against, and the band is a wide guess by comparison.
  final oppRatings = _map(prog['seasonOpponentRatings']);
  final drawn = <double>[
    for (var i = 0; i < opponentsPerSeason; i++)
      if (_num(oppRatings?['s${season}_o$i']) case final r?) r.toDouble(),
  ];
  final oppAvg = drawn.isNotEmpty
      ? drawn.reduce((a, b) => a + b) / drawn.length
      : (div.opponentRatingRange.$1 + div.opponentRatingRange.$2) / 2;
  final oppMax = drawn.isNotEmpty
      ? drawn.reduce(math.max)
      : div.opponentRatingRange.$2.toDouble();

  final tiers = [
    for (final c in squad) getPlayerDef(c.definitionId)?.tier ?? 1,
  ];
  final bronzeHeavy =
      tiers.isNotEmpty && tiers.where((t) => t <= 2).length / tiers.length >= 0.6;

  // An unowned asset is not a tier-one asset — it is no asset — so it is
  // filtered out rather than counted as 1, which would have every fresh save
  // told its facilities were basic before it owned any.
  final assetTiers = <int>[
    for (final a in (_map(state['clubAssets']) ?? const {}).values)
      if (_map(a)?['owned'] == true) _num(_map(a)?['tier'])?.toInt() ?? 1,
  ];
  final allT1Assets = assetTiers.isNotEmpty && assetTiers.every((t) => t <= 1);

  if (energy <= 2) {
    return (key: 'squadstate.low_energy', seed: seed, params: const {});
  }
  if (poorForm >= 3) {
    return (key: 'squadstate.poor_form', seed: seed, params: const {});
  }
  if (played >= 3 && wins / math.max(played, 1) >= 0.6) {
    return (key: 'squadstate.form_high', seed: seed, params: const {});
  }
  if (matchesLeft <= 3) {
    // One match left is its own key rather than `{n}` reading "1 matches" —
    // and it carries `n` anyway, because the params a pooled key needs are the
    // union across its variants and a caller pays nothing for the spare.
    return (
      key: matchesLeft == 1 ? 'squadstate.run_in_one' : 'squadstate.run_in',
      seed: seed,
      params: {'n': matchesLeft},
    );
  }
  if (squadRating < oppAvg - 6) {
    // The SAME weakness, said two ways: a division that can field silver has a
    // route out of it (merge), and one that cannot has only patience.
    return (
      key: div.maxPlayerTier >= 3
          ? 'squadstate.weak_higher'
          : 'squadstate.weak_lower',
      seed: seed,
      params: const {},
    );
  }
  if (bronzeHeavy && matchesPlayed == 0 && div.maxPlayerTier >= 3) {
    return (key: 'squadstate.bronze_heavy', seed: seed, params: const {});
  }
  if (allT1Assets && assetTiers.length >= 3) {
    return (key: 'squadstate.assets_t1', seed: seed, params: const {});
  }
  if (squadSize < getMaxPlayers(state) - 4) {
    return (key: 'squadstate.thin_squad', seed: seed, params: const {});
  }
  if (matchesPlayed == 0) {
    return (
      key: 'squadstate.season_start',
      seed: seed,
      params: {'div': tName('division', {'id': div.id, 'name': div.name})},
    );
  }
  if (squadRating > oppMax + 3) {
    return (key: 'squadstate.strong', seed: seed, params: const {});
  }
  // Nothing genuinely contextual. He stays quiet.
  return null;
}
