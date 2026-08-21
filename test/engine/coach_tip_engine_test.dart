/// The one-time milestone tips.
///
/// **`seenTips` was a ledger with no ledger in it** — in the schema, written by
/// the migration, and read by nothing. So all sixteen tips and the forty-four
/// `coachtip.*` strings sitting translated in all ten catalogues were
/// unreachable.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/coach_tip_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> _save({
  int matchesPlayed = 0,
  bool hardMode = false,
  List<String> divisions = const [],
  List<Map<String, dynamic>?> cells = const [],
  int totalMerges = 1,
  int energy = 5,
  List<String> seen = const [],
  bool? tutorialDone,
  String? authUid,
  List<Object?> trophies = const [],
}) {
  final s = createDefaultState();
  final prog = s['progression'] as Map<String, dynamic>;
  prog['matchesPlayed'] = matchesPlayed;
  prog['divisionsUnlocked'] = [...divisions];
  prog['leagueTrophies'] = [...trophies];
  (s['settings'] as Map<String, dynamic>)['hardMode'] = hardMode;
  (s['grid'] as Map<String, dynamic>)['cells'] = [...cells];
  (s['stats'] as Map<String, dynamic>)['totalMerges'] = totalMerges;
  (s['energy'] as Map<String, dynamic>)['current'] = energy;
  (s['leaderboard'] as Map<String, dynamic>)['authUid'] = authUid;
  s['seenTips'] = [...seen];
  // **As the save is when anyone reads it.** `createDefaultState` writes
  // `tutorial.done: false` because it is pinned leaf-for-leaf to the JS's, and
  // `settleTutorial` flips it on the way in — this port has no onboarding to be
  // in the middle of.
  settleTutorial(s);
  if (tutorialDone != null) {
    s['tutorial'] = <String, dynamic>{'done': tutorialDone};
  }
  return s;
}

Map<String, dynamic> _card(
  String id, {
  int variant = 0,
  bool injured = false,
}) => {'definitionId': id, 'variant': variant, 'injured': injured};

CoachTipContext _at(String? tab, {bool postMatch = false, String? subtab}) =>
    (tab: tab, subtab: subtab, postMatch: postMatch);

