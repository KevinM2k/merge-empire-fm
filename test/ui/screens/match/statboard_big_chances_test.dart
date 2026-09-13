/// **SHOTS AND BIG CHANCES WERE THE SAME NUMBER, in every match ever played.**
///
/// `liveStatsFor` incremented its big-chance counter on the same branch as its
/// shot counter, unconditionally, so two rows of a five-row board could never
/// differ. Reported from the couch off a goalless home win that read "Shots 14
/// / Big Chances 14 / Big Missed 7" and looked like daylight robbery rather
/// than a quiet afternoon.
///
/// The engine has marked a big chance at xG 0.22 since the feed was ported and
/// `MatchClockEvent` carries the flag; the statistics were the one reader that
/// never looked at it. And `bigmiss` counted OFF-TARGET shots — a different
/// stat wearing this one's name.
///
/// So the board now has to hold three things together: a big chance is a
/// chance the engine flagged, a small one is not, and — because a `chance`
/// event is a non-goal by construction — big chances equals big missed plus
/// goals.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';

void main() {
  TimelineEvent ev(
    String type, {
    required String team,
    int minute = 10,
    bool big = false,
    bool onTarget = true,
  }) => (
    minute: minute,
    type: type,
    team: team,
    scorer: null,
    scorerId: null,
    textKey: null,
    shotResult: type == 'chance' ? (onTarget ? 'on_target' : 'off') : null,
    big: big,
    xg: type == 'chance' ? (big ? 0.26 : 0.12) : 0,
    player: null,
    params: const <String, Object?>{},
    card: null,
    playerId: null,
    zone: null,
  );

  /// Four chances, one of them big, and one goal — at home, so the engine's
  /// `home` tag and ours are the same and the venue is not what is under test.
  LiveStats board(List<TimelineEvent> shown, {int ourGoals = 0}) => liveStatsFor(
    frame: (
      minute: 90,
      shown: shown,
      ourGoals: ourGoals,
      theirGoals: 0,
      finished: true,
    ),
    result: const <String, dynamic>{},
    isHome: true,
    strategyId: 'balanced',
  );

  int ours(LiveStats s, String key) =>
      s.rows.firstWhere((r) => r.key == key).home;

  test('a small chance is a shot and nothing more', () {
    final s = board([
      for (var i = 0; i < 4; i++) ev('chance', team: 'home', minute: 10 + i),
    ]);
    expect(ours(s, 'shots'), 4);
    expect(ours(s, 'big'), 0, reason: 'none of them was flagged big');
    expect(ours(s, 'bigmiss'), 0);
  });

  test('a big chance is counted as one, and only it', () {
    final s = board([
      ev('chance', team: 'home', minute: 10, big: true),
      ev('chance', team: 'home', minute: 20),
      ev('chance', team: 'home', minute: 30),
    ]);
    expect(ours(s, 'shots'), 3);
    expect(ours(s, 'big'), 1);
    expect(ours(s, 'bigmiss'), 1, reason: 'a chance in the list is a non-goal');
  });

  test('and the two rows can differ, which is the whole bug', () {
    // The goalless 14-shot afternoon that was reported, in miniature: plenty of
    // shooting, one real opening. The old board printed 5 and 5.
    final s = board([
      ev('chance', team: 'home', minute: 10, big: true),
      for (var i = 0; i < 4; i++) ev('chance', team: 'home', minute: 20 + i),
    ]);
    expect(ours(s, 'shots'), 5);
    expect(ours(s, 'big'), 1);
    expect(
      ours(s, 'big'),
      lessThan(ours(s, 'shots')),
      reason: 'Shots and Big Chances were the same number in every match',
    );
  });

  test('big missed counts the openings, not the wayward shooting', () {
    // A big chance ON target is still a big chance missed — it was saved. A
    // small chance dragged wide is not one at all. The old counter had both of
    // those exactly the wrong way round.
    final s = board([
      ev('chance', team: 'home', minute: 10, big: true),
      ev('chance', team: 'home', minute: 20, onTarget: false),
      ev('chance', team: 'home', minute: 30, onTarget: false),
    ]);
    expect(ours(s, 'bigmiss'), 1);
    expect(ours(s, 'sot'), 1, reason: 'only the big one was on target');
  });

  test('a goal is a converted big chance, so the board adds up', () {
    // The invariant the goal folding has always claimed and the board could
    // never satisfy: big chances = big missed + goals.
    final s = board([
      ev('goal', team: 'home', minute: 5),
      ev('chance', team: 'home', minute: 10, big: true),
      ev('chance', team: 'home', minute: 20, big: true),
      ev('chance', team: 'home', minute: 30),
    ], ourGoals: 1);
    expect(ours(s, 'big'), 3, reason: 'two missed and one taken');
    expect(ours(s, 'bigmiss'), 2);
    expect(ours(s, 'big'), ours(s, 'bigmiss') + 1);
    expect(ours(s, 'shots'), 4, reason: 'the goal is a shot too');
  });
}
