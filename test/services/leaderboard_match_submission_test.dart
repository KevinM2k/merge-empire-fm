/// The join between a match that was actually played and the four rows it
/// writes.
///
/// **The two halves were both right and the wire between them was missing.**
/// `leaderboard_service_test.dart` submits a hand-written result map, and it
/// passes whether or not any match in the game produces one — which it did,
/// for as long as `match:complete` had no emitter at all. `game_host`
/// subscribed to that event to call `submitMatchStats`, `match_orchestration`
/// deliberately did not emit it ("the UI fires it at full time"), and no screen
/// ever did: a player could finish a season and put nothing on any global
/// board.
///
/// So this file plays a REAL match — `beginMatch`, then `settleMatch` at full
/// time — and asks the leaderboard what it would send. The payload the play
/// button now puts on the bus is this map, so if the engine ever renames a
/// field the board reads, it fails here rather than silently scoring zero.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_launcher.dart';

late List<({String method, Uri url, Object? body})> sent;

/// A signed-in save that can take the field.
Map<String, dynamic> readySave({int squad = 11}) {
  final s = createDefaultState();
  s['clubName'] = 'Borough United';
  (s['energy'] as Map<String, dynamic>)['current'] = 10;
  // **ONBOARDING FINISHED, or every match below is a WIN.** `beginMatch` reads
  // `tutorialFirstMatch` and passes `forceWin` on a save that has never played
  // — the port's answer to a new player losing the one match the game walks
  // them through. A fresh default state is exactly that save, so a loop over
  // fresh ones is a loop over rigged wins, and the draw and defeat branches
  // below would never be reached.
  (s['tutorial'] as Map<String, dynamic>)['done'] = true;
  (s['leaderboard'] as Map<String, dynamic>)
    ..['authUid'] = 'u1'
    ..['rankingsVisible'] = true;
  (s['settings'] as Map<String, dynamic>)['regionCode'] = 'GB';
  (s['progression'] as Map<String, dynamic>)['seasonOpponents'] = [
    'Ayton',
    'Beeches',
    'Cadley',
    'Deeping',
    'Elton',
    'Fairby',
    'Gorton',
  ];

  final def = players.firstWhere((p) => p.tier == 1);
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < squad; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': def.id,
      'instanceId': 'c$i',
      'variant': 0,
    };
  }
  (s['squad'] as Map<String, dynamic>)['lineup'] = [
    for (var i = 0; i < squad && i < 11; i++)
      <String, dynamic>{
        'slotId': 's$i',
        'slotPosition': 'MID',
        'cardInstanceId': 'c$i',
      },
  ];
  return s;
}

/// Play one, and settle it — the play button's own two steps, in its own order.
///
/// The emit the button now makes sits after the second of these, because
/// `finalizeMatchOutcome` is what settles `won`, `drawn` and the scoreline.
Map<String, dynamic> playAndSettle(Map<String, dynamic> state) {
  final result = beginMatch(state)!;
  settleMatch(state, result);
  return result;
}

void main() {
  setUp(() {
    sent = [];
    resetLeaderboardSeams();
    firestoreSend = (method, url, headers, body) async {
      sent.add((method: method, url: url, body: body));
      return (status: 200, data: const <String, dynamic>{}, rawText: null);
    };
  });

  tearDown(() {
    resetLeaderboardSeams();
    resetFirestoreSeams();
  });

  test('a settled match carries every field the submission reads', () {
    final state = readySave();
    final result = playAndSettle(state);

    // Not "is non-null" — these are the five the leaderboard actually reads,
    // and `submissionFor` falls back rather than throwing on each of them, so
    // a rename would score a real match as a goalless nothing in the opening
    // division and never say a word.
    expect(result['won'], isA<bool>());
    expect(result['drawn'], isA<bool>());
    expect(result['homeGoals'], isA<num>());
    expect(result['divisionId'], isA<String>());
    expect(result['playedAt'], isA<num>());
  });

  test('and the submission AGREES with the scoreline that was played', () {
    // The result is a real simulation, so which way it went is not fixed —
    // what is fixed is that the board and the match tell the same story.
    final outcomes = <String>{};
    for (var i = 0; i < 40; i++) {
      final state = readySave();
      final result = playAndSettle(state);
      final submission = submissionFor(state, result);

      final won = result['won'] == true;
      final drawn = result['drawn'] == true;
      outcomes.add(won ? 'won' : (drawn ? 'drawn' : 'lost'));
      expect(submission.points, won ? 3 : (drawn ? 1 : 0));
      expect(submission.wins, won ? 1 : 0);
      expect(submission.goalsFor, (result['homeGoals'] as num).round());
      // The LEAGUE division, never null and never a cup: it becomes the row's
      // `division` field, which is what the division-scoped boards filter on.
      expect(submission.divisionId, result['divisionId']);
      expect(submission.divisionId, isNotEmpty);
    }

    // The guard on the loop. Forty rigged wins would satisfy every expectation
    // above while proving nothing about a point or a nil, which is how the
    // tutorial's `forceWin` made an earlier draft of this vacuous.
    expect(
      outcomes.length,
      greaterThan(1),
      reason: 'forty matches that all went the same way is a rigged sim, '
          'not a passing test — found only $outcomes',
    );
  });

  test('a real match is four rows in one commit', () async {
    final state = readySave();
    final result = playAndSettle(state);

    expect(await submitMatchStats(state, result), isTrue);
    expect(sent, hasLength(1), reason: 'one atomic commit');

    final body = jsonEncode(sent.single.body);
    expect(RegExp('/rows/u1').allMatches(body), hasLength(4));
    for (final period in leaderboardPeriods) {
      final key = leaderboardPeriodKey(
        period,
        DateTime.fromMillisecondsSinceEpoch((result['playedAt'] as num).toInt()),
      );
      expect(body, contains('lb/$key/rows/u1'), reason: period);
    }
  });

  test('and the row it writes carries the club, not the opponent', () {
    // `leaderboardRowMeta` reads the SAVE for the name and the result for the
    // division; a row that took its name from the result would be labelled
    // with whoever the player happened to face.
    final state = readySave();
    final result = playAndSettle(state);
    final meta = leaderboardRowMeta(
      state,
      divisionId: submissionFor(state, result).divisionId,
    );
    expect(meta['clubName'], 'Borough United');
    expect(meta['clubName'], isNot(result['opponentName']));
    expect(meta['region'], 'GB');
    expect(meta['listed'], isTrue);
  });

  test('a lost match still writes, so a beaten club is on every board', () async {
    // Increment-by-zero, over a result the engine produced rather than one
    // written to order: the fields exist at 0 and the club appears.
    final state = readySave();
    Map<String, dynamic>? lost;
    for (var i = 0; i < 200 && lost == null; i++) {
      final fresh = readySave();
      final result = playAndSettle(fresh);
      if (result['won'] != true && result['drawn'] != true) lost = result;
    }
    expect(
      lost,
      isNotNull,
      reason: 'a tier-1 side that cannot lose in two hundred goes is a rigged '
          'sim — see the tutorial note in readySave',
    );
    final submission = submissionFor(state, lost!);
    expect(submission.points, 0);
    expect(submission.wins, 0);
    expect(await submitMatchStats(state, lost), isTrue);
    expect(sent, hasLength(1));
  });
}
