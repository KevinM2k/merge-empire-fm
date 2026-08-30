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
      final e = only('season:ended', {
        'outcome': 'promoted',
        'position': 1,
        'oldDivision': 'regional_league',
        'newDivision': 'national_league',
        'payout': 25000,
      });
      expect(e.name, 'season_complete');
      expect(e.params['outcome'], 'promoted');
      expect(e.params['old_division'], 'regional_league');
      expect(e.params['new_division'], 'national_league');
    });

    test('and its payout is BANDED, never raw', () {
      // A raw figure is useless as a dimension — almost every value is unique.
      final e = only('season:ended', {'payout': 25000});
      expect(e.params['payout_band'], '10k-100k');
      expect(e.params.containsKey('payout'), isFalse);
    });

    test('a season starting names its number', () {
      expect(only('season:started', {'season': 7}).params['season'], 7);
    });

    test('prestige carries the level and the multiplier', () {
      final e = only('prestige:complete', {'level': 3, 'multiplier': 1.75});
      expect(e.name, 'prestige');
      expect(e.params['level'], 3);
      expect(e.params['multiplier'], 1.75);
    });

    test('A MATCH IS REPORTED FROM `match:close`, which is the one emitted', () {
      // `match:complete` reads like the right hook and nothing in lib/ emits
      // it, though `game_host` subscribes. Hanging analytics off it would have
      // produced a permanently empty chart.
      expect(only('match:close').name, 'match_complete');
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

      emit('merge:complete', {'newCard': null});
      expect(sent.single.name, 'merge_complete');
    });
  });

  group('teardown', () {
    test('DETACHING REALLY UNSUBSCRIBES, or every event doubles', () {
      wiring.detach();
      sent.clear();
      emit('match:close');
      expect(sent, isEmpty);
      expect(busListenerCount('match:close'), 0);
    });

    test('and a malformed payload is skipped rather than thrown', () {
      sent.clear();
      emit('season:ended', 'not a map');
      emit('prestige:complete', null);
      expect(sent, isEmpty);
    });
  });
}
