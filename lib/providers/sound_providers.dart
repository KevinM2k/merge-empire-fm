/// The sound engine, wired to the save and to the app's lifecycle.
///
/// **NOTHING CALLS THE SERVICE'S SWITCHES BY HAND.** The settings screen writes
/// `soundEnabled` / `soundVolume` / `musicEnabled` / `musicVolume` into the save
/// and stops there, exactly as it did when nothing was listening. [soundSyncProvider]
/// is what carries those four to the engine — so a value that arrives from a
/// migration, a cloud restore or a reset lands the same way a tap does, and there
/// is no second place for the two to disagree.
///
/// **THE FIRST SOUND HAS TO BE READY BEFORE IT IS WANTED.** Two dozen effects are
/// synthesised rather than shipped (see `util/audio_render.dart`), which is the
/// better part of a second of arithmetic, so the warm-up starts at boot in an
/// isolate. A tap that arrives before it finishes is silent rather than late: a
/// queued sound firing half a second after the thing it belongs to is worse than
/// no sound at all.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/sound_cues.dart';
import 'package:merge_empire_fc/services/sound_service.dart';

/// The engine. One per app.
final soundServiceProvider = Provider<SoundService>(
  (ref) => SoundService(backend: AudioPlayersBackend()),
);

/// The four save values the engine follows.
final soundSettingsProvider = savePick<
  ({bool sound, double soundVolume, bool music, double musicVolume})
>((s) {
  final settings = s['settings'];
  final map = settings is Map<String, dynamic>
      ? settings
      : const <String, dynamic>{};
  double vol(Object? v) => v is num ? v.toDouble().clamp(0.0, 1.0) : 1.0;
  return (
    sound: map['soundEnabled'] != false,
    soundVolume: vol(map['soundVolume']),
    // Music ships OFF, matching the schema.
    music: map['musicEnabled'] == true,
    musicVolume: vol(map['musicVolume']),
  );
});

/// Pushes the save's four values into the engine whenever they move.
///
/// Watched by [SoundHost] rather than being a listener set up at boot: a provider
/// that is never watched is never built, and this one has to be alive for the
/// whole session.
final soundSyncProvider = Provider<void>((ref) {
  final service = ref.watch(soundServiceProvider);
  final settings = ref.watch(soundSettingsProvider);
  service.setSoundEnabled(settings.sound);
  service.setSoundVolume(settings.soundVolume);
  service.setMusicVolume(settings.musicVolume);
  // Last, and asynchronous: it starts or stops the bed, and it needs the volume
  // above to already be in place or the first frame of the fade is at the old one.
  unawaited(service.setMusicEnabled(settings.music));
});

/// Play one effect, from anywhere.
///
/// A function rather than a widget-tree call so a provider, an engine callback or
/// a button can all reach it the same way. Fire and forget by design — a caller
/// must never be made to await a sound.
void playSound(Ref ref, String name, {bool overlap = false}) {
  unawaited(ref.read(soundServiceProvider).play(name, overlap: overlap));
}

/// The same, from a widget.
void playSoundFrom(WidgetRef ref, String name, {bool overlap = false}) {
  unawaited(ref.read(soundServiceProvider).play(name, overlap: overlap));
}

/// Keeps the engine alive, warm, and told when the app goes away.
///
/// The lifecycle half is not a nicety: without it the OS keeps the music bed
/// playing after the app leaves the foreground and it carries on until the
/// process is killed.
class SoundHost extends ConsumerStatefulWidget {
  const SoundHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SoundHost> createState() => _SoundHostState();
}

class _SoundHostState extends ConsumerState<SoundHost>
    with WidgetsBindingObserver {
  late final SoundService _service;
  late final void Function() _unwireCues;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = ref.read(soundServiceProvider);
    _unwireCues = wireSoundCues(_service);
    // After the first frame: the render is the heaviest thing in the boot and
    // the isolate spawn itself costs a few milliseconds on the main thread.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _service.warmUp();
      if (!mounted) return;
      // The bed can only start once the save's own settings have been pushed in,
      // which the sync provider does on its first build below.
      await _service.startMusic();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The bus holds a strong reference, so a host that forgets this keeps a dead
    // service alive and playing.
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
        // A banner, the app switcher, a phone call. The player has not left, and
        // cutting the music for a notification shade would be worse than not
        // cutting it at all. Same rule the game loop uses — see `GameHost`.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(soundSyncProvider);
    return widget.child;
  }
}
