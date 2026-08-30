/// The listeners that turn an engine's announcement into an analytics event.
///
/// **`game_wiring.dart` says this file should exist**, in as many words: "Only
/// the listeners that change the SAVE live here. The ones that show a toast,
/// play a sound or log an analytics event belong to the layer that has a screen
/// and a speaker, and they subscribe to the same bus." The toasts and the sounds
/// got their half. The analytics half was never written, so the port shipped
/// with five custom events in the entire game — three of them about gems and
/// coins — and no way to see a season, a cup, an achievement or a login.
///
/// **Why a listener rather than a call in each engine.** Eighty-eight signals
/// already ride the bus with the payloads an event wants on them, and every one
/// of them is emitted from the one place that knows the fact is true. A
/// `logAppEvent` sprinkled through fourteen engines is fourteen places for the
/// next caller to forget; this is one file to read when the question is "what
/// does this game report".
///
/// The tutorial is the deliberate exception and is logged in
/// `engine/tutorial_engine.dart`, because the script has no bus event to hang
/// off and inventing three to carry analytics alone would be indirection for
/// its own sake.
///
/// **Coins are BANDED, never raw.** `bucketCoins` was ported for this and had
/// no caller anywhere in `lib/` — a raw balance is a useless dimension because
/// almost every value of it is unique, which is the JS's own reasoning.
///
/// **Nothing here is high-frequency.** `merge:happened` fires on every single
/// merge and `coins:updated` on every tick, so neither is here: an event per
/// frame is a bill and a rate limit rather than a measurement. `merge:complete`
/// — a card that actually became a better card — is the one worth counting.
///
/// Deliberately Flutter-free, so it runs under plain `dart test` alongside the
/// wiring it mirrors.
library;

import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;
String? _str(Object? v) => v is String ? v : null;

/// Subscriptions that can be undone, so a test — or a reset — can start again.
///
/// The same shape as [GameWiring] in `state/game_wiring.dart`, for the same
/// reason: a listener that outlives the thing that made it reports every event
/// twice, and that is invisible from the outside.
class AnalyticsWiring {
  final List<({String event, BusHandler handler})> _handlers = [];

  void _listen(String event, BusHandler handler) {
    on(event, handler);
    _handlers.add((event: event, handler: handler));
  }

  /// Register every listener that reports.
  void attach() {
    // **PROGRESSION.** A season is the game's unit of time, so it is the
    // denominator for nearly every other rate — and `outcome` is the one field
    // that says whether the player is climbing or stuck, which is the churn
    // question.
    _listen('season:ended', (args) {
      final d = _map(args);
      if (d == null) return;
      logAppEvent('season_complete', {
        'outcome': _str(d['outcome']) ?? 'unknown',
        'position': _num(d['position']) ?? 0,
        'old_division': _str(d['oldDivision']) ?? 'unknown',
        'new_division': _str(d['newDivision']) ?? 'unknown',
        'payout_band': bucketCoins(_num(d['payout']) ?? 0),
      });
    });

    _listen('season:started', (args) {
      logAppEvent('season_start', {
        'season': _num(_map(args)?['season']) ?? 0,
      });
    });

    // The deepest progression signal there is: a player who prestiges has
    // finished the game once and chosen to start again.
    _listen('prestige:complete', (args) {
      final d = _map(args);
      if (d == null) return;
      logAppEvent('prestige', {
        'level': _num(d['level']) ?? 0,
        'multiplier': _num(d['multiplier']) ?? 0,
      });
    });

    // **A match, from the one event that is actually emitted.** `match:complete`
    // reads like the right hook and is a dead letter — nothing in `lib/` emits
    // it, though `game_host` subscribes. `match:close` is what the play button
    // fires at full time, for a league fixture and a cup tie alike.
    _listen('match:close', (_) => logAppEvent('match_complete'));

    // **REWARDS, which is where a funnel either pays out or does not.**
    _listen('achievement:unlocked', (args) {
      final d = _map(args);
      if (d == null) return;
      // A re-unlock is a different fact from a first unlock and the two must
      // not be summed — the prestige reset hands every achievement back.
      logAppEvent('achievement_unlocked', {
        'achievement_id': _str(d['id']) ?? 'unknown',
        'category': _str(d['category']) ?? 'unknown',
        'coins_band': bucketCoins(_num(d['coinsRewarded']) ?? 0),
        're_unlock': d['isReUnlock'] == true,
      });
    });

    _listen('quest:completed', (args) {
      logAppEvent('quest_completed', {
        'scope': _str(_map(args)?['scope']) ?? 'daily',
      });
    });

    _listen('quest:claimed', (_) => logAppEvent('quest_claimed'));

    _listen('cup:won', (args) {
      final d = _map(args);
      logAppEvent('cup_won', {
        'cup_id': _str(d?['cupId']) ?? 'unknown',
        'gems': _num(d?['gems']) ?? 0,
      });
    });

    _listen('cup:eliminated', (args) {
      final d = _map(args);
      logAppEvent('cup_eliminated', {
        'cup_id': _str(d?['cupId']) ?? 'unknown',
        'round': _num(d?['round']) ?? 0,
      });
    });

    // The core loop's one milestone worth counting — see the note on frequency
    // at the head of this file.
    _listen('merge:complete', (_) => logAppEvent('merge_complete'));

    // **ACCOUNTS.** A signed-in player is a player whose save survives a lost
    // phone, and the sign-in rate is the only thing that predicts how many
    // reinstalls come back rather than starting over.
    _listen('auth:changed', (args) {
      final uid = _map(args)?['uid'];
      logAppEvent(uid == null ? 'logout' : 'login');
    });

    // **The consent gate failing is a monetisation outage**, and it looked
    // exactly like low demand from the dashboard: the ads simply do not serve.
    _listen(
      'consent:unavailable',
      (_) => logAppEvent('ad_consent_unavailable'),
    );
  }

  void detach() {
    for (final h in _handlers) {
      off(h.event, h.handler);
    }
    _handlers.clear();
  }
}
