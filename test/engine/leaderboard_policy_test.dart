/// The leaderboard's shape, pinned against the JS's.
///
/// The rows on the server are the SHIPPED app's — a board written by the JS has
/// to be readable by this one and the other way round — so every key, field
/// name and path here is compared against the JS's rather than a tidier one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';

void main() {
  group('the period key', () {
    test('a day is the LOCAL calendar day, zero padded', () {
      expect(
        leaderboardPeriodKey('1d', DateTime(2026, 8, 3, 23, 59)),
        'day_2026-08-03',
      );
    });

    test('a month is the local calendar month', () {
      expect(leaderboardPeriodKey('30d', DateTime(2026, 12, 31)), 'month_2026-12');
    });

    test('and anything unrecognised is all-time', () {
      expect(leaderboardPeriodKey('alltime', DateTime(2026, 1, 1)), 'alltime');
      expect(leaderboardPeriodKey('nonsense', DateTime(2026, 1, 1)), 'alltime');
    });

    group('THE WEEK IS THE ISO WEEK', () {
      // Not "the day of the year divided by seven": a week belongs to the year
      // its THURSDAY falls in, so the first days of January can be week 52 or
      // 53 of the year before. Getting it wrong puts two different weeks in one
      // bucket once a year.
      test('and the first of January can belong to last year', () {
        // 1 Jan 2027 is a Friday; that week's Thursday is 31 Dec 2026.
        expect(
          leaderboardPeriodKey('7d', DateTime(2027, 1, 1)),
          'week_2026-W53',
        );
      });

      test('and the last of December can belong to next year', () {
        // 31 Dec 2025 is a Wednesday; that week's Thursday is 1 Jan 2026.
        expect(
          leaderboardPeriodKey('7d', DateTime(2025, 12, 31)),
          'week_2026-W01',
        );
      });

      test('every day of one week lands in the SAME bucket', () {
        final monday = DateTime(2026, 8, 17);
        final keys = {
          for (var i = 0; i < 7; i++)
            leaderboardPeriodKey('7d', monday.add(Duration(days: i))),
        };
        expect(keys, hasLength(1));
      });

      test('and the next day starts a new one', () {
        expect(
          leaderboardPeriodKey('7d', DateTime(2026, 8, 23)),
          isNot(leaderboardPeriodKey('7d', DateTime(2026, 8, 24))),
        );
      });
    });
  });

  group('the row path', () {
    test('IS ONE ROW PER PLAYER PER PERIOD, with the scope as a field', () {
      // Schema v2, and it is what makes a finished match four writes instead of
      // forty-eight: the four boards a player appears on are the same four rows
      // read back with different `where` clauses.
      expect(leaderboardRowPath('day_2026-08-23', 'p1'), 'lb/day_2026-08-23/rows/p1');
      for (final scope in leaderboardViewScopes) {
        expect(
          leaderboardRowPath('alltime', 'p1'),
          isNot(contains(scope)),
          reason: 'the scope is a filter, not a folder',
        );
      }
    });
  });

  group('the scope', () {
    test('the four composite ids round-trip', () {
      for (final id in leaderboardViewScopes) {
        final view = parseLeaderboardScope(id);
        expect(buildLeaderboardScope(view.tier, view.reach), id);
      }
    });

    test('AND THE THREE LEGACY IDS STILL PARSE, because saves have them', () {
      expect(parseLeaderboardScope('division').tier, LeaderboardTier.division);
      expect(parseLeaderboardScope('division').reach, LeaderboardReach.global);
      expect(parseLeaderboardScope('regional').tier, LeaderboardTier.all);
      expect(parseLeaderboardScope('regional').reach, LeaderboardReach.regional);
      expect(parseLeaderboardScope('global').tier, LeaderboardTier.all);
      expect(parseLeaderboardScope('global').reach, LeaderboardReach.global);
    });

    test('and anything else is the board the app opens on', () {
      for (final junk in [null, '', 'made up']) {
        final view = parseLeaderboardScope(junk);
        expect(view.tier, LeaderboardTier.division);
        expect(view.reach, LeaderboardReach.global);
      }
    });
  });

  group('the filters a view becomes', () {
    test('division-global filters on the division alone', () {
      expect(
        leaderboardScopeFilters('division_global', divisionId: 'league_two'),
        [('division', 'league_two')],
      );
    });

    test('all-global filters on nothing at all', () {
      expect(leaderboardScopeFilters('all_global'), isEmpty);
    });

    test('and division-regional filters on both', () {
      expect(
        leaderboardScopeFilters(
          'division_regional',
          divisionId: 'league_two',
          regionCode: 'FR',
        ),
        [('division', 'league_two'), ('region', 'FR')],
      );
    });

    test('A MISSING DIVISION OR REGION IS A DEFAULT, not a refusal', () {
      // An empty leaderboard reads as broken where a slightly wrong one reads
      // as a leaderboard.
      expect(
        leaderboardScopeFilters('division_regional'),
        [('division', 'sunday_league'), ('region', 'GB')],
      );
    });

    test('and a row is on the board when it satisfies every one', () {
      final filters = leaderboardScopeFilters(
        'division_regional',
        divisionId: 'league_two',
        regionCode: 'GB',
      );
      expect(
        leaderboardRowMatches(
          {'division': 'league_two', 'region': 'GB'},
          filters,
        ),
        isTrue,
      );
      expect(
        leaderboardRowMatches({'division': 'league_two'}, filters),
        isFalse,
      );
      expect(leaderboardRowMatches(null, filters), isFalse);
      // No filters is every row.
      expect(leaderboardRowMatches(null, const []), isTrue);
    });
  });

  group('who counts', () {
    const now = 1000000000000;

    test('A PLAYER WITH NO MATCH IN THIRTY DAYS IS NOT ON THE BOARD', () {
      expect(
        leaderboardRowIsActive(
          now - leaderboardInactiveAfter.inMilliseconds - 1,
          nowMs: now,
        ),
        isFalse,
      );
      expect(
        leaderboardRowIsActive(
          now - leaderboardInactiveAfter.inMilliseconds + 1,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('and a row that has never played is not a row', () {
      expect(leaderboardRowIsActive(null, nowMs: now), isFalse);
      expect(leaderboardRowIsActive('nonsense', nowMs: now), isFalse);
    });

    test('a clock in the future is not activity either', () {
      // A device with its clock set forward would otherwise be permanently
      // ranked.
      expect(leaderboardRowIsActive(now + 60000, nowMs: now), isFalse);
    });

    test('and the client filters it, which is why the fetch overreads', () {
      // The query is already ordered by score and Firestore will not take a
      // second range, so the pages have to be scanned here.
      expect(leaderboardBackfillBatches, greaterThan(1));
      expect(leaderboardFetchLimit, greaterThan(0));
    });
  });

  test('PRESTIGE RIDES ON THE META LEVEL FIELD, not one of its own', () {
    expect(leaderboardMetricField('prestige'), 'prestigeLevel');
    for (final m in ['points', 'wins', 'goals_for']) {
      expect(leaderboardMetricField(m), m);
    }
    // Anything unrecognised is a board rather than an error.
    expect(leaderboardMetricField('made up'), 'points');
  });

  test('and the four metrics and four periods are the JS\'s', () {
    expect(leaderboardMetrics, ['points', 'wins', 'goals_for', 'prestige']);
    expect(leaderboardPeriods, ['1d', '7d', '30d', 'alltime']);
    expect(leaderboardViewScopes, hasLength(4));
  });
}
