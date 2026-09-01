/// Colin, out loud.
///
/// **THE RULES LIVE HERE AND THE PLATFORM LIVES BEHIND [VoiceBackend]**, which
/// is the shape `sound_service.dart` already argues for: every decision about
/// whether a line may be spoken is arithmetic on a handful of fields and none of
/// it needs a device, so all of it is testable and the only untested part is the
/// thin adapter that talks to `flutter_tts`.
///
/// **HE SPEAKS FROM A FOLDER OF CLIPS, and says nothing when there is no clip
/// for the line.** The device voice went in first, behind this same seam, and it
/// was horrible: `flutter_tts` reads a gaffer's line the way a phone reads a
/// notification, and the ten locales it has to cover make that worse rather than
/// better. Asked for from the couch, and the plugin is gone with it — pubspec
/// line, pod and all.
///
/// So a line is a KEY now, not a sentence. Drop `assets/voice/<locale>/<key>.mp3`
/// in and that line is spoken; ship none and the game is exactly as silent as it
/// was before any of this. The lookup is a manifest read once — see
/// [voiceClipsFrom] — because asking the platform to play a file that is not
/// there is an exception per card rather than a no-op.
///
/// **What it cannot do is the reason the device voice was tried at all.**
/// Several of his lines interpolate a player's name or a fee, and nothing
/// pre-rendered can say "Nakamura wants twelve thousand five hundred". Those
/// keys simply have no clip, so they stay quiet: the cards that are worth
/// recording are the story beats, which are fixed sentences.
///
/// **NOT EVERY CARD TALKS.** The voice is opt-in per card (`speaks:` on
/// `showCoachCard`), because the same shape carries a story beat and a
/// confirmation dialog: being told out loud that the club has reached a
/// competition with a cup in it is the point, and being read the words "Sell
/// Nakamura?" every time you tap sell is not. See `ui/popups/coach_card.dart`.
///
/// **HE HAS HIS OWN CHANNEL, under the master sound switch.** He rode the SFX
/// toggle at first, for want of a label - and that meant the only way to stop
/// him talking was to mute the coin sounds with him. `voiceEnabled` and
/// `voiceVolume` are his; muting the game still mutes him. The row is labelled
/// with `coach.label`, his own name, because no new `t()` key can be added
/// here. See `providers/voice_providers.dart`.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;
import 'package:merge_empire_fc/i18n/i18n.dart';

/// Everything that touches the platform, and nothing else.
abstract class VoiceBackend {
  /// Play [asset] — a path relative to `assets/`, the way `audioplayers` wants
  /// it. Completes when the clip has been HANDED OVER, not when it has finished
  /// playing: a service that blocked on the audio could not cut a line.
  Future<void> play(String asset, {required double volume});

  /// Cut whatever is playing.
  Future<void> stop();
}

/// Where a line's clip lives, given the catalogue it is written in.
///
/// A path relative to `assets/`, because that is what `audioplayers` takes and
/// what `sound_service.dart` already passes. The folder is per LOCALE and the
/// file is the catalogue KEY, so dropping a clip in is the whole of adding a
/// spoken line — there is no list to keep in step.
String voiceClipAsset(String key, String locale) =>
    '$voiceClipDir/$locale/$key.mp3';

/// The folder, under `assets/`. Declared in pubspec per locale.
const String voiceClipDir = 'voice';

/// Which clips are actually bundled, off the asset manifest.
///
/// **Read once, and not by trying to play.** A missing clip reported as a
/// platform exception is a thrown error per card on a game that ships none of
/// them, and the manifest is the only thing that can answer the question
/// cheaply. Keys keep the `assets/` prefix off, so this set is comparable with
/// [voiceClipAsset].
Future<Set<String>> voiceClipsFrom(AssetBundle bundle) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    return {
      for (final path in manifest.listAssets())
        if (path.startsWith('assets/$voiceClipDir/'))
          path.substring('assets/'.length),
    };
  } catch (e) {
    debugPrint('voice manifest: $e');
    return const <String>{};
  }
}

