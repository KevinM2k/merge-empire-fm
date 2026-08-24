/// A board, as it comes back off the wire.
///
/// The rows on the server belong to the SHIPPED app, so what is pinned here is
/// the reading of them: what a missing field falls back to, what is dropped
/// outright, and the three fields this device overwrites on its own row.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/leaderboard_view.dart';

Map<String, dynamic> row({
  String id = 'p1',
  Object? score = 42,
  String? club = 'Borough United',
  String? badge = 'gold',
  Object? platform = 'ios',
  int? rank = 1,
}) => <String, dynamic>{
  'playerId': id,
  'score': score,
  'clubName': club,
  'division': 'regional',
  'prestigeLevel': 2,
  'badgeId': badge,
  'platform': platform,
  'rank': rank,
};

void main() {
  group('one row', () {
    test('reads every field', () {
      final entry = leaderboardEntryFrom(row(), selfId: 'p1')!;
      expect(entry.playerId, 'p1');
      expect(entry.clubName, 'Borough United');
      expect(entry.score, 42);
      expect(entry.division, 'regional');
      expect(entry.prestigeLevel, 2);
      expect(entry.badgeId, 'gold');
      expect(entry.platform, 'ios');
      expect(entry.rank, 1);
      expect(entry.isPlayer, isTrue);
    });

    test('A ROW WITH NO USABLE SCORE IS NOT A ROW', () {
      // Dropped rather than ranked at zero: a zero is a real score somebody
      // could hold, and a missing field is a document written by something
      // else.
      expect(leaderboardEntryFrom(row(score: null)), isNull);
      expect(leaderboardEntryFrom(row(score: 'nope')), isNull);
      expect(leaderboardEntryFrom(row(id: '')), isNull);
      expect(leaderboardEntryFrom(null), isNull);
      // But an actual zero IS one.
      expect(leaderboardEntryFrom(row(score: 0))!.score, 0);
    });

    test('a score that arrives as a STRING is still a score', () {
      expect(leaderboardEntryFrom(row(score: '17'))!.score, 17);
    });

    test('falls back rather than refusing on a thin row', () {
      final entry = leaderboardEntryFrom(row(club: null, badge: null))!;
      expect(entry.clubName, 'Unknown FC');
      expect(entry.badgeId, defaultLeaderboardBadge);
    });

    test('an unknown platform is WEB, not a crash', () {
      // Covers a row written by a build this one has never met.
      expect(leaderboardEntryFrom(row(platform: 'switch'))!.platform, 'web');
      expect(leaderboardEntryFrom(row(platform: null))!.platform, 'web');
      expect(leaderboardEntryFrom(row(platform: 'android'))!.platform, 'android');
    });

    test('is only the PLAYER when the id matches', () {
      expect(leaderboardEntryFrom(row(), selfId: 'other')!.isPlayer, isFalse);
      expect(leaderboardEntryFrom(row())!.isPlayer, isFalse);
    });
  });

  group('the whole view', () {
    test('reads the top, the player, the context and the tail', () {
      final view = leaderboardViewFrom({
        'entries': [row(id: 'a', rank: 1), row(id: 'b', rank: 2)],
        'playerEntry': row(id: 'me', rank: 812),
        'playerRank': 812,
        'contextAbove': row(id: 'above', rank: 811),
        'contextBelow': row(id: 'below', rank: 813),
        'bottomEntries': [row(id: 'last', rank: 900)],
        'playerBeyondTop': true,
        'showGap': true,
        'showGapBeforeBottom': true,
      }, selfId: 'me');

      expect(view.entries.map((e) => e.playerId), ['a', 'b']);
      expect(view.playerEntry!.isPlayer, isTrue);
      expect(view.playerRank, 812);
      expect(view.contextAbove!.playerId, 'above');
      expect(view.contextBelow!.playerId, 'below');
      expect(view.bottomEntries.single.playerId, 'last');
      expect(view.playerBeyondTop, isTrue);
      expect(view.showGap, isTrue);
      expect(view.showGapBeforeBottom, isTrue);
      expect(view.isEmpty, isFalse);
    });

    test('an empty body is an empty board, not an error', () {
      final view = leaderboardViewFrom(const <String, dynamic>{});
      expect(view.isEmpty, isTrue);
      expect(view.error, isNull);
    });

    test('drops the unreadable rows and keeps the rest', () {
      final view = leaderboardViewFrom({
        'entries': [row(id: 'a'), row(id: 'b', score: null), row(id: 'c')],
      });
      expect(view.entries.map((e) => e.playerId), ['a', 'c']);
    });
  });

  group('what this device overwrites on its own row', () {
    LeaderboardView twoRows() => leaderboardViewFrom({
      'entries': [row(id: 'me', club: 'Stale FC', badge: 'old'), row(id: 'them')],
      'playerEntry': row(id: 'me', club: 'Stale FC', badge: 'old'),
    }, selfId: 'me');

    test('the club name, because a rename is instant here', () {
      final view = withLocalOverrides(
        twoRows(),
        clubName: 'Renamed United',
        badgeId: 'new',
        platform: 'android',
      );
      expect(view.entries.first.clubName, 'Renamed United');
      expect(view.playerEntry!.clubName, 'Renamed United');
      // And nobody else's.
      expect(view.entries.last.clubName, 'Borough United');
    });

    test('and it is capped at forty, like every other write of it', () {
      final view = withLocalOverrides(
        twoRows(),
        clubName: 'x' * 60,
        platform: 'ios',
      );
      expect(view.entries.first.clubName.length, 40);
    });

    test('A DEVICE THAT NEVER CHOSE A BADGE OVERRIDES NOTHING', () {
      // The sharp edge: a second device with an unsynced save must show the
      // STORED badge rather than stomping it back to default.
      final view = withLocalOverrides(twoRows(), badgeId: null, platform: 'ios');
      expect(view.entries.first.badgeId, 'old');
    });

    test('the platform, which is a fact about this device', () {
      final view = withLocalOverrides(twoRows(), platform: 'android');
      expect(view.entries.first.platform, 'android');
      expect(view.entries.last.platform, 'ios', reason: 'not theirs');
    });

    test('an empty club name is not an override', () {
      final view = withLocalOverrides(
        twoRows(),
        clubName: '   ',
        platform: 'ios',
      );
      expect(view.entries.first.clubName, 'Stale FC');
    });
  });

  test('every row the view carries is reachable in one list', () {
    final view = leaderboardViewFrom({
      'entries': [row(id: 'a')],
      'playerEntry': row(id: 'me'),
      'contextAbove': row(id: 'above'),
      'contextBelow': row(id: 'below'),
      'bottomEntries': [row(id: 'last')],
    });
    expect(allViewRows(view).map((e) => e.playerId), [
      'a',
      'above',
      'me',
      'below',
      'last',
    ]);
  });
}
