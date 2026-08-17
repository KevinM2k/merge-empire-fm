import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/transfer_market.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> _card(
  String id, {
  String definitionId = 'player_t5_fwd',
  bool injured = false,
  Map<String, dynamic>? sponsor,
  int seasonsPlayed = 0,
  int? loanMatchesLeft,
}) => {
  'instanceId': id,
  'definitionId': definitionId,
  'seasonsPlayed': seasonsPlayed,
  if (injured) 'injured': true,
  'sponsor': ?sponsor,
  'loanMatchesLeft': ?loanMatchesLeft,
};

Map<String, dynamic> _state({
  List<Map<String, dynamic>>? cards,
  bool tutorialDone = true,
  Map<String, dynamic>? market,
  Map<String, dynamic>? pyramid,
  List<String> seasonOpponents = const [],
  String division = 'regional_league',
}) => {
  'tutorial': {'done': tutorialDone},
  'grid': <String, dynamic>{
    'cells': <dynamic>[
      ...?cards,
      // Enough bodies that the "never strand the player" guard is satisfied.
      for (var i = 0; i < 5; i++) _card('filler$i', definitionId: 'player_t1_mid'),
    ],
  },
  'progression': <String, dynamic>{
    'currentDivision': division,
    'seasonCount': 1,
    'seasonOpponents': <dynamic>[...seasonOpponents],
    'leaguePyramid': ?pyramid,
  },
  'resources': <String, dynamic>{'fanCoins': 1000},
  'stats': <String, dynamic>{},
  'squad': <String, dynamic>{'formation': '4-3-3', 'lineup': null},
  'transferMarket': ?market,
};

