/// Yellow and red cards — the port's own feature.
///
/// **Nothing in the spec books anybody**, so there is no fixture to compare
/// against and no JS to be faithful to. What these pin instead are the rules
/// that were asked for and the one architectural promise the file makes: that
/// it cannot perturb the parity-pinned event feed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart';

List<BookingCandidate> _squad() => [
  (instanceId: 'gk', name: 'Keeper', position: 'GK'),
  for (var i = 0; i < 4; i++)
    (instanceId: 'd$i', name: 'Def $i', position: 'DEF'),
  for (var i = 0; i < 4; i++)
    (instanceId: 'm$i', name: 'Mid $i', position: 'MID'),
  for (var i = 0; i < 2; i++)
    (instanceId: 'f$i', name: 'Fwd $i', position: 'FWD'),
];

/// A thousand matches, so the rare branches actually turn up.
List<List<Booking>> _season([int n = 1000]) => [
  for (var seed = 0; seed < n; seed++)
    rollBookings(squad: _squad(), seed: seed),
];

void main() {
  test('the same match books the same players', () {
    // A match replays the same bookings, which is the promise the cutaway
    // already makes about its passages.
    for (final seed in [1, 7, 99, 4242]) {
      expect(
        rollBookings(squad: _squad(), seed: seed),
        rollBookings(squad: _squad(), seed: seed),
        reason: 'seed $seed',
      );
    }
  });

  test('and different matches do not', () {
    final all = {
      for (var seed = 0; seed < 50; seed++)
        rollBookings(squad: _squad(), seed: seed).toString(),
    };
    expect(all.length, greaterThan(5), reason: 'every match booked the same');
  });

  test('MOST MATCHES ARE QUIET, and none is a bookfest', () {
    // A feed is read rather than watched. Two or three cards is a talking
    // point; six is noise nobody finishes.
    final season = _season();
    final counts = season.map((b) => b.length).toList();
    expect(counts.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(4));
    final quiet = counts.where((c) => c == 0).length;
    expect(quiet, greaterThan(100), reason: 'every match had a card in it');
    final average = counts.reduce((a, b) => a + b) / counts.length;
    expect(average, lessThan(1.6), reason: 'average $average is a bookfest');
  });

  test('a sending-off is RARE, and a straight red rarer still', () {
    final season = _season();
    final offs = season.where((b) => sentOffIn(b).isNotEmpty).length;
    final straight = season
        .where((b) => b.any((x) => x.card == cardRed))
        .length;
    expect(offs, greaterThan(10), reason: 'nobody was ever sent off');
    expect(offs, lessThan(200), reason: 'a red every five games');
    expect(straight, lessThan(offs), reason: 'most reds are second yellows');
  });

  test('A SECOND YELLOW FOLLOWS A FIRST, and follows it in TIME', () {
    // The two are different offences and the feed says which — a caution too
    // many against violent conduct. A second that arrives before the first is
    // nonsense on the page.
    for (final match in _season()) {
      for (final second in match.where((b) => b.card == cardSecondYellow)) {
        final first = match.where(
          (b) => b.card == cardYellow && b.instanceId == second.instanceId,
        );
        expect(first, hasLength(1), reason: 'a second yellow with no first');
        expect(second.minute, greaterThan(first.single.minute));
      }
    }
  });

  test('nobody is booked twice without being sent off for it', () {
    for (final match in _season()) {
      final yellows = match.where((b) => b.card == cardYellow).toList();
      expect(
        yellows.map((b) => b.instanceId).toSet(),
        hasLength(yellows.length),
        reason: 'two cautions and he stayed on',
      );
    }
  });

  test('and a player already off cannot pick another card up', () {
    for (final match in _season()) {
      final off = <String>{};
      for (final b in match) {
        expect(off, isNot(contains(b.instanceId)));
        if (cardSendsOff(b.card)) off.add(b.instanceId);
      }
    }
  });

  test('every card lands inside the ninety minutes it was earned in', () {
    // A booking in the 94th that the clock never reaches is a suspension
    // nobody saw earned.
    for (final match in _season()) {
      for (final b in match) {
        expect(b.minute, greaterThanOrEqualTo(8));
        expect(b.minute, lessThanOrEqualTo(88));
      }
    }
  });

  test('defenders see more of them than forwards, and the keeper hardly any', () {
    final by = <String, int>{};
    for (final match in _season(4000)) {
      for (final b in match) {
        by[b.instanceId[0]] = (by[b.instanceId[0]] ?? 0) + 1;
      }
    }
    expect(by['d']!, greaterThan(by['f']!));
    expect(by['g'] ?? 0, lessThan(by['f']!));
  });

  test('an empty bench books nobody rather than throwing', () {
    expect(rollBookings(squad: const [], seed: 1), isEmpty);
  });

  group('what a match leaves behind', () {
    test('a sending-off is a suspension and a caution is not', () {
      const off = (
        minute: 30,
        instanceId: 'd1',
        name: 'Def',
        card: cardRed,
      );
      const booked = (
        minute: 40,
        instanceId: 'm1',
        name: 'Mid',
        card: cardYellow,
      );
      expect(sentOffIn([off, booked]), {'d1'});
      expect(cautionedIn([off, booked]), {'m1'});
    });

    test('and a man who was booked THEN sent off only counts once', () {
      // He is suspended, which outlives the ninety minutes; the rating penalty
      // is for somebody still on the pitch.
      const first = (
        minute: 20,
        instanceId: 'd1',
        name: 'Def',
        card: cardYellow,
      );
      const second = (
        minute: 70,
        instanceId: 'd1',
        name: 'Def',
        card: cardSecondYellow,
      );
      expect(sentOffIn([first, second]), {'d1'});
      expect(cautionedIn([first, second]), isEmpty);
    });
  });

  group('THE RECORD', () {
    Map<String, dynamic> save(List<String> ids) => {
      'grid': {
        'cells': [
          for (final id in ids) <String, dynamic>{'instanceId': id},
        ],
      },
    };

    test('a caution and a sending-off both go on the card', () {
      final state = save(['a', 'b', 'c']);
      recordBookings(state, const [
        (minute: 20, instanceId: 'a', name: 'A', card: cardYellow),
        (minute: 40, instanceId: 'b', name: 'B', card: cardRed),
      ]);
      final cells = (state['grid'] as Map)['cells'] as List;
      expect((cells[0] as Map)['stats'], {'yellows': 1});
      expect((cells[1] as Map)['stats'], {'reds': 1});
      // And a card nothing happened to is left exactly as it was, which is what
      // keeps the parity harness's shape out of this.
      expect((cells[2] as Map).containsKey('stats'), isFalse);
    });

    test('a SECOND yellow counts as both, because it was both', () {
      final state = save(['a']);
      recordBookings(state, const [
        (minute: 20, instanceId: 'a', name: 'A', card: cardYellow),
        (minute: 70, instanceId: 'a', name: 'A', card: cardSecondYellow),
      ]);
      final cell = ((state['grid'] as Map)['cells'] as List).first as Map;
      expect(cell['stats'], {'yellows': 2, 'reds': 1});
    });

    test('it adds to what is already there rather than replacing it', () {
      final state = save(['a']);
      ((state['grid'] as Map)['cells'] as List).first['stats'] = {
        'goals': 3,
        'yellows': 1,
      };
      recordBookings(state, const [
        (minute: 20, instanceId: 'a', name: 'A', card: cardYellow),
      ]);
      final cell = ((state['grid'] as Map)['cells'] as List).first as Map;
      expect(cell['stats'], {'goals': 3, 'yellows': 2});
    });

    test('nothing to record, nothing written', () {
      final state = save(['a']);
      recordBookings(state, const []);
      recordBookings(null, const [
        (minute: 20, instanceId: 'a', name: 'A', card: cardYellow),
      ]);
      expect(((state['grid'] as Map)['cells'] as List).first, {
        'instanceId': 'a',
      });
    });
  });

  group('WHO IS BANNED FROM THE NEXT ONE', () {
    Map<String, dynamic> save(Map<String, int?> bans, {int played = 4}) => {
      'progression': {'matchesPlayed': played},
      'grid': {
        'cells': [
          for (final entry in bans.entries)
            <String, dynamic>{
              'instanceId': entry.key,
              if (entry.value != null) 'suspendedUntilMatch': entry.value,
            },
        ],
      },
    };

    test('the ban is read against the count, not as a countdown', () {
      // Written as the match number he is free again FOR, so nothing has to
      // remember to tick it down and a cloud restore mid-ban is still mid-ban.
      expect(suspendedIn(save({'a': 5, 'b': 4, 'c': null})), {'a'});
    });

    test('and it lapses on its own once the match has been played', () {
      final state = save({'a': 5}, played: 5);
      expect(suspendedIn(state), isEmpty);
    });

    test('a save with no grid, or none at all, bans nobody', () {
      expect(suspendedIn(null), isEmpty);
      expect(suspendedIn(<String, dynamic>{}), isEmpty);
      expect(suspendedIn({'grid': <String, dynamic>{}}), isEmpty);
    });

    test('two reds in a row EXTEND the ban rather than resetting it', () {
      // `applySuspensions` never shortens one — a man sent off while already
      // banned serves both.
      final state = save({'a': 9});
      applySuspensions(state, ['a'], playedSoFar: 4);
      expect(
        ((state['grid'] as Map)['cells'] as List).first['suspendedUntilMatch'],
        9,
      );
      applySuspensions(state, ['a'], playedSoFar: 12);
      expect(
        ((state['grid'] as Map)['cells'] as List).first['suspendedUntilMatch'],
        13,
      );
    });
  });
}
