/// **ONE MAN'S MATCH TRAIT, FOLLOWED ALL THE WAY TO THE STAR.** The engine
/// tests prove the multiplier map; the wiring tests prove it reaches the
/// re-simulation. This one composes the two on a real eleven and prints the
/// arithmetic: one striker's Fortress III at home lifts HIS rating by 11%,
/// which lifts team ATK by his share of it, DEF by his (smaller) share, and
/// the star with them — and away from home, nothing at all.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/match_traits.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

MatchContext _ctx({bool isHome = false, int minute = 40, bool tenMen = false}) => (
  isHome: isHome,
  isCup: false,
  isDerby: false,
  inRelegationZone: false,
  oppStronger: false,
  tenMen: tenMen,
  minute: minute,
  fullTime: 90,
  subbedOnLate: const {},
  cautioned: const {},
);

void main() {
  // A 4-4-2 of tier-6 men, so the numbers are big enough to read.
  final byPos = {
    for (final pos in ['GK', 'DEF', 'MID', 'FWD'])
      pos: players.firstWhere((p) => p.position == pos && p.tier == 6).id,
  };
  const order = ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD'];
  List<Map<String, dynamic>> raw({String? traitOn, String trait = 'fortress'}) => [
    for (var i = 0; i < 11; i++)
      {
        'instanceId': 'c$i',
        'definitionId': byPos[order[i]],
        'attackRatio': switch (order[i]) {
          'GK' => 0.02,
          'DEF' => 0.2,
          'MID' => 0.5,
          _ => 0.8,
        },
        if (traitOn == 'c$i') 'matchSlot': true,
        if (traitOn == 'c$i') 'matchTrait': {'id': trait, 'level': 3},
      },
  ];
  List<Map<String, dynamic>> lineup() => [
    for (var i = 0; i < 11; i++) {'cardInstanceId': 'c$i', 'slotPosition': order[i]},
  ];

  ({int atk, int def, int star}) rate(List<Map<String, dynamic>> cells, MatchContext ctx) {
    final ci = [for (final c in cells) CardInstance.from(c)];
    final mults = matchTraitMultipliers(ci, lineup(), ctx);
    final split = computeSquadRatings(ci, lineup: lineup(), ratingMultipliers: mults);
    final star = computeSquadRating(ci, lineup: lineup(), ratingMultipliers: mults);
    return (atk: split.attack, def: split.defence, star: star);
  }

  test('A STRIKER\'S FORTRESS III LIFTS HIM, THE TEAM ATK, THE DEF AND THE STAR — at home', () {
    final plain = rate(raw(), _ctx(isHome: true));
    final lit = rate(raw(traitOn: 'c9'), _ctx(isHome: true));
    final dark = rate(raw(traitOn: 'c9'), _ctx(isHome: false));
    debugPrint('plain ATK ${plain.atk} DEF ${plain.def} star ${plain.star}');
    debugPrint('lit   ATK ${lit.atk} DEF ${lit.def} star ${lit.star}');
    debugPrint('away  ATK ${dark.atk} DEF ${dark.def} star ${dark.star}');
    for (final id in ['derby_devil', 'cup_fighter', 'ten_man_wall']) {
      final r = rate(raw(traitOn: 'c9', trait: id), (
        isHome: true, isCup: true, isDerby: true, inRelegationZone: false,
        oppStronger: false, tenMen: true, minute: 40, fullTime: 90,
        subbedOnLate: const {}, cautioned: const {},
      ));
      debugPrint('$id III on the striker: ATK ${r.atk} DEF ${r.def} star ${r.star}');
    }

    // The man himself: exactly his level's multiplier, and only him.
    final mults = matchTraitMultipliers(
      [for (final c in raw(traitOn: 'c9')) CardInstance.from(c)],
      lineup(),
      _ctx(isHome: true),
    );
    expect(mults, {'c9': closeTo(getMatchTraitLevel(getMatchTrait('fortress'), 3)!.mult, 1e-9)});

    // The team: ATK up, and DEF up too — the multiplier is on his whole
    // rating, and a striker still carries a sliver of the DEF weight.
    expect(lit.atk, greaterThan(plain.atk));
    // His DEF share is a sliver (0.15 of 5.7) and may round to nothing.
    expect(lit.def, greaterThanOrEqualTo(plain.def));
    expect(lit.star, greaterThan(plain.star));
    // Away from home the same man is worth exactly what he was.
    expect(dark, plain);
  });

  test('a keeper\'s Fortress lifts DEF and not ATK', () {
    final plain = rate(raw(), _ctx(isHome: true));
    final lit = rate(raw(traitOn: 'c0'), _ctx(isHome: true));
    debugPrint('keeper plain ATK ${plain.atk} DEF ${plain.def} → lit ATK ${lit.atk} DEF ${lit.def}');
    expect(lit.def, greaterThan(plain.def));
    expect(lit.atk, plain.atk);
  });

  test('Fast Starter is on at 15 and off at 21, on the same eleven', () {
    final early = rate(raw(traitOn: 'c9', trait: 'fast_starter'), _ctx(minute: 15));
    final late = rate(raw(traitOn: 'c9', trait: 'fast_starter'), _ctx(minute: 21));
    final plain = rate(raw(), _ctx(minute: 21));
    expect(early.atk, greaterThan(plain.atk));
    expect(late, plain);
  });
}
