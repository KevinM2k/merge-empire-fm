import 'package:merge_empire_fc/engine/coach_tip_engine.dart';
import 'package:merge_empire_fc/engine/guide_engine.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fresh() {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)
    ..['done'] = true
    ..['completed'] = true;
  return s;
}

void main() {
  setUp(() => setLocale('en'));
  tearDown(resetLocale);

  group('WHO GETS THE TOUR', () {
    test('a save whose script ran to the end here', () {
      expect(guideActive(_fresh()), isTrue);
      expect(guideStepFor(_fresh(), GuideTab.grid)?.id, 'scout');
    });

    test('and NOT a save that was merely settled as done', () {
      // `settleTutorial` marks every old save that has played as done. That
      // is not a player who needs telling where the Squad tab is.
      final s = createDefaultState();
      (s['tutorial'] as Map<String, dynamic>)['done'] = true;
      expect(guideActive(s), isFalse);
      expect(guideStepFor(s, GuideTab.home), isNull);
      expect(guideHighlight(s), isNull);
    });

    test('nor one still mid-script', () {
      expect(guideStepFor(createDefaultState(), GuideTab.home), isNull);
    });

    test('and advancing off the end of the script is what switches it on', () {
      final s = createDefaultState();
      (s['tutorial'] as Map<String, dynamic>)['step'] =
          tutorialSteps.length - 1;
      advanceTutorial(s);
      expect(guideActive(s), isTrue);
    });

    test('but skipping the script does not', () {
      final s = createDefaultState();
      skipTutorial(s);
      expect(tutorialFinished(s), isTrue);
      expect(guideActive(s), isFalse);
    });
  });

  group('THE CHAIN', () {
    test('opens on the grid, where the script left them, with nothing lit', () {
      final s = _fresh();
      // The tutorial ends on the Players tab, so the first nudge is the thing
      // to do THERE — and "tap Scout" is not a tab, so nothing in the bar glows.
      expect(guideStepFor(s, GuideTab.grid)?.id, 'scout');
      expect(guideHighlight(s), isNull);
      // The home orb, meanwhile, has the Dugout to mention.
      expect(guideStepFor(s, GuideTab.home)?.id, 'dugout');
    });

    test('a card landing lights the Squad tab, and opening it spends the step', () {
      final s = _fresh();
      markGuideDone(s, 'scout');
      expect(guideStepFor(s, GuideTab.grid)?.id, 'squad_tab');
      expect(guideHighlight(s), GuideTab.squad);
      guideTabOpened(s, GuideTab.squad);
      expect(guideStepFor(s, GuideTab.grid), isNull);
      expect(guideHighlight(s), isNull, reason: 'the next step is on the pitch');
    });

    test('and a step done is NEVER said again', () {
      final s = _fresh();
      markGuideDone(s, 'scout');
      expect(guideStepFor(s, GuideTab.grid)?.id, 'squad_tab');
      expect(hasSeenTip(s, 'guide.scout'), isTrue);
      markGuideDone(s, 'scout');
      expect(
        (s['seenTips'] as List).where((e) => e == 'guide.scout').length,
        1,
        reason: 'the ledger holds one entry per step',
      );
    });

    test('a filled eleven satisfies the squad step by itself', () {
      final s = _fresh();
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      for (var i = 0; i < 11; i++) {
        cells[i] = {'instanceId': 'c$i', 'definitionId': 'player_t1_def'};
      }
      expect(guideStepFor(s, GuideTab.squad)?.id, 'squad_fill');
      (s['squad'] as Map<String, dynamic>)['lineup'] = [
        for (var i = 0; i < 11; i++) {'slotId': 's$i', 'instanceId': 'c$i'},
      ];
      expect(guideStepFor(s, GuideTab.squad), isNull);
    });

    test('and so does a side with everyone they own on it', () {
      final s = _fresh();
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      cells[0] = {'instanceId': 'c0', 'definitionId': 'player_t1_def'};
      cells[1] = {'instanceId': 'c1', 'definitionId': 'player_t1_def'};
      (s['squad'] as Map<String, dynamic>)['lineup'] = [
        {'slotId': 'a', 'instanceId': 'c0'},
        {'slotId': 'b', 'instanceId': 'c1'},
        {'slotId': 'c', 'instanceId': null},
      ];
      expect(guideStepFor(s, GuideTab.squad), isNull);
    });

    test('a facility owned satisfies the club step by itself', () {
      final s = _fresh();
      expect(guideStepFor(s, GuideTab.club)?.id, 'club_buy');
      (s['clubAssets'] as Map<String, dynamic>)['stadium'] = {
        'owned': true,
        'tier': 1,
      };
      expect(guideStepFor(s, GuideTab.club)?.id, 'shop_tab');
      expect(guideStepFor(s, GuideTab.club)?.leadsTo, GuideTab.shop);
    });

    test('and the tour ends', () {
      final s = _fresh();
      for (final step in guideSteps) {
        markGuideDone(s, step.id);
      }
      for (final tab in GuideTab.values) {
        expect(guideStepFor(s, tab), isNull);
      }
      expect(guideHighlight(s), isNull);
    });
  });

  group('WHAT HE SAYS', () {
    test('every step has copy, and it names the tab in the bar\'s own word', () {
      for (final step in guideSteps) {
        final text = guideText(step);
        expect(text, isNot(step.copyKey), reason: '${step.copyKey} missing');
        expect(text, isNot(contains('{')), reason: '$text has a raw brace');
        if (step.leadsTo != null) {
          expect(text, contains(t(guideTabLabelKey[step.leadsTo]!)));
        }
      }
    });
  });
}
