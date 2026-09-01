/// Gems — the hard currency. Ported from
/// `../merge-empire-fc/src/engine/gemEngine.js`.
///
/// Gems exist because coins couldn't do this job. Coins are the run's economy:
/// a reset wipes them, so anything they buy has to go back too, and a cosmetic
/// that re-locks when you take a new job is a cosmetic nobody trusts. Gems are
/// the opposite by design — PERMANENT across New Team and prestige, so
/// everything they buy is permanent too.
///
/// They come from exactly three places: lifting a cup for the first time ever,
/// a handful of one-time milestones, and an IAP. There is deliberately NO
/// coin-to-gem exchange — the moment coins can become gems, gems inherit the
/// run's inflation and stop being hard currency.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/engine/coin_sink_engine.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// The map at [key], created empty if the save hasn't got one.
Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

/// The list at [key], created empty if the save hasn't got one.
List<dynamic> _list(Map<String, dynamic> owner, String key) {
  final existing = owner[key];
  if (existing is List) return existing;
  final fresh = <dynamic>[];
  owner[key] = fresh;
  return fresh;
}

/// Gems for lifting each cup, by cup id.
///
/// ONE GEM, FLAT, first lift of each cup only. Cut three times: 2/4/6/10, then
/// 1/2/3/4, then 1/2/3/5, now one across the board.
///
/// The scaling table is gone on purpose, and it used to cost something real — a
/// cup win paid nothing a player could spend on its own, because the cheapest
/// item was two gems. The Scout Voucher is one now, so a first lift buys
/// exactly one thing: a gamble on a free scout. That is the right size for it.
/// The four cups together are still four gems, under a single look pack. What
/// they are is a TASTE — the first gems most players ever hold, enough to make
/// the balance in the HUD stop reading as zero, and now enough to spend.
///
/// Why not more: lifting a cup already pays coins, a sponsor drop AND a
/// cosmetic unlock, so gems were a fourth reward stacked on three, and the four
/// cups used to be 44% of everything a player could ever earn.
const Map<String, int> gemCupRewards = {
  'regional_cup': 1,
  'national_cup': 1,
  'continental_cup': 1,
  'world_club_cup': 1,
};

/// Gems to unlock ONE look pack. Every pack, the same price.
///
/// Five gems is about £1 at the 20p anchor and about 57p at the best bundle
/// rate — an easy yes on impulse, and the right shelf for something that
/// changes nothing but how the manager looks.
///
/// ONE PRICE, deliberately. It ran as two bands because the dearer one had no
/// rewarded-video route and so wasn't capped by what skipping a video is worth.
/// Every item is watchable now, which took that argument away and left two
/// prices for the same thing.
///
/// The Style Vault's ceiling is (best gem rate × the full set), so it moves
/// ONLY when this number, the pack count, or the bundle ladder moves.
const int packGemCostValue = 5;

/// What a pack costs. Flat across the catalogue — the function is kept so call
/// sites read as a price lookup rather than a constant, and so a future band
/// can land here instead of in every caller.
int packGemCost() => packGemCostValue;

/// Gems this cup win is worth. An unknown id pays nothing rather than throwing:
/// an event cup added later shouldn't mint currency by accident.
int gemsForCupWin(String? cupId) => gemCupRewards[cupId] ?? 0;

/// Lazily build the ledger so a save predating it can't throw.
Map<String, dynamic> _grants(Map<String, dynamic> state) {
  final existing = _map(state['gemGrants']);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{
    'tutorialGranted': false,
    'divisionFirsts': <dynamic>[],
    'cupFirsts': <dynamic>[],
    'firstPrestigeDone': false,
    'chlTitleThisRun': false,
  };
  state['gemGrants'] = fresh;
  return fresh;
}

/// Current balance. Tolerates a save with no resources block at all.
int getGems(Map<String, dynamic>? state) {
  final n = _num(_map(state?['resources'])?['gems']);
  if (n == null || !n.isFinite || n <= 0) return 0;
  return n.floor();
}

/// Can this save afford [cost] gems right now?
bool canAffordGems(Map<String, dynamic>? state, int cost) => getGems(state) >= cost;

