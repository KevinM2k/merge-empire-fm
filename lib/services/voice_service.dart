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
import 'package:merge_empire_fc/data/sound_defs.dart'
    show coachBabbleCue, coachBabbleScale;
import 'package:merge_empire_fc/i18n/i18n.dart';

/// Everything that touches the platform, and nothing else.
abstract class VoiceBackend {
  /// Play [asset] — a path relative to `assets/`, the way `audioplayers` wants
  /// it. Completes when the clip has been HANDED OVER, not when it has finished
  /// playing: a service that blocked on the audio could not cut a line.
  Future<void> play(String asset, {required double volume});

  /// One syllable of gibberish, by SFX cue name — see [animaleseCues].
  ///
  /// A separate entry point rather than a second `play`, because it is a
  /// different channel: a syllable is a rendered EFFECT out of the sound
  /// service's own cache, not a bundled file, and it stacks rather than
  /// replacing what is already sounding.
  Future<void> blip(String cue, {required double volume});

  /// Cut whatever is playing.
  Future<void> stop();
}

/// How long one syllable takes, and how many a line may run to.
///
/// **The ceiling is the typewriter's.** The card types a line in at 30ms a
/// glyph with a 2s cap, so a voice that ran the length of the text would still
/// be talking over a line that finished long ago. Thirty-six syllables at 55ms
/// is just under two seconds, which is the same ceiling from the other side.
const Duration babbleStep = Duration(milliseconds: 55);
const int babbleMost = 36;

/// **HIS VOICE, as a run of syllables — the Animal Crossing trick.**
///
/// Asked for from the couch. A letter picks a rung of [coachBabbleScale]; a
/// space is a REST, which is what gives the run its words; and a full stop is a
/// longer rest, which is what gives it sentences. Anything else — punctuation
/// inside a word, a digit, a glyph from a script with no Latin letters in it —
/// is skipped rather than voiced, because a voice that clicks on every comma
/// reads as a fault.
///
/// A null entry is a rest. Pure, and that is the point: the whole of what makes
/// this sound like speech rather than like a modem is in this function, and none
/// of it needs a device to test.
///
/// **It is deliberately NOT a hash of the whole word.** Two lines that start the
/// same have to start the same way — that is what makes it read as a voice
/// saying words rather than as noise keyed to a sentence.
List<String?> animaleseCues(String text) {
  final out = <String?>[];
  for (final unit in text.toLowerCase().runes) {
    if (out.length >= babbleMost) break;
    final c = String.fromCharCode(unit);
    if (c == ' ' || c == '\n') {
      // One rest, and never two in a row: a wrapped line or a double space is
      // still one gap between two words.
      if (out.isNotEmpty && out.last != null) out.add(null);
      continue;
    }
    if (c == '.' || c == '!' || c == '?') {
      // A sentence ends in a longer silence — two rests, which at 55ms each is
      // about the beat a reader takes.
      if (out.isNotEmpty && out.last != null) out..add(null)..add(null);
      continue;
    }
    final rung = _rungFor(unit);
    if (rung == null) continue;
    out.add(coachBabbleCue(rung));
  }
  // A run that is nothing but rests is silence, and silence is not a voice.
  return out.any((c) => c != null) ? out : const [];
}

/// Which rung a character speaks on, or null for one that does not speak.
///
/// a–z walk up the bank, which is what makes the same word sound the same way
/// twice. A digit takes the middle of it. Anything else is silent — including
/// every non-Latin script, which is honest: the bank has twelve rungs and no
/// mapping for Japanese kana that would be better than skipping.
int? _rungFor(int unit) {
  const a = 97, z = 122, zero = 48, nine = 57;
  if (unit >= a && unit <= z) {
    return (unit - a) * coachBabbleScale.length ~/ (z - a + 1);
  }
  if (unit >= zero && unit <= nine) return coachBabbleScale.length ~/ 2;
  return null;
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
  Future<void> say(String key, {String text = ''}) async {
    if (!enabled || _suspended || volume <= 0) return;
    if (key.isEmpty && text.isEmpty) return;

    if (key.isNotEmpty) {
      final asset = voiceClipAsset(key, _locale());
      final bundled = await (_loaded ??= _clips());
      if (bundled.contains(asset)) {
        // Checked again: awaiting the manifest gives the card time to close,
        // and a clip that starts after its card has gone is a voice from
        // nowhere.
        if (!enabled || _suspended || volume <= 0) return;
        await silence();
        _saying = asset;
        await _backend.play(asset, volume: volume);
        return;
      }
    }

    // **NO CLIP IS NOT SILENCE ANY MORE.** It was, and it was the normal case:
    // the folder ships empty and half his lines interpolate a name or a fee, so
    // nothing pre-rendered could ever cover them. He gibbers instead — see
    // [animaleseCues] — which needs no recording, no locale and no key, and so
    // covers every line he has rather than the handful somebody sat down and
    // read out. A clip still wins where one exists.
    await _babble(text);
  }

  /// The run of syllables, one every [babbleStep].
  ///
  /// **Its own token rather than a `Timer`**, because the thing that has to be
  /// cancellable is a LOOP with an await in it: a card can close between two
  /// syllables, and a timer cancelled from `silence` would still let the
  /// syllable already scheduled through. Every iteration checks that the run it
  /// belongs to is still the current one.
  Future<void> _babble(String text) async {
    final cues = animaleseCues(text);
    if (cues.isEmpty) return;
    await silence();
    final token = Object();
    _babbling = token;
    _saying = _babbleMark;
    for (final cue in cues) {
      if (_babbling != token || !enabled || _suspended || volume <= 0) return;
      if (cue != null) {
        // **Overlapping**, which is what `blip` is for: at 55ms a step and 90ms
        // a syllable each one is still ringing when the next arrives, and that
        // overlap is most of what makes a run of them read as a voice rather
        // than as a row of beeps.
        await _backend.blip(cue, volume: volume);
      }
      await Future<void>.delayed(babbleStep);
    }
    if (_babbling == token) {
      _babbling = null;
      _saying = null;
    }
  }

  /// The run in flight, or null. Compared by identity — see [_babble].
  Object? _babbling;

  /// What [saying] reads while he is gibbering. Not a path, on purpose: there
  /// is no file, and a caller that treats it as one should fail loudly.
  static const String _babbleMark = 'babble';

  /// Stop him — the card closed, or the setting went off.
  Future<void> silence() async {
    _babbling = null;
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
  ClipVoiceBackend({AudioPlayer? player, Future<void> Function(String cue)? blip})
    : _player = player ?? AudioPlayer(),
      _blip = blip;

  final AudioPlayer _player;

  /// How a syllable is played — the sound service's own `play`, wired in by
  /// `voice_providers.dart`.
  ///
  /// **Handed in rather than reached for.** A syllable is a rendered effect out
  /// of the sound cache, and a voice service that imported the sound service to
  /// get at it would tie the two together for one call. Null is silence, which
  /// is what a test gets.
  final Future<void> Function(String cue)? _blip;

  @override
  Future<void> blip(String cue, {required double volume}) async {
    try {
      await _blip?.call(cue);
    } catch (e) {
      debugPrint('voice: $e');
    }
  }

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
