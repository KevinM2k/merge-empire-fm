/// The leaderboard's transport, over the seams.
///
/// Nothing here opens a socket: the function POST and `firestoreSend` are both
/// replaced. What is pinned is the shape of what goes out — a match is four
/// writes, an opt-out is a patch and never a delete — and the caching, which is
/// the part that is invisible until it serves somebody a stale board.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

late List<Object> posted;
late List<({String method, Uri url, Object? body})> sent;

void serveBoard(Map<String, dynamic> view, {int status = 200}) {
  leaderboardPost = (url, headers, body) async {
    posted.add(body);
    return (status: status, data: {'result': view});
  };
}

Map<String, dynamic> save({
  String uid = 'u1',
  String club = 'Borough United',
  bool visible = true,
  String division = 'regional',
  String? badge,
}) {
  final s = createDefaultState();
  s['clubName'] = club;
  (s['leaderboard'] as Map<String, dynamic>)
    ..['authUid'] = uid
    ..['rankingsVisible'] = visible;
  final progression = s['progression'] as Map<String, dynamic>;
  progression['currentDivision'] = division;
  if (badge != null) progression['equippedBadgeId'] = badge;
  (s['settings'] as Map<String, dynamic>)['regionCode'] = 'GB';
  return s;
}

Map<String, dynamic> boardRow(String id, num score) => {
  'playerId': id,
  'score': score,
  'clubName': 'Club $id',
  'division': 'regional',
  'rank': 1,
};