/// Add gems and announce it. [reason] is for analytics only.
///
/// Returns the number actually added, so a caller can skip the toast on zero.
int addGems(Map<String, dynamic>? state, num amount, [String reason = 'unknown']) {
  if (state == null || !amount.isFinite) return 0;
  final n = amount.floor();
  if (n <= 0) return 0;
  final resources = _branch(state, 'resources');
  resources['gems'] = getGems(state) + n;
  emit('gems:updated', resources['gems']);
  // **`gems:updated` carries a BALANCE and nothing else**, so no listener could
  // tell a welcome gift from a purchase and the three `gems.toast.*` strings
  // sat translated in ten languages with nothing able to reach one — a player
  // could be handed gems by four different faucets and never be told by any of
  // them. This one carries the reason; `toastFor` decides which reasons are
  // worth a line, and the answer is most of them are not.
  emit('gems:granted', {'amount': n, 'reason': reason});
  logAppEvent('gems_earned', {
    'amount': n,
    'reason': reason,
    'balance': resources['gems'],
  });
  return n;
}

/// Spend gems, or refuse and change nothing.
///
/// The affordability check and the debit are one step, so there is no window
/// between them for a second tap to slip through.
bool spendGems(Map<String, dynamic>? state, num cost, [String reason = 'unknown']) {
  if (state == null || !cost.isFinite) return false;
  final n = cost.floor();
  if (n < 0) return false;
  if (getGems(state) < n) return false;
  final resources = _map(state['resources'])!;
  resources['gems'] = getGems(state) - n;
  emit('gems:updated', resources['gems']);
  logAppEvent('gems_spent', {
    'amount': n,
    'reason': reason,
    'balance': resources['gems'],
  });
  return true;
}

/// Award the gems for a cup win — the FIRST time this player lifts that cup,
/// ever. Later wins pay their coins and sponsor drop as always, but no gems.
///
/// This used to pay every time, and it can't: cups run once a season and a run
/// is about twenty seasons, so a repeatable award compounds into pounds of free
/// currency per run. "The first time you lift this trophy" is a milestone; the
/// fifth time is routine, and routine is what a hard currency must never pay
/// for.
///
/// Keyed on the LIFETIME ledger, so a New Team reset cannot re-arm it.
int awardCupGems(Map<String, dynamic> state, String? cupId) {
  final amount = gemsForCupWin(cupId);
  if (amount <= 0) return 0;
  final g = _grants(state);
  final firsts = _list(g, 'cupFirsts');
  if (firsts.contains(cupId)) return 0;
  firsts.add(cupId);
  return addGems(state, amount, 'cup_first_win');
}

// ── One-time faucets ────────────────────────────────────────────────────────
//
// Cup wins are the earned route, but they don't unlock until Regional League —
// the third division. A player can therefore reach the Shop, see a gems section
// and a Style Vault, and have no idea what a gem is worth because they have
// never held one. These faucets fix that, and mark the moments the cup ladder
// doesn't cover.
//
// THE RULE THAT MATTERS: every one of these reads a LIFETIME ledger, never a
// per-run flag. Several per-run flags in this codebase are cleared on reset by
// design so content can be re-earned. A gem award keyed off one of those is
// farmable by New Team spam — the same shape as the fixed bug where
// wonChampionsCup survived resets and let players inflate prestige level with
// no matches played. Gems are real money, so that leak is real money per reset.
//
// THE OTHER RULE: these are deliberately SMALL. The campaign's reward currency
// is coins; the honest way to get a wallet full of gems is to buy them. Every
// faucet exists to mark a moment and teach the exchange rate, not to fund a
// player — so each pays a gem or two, and only the tutorial pays a whole pack.

/// The one-time milestone payouts.
const Map<String, int> gemAwards = {
  'tutorial': 5, // exactly one look pack — enough to learn what a gem buys
  'divisionFirst': 1, // Elite / Continental / Champions, first time ever
  'firstPrestige': 2,
  'chlTitle': 1, // winning the top division outright, once per run
  'prestige': 2,
  'streak7': 2, // first seven-day login streak, ONCE EVER
};

/// Divisions that pay a first-reach bonus. The early ladder pays coins only.
const List<String> gemDivisionFirsts = [
  'elite_league',
  'continental',
  'champions_cup',
];

/// The onboarding grant. Load-bearing rather than generous: cups are the only
/// other route and they don't start until the third division, so without this a
/// new player meets the gem shop with an empty wallet and no idea what the
/// currency is for. It is exactly one look pack — enough to spend immediately.
int grantTutorialGems(Map<String, dynamic> state) {
  final g = _grants(state);
  if (g['tutorialGranted'] == true) return 0;
  g['tutorialGranted'] = true;
  return addGems(state, gemAwards['tutorial']!, 'tutorial');
}

