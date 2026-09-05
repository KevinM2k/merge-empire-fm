/// What Coach Colin has to say on whichever tab you are looking at. Ported from
/// `computeCoachTip` and the per-tab pipelines in
/// `../merge-empire-fc/src/ui/screens/LeagueScreen.js`.
///
/// **The pool is tab-scoped, and no tip crosses over.** That is the JS's own
/// decision and it is worth restating: a coach who says the same thing on the
/// squad screen as on the shop shelf is a banner, not a coach. Each tab asks
/// about the thing in front of you.
///
/// **The port had 120 `coach.*` strings and read four of them.** Everything here
/// was already in the catalogue, generated from the JS — the whole per-tab
/// pipeline simply had no caller, so Colin only ever existed on the Play tab as
/// a read on the next fixture.
///
/// **Order is priority.** Each pipeline returns the FIRST thing that applies, so
/// an injury outranks a merge, and a merge outranks a nudge about scouting.
/// Health and age come before anything about money.
///
/// Deliberately Flutter-free: what he says is a question about the save, and it
/// is answered without a widget so it can be tested without one.
library;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/guide_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/shell/guide.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;
int _int(Object? v) => v is num ? v.toInt() : 0;

/// The default mute after a dismissal: ten minutes, then he may say it again.
const Duration coachDismissCooldown = Duration(minutes: 10);

/// A whole day, for the tips that are about a decision rather than a moment. A
/// veteran in his final season is still in his final season ten minutes later,
/// and repeating it is nagging.
const Duration coachDayCooldown = Duration(hours: 24);

/// One thing Colin has to say, and the terms on which he says it.
typedef FloatingTip = ({
  /// What he says. Already resolved through `t()`, and already picked out of its
  /// pool — the caller does not know that a tip has variants.
  String text,

  /// Which pipeline produced it. Not shown; it is what the dismissal is keyed on
  /// when the text itself is too specific to key by.
  String category,

  /// Bypasses the dismissal cooldown. For the things that are urgent rather than
  /// merely true.
  bool priority,

  /// What a dismissal mutes. The text itself unless a tip names something else —
  /// a tip that includes a player's name would otherwise come straight back
  /// under a different name.
  String dismissKey,

  /// How long a dismissal lasts.
  Duration cooldown,
});

FloatingTip _tip(
  String text,
  String category, {
  bool priority = false,
  String? dismissKey,
  Duration cooldown = coachDismissCooldown,
}) => (
  text: text,
  category: category,
  priority: priority,
  dismissKey: dismissKey ?? text,
  cooldown: cooldown,
);

List<CardInstance?> _cells(Map<String, dynamic>? save) {
  final raw = _map(save?['grid'])?['cells'];
  return [
    for (final cell in raw is List ? raw : const []) CardInstance.from(cell),
  ];
}

List<Map<String, dynamic>>? _lineup(Map<String, dynamic>? save) {
  final raw = _map(save?['squad'])?['lineup'];
  if (raw is! List) return null;
  return [for (final slot in raw) ?_map(slot)];
}

/// Colin's read on the tab in front of the player, or null when he has nothing
/// worth interrupting for.
///
/// **The home tab returns null on purpose.** Its dock orb carries his bubble
/// already, and a floating head over a screen that has him on it is the same
/// coach twice — the JS gates the League > Overview sub-tab the same way, with an
/// external `setEnabled`.
FloatingTip? coachTipFor(Map<String, dynamic>? save, ShellTab tab) {
  if (save == null) return null;
  // **The tour outranks the pool, and is not a pool.** A player fresh out of
  // the tutorial needs "now open the Squad tab" more than a read on their
  // traits, and once they have done it the step is spent for good — see
  // `guide_engine.dart`. Not on the home tab, where his dock orb says it.
  final guide = tab == ShellTab.home
      ? null
      : guideStepFor(save, guideTabOf(tab));
  if (guide != null) {
    return _tip(guideText(guide), 'guide', dismissKey: guide.seenId);
  }
  return switch (tab) {
    ShellTab.home => null,
    ShellTab.grid => _gridTip(save),
    ShellTab.squad => _squadTip(save),
    ShellTab.club => _clubTip(save),
    ShellTab.shop => _shopTip(save),
  };
}

