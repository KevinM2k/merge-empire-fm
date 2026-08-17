/// Differential test: the Dart Deadline Day engine against the JS it was ported
/// from.
///
/// This is the one part of the game that runs on a REAL clock, and everything in
/// it derives from elapsed wall time rather than tick counts. So whole SESSIONS
/// are compared at fixed instants: open the window, jump the clock, and check
/// every listing on the board — because a port can get each formula right and
/// still spawn a different feed if it draws in a different order, or anchors the
/// schedule to the player instead of to the window.
///
/// BOTH generators are pinned. Listings roll real cards, and `rollDealCard` mixes
/// the seeded stream with bare `Math.random`, so ONE `JsMathRandom` feeds
/// `merge_engine` and `trait_engine` — the JS has one `Math.random`.
///
/// See `tool/dump_deadline_day_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/deadline_day.dart';
import 'package:merge_empire_fc/engine/deadline_day_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import '../support/js_math_random.dart';

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/deadline_day_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final Map<String, dynamic> refSave = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final int fixedNow = ref['fixedNow'] as int;
final int windowStart = ref['windowStart'] as int;
final int windowEnd = ref['windowEnd'] as int;

Object? _json(Object? v) => jsonDecode(jsonEncode(v));
Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _scenario(String name) => ref[name] as Map<String, dynamic>;

/// The instance id embeds a module counter reflecting how many cards each runtime
/// happened to have built — nothing about the deal. Stripped everywhere, with the
/// shape asserted separately.
const _idKeys = {'instanceId', 'signedInstanceId'};

Object? _stripIds(Object? v) {
  if (v is List) return [for (final e in v) _stripIds(e)];
  if (v is Map) {
    return {
      for (final e in v.entries)
        if (!_idKeys.contains(e.key)) '${e.key}': _stripIds(e.value),
    };
  }
  return v;
}

/// The same slice of the save the dump records.
Map<String, dynamic> _digest(Map<String, dynamic> s) {
  final cells = _map(s['grid'])?['cells'];
  final lineup = _map(s['squad'])?['lineup'];
  return {
    'deadlineDay': _stripIds(s['deadlineDay']),
    'cells': [
      if (cells is List)
        for (final c in cells)
          if (c == null)
            null
          else
            _stripIds({
              'definitionId': _map(c)?['definitionId'],
              'listed': _map(c)?['listed'],
              'loanedOut': _map(c)?['loanedOut'],
              'loanMatchesLeft': _map(c)?['loanMatchesLeft'],
              'borrowed': _map(c)?['borrowed'],
              'displayName': _map(c)?['displayName'],
            }),
    ],
    'lineup': [
      if (lineup is List)
        for (final l in lineup) _map(l)?['cardInstanceId'],
    ],
    'fanCoins': _map(s['resources'])?['fanCoins'],
    'transfersAccepted': _map(s['stats'])?['transfersAccepted'],
  };
}

/// The save every scenario starts from, matching the dump script's own.
Map<String, dynamic> _baseState({
  int fanCoins = 5000000,
  List<Object?>? cells,
}) {
  final s = jsonDecode(jsonEncode(refSave['state'])) as Map<String, dynamic>;
  (s['resources'] as Map)['fanCoins'] = fanCoins;
  s['stats'] = _map(s['stats']) ?? <String, dynamic>{};
  s['events'] = {
    'active': <Object?>[],
    'progress': <String, dynamic>{},
    'claimed': <String, dynamic>{},
  };
  if (cells != null) (s['grid'] as Map)['cells'] = cells;
  return s;
}

/// A squad stripped back to three cards, so bids cannot be built without taking
/// it below a fieldable core.
List<Object?> _bareCells() {
  final s = jsonDecode(jsonEncode(refSave['state'])) as Map<String, dynamic>;
  final cells = (s['grid'] as Map)['cells'] as List;
  return [for (var i = 0; i < cells.length; i++) i < 3 ? cells[i] : null];
}

/// Seeds both streams the way the dump did.
void _seedBoth(int seed, int mathSeed) {
  seeded.setSeed(seed);
  // ONE instance for both, because the JS has one Math.random.
  final rng = JsMathRandom(mathSeed);
  setMergeRandom(rng);
  setTraitRandom(rng);
}

/// How a session-run scenario differs from the default save.
typedef RunSetup = ({int fanCoins, bool bareSquad});
const RunSetup _plain = (fanCoins: 5000000, bareSquad: false);

