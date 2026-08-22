/// The head-to-head line, all the way to Colin's pool.
///
/// **The engine being right proves nothing about a player ever seeing it.** The
/// whole reason these fourteen strings were unreachable is that a surface and
/// an engine can both be finished and never introduced — so this asks the
/// provider the bubble actually reads.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Boot a save, then hand back the opponent Colin is previewing and a way to
/// stamp results against them.
({ProviderContainer c, String opponent}) bootWithFixtures(WidgetTester? _) {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Through the runner: the season's schedule is a boot sweep, and without one
  // there is no next fixture to have a history with.
  final save = container.read(gameRunnerProvider).boot();
  final opponents = _map(save['progression'])?['seasonOpponents'];
  final opponent = (opponents is List && opponents.isNotEmpty)
      ? '${opponents.first}'
      : '';
  return (c: container, opponent: opponent);
}

void main() {
  tearDown(resetLocale);

  test('A CLUB WE HAVE NEVER PLAYED GETS NO HISTORY LINE', () {
    final boot = bootWithFixtures(null);
    final ids = boot.c.read(coachTipsProvider).map((t) => t.id);
    expect(ids, isNot(contains('head_to_head')));
  });

  test('and a run of three against them DOES', () {
    final boot = bootWithFixtures(null);
    expect(boot.opponent, isNotEmpty, reason: 'no fixture was drawn at all');

    final prog =
        boot.c.read(gameProvider).state!['progression'] as Map<String, dynamic>;
    final results = (prog['fixtureResults'] ??= <String, dynamic>{})
        as Map<String, dynamic>;
    for (var i = 1; i <= 3; i++) {
      results['s1_m$i'] = <String, dynamic>{
        'homeGoals': 2,
        'awayGoals': 0,
        'won': true,
        'drawn': false,
        'isHome': true,
        'opponentName': boot.opponent,
      };
    }

    final tips = boot.c.read(coachTipsProvider);
    final history = tips.where((t) => t.id == 'head_to_head');
    expect(history, hasLength(1));

    final text = history.first.text;
    expect(text, contains(boot.opponent));
    // The placeholders are FILLED, not printed. `{when}` is the one that has to
    // be resolved twice — the engine hands back a key and the pool turns it
    // into a phrase — so an unresolved one shows up here as literal braces.
    expect(text, isNot(contains('{')));
    expect(text, isNot(contains('}')));
    // And it is pooled copy: one line, not four separated by pipes.
    expect(text, isNot(contains('|')));
  });

  test('IT IS ONE SENTENCE, not the whole pool, and it HOLDS STILL', () {
    // Every `streak.*` and `last_meeting.*` string is three or four sentences
    // separated by pipes. A straight `t()` reads all of them at the player in
    // one line — which is what the first version of this did.
    //
    // And the pick has to be stable: the pool is rebuilt on every change to the
    // save, so a random one would have Colin rephrasing himself while the
    // bubble is open.
    final boot = bootWithFixtures(null);
    final prog =
        boot.c.read(gameProvider).state!['progression'] as Map<String, dynamic>;
    final results = (prog['fixtureResults'] ??= <String, dynamic>{})
        as Map<String, dynamic>;
    for (var i = 1; i <= 3; i++) {
      results['s1_m$i'] = <String, dynamic>{
        'homeGoals': 2,
        'awayGoals': 0,
        'won': true,
        'drawn': false,
        'isHome': true,
        'opponentName': boot.opponent,
      };
    }

    String line() => boot.c
        .read(coachTipsProvider)
        .firstWhere((t) => t.id == 'head_to_head')
        .text;

    final first = line();
    expect(first, isNot(contains('|')));
    // **Not a sentence COUNT.** The first draft asserted two, and it passed in
    // a full-file run and failed a filtered one: the opponent's name is drawn
    // from the seeded stream, so which pooled line the seed lands on depends on
    // how many tests ran before this one. A test whose expectation moves with
    // its neighbours is worse than no test.
    expect(first.trim(), isNotEmpty);
    for (var i = 0; i < 5; i++) {
      expect(line(), first, reason: 'Colin rephrased himself on read ${i + 2}');
    }
  });

  test('AND IT SITS ABOVE THE RATING GAP, because it is about THEM', () {
    // The pool is ordered best-first and is deliberately short. A run of
    // results against a club is what a manager checks before he checks anyone's
    // rating, so it may not end up under it.
    final boot = bootWithFixtures(null);
    final prog =
        boot.c.read(gameProvider).state!['progression'] as Map<String, dynamic>;
    final results = (prog['fixtureResults'] ??= <String, dynamic>{})
        as Map<String, dynamic>;
    for (var i = 1; i <= 3; i++) {
      results['s1_m$i'] = <String, dynamic>{
        'homeGoals': 0,
        'awayGoals': 3,
        'won': false,
        'drawn': false,
        'isHome': true,
        'opponentName': boot.opponent,
      };
    }

    final ids = boot.c.read(coachTipsProvider).map((t) => t.id).toList();
    expect(ids, contains('head_to_head'));
    final gapAt = ids.indexWhere((id) => id.startsWith('gap_') || id == 'rotate');
    if (gapAt >= 0) {
      expect(ids.indexOf('head_to_head'), lessThan(gapAt));
    }
  });

  test('and the line is in the player\'s language', () {
    setLocale('de');
    final boot = bootWithFixtures(null);
    final prog =
        boot.c.read(gameProvider).state!['progression'] as Map<String, dynamic>;
    ((prog['fixtureResults'] ??= <String, dynamic>{})
            as Map<String, dynamic>)['s1_m1'] =
        <String, dynamic>{
          'homeGoals': 1,
          'awayGoals': 1,
          'won': false,
          'drawn': true,
          'isHome': true,
          'opponentName': boot.opponent,
        };
    final tips = boot.c.read(coachTipsProvider);
    final history = tips.firstWhere((t) => t.id == 'head_to_head');
    // Not the key itself, and not English's own sentence.
    expect(history.text, isNot(contains('manager_hint.')));
    expect(history.text, isNot(contains('tight affair')));
  });
}
