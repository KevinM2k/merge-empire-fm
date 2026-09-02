/// The playback clock.
///
/// `simulateMatch` decides the whole match up front; this only decides when an
/// already-decided event appears. The tests are mostly about that boundary.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';

Map<String, dynamic> resultWith({
  int addedTime = 3,
  List<Map<String, dynamic>> events = const [],
}) => {'addedTime': addedTime, 'events': events};

Map<String, dynamic> goal(int minute, String team) => {
  'minute': minute,
  'type': 'goal',
  'team': team,
  'scorer': 'Scorer $minute',
};

void main() {
  group('the timeline', () {
    test('is sorted by minute however it arrives', () {
      final result = resultWith(
        events: [goal(70, 'home'), goal(12, 'away'), goal(45, 'home')],
      );
      expect(timelineOf(result).map((e) => e.minute), [12, 45, 70]);
    });

    test('survives a result with no events at all', () {
      expect(timelineOf(resultWith()), isEmpty);
      expect(timelineOf(<String, dynamic>{}), isEmpty);
    });

    test('carries the commentary key through', () {
      final result = resultWith(
        events: [
          {
            'minute': 20,
            'type': 'commentary',
            'team': 'home',
            'textKey': 'commentary.flow.midfield.0',
          },
        ],
      );
      expect(timelineOf(result).single.textKey, 'commentary.flow.midfield.0');
    });
  });

  group('the frame', () {
    test('shows nothing at kickoff', () {
      final result = resultWith(events: [goal(12, 'home')]);
      final frame = frameAt(result, 0);
      expect(frame.shown, isEmpty);
      expect(frame.ourGoals, 0);
      expect(frame.theirGoals, 0);
    });

    test('counts the score from the goals SHOWN, not the result', () {
      // The number on screen must never run ahead of the commentary that
      // explains it.
      final result = resultWith(events: [goal(12, 'home'), goal(80, 'home')]);
      expect(frameAt(result, 11).ourGoals, 0);
      expect(frameAt(result, 12).ourGoals, 1);
      expect(frameAt(result, 79).ourGoals, 1);
      expect(frameAt(result, 80).ourGoals, 2);
    });

    test('keeps the two sides apart', () {
      final result = resultWith(
        events: [goal(10, 'home'), goal(20, 'away'), goal(30, 'away')],
      );
      final frame = frameAt(result, 90);
      expect(frame.ourGoals, 1);
      expect(frame.theirGoals, 2);
    });

    test('a goal with no team is ours', () {
      // The engine omits `team` on some goals; treating that as the opposition
      // would hand the other side a goal the player just scored.
      final result = resultWith(
        events: [
          {'minute': 10, 'type': 'goal', 'scorer': 'X'},
        ],
      );
      expect(frameAt(result, 90).ourGoals, 1);
      expect(frameAt(result, 90).theirGoals, 0);
    });

    test('non-goal events never move the score', () {
      final result = resultWith(
        events: [
          {'minute': 10, 'type': 'corner', 'team': 'home'},
          {'minute': 45, 'type': 'halftime'},
          {'minute': 60, 'type': 'commentary', 'team': 'away'},
        ],
      );
      final frame = frameAt(result, 90);
      expect(frame.shown.length, 3);
      expect(frame.ourGoals, 0);
      expect(frame.theirGoals, 0);
    });

    test('finishes at ninety plus added time, not at ninety', () {
      final result = resultWith(addedTime: 4);
      expect(frameAt(result, 90).finished, isFalse);
      expect(frameAt(result, 93).finished, isFalse);
      expect(frameAt(result, 94).finished, isTrue);
    });

    test('a negative added time is treated as none', () {
      expect(fullTime(-5), 90);
      expect(frameAt(resultWith(addedTime: -5), 90).finished, isTrue);
    });

    test('the final frame shows everything', () {
      final result = resultWith(
        events: [goal(1, 'home'), goal(93, 'away')],
        addedTime: 5,
      );
      final frame = frameAt(result, fullTime(5));
      expect(frame.shown.length, 2);
      expect(frame.finished, isTrue);
    });
  });

  group('the pace', () {
    test('fast mode HALVES the wait rather than skipping anything', () {
      // Exactly half, which is what the ×2 on the button says.
      expect(minuteDuration(fast: true) * 2, minuteDuration(fast: false));
    });

    test('AND THE PACE IS THE SPEC\'S, not a third of it', () {
      // `MatchPopup.js` ticks one minute per `TICK_MS = 350`, halved to 175.
      // The port had 120 and 60, so a ninety-minute match went by in eleven
      // seconds and the ×2 was six — reported as "1× seems to have gone fast
      // and 2× is far too fast".
      expect(matchMinuteMs, 350);
      expect(matchMinuteMsFast, 175);
      // A whole match is about half a minute, which is what the commentary was
      // written to be read at — and still something a player will sit through.
      final whole = minuteDuration(fast: false) * 93;
      expect(whole, greaterThan(const Duration(seconds: 25)));
      expect(whole, lessThan(const Duration(seconds: 40)));
    });
  });

  group('THE COMMENTARY AND THE PITCH NAME THE SAME MAN', () {
    // **The row is "the player name needs to match in the commentary who
    // scored it and when viewing replay it needs to be identical".** One half
    // was found and fixed earlier — the feed was reading a name SNAPSHOT while
    // everything the pitch draws resolved the card live. This is the other
    // half, and it was readable after all: the feed and the full-time scorers
    // card both fall back to the recorded name when the card has gone, and the
    // two CUTAWAY call sites — the live cut and the replay of it — had only the
    // live half. A sold scorer resolved to null there, so the shooter's dot was
    // never forced to his name and the pitch put a generic lineup name on the
    // man the feed directly above it had just named.
    TimelineEvent goal({String? scorer, String? scorerId}) => (
      minute: 22,
      type: 'goal',
      team: 'home',
      scorer: scorer,
      scorerId: scorerId,
      textKey: null,
      shotResult: null,
      big: false,
      xg: 0,
      params: const {},
      card: null,
      playerId: null,
      player: null,
    );

    // The save, as far as this rule is concerned: which ids still have a card.
    String? onTheGrid(Map<String, dynamic>? save, String id) =>
        id == 'here' ? 'Live Name' : null;

    test('a card still on the grid is named LIVE', () {
      // The whole point of the earlier half: a player who has been renamed or
      // re-rolled shows what he is called NOW, not what he was called then.
      expect(
        clipScorerName(
          const {},
          goal(scorer: 'Recorded Name', scorerId: 'here'),
          ours: true,
          nameOf: onTheGrid,
        ),
        'Live Name',
      );
    });

    test('AND A SOLD ONE STILL SCORED', () {
      expect(
        clipScorerName(
          const {},
          goal(scorer: 'Recorded Name', scorerId: 'gone'),
          ours: true,
          nameOf: onTheGrid,
        ),
        'Recorded Name',
        reason: 'the pitch would have had no name to put on him',
      );
    });

    test('and it agrees with the FEED, which is the whole ask', () {
      // Same event, same resolver, both readings — this is the assertion the
      // row is actually making, and it is the reason the rule is one shared
      // function rather than the same `??` written at each call site.
      final sold = goal(scorer: 'Recorded Name', scorerId: 'gone');
      final line = feedOf(
        [sold],
        ourName: 'Us',
        theirName: 'Them',
        isHome: true,
        nameOf: (id) => onTheGrid(const {}, id),
      ).first;
      expect(
        line.params.values,
        contains('Recorded Name'),
        reason: 'the feed prints the recorded name for a sold scorer',
      );
      expect(
        clipScorerName(const {}, sold, ours: true, nameOf: onTheGrid),
        'Recorded Name',
      );
    });

    test('a goal against gets no name forced onto anyone', () {
      // Their scorer is not one of our cards and never was.
      expect(
        clipScorerName(
          const {},
          goal(scorer: 'Their Man', scorerId: 'gone'),
          ours: false,
          nameOf: onTheGrid,
        ),
        isNull,
      );
    });

    test('and neither does a chance', () {
      expect(
        clipScorerName(
          const {},
          (
            minute: 30,
            type: 'chance',
            team: 'home',
            scorer: 'Recorded Name',
            scorerId: 'gone',
            textKey: null,
            shotResult: 'on_target',
            big: true,
            xg: 0.4,
            player: null,
            params: {},
            card: null,
            playerId: null,
          ),
          ours: true,
          nameOf: onTheGrid,
        ),
        isNull,
      );
    });
  });

  group('THE FEED', () {
    TimelineEvent ev(
      String type, {
      int minute = 10,
      String team = 'home',
      String? shotResult,
      bool big = false,
      double xg = 0,
      String? scorer,
      String? scorerId,
      String? player,
      String? textKey,
      Map<String, Object?> params = const {},
    }) => (
      minute: minute,
      type: type,
      team: team,
      scorer: scorer,
      scorerId: scorerId,
      textKey: textKey,
      shotResult: shotResult,
      big: big,
      xg: xg,
      player: player,
      params: params,
      card: null,
      playerId: null,
    );

    List<FeedLine> feed(List<TimelineEvent> events, {bool isHome = true}) =>
        feedOf(events, ourName: 'Us', theirName: 'Them', isHome: isHome);

    test('and the timeline is what carries them off the result', () {
      // The record had no field for `textParams`, so the engine wrote them and
      // nothing read them.
      final events = timelineOf({
        'events': [
          {
            'minute': 1,
            'type': 'commentary',
            'textKey': 'commentary.snub',
            'textParams': {'opp': 'Ayton'},
          },
        ],
      });
      expect(events.single.params['opp'], 'Ayton');
    });

    group('MORE THAN GOALS HAPPENS IN NINETY MINUTES', () {
      // Asked for from the couch: the feed should carry the other things a
      // match is made of, not only what went in. Every line below was already
      // written and translated ten times over — what was missing was the case
      // in `feedOf` that reaches it.

      test('THE BREAK SAYS WHAT THE SCORE MEANS', () {
        // It was `match.half_time`, which is the word the row's own HEAD
        // prints, so the interval read its own name twice and said nothing.
        String at(List<TimelineEvent> before) => feed([
          ...before,
          ev('halftime', minute: 45),
        ]).last.key;

        expect(at(const []), 'commentary.halftime_level');
        expect(
          at([ev('goal', minute: 20, team: 'home')]),
          'commentary.halftime_ahead',
        );
        expect(
          at([ev('goal', minute: 20, team: 'away')]),
          'commentary.halftime_behind',
        );
      });

      test('and it is the score AS THE FEED HAS TOLD IT', () {
        // A goal after the whistle cannot change what the verdict at the break
        // was — the running tally is what half time is judged on.
        final lines = feed([
          ev('goal', minute: 20, team: 'home'),
          ev('halftime', minute: 45),
          ev('goal', minute: 70, team: 'away'),
          ev('goal', minute: 80, team: 'away'),
        ]);
        expect(
          lines.firstWhere((l) => l.type == 'halftime').key,
          'commentary.halftime_ahead',
        );
      });

      test('THEIR SUBSTITUTIONS REACH THE FEED', () {
        // `buildMatchResult` pushes one `opp_sub` per entry in the AI's
        // rotation plan, key and parameters written onto the event. `feedOf`
        // had no case for it, so it fell through to `default` and the only
        // changes a player ever saw were their own.
        final lines = feed([
          ev(
            'opp_sub',
            minute: 60,
            textKey: 'commentary.opp_sub',
            params: const {'opp': 'Ayton'},
          ),
        ]);
        expect(lines, hasLength(1));
        expect(lines.single.type, 'opp_sub');
        expect(lines.single.key, 'commentary.opp_sub');
        expect(lines.single.params['opp'], 'Ayton');
      });

      test('AND A LINE KEEPS THE PARAMETERS IT WAS WRITTEN WITH', () {
        // The grudge line is the one that reached a screen: `commentary.snub`
        // takes `{opp}`, the feed handed `t()` an empty map, and a grudge match
        // opened by printing that brace to the player.
        final lines = feed([
          ev(
            'commentary',
            minute: 1,
            textKey: 'commentary.snub',
            params: const {'opp': 'Ayton'},
          ),
        ]);
        expect(lines.single.params['opp'], 'Ayton');
        expect(
          t(lines.single.key, lines.single.params),
          isNot(contains('{opp}')),
        );
      });
    });

    group('THE OPENING IS NOT SILENT', () {
      // `commentaryPools` says one line at minute 1 and the next anywhere in
      // 15..30, so a match spoke once and then said nothing for between fourteen
      // and twenty-nine minutes. Reported as the commentary being too quiet when
      // a game starts.
      List<FeedLine> opening(String opener) =>
          feed([ev('commentary', minute: 1, textKey: opener)]);

      test('the whole kick-off pool is said, not one line of it', () {
        final lines = opening('${openFlowPrefix}0');
        final pool = commentaryPools.firstWhere(
          (({List<int> range, String bucket, int count}) p) => p.bucket == 'open',
        );
        expect(lines, hasLength(pool.count));
        // Every line in the pool, once.
        expect(
          lines.map((l) => l.key).toSet(),
          {for (var i = 0; i < pool.count; i++) '$openFlowPrefix$i'},
        );
      });

      test('AND THE ENGINE STILL LEADS', () {
        // The seeded pick is what a match opens with and that has not changed —
        // the screen only fills the quiet after it.
        for (final i in [0, 1, 2]) {
          final lines = opening('$openFlowPrefix$i');
          expect(lines.first.key, '$openFlowPrefix$i');
          expect(lines.first.minute, 1);
        }
      });

      test('and they land in the window the engine leaves empty', () {
        final lines = opening('$openFlowPrefix$openKickoffIndex');
        expect(lines.map((l) => l.minute), [1, ...openingFillMinutes]);
        // Before `firstA` can possibly speak, which is the whole point.
        final firstA = commentaryPools.firstWhere(
          (({List<int> range, String bucket, int count}) p) =>
              p.bucket == 'firstA',
        );
        expect(lines.last.minute, lessThan(firstA.range[0]));
      });

      test('BUT THE KICK-OFF LINE NEVER MOVES', () {
        // `open.0` is "Kick-off! Both sides finding their feet." — it is about
        // the first whistle, not about the opening period — so when the engine
        // opened with one of the other two, this offered it as filler and a
        // match printed "6' Kick-off" six minutes in. Reported from the couch.
        for (final opener in [1, 2]) {
          final lines = opening('$openFlowPrefix$opener');
          expect(
            lines.map((l) => l.key),
            isNot(contains('$openFlowPrefix$openKickoffIndex')),
            reason: 'kick-off was said after kick-off',
          );
          // The pool is one line shorter than it looks, so one filler lands.
          expect(lines.map((l) => l.minute), [1, openingFillMinutes.first]);
        }
      });

      test('AND NOTHING IS SAID BEFORE THE CLOCK REACHES IT', () {
        // The filler is minted by the feed rather than released by the frame,
        // so it was the one thing in the list that could arrive whole: a match
        // in its third minute already showed "11' Early pressure from the
        // midfield", and a goal in the eighth went in UNDER it. Reported from
        // the couch.
        List<int> at(int minute) => feedOf(
          [ev('commentary', minute: 1, textKey: '${openFlowPrefix}0')],
          ourName: 'Us',
          theirName: 'Them',
          isHome: true,
          minute: minute,
        ).map((l) => l.minute).toList();

        expect(at(1), [1]);
        expect(at(openingFillMinutes.first - 1), [1]);
        expect(at(openingFillMinutes.first), [1, openingFillMinutes.first]);
        expect(at(openingFillMinutes.last), [1, ...openingFillMinutes]);
        // And with no clock at all, the whole lot — which is what the chance
        // filter derives itself against.
        expect(at(90), [1, ...openingFillMinutes]);
      });

      test('and a line from any OTHER bucket fills nothing', () {
        final lines = feed([
          ev('commentary', minute: 20, textKey: 'commentary.flow.firstA.0'),
        ]);
        expect(lines, hasLength(1));
      });

      test('AND THE MERGE KEEPS MINUTE ORDER, ties to the engine', () {
        // The filler is held back and merged, so a goal in a minute it shares
        // reads first and everything else stays where the engine put it.
        final lines = feed([
          ev('commentary', minute: 1, textKey: '${openFlowPrefix}0'),
          ev('goal', minute: 6),
          ev('goal', minute: 30, team: 'away'),
        ]);
        expect(lines.map((l) => l.minute).toList(), [1, 6, 6, 11, 30]);
        expect(lines[1].type, 'goal', reason: 'the goal lost its own minute');
      });
    });
    group('AND A CHANCE NOBODY SEES MAKES NO NOISE', () {
      // There are about thirteen chances in a match and the feed prints three
      // or four. The sound was hung on the EVENT, so all thirteen played a kick
      // and every on-target one played the crowd on top of it — nine or ten
      // noises a match with nothing on screen. Reported as miss noises with no
      // action.
      test('the shown minutes are the feed\'s own, not the timeline\'s', () {
        final events = [
          // Big, on target: printed, so it is heard.
          ev('chance', minute: 5, shotResult: 'on_target', big: true, xg: 0.4),
          // Inside the gap: dropped by the feed, so silent.
          ev('chance', minute: 9, shotResult: 'on_target', big: true, xg: 0.4),
          // Off target: dropped, so silent.
          ev('chance', minute: 40, shotResult: 'off', big: true, xg: 0.4),
          // Small: dropped, so silent.
          ev('chance', minute: 60, shotResult: 'on_target', xg: 0.1),
          // Big, on target, clear of the last SHOWN one: printed.
          ev('chance', minute: 70, shotResult: 'on_target', big: true, xg: 0.4),
        ];
        expect(feedChanceMinutes(events), {5, 70});
        // And that is exactly the set the feed itself prints, because it is
        // the feed that produced it.
        expect(
          feed(events).where((l) => l.type == 'chance').map((l) => l.minute),
          [5, 70],
        );
      });

      test('and a chance the pitch retold is heard, whatever its numbers', () {
        // A clip bypasses the filters — it is on screen by definition — so the
        // sound has to follow it there too.
        final events = [ev('chance', minute: 12, shotResult: 'off', xg: 0.05)];
        expect(feedChanceMinutes(events), isEmpty);
        expect(
          feedChanceMinutes(
            events,
            clippedChanceKeys: const {12: 'commentary.shot_wide'},
          ),
          {12},
        );
      });

      test('and nothing else in the timeline counts as a chance', () {
        expect(
          feedChanceMinutes([
            ev('goal', minute: 5),
            ev('corner', minute: 7),
            ev('injury', minute: 9, player: 'Smith'),
          ]),
          isEmpty,
        );
      });
    });

    test('AND A GOAL KNOWS WHOSE IT WAS', () {
      // The feed printed the scorer's NAME and carried nothing else, so a row
      // that wanted his face had a string to work from. The engine has written
      // `scorerInstanceId` all along — `finalizeMatchOutcome` attributes career
      // goals by it — and the line carries it now.
      final ours = feed([ev('goal', scorer: 'Bobby', scorerId: 'c7')]);
      expect(ours.single.aboutId, 'c7');

      // An opponent goal is nobody's, and it has to be: the engine picks
      // scorers from OUR squad, so a face for one of theirs cannot be drawn.
      final theirs = feed([ev('goal', team: 'away')]);
      expect(theirs.single.aboutId, isNull);

      // And a goal with no scorer at all — an own goal, an older save — is a
      // line without a face rather than a line without a goal.
      expect(feed([ev('goal')]).single.aboutId, isNull);
    });

    test('ONE NAME PER GOAL — the SAVE is asked, not the snapshot', () {
      // `event.scorer` is a name captured when the events were generated; the
      // 2D pitch, the replay badge and the full-time scorers card all resolve
      // the card LIVE through `cardDisplayName`. Two readings of one question,
      // and they part company the moment anything happens to the card between
      // the whistle and the replay — reported as the commentary and the replay
      // needing to name the same man.
      final lines = feedOf(
        [ev('goal', scorer: 'Old Name', scorerId: 'c1')],
        ourName: 'Us',
        theirName: 'Them',
        isHome: true,
        nameOf: (id) => id == 'c1' ? 'New Name' : null,
      );
      expect(lines.single.params['scorer'], 'New Name');
    });

    test('and the snapshot is the fallback, for a card the save has lost', () {
      // A sold or merged scorer has no card to look up, and his goal still
      // happened. The name the match was played with is the only one left.
      final lines = feedOf(
        [ev('goal', scorer: 'Gone Away', scorerId: 'c9')],
        ourName: 'Us',
        theirName: 'Them',
        isHome: true,
        nameOf: (_) => null,
      );
      expect(lines.single.params['scorer'], 'Gone Away');
    });

    test('A CORNER SAYS NOTHING, and neither does full time', () {
      // The port fell through to printing `event.type`, so a corner read as the
      // word "corner" and full time as "fulltime" — raw, untranslated strings
      // from the engine on the one screen a player watches for ninety minutes.
      // A corner is a momentum nudge; it is not news.
      expect(feed([ev('corner'), ev('fulltime', minute: 90)]), isEmpty);
    });

    test('and a chance only earns a line if it was BIG and ON TARGET', () {
      // There is a chance about every seven minutes. Without both filters the
      // feed is nothing else.
      expect(feed([ev('chance', xg: 0.1, shotResult: 'on_target')]), isEmpty);
      expect(feed([ev('chance', big: true, shotResult: 'off')]), isEmpty);
      final one = feed([ev('chance', big: true, shotResult: 'on_target')]);
      expect(one, hasLength(1));
      expect(one.single.key, 'commentary.forces_save');
      expect(one.single.params['who'], 'Us');
    });

    test('A CHANCE THE PITCH RETOLD SAYS WHAT WAS SHOWN', () {
      // Every chance printed "forces a save" whatever the clip had drawn, so
      // the ball went over the bar and the feed said the keeper had it. A
      // retold chance always earns its line — it was watched — and the line is
      // the clip's ending. `_endCutaway` in `MatchPopup.js`.
      final lines = feedOf(
        [
          ev('chance', xg: 0.1, shotResult: 'off', minute: 20),
          ev('chance', xg: 0.1, shotResult: 'off', minute: 24),
        ],
        ourName: 'Us',
        theirName: 'Them',
        isHome: true,
        clippedChanceKeys: {24: 'commentary.hit_post'},
      );
      expect(lines, hasLength(1));
      expect(lines.single.minute, 24);
      expect(lines.single.key, 'commentary.hit_post');
    });

    test('and the second one inside ten minutes is held back', () {
      final lines = feed([
        ev('chance', minute: 10, big: true, shotResult: 'on_target'),
        ev('chance', minute: 15, big: true, shotResult: 'on_target'),
        ev('chance', minute: 22, big: true, shotResult: 'on_target'),
      ]);
      expect([for (final l in lines) l.minute], [10, 22]);
    });

    test('THE SIDE IS NAMED FROM THE PLAYER\'S POINT OF VIEW', () {
      final away = feed([
        ev('chance', team: 'away', big: true, shotResult: 'on_target'),
      ], isHome: true);
      expect(away.single.params['who'], 'Them');
      final ours = feed([
        ev('chance', team: 'away', big: true, shotResult: 'on_target'),
      ], isHome: false);
      expect(ours.single.params['who'], 'Us');
    });

    test('A GOAL IS DESCRIBED BY WHAT IT DID TO THE SCORE', () {
      // Eight `commentary.goal.*` pools sat translated in ten catalogues with
      // nothing able to reach one: the feed printed the scorer's name alone. But
      // equalising, pulling one back, going ahead and stretching a lead are four
      // different moments and the feed should not read the same for all four.
      final lines = feed([
        ev('goal', minute: 5, team: 'away'),
        ev('goal', minute: 20, team: 'home', scorer: 'Ada'),
        ev('goal', minute: 30, team: 'home', scorer: 'Ada'),
        ev('goal', minute: 40, team: 'home', scorer: 'Ada'),
      ]);
      expect(lines[0].key, 'commentary.opp_goal');
      expect(lines[0].params['them'], 'Them');
      expect(lines[1].key, 'commentary.goal.equalise.with_scorer');
      expect(lines[2].key, 'commentary.goal.lead.with_scorer');
      expect(lines[3].key, 'commentary.goal.extend.with_scorer');
    });

    test('and pulling one back is not the same as equalising', () {
      final lines = feed([
        ev('goal', minute: 5, team: 'away'),
        ev('goal', minute: 6, team: 'away'),
        ev('goal', minute: 20, team: 'home'),
      ]);
      expect(lines.last.key, 'commentary.goal.pullback.no_scorer');
    });

    test('and the POOL PICK IS STABLE, because the feed rebuilds', () {
      // Every tick of the clock rebuilds it, and a sentence that rerolls under
      // the reader is worse than one sentence.
      final a = feed([ev('goal', minute: 20, scorer: 'Ada')]).single;
      final b = feed([ev('goal', minute: 20, scorer: 'Ada')]).single;
      expect(a.seed, b.seed);
    });

    test('an injury names who went down', () {
      final line = feed([ev('injury', player: 'Ada')]).single;
      expect(line.key, 'commentary.injury');
      expect(line.params['player'], 'Ada');
    });
  });



  group('AN ATMOSPHERE LINE MAY NOT CLAIM A BOOKING', () {
    // Two of the JS's flow pools describe a card — "The ref books a midfielder
    // for a late challenge" and "Yellow card for time-wasting" — and they were
    // harmless colour until the port grew a referee. Now they are the feed
    // contradicting itself: a booking with no card, no player and no
    // consequence. Reported from the couch.
    List<String> keysFor(String textKey) => [
      for (final line in feedOf(
        timelineOf({
          'clubName': 'Testville',
          'opponentName': 'Ayton',
          'isHome': true,
          'addedTime': 0,
          'events': [
            {'minute': 30, 'type': 'commentary', 'textKey': textKey},
          ],
        }),
        ourName: 'Testville',
        theirName: 'Ayton',
        isHome: true,
      ))
        line.key,
    ];

    test('the two that do are dropped', () {
      expect(keysFor('commentary.flow.firstB.2'), isEmpty);
      expect(keysFor('commentary.flow.secondB.3'), isEmpty);
    });

    test('and every other flow line still reaches the feed', () {
      expect(
        keysFor('commentary.flow.secondB.2'),
        contains('commentary.flow.secondB.2'),
      );
    });
  });
}
