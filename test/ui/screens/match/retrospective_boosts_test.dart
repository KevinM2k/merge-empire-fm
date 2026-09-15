/// VAR and the Physio Sponge — the two boosts that undo something already
/// written.
///
/// Neither prevents anything: by the time either is reachable the man is off
/// the pitch and the referee's list has moved on. What this proves is that the
/// undo is complete — his own square, both booking lists, the injury flags —
/// that it re-decides the rest of the match from NOW rather than from the
/// incident, and that a chance passed on is gone for that man.
///
/// Harness borrowed from `match_screen_test.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coach_pages.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/boost_engine.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart'
    show CutawayOutcome;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart';

import 'match_screen_test.dart';

Map<String, dynamic> _ratings() => {
  'strategyId': 'balanced',
  'strategiesUsed': ['balanced'],
  'strategyChanged': false,
  'followedCoachSuggestion': false,
  'ourAttackRating': 60,
  'ourDefenceRating': 55,
  'effectiveSquadRating': 58,
  'squadRating': 58,
  'effOppAttackRating': 50,
  'effOppDefenceRating': 52,
  'effectiveOppRating': 51,
  'opponentRating': 51,
  'homeGoals': 0,
  'awayGoals': 0,
};

/// `s4_m27` books c7 in the 51st and shows c3 a STRAIGHT RED in the 76th.
Map<String, dynamic> _redResult() => {
  ...matchResult(fixtureKey: 's4_m27', addedTime: 0),
  ..._ratings(),
};

/// An injury to c3 at 30, written the way the engine writes one: the event,
/// the port's `no_sub` marker beside it, and the log entry a cancel reads.
Map<String, dynamic> _injuryResult({List<String> also = const []}) => {
  ...matchResult(fixtureKey: 's1_m44', addedTime: 0),
  ..._ratings(),
  'events': [
    {'minute': 30, 'type': 'injury', 'player': 'Smith'},
    {
      'minute': 30,
      'type': 'no_sub',
      'player': 'Smith',
      'instanceId': 'c3',
      'slotId': 's3',
      'slotPosition': 'MID',
    },
  ],
  'injuredName': 'Smith',
  'injuryCount': 1 + also.length,
  'injuryLog': [
    {'iid': 'c3', 'minute': 30, 'name': 'Smith', 'prevSlotId': 's3', 'replacedBy': null},
    for (final id in also)
      {
        'iid': id,
        'minute': 30,
        'name': 'Jones',
        'prevSlotId': 's${id.substring(1)}',
        'replacedBy': null,
      },
  ],
};

/// The eleven `match_screen_test`'s `elevenSave` builds — GK, four DEF, three
/// MID, three FWD — because the referee rolls off the LINEUP'S DEFINITIONS and
/// `s4_m27` is documented against exactly these: c7 booked in the 51st, c3 a
/// straight red in the 76th. [cards] above eleven adds a bench.
Map<String, dynamic> _save({
  int cards = 16,
  Map<String, int> boosts = const {'var_review': 1, 'physio_sponge': 1},
  String? trait,
}) {
  final state = createDefaultState();
  final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
  final byPos = {
    for (final pos in ['GK', 'DEF', 'MID', 'FWD'])
      pos: players.firstWhere((p) => p.position == pos && p.tier == 1).id,
  };
  const order = [
    'GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'FWD', 'FWD', 'FWD',
  ];
  for (var i = 0; i < cards; i++) {
    cells[i] = {
      'definitionId': byPos[i < order.length ? order[i] : 'MID']!,
      'instanceId': 'c$i',
      'variant': 0,
      if (trait != null) 'matchSlot': true,
      if (trait != null) 'matchTrait': {'id': trait, 'level': 3},
    };
  }
  (state['squad'] as Map<String, dynamic>)['lineup'] = [
    for (var i = 0; i < 11; i++)
      <String, dynamic>{
        'slotId': 's$i',
        'slotPosition': order[i],
        'cardInstanceId': 'c$i',
      },
  ];
  state['matchBoosts'] = Map<String, dynamic>.from(boosts);
  return state;
}

