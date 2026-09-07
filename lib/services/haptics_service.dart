/// The buzz a press answers with.
///
/// **THE RULES LIVE HERE AND THE PLATFORM LIVES BEHIND [HapticsBackend]**, the
/// same split `sound_service.dart` runs on: whether a press may buzz is a
/// switch and a clock, and neither needs a device.
///
/// **IT IS THE PRESS CUE'S OTHER HALF.** The click and the buzz are wired at the
/// same place — the theme's splash factory, see `TapSoundSplash` — so the set of
/// things that buzz is the set of things that visibly respond to a press, and
/// nobody has to keep a list of buttons up to date.
///
/// **`lightImpact`, not `vibrate`.** `HapticFeedback.vibrate()` is the phone's
/// whole vibrator: on iOS it is `kSystemSoundID_Vibrate`, the buzz an alarm
/// uses, which is far too much for a button. `lightImpact` is the platform's own
/// button tap in both stores — `UIImpactFeedbackGenerator(.light)` on iOS and
/// `HapticFeedbackConstants.VIRTUAL_KEY` through `View.performHapticFeedback` on
/// Android. That route needs no permission: `android.permission.VIBRATE` is for
/// driving the motor directly, which is what a vibration PLUGIN does and this
/// does not.
///
/// **The device has the last word, and that is correct.** Android drops the
/// feedback when the player has touch feedback off in system settings; iOS needs
/// a Taptic Engine (iPhone 7 and later) and stays quiet in Low Power Mode or with
/// System Haptics off. Nothing here tries to detect any of that — a game that
/// second-guesses the OS's own accessibility switch is a game that buzzes
/// somebody who asked it not to.
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// **ONE PRESS IS ONE BUZZ.** `SoundService`'s `retriggerFloor` reason, in the
/// other medium and rather more so: the motor has a spin-up, so two impacts
/// inside one frame do not read as two taps but as one longer, muddier one.
/// A little wider than the sound's 70ms because that is the floor a double-tap
/// stops being a double-tap at.
const Duration hapticFloor = Duration(milliseconds: 80);

/// Everything that touches the platform, and nothing else.
abstract class HapticsBackend {
  Future<void> press();
}

/// The real one. Untested by construction — there is nothing here but the call.
class PlatformHapticsBackend implements HapticsBackend {
  const PlatformHapticsBackend();

  @override
  Future<void> press() => HapticFeedback.lightImpact();
}

class HapticsService {
  HapticsService({
    HapticsBackend backend = const PlatformHapticsBackend(),
    DateTime Function()? clock,
  }) : _backend = backend,
       _clock = clock ?? DateTime.now;

  final HapticsBackend _backend;
  final DateTime Function() _clock;

  /// **OFF UNTIL THE SAVE SAYS OTHERWISE.** The setting ships ON — see
  /// `hapticsSyncProvider` — but a service nobody has told is a service that
  /// has not read the player's choice yet, and buzzing before that is read is
  /// buzzing somebody who turned it off.
  bool _enabled = false;
  DateTime? _last;

  bool get enabled => _enabled;

  void setEnabled(bool value) => _enabled = value;

  /// Answer a press. Fire and forget: a caller must never be made to await one.
  void press() {
    if (!_enabled) return;
    final now = _clock();
    final last = _last;
    if (last != null && now.difference(last) < hapticFloor) return;
    _last = now;
    unawaited(_backend.press());
  }
}
