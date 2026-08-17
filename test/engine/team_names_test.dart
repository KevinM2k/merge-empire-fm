import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/team_names.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

void main() {
  setUp(() => seeded.setSeed(1234));

  group('divTier', () {
    test('the two grassroots divisions draw from the pub-team bank', () {
      expect(divTier('sunday_league'), 'grassroots');
      expect(divTier('amateur_cup'), 'grassroots');
    });

    test('the middle two are semi-pro', () {
      expect(divTier('regional_league'), 'semipro');
      expect(divTier('national_league'), 'semipro');
    });

    test('everything above that is pro', () {
      expect(divTier('elite_league'), 'pro');
      expect(divTier('continental'), 'pro');
      expect(divTier('champions_cup'), 'pro');
    });

    test('an unknown or missing division falls through to pro', () {
      expect(divTier('not_a_division'), 'pro');
      expect(divTier(null), 'pro');
    });
  });

  group('generateTeamName', () {
    test('never returns a name already taken', () {
      final used = <String>{};
      for (var i = 0; i < 400; i++) {
        final name = generateTeamName('grassroots', used);
        expect(used.contains(name), isFalse);
        used.add(name);
      }
    });

    test('each tier has its own voice', () {
      seeded.setSeed(11);
      final pro = {for (var i = 0; i < 200; i++) generateTeamName('pro', {})};
      // The Pro bank pairs a club prefix with a grand noun and never takes the
      // English lower-league suffixes.
      expect(pro.any((n) => n.endsWith(' Rovers')), isFalse);
      expect(pro.any((n) => n.endsWith(' Wanderers')), isFalse);

      seeded.setSeed(11);
      final grassroots = {
        for (var i = 0; i < 200; i++) generateTeamName('grassroots', {}),
      };
      expect(grassroots.any((n) => n.endsWith(' Rovers')), isTrue);
    });

    test('grassroots and semi-pro draw from different first-word banks', () {
      seeded.setSeed(13);
      final gr = {for (var i = 0; i < 300; i++) generateTeamName('grassroots', {})};
      seeded.setSeed(13);
      final sp = {for (var i = 0; i < 300; i++) generateTeamName('semipro', {})};
      final grFirsts = gr.map((n) => n.split(' ').first).toSet();
      final spFirsts = sp.map((n) => n.split(' ').first).toSet();
      expect(grFirsts.intersection(spFirsts), isEmpty);
    });

    test('an unknown tier is treated as grassroots', () {
      seeded.setSeed(17);
      final names = {
        for (var i = 0; i < 200; i++) generateTeamName('mystery', {}),
      };
      seeded.setSeed(17);
      final grassroots = {
        for (var i = 0; i < 200; i++) generateTeamName('grassroots', {}),
      };
      expect(names, grassroots);
    });

    test('the pool is deep enough to fill the whole pyramid', () {
      // Seven divisions of eight, all drawn without collision.
      final used = <String>{};
      for (var i = 0; i < 56; i++) {
        used.add(generateTeamName('semipro', used));
      }
      expect(used.length, 56);
    });

    test('falls back to a numbered name when the bank is exhausted', () {
      // Statistically unreachable at the real bank sizes, but a name is what
      // the caller needs and an infinite loop is not an option.
      final exhausted = <String>{};
      final probe = <String>{};
      // Drain the grassroots bank by generating far more names than it holds.
      for (var i = 0; i < 600; i++) {
        probe.add(generateTeamName('grassroots', exhausted));
        exhausted.addAll(probe);
      }
      expect(exhausted.any((n) => n.startsWith('Valley United ')), isTrue);
    });

    test('the numbered fallback keeps counting rather than repeating', () {
      final used = {'Valley United 1', 'Valley United 2'};
      // Block the bank entirely by claiming everything it can produce.
      final blocked = <String>{...used};
      for (var i = 0; i < 600; i++) {
        blocked.add(generateTeamName('grassroots', blocked));
      }
      final numbered = blocked.where((n) => n.startsWith('Valley United ')).toList();
      expect(numbered, contains('Valley United 3'));
      expect(numbered.toSet().length, numbered.length);
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(99);
      final a = [for (var i = 0; i < 20; i++) generateTeamName('pro', {})];
      seeded.setSeed(99);
      final b = [for (var i = 0; i < 20; i++) generateTeamName('pro', {})];
      expect(a, b);
    });

    test('draws from the SEEDED stream, so it advances the shared sequence', () {
      seeded.setSeed(5);
      final probe = seeded.random();
      seeded.setSeed(5);
      generateTeamName('pro', {});
      expect(seeded.random(), isNot(probe));
    });
  });
}
