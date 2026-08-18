/// The Deadline Day news ticker, against the JS it was ported from.
///
/// The strip is rebuilt on every League re-render, so the whole feature depends
/// on being deterministic: the same state at the same instant has to produce the
/// same three lines, or the rumours reshuffle under the player's eyes mid-read.
/// Everything comes off a stream seeded on the window, or on an hour bucket
/// through the build-up, and the draw ORDER is what a port gets wrong — the
/// outsider-name pass alone takes forty-eight numbers before a single rumour is
/// picked.
///
/// See `tool/dump_deadline_news_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/deadline_news_engine.dart';
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/deadline_news_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

final int _fixedNow = _ref['fixedNow'] as int;
final int _windowStart = _ref['windowStart'] as int;
const int _hour = 60 * 60 * 1000;

/// The JS reported the phase as a plain string.
const _phaseNames = {
  NewsPhase.buildup: 'buildup',
  NewsPhase.live: 'live',
  NewsPhase.aftermath: 'aftermath',
};

List<Map<String, dynamic>> _asJson(List<NewsLine> lines) => [
  for (final l in lines) {'key': l.key, 'params': l.params},
];

/// One listing the ticker can read, matching the dump script's builder.
Map<String, dynamic> _listing([Map<String, dynamic> over = const {}]) => {
  'listingId': 'dd_a',
  'kind': 'signing',
  'status': 'live',
  'marquee': false,
  'playerName': 'Ada Striker',
  'fromTeam': 'Northern Legion FC',
  'price': 12500,
  'matches': 0,
  'spawnAt': _windowStart,
  'expiresAt': _fixedNow + 5 * 60 * 1000,
  ...over,
};

Map<String, dynamic> _liveSession(
  List<Map<String, dynamic>> listings, [
  Map<String, dynamic> over = const {},
]) => {
  'startedAt': _windowStart,
  'windowStart': _windowStart,
  'done': false,
  'listings': listings,
  ...over,
};

Map<String, dynamic> _banked([Map<String, dynamic> over = const {}]) => {
  'windowStart': _windowStart,
  'endedAt': _windowStart + _hour,
  'signings': 0,
  'sales': 0,
  'loans': 0,
  'loanOuts': 0,
  'missed': 0,
  ...over,
};

Map<String, dynamic> _state({
  Map<String, dynamic>? session,
  List<Map<String, dynamic>> history = const [],
  bool squad = true,
  bool pyramid = true,
  bool opponents = true,
}) => {
  'clubName': 'Player Rovers',
  'grid': <String, dynamic>{
    'cells': squad
        ? <dynamic>[
            {'definitionId': 'player_t3_fwd', 'displayName': 'Rico Blaze'},
            {'definitionId': 'player_t3_mid', 'displayName': 'Milo Pivot'},
            null,
            {'definitionId': 'player_t2_def', 'customName': 'The Wall'},
          ]
        : <dynamic>[null, null],
  },
  'progression': <String, dynamic>{
    'currentDivision': 'regional_league',
    'seasonOpponents': opponents
        ? <dynamic>['Fallback Rovers', 'Fallback City']
        : <dynamic>[],
    if (pyramid)
      'leaguePyramid': <String, dynamic>{
        for (final d in divisions)
          d.id: [
            for (var i = 0; i < 8; i++) {'name': '${d.id} FC $i'},
          ],
      },
  },
  'deadlineDay': <String, dynamic>{
    'session':
        session ??
        <String, dynamic>{
          'startedAt': 0,
          'windowStart': 0,
          'listings': <dynamic>[],
          'done': false,
        },
    'history': history,
  },
};

