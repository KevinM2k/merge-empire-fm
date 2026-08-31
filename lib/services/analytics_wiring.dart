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
/// **EVERY NAME HERE IS THE JS'S NAME, and that is not a style preference.**
/// The port ships under `com.mergeempirefc.app` — the primary key of the
/// already-published app — against the same `merge-empire-fc` Firebase project,
/// so an updating device carries on writing into the property FC has been
/// filling for its whole life. An event this file renames is therefore not a
/// tidier name for the same series: it ENDS one series and starts another at
/// the update boundary, which reads on the dashboard as every established
/// player abruptly stopping and a cohort of strangers arriving. That is why
/// `merge_complete`, `match_complete` and `season_complete` are gone — they
/// were invented here, and the JS has been sending `merge`, `match_played` and
/// `season_end` for the life of the app. The repo already states this rule for
/// one event and this is the general case of it: the JS's `CLAUDE.md` keeps
/// `difficulty_switch` sending `standard` for a mode the UI renamed to Casual
/// "so the funnel stays comparable with pre-rename data".
///
/// Events with NO counterpart in the JS are additions rather than renames and
/// stay as they are — `season_start`, `achievement_unlocked`, `quest_*`,
/// `cup_won`, `cup_eliminated`, `login`/`logout`, `ad_stack_blocked`. Nothing
/// historical is broken by a series that begins here.
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

/// How this file reaches the save.
///
/// **A seam rather than an import**, for the reason the whole bottom half of
/// the app is arranged this way: the save lives behind Riverpod, this file is
/// Flutter-free, and half of what an event needs — the division a merge
/// happened in, the season a table finished in, the six user properties — is a
/// fact about the save rather than about the signal that fired. `game_host`
/// installs it once it has booted one; before that every reader answers null
/// and every event falls back to `unknown`, which is honest.
Map<String, dynamic>? Function()? _readState;

/// Let this file read the live save. Pass null to take it back off.
///
/// Returns the reader being replaced, so a test can restore it.
Map<String, dynamic>? Function()? setAnalyticsStateReader(
  Map<String, dynamic>? Function()? read,
) {
  final previous = _readState;
  _readState = read;
  return previous;
}

Map<String, dynamic>? _progression() => _map(_readState?.call()?['progression']);

/// The division the player is in, or `unknown`. The JS's own fallback string.
String _division() => _str(_progression()?['currentDivision']) ?? 'unknown';

/// **Casual reports as `standard`.** The mode was renamed in the UI and this
/// value deliberately was not, so the funnel stays comparable with everything
/// recorded before the rename — the JS's `CLAUDE.md` states this rule outright.
String _mode(Map<String, dynamic>? state) =>
    _map(state?['settings'])?['hardMode'] == true ? 'pro' : 'standard';

/// Push the six user properties from the live save.
///
/// Called at boot and again whenever one of them can have moved — a season
/// ending, a prestige, a sign-in. A property set only at boot describes the
/// player as they were when they opened the app, which for a long session is
/// the wrong answer to every question asked of it.
void refreshUserProps() {
  final state = _readState?.call();
  if (state == null) return;
  final progression = _map(state['progression']);
  setUserProps({
    'current_division': _str(progression?['currentDivision']) ?? 'unknown',
    'total_seasons': _num(progression?['seasonCount'])?.toInt() ?? 0,
    'is_vip': _map(state['boosts'])?['vipActive'] == true,
    'prestige_level': _num(_map(state['prestige'])?['level'])?.toInt() ?? 0,
    'game_mode': _mode(state),
    'signed_in': _map(state['leaderboard'])?['authUid'] != null,
  });
}

/// **THE SESSION, which is what the churn question is actually about.**
///
/// The JS keeps three running values in `main.js` and spends them in one event
/// when the app goes away: what the player was last doing, how long ago, and
/// how long they had been playing. A `screen_view` says where somebody was;
/// only this says what they were in the middle of when they put the phone down.
int _sessionStartedAt = 0;
String _lastAction = 'none';
int _lastActionAt = 0;

/// Record that the player did something, for [logAppBackgrounded].
void _didAction(String action) {
  _lastAction = action;
  _lastActionAt = DateTime.now().millisecondsSinceEpoch;
}

/// Start the session clock. Called at boot.
void startAnalyticsSession({int? at}) {
  _sessionStartedAt = at ?? DateTime.now().millisecondsSinceEpoch;
  _lastAction = 'none';
  _lastActionAt = 0;
}

