/// Selling a player.
///
/// The pricing was ported with `sell_engine`; the ACT of selling was not — it
/// lived inside the JS `SquadScreen`, like the shop consumables, the club's
/// build-and-invest and signing before it. Without it the grid is one-way:
/// cards come in and never leave.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

List<dynamic> _cells(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  return cells is List ? cells : const [];
}

int _indexOf(Map<String, dynamic>? state, String instanceId) => _cells(
  state,
).indexWhere((c) => c is Map<String, dynamic> && c['instanceId'] == instanceId);

/// Why a card cannot be sold, or null when it can.
///
/// One of: `not_found`, `on_loan`, `loaned_out`, `listed`.
String? sellBlocked(Map<String, dynamic>? state, String instanceId) {
  final idx = _indexOf(state, instanceId);
  if (idx < 0) return 'not_found';
  final card = CardInstance.from(_cells(state)[idx]);
  if (card == null) return 'not_found';
  // A loanee is not ours to sell, and a player lent out is at another club —
  // selling either breaks a contract the loan engine is still tracking.
  if (card.raw['loanMatchesLeft'] != null) return 'on_loan';
  if (card.loanedOut != null) return 'loaned_out';
  if (card.listed) return 'listed';
  return null;
}

/// What [instanceId] would fetch at [mult].
int sellPriceAt(Map<String, dynamic>? state, String instanceId, double mult) {
  final idx = _indexOf(state, instanceId);
  if (idx < 0) return 0;
  final card = CardInstance.from(_cells(state)[idx]);
  final def = getPlayerDef(card?.definitionId);
  return roundCoins(baseSellPrice(def, card, state) * mult);
}

/// How long one market quote stands before it is rolled again.
///
/// The JS refreshed on the wall clock's 30s boundaries; this is a window per
/// card, so whoever just opened the sheet gets the whole of it rather than
/// whatever is left of somebody else's.
const Duration marketWindow = Duration(seconds: 15);

/// A standing offer: the multiplier, what it pays, and when it expires.
typedef MarketQuote = ({double mult, int price, DateTime refreshAt});

final Map<String, ({double mult, DateTime refreshAt})> _offers = {};

/// The standing offer for [instanceId] — ONE roll, held for [marketWindow].
///
/// Ported from `getOrRefreshOffer` in `ui/screens/SquadScreen.js`. Rolling on
/// every open made closing and reopening the sheet a reroll, which is a slot
/// machine the player pulls rather than a market that moves.
MarketQuote marketQuote(
  Map<String, dynamic>? state,
  String instanceId, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  var offer = _offers[instanceId];
  if (offer == null || !offer.refreshAt.isAfter(at)) {
    final idx = _indexOf(state, instanceId);
    final card = idx < 0 ? null : CardInstance.from(_cells(state)[idx]);
    offer = (mult: rollMarketMult(card), refreshAt: at.add(marketWindow));
    _offers[instanceId] = offer;
  }
  return (
    mult: offer.mult,
    price: sellPriceAt(state, instanceId, offer.mult),
    refreshAt: offer.refreshAt,
  );
}

/// Forget every standing offer.
void resetMarketQuotes() => _offers.clear();

typedef SaleResult = ({bool ok, String? reason, int coins, double mult});

SaleResult _fail(String reason) =>
    (ok: false, reason: reason, coins: 0, mult: 0);

/// Sell a card at an already-rolled [mult].
///
/// The multiplier is rolled by the CALLER and passed in, because the sheet shows
/// the player what they are being offered before they accept it. Rolling again
/// here would pay out a different number from the one on screen.
SaleResult sellCard(
  Map<String, dynamic> state,
  String instanceId,
  double mult,
) {
  final blocked = sellBlocked(state, instanceId);
  if (blocked != null) return _fail(blocked);

  final idx = _indexOf(state, instanceId);
  final coins = sellPriceAt(state, instanceId, mult);
  final card = _map(_cells(state)[idx]);

  _cells(state)[idx] = null;

  final resources = _map(state['resources']);
  if (resources != null) {
    resources['fanCoins'] = ((_num(resources['fanCoins']) ?? 0) + coins)
        .toInt();
  }

  final stats = _map(state['stats']);
  if (stats != null) {
    stats['totalSold'] = ((_num(stats['totalSold']) ?? 0) + 1).toInt();
  }

  emit('player:sold', {
    'instanceId': instanceId,
    'definitionId': card?['definitionId'],
    'price': coins,
  });

  return (ok: true, reason: null, coins: coins, mult: mult);
}