class VoiceService {
  VoiceService({
    required VoiceBackend backend,
    String Function()? locale,
    Future<Set<String>> Function()? clips,
  }) : _backend = backend,
       _locale = locale ?? getLocale,
       _clips = clips ?? (() => voiceClipsFrom(rootBundle));

  final VoiceBackend _backend;

  /// Which catalogue is loaded. Injectable so the locale rule can be tested
  /// without moving the whole app's language.
  final String Function() _locale;

  /// Which clips are bundled. Injectable for the same reason, and awaited once:
  /// the manifest does not change while the app is running.
  final Future<Set<String>> Function() _clips;
  Future<Set<String>>? _loaded;

  /// Whether he may speak at all. **Off until told otherwise**: the app's own
  /// settings push the save's value in at boot, and a service that started
  /// talking before that arrived would talk over a player who had muted it.
  bool enabled = false;

  /// The player's own 0..1, the same one the sound effects use.
  double volume = 1;

  bool _suspended = false;

  /// Which clip is playing, or null. A test seam, and the flag that makes
  /// [silence] cheap when there is nothing to cut.
  String? get saying => _saying;
  String? _saying;

  /// Say the line for [key].
  ///
  /// **Silent when there is no clip, and that is the normal case.** A key with
  /// nothing recorded for it — anything with a name or a fee in it, anything
  /// nobody has got to yet — leaves the card exactly as it was before the voice
  /// existed. No lookup, no exception, no log.
  ///
  /// **One line at a time.** A card can open over a card — a tip queued behind
  /// the welcome-back card is the everyday case — and two Colins talking at once
  /// is worse than either of them. The new line wins, because it is the one the
  /// player is looking at.
  Future<void> say(String key) async {
    if (!enabled || _suspended || volume <= 0 || key.isEmpty) return;
    final asset = voiceClipAsset(key, _locale());
    final bundled = await (_loaded ??= _clips());
    if (!bundled.contains(asset)) return;
    // Checked again: awaiting the manifest gives the card time to close, and a
    // clip that starts after its card has gone is a voice from nowhere.
    if (!enabled || _suspended || volume <= 0) return;
    if (_saying != null) await _backend.stop();
    _saying = asset;
    await _backend.play(asset, volume: volume);
  }

  /// Stop him — the card closed, or the setting went off.
  Future<void> silence() async {
    if (_saying == null) return;
    _saying = null;
    await _backend.stop();
  }

  /// Push the save's values in. Turning the voice off silences him mid-sentence
  /// rather than at the end of it: a mute that waits is not a mute.
  Future<void> apply({required bool enabled, required double volume}) async {
    this.enabled = enabled;
    this.volume = volume;
    if (!enabled || volume <= 0) await silence();
  }

  /// The app went away.
  ///
  /// **Cut, do not pause.** The music bed pauses in place because a loop resumes
  /// invisibly; half a sentence resumed thirty seconds later, out of context and
  /// over whatever the player is doing now, is worse than not finishing it.
  Future<void> suspend() async {
    _suspended = true;
    await silence();
  }

  Future<void> resume() async => _suspended = false;
}

/// The `audioplayers` adapter, and the only part of the voice that touches the
/// platform.
///
/// One player, reused: he says one line at a time by construction — see
/// [VoiceService.say] — so a pool would only ever hold one live clip and a
/// second would be two Colins talking.
class ClipVoiceBackend implements VoiceBackend {
  ClipVoiceBackend([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String asset, {required double volume}) async {
    // **GUARDED, like every call in the sound backend.** A clip that is in the
    // manifest and unplayable — a truncated file, a codec the device does not
    // have — must not take the card down with it.
    try {
      await _player.setVolume(volume);
      await _player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('voice: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('voice: $e');
    }
  }
}
