/// **THE STATBOARD WAS MIRRORED AT AWAY FIXTURES.**
///
/// Two faults in `liveStatsFor`, both about the same confusion, and together
/// they explain a 2-0 away defeat that showed 67% possession and more shots:
///
/// - **the counters.** The engine's `team: 'home'` means US, whatever the
///   ground — that is what `homeGoals`/`awayGoals` mean everywhere else, and
///   what the commentary's goal line has always read. This read it as the
///   VENUE and folded `isHome` in, so shots, shots on target, big chances,
///   big chances missed and corners were all swapped with the opposition's
///   away from home.
/// - **the swing.** `swing` is counted up about US; `resting`, `possHome` and
///   `dangerHome` are all stated about the HOME side. Away those are opposite
///   numbers and nothing converted between them, so the possession bar and the
///   momentum arrow leaned toward whichever side was being beaten.
///
/// The full-time write-up was right all along — it reads the SCORE — which is
/// what made the pair of them so confusing to look at.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';

void main() {
  TimelineEvent ev(String type, {required String team, int minute = 10}) => (
    minute: minute,
    type: type,
    team: team,
    scorer: null,
    scorerId: null,
    textKey: null,
    shotResult: type == 'chance' ? 'on_target' : null,
    big: type == 'chance',
    xg: type == 'chance' ? 0.5 : 0,
    player: null,
    params: const <String, Object?>{},
    card: null,
    playerId: null,
  );

  /// A match THEY dominated: two goals and a chance to our one chance.
  ///
  /// Shaped after the fixture that was reported — a two-goal defeat in which
  /// the board claimed the beaten side had the better of it.
  LiveStats theyDominated({required bool isHome}) => liveStatsFor(
    frame: (
      minute: 90,
      shown: [
        ev('goal', team: 'away', minute: 20),
        ev('goal', team: 'away', minute: 55),
        ev('chance', team: 'away', minute: 40),
        ev('chance', team: 'home', minute: 30),
        ev('corner', team: 'away', minute: 50),
      ],
      ourGoals: 0,
      theirGoals: 2,
      finished: true,
    ),
    result: const <String, dynamic>{},
    isHome: isHome,
    strategyId: 'balanced',
  );

  /// Our column out of a row, whichever side of the board it is printed on.
  ///
  /// The venue decides the ORDER the two figures are shown in and nothing about
  /// who earned them, which is the whole distinction these tests are about.
  (int ours, int theirs) row(LiveStats s, String key, {required bool isHome}) {
    final r = s.rows.firstWhere((r) => r.key == key);
    return isHome ? (r.home, r.away) : (r.away, r.home);
  }

  test('the side that had the chances is the side they are counted for', () {
    for (final isHome in [true, false]) {
      final s = theyDominated(isHome: isHome);
      final shots = row(s, 'shots', isHome: isHome);
      final onTarget = row(s, 'sot', isHome: isHome);
      final corners = row(s, 'corners', isHome: isHome);
      expect(
        shots.$2,
        greaterThan(shots.$1),
        reason: 'we out-shot a side that beat us 2-0 (isHome: $isHome)',
      );
      expect(onTarget.$2, greaterThan(onTarget.$1));
      expect(corners, (0, 1));
    }
  });

  test('and the counters do not change with the venue at all', () {
    // Same match, same events, different ground. Every figure has to match.
    final home = theyDominated(isHome: true);
    final away = theyDominated(isHome: false);
    for (final key in ['shots', 'sot', 'big', 'bigmiss', 'corners']) {
      expect(
        row(away, key, isHome: false),
        row(home, key, isHome: true),
        reason: '$key moved between grounds',
      );
    }
  });

  test('POSSESSION LEANS TO THE SIDE ON TOP, at either ground', () {
    // The sign of the swing, which is the fault the counters hid. Ours is
    // `possHome` at home and `100 - possHome` away.
    for (final isHome in [true, false]) {
      final s = theyDominated(isHome: isHome);
      final ourPoss = isHome ? s.possHome : s.possAway;
      expect(
        ourPoss,
        lessThan(50),
        reason: 'a 2-0 defeat showed the ball our way (isHome: $isHome)',
      );
    }
  });

  test('and so does the momentum arrow', () {
    for (final isHome in [true, false]) {
      final s = theyDominated(isHome: isHome);
      final ourDanger = isHome ? s.dangerHome : 100 - s.dangerHome;
      expect(ourDanger, lessThan(50), reason: 'the arrow pointed our way');
    }
  });

  test('and it all reverses when WE are the side on top', () {
    // The mirror image, so none of the above can pass on a board that simply
    // always favours the opposition.
    LiveStats weDominated({required bool isHome}) => liveStatsFor(
      frame: (
        minute: 90,
        shown: [
          ev('goal', team: 'home', minute: 20),
          ev('goal', team: 'home', minute: 55),
          ev('chance', team: 'home', minute: 40),
          ev('chance', team: 'away', minute: 30),
        ],
        ourGoals: 2,
        theirGoals: 0,
        finished: true,
      ),
      result: const <String, dynamic>{},
      isHome: isHome,
      strategyId: 'balanced',
    );

    for (final isHome in [true, false]) {
      final s = weDominated(isHome: isHome);
      final shots = row(s, 'shots', isHome: isHome);
      expect(shots.$1, greaterThan(shots.$2));
      expect(isHome ? s.possHome : s.possAway, greaterThan(50));
    }
  });
}
