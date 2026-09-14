import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/boosts.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart' show gameIcons;

void main() {
  group('the boost catalogue', () {
    test('six boosts, three of each kind', () {
      expect(boostList.length, 6);
      expect(boosts.length, 6);
      expect(boostList.where((b) => b.kind == BoostKind.proactive).length, 3);
      expect(
        boostList.where((b) => b.kind == BoostKind.retrospective).length,
        3,
      );
    });

    test('every icon is one of the app\'s own, not an emoji', () {
      for (final b in boostList) {
        expect(gameIcons.containsKey(b.icon), isTrue, reason: '${b.id}: ${b.icon}');
      }
    });

    test('every key matches its id, and every boost has an icon', () {
      boosts.forEach((key, b) {
        expect(b.id, key);
        expect(b.icon, isNotEmpty, reason: key);
      });
    });

    test('one gem buys one', () {
      for (final b in boostList) {
        expect(b.packSize, 1, reason: b.id);
        expect(b.gemCost, 1, reason: b.id);
      }
    });

    // A retrospective boost is taken at the bench in front of the consequence;
    // it has no window because the match is paused while it is offered.
    test('only the proactive pair carry a window', () {
      for (final b in boostList) {
        expect(b.windowMinutes > 0, b.kind == BoostKind.proactive, reason: b.id);
      }
    });

    test('the window is twenty-five in-game minutes', () {
      expect(boosts['crowd_roar']!.windowMinutes, 25);
      expect(boosts['park_the_bus']!.windowMinutes, 25);
    });

    test('the six are the six', () {
      expect(boosts.keys.toSet(), {
        'crowd_roar',
        'park_the_bus',
        'var_review',
        'physio_sponge',
        'sharp_shooting',
        'quiet_word',
      });
      expect(boosts['var_review']!.kind, BoostKind.retrospective);
      expect(boosts['physio_sponge']!.kind, BoostKind.retrospective);
      expect(boosts['quiet_word']!.kind, BoostKind.retrospective);
      expect(boosts['sharp_shooting']!.kind, BoostKind.proactive);
      expect(boosts['sharp_shooting']!.windowMinutes, 25);
    });

    test('lookups tolerate a null or unknown id', () {
      expect(getBoost(null), isNull);
      expect(getBoost('nope'), isNull);
      expect(getBoost('crowd_roar')?.id, 'crowd_roar');
    });
  });
}
