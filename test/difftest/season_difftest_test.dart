/// The differential harness: whole SEASONS through the Dart engines, compared
/// against the same seasons through the JS.
///
/// The eleven per-module fixtures each pin one engine against node. This pins
/// the whole thing at once, and the difference matters: a per-module fixture
/// proves a function agrees on the inputs somebody thought to write down, and a
/// season proves the functions agree with EACH OTHER — that the pyramid the
/// season boundary shuffles is the one the next season's fixtures are drawn
/// from, that the ratings a match writes are the ones the table reads, and that
/// thirty thousand draws later both runtimes are still on the same number.
///
/// A mismatch reports the first match it happened on, because after that every
/// hash is wrong for the same reason and only the first one tells you anything.
///
/// See `tool/difftest/README.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/quest_match.dart'
    show resolveMatchQuests;
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import '../support/canonical.dart';
import '../support/js_math_random.dart';

final Map<String, dynamic> _ref =
    jsonDecode(File('test/fixtures/season_difftest.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _runs() => _ref['runs'] as Map<String, dynamic>;

/// The save the run starts from, as the harness shipped it.
Map<String, dynamic> _base(String label) =>
    jsonDecode(jsonEncode((_ref['base'] as Map)[label]))
        as Map<String, dynamic>;

/// What tells you WHAT went wrong, once a hash says something did.
Map<String, dynamic> _resultDigest(MatchResult r) => {
  'homeGoals': r['homeGoals'],
  'awayGoals': r['awayGoals'],
  'won': r['won'] == true,
  'drawn': r['drawn'] == true,
  'isHome': r['isHome'] == true,
  'coinsEarned': r['coinsEarned'] ?? 0,
  'trophiesEarned': r['trophiesEarned'] ?? 0,
  'opponentName': r['opponentName'],
  'squadRating': r['squadRating'],
  'opponentRating': r['opponentRating'],
  'injuryCount': r['injuryCount'] ?? 0,
  'events': (r['events'] as List?)?.length ?? 0,
};

Map<String, dynamic> _seasonEndDigest(SeasonOutcome o) => {
  'outcome': o.outcome,
  'position': o.position,
  'oldDivision': o.oldDivision,
  'newDivision': o.newDivision,
  'payout': o.payout,
  'gemsAwarded': o.gemsAwarded,
  'ageing': o.ageingReport.length,
  'injuryRecovered': o.injuryReport.recovered,
  'injuryShortened': o.injuryReport.shortened,
  'sponsorsExpired': o.sponsorReport.expired,
};

/// One league match, in the order the League screen runs it: simulate, count it
/// for the quests, commit the outcome at full time, resolve the match track, and
/// credit the payout on close.
MatchResult _playMatch(Map<String, dynamic> state) {
  final division = (state['progression'] as Map)['currentDivision'] as String;
  final result = simulateMatch(state, division);
  trackEvent(state, QuestAction.playMatches);
  if (result['won'] == true) trackEvent(state, QuestAction.matchWin);
  finalizeMatchOutcome(state, result);
  resolveMatchQuests(state, result);
  applyMatchRewards(state, result);
  return result;
}

void main() {
  setUp(() => setClock(() => _ref['fixedNow'] as int));
  tearDown(() {
    resetClock();
    resetMatchRandom();
    resetEventRandom();
  });

  for (final entry in _runs().entries) {
    final label = entry.key;
    final run = entry.value as Map<String, dynamic>;

    test('${_ref['seasons']} seasons match the JS byte for byte — $label', () {
      seeded.setSeed(run['seed'] as int);
      // ONE instance for both injection points: the JS has a single
      // `Math.random`, and driving two streams here would desynchronise the
      // moment the feed and the orchestration both drew from it.
      final unseeded = JsMathRandom(run['mathSeed'] as int);
      setMatchRandom(unseeded);
      setEventRandom(unseeded);

      final state = _base(label);
      ensureLeaguePyramid(state);
      initSeasonOpponents(state);
      generateSeasonFixtures(state);

      final steps = (run['steps'] as List).cast<Map<String, dynamic>>();
      final ends = (run['seasonEnds'] as List).cast<Map<String, dynamic>>();
      var step = 0;

      for (var season = 0; season < ends.length; season++) {
        final fixtures =
            (state['progression'] as Map)['seasonFixtures'] as List? ??
            const [];
        for (var i = 0; i < fixtures.length; i++) {
          final result = _playMatch(state);
          expect(
            step,
            lessThan(steps.length),
            reason: 'the JS run was ${steps.length} matches long',
          );
          final want = steps[step];
          final where = 'season $season match $i';
          // The result first: when both are wrong it is the more legible of the
          // two, and when only the hash is wrong the divergence is in the save
          // rather than in the scoreline.
          expect(
            _resultDigest(result),
            want['result'],
            reason: '$where result',
          );
          // The first match ships its whole save: a run that diverges
          // immediately has nowhere else to look.
          if (want['save'] != null) {
            expect(canonical(state), want['save'], reason: '$where save');
          }
          expect(hashOf(state), want['hash'], reason: '$where save');
          step++;
        }

        final ended = endSeason(state);
        expect(
          _seasonEndDigest(ended),
          ends[season]['ended'],
          reason: 'season $season outcome',
        );
        // The whole save, so a failure here says WHAT differs rather than only
        // that something does.
        expect(
          canonical(state),
          ends[season]['save'],
          reason: 'season $season save',
        );
      }

      expect(step, steps.length, reason: 'the run played every match');
    });

    test('nothing whole is stored as a double — $label', () {
      // What the canonical form deliberately hides, so the hash tracks values
      // rather than types. It is a real risk: coins are the most-written field
      // in the save, and one landing as 75.0 where the JS writes 75 is equal as
      // a number and different as JSON.
      seeded.setSeed(run['seed'] as int);
      final unseeded = JsMathRandom(run['mathSeed'] as int);
      setMatchRandom(unseeded);
      setEventRandom(unseeded);

      final state = _base(label);
      ensureLeaguePyramid(state);
      initSeasonOpponents(state);
      generateSeasonFixtures(state);

      for (var season = 0; season < (_ref['seasons'] as int); season++) {
        final fixtures =
            (state['progression'] as Map)['seasonFixtures'] as List? ??
            const [];
        for (var i = 0; i < fixtures.length; i++) {
          _playMatch(state);
        }
        endSeason(state);
      }

      expect(integralDoubles(state), isEmpty);
      // And the whole thing still serialises, which is the other half of the
      // same promise.
      expect(() => jsonEncode(state), returnsNormally);
    });
  }
}