// ── Players (the merge grid) ────────────────────────────────────────────────

FloatingTip? _gridTip(Map<String, dynamic> save) {
  final cells = _cells(save);
  final filled = cells.nonNulls.toList();
  final count = filled.length;
  final prog = _map(save['progression']);
  final division = getDivision('${prog?['currentDivision']}');
  final seed = 'grid-s${_int(prog?['seasonCount'])}-n$count';

  // Actionable first: something to do beats something to know.
  if (filled.any((c) => c.injured)) {
    return _tip(tPoolStable('coach.grid.injury', '$seed-inj'), 'grid');
  }

  // **A pair must match on definition AND gender**, which is the actual merge
  // rule. Matching on definition alone gave false positives for a male and a
  // female of the same tier, and had him pointing at a merge that does not
  // exist. The division's ceiling counts too: a pair the league will not allow
  // is not a pair worth mentioning.
  final seen = <String>{};
  var hasPair = false;
  for (final card in filled) {
    final def = getPlayerDef(card.definitionId);
    final next = getPlayerDef(def?.mergesInto);
    if (next == null || next.tier > division.maxPlayerTier) continue;
    // `discoveryKey` is already definition-plus-gender, and it is what the
    // merge rule and the Player Index both key on — a second spelling of the
    // same pair key is a second thing to keep in step.
    if (!seen.add(card.discoveryKey)) {
      hasPair = true;
      break;
    }
  }
  if (hasPair) {
    return _tip(
      tPoolStable(
        count < 11 ? 'coach.grid.pair_under_xi' : 'coach.grid.has_pair',
        '$seed-${count < 11 ? 'pair-underxi' : 'pair'}',
      ),
      'grid',
    );
  }

  // Over eleven with nothing to merge is a different problem from over eleven
  // with a merge waiting: telling somebody to merge up when there is nothing to
  // merge reads as nonsense.
  if (count > 11) {
    return _tip(tPoolStable('coach.grid.over_xi', '$seed-extras'), 'grid');
  }
  if (count == 11) return _tip(t('coach.grid.full_xi'), 'grid');
  if (count > 0) {
    return _tip(tPoolStable('coach.grid.under_xi', '$seed-undersize'), 'grid');
  }
  return null;
}

// ── Squad ───────────────────────────────────────────────────────────────────

