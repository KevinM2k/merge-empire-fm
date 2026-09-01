/// Colin's own audio channel, as the save sees it.
///
/// He rode the SFX toggle while he had no label of his own, which meant the
/// only way to stop him talking was to mute the coin sounds with him. The two
/// rules worth pinning are the pair that arrangement could not express: **his
/// switch is his own**, and **the master sound switch still silences him** —
/// a player who has muted the game has muted the game.
///
/// **And neither key is in `createDefaultState`**, deliberately: that map is
/// compared field for field against the JS's by `game_state_test`, so a
/// port-only setting that reads correctly when it is MISSING stays out of it.
/// The first test here is that reading, not a formality.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/providers/voice_providers.dart';
import 'package:merge_empire_fc/services/voice_service.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

class _FakeVoice implements VoiceBackend {
  final List<String> played = [];
  final List<double> volumes = [];

  /// The gibberish syllables, in the order they were asked for.
  final List<String> blips = [];
  int stops = 0;

  @override
  Future<void> play(String asset, {required double volume}) async {
    played.add(asset);
    volumes.add(volume);
  }

  @override
  Future<void> blip(String cue, {required double volume}) async =>
      blips.add(cue);

  @override
  Future<void> stop() async => stops++;
}

void main() {
  late _FakeVoice backend;

  ProviderContainer boot(Map<String, Object?> settings) {
    backend = _FakeVoice();
    final state = createDefaultState();
    (state['settings'] as Map<String, dynamic>).addAll(settings);
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
        ),
        voiceServiceProvider.overrideWith(
          (ref) => VoiceService(backend: backend),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameProvider).load();
    container.read(voiceSyncProvider);
    return container;
  }

  test('a save that has never touched the row hears him at full volume', () {
    final container = boot(const {});
    final voice = container.read(voiceServiceProvider);
    expect(voice.enabled, isTrue);
    expect(voice.volume, 1);
  });

  test('HIS SWITCH IS HIS OWN, and the coin sounds keep playing', () {
    final container = boot(const {'voiceEnabled': false});
    final voice = container.read(voiceServiceProvider);
    expect(voice.enabled, isFalse);
    // The thing this whole channel exists for: SFX are untouched.
    expect(container.read(soundSettingsProvider).sound, isTrue);
  });

  test('and his volume is his own too', () {
    final container = boot(const {'voiceVolume': 0.4, 'soundVolume': 1});
    expect(container.read(voiceServiceProvider).volume, 0.4);
  });

  test('BUT MUTING THE GAME MUTES HIM', () {
    // A player who has muted the game has muted the game — a gaffer talking
    // out of a phone that is supposed to be silent is the one outcome nobody
    // wants.
    final container = boot(const {'soundEnabled': false});
    expect(container.read(voiceServiceProvider).enabled, isFalse);
  });
}