/// **The first event of the session, once there is a save to describe it.**
///
/// It cannot go where `startAnalytics` does: that runs before the store is
/// read, so a boot event fired there would report `unknown` for every field it
/// exists to carry. The JS has the same shape — `initAnalytics().then(...)`
/// reads the state singleton once boot has one.
void logAppBoot({int? at}) {
  startAnalyticsSession(at: at);
  final state = _readState?.call();
  final progression = _map(state?['progression']);
  setAnalyticsUserId(_map(state?['leaderboard'])?['playerId']);
  refreshUserProps();
  logAppEvent('app_boot', {
    'division': _str(progression?['currentDivision']) ?? 'unknown',
    'season': _num(progression?['seasonCount']) ?? 0,
    'mode': _mode(state),
  });
}

/// **The last event of the session**, fired when the app is really going away
/// — not for a notification shade, which is the distinction `game_host` draws.
///
/// `time_since_action_s` is -1 rather than 0 when nothing was ever done, which
/// is the JS's own encoding: a player who opened the app and did nothing at all
/// is the single most interesting row in this event, and a zero would file them
/// alongside somebody who had just merged.
void logAppBackgrounded({int? at}) {
  final now = at ?? DateTime.now().millisecondsSinceEpoch;
  final state = _readState?.call();
  logAppEvent('app_backgrounded', {
    'active_tab': currentScreen ?? 'unknown',
    'session_duration_s': _sessionStartedAt > 0
        ? ((now - _sessionStartedAt) / 1000).round()
        : 0,
    'last_action': _lastAction,
    'time_since_action_s': _lastActionAt > 0
        ? ((now - _lastActionAt) / 1000).round()
        : -1,
    'tutorial_done': _map(state?['tutorial'])?['done'] == true,
    'division': _division(),
  });
}

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
      final to = _str(d['newDivision']) ?? 'unknown';
      final outcome = _str(d['outcome']) ?? 'unknown';
      // **`from_division` / `to_division`, which are the JS's names for these.**
      // `position` and `payout_band` have no JS counterpart and are kept: they
      // are additions to an existing event rather than a rename of one, and a
      // param nothing reads costs a dashboard nothing.
      logAppEvent('season_end', {
        'from_division': _str(d['oldDivision']) ?? 'unknown',
        'to_division': to,
        'outcome': outcome,
        'season': _num(_progression()?['seasonCount']) ?? 0,
        'position': _num(d['position']) ?? 0,
        'payout_band': bucketCoins(_num(d['payout']) ?? 0),
      });
      // **The ladder, as its own event.** `season_end` says a promotion
      // happened; this says WHICH rung was reached, which is the one series
      // that answers how far players actually get before they stop. Only on a
      // promotion — a division arrived at by relegation is not reaching it.
      if (outcome == 'promoted') {
        logAppEvent('division_reached', {'division': to});
      }
      // The division and the season count have both just moved, and a user
      // property that is only set at boot describes the player as they were
      // when they opened the app rather than as they are.
      refreshUserProps();
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
      // `to_pro` is the JS's field and rides the payload because the flag is
      // written by the card AFTER `performPrestige` returns — see the ordering
      // note in `ui/popups/prestige_card.dart`. Read from the save here it
      // would always be the pre-switch value.
      final toPro = d['toPro'] == true;
      logAppEvent('prestige', {
        'level': _num(d['level']) ?? 0,
        'to_pro': toPro,
        'multiplier': _num(d['multiplier']) ?? 0,
      });
      // **Prestiging into Pro is a mode switch and is reported as one**, with
      // the JS's own `source`. It is the one difficulty change the port can
      // make — the Settings switch the JS also logs from has no screen here
      // yet — so without this the whole `difficulty_switch` funnel is empty.
      if (toPro) {
        logAppEvent('difficulty_switch', {
          // `standard`, not `casual`: the mode was renamed in the UI and this
          // value deliberately was not. See the head of this file.
          'from': 'standard',
          'to': 'pro',
          'source': 'prestige_popup',
          'prestige_level': _num(d['level']) ?? 0,
        });
      }
      refreshUserProps();
    });

    // **A match, and NOT from `match:complete`.** That event was a dead letter
    // when this was written — nothing in `lib/` emitted it, though `game_host`
    // subscribed — and the play button now fires it at full time for a league
    // fixture. It is still the wrong hook HERE: it does not fire for a cup tie,
    // and analytics wants every match. `match:close` is what the play button
    // fires on the way out, for a league fixture and a cup tie alike.
    // **`match:close` no longer reports.** The JS's `match_played` carries the
    // division, the result and the fixture number, and none of those are on
    // this signal — it fires when the SCREEN closes, with an empty payload. It
    // is logged from `engine/match_orchestration.dart` instead, at the moment
    // the match is decided, which is where the JS logs it too. A paramless
    // second event per match beside it would double every match count.
    _listen('match:close', (_) => _didAction('match'));

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
    _listen('merge:complete', (args) {
      _didAction('merge');
      // `merge`, the JS's name, with the tier the card BECAME. Tier is the
      // whole point of the event: a merge at tier 2 is the tutorial and a merge
      // at tier 8 is the end of the game, and one undifferentiated count cannot
      // tell them apart.
      logAppEvent('merge', {
        'tier': _num(_map(args)?['tier']) ?? 0,
        'division': _division(),
      });
    });

    // **ACCOUNTS.** A signed-in player is a player whose save survives a lost
    // phone, and the sign-in rate is the only thing that predicts how many
    // reinstalls come back rather than starting over.
    _listen('auth:changed', (args) {
      final uid = _map(args)?['uid'];
      logAppEvent(uid == null ? 'logout' : 'login');
      // `signed_in` is one of the six user properties, so it moves with this.
      refreshUserProps();
    });

    // **THE ANNUAL EVENT CUP.** Two events, both the JS's, and they are a pair:
    // `wc_entered` is the denominator and `wc_won` the numerator, so a
    // completion rate for the one piece of seasonal content in the game falls
    // out of them. `first_win` separates a maiden title from a repeat — the
    // prize is only paid once, and summing them would say the reward went out
    // far more often than it did.
    _listen('event:cup-started', (args) {
      final d = _map(args);
      logAppEvent('wc_entered', {
        'event_id': _str(d?['eventId']) ?? 'unknown',
        'nation': _str(d?['playerNation']) ?? 'none',
      });
    });

    _listen('event:cup-won', (args) {
      final d = _map(args);
      logAppEvent('wc_won', {
        'event_id': _str(d?['eventId']) ?? 'unknown',
        'nation': _str(d?['playerNation']) ?? 'none',
        'first_win': d?['firstWin'] == true,
      });
    });

    // **NAMING THE CLUB, which is the first thing the game asks of anybody.**
    // The JS logs all three because they are the top of the funnel: the card
    // being shown, the name being taken, and the auto-name a save gets when it
    // is never shown at all. A drop between the first two is a player who put
    // the game down on its opening screen.
    _listen('club:name-card-shown', (args) {
      logAppEvent('club_name_modal_shown', {
        'is_first_time': _map(args)?['isFirstTime'] == true,
      });
    });

    _listen('club:renamed', (args) {
      final d = _map(args);
      if (d == null) return;
      logAppEvent('club_name_confirmed', {
        'used_suggestion': d['usedSuggestion'] == true,
        'used_generate_btn': d['usedGenerateBtn'] == true,
        'time_to_confirm_ms': _num(d['timeToConfirmMs']) ?? 0,
        'name_length': _num(d['nameLength']) ?? 0,
      });
    });

    _listen('club:name-auto-assigned', (args) {
      logAppEvent('club_name_auto_assigned', {
        'name_length': _num(_map(args)?['nameLength']) ?? 0,
      });
    });

    // **RENAMING A PLAYER is an ATTACHMENT signal**, which is why the JS
    // counts it: nobody names a card they are about to sell. `tier` says which
    // cards earn that, and the reset is its own event because undoing a name
    // is not the same act as choosing one.
    _listen('player:renamed', (args) {
      final d = _map(args);
      if (d == null) return;
      final tier = _num(d['tier']) ?? 0;
      if (d['reset'] == true) {
        logAppEvent('player_rename_reset', {'tier': tier});
      } else {
        logAppEvent('player_renamed', {
          'name_length': (_str(d['name']) ?? '').length,
          'tier': tier,
        });
      }
    });

    // **THE STORE REVIEW SHEET, counted where it is asked for.** `prompt_count`
    // is what says whether the lifetime cap is doing its job, and the trigger
    // separates the two moments the game chooses to ask.
    _listen('rating:shown', (args) {
      final d = _map(args);
      logAppEvent('rating_shown', {
        'prompt_count': _num(d?['promptCount']) ?? 0,
        'trigger': _str(d?['trigger']) ?? 'match',
        'matches_played': _num(d?['matchesPlayed']) ?? 0,
      });
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
