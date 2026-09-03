/// Coach Colin's read on our own squad.
///
/// **Thirteen `squadstate.*` keys and forty-odd sentences, translated into ten
/// languages, with nothing in `lib/` even mentioning the prefix.** The keys
/// name their conditions and none of them names its threshold — "six in ten
/// isn't bad" is a number somebody chose — so this stayed blocked until
/// `../merge-empire-fc` could be read rather than being guessed at and called a
/// port.
///
/// The ORDER is as much of the spec as the numbers are, which is why most of
/// what is pinned below is what he says INSTEAD of something else.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/squad_state_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

/// A save sitting in exactly the state the branch under test needs.
///
/// Opponent ratings are STAMPED rather than left to the division's advertised
/// band: the engine prefers what the season actually drew, so a test that left
/// them out would be pinning the fallback and calling it the rule.
Map<String, dynamic> save({
  int energy = 10,
  int cards = 11,
  int tier = 3,
  int poorForm = 0,
  int matchesPlayed = 5,
  int awardedPlayed = 0,
  int wins = 0,
  int coins = 1500,
  String division = 'sunday_league',
  int? oppRating,
  Map<String, int> ownedAssets = const {},
}) {
  final s = createDefaultState();
  final ids = getPlayersByTier(tier).map((d) => d.id).toList();
  final grid = s['grid'] as Map<String, dynamic>;
  final cells = (grid['cells'] as List).length;
  grid['cells'] = [
    for (var i = 0; i < cells; i++)
      if (i < cards)
        <String, dynamic>{
          'definitionId': ids[i % ids.length],
          'instanceId': 'i$i',
          'form': i < poorForm ? -1 : 0,
        }
      else
        null,
  ];
  (s['energy'] as Map<String, dynamic>)['current'] = energy;
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  final prog = s['progression'] as Map<String, dynamic>;
  prog['currentDivision'] = division;
  prog['seasonMatchesPlayed'] = matchesPlayed;
  prog['seasonAwardedPlayed'] = awardedPlayed;
  prog['seasonWins'] = wins;
  if (oppRating != null) {
    prog['seasonOpponentRatings'] = <String, dynamic>{
      for (var i = 0; i < 7; i++) 's1_o$i': oppRating,
    };
  }
  final assets = s['clubAssets'] as Map<String, dynamic>;
  for (final entry in ownedAssets.entries) {
    (assets[entry.key] as Map<String, dynamic>)
      ..['owned'] = true
      ..['tier'] = entry.value;
  }
  return s;
}

String? keyOf(Map<String, dynamic> s) => squadStateHint(s)?.key;

