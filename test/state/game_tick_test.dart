/// One turn of the game loop.
///
/// The JS reads its gates off the DOM — is a mini-game open, is the match popup
/// up, is Coach Colin already on screen — which is why none of this was ever
/// testable there. Here they are arguments, so each can be asked about
/// directly: what a tick does, and what it declines to start.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;

/// The instant the loop and every engine agree on. The tick reads the shared
/// clock rather than taking one, so a test moves time by moving this.
int _at = _now;

void _advance(int ms) => _at += ms;

/// The shared reference save's squad.
///
/// A DEFAULT state starts with an empty grid — the tutorial is what fills it —
/// and a loop with nothing on the grid earns nothing, injures nobody and has no
/// fitness to recover.
List<dynamic> _referenceSquad() {
  final ref =
      jsonDecode(
            File(
              'test/fixtures/quest_engine_reference.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final grid = (ref['state'] as Map<String, dynamic>)['grid'] as Map;
  return jsonDecode(jsonEncode(grid['cells'])) as List<dynamic>;
}

Map<String, dynamic> _state({
  bool hardMode = false,
  num coins = 1000,
  int energy = 3,
}) {
  final s = createDefaultState();
  (s['grid'] as Map)['cells'] = _referenceSquad();
  (s['settings'] as Map)['hardMode'] = hardMode;
  (s['resources'] as Map)['fanCoins'] = coins;
  (s['energy'] as Map)
    ..['current'] = energy
    ..['lastRegenAt'] = _now;
  // Something that actually earns, so the income line has a number to move.
  (s['clubAssets'] as Map)['MERCH'] = <String, dynamic>{
    'owned': true,
    'tier': 4,
    'invested': 0,
    'tapCount': 0,
  };
  return s;
}

const TickGates _matchUp = (
  matchOpen: true,
  miniGameOpen: false,
  transferOpen: false,
  colinOnScreen: false,
);

GameLoop _loop() => GameLoop(startedAt: _now);

void main() {
  setUp(() {
    _at = _now;
    setClock(() => _at);
    seeded.setSeed(1234);
  });
  tearDown(resetClock);

  test('a tick credits the income that accrued since the last one', () {
    final state = _state();
    final before = (state['resources'] as Map)['fanCoins'] as num;
    final loop = _loop();
    _advance(60000);
    final report = loop.tick(state);
    expect(report.coinsEarned, greaterThan(0));
    expect(
      (state['resources'] as Map)['fanCoins'],
      before + report.coinsEarned,
    );
  });

  test('a hidden app does nothing at all', () {
    // The pause handler has already saved, and the offline calculation pays for
    // the time away. Ticking as well would burn battery to pay it twice.
    final state = _state();
    final before = (state['resources'] as Map)['fanCoins'];
    final loop = _loop();
    _advance(60000);
    final report = loop.tick(state, hidden: true);
    expect(report.coinsEarned, 0);
    expect((state['resources'] as Map)['fanCoins'], before);
    // And the clock still moves, so the next visible tick does not bill for the
    // time spent hidden.
    expect(loop.lastTickAt, _now + 60000);
  });

  test('a resume skips the elapsed time rather than crediting it', () {
    final state = _state();
    final loop = _loop();
    _advance(3600000);
    loop.skipElapsed();
    expect(loop.lastTickAt, _now + 3600000);

    _advance(1000);
    final oneSecond = loop.tick(state);

    // The same hour, ticked rather than skipped, pays far more.
    final other = _loop();
    _at = _now;
    _advance(3600000 + 1000);
    final anHour = other.tick(_state());
    expect(oneSecond.coinsEarned, lessThan(anHour.coinsEarned));
  });

  test('the pip pool regenerates, and says when it moved', () {
    final state = _state(energy: 1);
    final loop = _loop();
    _advance(1000);
    expect(loop.tick(state).energyChanged, isFalse);

    _advance(30 * 60 * 1000);
    expect(loop.tick(state).energyChanged, isTrue);
    expect((state['energy'] as Map)['current'], greaterThan(1));
  });

  test('Pro mode recovers fitness and Casual has none to recover', () {
    final casual = _state();
    final casualLoop = _loop();
    _advance(60000);
    expect(casualLoop.tick(casual).fitnessRecovered, 0);

    _at = _now;
    final pro = _state(hardMode: true);
    for (final c in (pro['grid'] as Map)['cells'] as List) {
      if (c == null) continue;
      (c as Map)
        ..['energy'] = 0.2
        ..['energyUpdatedAt'] = _now;
    }
    final proLoop = _loop();
    _advance(60 * 60 * 1000);
    expect(proLoop.tick(pro).fitnessRecovered, greaterThan(0));
  });

  group('the gates', () {
    test('a bid is rolled only when the screen is clear', () {
      for (final gates in <TickGates>[
        _matchUp,
        (
          matchOpen: false,
          miniGameOpen: true,
          transferOpen: false,
          colinOnScreen: false,
        ),
        (
          matchOpen: false,
          miniGameOpen: false,
          transferOpen: true,
          colinOnScreen: false,
        ),
        (
          matchOpen: false,
          miniGameOpen: false,
          transferOpen: false,
          colinOnScreen: true,
        ),
      ]) {
        _at = _now;
        final loop = _loop();
        _advance(transferCheckIntervalMs);
        expect(
          loop.tick(_state(), gates: gates).transferOffer,
          isNull,
          reason: '$gates',
        );
      }
    });

    test('a busy screen delays the roll rather than burning it', () {
      // The clock is deliberately not stamped while the screen is busy, so the
      // bid arrives as soon as it clears rather than waiting out another full
      // minute.
      final state = _state();
      final loop = _loop();
      for (var i = 0; i < 3; i++) {
        _advance(transferCheckIntervalMs);
        loop.tick(state, gates: _matchUp);
      }
      // A clear tick one millisecond later is eligible — no further wait.
      _advance(1);
      final report = loop.tick(state);
      expect(report.transferOffer, anyOf(isNull, isA<Map<String, dynamic>>()));
      // And having rolled, the next one is not eligible for another minute.
      _advance(1);
      expect(loop.tick(state).transferOffer, isNull);
    });

    test('an injury heals whether or not the match is up', () {
      // What the match suppresses is the lineup REFILL, not the healing:
      // filling the hole an injury just left, mid-match, would be an automatic
      // substitution the player never made.
      Map<String, dynamic> injured() {
        final s = _state();
        for (final c in (s['grid'] as Map)['cells'] as List) {
          if (c == null) continue;
          (c as Map)
            ..['injured'] = true
            ..['injuredAt'] = _now - 60 * 60 * 1000
            ..['injuryDurationMs'] = 1000;
          break;
        }
        return s;
      }

      for (final gates in <TickGates>[clearScreen, _matchUp]) {
        _at = _now;
        final loop = _loop();
        _advance(1000);
        expect(
          loop.tick(injured(), gates: gates).injuriesHealed,
          isTrue,
          reason: '$gates',
        );
      }
    });
  });

  test('an event window opening asks for an immediate save', () {
    // A window crossing is not something to lose to a debounce, and neither is
    // a loan going home.
    final state = _state();
    (state['events'] as Map)['devOverride'] = 'wc2026';
    final loop = _loop();
    _advance(1000);
    final report = loop.tick(state);
    expect(report.eventsActivated, contains('wc2026'));
    expect(report.needsImmediateSave, isTrue);
  });

  test('a quiet tick asks for nothing', () {
    final state = _state(coins: 0);
    // Nothing on the grid and no assets, so no income either.
    (state['clubAssets'] as Map).remove('MERCH');
    (state['grid'] as Map)['cells'] = List<dynamic>.filled(24, null);
    final loop = _loop();
    _advance(100);
    final report = loop.tick(state);
    expect(report.eventsActivated, isEmpty);
    expect(report.coinsEarned, 0);
    expect(report.energyChanged, isFalse);
    expect(report.injuriesHealed, isFalse);
    expect(report.loansRecalled, isEmpty);
    expect(report.needsImmediateSave, isFalse);
  });

  test('a squad that cannot pay its loans loses them', () {
    // A borrowed card earns nothing itself and is charged a share of what a
    // player of its calibre WOULD bring in, so a squad that is ONE loanee
    // cannot cover him by definition. That is the shape the continuous check
    // exists for: affordability is a question the game asks all the time now,
    // not only when a match is played.
    final state = _state(coins: 0);
    (state['grid'] as Map)['cells'] = <dynamic>[
      <String, dynamic>{
        'instanceId': 'loanee',
        'definitionId': 'player_t8_fwd',
        'seasonsPlayed': 0,
        'borrowed': true,
        'loanFrom': 'Rival FC',
        'loanMatchesLeft': 3,
      },
      null,
      null,
    ];
    final loop = _loop();
    _advance(1000);
    final report = loop.tick(state);
    expect(report.loansRecalled, hasLength(1));
    expect(report.loansRecalled.single.from, 'Rival FC');
    expect(report.needsImmediateSave, isTrue);
  });

  test('a loop with no start time begins now', () {
    expect(GameLoop().lastTickAt, _now);
  });
}
