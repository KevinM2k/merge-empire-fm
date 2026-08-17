import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

int _at(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

/// Inside the International Cup window.
final int _live = _at('2026-07-01T12:00:00Z');

/// Inside its preview window, three weeks out.
final int _soon = _at('2026-05-25T12:00:00Z');

/// Long after it closed.
final int _over = _at('2026-09-01T12:00:00Z');

EventDef get _wc => getEventById('wc2026')!;
EventDef get _ddl => getEventById('deadline_day')!;

bool get _runningInUtc => DateTime.now().timeZoneOffset == Duration.zero;

Map<String, dynamic> _state({
  List<dynamic>? active,
  Map<String, dynamic>? progress,
  List<dynamic>? history,
  String? devOverride,
  String division = 'regional_league',
  num coins = 0,
  num trophies = 0,
  int energy = 0,
  bool noEventsBranch = false,
}) => {
  'resources': <String, dynamic>{'fanCoins': coins, 'trophies': trophies},
  'progression': <String, dynamic>{'currentDivision': division},
  'energy': <String, dynamic>{'current': energy, 'lastRegenAt': 0},
  'shop': <String, dynamic>{},
  if (!noEventsBranch)
    'events': <String, dynamic>{
      'active': active ?? <dynamic>[],
      'progress': progress ?? <String, dynamic>{},
      'history': history ?? <dynamic>[],
      'devOverride': ?devOverride,
    },
};

void main() {
  setUp(() {
    setClock(() => _live);
    clearAnnualWindowCache();
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('eventPhase', () {
    test('is active inside a fixed window', () {
      expect(eventPhase(_wc, _state(), _live), EventPhase.active);
    });

    test('is preview in the run-up', () {
      expect(eventPhase(_wc, _state(), _soon), EventPhase.preview);
    });

    test('is inactive before the preview window opens', () {
      expect(
        eventPhase(_wc, _state(), _at('2026-01-01T00:00:00Z')),
        EventPhase.inactive,
      );
    });

    test('is ended once a fixed window has passed', () {
      expect(eventPhase(_wc, _state(), _over), EventPhase.ended);
    });

    test('a recurring event NEVER reports ended', () {
      // It comes back, so once an occurrence closes it is only ever counting
      // down to the next one.
      for (final iso in [
        '2026-01-15T12:00:00Z',
        '2026-06-01T00:00:00Z',
        '2027-03-01T00:00:00Z',
      ]) {
        expect(eventPhase(_ddl, _state(), _at(iso)), isNot(EventPhase.ended));
      }
    });

    test('the dev override forces active whatever the calendar says', () {
      // The hidden Settings toggle, so an event can be dogfooded without
      // touching the device clock.
      final state = _state(devOverride: 'wc2026');
      expect(eventPhase(_wc, state, _at('2020-01-01T00:00:00Z')), EventPhase.active);
    });

    test('and only for the event it names', () {
      final state = _state(devOverride: 'wc2026');
      expect(eventPhase(_ddl, state, _at('2026-06-15T12:00:00Z')), isNot(EventPhase.active));
    });

    test('a null event is inactive', () {
      expect(eventPhase(null, _state(), _live), EventPhase.inactive);
    });

    test('an unparseable window is inactive, never always-on', () {
      const broken = EventDef(
        id: 'broken',
        name: 'Broken',
        nameKey: 'x',
        shortName: 'B',
        flavour: '',
        flavourKey: 'y',
        color: '#fff',
        trigger: DateWindowTrigger(start: 'nope', end: 'also nope'),
      );
      expect(eventPhase(broken, _state(), _live), EventPhase.inactive);
    });
  });

  group('the countdown', () {
    test('counts down to a fixed window and stops at zero', () {
      expect(eventStartsInMs(_wc, _soon), _at('2026-06-11T00:00:00Z') - _soon);
      expect(eventStartsInMs(_wc, _live), 0);
      expect(eventStartsInMs(_wc, _over), 0);
    });

    test('reports when a live fixed window closes', () {
      expect(eventEndsAtMs(_wc, _live), _at('2026-07-19T23:59:59Z'));
    });

    test('a fixed window reports its end even after it has passed', () {
      // Deliberate: the end is a property of the window, not of now.
      expect(eventEndsAtMs(_wc, _over), _at('2026-07-19T23:59:59Z'));
    });

    test('a recurring window reports zero when it is not live', () {
      final noon = DateTime(2026, 1, 15, 12).millisecondsSinceEpoch;
      expect(eventEndsAtMs(_ddl, noon), 0);
      expect(eventStartsInMs(_ddl, noon), greaterThan(0));
    });

    test('and its own end when it is', () {
      final live = DateTime(2026, 1, 15, 18, 30).millisecondsSinceEpoch;
      expect(eventStartsInMs(_ddl, live), 0);
      expect(eventEndsAtMs(_ddl, live), DateTime(2026, 1, 15, 19).millisecondsSinceEpoch);
    });

    test('a null event answers zero to both', () {
      expect(eventStartsInMs(null, _live), 0);
      expect(eventEndsAtMs(null, _live), 0);
    });
  });

  group('previewEvents', () {
    test('lists what is coming up', () {
      expect(previewEvents(_state(), _soon).map((e) => e.id), ['wc2026']);
    });

    test('and nothing while an event is actually live', () {
      expect(previewEvents(_state(), _live), isEmpty);
    });

    test('sorted by whichever opens first', () {
      // Late December: Deadline Day previews from a week out, and the
      // International Cup is long gone.
      final ids = previewEvents(_state(), _at('2026-12-27T12:00:00Z')).map((e) => e.id);
      expect(ids, ['deadline_day']);
    });
  });

  group('evaluateTrigger', () {
    test('fires inside a window and not outside it', () {
      expect(evaluateTrigger(_wc, _state(), _live), isTrue);
      expect(evaluateTrigger(_wc, _state(), _over), isFalse);
      expect(evaluateTrigger(_wc, _state(), _soon), isFalse);
    });

    test('the dev override bypasses the trigger entirely', () {
      final state = _state(devOverride: 'wc2026');
      expect(evaluateTrigger(_wc, state, _over), isTrue);
    });

    test('a null event never fires', () {
      expect(evaluateTrigger(null, _state(), _live), isFalse);
    });
  });

  group('activateEligibleEvents', () {
    test('activates an event whose window has opened', () {
      final state = _state();
      expect(activateEligibleEvents(state, _live), ['wc2026']);
      expect(state['events']['active'], ['wc2026']);
    });

    test('and seeds it a progress record', () {
      final state = _state();
      activateEligibleEvents(state, _live);
      final progress = eventProgress(state, 'wc2026')!;
      expect(progress['score'], 0);
      expect(progress['claimedTiers'], isEmpty);
      expect(progress['challenges'], isEmpty);
      expect(progress['activatedAt'], _live);
    });

    test('announces the activation', () {
      Object? announced;
      on('event:activated', (v) => announced = v);
      activateEligibleEvents(_state(), _live);
      expect((announced as Map)['eventId'], 'wc2026');
    });

    test('is idempotent — a second call activates nothing', () {
      final state = _state();
      activateEligibleEvents(state, _live);
      expect(activateEligibleEvents(state, _live), isEmpty);
      expect(state['events']['active'], ['wc2026']);
    });

    test('retires an event whose window has closed', () {
      final state = _state(active: ['wc2026'], progress: {
        'wc2026': <String, dynamic>{'score': 40, 'claimedTiers': <dynamic>[0]},
      });
      activateEligibleEvents(state, _over);
      expect(state['events']['active'], isEmpty);
      expect(state['events']['history'], hasLength(1));
    });

    test('the retirement keeps what the player earned', () {
      final state = _state(active: ['wc2026'], progress: {
        'wc2026': <String, dynamic>{
          'score': 40,
          'claimedTiers': <dynamic>[0, 1],
          'cup': <String, dynamic>{'won': true},
        },
      });
      activateEligibleEvents(state, _over);
      final record = (state['events']['history'] as List).single as Map;
      expect(record['finalScore'], 40);
      expect(record['claimedTiers'], [0, 1]);
      expect(record['won'], isTrue);
    });

    test('a save with no events branch is left alone', () {
      final state = _state(noEventsBranch: true);
      expect(activateEligibleEvents(state, _live), isEmpty);
      expect(state.containsKey('events'), isFalse);
    });
  });

  group('endEventCleanup', () {
    test('is idempotent — the second call does nothing', () {
      final state = _state(active: ['wc2026']);
      endEventCleanup(state, 'wc2026');
      endEventCleanup(state, 'wc2026');
      expect(state['events']['history'], hasLength(1));
    });

    test('an event that was never active is not filed', () {
      final state = _state();
      endEventCleanup(state, 'wc2026');
      expect(state['events']['history'], isEmpty);
    });

    test('announces the ending with the name', () {
      Object? announced;
      on('event:ended', (v) => announced = v);
      endEventCleanup(_state(active: ['wc2026']), 'wc2026');
      expect((announced as Map)['name'], 'International Cup 2026');
    });

    test('an unknown id falls back to the id as its name', () {
      Object? announced;
      on('event:ended', (v) => announced = v);
      endEventCleanup(_state(active: ['mystery']), 'mystery');
      expect((announced as Map)['name'], 'mystery');
    });

    test('a record with no progress still files a clean one', () {
      final state = _state(active: ['wc2026']);
      endEventCleanup(state, 'wc2026');
      final record = (state['events']['history'] as List).single as Map;
      expect(record['finalScore'], 0);
      expect(record['won'], isFalse);
    });
  });

  group('accessors', () {
    test('activeEvents resolves ids to catalogue entries', () {
      expect(activeEvents(_state(active: ['wc2026'])).single.id, 'wc2026');
    });

    test('and quietly drops an id the catalogue no longer has', () {
      // A retired event in an old save must not crash the screen.
      expect(activeEvents(_state(active: ['wc2026', 'retired'])), hasLength(1));
    });

    test('isEventActive reads the list', () {
      final state = _state(active: ['wc2026']);
      expect(isEventActive(state, 'wc2026'), isTrue);
      expect(isEventActive(state, 'deadline_day'), isFalse);
      expect(isEventActive(null, 'wc2026'), isFalse);
    });

    test('eventProgress is null when there is none', () {
      expect(eventProgress(_state(), 'wc2026'), isNull);
      expect(eventProgress(null, 'wc2026'), isNull);
    });
  });

  group('trackEventAction', () {
    Map<String, dynamic> activeState() {
      final state = _state();
      activateEligibleEvents(state, _live);
      return state;
    }

    Map<String, dynamic> challenge(Map<String, dynamic> state, String id) =>
        (eventProgress(state, 'wc2026')!['challenges'] as Map)[id]
            as Map<String, dynamic>;

    test('advances a challenge that is watching for the action', () {
      final state = activeState();
      trackEventAction(state, 'event_cup_won');
      expect(challenge(state, 'wc_first_win')['progress'], 1);
      expect(challenge(state, 'wc_first_win')['completed'], isTrue);
    });

    test('one action advances EVERY challenge watching for it', () {
      // The three win counters share a type; a single win moves all three.
      final state = activeState();
      trackEventAction(state, 'event_cup_won');
      expect(challenge(state, 'wc_won_5')['progress'], 1);
      expect(challenge(state, 'wc_won_10')['progress'], 1);
      expect(challenge(state, 'wc_won_5')['completed'], isFalse);
    });

    test('progress never runs past the target', () {
      final state = activeState();
      for (var i = 0; i < 20; i++) {
        trackEventAction(state, 'event_cup_won');
      }
      expect(challenge(state, 'wc_won_10')['progress'], 10);
    });

    test('a completed challenge stops counting', () {
      final state = activeState();
      trackEventAction(state, 'event_cup_won');
      final at = challenge(state, 'wc_first_win')['scoredAt'];
      trackEventAction(state, 'event_cup_won');
      expect(challenge(state, 'wc_first_win')['scoredAt'], at);
    });

    test('an amount advances by that much in one go', () {
      final state = activeState();
      trackEventAction(state, 'event_cup_won', 5);
      expect(challenge(state, 'wc_won_5')['completed'], isTrue);
      expect(challenge(state, 'wc_won_10')['progress'], 5);
    });

    test('an action nothing is watching passes through harmlessly', () {
      final state = activeState();
      expect(() => trackEventAction(state, 'merged_card'), returnsNormally);
      expect(eventProgress(state, 'wc2026')!['challenges'], isEmpty);
    });

    test('announces a completion and the new score', () {
      final state = activeState();
      final seen = <String>[];
      on('event:challenge-completed', (_) => seen.add('completed'));
      on('event:score-updated', (_) => seen.add('score'));
      trackEventAction(state, 'event_cup_won');
      expect(seen, contains('completed'));
      expect(seen, contains('score'));
    });

    test('an inactive event is not tracked', () {
      final state = _state();
      trackEventAction(state, 'event_cup_won');
      expect(eventProgress(state, 'wc2026'), isNull);
    });

    test('a save with no events branch is left alone', () {
      final state = _state(noEventsBranch: true);
      expect(() => trackEventAction(state, 'event_cup_won'), returnsNormally);
    });
  });

  group('claimEventChallenge', () {
    Map<String, dynamic> wonState({String division = 'regional_league'}) {
      final state = _state(division: division);
      activateEligibleEvents(state, _live);
      trackEventAction(state, 'event_cup_won');
      return state;
    }

    test('pays out and marks the challenge claimed', () {
      final state = wonState();
      final result = claimEventChallenge(state, 'wc2026', 'wc_first_win');
      expect(result.ok, isTrue);
      expect(result.coins, greaterThan(0));
      expect(state['resources']['fanCoins'], result.coins);
    });

    test('the payout scales with the division', () {
      // Which is what keeps a headline reward a headline all the way up.
      num claim(String division) {
        final state = wonState(division: division);
        return claimEventChallenge(state, 'wc2026', 'wc_first_win').coins;
      }

      expect(claim('champions_cup'), greaterThan(claim('sunday_league')));
    });

    test('the figure is the division base times the multiplier', () {
      final state = wonState(division: 'elite_league');
      final expected = roundCoins(
        getDivision('elite_league').matchRevenueBase * 5,
      );
      expect(claimEventChallenge(state, 'wc2026', 'wc_first_win').coins, expected);
    });

    test('a second claim is refused and pays nothing', () {
      final state = wonState();
      claimEventChallenge(state, 'wc2026', 'wc_first_win');
      final before = state['resources']['fanCoins'];
      final second = claimEventChallenge(state, 'wc2026', 'wc_first_win');
      expect(second.ok, isFalse);
      expect(second.reason, 'already_claimed');
      expect(state['resources']['fanCoins'], before);
    });

    test('an incomplete challenge cannot be claimed', () {
      final state = wonState();
      final result = claimEventChallenge(state, 'wc2026', 'wc_won_10');
      expect(result.ok, isFalse);
      expect(result.reason, 'not_completed');
    });

    test('an unknown event or challenge is refused', () {
      final state = wonState();
      expect(claimEventChallenge(state, 'nope', 'x').reason, 'unknown_event');
      expect(
        claimEventChallenge(state, 'wc2026', 'nope').reason,
        'unknown_challenge',
      );
    });

    test('an event with no challenges at all is refused', () {
      final state = _state();
      expect(
        claimEventChallenge(state, 'deadline_day', 'x').reason,
        'unknown_event',
      );
    });

    test('announces the claim and the new balance', () {
      final state = wonState();
      Object? claimed;
      Object? coins;
      on('event:challenge-claimed', (v) => claimed = v);
      on('coins:updated', (v) => coins = v);
      claimEventChallenge(state, 'wc2026', 'wc_first_win');
      expect((claimed as Map)['challengeId'], 'wc_first_win');
      expect(coins, state['resources']['fanCoins']);
    });
  });

  group('claimRewardTier', () {
    test('neither shipped event offers a reward track', () {
      // The International Cup's only prize is the trophy and the coin bounty
      // for winning the bracket.
      for (final e in events) {
        expect(e.rewardTrack, isEmpty, reason: e.id);
      }
    });

    test('an unknown event is refused', () {
      expect(claimRewardTier(_state(), 'nope', 0).reason, 'unknown_event');
    });

    test('a tier that does not exist is refused', () {
      expect(claimRewardTier(_state(), 'wc2026', 0).reason, 'unknown_tier');
      expect(claimRewardTier(_state(), 'wc2026', -1).reason, 'unknown_tier');
    });
  });

  group('claimRewardTier — against a track', () {
    // Neither shipped event has one, and the dormant slot is going to be
    // reused, so the tier machinery is exercised against a definition built
    // for it. This is the specification for whatever fills that slot.
    const tracked = EventDef(
      id: 'tracked',
      name: 'Tracked Event',
      nameKey: 'x',
      shortName: 'TR',
      flavour: '',
      flavourKey: 'y',
      color: '#fff',
      trigger: DateWindowTrigger(
        start: '2026-06-11T00:00:00Z',
        end: '2026-07-19T23:59:59Z',
      ),
      challengeConfig: [
        EventChallenge(
          id: 'scorer',
          type: 'goals',
          target: 3,
          rewardMult: 1,
          text: 'Score three',
          icon: '⚽',
          points: 10,
        ),
      ],
      rewardTrack: [
        RewardTier(
          score: 0,
          reward: (coins: 500, trophies: 0, energy: 0, freeScout: false),
        ),
        RewardTier(
          score: 10,
          reward: (coins: 0, trophies: 2, energy: 4, freeScout: true),
        ),
        RewardTier(
          score: 999,
          reward: (coins: 1000, trophies: 0, energy: 0, freeScout: false),
        ),
      ],
    );

    setUp(() => debugSetEvents([tracked]));
    tearDown(() => debugSetEvents(null));

    Map<String, dynamic> earned({int energy = 0}) {
      final state = _state(energy: energy);
      activateEligibleEvents(state, _live);
      trackEventAction(state, 'goals', 3);
      return state;
    }

    test('the challenge scores the track', () {
      expect(eventProgress(earned(), 'tracked')!['score'], 10);
    });

    test('a tier at or under the score is claimable', () {
      final state = earned();
      expect(claimRewardTier(state, 'tracked', 1).ok, isTrue);
    });

    test('a tier above it is not yet earned', () {
      final state = earned();
      final result = claimRewardTier(state, 'tracked', 2);
      expect(result.ok, isFalse);
      expect(result.reason, 'not_earned');
    });

    test('coins land and are announced', () {
      final state = earned();
      Object? announced;
      on('coins:updated', (v) => announced = v);
      claimRewardTier(state, 'tracked', 0);
      expect(state['resources']['fanCoins'], roundCoins(500));
      expect(announced, state['resources']['fanCoins']);
    });

    test('trophies, energy and a free scout all land together', () {
      final state = earned(energy: 2);
      final result = claimRewardTier(state, 'tracked', 1);
      expect(result.ok, isTrue);
      expect(state['resources']['trophies'], 2);
      expect(state['energy']['current'], 6);
      expect(state['shop']['freeScoutReady'], isTrue);
    });

    test('energy is capped at the UPGRADED maximum', () {
      // The same ceiling the challenge claim uses, whether or not this save
      // owns the upgrade.
      final state = earned(energy: Energy.maxUpgraded);
      claimRewardTier(state, 'tracked', 1);
      expect(state['energy']['current'], Energy.maxUpgraded);
      expect(Energy.maxUpgraded, greaterThan(Energy.max));
    });

    test('a tier with no coins announces no balance change', () {
      final state = earned();
      var announced = false;
      on('coins:updated', (_) => announced = true);
      claimRewardTier(state, 'tracked', 1);
      expect(announced, isFalse);
    });

    test('announces the claim with the reward attached', () {
      final state = earned();
      Object? announced;
      on('event:reward-claimed', (v) => announced = v);
      claimRewardTier(state, 'tracked', 0);
      expect((announced as Map)['tierIdx'], 0);
      expect((announced as Map)['reward'], tracked.rewardTrack[0].reward);
    });

    test('a second claim of the same tier is refused and pays nothing', () {
      final state = earned();
      claimRewardTier(state, 'tracked', 0);
      final before = state['resources']['fanCoins'];
      final second = claimRewardTier(state, 'tracked', 0);
      expect(second.ok, isFalse);
      expect(second.reason, 'already_claimed');
      expect(state['resources']['fanCoins'], before);
    });

    test('a different tier is still claimable after the first', () {
      final state = earned();
      claimRewardTier(state, 'tracked', 0);
      expect(claimRewardTier(state, 'tracked', 1).ok, isTrue);
      expect(eventProgress(state, 'tracked')!['claimedTiers'], [0, 1]);
    });

    test('claiming seeds a progress record on a save that has none', () {
      final state = _state();
      expect(claimRewardTier(state, 'tracked', 0).ok, isTrue);
      expect(eventProgress(state, 'tracked'), isNotNull);
    });
  });

  group('parity with the JS', () {
    test('reproduces every reference phase and countdown', () {
      if (!_runningInUtc) {
        markTestSkipped('needs TZ=UTC — the reference was generated there');
        return;
      }
      final data =
          jsonDecode(
                File('test/fixtures/event_window_reference.json').readAsStringSync(),
              )
              as Map<String, dynamic>;

      for (final iso in (data['probes'] as List).cast<String>()) {
        final at = _at(iso);
        final expected = data['phase'][iso] as Map<String, dynamic>;
        expect(eventPhase(_wc, _state(), at).name, expected['wc'], reason: iso);
        expect(eventStartsInMs(_wc, at), expected['wcStartsIn'], reason: iso);
        expect(eventEndsAtMs(_wc, at), expected['wcEndsAt'], reason: iso);
        expect(eventPhase(_ddl, _state(), at).name, expected['ddl'], reason: iso);
        expect(eventStartsInMs(_ddl, at), expected['ddlStartsIn'], reason: iso);
        expect(eventEndsAtMs(_ddl, at), expected['ddlEndsAt'], reason: iso);
      }
    });
  });
}