void main() {
  tearDown(resetLocale);

  group('a squad that cannot field a side', () {
    test('IS THE FIRST THING HE SAYS, and it is outside the chain', () {
      expect(keyOf(save(cards: 2)), 'squadstate.few_players');
    });

    test('but only when the player can DO something about it', () {
      // The one branch that asks whether the advice is actionable. Telling a
      // manager with no coin to scout is naming the problem twice.
      expect(keyOf(save(cards: 2, coins: 0)),
          isNot('squadstate.few_players'));
    });

    test('and three players is already enough to fall through', () {
      expect(keyOf(save(cards: 3)), isNot('squadstate.few_players'));
    });
  });

  group('the chain, most urgent first', () {
    test('ENERGY OUTRANKS EVERYTHING, because nothing else can be spent', () {
      expect(keyOf(save(energy: 2, poorForm: 5)), 'squadstate.low_energy');
      expect(keyOf(save(energy: 3, poorForm: 5)), 'squadstate.poor_form');
    });

    test('poor form is THREE players, not two', () {
      expect(keyOf(save(poorForm: 3)), 'squadstate.poor_form');
      expect(keyOf(save(poorForm: 2)), isNot('squadstate.poor_form'));
    });

    test('SIX IN TEN IS THE FORM LINE, over at least three matches', () {
      expect(keyOf(save(awardedPlayed: 5, wins: 3)), 'squadstate.form_high');
      expect(keyOf(save(awardedPlayed: 5, wins: 2)),
          isNot('squadstate.form_high'));
      // Two out of two is a fine start and not a run of form.
      expect(keyOf(save(awardedPlayed: 2, wins: 2)),
          isNot('squadstate.form_high'));
    });

    test('THE RUN-IN IS THE LAST THREE, and one match has its own line', () {
      final three = squadStateHint(save(matchesPlayed: 11))!;
      expect(three.key, 'squadstate.run_in');
      expect(three.params['n'], 3);

      final one = squadStateHint(save(matchesPlayed: 13))!;
      expect(one.key, 'squadstate.run_in_one');
      // `run_in_one` writes the number out in words, but the param rides along
      // anyway: the params a pooled key needs are the union across its
      // variants, and a spare costs the caller nothing.
      expect(one.params['n'], 1);

      expect(keyOf(save(matchesPlayed: 10)), isNot('squadstate.run_in'));
    });

    test('SIX RATING POINTS BEHIND THE AVERAGE IS OUTGUNNED', () {
      // Eleven tier-ones rate 18. Against an average of 30 that is outgunned;
      // against 22 it is not, and the boundary is the spec's `- 6`.
      expect(keyOf(save(tier: 1, oppRating: 30)), 'squadstate.weak_lower');
      expect(keyOf(save(tier: 1, oppRating: 22)),
          isNot('squadstate.weak_lower'));
    });

    test('and WHICH weakness he names is whether the division has a way out',
        () {
      // A division that can field silver has merging as an answer; one that
      // cannot has only patience, and the two keys say exactly that.
      expect(keyOf(save(tier: 1, oppRating: 30, division: 'sunday_league')),
          'squadstate.weak_lower');
      expect(keyOf(save(tier: 1, oppRating: 40, division: 'amateur_cup')),
          'squadstate.weak_higher');
    });

    test('a bronze-heavy side is a SEASON-START note, not a standing one', () {
      // Six in ten at tier two or below, before a ball is kicked, in a division
      // that can actually field silver.
      expect(
        keyOf(save(
          tier: 1,
          oppRating: 20,
          division: 'amateur_cup',
          matchesPlayed: 0,
        )),
        'squadstate.bronze_heavy',
      );
      expect(
        keyOf(save(
          tier: 1,
          oppRating: 20,
          division: 'amateur_cup',
          matchesPlayed: 3,
        )),
        isNot('squadstate.bronze_heavy'),
      );
    });

    test('THREE OWNED ASSETS, ALL TIER ONE, and it beats a thin squad', () {
      // `assets_t1` sits above `thin_squad` in the chain, so a club with both
      // problems is told about the one an upgrade fixes.
      expect(
        keyOf(save(
          oppRating: 30,
          ownedAssets: const {'TRAINING': 1, 'STADIUM': 1, 'MEDIA': 1},
        )),
        'squadstate.assets_t1',
      );
      // One of them upgraded and the line is gone.
      expect(
        keyOf(save(
          oppRating: 30,
          ownedAssets: const {'TRAINING': 2, 'STADIUM': 1, 'MEDIA': 1},
        )),
        isNot('squadstate.assets_t1'),
      );
      // Two owned is not enough of a club to have an opinion about.
      expect(
        keyOf(save(
          oppRating: 30,
          ownedAssets: const {'TRAINING': 1, 'STADIUM': 1},
        )),
        isNot('squadstate.assets_t1'),
      );
    });

    test('an UNOWNED asset is not a tier-one asset', () {
      // A fresh save owns nothing, and being told its facilities are basic
      // before it has any would be the first thing every new player read.
      expect(keyOf(save(oppRating: 30)), isNot('squadstate.assets_t1'));
    });

    test('a thin squad is four short of the cap', () {
      expect(keyOf(save(oppRating: 30)), 'squadstate.thin_squad');
      expect(keyOf(save(cards: 26, oppRating: 30)),
          isNot('squadstate.thin_squad'));
    });

    test('THE NEW SEASON NAMES THE DIVISION, in the player\'s language', () {
      final hint = squadStateHint(save(
        cards: 26,
        oppRating: 30,
        matchesPlayed: 0,
        division: 'regional_league',
      ))!;
      expect(hint.key, 'squadstate.season_start');
      expect(hint.params['div'], t('division.regional_league'));

      setLocale('de');
      final de = squadStateHint(save(
        cards: 26,
        oppRating: 30,
        matchesPlayed: 0,
        division: 'regional_league',
      ))!;
      expect(de.params['div'], isNot(hint.params['div']));
    });

    test('and a side that outrates the BEST of them is strong', () {
      // The strong line reads against the hardest fixture rather than the
      // average — being better than the median of a league you are in the
      // middle of is not a promotion push.
      expect(keyOf(save(cards: 26, tier: 7, oppRating: 30)),
          'squadstate.strong');
      expect(keyOf(save(cards: 26, tier: 7, oppRating: 74)),
          isNot('squadstate.strong'));
    });
  });

  group('and he is allowed to say nothing', () {
    test('A SQUAD WITH NO STORY GETS NO LINE', () {
      // Every branch answered no. The JS returns null here rather than filler,
      // and the floating coach stays shut — a head that always has an opinion
      // is one nobody opens.
      expect(squadStateHint(save(cards: 26, tier: 3, oppRating: 35)), isNull);
    });

    test('a save with no progression at all is not a squad state', () {
      expect(squadStateHint(null), isNull);
      expect(squadStateHint(<String, dynamic>{}), isNull);
    });
  });

  group('the seed holds his wording still', () {
    test('IT IS THE SEASON AND THE MATCH, not the tick', () {
      // The pool is rebuilt on every change to the save, so a seed that moved
      // with the coin balance would have Colin rephrasing himself on every idle
      // tick — which is exactly the bug `tPoolStable` was written for.
      final a = squadStateHint(save(cards: 2, coins: 1500))!;
      final b = squadStateHint(save(cards: 2, coins: 9999))!;
      expect(a.seed, b.seed);
      expect(a.seed, 'state-s1-m5');
      expect(squadStateHint(save(cards: 2, matchesPlayed: 6))!.seed,
          'state-s1-m6');
    });
  });

  group('every sentence he can reach', () {
    test('RESOLVES, in all thirteen keys and every variant', () {
      // The two keys that take a placeholder are the ones this catches: a
      // caller supplying what one variant needs leaves literal braces in the
      // others, and which variant a player sees is a seed.
      final saves = <Map<String, dynamic>>[
        save(cards: 2),
        save(energy: 2),
        save(poorForm: 3),
        save(awardedPlayed: 5, wins: 3),
        save(matchesPlayed: 11),
        save(matchesPlayed: 13),
        save(tier: 1, oppRating: 30),
        save(tier: 1, oppRating: 40, division: 'amateur_cup'),
        save(tier: 1, oppRating: 20, division: 'amateur_cup', matchesPlayed: 0),
        save(oppRating: 30, ownedAssets: const {
          'TRAINING': 1,
          'STADIUM': 1,
          'MEDIA': 1,
        }),
        save(oppRating: 30),
        save(cards: 26, oppRating: 30, matchesPlayed: 0),
        save(cards: 26, tier: 7, oppRating: 30),
      ];
      final seen = <String>{};
      for (final s in saves) {
        final hint = squadStateHint(s)!;
        seen.add(hint.key);
        for (final sentence
            in t(hint.key, hint.params).split('|')) {
          expect(sentence, isNot(contains('{')), reason: hint.key);
          expect(sentence, isNot(contains('}')), reason: hint.key);
          expect(sentence.trim(), isNotEmpty, reason: hint.key);
        }
      }
      // And all thirteen were actually reached — a key nobody can get to
      // cannot pass this by never being looked at, which is the whole reason
      // these were unreachable in the first place.
      expect(seen, hasLength(13));
    });
  });

  group('WHERE HE IS ON THE AGE CURVE', () {
    // Four more `squad.badge.*` keys shipped in ten languages with no caller —
    // the injured badge was one of eight. The thresholds are not invented: they
    // are the ladder `coach_tips.dart` already runs on, lifted so the badge on
    // a card and the sentence out of Colin cannot disagree about one player.

    test('most of a squad wears nothing', () {
      // A badge on every card says nothing about any of them — the rule the
      // form arrow already follows.
      for (var s = 0; s < 7; s++) {
        expect(ageBadgeKeyFor(s), isNull, reason: '$s seasons');
      }
    });

    test('and the ladder climbs in the order it becomes urgent', () {
      for (var s = 7; s < 10; s++) {
        expect(ageBadgeKeyFor(s), 'squad.badge.ageing', reason: '$s');
      }
      for (var s = 10; s < 13; s++) {
        expect(ageBadgeKeyFor(s), 'squad.badge.declining', reason: '$s');
      }
      expect(ageBadgeKeyFor(13), 'squad.badge.sell_now');
      expect(ageBadgeKeyFor(14), 'squad.badge.last_season');
    });

    test('A MAN IN HIS LAST SEASON IS STILL IN IT AT FIFTEEN', () {
      // `processAgeRegression` retires at fifteen, and it runs at the season
      // END — so a save can hold a card at fifteen that has not been swept yet,
      // and telling him he is merely "declining" would be the last thing the
      // game said about him.
      expect(ageBadgeKeyFor(retirementSeasons), 'squad.badge.last_season');
      expect(ageBadgeKeyFor(40), 'squad.badge.last_season');
    });

    test('and only the two that mean ACT NOW are urgent', () {
      expect(ageBadgeIsUrgent('squad.badge.last_season'), isTrue);
      expect(ageBadgeIsUrgent('squad.badge.sell_now'), isTrue);
      expect(ageBadgeIsUrgent('squad.badge.declining'), isFalse);
      expect(ageBadgeIsUrgent('squad.badge.ageing'), isFalse);
    });

    test('IT AGREES WITH COLIN, which is the whole reason it lives here', () {
      // His ladder: >=14 final season, ==13 sell now, 10..12 declining,
      // 7..9 veteran. If one moves without the other, a card can say "Ageing"
      // while he is calling the same man a sell-now.
      String? colin(int s) {
        if (s >= 14) return 'squad.badge.last_season';
        if (s == 13) return 'squad.badge.sell_now';
        if (s >= 10 && s < 13) return 'squad.badge.declining';
        if (s >= 7 && s < 10) return 'squad.badge.ageing';
        return null;
      }

      for (var s = 0; s <= 20; s++) {
        expect(ageBadgeKeyFor(s), colin(s), reason: '$s seasons');
      }
    });
  });


}