FloatingTip? _squadTip(Map<String, dynamic> save) {
  final cards = _cells(save).nonNulls.toList();
  final prog = _map(save['progression']);
  final seed = 'squad-s${_int(prog?['seasonCount'])}-n${cards.length}';

  final injured = cards.where((c) => c.injured).toList();
  if (injured.length >= 2) {
    return _tip(
      tPoolStable('coach.squad.injury_crisis', '$seed-injcrisis', {
        'n': injured.length,
      }),
      'squad',
    );
  }

  String nameOf(CardInstance card) =>
      getCardName(card.raw, t('common.veteran'));

  // Age, in the order it becomes urgent. A player retires after fifteen
  // seasons, so the last one is a warning and the two before it are a window.
  final finalSeason = cards.where((c) => c.seasonsPlayed >= 14).toList();
  if (finalSeason.isNotEmpty) {
    return _tip(
      t('coach.squad.final_season', {
        'names': finalSeason.map(nameOf).join(', '),
      }),
      'squad',
      // A day, not ten minutes: he is still in his final season either way, and
      // saying so every ten minutes is nagging.
      cooldown: coachDayCooldown,
    );
  }
  final sellNow = cards.where((c) => c.seasonsPlayed == 13).toList();
  if (sellNow.isNotEmpty) {
    return _tip(
      t('coach.squad.sell_now', {'name': nameOf(sellNow.first)}),
      'squad',
    );
  }
  final declining = cards
      .where((c) => c.seasonsPlayed >= 10 && c.seasonsPlayed < 13)
      .toList();
  if (declining.isNotEmpty) {
    final card = declining.first;
    return _tip(
      t('coach.squad.declining', {
        'name': nameOf(card),
        'pen': agingPenalty(card.seasonsPlayed),
        'left': 15 - card.seasonsPlayed,
      }),
      'squad',
    );
  }
  final veterans = cards
      .where((c) => c.seasonsPlayed >= 7 && c.seasonsPlayed < 10)
      .toList();
  if (veterans.isNotEmpty) {
    final card = veterans.first;
    return _tip(
      t('coach.squad.veteran', {
        'name': nameOf(card),
        'seasons': card.seasonsPlayed,
      }),
      'squad',
    );
  }

  if (cards.where((c) => _num(c.raw['form']) <= -1).length >= 3) {
    return _tip(tPoolStable('coach.squad.poor_form', '$seed-form'), 'squad');
  }

  // **Traits are measured over the ELEVEN, not the grid**, because a trait does
  // nothing from the bench — counting bench cards had him telling managers with
  // a fully-kitted XI to go and roll more.
  final traits = traitCoverage(_cells(save), _lineup(save));
  if (traits.counted >= 1 && traits.withTrait == 0) {
    return _tip(
      t('hint.squad_no_traits'),
      'squad',
      dismissKey: 'squad_no_traits',
      cooldown: coachDayCooldown,
    );
  }
  if (traits.counted >= 11 && traits.withTrait > 0 && traits.ratio < 0.4) {
    return _tip(
      t('hint.squad_full_few_traits'),
      'squad',
      dismissKey: 'squad_few_traits',
      cooldown: coachDayCooldown,
    );
  }

  if (cards.length >= 3 && !cards.any((c) => c.raw['sponsor'] != null)) {
    return _tip(t('coach.squad.no_sponsor'), 'squad');
  }
  return null;
}

// ── Club ────────────────────────────────────────────────────────────────────

FloatingTip? _clubTip(Map<String, dynamic> save) {
  final owned = [
    for (final asset in (_map(save['clubAssets']) ?? const {}).values)
      ?_map(asset),
  ].where((a) => a['owned'] == true).toList();
  final seed =
      'club-s${_int(_map(save['progression'])?['seasonCount'])}'
      '-n${owned.length}';

  if (owned.isEmpty) return _tip(t('coach.club.empty'), 'club');
  if (owned.length < 3) {
    return _tip(tPoolStable('coach.club.sparse', '$seed-sparse'), 'club');
  }
  if (owned.every((a) => _num(a['tier']) <= 1)) {
    return _tip(t('coach.club.all_t1'), 'club');
  }
  return null;
}

// ── Shop ────────────────────────────────────────────────────────────────────

FloatingTip? _shopTip(Map<String, dynamic> save) {
  final coins = _num(_map(save['resources'])?['fanCoins']);
  final prog = _map(save['progression']);
  final divisionId = '${prog?['currentDivision']}';
  // **Seeded on the DIVISION, not the balance.** Shop advice only changes when
  // the player promotes or relegates; tied to the coin count it reshuffled on
  // every idle tick and flashed his head.
  final seed = 'shop-$divisionId';

  if (_cells(save).nonNulls.any((c) => c.injured)) {
    return _tip(t('coach.shop.injured'), 'shop');
  }
  if (_num(_map(save['energy'])?['current']) <= 2) {
    return _tip(
      t('coach.shop.low_energy'),
      'shop',
      dismissKey: 'shop_low_energy',
    );
  }

  final division = getDivision(divisionId);
  if (coins >= division.matchRevenueBase * 20) {
    return _tip(
      tPoolStable(
        divisionId == 'champions_cup'
            ? 'coach.shop.hoard_top'
            : 'coach.shop.hoard_normal',
        '$seed-hoard',
      ),
      'shop',
    );
  }
  // Broke: not enough for the cheapest new player at this level. The BASE rate,
  // so an Academy's discount does not quietly change what "broke" means.
  if (coins < (Scout.baseCostByDiv[divisionId] ?? Scout.baseCost)) {
    return _tip(t('coach.shop.broke'), 'shop');
  }
  return null;
}