/// What the sim does to a casualty: the card is marked hurt and his square is
/// emptied. Both halves — the flag is what keeps him off his own bench.
void _injure(ProviderContainer container, String id) {
  container.read(gameProvider).update((s) {
    for (final row in (s['squad'] as Map<String, dynamic>)['lineup'] as List) {
      if (row is Map<String, dynamic> && row['cardInstanceId'] == id) {
        row['cardInstanceId'] = null;
      }
    }
    for (final cell in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
      if (cell is Map<String, dynamic> && cell['instanceId'] == id) {
        cell['injured'] = true;
        cell['injuredAt'] = DateTime.now().millisecondsSinceEpoch;
        cell['injuryDurationMs'] = const Duration(days: 2).inMilliseconds;
      }
    }
  });
}

Map<String, dynamic> _cell(ProviderContainer c, String id) =>
    ((c.read(gameProvider).state!['grid'] as Map<String, dynamic>)['cells']
            as List)
        .whereType<Map<String, dynamic>>()
        .firstWhere((x) => x['instanceId'] == id);

Object? _slotOf(ProviderContainer c, String slotId) =>
    ((c.read(gameProvider).state!['squad'] as Map<String, dynamic>)['lineup']
            as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => r['slotId'] == slotId)['cardInstanceId'];

/// The referee's list, ours only, as `minute:who:card`.
List<String> _ourCards(MatchScreenState state) => [
  for (final b in state.bookings)
    if (b['team'] != 'away')
      '${b['minute']}:${b['playerInstanceId']}:${b['card']}',
];