const Map<String, RunSetup> _sessionRuns = {
  'punctual': _plain,
  'aMinuteIn': _plain,
  'tenLate': _plain,
  'halfHourLate': _plain,
  'toTheWhistle': _plain,
  'bareSquad': (fanCoins: 5000000, bareSquad: true),
  'broke': (fanCoins: 0, bareSquad: false),
};

/// The drive scenarios, and the kind each plan is about.
const Map<String, String> _driveKinds = {
  'sellSide': 'bid',
  'haggle': 'bid',
  'greed': 'bid',
  'buySide': 'signing',
  'lowball': 'signing',
  'offers': 'signing',
  'noPatience': 'signing',
  'cannotAfford': 'signing',
  'dismissed': 'signing',
  'pauseResume': 'signing',
};

/// Only `offers` and `noPatience` narrow on the seller's patience, exactly as the
/// dump does — patience is derived from the listing id, and about a third of clubs
/// have none at all.
bool Function(Listing) _wantWhen(String name) => switch (name) {
  'offers' => (l) => (_num(l['haggleRounds']) ?? 0) > 0,
  'noPatience' => (l) => (_num(l['haggleRounds']) ?? 0) == 0,
  _ => (_) => true,
};

void main() {
  setUp(() => setClock(() => fixedNow));
  tearDown(() {
    resetClock();
    resetMergeRandom();
    resetTraitRandom();
    clearBus();
  });

  group('constants', () {
    test('match the JS', () {
      final c = ref['constants'] as Map<String, dynamic>;
      expect(sessionMs, c['SESSION_MS']);
      expect(listingIntervalMs, c['LISTING_INTERVAL_MS']);
      expect(listingTtlMs, c['LISTING_TTL_MS']);
      expect(maxSpawns, c['MAX_SPAWNS']);
      expect(maxLiveListings, c['MAX_LIVE_LISTINGS']);
      expect(bidShare, c['BID_SHARE']);
      expect(loanShare, c['LOAN_SHARE']);
      expect(loanOutShare, c['LOAN_OUT_SHARE']);
      expect(bidPremium, c['BID_PREMIUM']);
      expect(signingPremium, c['SIGNING_PREMIUM']);
      expect(marqueePremium, c['MARQUEE_PREMIUM']);
      expect(maxMarquee, c['MAX_MARQUEE']);
      expect(marqueeMinIndex, c['MARQUEE_MIN_INDEX']);
      expect(marqueeMaxIndex, c['MARQUEE_MAX_INDEX']);
      expect(marqueeChance, c['MARQUEE_CHANCE']);
      expect(bidMinTier, c['BID_MIN_TIER']);
      expect(minHealthyKeep, c['MIN_HEALTHY_KEEP']);
      expect(scorePerSale, c['SCORE_PER_SALE']);
      expect(scorePerLoan, c['SCORE_PER_LOAN']);
      expect(scorePerSigning, c['SCORE_PER_SIGNING']);
      expect(scorePerMarquee, c['SCORE_PER_MARQUEE']);
      expect(historyLimit, c['HISTORY_LIMIT']);
      expect(tickerLines, c['TICKER_LINES']);
      expect(maxMarketTier, c['MAX_MARKET_TIER']);
    });

    test('divGapMult matches the JS, clamps and all', () {
      (ref['divGapMult'] as Map<String, dynamic>).forEach((gap, want) {
        final g = gap == 'null' ? null : num.parse(gap);
        expect(divGapMult(g), closeTo(want as num, 1e-12), reason: 'gap $gap');
      });
    });
  });

  group('the session', () {
    for (final entry in _sessionRuns.entries) {
      test('${entry.key} spawns the same feed and leaves the same save', () {
        final scenario = _scenario(entry.key);
        _seedBoth(scenario['seed'] as int, scenario['mathSeed'] as int);
        final state = _baseState(
          fanCoins: entry.value.fanCoins,
          cells: entry.value.bareSquad ? _bareCells() : null,
        );

        final joinAt = windowStart + (scenario['joinOffsetMs'] as int);
        final started = startSession(
          state,
          windowStart,
          nowMs: joinAt,
          windowEnd: windowEnd,
        );
        final wantStarted = scenario['started'] as Map<String, dynamic>;
        expect(started.ok, wantStarted['ok']);
        expect(started.reason, wantStarted['reason']);
        expect(started.endsAt, wantStarted['endsAt']);

        final wantSnaps = scenario['snapshots'] as List;
        for (var i = 0; i < wantSnaps.length; i++) {
          final want = wantSnaps[i] as Map<String, dynamic>;
          final at = windowStart + (want['offset'] as int);
          tickSession(state, at);
          final why = '${entry.key} @ ${want['offset']}';
          expect(sessionRemainingMs(state, at), want['remainingMs'], reason: why);
          expect(sessionStatus(state, windowStart, at), want['status'], reason: why);
          expect(
            [for (final l in liveListings(state, at)) l['listingId']],
            want['live'],
            reason: '$why — board order',
          );
          expect(
            [for (final l in liveListingsBySide(state, 'buy', at)) l['listingId']],
            want['liveBuy'],
            reason: '$why — buy side',
          );
          expect(
            [for (final l in liveListingsBySide(state, 'sell', at)) l['listingId']],
            want['liveSell'],
            reason: '$why — sell side',
          );
        }

        expect(
          _json(_digest(state)),
          scenario['state'],
          reason: '${entry.key} — save',
        );
      });
    }
  });

  group('the gates', () {
    test('report the same reason the JS does, per listing', () {
      final scenario = _scenario('punctual');
      _seedBoth(scenario['seed'] as int, scenario['mathSeed'] as int);
      final state = _baseState();
      startSession(state, windowStart, nowMs: windowStart, windowEnd: windowEnd);
      const at = 1200000;
      tickSession(state, windowStart + at);

      final rows = ref['gates'] as List;
      final board = liveListings(state, windowStart + at);
      var i = 0;
      for (final l in board) {
        final want = rows[i++] as Map<String, dynamic>;
        final why = '${l['kind']} ${l['listingId']}';
        expect(l['listingId'], want['listingId'], reason: why);
        expect(listingSide(l), want['side'], reason: why);
        expect(listingBlockedReason(state, l), want['blocked'], reason: why);
        final gate = canSign(state, l);
        expect(gate.ok, (want['canSign'] as Map)['ok'], reason: why);
        expect(gate.reason, (want['canSign'] as Map)['reason'], reason: why);
        expect(
          listingRemainingMs(l, windowStart + at),
          want['remainingMs'],
          reason: why,
        );
        expect(listingExpired(l, windowStart + at), want['expired'], reason: why);
      }
      // The last row is the null listing.
      expect(
        listingBlockedReason(state, null),
        (rows.last as Map)['blocked'],
      );
    });
  });

  group('driving a session', () {
    for (final entry in _driveKinds.entries) {
      final name = entry.key;
      test('$name takes the same path through the JS', () {
        final scenario = _scenario(name);
        _seedBoth(scenario['seed'] as int, scenario['mathSeed'] as int);
        final state = _baseState(
          fanCoins: name == 'cannotAfford' ? 1 : 5000000,
        );
        startSession(state, windowStart, nowMs: windowStart, windowEnd: windowEnd);

        final wantWhen = _wantWhen(name);
        // Advance until a listing of the kind this plan is about is actually live.
        var at = windowStart;
        while (at < windowEnd) {
          tickSession(state, at);
          final found = _listings(state).any(
            (l) =>
                l['status'] == 'live' &&
                !listingExpired(l, at) &&
                l['kind'] == entry.value &&
                wantWhen(l),
          );
          if (found) break;
          at += listingIntervalMs;
        }
        expect(
          at - windowStart,
          scenario['atOffset'],
          reason: '$name — the plan started at a different instant',
        );

        String? last;
        for (final rawStep in scenario['steps'] as List) {
          final step = rawStep as Map<String, dynamic>;
          final reuse = step['reuse'] == true;
          final kind = step['kind'] as String?;
          final target = reuse
              ? _find(state, last)
              : _listings(state).cast<Listing?>().firstWhere(
                    (l) =>
                        l!['status'] == 'live' &&
                        !listingExpired(l, at) &&
                        (kind == null || l['kind'] == kind) &&
                        (kind == null || wantWhen(l)),
                    orElse: () => null,
                  );
          final why = '$name / ${step['action']}';
          if (target == null) {
            expect(step['skipped'], 'none_live', reason: why);
            continue;
          }
          expect(step['skipped'], isNull, reason: why);
          last = '${target['listingId']}';
          expect(target['listingId'], step['listingId'], reason: why);

          final mult = _num(step['mult']);
          final price = _num(target['price']) ?? 0;
          final result = switch (step['action']) {
            'accept' => acceptListing(state, last, at),
            'dismiss' => dismissListing(state, last),
            'askForMore' =>
              askForMore(state, last, (price * mult!).round(), at),
            'submitOffer' => submitOffer(state, last, {
              'cash': (price * mult!).round(),
              'players': <Object?>[],
            }, at),
            'acceptCounter' => acceptSellerCounter(state, last, at),
            'pause' => {'paused': pauseListing(state, last, at)},
            'resume' => {'resumed': resumeListing(state, last, at + 30000)},
            _ => throw ArgumentError('${step['action']}'),
          };

          expect(_json(_stripIds(result)), step['result'], reason: why);
          expect(
            _json(_stripIds(_find(state, last))),
            step['listing'],
            reason: '$why — listing after',
          );
        }

        expect(
          _json(endSession(state, windowEnd)),
          scenario['summary'],
          reason: '$name — summary',
        );
        expect(_json(_digest(state)), scenario['state'], reason: '$name — save');
      });
    }
  });

  group('the one-session rule', () {
    test('a window can be opened once, and only once', () {
      final want = ref['reentry'] as Map<String, dynamic>;
      _seedBoth(11, 101);
      final state = _baseState();

      final first = startSession(
        state,
        windowStart,
        nowMs: windowStart,
        windowEnd: windowEnd,
      );
      expect(first.ok, (want['first'] as Map)['ok']);

      final again = startSession(
        state,
        windowStart,
        nowMs: windowStart + 60000,
        windowEnd: windowEnd,
      );
      expect(again.ok, (want['again'] as Map)['ok']);
      expect(again.reason, (want['again'] as Map)['reason']);

      endSession(state, windowEnd);

      final afterEnd = startSession(
        state,
        windowStart,
        nowMs: windowEnd + 1000,
        windowEnd: windowEnd + sessionMs,
      );
      expect(afterEnd.ok, (want['afterEnd'] as Map)['ok']);
      expect(afterEnd.reason, (want['afterEnd'] as Map)['reason']);

      // The NEXT occurrence is a different window, and is fair game.
      final nextWindow = startSession(
        state,
        windowEnd,
        nowMs: windowEnd + 1000,
        windowEnd: windowEnd + sessionMs,
      );
      expect(nextWindow.ok, (want['nextWindow'] as Map)['ok']);

      expect(hasUsedSession(state, windowStart), want['hasUsed']);
      expect(
        (_map(state['deadlineDay'])!['history'] as List).length,
        want['historyLength'],
      );
    });

    test('a window already shut buys nothing', () {
      final want = ref['closedWindow'] as Map<String, dynamic>;
      _seedBoth(1, 1);
      final state = _baseState();
      final r = startSession(
        state,
        windowStart,
        nowMs: windowEnd + 1,
        windowEnd: windowEnd,
      );
      expect(r.ok, want['ok']);
      expect(r.reason, want['reason']);
    });

    test('no window end falls back to the fixed length', () {
      final want = ref['noWindowEnd'] as Map<String, dynamic>;
      _seedBoth(1, 1);
      final state = _baseState();
      final r = startSession(state, windowStart, nowMs: windowStart);
      expect(r.ok, want['ok']);
      expect(r.endsAt, want['endsAt']);
    });

    test('the history ring keeps the most recent few, newest first', () {
      final want = ref['historyRing'] as Map<String, dynamic>;
      _seedBoth(2, 2);
      final state = _baseState();
      for (var i = 0; i < historyLimit + 3; i++) {
        final start = windowStart + i * sessionMs * 2;
        startSession(state, start, nowMs: start, windowEnd: start + sessionMs);
        endSession(state, start + sessionMs);
      }
      final history = _map(state['deadlineDay'])!['history'] as List;
      expect(history.length, want['length']);
      expect(
        [for (final h in history) _map(h)?['windowStart']],
        want['windowStarts'],
      );
    });
  });

  group('ensureDeadlineDay', () {
    test('grows the branch, and repairs a junk one', () {
      final want = ref['ensure'] as Map<String, dynamic>;
      final empty = <String, dynamic>{};
      expect(_json(ensureDeadlineDay(empty)), want['made']);

      // Typed dynamic on purpose: a junk branch reaches this from jsonDecode, so
      // the repair has to be able to write a map over a string.
      final junk = <String, dynamic>{
        'deadlineDay': <String, dynamic>{'session': 'nope', 'history': 'nope'},
      };
      ensureDeadlineDay(junk);
      expect(_json(junk['deadlineDay']), want['repaired']);
    });
  });
}

List<Listing> _listings(Map<String, dynamic> state) => [
  for (final l in (_map(_map(state['deadlineDay'])!['session'])!['listings']
      as List))
    l as Listing,
];

Listing? _find(Map<String, dynamic> state, String? listingId) {
  if (listingId == null) return null;
  for (final l in _listings(state)) {
    if (l['listingId'] == listingId) return l;
  }
  return null;
}
