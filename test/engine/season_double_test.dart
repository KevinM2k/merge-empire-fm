/// The season summary's rewarded video.
///
/// `LeagueScreen.js:3592` offers this against a payout it has NOT yet banked
/// and pays `payout * 2` on continue; the port banks the payout in `endSeason`
/// before the summary exists, so the offer pays the half still owed instead.
/// The two things worth pinning are that the second half is exactly the first,
/// and that it cannot be taken twice — a summary is a route, and a route that
/// rebuilds must not pay again.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> _settled({required int payout, int coins = 0}) {
  final state = createDefaultState();
  (state['progression'] as Map<String, dynamic>)['lastSeasonPayout'] = payout;
  (state['progression'] as Map<String, dynamic>)['lastSeasonDoubled'] = false;
  (state['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  return state;
}

int _coins(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

void main() {
  group('seasonDoubleOffer', () {
    test('is the payout the season just banked', () {
      expect(seasonDoubleOffer(_settled(payout: 4200)), 4200);
    });

    test('is nothing once the video has been taken', () {
      final state = _settled(payout: 4200);
      grantSeasonDouble(state);
      expect(seasonDoubleOffer(state), 0);
    });

    test('is nothing on a season that paid nothing', () {
      // Bottom of the table out of a division with no position bonus: the
      // button must not offer to double zero.
      expect(seasonDoubleOffer(_settled(payout: 0)), 0);
    });

    test('is nothing on a save that has never finished a season', () {
      expect(seasonDoubleOffer(createDefaultState()), 0);
      expect(seasonDoubleOffer(null), 0);
      expect(seasonDoubleOffer(const {}), 0);
    });
  });

  group('grantSeasonDouble', () {
    test('pays the payout a second time', () {
      final state = _settled(payout: 4200, coins: 1000);
      expect(grantSeasonDouble(state), 4200);
      // The season already banked one lot; this is the half still owed, so the
      // player ends on `payout * 2` for the season.
      expect(_coins(state), 5200);
    });

    test('pays once however many times it is called', () {
      // The summary is a route that survives a rebuild, and a second grant is
      // a free season's pay.
      final state = _settled(payout: 4200, coins: 1000);
      expect(grantSeasonDouble(state), 4200);
      expect(grantSeasonDouble(state), 0);
      expect(grantSeasonDouble(state), 0);
      expect(_coins(state), 5200);
    });

    test('pays nothing when there was no payout', () {
      final state = _settled(payout: 0, coins: 1000);
      expect(grantSeasonDouble(state), 0);
      expect(_coins(state), 1000);
      // And it does not burn the flag either — nothing was spent.
      expect(
        (state['progression'] as Map<String, dynamic>)['lastSeasonDoubled'],
        false,
      );
    });

    test('the NEXT season can be doubled too', () {
      // The guard is cleared where `lastSeasonPayout` is written, so it is
      // per-season rather than once per save.
      final state = _settled(payout: 4200, coins: 0);
      expect(grantSeasonDouble(state), 4200);
      final prog = state['progression'] as Map<String, dynamic>;
      prog['lastSeasonPayout'] = 5000;
      prog['lastSeasonDoubled'] = false;
      expect(grantSeasonDouble(state), 5000);
      expect(_coins(state), 9200);
    });
  });

  group('THE FLAG IS THE PORT\'S, so it never reaches the save', () {
    // The JS doubles a payout nobody has banked and has no such field, and the
    // season difftest compares the whole save against node byte for byte — so
    // `endSeason` writing the flag put a key in the save the JS has never
    // heard of. Absent is what every reader already means by "not doubled".
    test('a settled season leaves no lastSeasonDoubled key behind', () {
      final state = createDefaultState();
      endSeason(state);
      expect(
        (state['progression'] as Map<String, dynamic>)
            .containsKey('lastSeasonDoubled'),
        isFalse,
        reason: 'a port-only field is in a save the JS is compared against',
      );
    });

    test('and the offer still resets season to season', () {
      // Which is what setting it false was FOR, so removing it has to keep it.
      final state = _settled(payout: 4200, coins: 0);
      expect(grantSeasonDouble(state), 4200);
      expect(seasonDoubleOffer(state), 0, reason: 'it was already taken');

      // A fresh season end clears the guard the same way it always did.
      final prog = state['progression'] as Map<String, dynamic>;
      endSeason(state);
      prog['lastSeasonPayout'] = 5000;
      expect(
        seasonDoubleOffer(state),
        5000,
        reason: 'last season\'s video killed this season\'s offer',
      );
    });
  });
}
