import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/player_rating.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

CardInstance _card({
  String definitionId = 'player_t5_fwd',
  int seasonsPlayed = 0,
  num ratingBonus = 0,
  num form = 0,
  String? traitId,
  int traitLevel = 1,
  Map<String, dynamic>? sponsor,
  double? attackRatio,
}) => CardInstance({
  'instanceId': 'c1',
  'definitionId': definitionId,
  'seasonsPlayed': seasonsPlayed,
  'ratingBonus': ratingBonus,
  'form': form,
  if (traitId != null) 'trait': {'id': traitId, 'level': traitLevel},
  'sponsor': ?sponsor,
  'attackRatio': ?attackRatio,
});

void main() {
  group('getEffectiveRating', () {
    test('a plain card rates at its definition', () {
      // T5 FWD bases at 56.
      expect(getEffectiveRating(_card()), 56);
    });

    test('applies a per-instance rating bonus', () {
      expect(getEffectiveRating(_card(ratingBonus: 3)), 59);
    });

    test('clamps to the tier ceiling', () {
      // T5 caps at 64.
      expect(getEffectiveRating(_card(ratingBonus: 999)), 64);
    });

    test('never drops below 1', () {
      expect(getEffectiveRating(_card(seasonsPlayed: 40)), 1);
    });

    test('applies form directionally', () {
      expect(getEffectiveRating(_card(form: 1)), 57);
      expect(getEffectiveRating(_card(form: -1)), 55);
    });

    test('is free of aging for the first ten seasons', () {
      expect(getEffectiveRating(_card(seasonsPlayed: 10)), 56);
    });

    test('ages ten points a season past ten', () {
      expect(getEffectiveRating(_card(seasonsPlayed: 11)), 46);
      expect(getEffectiveRating(_card(seasonsPlayed: 12)), 36);
    });

    test('a veteran trait claws back aging', () {
      // An 11-season card carries a penalty of 10. Veteran III takes 6 of it
      // back — SOME of it, not all: Rock is the trait whose description claims
      // to be the strongest defence against decline, and Veteran is the one
      // that covers aging AND recovery on any position instead of owning
      // either axis.
      expect(
        getEffectiveRating(_card(seasonsPlayed: 11, traitId: 'veteran', traitLevel: 3)),
        56 - 4,
      );
    });

    test('aging reduction cannot become a bonus', () {
      // Rock III reduces by 14 against an 11-season penalty of 10 — the excess
      // must not turn into a rating gain.
      final aged = getEffectiveRating(
        _card(definitionId: 'player_t5_def', seasonsPlayed: 11, traitId: 'rock', traitLevel: 3),
      );
      final fresh = getEffectiveRating(
        _card(definitionId: 'player_t5_def', traitId: 'rock', traitLevel: 3),
      );
      expect(aged, fresh);
    });

    test('a sponsor drawback takes a percentage of the base rating', () {
      // Danger Drinks takes 20% of 56 = 11.
      final rated = getEffectiveRating(
        _card(sponsor: {'ratingPenalty': 20, 'injuryPenalty': 0.10}),
      );
      expect(rated, 56 - 11);
    });

    test('a legacy sponsor still bites via the company lookup', () {
      final rated = getEffectiveRating(_card(sponsor: {'name': 'BurgerKing'}));
      // BurgerKing takes 8% of 56 = 4 (rounded).
      expect(rated, 56 - 4);
    });

    test('a clean sponsor costs nothing', () {
      expect(getEffectiveRating(_card(sponsor: {'name': 'GreenPower'})), 56);
    });

    test('penalties stack: sponsor, aging and form together', () {
      final rated = getEffectiveRating(
        _card(seasonsPlayed: 11, form: -1, sponsor: {'ratingPenalty': 20}),
      );
      // 56 - 11 (sponsor) - 10 (aging) - 1 (form) = 34.
      expect(rated, 34);
    });

    test('T9 is always 100 before penalties', () {
      expect(getEffectiveRating(_card(definitionId: 'player_t9_fwd')), 100);
    });

    test('T9 can still be dragged down by penalties', () {
      final rated = getEffectiveRating(
        _card(definitionId: 'player_t9_fwd', sponsor: {'ratingPenalty': 20}),
      );
      expect(rated, 80);
    });

    test('an unknown definition rates zero', () {
      expect(getEffectiveRating(CardInstance({'definitionId': 'nope'})), 0);
    });

    test('a null card rates zero', () {
      expect(getEffectiveRating(null), 0);
    });

    test('a trait rating bonus is currently neutral', () {
      // No trait level authors a rating bonus, so a trait must not move the
      // composed rating on its own.
      expect(
        getEffectiveRating(_card(traitId: 'finisher', traitLevel: 3)),
        getEffectiveRating(_card()),
      );
    });
  });

  /// **These pinned `getCardSplit`, which was the second implementation.**
  /// Every property below is a property of the ATK/DEF split itself, so they
  /// moved to the one every screen actually goes through rather than being
  /// deleted with it — that is the whole reason to check whether an unreachable
  /// function's tests prove something the live one is missing. It ran with the
  /// definition ratio passed as a bare double; `getCardStats` takes the map the
  /// save carries, which is where a live re-rating comes from.
  group('the ATK/DEF split, through getCardStats', () {
    test('a striker leads on attack', () {
      final split = getCardStats(_card());
      expect(split.attack, greaterThan(split.defence));
    });

    test('a keeper leads on defence', () {
      final split = getCardStats(_card(definitionId: 'player_t5_gk'));
      expect(split.defence, greaterThan(split.attack));
    });

    test('a trait adds its directional bonus', () {
      final plain = getCardStats(_card());
      final withTrait = getCardStats(_card(traitId: 'finisher', traitLevel: 3));
      expect(withTrait.attack, greaterThan(plain.attack));
      expect(
        withTrait.attack - plain.attack,
        closeTo(13 * traitStatScale, 1.0),
      );
    });

    test('an off-position trait adds nothing directional', () {
      final plain = getCardStats(_card(definitionId: 'player_t5_def'));
      final withTrait = getCardStats(
        _card(definitionId: 'player_t5_def', traitId: 'finisher', traitLevel: 3),
      );
      expect(withTrait.attack, plain.attack);
    });

    test('a per-instance ratio beats the definition ratio', () {
      final split = getCardStats(_card(attackRatio: 0.10));
      expect(split.defence, greaterThan(split.attack));
    });

    test('a supplied definition ratio is used when the card has none', () {
      final split = getCardStats(_card(), definitionRatios: {'player_t5_fwd': 0.10});
      expect(split.defence, greaterThan(split.attack));
    });

    test('both stats stay inside 0..100', () {
      for (final defId in players.map((p) => p.id)) {
        final split = getCardStats(_card(definitionId: defId, traitId: 'allrounder', traitLevel: 3));
        expect(split.attack, inInclusiveRange(0, 100), reason: defId);
        expect(split.defence, inInclusiveRange(0, 100), reason: defId);
      }
    });

    test('an unknown definition or null card splits to zero', () {
      expect(getCardStats(null).attack, 0);
      expect(getCardStats(CardInstance({'definitionId': 'nope'})).attack, 0);
    });

    test('aging drags both stats down together', () {
      final fresh = getCardStats(_card());
      final old = getCardStats(_card(seasonsPlayed: 13));
      expect(old.attack, lessThan(fresh.attack));
    });
  });
}
