/// What the game actually reports, from the bus it already had.
///
/// **The port shipped with five custom events**, three of them about gems and
/// coins, so a season, a cup, an achievement, a login and every ad were
/// invisible. This is the file that decides what a dashboard can answer, so it
/// is the file worth pinning: an event silently renamed is a chart that goes
/// flat, which reads as a change in player behaviour rather than a bug.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/analytics_wiring.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

void main() {
  late List<({String name, Map<String, Object?> params})> sent;
  late AnalyticsWiring wiring;

  setUp(() {
    clearBus();
    sent = [];
    setAnalyticsSink((name, params) => sent.add((name: name, params: params)));
    wiring = AnalyticsWiring()..attach();
  });

  tearDown(() {
    wiring.detach();
    setAnalyticsSink(null);
    setAnalyticsStateReader(null);
    resetCurrentScreen();
    clearBus();
  });

  ({String name, Map<String, Object?> params}) only(
    String event, [
    Object? args,
  ]) {
    sent.clear();
    emit(event, args);
    expect(sent, hasLength(1), reason: '$event reported ${sent.length} events');
    return sent.single;
  }

  group('progression', () {
    test('A SEASON CARRIES THE OUTCOME AND BOTH DIVISIONS', () {
      sent.clear();
      emit('season:ended', {
        'outcome': 'promoted',
        'position': 1,
        'oldDivision': 'regional_league',
        'newDivision': 'national_league',
        'payout': 25000,
      });
      final e = sent.first;
      // The JS's name and the JS's field names. A tidier one would end the
      // series FC has been filling — see the head of the wiring.
      expect(e.name, 'season_end');
      expect(e.params['outcome'], 'promoted');
      expect(e.params['from_division'], 'regional_league');
      expect(e.params['to_division'], 'national_league');
    });

    test('A PROMOTION ALSO REPORTS THE RUNG REACHED', () {
      // `season_end` says a promotion happened; `division_reached` says which
      // rung, which is the series that answers how far players actually get.
      sent.clear();
      emit('season:ended', {
        'outcome': 'promoted',
        'oldDivision': 'regional_league',
        'newDivision': 'national_league',
      });
      final reached = sent.where((e) => e.name == 'division_reached');
      expect(reached, hasLength(1));
      expect(reached.single.params['division'], 'national_league');
    });

    test('and a relegation does NOT — a division fallen into is not reached',
        () {
      sent.clear();
      emit('season:ended', {
        'outcome': 'relegated',
        'oldDivision': 'national_league',
        'newDivision': 'regional_league',
      });
      expect(sent.where((e) => e.name == 'division_reached'), isEmpty);
    });

    test('and its payout is BANDED, never raw', () {
      // A raw figure is useless as a dimension — almost every value is unique.
      sent.clear();
      emit('season:ended', {'payout': 25000});
      final e = sent.first;
      expect(e.params['payout_band'], '10k-100k');
      expect(e.params.containsKey('payout'), isFalse);
    });

    test('a season starting names its number', () {
      expect(only('season:started', {'season': 7}).params['season'], 7);
    });

    test('prestige carries the level and the multiplier', () {
      sent.clear();
      emit('prestige:complete', {'level': 3, 'multiplier': 1.75});
      final e = sent.first;
      expect(e.name, 'prestige');
      expect(e.params['level'], 3);
      expect(e.params['multiplier'], 1.75);
      expect(e.params['to_pro'], 0);
    });

    test('PRESTIGING INTO PRO IS A MODE SWITCH and is reported as one', () {
      // The only difficulty change the port can make — the JS also logs one
      // from Settings, which has no screen here yet. Without this the whole
      // `difficulty_switch` funnel is empty.
      sent.clear();
      emit('prestige:complete', {'level': 2, 'toPro': true});
      expect(sent.first.params['to_pro'], 1);
      final switched = sent.where((e) => e.name == 'difficulty_switch');
      expect(switched, hasLength(1));
      // `standard`, not `casual`: the UI renamed the mode and this value
      // deliberately did not, so the funnel stays comparable.
      expect(switched.single.params['from'], 'standard');
      expect(switched.single.params['to'], 'pro');
      expect(switched.single.params['source'], 'prestige_popup');
      expect(switched.single.params['prestige_level'], 2);
    });

    test('and a prestige that stays in Casual does not claim a switch', () {
      sent.clear();
      emit('prestige:complete', {'level': 2, 'toPro': false});
      expect(sent.where((e) => e.name == 'difficulty_switch'), isEmpty);
    });

    test('`match:close` NO LONGER REPORTS — it would double every match', () {
      // The JS's `match_played` carries the division, the result and the
      // fixture number, and none of those are on this signal: it fires when
      // the SCREEN closes, with an empty payload. It is logged from
      // `engine/match_orchestration.dart` at the moment the match is decided,
      // which is where the JS logs it too. A paramless second event beside it
      // would double every match count on the dashboard.
      sent.clear();
      emit('match:close');
      expect(sent, isEmpty);
    });
  });

  group('rewards', () {
    test('an achievement names itself and bands its coins', () {
      final e = only('achievement:unlocked', {
        'id': 'first_win',
        'category': 'matches',
        'coinsRewarded': 500,
        'isReUnlock': false,
      });
      expect(e.name, 'achievement_unlocked');
      expect(e.params['achievement_id'], 'first_win');
      expect(e.params['category'], 'matches');
      expect(e.params['coins_band'], '100-1k');
      expect(e.params['re_unlock'], 0);
    });

    test('A RE-UNLOCK IS A DIFFERENT FACT and says so', () {
      // Prestige hands every achievement back, so summing the two would count
      // one player's first win a dozen times.
      final e = only('achievement:unlocked', {
        'id': 'first_win',
        'isReUnlock': true,
      });
      expect(e.params['re_unlock'], 1);
    });

    test('a quest carries its scope', () {
      expect(only('quest:completed', {'scope': 'season'}).params['scope'],
          'season');
      expect(only('quest:claimed').name, 'quest_claimed');
    });

    test('a cup won and a cup lost are separate events', () {
      expect(
        only('cup:won', {'cupId': 'fa_cup', 'gems': 40}).name,
        'cup_won',
      );
      expect(
        only('cup:eliminated', {'cupId': 'fa_cup', 'round': 3}).params['round'],
        3,
      );
    });
  });

  group('accounts and ads', () {
    test('A UID IS A LOGIN AND A NULL ONE IS A LOGOUT', () {
      expect(only('auth:changed', {'uid': 'abc123'}).name, 'login');
      expect(only('auth:changed', {'uid': null}).name, 'logout');
    });

    test('the consent gate failing is reported, because it looks like demand', () {
      expect(only('consent:unavailable').name, 'ad_consent_unavailable');
    });
  });

  group('frequency', () {
    test('THE PER-FRAME SIGNALS ARE DELIBERATELY NOT LISTENED TO', () {
      // An event per merge and an event per tick is a bill and a rate limit
      // rather than a measurement. `merge:complete` — a card that actually
      // became a better card — is the one worth counting.
      sent.clear();
      emit('merge:happened');
      emit('coins:updated', 1234);
      emit('energy:updated', 3);
      expect(sent, isEmpty);

      // And the one that IS counted is the JS's `merge`, carrying the tier the
      // card became: a merge at tier 2 is the tutorial and one at tier 8 is
      // the end of the game, and an undifferentiated count cannot tell them
      // apart.
      emit('merge:complete', {'newCard': null, 'tier': 6});
      expect(sent.single.name, 'merge');
      expect(sent.single.params['tier'], 6);
    });
  });

  group('the annual event cup', () {
    test('ENTERING AND WINNING ARE A PAIR, so a completion rate falls out', () {
      final entered = only('event:cup-started', {
        'eventId': 'world_cup',
        'playerNation': 'BRA',
      });
      expect(entered.name, 'wc_entered');
      expect(entered.params['event_id'], 'world_cup');
      expect(entered.params['nation'], 'BRA');

      final won = only('event:cup-won', {
        'eventId': 'world_cup',
        'playerNation': 'BRA',
        'firstWin': true,
      });
      expect(won.name, 'wc_won');
      expect(won.params['first_win'], 1);
    });

    test('A REPEAT TITLE IS NOT A FIRST ONE', () {
      // The prize is paid once; summing the two would say the reward went out
      // far more often than it did.
      final e = only('event:cup-won', {'eventId': 'world_cup', 'firstWin': false});
      expect(e.params['first_win'], 0);
    });

    test('and a nation nobody picked reports `none`, not an empty string', () {
      expect(only('event:cup-started', {'eventId': 'x'}).params['nation'], 'none');
    });
  });

  group('naming', () {
    test('THE CLUB NAME CARD IS A FUNNEL, so all three steps report', () {
      expect(
        only('club:name-card-shown', {'isFirstTime': true}).name,
        'club_name_modal_shown',
      );
      expect(
        only('club:name-auto-assigned', {'nameLength': 12}).params['name_length'],
        12,
      );
    });

    test('a confirmed name says whether the dice produced it', () {
      final e = only('club:renamed', {
        'name': 'Real Anywhere',
        'nameLength': 13,
        'usedSuggestion': true,
        'usedGenerateBtn': true,
        'timeToConfirmMs': 4200,
      });
      expect(e.name, 'club_name_confirmed');
      expect(e.params['used_suggestion'], 1);
      expect(e.params['used_generate_btn'], 1);
      expect(e.params['time_to_confirm_ms'], 4200);
      expect(e.params['name_length'], 13);
    });

    test('RENAMING A PLAYER AND RESETTING ONE ARE DIFFERENT ACTS', () {
      final named = only('player:renamed', {
        'name': 'Sparky',
        'tier': 5,
        'reset': false,
      });
      expect(named.name, 'player_renamed');
      expect(named.params['name_length'], 6);
      expect(named.params['tier'], 5);

      final reset = only('player:renamed', {'name': 'Smith', 'tier': 5, 'reset': true});
      expect(reset.name, 'player_rename_reset');
      // The reset carries the tier and NOT a name length: there is no chosen
      // name left to measure.
      expect(reset.params['tier'], 5);
      expect(reset.params.containsKey('name_length'), isFalse);
    });
  });

  group('the review sheet', () {
    test('IT REPORTS THE COUNT, which is what says the cap is working', () {
      final e = only('rating:shown', {
        'promptCount': 2,
        'trigger': 'promotion',
        'matchesPlayed': 31,
      });
      expect(e.name, 'rating_shown');
      expect(e.params['prompt_count'], 2);
      expect(e.params['trigger'], 'promotion');
      expect(e.params['matches_played'], 31);
    });
  });

  group('the session', () {
    test('BOOT DESCRIBES THE SAVE, which is why it is not fired in `main`', () {
      // `startAnalytics` runs before the store is read, so a boot event fired
      // there reports `unknown` for every field it exists to carry.
      final previous = setAnalyticsStateReader(() => {
            'progression': {'currentDivision': 'elite_league', 'seasonCount': 9},
            'settings': {'hardMode': true},
          });
      addTearDown(() => setAnalyticsStateReader(previous));
      sent.clear();
      logAppBoot();
      final boot = sent.singleWhere((e) => e.name == 'app_boot');
      expect(boot.params['division'], 'elite_league');
      expect(boot.params['season'], 9);
      expect(boot.params['mode'], 'pro');
    });

    test('CASUAL REPORTS AS `standard`, because the UI renamed it and GA did not',
        () {
      final previous = setAnalyticsStateReader(
            () => <String, dynamic>{'settings': {'hardMode': false}},
          );
      addTearDown(() => setAnalyticsStateReader(previous));
      sent.clear();
      logAppBoot();
      expect(sent.singleWhere((e) => e.name == 'app_boot').params['mode'],
          'standard');
    });

    test('BACKGROUNDING SPENDS WHAT THE SESSION WAS DOING', () {
      final previous = setAnalyticsStateReader(() => {
            'progression': {'currentDivision': 'amateur_cup'},
            'tutorial': {'done': true},
          });
      addTearDown(() => setAnalyticsStateReader(previous));
      final at = DateTime.now().millisecondsSinceEpoch;
      startAnalyticsSession(at: at - 60000);
      logScreen('squad');
      emit('merge:complete', {'tier': 3});
      sent.clear();
      logAppBackgrounded(at: at);
      final e = sent.single;
      expect(e.name, 'app_backgrounded');
      expect(e.params['active_tab'], 'squad');
      expect(e.params['session_duration_s'], 60);
      expect(e.params['last_action'], 'merge');
      expect(e.params['division'], 'amateur_cup');
      expect(e.params['tutorial_done'], 1);
    });

    test('A PLAYER WHO DID NOTHING AT ALL REPORTS -1, NOT 0', () {
      // The single most interesting row in this event. A zero would file them
      // alongside somebody who had just merged.
      startAnalyticsSession();
      sent.clear();
      logAppBackgrounded();
      expect(sent.single.params['time_since_action_s'], -1);
      expect(sent.single.params['last_action'], 'none');
    });
  });

  group('user properties', () {
    test('THE SIX DIMENSIONS EVERY EVENT IS SLICED BY', () {
      final props = <String, Object?>{};
      final previousSink = setUserPropsSink((k, v) => props[k] = v);
      final previous = setAnalyticsStateReader(() => {
            'progression': {'currentDivision': 'continental', 'seasonCount': 14},
            'boosts': {'vipActive': true},
            'prestige': {'level': 2},
            'settings': {'hardMode': true},
            'leaderboard': {'authUid': 'uid-1'},
          });
      addTearDown(() {
        setAnalyticsStateReader(previous);
        setUserPropsSink(previousSink);
      });
      refreshUserProps();
      expect(props['current_division'], 'continental');
      expect(props['total_seasons'], 14);
      expect(props['is_vip'], 1);
      expect(props['prestige_level'], 2);
      expect(props['game_mode'], 'pro');
      expect(props['signed_in'], 1);
    });

    test('A SEASON ENDING REFRESHES THEM, or they describe the boot', () {
      var refreshes = 0;
      final previousSink = setUserPropsSink((_, _) => refreshes++);
      final previous = setAnalyticsStateReader(
        () => <String, dynamic>{'progression': <String, dynamic>{}},
      );
      addTearDown(() {
        setAnalyticsStateReader(previous);
        setUserPropsSink(previousSink);
      });
      emit('season:ended', {'outcome': 'promoted', 'newDivision': 'elite_league'});
      expect(refreshes, greaterThan(0));
      refreshes = 0;
      emit('auth:changed', {'uid': 'abc'});
      expect(refreshes, greaterThan(0));
    });

    test('and with NO reader installed nothing is claimed about the player', () {
      final props = <String, Object?>{};
      final previousSink = setUserPropsSink((k, v) => props[k] = v);
      final previous = setAnalyticsStateReader(null);
      addTearDown(() {
        setAnalyticsStateReader(previous);
        setUserPropsSink(previousSink);
      });
      refreshUserProps();
      expect(props, isEmpty);
    });
  });

  group('teardown', () {
    test('DETACHING REALLY UNSUBSCRIBES, or every event doubles', () {
      wiring.detach();
      sent.clear();
      emit('quest:claimed');
      expect(sent, isEmpty);
      expect(busListenerCount('quest:claimed'), 0);
      expect(busListenerCount('match:close'), 0);
    });

    test('and a malformed payload is skipped rather than thrown', () {
      sent.clear();
      emit('season:ended', 'not a map');
      emit('prestige:complete', null);
      emit('player:renamed', null);
      emit('club:renamed', 'not a map');
      expect(sent, isEmpty);
    });
  });
}
