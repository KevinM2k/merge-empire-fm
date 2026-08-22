/// The rules Deadline Day has to obey, as distinct from the feed it produces.
///
/// The parity fixture pins whole sessions against the JS; this pins the design
/// claims. Several of these are bugs the JS shipped and fixed, and the comments in
/// that file argue for them at length — so they are worth holding onto here rather
/// than trusting a regenerated fixture to notice.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/deadline_day.dart';
import 'package:merge_empire_fc/engine/deadline_day_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import '../support/js_math_random.dart';

const int _now = 1700000000000;
const int _windowStart = _now;
const int _windowEnd = _now + sessionMs;

final Map<String, dynamic> _refSave =
    jsonDecode(
          File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _state({int fanCoins = 5000000}) {
  final s = jsonDecode(jsonEncode(_refSave['state'])) as Map<String, dynamic>;
  (s['resources'] as Map)['fanCoins'] = fanCoins;
  s['stats'] = <String, dynamic>{};
  s['events'] = {
    'active': <Object?>[],
    'progress': <String, dynamic>{},
    'claimed': <String, dynamic>{},
  };
  return s;
}

List<Listing> _listings(Map<String, dynamic> state) => [
  for (final l
      in (_map(_map(state['deadlineDay'])!['session'])!['listings'] as List))
    l as Listing,
];

/// Every live listing, ignoring the display cap.
List<Listing> _allLive(Map<String, dynamic> state, int at) => [
  for (final l in _listings(state))
    if (l['status'] == 'live' && !listingExpired(l, at)) l,
];

void _seed(int seed) {
  seeded.setSeed(seed);
  final rng = JsMathRandom(seed * 7 + 1);
  setMergeRandom(rng);
  setTraitRandom(rng);
}

/// Opens the window punctually and runs it forward to [offset].
Map<String, dynamic> _openAndRun(int seed, int offset) {
  _seed(seed);
  final state = _state();
  startSession(state, _windowStart, nowMs: _windowStart, windowEnd: _windowEnd);
  tickSession(state, _windowStart + offset);
  return state;
}

void main() {
  setUp(() => setClock(() => _now));
  tearDown(() {
    resetClock();
    resetMergeRandom();
    resetTraitRandom();
    clearBus();
  });

  group('the schedule belongs to the window, not to you', () {
    test('joining late means the business already happened without you', () {
      // Anchoring to the player's arrival instead would have made the world wait
      // for them, which is the opposite of a deadline.
      _seed(11);
      final late = _state();
      startSession(
        late,
        _windowStart,
        nowMs: _windowStart + 1800000,
        windowEnd: _windowEnd,
      );
      // Half an hour of ninety-second slots have come due already — inclusive of
      // the one falling exactly on the half hour, hence the plus one.
      final spawned = _num(
        _map(_map(late['deadlineDay'])!['session'])!['spawned'],
      );
      expect(spawned, 1800000 ~/ listingIntervalMs + 1);
      // And nearly all of them are gone: the fuse is five minutes.
      expect(_allLive(late, _windowStart + 1800000).length, lessThan(5));
    });

    test('a session opened late still shuts when the window does', () {
      // A countdown that outlived the event it belongs to would be a lie, and it
      // would let a late opener trade past closing time.
      _seed(3);
      final state = _state();
      final joinAt = _windowEnd - 60000;
      final r = startSession(
        state,
        _windowStart,
        nowMs: joinAt,
        windowEnd: _windowEnd,
      );
      expect(r.ok, isTrue);
      expect(r.endsAt, _windowEnd);
      expect(sessionRemainingMs(state, joinAt), 60000);
    });

    test('backgrounding the app does not pause the window', () {
      // Come back three minutes late and you missed three minutes of business.
      final steady = _openAndRun(11, 900000);
      final jumped = _openAndRun(11, 900000);
      // One long jump and a walk in ninety-second steps land in the same place.
      _seed(11);
      final stepped = _state();
      startSession(
        stepped,
        _windowStart,
        nowMs: _windowStart,
        windowEnd: _windowEnd,
      );
      for (var t = 0; t <= 900000; t += listingIntervalMs) {
        tickSession(stepped, _windowStart + t);
      }
      expect(
        _listings(stepped).map((l) => l['listingId']),
        _listings(steady).map((l) => l['listingId']),
      );
      expect(
        _listings(jumped).map((l) => l['listingId']),
        _listings(steady).map((l) => l['listingId']),
      );
    });

    test('ticking is idempotent for a given instant', () {
      final state = _openAndRun(7, 600000);
      final before = jsonEncode(state['deadlineDay']);
      for (var i = 0; i < 5; i++) {
        tickSession(state, _windowStart + 600000);
      }
      expect(jsonEncode(state['deadlineDay']), before);
    });

    test('never spawns past the cap, or past closing time', () {
      final state = _openAndRun(3, sessionMs);
      final s = _map(_map(state['deadlineDay'])!['session'])!;
      expect(_num(s['spawned']), lessThanOrEqualTo(maxSpawns));
      for (final l in _listings(state)) {
        expect(_num(l['spawnAt']), lessThan(_windowEnd));
      }
    });
  });

  group('the board', () {
    test('a listing you are negotiating is never pushed off it', () {
      // Pausing is what makes a listing outlive its natural window, and four fit
      // inside a fuse at the normal cadence — exactly the cap. So an unpaused
      // listing is never evicted and a paused one always was: the reward for
      // negotiating used to be watching the deal vanish with no explanation.
      for (var seed = 0; seed < 20; seed++) {
        // The board is only ever exactly full at particular instants — a
        // five-minute fuse holds four ninety-second slots — so walk to one.
        for (
          var offset = listingIntervalMs * 4;
          offset < sessionMs ~/ 2;
          offset += listingIntervalMs
        ) {
          final state = _openAndRun(seed, offset);
          var at = _windowStart + offset;
          final live = liveListings(state, at);
          if (live.length < maxLiveListings) continue;

          // Engage the OLDEST thing on the board — the one about to be evicted.
          final oldest = live.last;
          expect(pauseListing(state, '${oldest['listingId']}', at), isTrue);

          // Roll on so more arrive and the paused one has outlived its own fuse.
          at += listingIntervalMs * 3;
          tickSession(state, at);
          if (_allLive(state, at).length <= maxLiveListings) continue;

          expect(
            liveListings(state, at).map((l) => l['listingId']),
            contains(oldest['listingId']),
            reason: 'seed $seed @ $offset — an engaged listing was evicted',
          );
          return;
        }
      }
      fail('no seed produced a full board with an engaged listing');
    });

    test('shows at most the display cap, newest first', () {
      final state = _openAndRun(11, 900000);
      final at = _windowStart + 900000;
      final board = liveListings(state, at);
      expect(board.length, lessThanOrEqualTo(maxLiveListings));
      for (var i = 1; i < board.length; i++) {
        expect(
          _num(board[i - 1]['spawnAt'])!,
          greaterThanOrEqualTo(_num(board[i]['spawnAt'])!),
        );
      }
    });

    test('splits by which side of the desk, not by transfer versus loan', () {
      // The question a manager is actually asking is "am I losing a player or
      // gaining one". A loan IN costs us and still counts as buying.
      expect(listingSide({'kind': 'bid'}), 'sell');
      expect(listingSide({'kind': 'loanOut'}), 'sell');
      expect(listingSide({'kind': 'signing'}), 'buy');
      expect(listingSide({'kind': 'loan'}), 'buy');
      expect(listingSide(null), 'buy');

      final state = _openAndRun(11, 900000);
      final at = _windowStart + 900000;
      final board = liveListings(state, at);
      expect(
        [
          ...liveListingsBySide(state, 'buy', at),
          ...liveListingsBySide(state, 'sell', at),
        ].length,
        board.length,
      );
    });
  });

  group('the clock stops while you are talking', () {
    test('but the reading does not stop it', () {
      // Tapping a card for details leaves the clock running — the pause is the
      // NEGOTIATION.
      final state = _openAndRun(11, 300000);
      final at = _windowStart + 300000;
      final l = liveListings(state, at).first;
      final before = listingRemainingMs(l, at);
      expect(listingRemainingMs(l, at + 30000), before - 30000);
    });

    test('the fuse picks up where it left off, not from the top', () {
      // Otherwise a long haggle could be used to farm time.
      final state = _openAndRun(11, 300000);
      var at = _windowStart + 300000;
      final l = liveListings(state, at).first;
      final id = '${l['listingId']}';
      final remaining = listingRemainingMs(l, at);

      expect(pauseListing(state, id, at), isTrue);
      // Frozen while paused, however long we think about it.
      expect(listingRemainingMs(l, at + 120000), remaining);
      expect(listingExpired(l, at + 999999), isFalse);

      at += 120000;
      expect(resumeListing(state, id, at), isTrue);
      expect(listingRemainingMs(l, at), remaining);
    });

    test('a pause is not re-banked by a second offer', () {
      final state = _openAndRun(11, 300000);
      final at = _windowStart + 300000;
      final id = '${liveListings(state, at).first['listingId']}';
      expect(pauseListing(state, id, at), isTrue);
      expect(pauseListing(state, id, at + 60000), isFalse);
      expect(resumeListing(state, id, at + 60000), isTrue);
      expect(resumeListing(state, id, at + 60000), isFalse);
    });

    test('time given back cannot outlive the window', () {
      // A negotiation that ran past closing time hands back time that no longer
      // exists.
      final state = _openAndRun(11, 300000);
      final id =
          '${liveListings(state, _windowStart + 300000).first['listingId']}';
      expect(pauseListing(state, id, _windowStart + 300000), isTrue);
      expect(resumeListing(state, id, _windowEnd + sessionMs), isTrue);
      final l = _listings(state).firstWhere((x) => x['listingId'] == id);
      expect(_num(l['expiresAt']), lessThanOrEqualTo(_windowEnd));
    });
  });

  group('the window closing', () {
    test('counts a deal you never answered as missed, not as nothing', () {
      // With a five-minute fuse that is most of the last five minutes of every
      // window, so closing out before counting is the difference between an
      // honest recap and a silent one.
      final state = _openAndRun(11, 300000);
      final liveAtClose = _allLive(state, _windowStart + 300000).length;
      expect(liveAtClose, greaterThan(0));

      final summary = endSession(state, _windowEnd)!;
      expect(_num(summary['missed']), greaterThanOrEqualTo(liveAtClose));
      for (final l in _listings(state)) {
        expect(l['status'], isNot('live'));
      }
    });

    test('reports what came ACROSS the desk, not just what was signed', () {
      // Forty offers and you took two is a different evening from two offers and
      // you took both, and the deals-done rows cannot tell them apart.
      final state = _openAndRun(3, sessionMs);
      final summary = endSession(state, _windowEnd)!;
      final offers = _map(summary['offers'])!;
      final total = offers.values.fold<num>(0, (a, b) => a + (_num(b) ?? 0));
      expect(total, _listings(state).length);
    });

    test('is idempotent, and banks the summary once', () {
      final state = _openAndRun(11, 600000);
      final first = endSession(state, _windowEnd);
      final again = endSession(state, _windowEnd + 5000);
      expect(again, same(first));
      expect((_map(state['deadlineDay'])!['history'] as List).length, 1);
    });

    test('a session that never opened has nothing to close', () {
      final state = _state();
      expect(endSession(state, _windowEnd), isNull);
      expect((_map(state['deadlineDay'])!['history'] as List), isEmpty);
    });

    test('the ledger adds up', () {
      final state = _openAndRun(11, 600000);
      final summary = endSession(state, _windowEnd)!;
      expect(
        _num(summary['net']),
        _num(summary['income'])! - _num(summary['spend'])!,
      );
    });
  });

  group('the squad is protected', () {
    test('a bid never strips it below a fieldable core', () {
      // A deadline-day frenzy must not leave you unable to field a side.
      for (var seed = 0; seed < 12; seed++) {
        _seed(seed);
        final state = _state();
        final cells = (state['grid'] as Map)['cells'] as List;
        for (var i = minHealthyKeep; i < cells.length; i++) {
          cells[i] = null;
        }
        startSession(
          state,
          _windowStart,
          nowMs: _windowStart,
          windowEnd: _windowEnd,
        );
        tickSession(state, _windowStart + 900000);
        expect(
          _listings(state).where((l) => l['kind'] == 'bid'),
          isEmpty,
          reason: 'seed $seed',
        );
      }
    });

    test('two clubs never chase the same player at once', () {
      // Two bids for one man in the same window reads as a bug, not a bidding war.
      for (var seed = 0; seed < 20; seed++) {
        final state = _openAndRun(seed, 600000);
        final at = _windowStart + 600000;
        for (final kind in ['bid', 'loanOut']) {
          final ids = [
            for (final l in _allLive(state, at))
              if (l['kind'] == kind) l['cardInstanceId'],
          ];
          expect(ids.toSet().length, ids.length, reason: '$kind / seed $seed');
        }
      }
    });

    test('a bid dies when its player leaves the grid another way', () {
      for (var seed = 0; seed < 30; seed++) {
        final state = _openAndRun(seed, 400000);
        var at = _windowStart + 400000;
        final bid = _allLive(state, at).cast<Listing?>().firstWhere(
          (l) => l!['kind'] == 'bid',
          orElse: () => null,
        );
        if (bid == null) continue;

        // Sold on the Squad screen, or merged away.
        final cells = (state['grid'] as Map)['cells'] as List;
        final idx = cells.indexWhere(
          (c) => _map(c)?['instanceId'] == bid['cardInstanceId'],
        );
        cells[idx] = null;

        at += 1000;
        tickSession(state, at);
        expect(bid['status'], 'void', reason: 'seed $seed');
        expect(acceptListing(state, '${bid['listingId']}', at)['ok'], isFalse);
        return;
      }
      fail('no seed produced a live bid');
    });
  });

  group('the marquee', () {
    test('never the opening listing, and never more than one', () {
      for (var seed = 0; seed < 25; seed++) {
        final state = _openAndRun(seed, sessionMs);
        final marquees = [
          for (final l in _listings(state))
            if (l['marquee'] == true) l,
        ];
        expect(
          marquees.length,
          lessThanOrEqualTo(maxMarquee),
          reason: 'seed $seed',
        );
        for (final m in marquees) {
          final index =
              ((_num(m['spawnAt'])! - _windowStart) / listingIntervalMs)
                  .round();
          expect(
            index,
            greaterThanOrEqualTo(marqueeMinIndex),
            reason: 'seed $seed',
          );
          expect(
            index,
            lessThanOrEqualTo(marqueeMaxIndex),
            reason: 'seed $seed',
          );
        }
      }
    });

    test(
      'is the only route above the division ceiling, and never reaches T9',
      () {
        for (var seed = 0; seed < 25; seed++) {
          final state = _openAndRun(seed, sessionMs);
          for (final l in _listings(state)) {
            expect(
              _num(l['tier']),
              lessThanOrEqualTo(maxMarketTier),
              reason: 'seed $seed — T9 is scout-only',
            );
          }
        }
      },
    );
  });

  group('everything here is save state', () {
    test('a whole driven session encodes as JSON', () {
      // The session and its listings live in the save, so anything on one that
      // cannot be encoded throws on the first save after the window.
      for (var seed = 0; seed < 10; seed++) {
        final state = _openAndRun(seed, 600000);
        var at = _windowStart + 600000;
        for (final l in List<Listing>.of(_allLive(state, at))) {
          final id = '${l['listingId']}';
          switch (l['kind']) {
            case 'bid':
              askForMore(state, id, (_num(l['price'])! * 1.2).round(), at);
            case 'signing':
              submitOffer(state, id, {
                'cash': (_num(l['price'])! * 0.9).round(),
                'players': <Object?>[],
              }, at);
            default:
              acceptListing(state, id, at);
          }
        }
        at = _windowEnd;
        endSession(state, at);
        expect(() => jsonEncode(state), returnsNormally, reason: 'seed $seed');
      }
    });
  });

  group('gates', () {
    test('selling is never blocked', () {
      for (var seed = 0; seed < 20; seed++) {
        final state = _openAndRun(seed, 600000);
        for (final l in _allLive(state, _windowStart + 600000)) {
          if (l['kind'] != 'bid') continue;
          expect(listingBlockedReason(state, l), isNull, reason: 'seed $seed');
        }
      }
    });

    test('a broke club cannot buy, but can still be bid at', () {
      _seed(11);
      final state = _state(fanCoins: 0);
      startSession(
        state,
        _windowStart,
        nowMs: _windowStart,
        windowEnd: _windowEnd,
      );
      tickSession(state, _windowStart + 900000);
      for (final l in _allLive(state, _windowStart + 900000)) {
        final blocked = listingBlockedReason(state, l);
        if (l['kind'] == 'signing' || l['kind'] == 'loan') {
          expect(blocked, 'not_enough_coins', reason: '${l['kind']}');
        }
      }
    });

    test('a loanOut is gated on the player, not on the signing gate', () {
      // This used to fall through to the signing gate, which rejects anything that
      // is not a signing — so every loanOut card carried a permanent
      // `not_signing`, a reason with no string behind it.
      for (var seed = 0; seed < 30; seed++) {
        final state = _openAndRun(seed, 600000);
        final out = _allLive(state, _windowStart + 600000)
            .cast<Listing?>()
            .firstWhere((l) => l!['kind'] == 'loanOut', orElse: () => null);
        if (out == null) continue;
        expect(listingBlockedReason(state, out), isNot('not_signing'));
        return;
      }
      fail('no seed produced a live loanOut');
    });

    test('an unknown or dead listing cannot be acted on', () {
      final state = _openAndRun(11, 600000);
      final at = _windowStart + 600000;
      expect(acceptListing(state, 'nope', at)['reason'], 'unknown_listing');
      expect(askForMore(state, 'nope', 1, at)['reason'], 'unknown_listing');
      expect(
        submitOffer(state, 'nope', {'cash': 1}, at)['reason'],
        'unknown_listing',
      );
      expect(dismissListing(state, 'nope')['reason'], 'unknown_listing');
      expect(
        acceptSellerCounter(state, 'nope', at)['reason'],
        'unknown_listing',
      );

      final id = '${liveListings(state, at).first['listingId']}';
      dismissListing(state, id);
      expect(acceptListing(state, id, at)['reason'], 'not_live');
    });

    test('every action reads the clock when it is not given one', () {
      // The no-argument forms are what the UI actually calls; the tests pass an
      // explicit instant everywhere else.
      setClock(() => _windowStart);
      _seed(11);
      final state = _state();
      startSession(state, _windowStart, windowEnd: _windowEnd);
      setClock(() => _windowStart + 600000);
      tickSession(state);
      expect(sessionRemainingMs(state), sessionMs - 600000);
      expect(sessionStatus(state, _windowStart), 'live');
      final id = '${liveListings(state).first['listingId']}';
      expect(listingRemainingMs(liveListings(state).first), greaterThan(0));
      expect(liveListingsBySide(state, 'buy'), isNotNull);
      expect(pauseListing(state, id), isTrue);
      expect(resumeListing(state, id), isTrue);
      expect(acceptListing(state, 'nope')['reason'], 'unknown_listing');
      expect(askForMore(state, 'nope', 1)['reason'], 'unknown_listing');
      expect(
        submitOffer(state, 'nope', {'cash': 1})['reason'],
        'unknown_listing',
      );
      expect(acceptSellerCounter(state, 'nope')['reason'], 'unknown_listing');
      setClock(() => _windowEnd);
      expect(endSession(state), isNotNull);
    });

    test('a window nobody opened is idle, and a used one is done', () {
      final state = _state();
      expect(sessionStatus(state, _windowStart), 'idle');
      _seed(11);
      startSession(
        state,
        _windowStart,
        nowMs: _windowStart,
        windowEnd: _windowEnd,
      );
      endSession(state, _windowEnd);
      expect(sessionStatus(state, _windowStart), 'done');
      // A different occurrence is still untouched.
      expect(sessionStatus(state, _windowEnd), 'idle');
    });

    test('acting on an expired listing marks it expired and refuses', () {
      // The fuse is the fuse: a listing whose time ran out while the sheet sat
      // open cannot be accepted, haggled or offered on.
      for (final action in ['accept', 'askForMore', 'submitOffer', 'counter']) {
        final state = _openAndRun(11, 300000);
        final at = _windowStart + 300000;
        final wantKind = action == 'askForMore' ? 'bid' : 'signing';
        final target = _allLive(state, at).cast<Listing?>().firstWhere(
          (l) => l!['kind'] == wantKind,
          orElse: () => null,
        );
        if (target == null) continue;
        final id = '${target['listingId']}';
        // Past its fuse, but before the window shuts, so the session is still live.
        final late = (_num(target['expiresAt'])! + 1).toInt();

        final res = switch (action) {
          'accept' => acceptListing(state, id, late),
          'askForMore' => askForMore(state, id, 1, late),
          'submitOffer' => submitOffer(state, id, {'cash': 1}, late),
          _ => (() {
            target['sellerCounter'] = {
              'price': 1,
              'offer': <String, dynamic>{},
            };
            return acceptSellerCounter(state, id, late);
          })(),
        };
        expect(res['reason'], 'expired', reason: action);
        expect(target['status'], 'expired', reason: action);
      }
    });

    test('a counter cannot be taken when it was never made', () {
      final state = _openAndRun(11, 300000);
      final at = _windowStart + 300000;
      final id = '${liveListings(state, at).first['listingId']}';
      expect(acceptSellerCounter(state, id, at)['reason'], 'no_counter');
    });

    test('a counter we cannot cover reports what it would take', () {
      for (var seed = 0; seed < 40; seed++) {
        final state = _openAndRun(seed, 600000);
        final at = _windowStart + 600000;
        final target = _allLive(state, at).cast<Listing?>().firstWhere(
          (l) => l!['kind'] == 'signing' && (_num(l['haggleRounds']) ?? 0) > 0,
          orElse: () => null,
        );
        if (target == null) continue;
        final id = '${target['listingId']}';
        final res = submitOffer(state, id, {
          'cash': (_num(target['price'])! * 0.9).round(),
          'players': <Object?>[],
        }, at);
        if (res['reason'] != 'counter') continue;

        // Spend the money before taking their number.
        (state['resources'] as Map)['fanCoins'] = 0;
        final taken = acceptSellerCounter(state, id, at);
        expect(taken['ok'], isFalse);
        expect(taken['reason'], 'not_enough_coins');
        expect(_num(taken['cashNeeded']), greaterThan(0));
        return;
      }
      fail('no seed produced a seller counter');
    });

    test('there is no counter to read until they have made one', () {
      final state = _openAndRun(11, 300000);
      final at = _windowStart + 300000;
      final id = '${liveListings(state, at).first['listingId']}';
      expect(sellerCounter(state, id), isNull);
      expect(sellerCounter(state, 'nope'), isNull);
    });

    test('the counter reads the same cash the accept charges', () {
      // The button that offers to take a counter has to name the figure BEFORE
      // the money moves, and the only other way to get it is to write the
      // subtraction out again in the UI. This is the claim that stops that: the
      // peek and the charge are the same arithmetic.
      for (var seed = 0; seed < 40; seed++) {
        final state = _openAndRun(seed, 600000);
        final at = _windowStart + 600000;
        final target = _allLive(state, at).cast<Listing?>().firstWhere(
          (l) => l!['kind'] == 'signing' && (_num(l['haggleRounds']) ?? 0) > 0,
          orElse: () => null,
        );
        if (target == null) continue;
        final id = '${target['listingId']}';
        final res = submitOffer(state, id, {
          'cash': (_num(target['price'])! * 0.9).round(),
          'players': <Object?>[],
        }, at);
        if (res['reason'] != 'counter') continue;

        final peek = sellerCounter(state, id)!;
        // Nothing but cash was on the table, so their total IS our cash.
        expect(peek.price, _num(res['counterPrice']), reason: 'seed $seed');
        expect(peek.cash, peek.price, reason: 'seed $seed');

        final coinsBefore = _num(_map(state['resources'])!['fanCoins'])!;
        final taken = acceptSellerCounter(state, id, at);
        expect(taken['ok'], isTrue, reason: 'seed $seed');
        expect(taken['paid'], peek.cash, reason: 'seed $seed');
        expect(
          _num(_map(state['resources'])!['fanCoins']),
          coinsBefore - peek.cash,
          reason: 'seed $seed',
        );
        return;
      }
      fail('no seed produced a seller counter');
    });

    test('players already on the table are paid off their number, not ours', () {
      // Their figure is a TOTAL. A button offering to "pay" it would ask for
      // coins the deal never wanted, because the swap already agreed covers part
      // of it — so the peek's cash has to come off the total, and it is the
      // figure the accept then charges.
      for (var seed = 0; seed < 60; seed++) {
        final state = _openAndRun(seed, 600000);
        final at = _windowStart + 600000;
        for (final l in _allLive(state, at)) {
          if (l['kind'] != 'signing') continue;
          if ((_num(l['haggleRounds']) ?? 0) <= 0) continue;

          // The cheapest of ours, so the player is a make-weight rather than the
          // whole fee: a big enough name simply buys the deal outright and there
          // is no counter to read.
          final ours = ((state['grid'] as Map)['cells'] as List)
              .whereType<Map<String, dynamic>>()
              .where(
                (c) => c['loanMatchesLeft'] == null && c['injured'] != true,
              )
              .toList();
          if (ours.isEmpty) continue;
          ours.sort(
            (a, b) =>
                playerValue(
                  state,
                  findOurCard(state, '${a['instanceId']}'),
                ).compareTo(
                  playerValue(state, findOurCard(state, '${b['instanceId']}')),
                ),
          );
          final makeWeight = '${ours.first['instanceId']}';
          final worth = playerValue(state, findOurCard(state, makeWeight));
          final price = _num(l['price'])!;
          // Short enough to be countered, close enough not to insult them.
          final cash = (price * 0.9 - worth).round();
          if (cash < 0) continue;

          final id = '${l['listingId']}';
          final res = submitOffer(state, id, {
            'cash': cash,
            'players': [makeWeight],
          }, at);
          if (res['reason'] != 'counter') continue;

          final peek = sellerCounter(state, id)!;
          expect(peek.price, _num(res['counterPrice']), reason: 'seed $seed');
          // The make-weight's worth is exactly what we do NOT pay in cash.
          expect(peek.cash, peek.price - worth, reason: 'seed $seed');

          final coinsBefore = _num(_map(state['resources'])!['fanCoins'])!;
          final taken = acceptSellerCounter(state, id, at);
          expect(taken['ok'], isTrue, reason: 'seed $seed');
          expect(taken['agreed'], peek.price, reason: 'seed $seed');
          expect(taken['paid'], peek.cash, reason: 'seed $seed');
          expect(
            _num(_map(state['resources'])!['fanCoins']),
            coinsBefore - peek.cash,
            reason: 'seed $seed',
          );
          return;
        }
      }
      fail('no seed produced a counter with players on the table');
    });

    test('a swap puts their players on our grid, and only the cash is money', () {
      // Done after freeing the sold player's cell, so a swap never fails for want
      // of a slot — and offering more than we can house was a quiet robbery.
      for (var seed = 0; seed < 60; seed++) {
        final state = _openAndRun(seed, 600000);
        final at = _windowStart + 600000;
        final bid = _allLive(state, at).cast<Listing?>().firstWhere(
          (l) =>
              l!['kind'] == 'bid' &&
              ((_map(l['offer'])?['incoming'] as List?)?.isNotEmpty ?? false),
          orElse: () => null,
        );
        if (bid == null) continue;

        final coinsBefore = _num(_map(state['resources'])!['fanCoins'])!;
        final incoming = (_map(bid['offer'])!['incoming'] as List).length;
        final occupiedBefore = ((state['grid'] as Map)['cells'] as List)
            .whereType<Map<String, dynamic>>()
            .length;

        final res = acceptListing(state, '${bid['listingId']}', at);
        expect(res['ok'], isTrue, reason: 'seed $seed');
        expect((res['arrived'] as List).length, incoming, reason: 'seed $seed');
        // One out, `incoming` in.
        expect(
          ((state['grid'] as Map)['cells'] as List)
              .whereType<Map<String, dynamic>>()
              .length,
          occupiedBefore - 1 + incoming,
          reason: 'seed $seed',
        );
        // Only the CASH part is money — the players arrived on the grid.
        expect(
          _num(_map(state['resources'])!['fanCoins']),
          coinsBefore + _num(res['cash'])!,
          reason: 'seed $seed',
        );
        return;
      }
      fail('no seed produced a bid with players in it');
    });

    test('a loan can be bought by offering, not just at the sticker price', () {
      for (var seed = 0; seed < 60; seed++) {
        final state = _openAndRun(seed, 600000);
        final at = _windowStart + 600000;
        final loan = _allLive(state, at).cast<Listing?>().firstWhere(
          (l) => l!['kind'] == 'loan',
          orElse: () => null,
        );
        if (loan == null) continue;
        final res = submitOffer(state, '${loan['listingId']}', {
          // Over the asking price, so no seller has a reason to refuse.
          'cash': (_num(loan['price'])! * 1.2).round(),
          'players': <Object?>[],
        }, at);
        if (res['ok'] != true) continue;
        expect(res['kind'], 'loan', reason: 'seed $seed');
        expect(loan['status'], 'accepted', reason: 'seed $seed');
        return;
      }
      fail('no seed let a loan be bought by offer');
    });

    test('a bid whose player vanished mid-accept reports card_gone', () {
      for (var seed = 0; seed < 30; seed++) {
        final state = _openAndRun(seed, 400000);
        final at = _windowStart + 400000;
        final bid = _allLive(state, at).cast<Listing?>().firstWhere(
          (l) => l!['kind'] == 'bid',
          orElse: () => null,
        );
        if (bid == null) continue;
        // Gone without a tick in between, so the accept path is what notices.
        final cells = (state['grid'] as Map)['cells'] as List;
        cells[cells.indexWhere(
              (c) => _map(c)?['instanceId'] == bid['cardInstanceId'],
            )] =
            null;
        final res = acceptListing(state, '${bid['listingId']}', at);
        expect(res['reason'], 'card_gone', reason: 'seed $seed');
        expect(bid['status'], 'void', reason: 'seed $seed');
        return;
      }
      fail('no seed produced a live bid');
    });

    test('an aging player is worth less to a rival', () {
      // The same discount a sale takes: a veteran fetches less.
      int bidPriceFor(int seasons) {
        for (var seed = 0; seed < 60; seed++) {
          _seed(seed);
          final state = _state();
          for (final c in (state['grid'] as Map)['cells'] as List) {
            if (c is Map) c['seasonsPlayed'] = seasons;
          }
          startSession(
            state,
            _windowStart,
            nowMs: _windowStart,
            windowEnd: _windowEnd,
          );
          tickSession(state, _windowStart + 900000);
          final bid = _listings(state).cast<Listing?>().firstWhere(
            (l) => l!['kind'] == 'bid',
            orElse: () => null,
          );
          if (bid != null) return _num(bid['price'])!.toInt();
        }
        fail('no bid at $seasons seasons');
      }

      expect(bidPriceFor(14), lessThan(bidPriceFor(0)));
    });

    test('a bid is not an offer, and a signing is not a haggle', () {
      final state = _openAndRun(11, 600000);
      final at = _windowStart + 600000;
      for (final l in _allLive(state, at)) {
        final id = '${l['listingId']}';
        if (l['kind'] == 'bid') {
          expect(
            submitOffer(state, id, {'cash': 1}, at)['reason'],
            'not_negotiable',
          );
        } else if (l['kind'] == 'signing' || l['kind'] == 'loan') {
          expect(askForMore(state, id, 1, at)['reason'], 'not_negotiable');
        }
      }
    });
  });

  group('the card that arrives', () {
    /// Sign the first signing on the board, and hand back the listing and the
    /// card that landed on the grid.
    ({Listing listing, Map<String, dynamic> card})? signOne(int seed) {
      final state = _openAndRun(seed, 600000);
      final at = _windowStart + 600000;
      for (final l in _allLive(state, at)) {
        if (l['kind'] != 'signing') continue;
        if (_map(l['card']) == null) continue;
        final res = acceptListing(state, '${l['listingId']}', at);
        if (res['ok'] != true) continue;
        final cells = _map(state['grid'])!['cells'] as List;
        final landed = cells.whereType<Map<String, dynamic>>().firstWhere(
          (c) => c['instanceId'] == l['signedInstanceId'],
        );
        return (listing: l, card: landed);
      }
      // Not every seed's feed puts a signable signing on the board — the
      // squad fills up, or the window runs to bids and loans. Skipped rather
      // than failed, with the caller insisting on a quorum.
      return null;
    }

    test('IS THE CARD THE FEED SHOWED, not a fresh roll of the same name', () {
      // The pre-roll exists precisely so "the portrait, the rating and the stat
      // split on the offer are exactly what lands on your grid" — and the JS
      // then rolled a new instance and copied only the name across, which is
      // the JS contradicting its own comment. Fixed deliberately; see the note
      // in `_acceptSigning`.
      var checked = 0;
      for (var seed = 0; seed < 12; seed++) {
        final signed = signOne(seed);
        if (signed == null) continue;
        checked++;
        final offered = _map(signed.listing['card'])!;
        for (final key in [
          'definitionId',
          'variant',
          'ratingBonus',
          'attackRatio',
          'displayName',
        ]) {
          expect(signed.card[key], offered[key], reason: 'seed \$seed: \$key');
        }
        // The trait is the one a fresh roll dropped entirely: a card advertised
        // with one arrived without it.
        expect(
          jsonEncode(signed.card['trait']),
          jsonEncode(offered['trait']),
          reason: 'seed \$seed: trait',
        );
      }
      expect(checked, greaterThan(2), reason: 'nothing was actually signed');
    });

    test('and it is a COPY, so the grid cannot rewrite the deal', () {
      // The listing is the record of what was offered. Sharing one map would
      // let the signed player levelling up retro-edit the offer that was made.
      final signed = [
        for (var seed = 0; seed < 12; seed++) signOne(seed),
      ].nonNulls.first;
      expect(identical(signed.card, signed.listing['card']), isFalse);
      signed.card['ratingBonus'] = 99;
      expect(_map(signed.listing['card'])!['ratingBonus'], isNot(99));
    });

    test('THE ROLL IS STILL SPENT, so the rest of the session is unchanged', () {
      // The JS's position in the merge RNG stream is part of the spec and every
      // later card depends on it. Skipping the draw would quietly change the
      // whole remainder of the feed — so it is taken and thrown away. Two runs
      // of the same seed, one signing and one dismissing, must leave the stream
      // in the same place.
      List<String> tailAfter(bool sign) {
        final state = _openAndRun(5, 600000);
        final at = _windowStart + 600000;
        for (final l in _allLive(state, at)) {
          if (l['kind'] != 'signing' || _map(l['card']) == null) continue;
          if (sign) {
            acceptListing(state, '${l['listingId']}', at);
          }
          break;
        }
        // Whatever the feed rolls next is what the stream position decides.
        tickSession(state, _windowStart + 900000);
        return [
          for (final l in _listings(state))
            if (_map(l['card']) != null)
              '${_map(l['card'])!['definitionId']}'
                  '/${_map(l['card'])!['variant']}',
        ];
      }

      expect(tailAfter(true), tailAfter(false));
    });
  });
}
