/// A trait's name, in the player's own language.
///
/// **Every trait in the game was untranslatable.** The port rendered
/// `Trait.name` and `Trait.desc`, which are the English literals on the record,
/// while all forty-two `trait.name.*` and `trait.desc.*` strings sat generated
/// in all ten catalogues with nothing able to reach one — the same tell that
/// found the Shop showing the wrong product names.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';

void main() {
  tearDown(resetLocale);

  test('the CATALOGUE names a trait, not the record', () {
    setLocale('fr');
    final finisher = traits['finisher']!;
    expect(
      traitName(finisher),
      t('trait.name.finisher'),
      reason: 'the record\'s English literal reached the player',
    );
    expect(traitName(finisher), isNot(finisher.name));
    expect(traitDesc(finisher), t('trait.desc.finisher'));
    expect(traitDesc(finisher), isNot(finisher.desc));
  });

  test('and the record is the FALLBACK, never the source', () {
    // A trait added ahead of its copy still has a name rather than a key.
    setLocale('en');
    for (final trait in traits.values) {
      expect(traitName(trait), isNotEmpty);
      expect(
        traitName(trait),
        isNot(startsWith('trait.name.')),
        reason: '${trait.id} prints its key',
      );
      expect(traitDesc(trait), isNot(startsWith('trait.desc.')));
    }
  });

  test('a held trait reads as glyph, name and level', () {
    setLocale('en');
    expect(traitTitle({'id': 'finisher', 'level': 3}), '⚽ Finisher III');
    expect(traitTitle(null), '');
    expect(traitTitle({'id': 'nope', 'level': 1}), '');
    expect(
      traitInstanceDesc({'id': 'finisher', 'level': 1}),
      traitDesc(traits['finisher']!),
    );
  });

  test('THE ENGINE IS LEFT ALONE, and that is deliberate', () {
    // `traitLabel` is the JS's function and its output is pinned against the
    // JS's. A fixture that starts speaking French is not a fixture, which is
    // why the display copy lives up here instead.
    setLocale('fr');
    expect(traitLabel({'id': 'finisher', 'level': 3}), '⚽ Finisher III');
  });
}
