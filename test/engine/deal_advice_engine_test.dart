/// Coach Colin's read on a Deadline Day listing, against the JS it was ported
/// from.
///
/// Nothing here draws a random number. What it pins is a lattice of judgements
/// reading the same squad from different angles — a price band against fair
/// value, whether the player would get in the side, whether the position is bare
/// or already glutted — and the CAPS, which are the part a port gets wrong. A
/// cap applied as a demotion instead prints "worth doing" over "we're already
/// well stocked", which is two halves of one sentence arguing with each other.
///
/// The reference builds every price from `playerValue` at generation time, and
/// ships the listing it judged, so both runtimes score the identical deal.
///
/// See `tool/dump_deal_advice_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/deal_advice_engine.dart';
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/deal_advice_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

final Map<String, dynamic> _questRef =
    jsonDecode(
          File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

/// The JS reported a verdict as a plain string.
const _verdictNames = {
  DealVerdict.blocked: 'blocked',
  DealVerdict.poor: 'poor',
  DealVerdict.fair: 'fair',
  DealVerdict.good: 'good',
  DealVerdict.great: 'great',
  DealVerdict.tempting: 'tempting',
};

Map<String, dynamic> _card(String definitionId, String instanceId) => {
  'instanceId': instanceId,
  'definitionId': definitionId,
  'seasonsPlayed': 0,
};

/// A squad built to order, matching the dump script's builder: position to how
/// many, all at tier 3.
List<dynamic> _squad(Map<String, dynamic> spec, {int size = 15}) {
  final cells = <dynamic>[];
  var n = 0;
  for (final entry in spec.entries) {
    for (var i = 0; i < (entry.value as num); i++) {
      cells.add(_card('player_t3_${entry.key}', 's${n++}'));
    }
  }
  while (cells.length < size) {
    cells.add(null);
  }
  return cells;
}

/// The reference save, with the branches the advice reads.
Map<String, dynamic> _state({
  num coins = 5000000,
  List<dynamic>? cells,
  String division = 'regional_league',
}) {
  final s = jsonDecode(jsonEncode(_questRef['state'])) as Map<String, dynamic>;
  (s['resources'] as Map)['fanCoins'] = coins;
  (s['progression'] as Map)['currentDivision'] = division;
  if (cells != null) (s['grid'] as Map)['cells'] = cells;
  return s;
}

/// The state one reference row was judged against.
Map<String, dynamic> _stateFor(Map<String, dynamic> row) => _state(
  coins: (row['coins'] as num?) ?? 5000000,
  cells: _squad(
    row['spec'] as Map<String, dynamic>,
    size: (row['size'] as int?) ?? 15,
  ),
);

void _expectAdvice(
  DealAdvice got,
  Map<String, dynamic> want, {
  required String reason,
}) {
  expect(
    _verdictNames[got.verdict],
    want['verdict'],
    reason: '$reason verdict',
  );
  expect(
    [
      for (final r in got.reasons) {'id': r.id, 'params': r.params},
    ],
    want['reasons'],
    reason: '$reason reasons',
  );
  expect(got.suggestedAsk, want['suggestedAsk'], reason: '$reason ask');
  expect(got.suggestedOffer, want['suggestedOffer'], reason: '$reason offer');
}

void main() {
  setUp(() => setClock(() => 1700000000000));
  tearDown(resetClock);

  test('the thresholds match the JS', () {
    final want = _ref['constants'] as Map<String, dynamic>;
    expect(grindGames, want['grindGames']);
    expect(grindPayoutMult, want['grindPayoutMult']);
    expect(overOdds, want['overOdds']);
    expect(lowball, want['lowball']);
    expect(glutAt, want['glutAt']);
    expect(meaningful, want['meaningful']);
    expect(coverAt, want['coverAt']);
  });

  test('parity — the two rules of thumb', () {
    for (final row in _rows('suggested')) {
      final listing = row['listing'] as Map<String, dynamic>;
      expect(suggestedAskFor(listing), row['ask'], reason: 'ask for $listing');
      expect(
        suggestedOfferFor(listing),
        row['offer'],
        reason: 'offer for $listing',
      );
    }
    final want = _ref['suggestedNull'] as Map<String, dynamic>;
    expect(suggestedAskFor(null), want['ask']);
    expect(suggestedOfferFor(null), want['offer']);
  });

  test('parity — buying', () {
    for (final row in _rows('buy')) {
      _expectAdvice(
        adviseOnListing(_stateFor(row), row['listing'] as Map<String, dynamic>),
        row['advice'] as Map<String, dynamic>,
        reason: '${row['label']}',
      );
    }
  });

  test('parity — blocked, and what Colin says next', () {
    for (final row in _rows('blocked')) {
      _expectAdvice(
        adviseOnListing(_stateFor(row), row['listing'] as Map<String, dynamic>),
        row['advice'] as Map<String, dynamic>,
        reason: '${row['label']}',
      );
    }
  });

  test('parity — selling', () {
    for (final row in _rows('sell')) {
      _expectAdvice(
        adviseOnListing(
          _state(cells: _squad(row['spec'] as Map<String, dynamic>)),
          row['listing'] as Map<String, dynamic>,
        ),
        row['advice'] as Map<String, dynamic>,
        reason: '${row['label']}',
      );
    }
  });

  test('parity — selling the best player we have', () {
    // Never an unqualified "take it", however good the money: "strong deal, I'd
    // take it" and "he's the best we've got" in the same breath is not advice,
    // it is two facts contradicting each other.
    for (final row in _rows('sellBest')) {
      final cells = _squad({'fwd': 2, 'mid': 3, 'def': 3, 'gk': 1});
      cells[0] = _card('player_t8_fwd', 'star');
      _expectAdvice(
        adviseOnListing(
          _state(cells: cells),
          row['listing'] as Map<String, dynamic>,
        ),
        row['advice'] as Map<String, dynamic>,
        reason: 'at ${row['mult']}× fair value',
      );
    }
  });

  test('parity — an equal twin makes him replaceable', () {
    // The comparison excludes the man being sold, which is the whole point: one
    // of three identical forwards is not irreplaceable, and counting him against
    // himself meant no ordinary squad player could be sold without a warning.
    final want = _ref['sellTwin'] as Map<String, dynamic>;
    final cells = _squad({'fwd': 2, 'mid': 3, 'def': 3, 'gk': 1});
    cells[0] = _card('player_t8_fwd', 'twinA');
    cells[1] = _card('player_t8_fwd', 'twinB');
    _expectAdvice(
      adviseOnListing(
        _state(cells: cells),
        want['listing'] as Map<String, dynamic>,
      ),
      want['advice'] as Map<String, dynamic>,
      reason: 'twin',
    );
  });

  test('parity — the guards', () {
    final want = _ref['guards'] as Map<String, dynamic>;
    _expectAdvice(
      adviseOnListing(null, {'kind': 'signing', 'price': 1}),
      want['noState'] as Map<String, dynamic>,
      reason: 'noState',
    );
    _expectAdvice(
      adviseOnListing(_state(), null),
      want['noListing'] as Map<String, dynamic>,
      reason: 'noListing',
    );
    _expectAdvice(
      adviseOnListing(null, null),
      want['neither'] as Map<String, dynamic>,
      reason: 'neither',
    );
  });

  group('the caps', () {
    // A cap can only lower a verdict, which is what stops a reason and a
    // verdict contradicting each other.
    test('a glut caps a bargain at "your call" rather than demoting it', () {
      final bargain = _rows(
        'buy',
      ).firstWhere((r) => r['label'] == 'glutBargain');
      final priced = _rows(
        'buy',
      ).firstWhere((r) => r['label'] == 'glutOverpriced');
      final a = adviseOnListing(
        _stateFor(bargain),
        bargain['listing'] as Map<String, dynamic>,
      );
      final b = adviseOnListing(
        _stateFor(priced),
        priced['listing'] as Map<String, dynamic>,
      );
      // A bargain is pulled down to fair; an overpriced one is already below
      // the cap and stays where it is.
      expect(a.verdict, DealVerdict.fair);
      expect(b.verdict, DealVerdict.poor);
      expect(a.reasons.map((r) => r.id), contains('glut_buy'));
      expect(b.reasons.map((r) => r.id), contains('glut_buy'));
    });

    test('cover is your call, never an endorsement', () {
      final row = _rows('buy').firstWhere((r) => r['label'] == 'needsCover');
      final advice = adviseOnListing(
        _stateFor(row),
        row['listing'] as Map<String, dynamic>,
      );
      expect(advice.verdict, DealVerdict.fair);
      expect(advice.reasons.map((r) => r.id), contains('bargain'));
      expect(advice.reasons.map((r) => r.id), contains('needs_cover'));
    });

    test(
      'a bargain on someone who cannot get in the side is not a bargain',
      () {
        final row = _rows(
          'buy',
        ).firstWhere((r) => r['label'] == 'belowStandard');
        final advice = adviseOnListing(
          _stateFor(row),
          row['listing'] as Map<String, dynamic>,
        );
        expect(advice.verdict, DealVerdict.poor);
      },
    );
  });

  test('a number is only offered where one can be named', () {
    // Saying "too dear" and stopping there tells the player the problem and
    // withholds the move, which is the one thing a coach is for. But a bid is
    // not haggleable, so there is no number to give.
    for (final row in _rows('buy')) {
      final advice = adviseOnListing(
        _stateFor(row),
        row['listing'] as Map<String, dynamic>,
      );
      final overpriced = advice.reasons.any((r) => r.id == 'overpriced');
      final haggleable = row['kind'] == 'signing' || row['kind'] == 'loan';
      expect(
        advice.suggestedOffer > 0,
        overpriced && haggleable,
        reason: '${row['label']}',
      );
    }
  });

  test('blocked always leads with the engine\'s own reason', () {
    // The advice can never contradict the button being disabled.
    for (final row in _rows('blocked')) {
      final advice = adviseOnListing(
        _stateFor(row),
        row['listing'] as Map<String, dynamic>,
      );
      expect(advice.verdict, DealVerdict.blocked, reason: '${row['label']}');
      expect(
        advice.reasons.first.id,
        startsWith('blocked_'),
        reason: '${row['label']}',
      );
    }
  });
}
