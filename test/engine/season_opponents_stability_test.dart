/// The division's clubs do not change between one look at the table and the next.
///
/// `buildLeagueTable` runs on every save revision, so anything it calls has to be
/// a pure function of the save. The fallback path used to call `generateTeamName`,
/// which draws from the shared seeded stream and ADVANCES it — so the table
/// reshuffled its clubs on every rebuild, and pulled the sequence out from under
/// the save's own determinism on the way.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/engine/team_names.dart';
import 'package:merge_empire_fc/util/random.dart';

void main() {
  group('the season opponents', () {
    test('are the SAME on every call for one division and season', () {
      final first = getSeasonOpponents('sunday_league', 3, null);
      for (var i = 0; i < 20; i++) {
        expect(
          getSeasonOpponents('sunday_league', 3, null),
          first,
          reason: 'the table would show different clubs on rebuild $i',
        );
      }
      expect(first, hasLength(opponentsPerSeason));
      expect(first.toSet(), hasLength(opponentsPerSeason), reason: 'duplicates');
    });

    test('and do not advance the shared random stream', () {
      // The save's determinism rests on this sequence. A display path that
      // consumes from it desyncs the port from the JS silently.
      setSeed(1234);
      final before = [for (var i = 0; i < 3; i++) randomInt(0, 999)];

      setSeed(1234);
      getSeasonOpponents('national_league', 2, null);
      final after = [for (var i = 0; i < 3; i++) randomInt(0, 999)];

      expect(after, before);
    });

    test('but a different season is a different league', () {
      expect(
        getSeasonOpponents('sunday_league', 1, null),
        isNot(getSeasonOpponents('sunday_league', 2, null)),
      );
    });

    test('and a stored schedule always wins over the fallback', () {
      final stored = getSeasonOpponents('sunday_league', 1, {
        'progression': {'seasonOpponents': ['Real Actual', 'Stored FC']},
      });
      expect(stored, ['Real Actual', 'Stored FC']);
    });

    test('stableTeamNames fills its count from a small bank', () {
      // The last-resort branch is reachable only when the bank is smaller than
      // the ask; it must still return the count rather than a short list.
      final names = stableTeamNames('pro', 99, 40);
      expect(names, hasLength(40));
      expect(names.toSet(), hasLength(40));
    });
  });
}