/// The live sessions the reference built its cases from, by label.
Map<String, dynamic> _liveCase(String label) => switch (label) {
  'nothingYet' => _liveSession([]),
  'oneOnTheTable' => _liveSession([_listing()]),
  'threeOnTheTable' => _liveSession([
    _listing({'listingId': 'dd_a', 'spawnAt': _windowStart + 1000}),
    _listing({
      'listingId': 'dd_b',
      'kind': 'bid',
      'playerName': 'Milo Pivot',
      'spawnAt': _windowStart + 2000,
    }),
    _listing({
      'listingId': 'dd_c',
      'kind': 'loan',
      'playerName': 'Kit Loanee',
      'matches': 4,
      'spawnAt': _windowStart + 3000,
    }),
  ]),
  'marqueeAndLoanOut' => _liveSession([
    _listing({
      'listingId': 'dd_d',
      'marquee': true,
      'spawnAt': _windowStart + 1000,
    }),
    _listing({
      'listingId': 'dd_e',
      'kind': 'loanOut',
      'playerName': 'The Wall',
      'matches': 6,
      'spawnAt': _windowStart + 2000,
    }),
  ]),
  'doneDealsOutrankTalks' => _liveSession([
    _listing({'listingId': 'dd_f', 'status': 'accepted', 'price': 30000}),
    _listing({
      'listingId': 'dd_g',
      'kind': 'bid',
      'status': 'accepted',
      'price': 44000,
    }),
    _listing({'listingId': 'dd_h', 'spawnAt': _windowStart + 9000}),
  ]),
  'lastNightsSession' => _liveSession(
    [
      _listing({'listingId': 'dd_i', 'status': 'accepted'}),
    ],
    {
      'windowStart': _windowStart - 24 * _hour,
      'startedAt': _windowStart - 24 * _hour,
    },
  ),
  'finishedSession' => _liveSession(
    [
      _listing({'listingId': 'dd_j', 'status': 'accepted'}),
    ],
    {'done': true},
  ),
  'expiredListingsAreNotTalks' => _liveSession([
    _listing({'listingId': 'dd_k', 'expiresAt': _fixedNow - 1}),
  ]),
  'unknownKind' => _liveSession([
    _listing({'listingId': 'dd_l', 'kind': 'mystery'}),
  ]),
  _ => throw ArgumentError(label),
};

/// The aftermath cases: the session on file, and tonight's banked ledger.
({Map<String, dynamic> session, List<Map<String, dynamic>> history})
_aftermathCase(String label) => switch (label) {
  'busyEvening' => (
    session: _liveSession(
      [
        _listing({'listingId': 'dd_m', 'status': 'accepted', 'price': 30000}),
        _listing({
          'listingId': 'dd_n',
          'kind': 'bid',
          'status': 'accepted',
          'price': 44000,
        }),
      ],
      {'done': true},
    ),
    history: [
      _banked({'signings': 1, 'sales': 1}),
    ],
  ),
  'oneDeal' => (
    session: _liveSession(
      [
        _listing({'listingId': 'dd_o', 'status': 'accepted'}),
      ],
      {'done': true},
    ),
    history: [
      _banked({'signings': 1}),
    ],
  ),
  'quietEvening' => (
    session: _liveSession([], {'done': true}),
    history: [_banked()],
  ),
  'quietButMissed' => (
    session: _liveSession([], {'done': true}),
    history: [
      _banked({'missed': 3}),
    ],
  ),
  'missedExactlyOne' => (
    session: _liveSession([], {'done': true}),
    history: [
      _banked({'missed': 1}),
    ],
  ),
  'loansCountToo' => (
    session: _liveSession(
      [
        _listing({
          'listingId': 'dd_p',
          'kind': 'loan',
          'status': 'accepted',
          'matches': 5,
        }),
        _listing({
          'listingId': 'dd_q',
          'kind': 'loanOut',
          'status': 'accepted',
          'matches': 3,
        }),
      ],
      {'done': true},
    ),
    history: [
      _banked({'loans': 1, 'loanOuts': 1}),
    ],
  ),
  'staleSession' => (
    session: _liveSession(
      [
        _listing({'listingId': 'dd_r', 'status': 'accepted'}),
      ],
      {'done': true, 'windowStart': _windowStart - 24 * _hour},
    ),
    history: [
      _banked({'signings': 1}),
    ],
  ),
  'marqueeUndisclosed' => (
    session: _liveSession(
      [
        _listing({
          'listingId': 'dd_s',
          'marquee': true,
          'status': 'accepted',
          'price': 250000,
        }),
      ],
      {'done': true},
    ),
    history: [
      _banked({'signings': 1}),
    ],
  ),
  _ => throw ArgumentError(label),
};