void main() {
  setUp(() {
    resetClock();
    resetBus();
    seeded.setSeed(12345);
  });

  group('teamDivisionIndex', () {
    test('walks the LADDER, not the pyramid key order', () {
      // The pyramid is a plain map; its key order is not the ladder's.
      final state = _state(
        pyramid: {
          'champions_cup': [
            {'name': 'Top FC'},
          ],
          'sunday_league': [
            {'name': 'Pub FC'},
          ],
        },
      );
      expect(teamDivisionIndex(state, 'Pub FC'), 0);
      expect(teamDivisionIndex(state, 'Top FC'), 6);
    });

    test('returns null for an unknown club', () {
      expect(teamDivisionIndex(_state(), 'Nobody'), isNull);
      expect(teamDivisionIndex(_state(), null), isNull);
    });
  });

  group('pickOfferingRival', () {
    test('falls back to a placeholder with nobody to bid', () {
      expect(pickOfferingRival(_state()), 'Rival FC');
    });

    test('falls back to season opponents with no pyramid', () {
      final state = _state(seasonOpponents: ['Alpha', 'Beta']);
      for (var i = 0; i < 20; i++) {
        expect(['Alpha', 'Beta'], contains(pickOfferingRival(state)));
      }
    });

    test('skips clubs already nursing a grudge', () {
      // They are cross with us; they are not bidding.
      final state = _state(
        seasonOpponents: ['Angry', 'Calm'],
        market: {
          'pendingOffer': null,
          'grudges': {
            'Angry': {'matchesLeft': 1, 'boost': 2},
          },
          'lastOfferAt': 0,
        },
      );
      for (var i = 0; i < 30; i++) {
        expect(pickOfferingRival(state), 'Calm');
      }
    });

    test('bids bias toward higher-league clubs', () {
      // The JS keyed this weighting on pyramid insertion order, which its own
      // teamDivisionIndex documents is NOT the ladder order. This walks the
      // ladder, so the bias is real regardless of how the map was built.
      final state = _state(
        pyramid: {
          // Deliberately declared out of ladder order.
          'champions_cup': [
            {'name': 'Top FC'},
          ],
          'sunday_league': [
            {'name': 'Pub FC'},
          ],
        },
      );

      var top = 0;
      for (var i = 0; i < 2000; i++) {
        if (pickOfferingRival(state) == 'Top FC') top++;
      }
      // Champions (weight 7) against Sunday League (weight 1).
      expect(top / 2000, greaterThan(0.7));
    });
  });

  group('buildOffer', () {
    test('builds a complete offer', () {
      final state = _state(cards: [_card('star')]);
      final offer = buildOffer(state)!;

      expect(offer['cardInstanceId'], isNotNull);
      expect(offer['price'], greaterThan(0));
      expect(offer['playerName'], isNotEmpty);
      expect(offer['fromTeam'], isNotEmpty);
      expect(_stateMarket(state)['pendingOffer'], offer);
    });

    test('never bids for a loanee — they are not ours to sell', () {
      final state = _state(
        cards: [_card('borrowed', loanMatchesLeft: 5, definitionId: 'player_t8_fwd')],
      );
      for (var i = 0; i < 30; i++) {
        _stateMarket(state)['pendingOffer'] = null;
        final offer = buildOffer(state);
        expect(offer?['cardInstanceId'], isNot('borrowed'));
      }
    });

    test('never bids for an injured player', () {
      final state = _state(
        cards: [_card('hurt', injured: true, definitionId: 'player_t8_fwd')],
      );
      for (var i = 0; i < 30; i++) {
        _stateMarket(state)['pendingOffer'] = null;
        expect(buildOffer(state)?['cardInstanceId'], isNot('hurt'));
      }
    });

    test('never bids below the minimum tier', () {
      final state = _state(cards: [_card('rookie', definitionId: 'player_t1_fwd')]);
      for (var i = 0; i < 30; i++) {
        _stateMarket(state)['pendingOffer'] = null;
        expect(buildOffer(state)?['cardInstanceId'], isNot('rookie'));
      }
      expect(transferMinTier, 2);
    });

    test('refuses to strand a player with too thin a squad', () {
      final thin = <String, dynamic>{
        'tutorial': {'done': true},
        'grid': <String, dynamic>{
          'cells': <dynamic>[_card('a'), _card('b'), _card('c')],
        },
        'progression': <String, dynamic>{
          'currentDivision': 'regional_league',
          'seasonCount': 1,
          'seasonOpponents': <dynamic>[],
        },
        'resources': <String, dynamic>{'fanCoins': 0},
        'squad': <String, dynamic>{'lineup': null},
      };
      expect(buildOffer(thin), isNull);
    });

    test('only one offer is pending at a time', () {
      final state = _state(cards: [_card('star')]);
      expect(buildOffer(state), isNotNull);
      expect(buildOffer(state), isNull);
    });

    test('a sponsored player fetches a premium', () {
      num priceFor({Map<String, dynamic>? sponsor}) {
        seeded.setSeed(4242);
        final state = _state(
          cards: [_card('star', definitionId: 'player_t8_fwd', sponsor: sponsor)],
        );
        // Force the target by leaving only one eligible card.
        (state['grid'] as Map)['cells'] = <dynamic>[
          _card('star', definitionId: 'player_t8_fwd', sponsor: sponsor),
          for (var i = 0; i < 5; i++) _card('f$i', definitionId: 'player_t1_mid'),
        ];
        return buildOffer(state)!['price'] as num;
      }

      expect(
        priceFor(sponsor: {'name': 'MetaTech', 'multiplier': 1.5}),
        greaterThan(priceFor()),
      );
    });

    test('an ageing player fetches less', () {
      num priceFor(int seasons) {
        seeded.setSeed(4242);
        final state = _state();
        (state['grid'] as Map)['cells'] = <dynamic>[
          _card('star', definitionId: 'player_t8_fwd', seasonsPlayed: seasons),
          for (var i = 0; i < 5; i++) _card('f$i', definitionId: 'player_t1_mid'),
        ];
        return buildOffer(state)!['price'] as num;
      }

      expect(priceFor(14), lessThan(priceFor(0)));
    });

    test('offers scale with division', () {
      num priceFor(String div) {
        seeded.setSeed(4242);
        final state = _state(division: div);
        (state['grid'] as Map)['cells'] = <dynamic>[
          _card('star', definitionId: 'player_t8_fwd'),
          for (var i = 0; i < 5; i++) _card('f$i', definitionId: 'player_t1_mid'),
        ];
        return buildOffer(state)!['price'] as num;
      }

      expect(priceFor('champions_cup'), greaterThan(priceFor('sunday_league')));
    });

    test('always beats the market base price', () {
      final state = _state(cards: [_card('star', definitionId: 'player_t8_fwd')]);
      final offer = buildOffer(state)!;
      expect(offer['price'], greaterThan(offer['marketBasePrice']));
    });
  });

  group('triggers', () {
    test('nothing fires during the tutorial', () {
      final state = _state(cards: [_card('star')], tutorialDone: false);
      for (var i = 0; i < 50; i++) {
        expect(maybeGenerateOffer(state), isNull);
        expect(maybeGenerateIdleOffer(state), isNull);
      }
    });

    test('a new season holds off the first post-match bid', () {
      final state = _state(cards: [_card('star')]);
      holdOffersForNewSeason(state);

      expect(maybeGenerateOffer(state), isNull);
      expect(_stateMarket(state)['holdUntilNextMatch'], isFalse);
    });

    test('the hold also blocks an idle bid', () {
      final state = _state(cards: [_card('star')]);
      holdOffersForNewSeason(state);
      expect(maybeGenerateIdleOffer(state), isNull);
    });

    test('a sponsored squad raises the post-match chance', () {
      expect(transferSponsorTriggerBonus, greaterThan(0));
    });

    test('the idle trigger respects its interval gate', () {
      setClock(() => 1000);
      final state = _state(
        cards: [_card('star')],
        market: {'pendingOffer': null, 'grudges': {}, 'lastOfferAt': 900},
      );
      for (var i = 0; i < 50; i++) {
        expect(maybeGenerateIdleOffer(state), isNull);
      }
    });

    test('an ignored offer times out into a grudge', () {
      // Ignoring one has stakes.
      setClock(() => 10 * 60 * 1000);
      final state = _state(
        cards: [_card('star')],
        market: {
          'pendingOffer': {
            'cardInstanceId': 'star',
            'fromTeam': 'Angry FC',
            'playerName': 'Star',
            'createdAt': 0,
          },
          'grudges': <String, dynamic>{},
          'lastOfferAt': 0,
        },
      );

      var fired = false;
      on('transfer:offer-expired', (_) => fired = true);
      maybeGenerateIdleOffer(state);

      expect(fired, isTrue);
      expect(
        (_stateMarket(state)['grudges'] as Map)['Angry FC'],
        isNotNull,
      );
    });

    test('an offer for a card that has left is simply dropped', () {
      setClock(() => 1000);
      final state = _state(
        cards: [_card('star')],
        market: {
          'pendingOffer': {
            'cardInstanceId': 'vanished',
            'fromTeam': 'Some FC',
            'playerName': 'Ghost',
            'createdAt': 0,
          },
          'grudges': <String, dynamic>{},
          'lastOfferAt': 0,
        },
      );
      maybeGenerateIdleOffer(state);
      // No grudge — nobody was snubbed, the card just went.
      expect((_stateMarket(state)['grudges'] as Map), isEmpty);
    });
  });

  group('acceptOffer', () {
    test('removes the card, pays us, and strengthens the buyer', () {
      // Only the star clears the minimum tier, so it is certainly the target.
      final state = _state(
        cards: [_card('star', definitionId: 'player_t8_fwd')],
        pyramid: {
          'regional_league': [
            {'name': 'Buyer FC', 'rating': 40},
          ],
        },
      );
      final offer = buildOffer(state, fromTeam: 'Buyer FC')!;
      expect(offer['cardInstanceId'], 'star');
      final before = (state['resources'] as Map)['fanCoins'] as num;

      final result = acceptOffer(state);
      expect(result.ok, isTrue);
      expect((state['resources'] as Map)['fanCoins'], before + (offer['price'] as num));

      final cells = (state['grid'] as Map)['cells'] as List;
      expect(cells.any((c) => CardInstance.from(c)?.instanceId == offer['cardInstanceId']), isFalse);

      final buyer = ((state['progression'] as Map)['leaguePyramid'] as Map)['regional_league'] as List;
      expect((buyer.first as Map)['rating'], greaterThan(40));
    });

    test('refuses with no offer', () {
      final r = acceptOffer(_state());
      expect(r.ok, isFalse);
      expect(r.reason, 'no_offer');
    });

    test('refuses when the card has already gone', () {
      final state = _state(cards: [_card('star')]);
      buildOffer(state);
      (state['grid'] as Map)['cells'] = <dynamic>[];

      final r = acceptOffer(state);
      expect(r.ok, isFalse);
      expect(r.reason, 'card_gone');
      expect(_stateMarket(state)['pendingOffer'], isNull);
    });

    test('counts the sale', () {
      final state = _state(cards: [_card('star')]);
      buildOffer(state);
      acceptOffer(state);
      expect((state['stats'] as Map)['transfersAccepted'], 1);
    });

    test('announces the sale', () {
      var sold = false;
      on('player:sold', (_) => sold = true);
      final state = _state(cards: [_card('star')]);
      buildOffer(state);
      acceptOffer(state);
      expect(sold, isTrue);
    });
  });

  group('applyRivalPlayerBoost', () {
    test('a weak side buying a star jumps; a strong side barely moves', () {
      final weak = _state(
        pyramid: {
          'regional_league': [
            {'name': 'Weak FC', 'rating': 50},
          ],
        },
      );
      final strong = _state(
        pyramid: {
          'regional_league': [
            {'name': 'Strong FC', 'rating': 88},
          ],
        },
      );

      final weakBoost = applyRivalPlayerBoost(weak, 'Weak FC', 90);
      final strongBoost = applyRivalPlayerBoost(strong, 'Strong FC', 90);

      expect(weakBoost.after! - weakBoost.before!, greaterThan(5));
      expect(strongBoost.after! - strongBoost.before!, lessThan(2));
    });

    test('a signing can never make a rival worse', () {
      final state = _state(
        pyramid: {
          'regional_league': [
            {'name': 'Good FC', 'rating': 80},
          ],
        },
      );
      final boost = applyRivalPlayerBoost(state, 'Good FC', 20);
      expect(boost.after, greaterThanOrEqualTo(boost.before!));
    });

    test('caps at 100', () {
      final state = _state(
        pyramid: {
          'champions_cup': [
            {'name': 'Elite FC', 'rating': 99},
          ],
        },
      );
      expect(applyRivalPlayerBoost(state, 'Elite FC', 100).after, lessThanOrEqualTo(100));
    });

    test('mirrors onto this season when the buyer is a current rival', () {
      final state = _state(seasonOpponents: ['Rival FC']);
      applyRivalPlayerBoost(state, 'Rival FC', 90);

      final ratings = (state['progression'] as Map)['seasonOpponentRatings'] as Map;
      expect(ratings['s1_o0'], isNotNull);
    });
  });

  group('grudges', () {
    test('declining creates one', () {
      final state = _state(cards: [_card('star')]);
      buildOffer(state, fromTeam: 'Snubbed FC');

      final r = declineOffer(state);
      expect(r.ok, isTrue);
      expect(r.fromTeam, 'Snubbed FC');
      expect(peekGrudge(state, 'Snubbed FC'), grudgeRatingBoost);
      expect((state['stats'] as Map)['transfersDeclined'], 1);
    });

    test('consuming one returns the boost then expires it', () {
      final state = _state(cards: [_card('star')]);
      buildOffer(state, fromTeam: 'Snubbed FC');
      declineOffer(state);

      expect(consumeGrudge(state, 'Snubbed FC'), grudgeRatingBoost);
      // It lasts a single match.
      expect(consumeGrudge(state, 'Snubbed FC'), 0);
      expect(peekGrudge(state, 'Snubbed FC'), 0);
    });

    test('peeking does not consume', () {
      final state = _state(cards: [_card('star')]);
      buildOffer(state, fromTeam: 'Snubbed FC');
      declineOffer(state);

      expect(peekGrudge(state, 'Snubbed FC'), grudgeRatingBoost);
      expect(peekGrudge(state, 'Snubbed FC'), grudgeRatingBoost);
      expect(consumeGrudge(state, 'Snubbed FC'), grudgeRatingBoost);
    });

    test('an unknown club has no grudge', () {
      expect(consumeGrudge(_state(), 'Nobody'), 0);
      expect(peekGrudge(_state(), 'Nobody'), 0);
      expect(consumeGrudge(_state(), null), 0);
    });

    test('merging away a bid-for card angers the club just as much', () {
      final state = _state(cards: [_card('star')]);
      final offer = buildOffer(state, fromTeam: 'Furious FC')!;

      final team = notifyCardRemoved(state, offer['cardInstanceId'] as String);
      expect(team, 'Furious FC');
      expect(peekGrudge(state, 'Furious FC'), grudgeRatingBoost);
      expect(_stateMarket(state)['pendingOffer'], isNull);
    });

    test('removing an unrelated card angers nobody', () {
      final state = _state(cards: [_card('star')]);
      buildOffer(state, fromTeam: 'Calm FC');
      expect(notifyCardRemoved(state, 'someone_else'), isNull);
      expect(_stateMarket(state)['pendingOffer'], isNotNull);
    });
  });
}

Map<String, dynamic> _stateMarket(Map<String, dynamic> state) =>
    ensureMarket(state);
