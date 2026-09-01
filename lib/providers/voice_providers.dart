/// Colin's voice, wired to the save and to the app's lifecycle.
///
/// The same two jobs [SoundHost] does, and for the same reasons: **nothing calls
/// the service's switches by hand** — the settings screen writes into the save
/// and stops there, and the sync below carries the value in, so a setting that
/// arrives from a migration, a cloud restore or a reset lands the way a tap
/// does; and **the lifecycle half is not a nicety**, because an app that is put
/// away mid-sentence otherwise finishes it into a locked phone.
///
/// **AND HE HAS HIS OWN CHANNEL NOW.** He rode the SFX toggle, on the reasoning
/// that a switch of his own needs a label and a label needs a key in the spec
/// repo's `en.js` - which is not on disk here. That was the wrong trade: riding
/// the SFX toggle means the only way to stop him talking is to mute the coin
/// sounds too, and a voice is the one channel a player most wants to turn off
/// on its own. `coach.label` is his name, shipped in ten languages, and beside
/// a megaphone in the audio list it names the channel without a new key.
///
/// The debt that is left is real and smaller: the row is labelled with his NAME
/// rather than with the word "voice".
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/services/voice_cues.dart';
import 'package:merge_empire_fc/services/voice_service.dart';

/// The voice. One per app.
final voiceServiceProvider = Provider<VoiceService>(
  (ref) => VoiceService(
    backend: ClipVoiceBackend(
      // **The syllables come out of the SOUND cache**, which is where every
      // other rendered effect in the game lives — see `coachBabbleScale`. Wired
      // here rather than imported inside the voice service, so the two services
      // stay independent and a test gets silence for free. `overlap` because a
      // 90ms syllable every 55ms is still ringing when the next lands, and that
      // overlap is most of what makes a run of them read as a voice.
      blip: (cue) => ref.read(soundServiceProvider).play(cue, overlap: true),
    ),
  ),
);

/// His two save values, and nothing else's.
///
/// **Absent by default, and that is deliberate.** `createDefaultState` is
/// compared field for field against the JS's by `game_state_test`, and that
/// fixture cannot be regenerated from this repo - so a port-only setting that
/// reads correctly when it is MISSING has no business being written into the
/// schema. Both do: unset means on, at full volume, and the row writes a key
/// the first time it is touched.
final voiceSettingsProvider = savePick<({bool voice, double volume})>((s) {
  final settings = s['settings'];
  final map = settings is Map<String, dynamic>
      ? settings
      : const <String, dynamic>{};
  return (
    voice: map['voiceEnabled'] != false,
    volume: map['voiceVolume'] is num
        ? (map['voiceVolume'] as num).toDouble().clamp(0.0, 1.0)
        : 1.0,
  );
});

/// Carries them into the service. Watched, never read: the point is that a
/// later change arrives too.
///
/// **The master SFX switch still silences him**, which is not the same thing as
/// riding it: a player who has muted the game has muted the game, and a gaffer
/// talking out of a phone that is supposed to be silent is the one outcome
/// nobody wants. His own switch turns him off without touching the rest.
final voiceSyncProvider = Provider<void>((ref) {
  final sound = ref.watch(soundSettingsProvider);
  final mine = ref.watch(voiceSettingsProvider);
  final voice = ref.watch(voiceServiceProvider);
  unawaited(
    voice.apply(
      enabled: sound.sound && mine.voice,
      volume: mine.volume,
    ),
  );
});

/// Keeps the voice wired to the bus and told when the app goes away.
class VoiceHost extends ConsumerStatefulWidget {
  const VoiceHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<VoiceHost> createState() => _VoiceHostState();
}

class _VoiceHostState extends ConsumerState<VoiceHost>
    with WidgetsBindingObserver {
  late final VoiceService _service;
  late final void Function() _unwireCues;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = ref.read(voiceServiceProvider);
    _unwireCues = wireVoiceCues(_service);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unwireCues();
    unawaited(_service.suspend());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_service.resume());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_service.suspend());
      case AppLifecycleState.inactive:
        // A banner or the app switcher. The player has not left — and unlike the
        // music, a sentence cut here cannot be resumed, so cutting it for a
        // notification shade would lose the line outright.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(voiceSyncProvider);
    return widget.child;
  }
}