void main() {
  setUp(() => setClock(() => _fixedNow));
  tearDown(resetClock);

  test('the strip is three lines', () {
    expect(newsLines, _ref['newsLines']);
  });

  test('parity — which phase the strip is in', () {
    for (final row in _rows('phase')) {
      final history = switch (row['label']) {
        'noHistory' => const <Map<String, dynamic>>[],
        'tonight' || 'tomorrow' => [
          {'windowStart': _windowStart, 'endedAt': _windowStart + _hour},
        ],
        'yesterday' => [
          {
            'windowStart': _windowStart - 24 * _hour,
            'endedAt': _windowStart - 23 * _hour,
          },
        ],
        'noWindowStart' => [
          {'windowStart': 0, 'endedAt': _fixedNow},
        ],
        _ => const <Map<String, dynamic>>[],
      };
      expect(
        _phaseNames[deadlineNewsPhase(
          _state(history: history),
          row['live'] as bool,
          row['at'] as int,
        )],
        row['phase'],
        reason: '${row['label']}',
      );
    }
  });

  test('the phase reads the clock when it is not given one', () {
    // Every engine takes its time through the same seam, which is what makes a
    // "was that today" question testable at all.
    expect(deadlineNewsPhase(_state(), false), NewsPhase.buildup);
    expect(
      deadlineNewsPhase(_state(history: [_banked()]), false),
      NewsPhase.aftermath,
    );
  });

  test('parity — the build-up rumour mill', () {
    for (final row in _rows('buildup')) {
      final label = row['label'] as String;
      final lines = deadlineHeadlines(
        _state(
          squad: !const [
            'noSquad',
            'nothingAtAll',
            'noTeamsAtAll',
          ].contains(label),
          pyramid: !const [
            'noPyramid',
            'nothingAtAll',
            'noTeamsAtAll',
          ].contains(label),
          opponents: label != 'noTeamsAtAll',
        ),
        clubName: label == 'bare' ? '' : 'Player Rovers',
        nowMs: row['at'] as int,
        opener: label == 'withOpener'
            ? (
                key: 'event.news.buildup.opens',
                params: <String, dynamic>{'at': '6:00 pm'},
              )
            : null,
      );
      expect(_asJson(lines), row['lines'], reason: '$label at ${row['at']}');
    }
  });

  test('the same instant is the same strip', () {
    // The whole design: a fresh draw on every re-render would reshuffle the
    // rumours under the player's eyes mid-read.
    final want = _section('buildupStable');
    final state = _state();
    final a = deadlineHeadlines(
      state,
      clubName: 'Player Rovers',
      nowMs: _fixedNow,
    );
    final b = deadlineHeadlines(
      state,
      clubName: 'Player Rovers',
      nowMs: _fixedNow,
    );
    expect(_asJson(a), _asJson(b));
    expect(want['same'], true);
    expect(_asJson(a), want['lines']);
  });

  test('an hour on, the news has moved', () {
    // And the hour bucket is what moves it: a whole afternoon on one seed would
    // be three sentences.
    final state = _state();
    final now = deadlineHeadlines(state, nowMs: _fixedNow);
    final later = deadlineHeadlines(state, nowMs: _fixedNow + _hour);
    expect(_asJson(now), isNot(_asJson(later)));
  });

  test('parity — the live window', () {
    for (final row in _rows('live')) {
      final lines = deadlineHeadlines(
        _state(session: _liveCase(row['label'] as String)),
        live: true,
        clubName: 'Player Rovers',
        nowMs: row['at'] as int,
      );
      expect(
        _asJson(lines),
        row['lines'],
        reason: '${row['label']} at ${row['at']}',
      );
    }
  });

  test('parity — the aftermath', () {
    for (final row in _rows('aftermath')) {
      final c = _aftermathCase(row['label'] as String);
      final lines = deadlineHeadlines(
        _state(session: c.session, history: c.history),
        clubName: 'Player Rovers',
        nowMs: _fixedNow,
      );
      expect(_asJson(lines), row['lines'], reason: '${row['label']}');
    }
  });

  test('the league-wide number holds all evening', () {
    // Seeded off the window rather than the clock, so it does not re-roll on
    // every rotation of the strip.
    final want = _section('aftermathStable');
    final state = _state(
      session: _liveSession([], {'done': true}),
      history: [_banked()],
    );
    final a = deadlineHeadlines(
      state,
      clubName: 'Player Rovers',
      nowMs: _fixedNow,
    );
    final b = deadlineHeadlines(
      state,
      clubName: 'Player Rovers',
      nowMs: _fixedNow + 20 * 60 * 1000,
    );
    expect(_asJson(a), want['a']);
    expect(_asJson(b), want['b']);
    expect(_asJson(a), _asJson(b));
  });

  test('parity — the undisclosed-fee flip is stable per listing', () {
    // A fee that turned undisclosed halfway through a rotation would read as a
    // bug in the ticker. Both branches have to be reachable, too, or every deal
    // reads the same way.
    final rows = _rows('undisclosed');
    for (final row in rows) {
      final lines = deadlineHeadlines(
        _state(
          session: _liveSession(
            [
              _listing({'listingId': row['listingId'], 'status': 'accepted'}),
            ],
            {'done': true},
          ),
          history: [
            _banked({'signings': 1}),
          ],
        ),
        clubName: 'Player Rovers',
        nowMs: _fixedNow,
      );
      expect(lines.first.key, row['key'], reason: '${row['listingId']} key');
      expect(
        lines.first.params['fee'],
        row['fee'],
        reason: '${row['listingId']} fee',
      );
    }
    expect(
      rows.map((r) => r['key']).toSet().length,
      greaterThan(1),
      reason: 'both branches must be reachable',
    );
  });

  test('a build-up line is never a blank name', () {
    // A template whose names we have not got is not drawn at all: "has been
    // spotted at" with a blank in front of it is worse than one fewer line.
    for (var h = 0; h < 200; h++) {
      final lines = deadlineHeadlines(
        _state(),
        clubName: 'Player Rovers',
        nowMs: _fixedNow + h * _hour,
      );
      expect(lines.length, newsLines, reason: 'hour $h');
      for (final line in lines) {
        for (final entry in line.params.entries) {
          expect(entry.value, isNot(''), reason: '${line.key} ${entry.key}');
          expect(entry.value, isNotNull, reason: '${line.key} ${entry.key}');
        }
      }
    }
  });

  test('a bidding war is never a club against itself', () {
    for (var h = 0; h < 200; h++) {
      final lines = deadlineHeadlines(
        _state(),
        clubName: 'Player Rovers',
        nowMs: _fixedNow + h * _hour,
      );
      for (final line in lines) {
        if (!line.params.containsKey('team2')) continue;
        expect(
          line.params['team2'],
          isNot(line.params['team']),
          reason: '${line.key} at hour $h',
        );
      }
    }
  });

  test('the headlines read the clock when they are not given one', () {
    // The same seam every engine takes its time through.
    final fromClock = deadlineHeadlines(_state(), clubName: 'Player Rovers');
    final explicit = deadlineHeadlines(
      _state(),
      clubName: 'Player Rovers',
      nowMs: _fixedNow,
    );
    expect(_asJson(fromClock), _asJson(explicit));
  });

  test('an empty save still fills the strip', () {
    // No squad, no pyramid, no club name: every rumour that needs a name is
    // unusable, and the filler is what stops the strip coming back short.
    final lines = deadlineHeadlines(
      _state(squad: false, pyramid: false),
      nowMs: _fixedNow,
    );
    expect(lines.length, newsLines);
  });
}

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;