final _coachSpeaks = find.byWidgetPredicate(
  (Widget w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('coach-action-'),
);

/// Run the clock to the card whose action is [waitFor], answering anything
/// else Colin says on the way — the half-time talk holds the match — and
/// finishing any chance the pitch is retelling, which stops the clock too.
Future<void> _runTo(
  WidgetTester tester,
  MatchScreenState state, {
  required String waitFor,
}) async {
  final target = find.byKey(ValueKey('coach-action-$waitFor'));
  for (var i = 0; i < 600 && !state.frame.finished; i++) {
    // A card he has to answer is a ROUTE, so it is not on screen until the
    // frames it opens over have run.
    if (state.paused && _coachSpeaks.evaluate().isEmpty) {
      await tester.pumpAndSettle();
    }
    if (target.evaluate().isNotEmpty) return;
    if (_coachSpeaks.evaluate().isNotEmpty) {
      await tester.tap(_coachSpeaks.first);
      await tester.pumpAndSettle();
      continue;
    }
    if (state.clipPlaying) {
      tester.widget<CutawayStage>(find.byType(CutawayStage)).onDone!(
        CutawayOutcome.goal,
      );
      await tester.pump();
      continue;
    }
    await tester.pump(minuteDurationFor(1));
  }
  fail('never reached the $waitFor card');
}

Future<void> _finish(WidgetTester tester, MatchScreenState state) async {
  if (state.paused) {
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
  }
  state.skipToEnd();
  await tester.pumpAndSettle();
  await settleSave(tester);
}

void main() {
  group('VAR REVIEW', () {
    /// Play to the red, answer Colin, and arrive at the open bench.
    Future<(ProviderContainer, MatchScreenState)> atTheRed(
      WidgetTester tester, {
      required String instance,
      Map<String, int> boosts = const {'var_review': 1, 'physio_sponge': 1},
      String? trait,
    }) async {
      tester.view.physicalSize = const Size(420 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = await pumpMatch(
        tester,
        _redResult(),
        save: _save(boosts: boosts, trait: trait),
        instance: instance,
      );
      final state = stateOf(tester);
      expect(
        _ourCards(state),
        ['51:c7:yellow', '76:c3:red'],
        reason: 'the fixture chosen no longer shows those two cards',
      );
      // The red at 76 pauses into Colin's one-time explanation, then the bench.
      await _runTo(tester, state, waitFor: 'coachtip.tap_dismiss');
      expect(state.frame.minute, 76);
      await tester.tap(
        find.byKey(const ValueKey('coach-action-coachtip.tap_dismiss')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsOneWidget);
      return (c, state);
    }

    testWidgets('A QUIET WORD WIPES THE OTHER MAN\'S YELLOW at the same bench', (
      tester,
    ) async {
      final (c, state) = await atTheRed(
        tester,
        instance: 'quiet',
        boosts: const {'var_review': 1, 'physio_sponge': 1, 'quiet_word': 1},
      );
      // c7 was booked at 51 and is still on; he is the word's man.
      expect(state.cautionedIds, contains('c7'));
      expect(state.quietTarget, 'c7');
      expect(find.byKey(const ValueKey('bench-boost-quiet_word')), findsOneWidget);

      state.applyQuietWord('c7');
      await tester.pump();

      expect(state.cautionedIds, isNot(contains('c7')));
      expect(_ourCards(state), ['76:c3:red'], reason: 'his yellow is gone');
      expect(boostCount(c.read(gameProvider).state, 'quiet_word'), 0);
      expect(state.notes.any((n) => n.key == 'boost.quiet.wiped'), isTrue);
      expect(state.canQuietWord('c7'), isFalse);

      await _finish(tester, state);
      // And the whistle writes nothing on his card.
      final stats = _cell(c, 'c7')['stats'] as Map?;
      expect(stats?['yellows'] ?? 0, 0);
    });

    // Ten Man Wall lights on the red, so the ten left glow and the man who
    // went is not listed — his trait died with his square.
    testWidgets('THE MAN SENT OFF IS NOT ON THE ACTIVE LIST, AND THE TEN PULSE',
        (tester) async {
      final (c, state) = await atTheRed(
        tester,
        instance: 'lit-bench',
        trait: 'ten_man_wall',
      );
      expect(state.sentOffIds, contains('c3'));
      expect(state.litIds(), hasLength(10));
      expect(state.litIds(), isNot(contains('c3')));
      // The bench sheet: the ten on the pitch pulse, and so does a sub who
      // would light up the moment he came on.
      final pulses = find.byKey(const ValueKey('boost-pulse'));
      expect(pulses, findsWidgets);
      expect(state.wouldBeLitIds(), contains('c11'));
      expect(state.wouldBeLitIds(), isNot(contains('c3')));
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsNothing);
      // Colin's tactic tip may be over the board; put him away first.
      state.clearCoachLine();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('match-stats-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-active-cards')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-active-ten_man_wall-c3')), findsNothing);
      expect(find.byKey(const ValueKey('match-active-ten_man_wall-c7')), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _finish(tester, state);
      expect(c.read(gameProvider).state, isNotNull);
    });

    testWidgets('PUTS HIM BACK IN HIS OWN SQUARE, ON A YELLOW', (tester) async {
      final (c, state) = await atTheRed(tester, instance: 'var-back');
      expect(_slotOf(c, 's3'), isNull, reason: 'he was not sent off');
      expect(state.sentOffIds, contains('c3'));
      expect(state.canVar('c3'), isTrue);

      state.applyVar('c3');
      await tester.pump();

      expect(_slotOf(c, 's3'), 'c3');
      expect(state.sentOffIds, isNot(contains('c3')));
      expect(state.cautionedIds, contains('c3'));
      expect(boostCount(c.read(gameProvider).state, 'var_review'), 0);
      // The red is off the referee's list — what stands at 76 is a yellow.
      final his = [
        for (final b in state.bookings)
          if (b['playerInstanceId'] == 'c3') '${b['minute']}:${b['card']}',
      ];
      expect(his, ['76:$cardYellow']);
      expect(state.notes.any((n) => n.key == 'boost.var.overturned'), isTrue);
      // Spent for him: a second review is not on offer.
      expect(state.canVar('c3'), isFalse);

      await _finish(tester, state);
      // And the whistle writes a yellow on his card, not a red.
      final stats = _cell(c, 'c3')['stats'] as Map?;
      expect(stats?['reds'] ?? 0, 0);
      expect(stats?['yellows'], 1);
    });

    testWidgets('RE-DECIDES THE REST FROM NOW, NOT FROM THE INCIDENT', (
      tester,
    ) async {
      final (c, state) = await atTheRed(tester, instance: 'var-now');
      final before = state.resimCount;
      final at = state.frame.minute;
      final kept = [
        for (final e in (state.widget.result['events'] as List))
          if ((e as Map)['minute'] as num <= at) Map.of(e),
      ];

      state.applyVar('c3');
      await tester.pump();

      expect(state.resimCount, before + 1);
      final after = [
        for (final e in (state.widget.result['events'] as List))
          if ((e as Map)['minute'] as num <= at) Map.of(e),
      ];
      expect(after, kept, reason: 'minutes already watched were rewritten');
      await _finish(tester, state);
      expect(c.read(gameProvider).state, isNotNull);
    });

    testWidgets('CLOSING THE BENCH WITHOUT USING IT IS THE DECISION', (
      tester,
    ) async {
      final (c, state) = await atTheRed(tester, instance: 'var-lock');
      expect(state.canVar('c3'), isTrue);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsNothing);

      expect(state.canVar('c3'), isFalse);
      expect(boostCount(c.read(gameProvider).state, 'var_review'), 1,
          reason: 'nothing was spent');
      state.applyVar('c3');
      await tester.pump();
      expect(_slotOf(c, 's3'), isNull, reason: 'a locked review still ran');
      await _finish(tester, state);
    });

    testWidgets('is not on offer without one in the bag', (tester) async {
      final (_, state) = await atTheRed(
        tester,
        instance: 'var-none',
        boosts: const {},
      );
      expect(state.canVar('c3'), isFalse);
      // The bench still shows the tile — with the price on it, not a blank.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bench-boost-count-var_review'))).data,
        'x0',
      );
      expect(
        tester.widget<Tooltip>(find.byKey(const ValueKey('bench-boost-reason-var_review'))).message,
        t('boost.bench.none'),
      );
      await _finish(tester, state);
    });

    // ── The row on the bench ──────────────────────────────────────────────
    testWidgets('THE BENCH OFFERS IT FOR HIM, AND A TAP PUTS HIM BACK', (
      tester,
    ) async {
      // Two in the bag, so that after one is taken the tile's reason is
      // about the MATCH (nothing left to review) rather than the wallet.
      final (c, state) = await atTheRed(
        tester,
        instance: 'bench-var',
        boosts: const {'var_review': 2, 'physio_sponge': 1},
      );
      final reason = find.byKey(const ValueKey('bench-boost-reason-var_review'));
      expect(find.byKey(const ValueKey('bench-boost-var_review')), findsOneWidget);
      // FOR him, by name — a tile that is live says who it is for.
      final him = CardInstance.from(_cell(c, 'c3'))!.name();
      expect(
        tester.widget<Tooltip>(reason).message,
        t('boost.bench.for', {'player': him}),
      );
      await tester.tap(find.byKey(const ValueKey('bench-boost-var_review')));
      await tester.pumpAndSettle();
      expect(_slotOf(c, 's3'), 'c3');
      expect(state.sentOffIds, isNot(contains('c3')));
      // Taken: the tile now says there is nothing left to review.
      expect(tester.widget<Tooltip>(reason).message, t('boost.var_review.idle'));
      await _finish(tester, state);
    });

    testWidgets('CLOSED WITHOUT USING IT, THE TILE SAYS WHY WHEN THE BENCH REOPENS', (
      tester,
    ) async {
      final (c, state) = await atTheRed(tester, instance: 'bench-var-late');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsNothing);

      unawaited(state.openSubs());
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsOneWidget);
      expect(
        tester.widget<Tooltip>(find.byKey(const ValueKey('bench-boost-reason-var_review'))).message,
        t('boost.locked.too_late'),
      );
      await tester.tap(find.byKey(const ValueKey('bench-boost-var_review')));
      await tester.pumpAndSettle();
      expect(_slotOf(c, 's3'), isNull, reason: 'a locked tile still acted');
      await _finish(tester, state);
    });
  });

  group('PHYSIO SPONGE', () {
    Future<(ProviderContainer, MatchScreenState)> atTheInjury(
      WidgetTester tester, {
      required String instance,
      int cards = 16,
      Map<String, int> boosts = const {'var_review': 1, 'physio_sponge': 1},
      List<String> also = const [],
    }) async {
      tester.view.physicalSize = const Size(420 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = await pumpMatch(
        tester,
        _injuryResult(also: also),
        save: _save(cards: cards, boosts: boosts),
        instance: instance,
      );
      _injure(c, 'c3');
      for (final id in also) {
        _injure(c, id);
      }
      final state = stateOf(tester);
      // Cover on the bench asks "make the change?"; nobody fit says so and OK.
      await _runTo(tester, state, waitFor: cards > 11 ? 'match.subs' : 'common.ok');
      expect(state.frame.minute, 30);
      return (c, state);
    }

    testWidgets('HEALS HIM, PUTS HIM BACK, AND SAYS SO', (tester) async {
      final (c, state) = await atTheInjury(tester, instance: 'physio-back');
      expect(state.paused, isTrue);
      await tester.tap(find.byKey(const ValueKey('coach-action-match.subs')));
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsOneWidget);
      expect(state.canPhysio('c3'), isTrue);
      final before = state.resimCount;

      state.applyPhysio('c3');
      await tester.pump();

      expect(_cell(c, 'c3')['injured'], isFalse);
      expect(_slotOf(c, 's3'), 'c3');
      final log = (state.widget.result['injuryLog'] as List).first as Map;
      expect(log['cancelled'], isTrue);
      expect(boostCount(c.read(gameProvider).state, 'physio_sponge'), 0);
      expect(state.resimCount, before + 1);
      expect(state.notes.any((n) => n.key == 'boost.physio.recovered'), isTrue);
      expect(state.canPhysio('c3'), isFalse);
      await _finish(tester, state);
    });

    // **THE GUARD HAD TO MOVE.** `_onInjuryShown` returned without opening the
    // bench when nobody fit was left — exactly when a sponge is worth most.
    testWidgets('OPENS THE BENCH WITH NOBODY TO BRING ON, because a sponge is held', (
      tester,
    ) async {
      final (_, state) = await atTheInjury(
        tester,
        instance: 'physio-nobody',
        cards: 11,
      );
      expect(state.paused, isTrue);
      await tester.tap(find.byKey(const ValueKey('coach-action-common.ok')));
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsOneWidget);
      expect(state.canPhysio('c3'), isTrue);
      await _finish(tester, state);
    });

    testWidgets('and stays shut with nobody to bring on and no sponge', (
      tester,
    ) async {
      final (_, state) = await atTheInjury(
        tester,
        instance: 'physio-nobody-none',
        cards: 11,
        boosts: const {},
      );
      await tester.tap(find.byKey(const ValueKey('coach-action-common.ok')));
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsNothing);
      await _finish(tester, state);
    });

    testWidgets('THE LOCK IS PER MAN: a second casualty is still offered one', (
      tester,
    ) async {
      final (c, state) = await atTheInjury(
        tester,
        instance: 'physio-lock',
        also: const ['c5'],
      );
      await tester.tap(find.byKey(const ValueKey('coach-action-match.subs')));
      await tester.pumpAndSettle();
      expect(state.canPhysio('c3'), isTrue);
      expect(state.canPhysio('c5'), isTrue);

      // Dismissed with neither used: BOTH men were on offer, both are gone.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(state.canPhysio('c3'), isFalse);
      expect(state.canPhysio('c5'), isFalse);
      expect(boostCount(c.read(gameProvider).state, 'physio_sponge'), 1);
      await _finish(tester, state);
    });

    // ── The row on the bench ──────────────────────────────────────────────
    testWidgets('COLIN SIGNPOSTS IT, AND THE BENCH TILE HEALS HIM', (
      tester,
    ) async {
      // Two in the bag, so that after one is used the tile's reason is about
      // the match (nobody down) rather than the wallet.
      final (c, state) = await atTheInjury(
        tester,
        instance: 'bench-physio',
        boosts: const {'var_review': 1, 'physio_sponge': 2},
      );
      // The card names the door; the bench IS the door.
      expect(await readCoachPages(tester), contains(t('coach.injury.physio_hint')));
      await tester.tap(find.byKey(const ValueKey('coach-action-match.subs')));
      await tester.pumpAndSettle();
      // The panel arrives with the bench list already open on the hole —
      // `openOn` — which sits over the row. Close the list; the panel stays.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(SubsPanel), findsOneWidget);

      final tile = find.byKey(const ValueKey('bench-boost-physio_sponge'));
      expect(tile, findsOneWidget);
      expect(find.byKey(const ValueKey('bench-boost-count-physio_sponge')), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(_cell(c, 'c3')['injured'], isFalse);
      expect(_slotOf(c, 's3'), 'c3');
      expect(boostCount(c.read(gameProvider).state, 'physio_sponge'), 1);
      expect(
        tester.widget<Tooltip>(find.byKey(const ValueKey('bench-boost-reason-physio_sponge'))).message,
        t('boost.physio_sponge.idle'),
      );
      await _finish(tester, state);
    });
  });
}