/// First time this player has EVER reached one of the top three divisions.
///
/// Reads the lifetime ledger, never `progression.divisionsUnlocked` — that is
/// rebuilt from scratch by every reset, so keying off it would pay out again on
/// each New Team.
int grantDivisionFirstGems(Map<String, dynamic> state, String? divisionId) {
  if (!gemDivisionFirsts.contains(divisionId)) return 0;
  final g = _grants(state);
  final firsts = _list(g, 'divisionFirsts');
  if (firsts.contains(divisionId)) return 0;
  firsts.add(divisionId);
  return addGems(
    state,
    gemAwards['divisionFirst']!,
    'division_first:$divisionId',
  );
}

/// Winning the Champions League. Once per run — the flag clears on reset.
int grantChampionsTitleGems(Map<String, dynamic> state) {
  final g = _grants(state);
  if (g['chlTitleThisRun'] == true) return 0;
  g['chlTitleThisRun'] = true;
  return addGems(state, gemAwards['chlTitle']!, 'chl_title');
}

/// Prestige — the only repeatable faucet left, which is why it is the smallest
/// thing it can be and still register.
///
/// Prestige costs the player everything the run built and gems are the one
/// reward shaped to survive it, so paying nothing would be wrong; paying well
/// would make New Team spam a gem farm. The first prestige ever pays a lifetime
/// bonus on top — gated on the ledger rather than on `prestige.level` so it
/// cannot be re-earned by resetting.
int grantPrestigeGems(Map<String, dynamic> state) {
  final g = _grants(state);
  var total = addGems(state, gemAwards['prestige']!, 'prestige');
  if (g['firstPrestigeDone'] != true) {
    g['firstPrestigeDone'] = true;
    total += addGems(state, gemAwards['firstPrestige']!, 'first_prestige');
  }
  return total;
}

// ── The item catalogue ──────────────────────────────────────────────────────
//
// Look packs were the only gem sink, so a Style Vault owner had nothing left to
// spend on. These are the second sink, and between them they make the catalogue
// several times larger than the biggest pack — so no single purchase can empty
// the shop.
//
// Two rules shape what is allowed in here:
//
//   1. EXCLUSIVITY. Nothing sold for gems may also be buyable with coins. A gem
//      item you could have bought with coins is a shortcut, not something only
//      gems get, and shortcuts make a premium currency feel cheap. This is why
//      there is no gem Magic Sponge and no gem Merge All.
//   2. NEVER RAW RATING. The division bands are tuned against a no-trait maxed
//      squad with a shrinking edge per division; anything that adds ★ punches
//      straight through the curve.

/// One row of the gem catalogue.
class GemItem {
  const GemItem({
    required this.id,
    required this.cost,
    required this.permanent,
    required this.live,
    this.requires,
    this.heldWhen,
  });

  final String id;
  final int cost;

  /// A permanent unlock is recorded in `gemUnlocks` and can only be bought once.
  final bool permanent;

  /// The ship gate: an item is only OFFERED once the code that makes it do
  /// something exists, because a row that debits gems and delivers nothing is
  /// taking real money for nothing. Flip it in the same change that wires the
  /// effect, never before. A dormant row still documents the plan and keeps the
  /// catalogue maths honest.
  final bool live;

  /// A permanent this one needs first.
  final String? requires;

  /// "Is one of these already in force?" Where it answers yes the shop must not
  /// sell another, because these effects are FLAGS rather than counters: a
  /// second purchase overwrites a flag that is already set and takes the gems
  /// for nothing.
  final bool Function(Map<String, dynamic>? state)? heldWhen;
}

const List<GemItem> gemItems = [
  // ONE gem — about 20p — because it is the GAMBLE, and it has to be priced
  // against the Guaranteed Scout standing next to it. At two gems it was
  // strictly dominated: the cheapest guarantee is also two, both cover the
  // scout fee outright, and one of them promises Bronze+ while this one is 85%
  // bronze at Sunday League. Two rows at one price where one is never the right
  // choice is a dead row.
  //
  // What it buys that no voucher can is the FULL division pool. Tier 9 is cut
  // from every voucher floor to keep Football Icon a chase, so this is the only
  // thing in the shop that can draw one — the same 1% the coin scout already
  // offers at Champions, not a new route to it.
  GemItem(
    id: 'scout_voucher_gem',
    cost: 1,
    permanent: false,
    live: true,
    // ONE voucher armed at a time, across the whole ladder — an armed FLOOR
    // blocks this one too. The scout voucher engine can't be imported here
    // (that would be a cycle), so the scalar read is inlined and a test pins
    // the two halves together instead.
    heldWhen: _scoutVoucherHeld,
  ),
  GemItem(id: 'energy_refill', cost: 5, permanent: false, live: true),
  GemItem(
    id: 'trophy_polish_gem',
    cost: 8,
    permanent: false,
    live: true,
    // The shop's "already active" and the multiplier that pays it out are one
    // question, so they are one function: the guard used to read the stamp
    // itself and read a missing season more generously than the engines did.
    heldWhen: isTrophyPolishActive,
  ),
];

