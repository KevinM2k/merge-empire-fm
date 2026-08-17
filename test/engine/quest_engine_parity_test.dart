/// Differential test: the Dart quest engine against the JS it was ported from.
///
/// The save is BUILT BY THE NODE SCRIPT and shipped inside the fixture, so this
/// feeds the port byte-identical input rather than trying to reconstruct it —
/// which for a state with a squad, a set XI and a league in progress is most of
/// the divergence risk on its own.
///
/// See `tool/dump_quest_engine_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/engine/quest_match.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// A fresh copy of the reference save, so one test can't leak into the next.
Map<String, dynamic> baseState() =>
    jsonDecode(jsonEncode(ref['state'])) as Map<String, dynamic>;

Map<String, dynamic> result(String name) =>
    jsonDecode(jsonEncode((ref['results'] as Map)[name])) as Map<String, dynamic>;

List<Map<String, dynamic>> _instances(Object? raw) => [
  for (final c in raw as List) c as Map<String, dynamic>,
];

/// The reference writes an empty grant object for a quest that didn't pass.
int _grantCoins(Object? granted) =>
    ((granted as Map?)?['coins'] as num?)?.toInt() ?? 0;

void main() {
  setUp(() => setClock(() => 1700000000000));
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('questContext', () {
    test('reads the same fixture and squad facts', () {
      // The JS context also carries `hardMode`, which nothing reads off it —
      // the eligibility filter goes to the save directly — so the port leaves
      // it out rather than carrying a field with no reader.
      seeded.setSeed(1);
      final ctx = questContext(baseState());
      final want = ref['questContextMatch'] as Map<String, dynamic>;

      expect(ctx.divIdx, want['divIdx']);
      expect(ctx.matchesLeft, want['matchesLeft']);
      expect(ctx.quest.isHome, want['isHome']);
      expect(ctx.quest.ourRating, want['ourRating']);
      expect(ctx.quest.oppRating, want['oppRating']);
      expect(ctx.quest.ourDefence, want['ourDefence']);
      expect(ctx.quest.oppAttack, want['oppAttack']);
      expect(ctx.quest.fitCount, want['fitCount']);
      expect(ctx.quest.benchCount, want['benchCount']);
      expect(ctx.quest.defInLineup, want['defInLineup']);
      expect(ctx.quest.midInLineup, want['midInLineup']);
      expect(ctx.quest.hasGK, want['hasGK']);
      expect(ctx.quest.oldestSeasons, want['oldestSeasons']);
      expect(ctx.quest.undiscovered, want['undiscovered']);
      expect(ctx.quest.minigames, want['minigames']);
    });

    test('a season context skips the fixture entirely', () {
      // A season quest cannot depend on one fixture — it spans fourteen — and
      // the preview isn't free.
      seeded.setSeed(1);
      final ctx = questContext(baseState(), 'season');
      final want = ref['questContextSeason'] as Map<String, dynamic>;
      expect(ctx.quest.isHome, want['isHome']);
      expect(ctx.quest.oppRating, want['oppRating']);
      expect(ctx.quest.oppAttack, want['oppAttack']);
    });
  });

  group('rolling', () {
    for (final (label, seed, scope) in const [
      ('matchA', 4242, 'match'),
      ('matchB', 99, 'match'),
      ('seasonA', 4242, 'season'),
      ('seasonB', 7, 'season'),
    ]) {
      test('the rollable pool matches — $label', () {
        seeded.setSeed(seed);
        final ids = rollableQuests(baseState(), scope).map((d) => d.id);
        expect(ids, ref['rollable_$label']);
      });

      test('the draw matches, instance for instance — $label', () {
        // Pins the RNG draw order as well as the filters: the same pool shuffled
        // differently is a different track.
        seeded.setSeed(seed);
        final state = baseState();
        final rolled = rollQuests(state, scope, 3);
        expect(rolled, ref['roll_$label']);
        expect(state['quests']['recent'], ref['recent_$label']);
      });
    }

    test('the match track matches, and re-asking gives the same three', () {
      seeded.setSeed(31337);
      final state = baseState();
      expect(rollMatchQuests(state, 's3_m4'), ref['matchTrack']);
      expect(rollMatchQuests(state, 's3_m4'), ref['matchTrackAgain']);
    });

    test('the season track and its baselines match', () {
      seeded.setSeed(31337);
      final state = baseState();
      expect(rollSeasonQuests(state, 3), ref['seasonTrack']);
      expect(state['quests']['seasonBaselines'], ref['seasonBaselines']);
    });
  });

  group('evaluateMatchQuest', () {
    test('agrees on every match quest, at three divisions, over six results', () {
      // Six constructed matches against every match quest in the bank: a
      // routine home win, an away comeback with an injury and a late sub goal,
      // a hat-trick rout in which the keeper also scored, a goalless away draw,
      // a heavy defeat with the coach obeyed, and a defender's late winner.
      final state = baseState();
      var checked = 0;
      for (final entry in (ref['evaluate'] as Map<String, dynamic>).entries) {
        final res = result(entry.key);
        for (final cell in (entry.value as Map<String, dynamic>).entries) {
          final parts = cell.key.split('@');
          final def = getQuest(parts[0])!;
          final divIdx = int.parse(parts[1]);
          expect(
            evaluateMatchQuest(state, def, resolveTarget(def, divIdx), res),
            cell.value,
            reason: '${entry.key} ${cell.key}',
          );
          checked++;
        }
      }
      expect(checked, greaterThan(100));
    });
  });

  group('liveMatchQuestStatus', () {
    test('agrees at every minute of every result', () {
      final state = baseState();
      var checked = 0;
      for (final entry in (ref['live'] as Map<String, dynamic>).entries) {
        final res = result(entry.key);
        final events = (res['events'] as List?) ?? const [];
        for (final cell in (entry.value as Map<String, dynamic>).entries) {
          final parts = cell.key.split('@');
          final def = getQuest(parts[0])!;
          final minute = int.parse(parts[1]);
          final fired = [
            for (final e in events)
              if (((e as Map)['minute'] as num? ?? 0) <= minute) e,
          ];
          final partial = partialMatchResult(res, fired, minute);
          expect(
            liveMatchQuestStatus(state, def, resolveTarget(def, 3), partial).name,
            cell.value,
            reason: '${entry.key} ${cell.key}',
          );
          checked++;
        }
      }
      expect(checked, greaterThan(300));
    });
  });

  group('partialMatchResult', () {
    test('recounts the same way at every checkpoint', () {
      for (final entry in (ref['partials'] as Map<String, dynamic>).entries) {
        final res = result(entry.key);
        final events = (res['events'] as List?) ?? const [];
        for (final cell in (entry.value as Map<String, dynamic>).entries) {
          final minute = int.parse(cell.key);
          final fired = [
            for (final e in events)
              if (((e as Map)['minute'] as num? ?? 0) <= minute) e,
          ];
          final p = partialMatchResult(res, fired, minute);
          final want = cell.value as Map<String, dynamic>;
          for (final field in [
            'homeGoals',
            'awayGoals',
            'injuryCount',
            'won',
            'drawn',
            'minute',
            'duration',
          ]) {
            expect(p[field], want[field], reason: '${entry.key}@$minute $field');
          }
        }
      }
    });
  });

  group('applyMatchToSeasonQuests', () {
    test('accumulates the same counters, streaks and track over five matches', () {
      seeded.setSeed(31337);
      final state = baseState();
      rollSeasonQuests(state, 3);

      final steps = ref['seasonAccumulation'] as List;
      for (final raw in steps) {
        final step = raw as Map<String, dynamic>;
        applyMatchToSeasonQuests(state, result(step['after'] as String));
        expect(state['quests']['streaks'], step['streaks'],
            reason: 'streaks after ${step['after']}');
        expect(state['quests']['seasonTally'], step['tally'],
            reason: 'tally after ${step['after']}');
        expect(state['quests']['season'], step['track'],
            reason: 'track after ${step['after']}');
      }
    });
  });

  group('resolveMatchQuests', () {
    test('pays and clears the league track identically', () {
      seeded.setSeed(31337);
      final state = baseState();
      rollMatchQuests(state, 's3_m4');
      rollSeasonQuests(state, 3);
      final rows = resolveMatchQuests(state, result('hatTrickRout'));

      final want = ref['resolve_league'] as Map<String, dynamic>;
      final wantRows = want['rows'] as List;
      expect(rows.length, wantRows.length);
      for (var i = 0; i < rows.length; i++) {
        final w = wantRows[i] as Map<String, dynamic>;
        expect(rows[i].id, w['id']);
        expect(rows[i].icon, w['icon']);
        expect(rows[i].target, w['target']);
        expect(rows[i].passed, w['passed']);
        expect(rows[i].granted.coins, _grantCoins(w['granted']));
      }
      expect(state['resources']['fanCoins'], want['coins']);
      expect(state['quests']['match']['active'], want['activeAfter']);
      expect(state['quests']['match']['fixtureKey'], want['fixtureKeyAfter']);
    });

    test('a cup tie keeps the unfinished quests standing', () {
      // Cups sit between league games and are always played at home, so
      // clearing the track there let a cup tie eat "win away from home" — a
      // quest the match it was spent on could not possibly have passed.
      seeded.setSeed(31337);
      final state = baseState();
      rollMatchQuests(state, 's3_m4');
      rollSeasonQuests(state, 3);
      resolveMatchQuests(state, {...result('hatTrickRout'), 'isCup': true});

      final want = ref['resolve_cup'] as Map<String, dynamic>;
      expect(state['quests']['match']['active'], want['activeAfter']);
      expect(state['quests']['match']['fixtureKey'], want['fixtureKeyAfter']);
      expect(state['resources']['fanCoins'], want['coins']);
    });
  });

  group('rerolling', () {
    test('swaps the same quests and charges the same way', () {
      seeded.setSeed(555);
      final state = baseState();
      rollSeasonQuests(state, 3);
      final want = ref['reroll'] as Map<String, dynamic>;

      expect(
        _instances(state['quests']['season']).map((c) => c['id']),
        want['before'],
      );

      final first = rerollQuests(state);
      final second = rerollQuests(state);
      final third = rerollQuests(state);

      for (final (got, key) in [
        (first, 'first'),
        (second, 'second'),
        (third, 'third'),
      ]) {
        final w = want[key] as Map<String, dynamic>;
        expect(got.ok, w['ok'], reason: key);
        expect(got.cost, w['cost'], reason: key);
        expect(
          [for (final r in got.replaced) {'from': r.from, 'to': r.to}],
          w['replaced'],
          reason: key,
        );
      }

      expect(state['resources']['gems'], want['gemsAfter']);
      expect(state['quests']['seasonFreeRerollsUsed'], want['freeUsed']);
      expect(
        _instances(state['quests']['season']).map((c) => c['id']),
        want['track'],
      );
    });

    test('the first two are free and the third costs a gem', () {
      // Two, not one, because the capstone pays a single gem per division — so
      // with one free reroll a player who drew badly twice paid the ENTIRE
      // prize for the right to earn it.
      final want = ref['reroll'] as Map<String, dynamic>;
      expect((want['first'] as Map)['cost'], 0);
      expect((want['second'] as Map)['cost'], 0);
      expect((want['third'] as Map)['cost'], rerollGemCost);
    });
  });

  group('questTarget', () {
    test('resolves the same target for every quest at three divisions', () {
      final state = baseState();
      for (final entry in (ref['questTargets'] as Map<String, dynamic>).entries) {
        final parts = entry.key.split('@');
        final def = getQuest(parts[0])!;
        expect(
          questTarget(def, state, int.parse(parts[1])),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  group('fitsInSeason', () {
    test('agrees on every season quest across five states of a campaign', () {
      for (final entry in (ref['fitsInSeason'] as Map<String, dynamic>).entries) {
        final parts = entry.key.split('|');
        final def = getQuest(parts[0])!;
        final left = int.parse(parts[1]);
        final soFar = int.parse(parts[2]);
        expect(
          fitsInSeason(def, resolveTarget(def, 3), soFar, left),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  group('the division capstone', () {
    test('pays on the last claim and never again', () {
      seeded.setSeed(31337);
      final state = baseState();
      rollSeasonQuests(state, 3);
      for (final inst in _instances(state['quests']['season'])) {
        inst['completed'] = true;
        inst['progress'] = inst['target'];
      }

      final want = ref['capstone'] as Map<String, dynamic>;
      final wantClaims = want['claims'] as List;
      final ids = _instances(state['quests']['season'])
          .map((c) => c['id'] as String)
          .toList();

      for (var i = 0; i < ids.length; i++) {
        final got = claimQuest(state, ids[i]);
        final w = wantClaims[i] as Map<String, dynamic>;
        expect(got.ok, w['ok'], reason: ids[i]);
        expect(got.granted?.coins ?? 0, w['coins'], reason: ids[i]);
        final wantCapstone = w['capstone'] as Map<String, dynamic>?;
        expect(got.capstone?.divisionId, wantCapstone?['divisionId'],
            reason: ids[i]);
        expect(got.capstone?.gems, wantCapstone?['gems'], reason: ids[i]);
      }

      expect(state['resources']['gems'], want['gems']);
      expect(state['gemGrants']['questDivisionFirsts'], want['ledger']);
      expect(checkDivisionCapstone(state), want['again']);
    });
  });

  group('sweeping', () {
    test('pays out the unclaimed and leaves nothing behind', () {
      seeded.setSeed(31337);
      final state = baseState();
      rollSeasonQuests(state, 3);
      final first = _instances(state['quests']['season']).first;
      first['completed'] = true;
      first['progress'] = first['target'];

      final swept = sweepUnclaimedSeasonQuests(state);
      final want = ref['sweep'] as Map<String, dynamic>;
      final wantResult = want['result'] as Map<String, dynamic>;
      expect(swept.count, wantResult['count']);
      expect(swept.coins, wantResult['coins']);
      expect(state['resources']['fanCoins'], want['coins']);
      expect(unclaimedCount(state), want['unclaimedAfter']);
    });
  });
}