void main() {
  group('the ledger', () {
    test('a tip fires ONCE, ever', () {
      final s = _save(matchesPlayed: 3, cells: [_card('a'), _card('b')]);
      final first = pickCoachTip(s, _at('club'));
      expect(first?.id, 'club_assets');

      markTipSeen(s, first!.id);
      expect(
        pickCoachTip(s, _at('club'))?.id,
        isNot('club_assets'),
        reason: 'it came back',
      );
      expect(s['seenTips'], contains('club_assets'));
    });

    test('and NEVER over onboarding', () {
      // `!= false`, not `== true`. Most saves predate the flag and reading them
      // as mid-tutorial has already cost this port two controls.
      final mid = _save(tutorialDone: false);
      expect(pickCoachTip(mid, _at('club')), isNull);
      expect(takeTipOnce(mid, 'sponsor'), isFalse);

      final old = _save()..remove('tutorial');
      expect(
        pickCoachTip(old, _at('club'))?.id,
        'club_assets',
        reason: 'a save from before the flag read as mid-tutorial',
      );
    });

    test('takeTipOnce spends an id, and only once', () {
      final s = _save();
      expect(takeTipOnce(s, 'sponsor'), isTrue);
      expect(takeTipOnce(s, 'sponsor'), isFalse);
      expect(s['seenTips'], contains('sponsor'));
      // ONE ledger. A tip spent through this must not come back as a popup, and
      // vice versa — two of them and it would.
      expect(hasSeenTip(s, 'sponsor'), isTrue);
    });

    test('the baseline banks what is ALREADY true, and nothing else', () {
      // Otherwise a tutorial's own forced match and scouts trigger a pile of
      // tips the moment it closes. Only conditions that turn true later fire.
      final s = _save(
        matchesPlayed: 3,
        cells: [for (var i = 0; i < 6; i++) _card('p$i')],
      );
      baselineCoachTips(s, _at('squad'));
      expect(s['seenTips'], contains('rename_player'));
      expect(s['seenTips'], contains('atk_def'));
      // Not banked: he has not been to the Club tab, so that lesson is still to
      // come.
      expect(s['seenTips'], isNot(contains('club_assets')));
      expect(pickCoachTip(s, _at('club'))?.id, 'club_assets');
    });
  });

  group('priority is the ORDER of the list', () {
    test('an injury outranks an explainer', () {
      // Urgent and actionable beat passive: a single moment should surface the
      // most useful thing, not the first thing that happens to be true.
      final s = _save(
        matchesPlayed: 3,
        cells: [_card('a', injured: true), _card('b')],
        trophies: const [<String, dynamic>{}],
      );
      expect(pickCoachTip(s, _at('squad', postMatch: true))?.id, 'injury');
      markTipSeen(s, 'injury');
      expect(pickCoachTip(s, _at('squad', postMatch: true))?.id, 'promotion');
    });
  });

  group('when each one applies', () {
    test(
      'POST-MATCH ONLY, for the three that would land on the wrong screen',
      () {
        // An injury tip on the pre-match screen, or an energy tip fired the
        // instant Play spends the last pip, both pop over the game you are about
        // to watch.
        final injured = _save(cells: [_card('a', injured: true)]);
        expect(pickCoachTip(injured, _at('squad'))?.id, isNot('injury'));
        expect(
          pickCoachTip(injured, _at('squad', postMatch: true))?.id,
          'injury',
        );

        final flat = _save(energy: 0);
        expect(pickCoachTip(flat, _at('league'))?.id, isNot('energy'));
        expect(
          pickCoachTip(flat, _at('league', postMatch: true))?.id,
          'energy',
        );
      },
    );

    test(
      'the merge lesson waits for a PAIR, and for a player who has none',
      () {
        final none = _save(totalMerges: 0, cells: [_card('a'), _card('b')]);
        expect(pickCoachTip(none, _at('grid')), isNull);

        final pair = _save(totalMerges: 0, cells: [_card('a'), _card('a')]);
        expect(pickCoachTip(pair, _at('grid'))?.id, 'merge');

        // **Gender counts**, which is the actual merge rule: variant 0 is a man
        // and variant 2 is a woman, so those two are not a pair however matched
        // their definitions are. Two men are.
        final mixed = _save(
          totalMerges: 0,
          cells: [_card('a'), _card('a', variant: 2)],
        );
        expect(hasMergeablePair(mixed), isFalse);
        expect(pickCoachTip(mixed, _at('grid')), isNull);
        final sameSex = _save(
          totalMerges: 0,
          cells: [_card('a'), _card('a', variant: 1)],
        );
        expect(hasMergeablePair(sameSex), isTrue);

        // And a player who has already merged has nothing to learn.
        final veteran = _save(totalMerges: 4, cells: [_card('a'), _card('a')]);
        expect(pickCoachTip(veteran, _at('grid')), isNull);
      },
    );

    test('HARD MODE splits the fitness lesson from the bench one', () {
      // Hard has fitness bars to hang the lesson on; Casual has none, so its
      // counterpart is about the bench and waits a couple of games.
      final pro = _save(hardMode: true, matchesPlayed: 1);
      expect(pickCoachTip(pro, _at('squad'))?.id, 'fatigue');

      final casual = _save(matchesPlayed: 2);
      expect(pickCoachTip(casual, _at('league'))?.id, 'subs_bench');
      expect(
        pickCoachTip(pro, _at('league'))?.id,
        isNot('subs_bench'),
        reason: 'Casual\'s lesson fired in Pro',
      );
    });

    test('and Hard mode gets NO tactical hand-holding', () {
      final pro = _save(
        hardMode: true,
        matchesPlayed: 3,
        seen: const ['fatigue'],
      );
      expect(pickCoachTip(pro, _at('squad'))?.id, isNot('atk_def'));
    });

    test(
      'auto-sell is skipped for anyone who found the setting themselves',
      () {
        // A rule already switched on has nothing to explain.
        final unaware = _save(divisions: const ['elite_league']);
        expect(pickCoachTip(unaware, _at('shop'))?.id, 'auto_sell');

        final aware = _save(divisions: const ['elite_league']);
        setTierAction(aware, autoTiers.first, TierAction.sell);
        expect(pickCoachTip(aware, _at('shop'))?.id, isNot('auto_sell'));
      },
    );

    test('and the cloud nag only bothers somebody who is not signed in', () {
      final out = _save(matchesPlayed: 10);
      expect(pickCoachTip(out, _at('shop'))?.id, 'save_progress');
      expect(
        coachTips.firstWhere((t) => t.id == 'save_progress').bodyParams!(out),
        {'n': 10},
      );

      final inn = _save(matchesPlayed: 10, authUid: 'abc');
      expect(pickCoachTip(inn, _at('shop')), isNull);
    });

    test('the training tip is the SUB-TAB, not a tab', () {
      final s = _save();
      expect(pickCoachTip(s, _at(null, subtab: 'minigames'))?.id, 'training');
      expect(pickCoachTip(s, _at('league')), isNull);
    });
  });

  test('every tip names copy that exists, and a CTA carries a label', () {
    // The build fails on a missing key, but only for a key a call site
    // MENTIONS — and these are built from an id, so nothing would have caught a
    // typo.
    for (final tip in coachTips) {
      expect(tip.titleKey, 'coachtip.${tip.id}.title');
      expect(tip.bodyKey, 'coachtip.${tip.id}.body');
      expect(
        tip.cta == null,
        tip.ctaLabelKey == null,
        reason: '${tip.id} has one half of a button',
      );
    }
  });
}
