/// Auto-sell rules: per-tier "I don't want these any more" handling. Ported
/// from `../merge-empire-fc/src/engine/autoTierEngine.js`.
///
/// Late in the ladder a bronze scout result is pure busywork — you open the
/// squad, sell it, come back. A tier marked auto-sell is cashed in the moment
/// it is scouted, at flat market value with no market roll.
///
/// Rules live in `settings.autoTierActions` as `{ tier: 'sell' }`. A tier you
/// still want is simply absent, so an untouched save carries an empty map and
/// every tier behaves exactly as before.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/format.dart';

/// What a tier rule can say.
abstract final class TierAction {
  static const String keep = 'keep';
  static const String sell = 'sell';
}

/// Tiers a rule can be set for.
///
/// World Legend (8) and Football Icon (9) are deliberately absent — nobody
/// wants a chase card sold out from under them, and T9 is globally unique, so
/// an auto-sale there is unrecoverable. Enforced here rather than only hidden
/// in the UI, so a hand-edited or cloud-synced save can't turn them on either.
const List<int> autoTiers = [1, 2, 3, 4, 5, 6, 7];

/// The highest tier a rule may cover.
const int maxAutoTier = 7;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// The rule map, repaired in place if the save has none or has a broken one.
Map<String, dynamic> _rules(Map<String, dynamic>? state) {
  final settings = _map(state?['settings']);
  if (settings == null) return <String, dynamic>{};
  final existing = _map(settings['autoTierActions']);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  settings['autoTierActions'] = fresh;
  return fresh;
}

/// The rule for a tier. Anything above [maxAutoTier] never sells.
String getTierAction(Map<String, dynamic>? state, Object? tier) {
  final n = tier is num ? tier.toInt() : int.tryParse('$tier');
  if (n == null || !autoTiers.contains(n)) return TierAction.keep;
  return _rules(state)['$n'] == TierAction.sell ? TierAction.sell : TierAction.keep;
}

/// Set the rule for a tier, or clear it with [TierAction.keep]. Returns the
/// rule as it stands afterwards, which is `keep` for a tier that refused.
String setTierAction(Map<String, dynamic>? state, Object? tier, String action) {
  final rules = _rules(state);
  final n = tier is num ? tier.toInt() : int.tryParse('$tier');
  if (action == TierAction.sell && n != null && autoTiers.contains(n)) {
    rules['$n'] = TierAction.sell;
  } else if (n != null) {
    rules.remove('$n');
  }
  return getTierAction(state, tier);
}

/// Tiers set to auto-sell, ascending. Drives the Settings summary chip.
List<int> activeAutoTiers(Map<String, dynamic>? state) => [
  for (final tier in autoTiers)
    if (getTierAction(state, tier) == TierAction.sell) tier,
];

/// Switch every rule back off. Called on New Team and on prestige.
///
/// These are the one setting that isn't a preference — they are a judgement
/// about a squad ("I'm past bronze"), and a fresh career starts back in Sunday
/// League where bronze is all there is. Carrying them over would have a new
/// save auto-selling everything it scouts. Everything else in `settings` —
/// sound, language, game mode — is a preference and deliberately survives.
void clearTierActions(Map<String, dynamic>? state) {
  final settings = _map(state?['settings']);
  if (settings != null) settings['autoTierActions'] = <String, dynamic>{};
}

/// Coins a card fetches when auto-sold: flat market value, no market roll.
num autoSellPrice(
  Map<String, dynamic>? state,
  PlayerDef? def,
  CardInstance? card,
) {
  if (def == null) return 0;
  return roundCoins(baseSellPrice(def, card, state));
}

/// Would the card at [idx] be auto-sold? The same guards as [applyTierAction],
/// but it touches nothing.
///
/// The scout flow asks this up front and applies the sale only once the card
/// has finished its reveal, so "does this go?" and "make it go" are
/// deliberately separate questions.
bool willAutoSell(Map<String, dynamic>? state, List<dynamic>? cells, int idx) {
  if (cells == null || idx < 0 || idx >= cells.length) return false;
  final card = CardInstance.from(cells[idx]);
  final def = card == null ? null : getPlayerDef(card.definitionId);
  if (card == null || def == null) return false;

  // A loanee is never ours to sell. The coins would be fictional and the parent
  // club would be owed a player.
  if (card.raw['loanMatchesLeft'] != null) return false;

  // Rules stay dormant until the tutorial is done. Its early steps only advance
  // once cards actually land in the grid ("scout until you have three"), and
  // every Sunday League draw is bronze, so a live bronze rule would soft-lock
  // it. [clearTierActions] already wipes the rules on New Team and prestige;
  // this is the backstop for the paths that go through neither — a cloud save
  // restored mid-tutorial, or a hand-edited one.
  final tutorial = _map(state?['tutorial']);
  if (tutorial != null && tutorial['done'] != true) return false;

  if (getTierAction(state, def.tier) != TierAction.sell) return false;

  // Never sell the last card standing — that leaves an unplayable empty grid.
  return cells.where((c) => c != null).length > 1;
}

/// What happened to a card the tier rules were applied to.
typedef TierOutcome = ({
  String action,
  num coins,
  PlayerDef? def,
  CardInstance? card,
});

/// Apply the tier rule to the card at [idx], clearing the cell and paying out.
///
/// The guards are re-checked here rather than trusted from an earlier
/// [willAutoSell], because the scout flow leaves a reveal's worth of time
/// between the two.
TierOutcome applyTierAction(
  Map<String, dynamic> state,
  List<dynamic> cells,
  int idx,
) {
  final card = idx >= 0 && idx < cells.length
      ? CardInstance.from(cells[idx])
      : null;
  final def = card == null ? null : getPlayerDef(card.definitionId);

  if (!willAutoSell(state, cells, idx)) {
    return (action: TierAction.keep, coins: 0, def: def, card: card);
  }

  // Rival interest tracks a card leaving the squad the same way a manual sale
  // does, so an auto-sale doesn't strand a pending offer.
  notifyCardRemoved(state, card!.instanceId);
  cells[idx] = null;

  // The sale lands AFTER the batch's lineup auto-fill has run, so a sold card
  // can be holding a slot. Manual sales prune the same way.
  final lineup = _map(state['squad'])?['lineup'];
  if (lineup is List) {
    for (final slot in lineup) {
      if (slot is Map && slot['cardInstanceId'] == card.instanceId) {
        slot['cardInstanceId'] = null;
      }
    }
  }

  final coins = autoSellPrice(state, def, card);
  // Round the PRICE, not the balance — roundCoins snaps to significant steps,
  // so applying it to a large total would quietly move the player's money.
  final resources = _map(state['resources']);
  if (resources != null) {
    resources['fanCoins'] = (resources['fanCoins'] as num? ?? 0) + coins;
  }

  return (action: TierAction.sell, coins: coins, def: def, card: card);
}
