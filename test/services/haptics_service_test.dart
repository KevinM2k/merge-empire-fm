/// The buzz's rules, which is all of it that is not the platform.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/haptics_service.dart';

class _Backend implements HapticsBackend {
  int calls = 0;

  @override
  Future<void> press() async => calls++;
}

void main() {
  late _Backend backend;
  late DateTime now;
  late HapticsService haptics;

  setUp(() {
    backend = _Backend();
    now = DateTime(2026);
    haptics = HapticsService(backend: backend, clock: () => now);
  });

  test('SAYS NOTHING UNTIL THE SAVE HAS BEEN READ', () {
    // A service nobody has told yet has not seen the player's switch, and
    // buzzing before it does is buzzing somebody who turned it off.
    expect(haptics.enabled, isFalse);
    haptics.press();
    expect(backend.calls, 0);
  });

  test('and nothing at all once the switch is off again', () {
    haptics.setEnabled(true);
    haptics.press();
    expect(backend.calls, 1);
    haptics.setEnabled(false);
    now = now.add(const Duration(seconds: 1));
    haptics.press();
    expect(backend.calls, 1);
  });

  group('one press is one buzz', () {
    setUp(() => haptics.setEnabled(true));

    test('a burst inside the floor is a single impact', () {
      // The motor has a spin-up: four impacts in one frame are not four taps,
      // they are one longer, muddier one. `SoundService`'s rule, in the other
      // medium.
      for (var i = 0; i < 4; i++) {
        haptics.press();
      }
      expect(backend.calls, 1);
    });

    test('and a press past the floor is its own', () {
      haptics.press();
      now = now.add(hapticFloor + const Duration(milliseconds: 1));
      haptics.press();
      expect(backend.calls, 2);
    });

    test('the floor runs from the buzz, not from the press that was dropped', () {
      // Otherwise a fast enough drum-roll holds the floor open forever and the
      // second buzz never lands.
      haptics.press();
      now = now.add(hapticFloor ~/ 2);
      haptics.press();
      now = now.add(hapticFloor ~/ 2 + const Duration(milliseconds: 1));
      haptics.press();
      expect(backend.calls, 2);
    });
  });
}
