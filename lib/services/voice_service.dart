/// Colin, out loud.
///
/// **THE RULES LIVE HERE AND THE PLATFORM LIVES BEHIND [VoiceBackend]**, which
/// is the shape `sound_service.dart` already argues for: every decision about
/// whether a line may be spoken is arithmetic on a handful of fields and none of
/// it needs a device, so all of it is testable and the only untested part is the
/// thin adapter that talks to `flutter_tts`.
///
/// **HE SPEAKS THE DEVICE'S VOICE, not a recorded one, and that is a deliberate
/// first step rather than the finished thing.** A recorded gaffer would sound
/// enormously better and cannot cover this game: his lines are catalogue strings
/// in ten languages, several of them interpolate a player's name or a fee, and
/// `welcome.line` is a pool of five. Nothing pre-rendered can say "Nakamura
/// wants twelve thousand five hundred". So the seam is what matters — swap this
/// backend for one that plays a bundled clip when a line has no parameters, and
/// no call site changes.
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

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// Everything that touches the platform, and nothing else.
abstract class VoiceBackend {
  /// Say [text]. Completes when the utterance has been HANDED OVER, not when it
  /// has finished being spoken — the engines differ on whether they await the
  /// audio, and a service that blocked on it could not stop a line.
  Future<void> speak(
    String text, {
    required String locale,
    required double volume,
    required double rate,
    required double pitch,
  });

  /// Cut whatever is being said.
  Future<void> stop();
}

/// How he talks.
///
/// Slower and lower than the engine's default, which is tuned for reading a
/// notification aloud rather than for a man leaning over a dugout. Both are
/// engine-relative — 1.0 is "whatever this device calls normal" — so they are
/// nudges rather than absolute settings.
const double voiceRate = 0.46;
const double voicePitch = 0.92;

/// Which speech locale each shipped catalogue asks for.
///
/// **The catalogue ids are not speech locales.** `zh` and `pt` in particular are
/// languages rather than voices, and an engine handed a bare language code picks
/// a region for you — which for Portuguese is the difference between Lisbon and
/// São Paulo. English is en-GB: he is a British gaffer, and the JS's copy is
/// written that way ("boss", "the gaffer", "clean sheet").
const Map<String, String> voiceLocales = {
  'en': 'en-GB',
  'es': 'es-ES',
  'pt': 'pt-BR',
  'fr': 'fr-FR',
  'de': 'de-DE',
  'it': 'it-IT',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'zh': 'zh-CN',
  'ar': 'ar-SA',
};

/// What a speech engine should not be handed.
///
/// **The copy is written to be READ**, and the catalogue is full of things that
/// are punctuation to an eye and a word to an engine: the emoji a milestone card
/// carries, the arrows in a stat line, the box-drawing in a table. Engines
/// disagree about what to do with them — some skip, some announce the character
/// by name, and "clean sheet grinning face with smiling eyes" is not a sentence.
final RegExp _unspeakable = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2190}-\u{2BFF}\u{2600}-\u{27BF}\u{FE0F}\u{2022}]',
  unicode: true,
);

/// The line as it should be SAID rather than as it is printed.
String speakable(String line) => line
    .replaceAll(_unspeakable, ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class VoiceService {
  VoiceService({required VoiceBackend backend, String Function()? locale})
    : _backend = backend,
      _locale = locale ?? getLocale;

  final VoiceBackend _backend;

  /// Which catalogue is loaded. Injectable so the locale rule can be tested
  /// without moving the whole app's language.
  final String Function() _locale;

  /// Whether he may speak at all. **Off until told otherwise**: the app's own
  /// settings push the save's value in at boot, and a service that started
  /// talking before that arrived would talk over a player who had muted it.
  bool enabled = false;

  /// The player's own 0..1, the same one the sound effects use.
  double volume = 1;

  bool _suspended = false;

  /// What he is saying, or null. A test seam, and the flag that makes
  /// [silence] cheap when there is nothing to cut.
  String? get saying => _saying;
  String? _saying;

  /// Say a line.
  ///
  /// **One line at a time.** A card can open over a card — a tip queued behind
  /// the welcome-back card is the everyday case — and two Colins talking at once
  /// is worse than either of them. The new line wins, because it is the one the
  /// player is looking at.
  Future<void> say(String line) async {
    if (!enabled || _suspended || volume <= 0) return;
    final text = speakable(line);
    if (text.isEmpty) return;
    if (_saying != null) await _backend.stop();
    _saying = text;
    await _backend.speak(
      text,
      locale: voiceLocales[_locale()] ?? voiceLocales['en']!,
      volume: volume,
      rate: voiceRate,
      pitch: voicePitch,
    );
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

/// The `flutter_tts` adapter. The only thing in the app that imports the plugin.
class FlutterTtsBackend implements VoiceBackend {
  FlutterTtsBackend([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// The locale the engine is currently set to, so a line in the same language
  /// as the last one does not pay for the round trip.
  String? _set;

  /// **iOS SAYS NOTHING UNTIL THE SESSION IS ASKED FOR, which is why he was
  /// silent.** `flutter_tts` leaves the audio session alone unless
  /// `setSharedInstance(true)` is called, and what it falls back to is silenced
  /// by the ring switch and by whatever the game's own player has already
  /// activated - so on a phone that is playing coin sounds perfectly well, the
  /// voice is inaudible and nothing throws.
  ///
  /// The session it asks for is the one `sound_service.dart` already argued
  /// for: PLAYBACK so the ring switch does not silence a line the card is
  /// waiting on, MIXED so the player's podcast keeps running, and DUCKED so
  /// what is playing drops under him instead of burying him. `voicePrompt` is
  /// the mode Apple documents for exactly this - a synthesised line spoken over
  /// other audio.
  ///
  /// Once, lazily, and never fatal: a device with no speech engine at all
  /// throws from whichever call comes first, and a coach card must still open.
  bool _sessionAsked = false;

  /// **Its own try, and only where the calls exist.** Both are iOS/macOS
  /// methods: Android's plugin has no handler for either, so an unguarded pair
  /// here throws a `MissingPluginException` out of the first line of `speak`
  /// and takes the whole utterance with it - the one platform that was working
  /// would have stopped talking to fix the one that was not.
  Future<void> _session() async {
    if (_sessionAsked) return;
    _sessionAsked = true;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } catch (e) {
      debugPrint('voice session: $e');
    }
  }

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required double volume,
    required double rate,
    required double pitch,
  }) async {
    // **EVERY CALL IS GUARDED.** A speech engine is a service on the device that
    // may simply not be there — a stripped Android build, a locale with no voice
    // installed, an emulator — and it reports that by throwing from whichever
    // call happens to be first. A coach card must not fail to open because the
    // phone cannot talk.
    try {
      await _session();
      if (_set != locale) {
        await _tts.setLanguage(locale);
        _set = locale;
      }
      await _tts.setVolume(volume);
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('voice: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('voice: $e');
    }
  }
}
