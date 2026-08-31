/// Colin's voice, wired to the save and to the app's lifecycle.
///
/// The same two jobs [SoundHost] does, and for the same reasons: **nothing calls
/// the service's switches by hand** — the settings screen writes into the save
/// and stops there, and the sync below carries the value in, so a setting that
/// arrives from a migration, a cloud restore or a reset lands the way a tap
/// does; and **the lifecycle half is not a nicety**, because an app that is put
/// away mid-sentence otherwise finishes it into a locked phone.
///
/// **It rides the SOUND setting.** A switch of its own needs a label, a label
/// needs a key in the spec repo's `en.js`, and that repo is not on disk here.
/// See the note in `services/voice_service.dart` — a settings row is owed.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/services/voice_cues.dart';
import 'package:merge_empire_fc/services/voice_service.dart';

/// The voice. One per app.
final voiceServiceProvider = Provider<VoiceService>(
  (ref) => VoiceService(backend: FlutterTtsBackend()),
);

/// Carries the sound settings into it. Watched, never read: the point is that a
/// later change arrives too.
final voiceSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(soundSettingsProvider);
  final voice = ref.watch(voiceServiceProvider);
  unawaited(
    voice.apply(enabled: settings.sound, volume: settings.soundVolume),
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
