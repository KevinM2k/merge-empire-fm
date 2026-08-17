import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

void main() {
  group('field reads', () {
    test('reads the identity fields', () {
      final card = CardInstance({
        'definitionId': 'player_t3_mid',
        'instanceId': 'abc123',
      });
      expect(card.definitionId, 'player_t3_mid');
      expect(card.instanceId, 'abc123');
    });

    test('defaults missing fields rather than throwing', () {
      final card = CardInstance({});
      expect(card.definitionId, '');
      expect(card.instanceId, '');
      expect(card.seasonsPlayed, 0);
      expect(card.ratingBonus, 0);
      expect(card.form, 0);
      expect(card.injured, isFalse);
      expect(card.listed, isFalse);
      expect(card.loanedOut, isNull);
      expect(card.customName, isNull);
      expect(card.attackRatio, isNull);
      expect(card.energy, isNull);
    });

    test('ignores a field of the wrong type instead of crashing', () {
      // Old saves are not guaranteed well-typed.
      final card = CardInstance({'definitionId': 42, 'seasonsPlayed': 'nope'});
      expect(card.definitionId, '');
      expect(card.seasonsPlayed, 0);
    });

    test('accepts a double where an int is expected', () {
      // JSON round-trips can widen an int to a double.
      final card = CardInstance({'seasonsPlayed': 3.0});
      expect(card.seasonsPlayed, 3);
    });

    test('reads optional gameplay fields', () {
      final card = CardInstance({
        'seasonsPlayed': 12,
        'ratingBonus': 4,
        'form': -1,
        'attackRatio': 0.72,
        'energy': 55.5,
        'customName': 'Gaffer',
        'displayName': 'Rodrigo Flash',
      });
      expect(card.seasonsPlayed, 12);
      expect(card.ratingBonus, 4);
      expect(card.form, -1);
      expect(card.attackRatio, 0.72);
      expect(card.energy, 55.5);
      expect(card.customName, 'Gaffer');
      expect(card.displayName, 'Rodrigo Flash');
    });
  });

  group('availability', () {
    test('a plain card is selectable', () {
      final card = CardInstance({'instanceId': 'a'});
      expect(card.isUnavailable, isFalse);
      expect(card.isSelectable, isTrue);
    });

    test('an injured card is available but not selectable', () {
      // Injured is ours-and-here-but-unfit, which is not the same as absent.
      final card = CardInstance({'injured': true});
      expect(card.injured, isTrue);
      expect(card.isUnavailable, isFalse);
      expect(card.isSelectable, isFalse);
    });

    test('a listed card is unavailable', () {
      final card = CardInstance({'listed': true});
      expect(card.isUnavailable, isTrue);
      expect(card.isSelectable, isFalse);
    });

    test('a loaned-out card is unavailable', () {
      final card = CardInstance({'loanedOut': 'rival_fc'});
      expect(card.isUnavailable, isTrue);
      expect(card.isSelectable, isFalse);
    });

    test('an explicit false listed flag does not make a card unavailable', () {
      expect(CardInstance({'listed': false}).isUnavailable, isFalse);
    });

    test('a loanedOut of null is treated as not loaned', () {
      expect(CardInstance({'loanedOut': null}).isUnavailable, isFalse);
    });
  });

  group('lossless backing', () {
    test('keeps fields the model knows nothing about', () {
      final raw = <String, dynamic>{
        'definitionId': 'player_t1_gk',
        'instanceId': 'x',
        'someFutureField': {'nested': 1},
      };
      final card = CardInstance(raw);

      final round = jsonDecode(jsonEncode(card.raw)) as Map<String, dynamic>;
      expect(round['someFutureField'], {'nested': 1});
    });

    test('exposes the same map it was given', () {
      final raw = <String, dynamic>{'instanceId': 'x'};
      expect(identical(CardInstance(raw).raw, raw), isTrue);
    });

    test('writes through to the backing map', () {
      final raw = <String, dynamic>{'instanceId': 'x'};
      final card = CardInstance(raw)..raw['injured'] = true;
      expect(card.injured, isTrue);
      expect(raw['injured'], isTrue);
    });
  });

  group('from', () {
    test('wraps a JSON object', () {
      expect(CardInstance.from({'instanceId': 'a'})?.instanceId, 'a');
    });

    test('returns null for a non-object, including an empty grid slot', () {
      expect(CardInstance.from(null), isNull);
      expect(CardInstance.from('string'), isNull);
      expect(CardInstance.from(7), isNull);
    });
  });
}
