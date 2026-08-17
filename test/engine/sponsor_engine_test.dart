import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/sponsors.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> _card(String id, {Map<String, dynamic>? sponsor, num? form}) => {
  'instanceId': id,
  'definitionId': 'player_t5_fwd',
  'sponsor': ?sponsor,
  'form': ?form,
};

Map<String, dynamic> _state({
  List<dynamic>? cells,
  bool tutorialDone = true,
  num lastSponsorAt = 0,
  int seasonCount = 1,
}) => {
  'tutorial': {'done': tutorialDone},
  'transferMarket': {'lastSponsorAt': lastSponsorAt},
  'grid': {'cells': cells ?? [_card('a')]},
  'progression': {'seasonCount': seasonCount},
  'resources': {'fanCoins': 500},
};

void main() {
  setUp(() {
    resetSponsorRandom();
    resetClock();
    resetBus();
  });

  group('sponsorDrawback', () {
    test('reads penalties baked onto the sponsor at signing', () {
      final d = sponsorDrawback({'ratingPenalty': 8, 'injuryPenalty': 0.05});
      expect(d.ratingPenalty, 8);
      expect(d.injuryPenalty, 0.05);
    });

    test('falls back to the company by name for legacy saves', () {
      // Older saves store only { name, multiplier }.
      final d = sponsorDrawback({'name': 'BurgerKing', 'multiplier': 2.0});
      expect(d.ratingPenalty, 8);
      expect(d.injuryPenalty, 0.05);
    });

    test('an unknown legacy name yields no penalties', () {
      final d = sponsorDrawback({'name': 'Nonesuch'});
      expect(d.ratingPenalty, 0);
      expect(d.injuryPenalty, 0);
    });

    test('no sponsor means no penalties', () {
      final d = sponsorDrawback(null);
      expect(d.ratingPenalty, 0);
      expect(d.injuryPenalty, 0);
    });

    test('a partially-baked sponsor uses what it has', () {
      final d = sponsorDrawback({'ratingPenalty': 5});
      expect(d.ratingPenalty, 5);
      expect(d.injuryPenalty, 0);
    });

    test('every company round-trips through the legacy lookup', () {
      for (final c in companies) {
        final d = sponsorDrawback({'name': c.name});
        expect(d.ratingPenalty, c.drawback.ratingPenalty, reason: c.id);
        expect(d.injuryPenalty, c.drawback.injuryPenalty, reason: c.id);
      }
    });
  });

  group('sponsorImpact', () {
    test('states the income gain as a percentage', () {
      final def = getPlayerDef('player_t5_fwd');
      expect(sponsorImpact(def, getCompany('greenpower')).incomePct, 25);
      expect(sponsorImpact(def, getCompany('dangerdrinks')).incomePct, 200);
    });

    test('converts the rating penalty into points off this card', () {
      // T5 FWD rates 56; Danger Drinks takes 20%.
      final def = getPlayerDef('player_t5_fwd')!;
      expect(def.rating, 56);
      expect(sponsorImpact(def, getCompany('dangerdrinks')).ratingDrop, 11);
    });

    test('converts the injury penalty into percentage points', () {
      final def = getPlayerDef('player_t5_fwd');
      expect(sponsorImpact(def, getCompany('dangerdrinks')).injuryPct, 10);
      expect(sponsorImpact(def, getCompany('stayfit')).injuryPct, 1);
    });

    test('passes the form drop through unchanged', () {
      final def = getPlayerDef('player_t5_fwd');
      expect(sponsorImpact(def, getCompany('farmfresh')).formDrop, 4);
    });

    test('a clean deal reports clean', () {
      final def = getPlayerDef('player_t5_fwd');
      expect(sponsorImpact(def, getCompany('greenpower')).clean, isTrue);
    });

    test('a penalty that rounds away counts as clean, honestly', () {
      // SparkPad takes 1% of a T1 card's rating of 18, which rounds to zero —
      // and the engine rounds it away too, so it genuinely costs nothing.
      final t1 = getPlayerDef('player_t1_gk')!;
      final impact = sponsorImpact(t1, getCompany('sparkpad'));
      expect(impact.ratingDrop, 0);
      expect(impact.clean, isTrue);
    });

    test('the same deal bites harder on a better card', () {
      final small = sponsorImpact(getPlayerDef('player_t1_fwd'), getCompany('fastfood'));
      final big = sponsorImpact(getPlayerDef('player_t8_fwd'), getCompany('fastfood'));
      expect(big.ratingDrop, greaterThan(small.ratingDrop));
    });

    test('handles a null def or company', () {
      final impact = sponsorImpact(null, null);
      expect(impact.incomePct, 0);
      expect(impact.ratingDrop, 0);
      expect(impact.clean, isTrue);
    });
  });

  group('maybeGenerateSponsorshipOffer', () {
    test('is suppressed during the tutorial', () {
      setSponsorRandom(math.Random(1));
      expect(maybeGenerateSponsorshipOffer(_state(tutorialDone: false)), isNull);
    });

    test('is suppressed inside the cooldown', () {
      setClock(() => 1000000);
      setSponsorRandom(math.Random(1));
      final state = _state(lastSponsorAt: 1000000 - 1000);
      expect(maybeGenerateSponsorshipOffer(state), isNull);
    });

    test('is allowed once the cooldown has elapsed', () {
      setClock(() => sponsorMinIntervalMs * 2);
      // Seed chosen so the 20% roll passes.
      var offer = maybeGenerateSponsorshipOffer(_state());
      var tries = 0;
      while (offer == null && tries < 200) {
        offer = maybeGenerateSponsorshipOffer(_state());
        tries++;
      }
      expect(offer, isNotNull);
    });

    test('never offers to a player who already has a sponsor', () {
      setClock(() => sponsorMinIntervalMs * 2);
      final cells = [
        _card('taken', sponsor: {'name': 'MetaTech'}),
        _card('free'),
      ];
      for (var i = 0; i < 200; i++) {
        final offer = maybeGenerateSponsorshipOffer(_state(cells: cells));
        if (offer != null) expect(offer.player.instanceId, 'free');
      }
    });

    test('returns null when every player is already sponsored', () {
      setClock(() => sponsorMinIntervalMs * 2);
      final cells = [_card('a', sponsor: {'name': 'MetaTech'})];
      for (var i = 0; i < 100; i++) {
        expect(maybeGenerateSponsorshipOffer(_state(cells: cells)), isNull);
      }
    });

    test('returns null on an empty grid', () {
      setClock(() => sponsorMinIntervalMs * 2);
      for (var i = 0; i < 100; i++) {
        expect(maybeGenerateSponsorshipOffer(_state(cells: [])), isNull);
      }
    });

    test('tolerates empty grid slots', () {
      setClock(() => sponsorMinIntervalMs * 2);
      final cells = [null, _card('a'), null];
      var offer = maybeGenerateSponsorshipOffer(_state(cells: cells));
      var tries = 0;
      while (offer == null && tries < 200) {
        offer = maybeGenerateSponsorshipOffer(_state(cells: cells));
        tries++;
      }
      expect(offer!.player.instanceId, 'a');
    });

    test('stamps the cooldown when an offer is rolled', () {
      setClock(() => sponsorMinIntervalMs * 2);
      final state = _state();
      var offer = maybeGenerateSponsorshipOffer(state);
      var tries = 0;
      while (offer == null && tries < 200) {
        offer = maybeGenerateSponsorshipOffer(state);
        tries++;
      }
      expect(
        (state['transferMarket'] as Map)['lastSponsorAt'],
        sponsorMinIntervalMs * 2,
      );
    });
  });

  group('applySponsorship', () {
    test('bakes the deal onto the card', () {
      final state = _state(seasonCount: 4);
      final player = CardInstance((state['grid'] as Map)['cells'][0] as Map<String, dynamic>);

      expect(applySponsorship(state, player, getCompany('fastfood')!), isTrue);

      final sponsor = player.raw['sponsor'] as Map<String, dynamic>;
      expect(sponsor['name'], 'BurgerKing');
      expect(sponsor['multiplier'], 2.0);
      expect(sponsor['ratingPenalty'], 8);
      expect(sponsor['injuryPenalty'], 0.05);
      expect(sponsor['signedSeason'], 4);
    });

    test('refuses a player who already has a sponsor', () {
      final state = _state(cells: [_card('a', sponsor: {'name': 'MetaTech'})]);
      final player = CardInstance((state['grid'] as Map)['cells'][0] as Map<String, dynamic>);

      expect(applySponsorship(state, player, getCompany('fastfood')!), isFalse);
      expect((player.raw['sponsor'] as Map)['name'], 'MetaTech');
    });

    test('refuses a player who is not in the grid', () {
      final state = _state();
      final stranger = CardInstance(_card('elsewhere'));
      expect(applySponsorship(state, stranger, getCompany('fastfood')!), isFalse);
    });

    test('applies the form debuff once, at signing', () {
      final state = _state(cells: [_card('a', form: 1)]);
      final player = CardInstance((state['grid'] as Map)['cells'][0] as Map<String, dynamic>);

      applySponsorship(state, player, getCompany('farmfresh')!);
      // Form floors at FORM.MIN (-1), and FarmFresh takes 4.
      expect(player.form, -1);
    });

    test('a clean deal leaves form alone', () {
      final state = _state(cells: [_card('a', form: 1)]);
      final player = CardInstance((state['grid'] as Map)['cells'][0] as Map<String, dynamic>);

      applySponsorship(state, player, getCompany('greenpower')!);
      expect(player.form, 1);
    });

    test('announces the coin balance so the HUD refreshes', () {
      Object? seen;
      on('coins:updated', (args) => seen = args);

      final state = _state();
      final player = CardInstance((state['grid'] as Map)['cells'][0] as Map<String, dynamic>);
      applySponsorship(state, player, getCompany('greenpower')!);

      expect(seen, 500);
    });

    test('the signed sponsor reads back through sponsorDrawback', () {
      final state = _state();
      final player = CardInstance((state['grid'] as Map)['cells'][0] as Map<String, dynamic>);
      applySponsorship(state, player, getCompany('vegasnights')!);

      final d = sponsorDrawback(player.raw['sponsor'] as Map<String, dynamic>);
      expect(d.ratingPenalty, 12);
      expect(d.injuryPenalty, 0.05);
    });
  });
}