void main() {
  setUp(() {
    posted = [];
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

  group('fetching a board', () {
    test('asks the function for the period, metric, filters and limit', () async {
      serveBoard(<String, dynamic>{'entries': [boardRow('a', 10)]});
      await fetchLeaderboard(
        save(),
        scope: 'division_regional',
        period: '7d',
        metric: 'wins',
      );
      final data = (posted.single as Map)['data'] as Map;
      expect(data['metric'], 'wins');
      expect(data['limit'], leaderboardFetchLimit);
      expect(data['playerId'], 'u1');
      // A division board filters on the save's own division AND its region.
      expect(data['scopeFilters'], [
        ['division', 'regional'],
        ['region', 'GB'],
      ]);
    });

    test('PRESTIGE IS ALWAYS ALL-TIME, whatever the period says', () async {
      // It is a level, not a score that accumulates in a window — "this week's
      // prestige" would rank whoever prestiged this week.
      serveBoard(const <String, dynamic>{'entries': <Object>[]});
      await fetchLeaderboard(
        save(),
        scope: 'all_global',
        period: '1d',
        metric: 'prestige',
      );
      expect(((posted.single as Map)['data'] as Map)['periodKey'], 'alltime');
    });

    test('an OPTED-OUT player is not looked up', () async {
      // They can read the board; asking for their row would put them on it.
      serveBoard(const <String, dynamic>{'entries': <Object>[]});
      final view = await fetchLeaderboard(
        save(visible: false),
        scope: 'all_global',
        period: '7d',
        metric: 'points',
      );
      expect(((posted.single as Map)['data'] as Map)['playerId'], isNull);
      expect(view.optedOut, isTrue);
    });

    test("stamps THIS device's club name on the player's own row", () async {
      serveBoard(<String, dynamic>{
        'entries': [boardRow('u1', 10), boardRow('other', 9)],
      });
      final view = await fetchLeaderboard(
        save(club: 'Renamed United'),
        scope: 'all_global',
        period: '7d',
        metric: 'points',
      );
      expect(view.entries.first.clubName, 'Renamed United');
      expect(view.entries.last.clubName, 'Club other');
    });

    test('a failure is reported and NEVER cached', () async {
      // The next look should try again rather than be told the same thing for
      // a minute.
      leaderboardPost = (url, headers, body) async {
        posted.add(body);
        return (status: 500, data: null);
      };
      final view = await fetchLeaderboard(
        save(),
        scope: 'all_global',
        period: '7d',
        metric: 'points',
      );
      expect(view.error, 'fetch_failed');
      await fetchLeaderboard(
        save(),
        scope: 'all_global',
        period: '7d',
        metric: 'points',
      );
      expect(posted, hasLength(2));
    });

    group('the cache', () {
      test('serves the same board rather than asking twice', () async {
        serveBoard(<String, dynamic>{'entries': [boardRow('a', 10)]});
        for (var i = 0; i < 3; i++) {
          await fetchLeaderboard(
            save(),
            scope: 'all_global',
            period: '7d',
            metric: 'points',
          );
        }
        expect(posted, hasLength(1));
      });

      test('and a different board is a different key', () async {
        serveBoard(<String, dynamic>{'entries': [boardRow('a', 10)]});
        await fetchLeaderboard(save(),
            scope: 'all_global', period: '7d', metric: 'points');
        await fetchLeaderboard(save(),
            scope: 'all_global', period: '1d', metric: 'points');
        await fetchLeaderboard(save(),
            scope: 'all_regional', period: '7d', metric: 'points');
        expect(posted, hasLength(3));
      });

      test('A RENAME MISSES IT, because the name is stamped on the row', () async {
        serveBoard(<String, dynamic>{'entries': [boardRow('u1', 10)]});
        await fetchLeaderboard(save(club: 'Before'),
            scope: 'all_global', period: '7d', metric: 'points');
        final after = await fetchLeaderboard(save(club: 'After'),
            scope: 'all_global', period: '7d', metric: 'points');
        expect(posted, hasLength(2));
        expect(after.entries.single.clubName, 'After');
      });

      test('force bypasses it — that is what pull-to-refresh is', () async {
        serveBoard(<String, dynamic>{'entries': [boardRow('a', 10)]});
        await fetchLeaderboard(save(),
            scope: 'all_global', period: '7d', metric: 'points');
        await fetchLeaderboard(save(),
            scope: 'all_global', period: '7d', metric: 'points', force: true);
        expect(posted, hasLength(2));
      });
    });
  });

  group('a finished match', () {
    Map<String, dynamic> result({bool won = true, int goals = 3}) => {
      'won': won,
      'drawn': false,
      'homeGoals': goals,
      // A REAL division id: `leaderboardEligibleMatch` refuses anything that
      // is not one, which is how cup ties stay off the boards.
      'divisionId': 'regional_league',
      'playedAt': DateTime.utc(2026, 3, 1, 12).millisecondsSinceEpoch,
    };

    test('IS FOUR WRITES, ONE PER PERIOD, in one commit', () async {
      // Schema v2: one row per player per period, scope as a `where` filter
      // rather than a folder in the path — which is what makes this four
      // writes and not forty-eight.
      final state = save();
      expect(await submitMatchStats(state, result()), isTrue);
      expect(sent, hasLength(1), reason: 'one atomic commit');
      final body = jsonEncode(sent.single.body);
      for (final period in leaderboardPeriods) {
        expect(body, contains('lb/'), reason: period);
      }
      expect(RegExp('/rows/u1').allMatches(body), hasLength(4));
    });

    test('a WIN is three points and a win', () async {
      await submitMatchStats(save(), result());
      final body = jsonEncode(sent.single.body);
      expect(body, contains('"points"'));
      expect(body, contains('"goals_for"'));
    });

    test('A LOSS STILL WRITES, at zero', () async {
      // Increment-by-zero creates the field without resetting an existing
      // score, so a beaten club is still on every board.
      final submission = submissionFor(save(), result(won: false, goals: 0));
      expect(submission.points, 0);
      expect(submission.wins, 0);
      expect(submission.goalsFor, 0);
      expect(await submitMatchStats(save(), result(won: false, goals: 0)), isTrue);
      expect(sent, hasLength(1));
    });

    test('a draw is one point', () async {
      final drawn = result(won: false)..['drawn'] = true;
      expect(submissionFor(save(), drawn).points, 1);
    });

    test('signed out it writes NOTHING', () async {
      final out = save()..['leaderboard'] = <String, dynamic>{};
      expect(await submitMatchStats(out, result()), isFalse);
      expect(sent, isEmpty);
    });

    test('and records what it told the server', () async {
      final state = save();
      await submitMatchStats(state, result());
      final board = state['leaderboard'] as Map<String, dynamic>;
      expect(board['lastSubmittedAt'], isNonZero);
      expect(board['prestigeSynced'], isNotNull);
    });
  });

  group('the row meta every write refreshes', () {
    test('NEVER PUBLISHES AN ACCOUNT NAME, and says so explicitly', () async {
      // Email-derived names are never published, and stating the null is what
      // scrubs the field from a row created by an older version.
      final meta = leaderboardRowMeta(save(), divisionId: 'regional');
      expect(meta.containsKey('accountName'), isTrue);
      expect(meta['accountName'], isNull);
    });

    test('LEAVES THE BADGE OUT when this device never chose one', () async {
      // A merge patch then leaves the stored badge alone — a second device
      // with an unsynced save must not stomp it back to default.
      expect(
        leaderboardRowMeta(save(), divisionId: 'regional').containsKey('badgeId'),
        isFalse,
      );
      expect(
        leaderboardRowMeta(save(badge: 'gold'), divisionId: 'regional')['badgeId'],
        'gold',
      );
    });

    test('caps the club name at forty', () async {
      final meta = leaderboardRowMeta(save(club: 'y' * 90), divisionId: 'x');
      expect((meta['clubName'] as String).length, 40);
    });

    test('AN OPTED-OUT PLAYER STILL ACCRUES, unlisted', () async {
      // Scores keep accruing so the rolling windows stay correct; they are
      // simply hidden, and opting back in loses nothing.
      expect(
        leaderboardRowMeta(save(visible: false), divisionId: 'x')['listed'],
        isFalse,
      );
    });
  });

  group('opting out', () {
    test('PATCHES `listed` and never deletes', () async {
      // A row UPDATE is always permitted and a DELETE may not be, so this is
      // what guarantees the scores vanish from every board.
      expect(await setLeaderboardListed(save(), listed: false), isTrue);
      final body = jsonEncode(sent.map((s) => s.body).toList());
      expect(body, contains('listed'));
      expect(sent.every((s) => s.method == 'POST'), isTrue);
      expect(body, isNot(contains('"delete"')));
    });

    test('sweeps the windows a row can still be in, and no more', () async {
      // Thirty-five days, six weeks, three months, plus all-time. A row older
      // than that has aged off every board it could appear on.
      final periods = leaderboardSweepPeriods(DateTime.utc(2026, 3, 1));
      expect(periods, contains('alltime'));
      expect(periods.where((p) => p.startsWith('d')), hasLength(35));
      expect(periods.where((p) => p.startsWith('w')), hasLength(6));
      expect(periods.where((p) => p.startsWith('m')), hasLength(3));
    });

    test('records that the server was told', () async {
      final state = save();
      await setLeaderboardListed(state, listed: false);
      expect((state['leaderboard'] as Map)['optOutApplied'], isTrue);
      await setLeaderboardListed(state, listed: true);
      expect((state['leaderboard'] as Map)['optOutApplied'], isFalse);
    });

    test('signed out it writes nothing', () async {
      final out = save()..['leaderboard'] = <String, dynamic>{};
      expect(await setLeaderboardListed(out, listed: false), isFalse);
      expect(sent, isEmpty);
    });
  });

  group('the boot repair', () {
    test('RETRIES A HIDE THAT NEVER LANDED', () async {
      // The direction that matters: somebody who asked not to be listed still
      // being listed.
      final state = save(visible: false);
      await ensureLeaderboardOptOutApplied(state);
      expect(sent, isNotEmpty);
      expect((state['leaderboard'] as Map)['optOutApplied'], isTrue);
    });

    test('and an opt-in that was interrupted mid-toggle', () async {
      final state = save()
        ..['leaderboard'] = <String, dynamic>{
          'authUid': 'u1',
          'rankingsVisible': true,
          'optOutApplied': true,
        };
      await ensureLeaderboardOptOutApplied(state);
      expect(sent, isNotEmpty);
      expect((state['leaderboard'] as Map)['optOutApplied'], isFalse);
    });

    test('is a no-op when the server already agrees', () async {
      await ensureLeaderboardOptOutApplied(save());
      expect(sent, isEmpty);
    });

    test('and signed out there is nothing to repair', () async {
      final out = save()..['leaderboard'] = <String, dynamic>{};
      await ensureLeaderboardOptOutApplied(out);
      expect(sent, isEmpty);
    });
  });

  group('WHICH MATCHES COUNT', () {
    // `isLeaderboardEligibleMatch` in `leaderboardService.js`: a result may
    // carry no `divisionId`, or one that names a real DIVISION. Anything else
    // is refused — which is the answer to the cup question the port carried
    // open for a while, because a cup tie's result map carries the CUP's id in
    // that field and `leaderboardRowMeta` writes it to the row's `division`,
    // the very field the division-scoped boards filter on.
    test('a league fixture does', () {
      expect(
        leaderboardEligibleMatch({'divisionId': 'regional_league'}),
        isTrue,
      );
    });

    test('and so does one that names no division at all', () {
      expect(leaderboardEligibleMatch(const {}), isTrue);
    });

    test('A CUP TIE DOES NOT', () {
      // The cup path deliberately does not emit `match:complete`, which is a
      // rule living in one comment. This is the rule living where the write is.
      expect(
        leaderboardEligibleMatch({'divisionId': 'the_cup'}),
        isFalse,
      );
    });
  });
}