bool _scoutVoucherHeld(Map<String, dynamic>? state) {
  final shop = _map(state?['shop']);
  if (shop?['freeScoutReady'] == true) return true;
  final tier = _num(shop?['scoutVoucherTier']);
  return tier != null && tier.isFinite && tier > 1;
}

final Map<String, GemItem> _itemsById = {for (final i in gemItems) i.id: i};

GemItem? getGemItem(String id) => _itemsById[id];

List<GemItem> getLiveGemItems() => [for (final i in gemItems) if (i.live) i];

/// Permanent gem unlocks the player owns. Kept apart from `shop.purchasedIds`,
/// which is filtered on reset and would drop these.
bool ownsGemItem(Map<String, dynamic>? state, String id) {
  final unlocks = state?['gemUnlocks'];
  return unlocks is List && unlocks.contains(id);
}

/// Why this item can't be bought right now, or null when it can.
///
/// Split out so the Shop can grey a row with a reason instead of failing on
/// tap. One of: `unknown_item`, `not_live`, `already_held`, `already_owned`,
/// `requires`, `insufficient_gems`.
String? gemItemBlocked(Map<String, dynamic>? state, String itemId) {
  final item = getGemItem(itemId);
  if (item == null) return 'unknown_item';
  if (!item.live) return 'not_live';
  if (item.heldWhen?.call(state) ?? false) return 'already_held';
  if (item.permanent) {
    if (ownsGemItem(state, itemId)) return 'already_owned';
    final requires = item.requires;
    if (requires != null && !ownsGemItem(state, requires)) return 'requires';
  }
  if (getGems(state) < item.cost) return 'insufficient_gems';
  return null;
}

/// The outcome of a purchase.
typedef GemPurchase = ({bool ok, GemItem? item, String? reason});

/// Buy a catalogue item: debit, record the unlock, apply the effect.
///
/// The effect lives here rather than in the Shop so it can never drift from the
/// `live` flag that decides whether the item is sellable at all.
GemPurchase buyGemItem(Map<String, dynamic> state, String itemId) {
  final blocked = gemItemBlocked(state, itemId);
  if (blocked != null) return (ok: false, item: null, reason: blocked);

  final item = getGemItem(itemId)!;
  if (!spendGems(state, item.cost, 'item:$itemId')) {
    return (ok: false, item: null, reason: 'insufficient_gems');
  }

  if (item.permanent) {
    _list(state, 'gemUnlocks').add(itemId);
  }

  switch (itemId) {
    case 'scout_voucher_gem':
      _branch(state, 'shop')['freeScoutReady'] = true;
    case 'energy_refill':
      _applyEnergyRefill(state);
    case 'trophy_polish_gem':
      // Half an hour from now, so what it buys does not depend on how much of
      // the season happens to be left — see [trophyPolishMs].
      _branch(state, 'boosts')['trophyPolishUntil'] = now() + trophyPolishMs;
      emit('boosts:changed');
    default:
      break; // a dormant permanent has no effect wired yet, and isn't live
  }

  return (ok: true, item: item, reason: null);
}

/// ONE full tank, banked over the cap.
///
/// The amount is deliberately small: energy paces matches, and matches pace the
/// whole coin economy, so a refill big enough to feel premium would be selling
/// progression rather than convenience.
///
/// Denominated in TANKS rather than a fixed ten so it tracks the cap — an
/// Energy Director owner has a fifteen tank and gets fifteen. That is the right
/// way round: a permanent upgrade should make the consumables better too, and a
/// hardcoded number leaves the £7.99 purchase doing nothing here.
///
/// Pro mode has no team pip pool, so a refill banks a full extra bar of squad
/// fitness instead.
void _applyEnergyRefill(Map<String, dynamic> state) {
  if (_map(state['settings'])?['hardMode'] == true) {
    topUpAllEnergy(state, now(), 1, overfill: true);
    return;
  }
  final energy = _branch(state, 'energy');
  energy['lastRegenAt'] ??= now();
  energy['current'] =
      (_num(energy['current'])?.toInt() ?? 0) + getEnergyMax(state);
  emit('energy:updated', energy['current']);
}
