/// What makes Colin speak, and what shuts him up.
///
/// **THROUGH THE BUS, the way every sound in the game already is.** The
/// alternative is a `voice.say(...)` next to the card, which means the popup
/// layer imports a speech engine and a widget test needs one — and it means the
/// same line is spoken when it arrives one way and silent when it arrives
/// another. `sound_cues.dart` makes this argument at length; this is the same
/// argument for the same reason.
///
/// It also buys the thing the voice most needs: **nothing is wired in a test**,
/// so a card under test emits into an empty bus and no device is touched.
library;

import 'package:merge_empire_fc/services/voice_service.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// A line of his has arrived on screen. `{'key': String, 'text': String}`.
///
/// **Both halves.** The KEY is what the voice plays — a clip is
/// `assets/voice/<locale>/<key>.mp3`, see `voice_service.dart` — and the TEXT is
/// what is actually on screen, which is the only thing a caller with a pooled or
/// interpolated line can hand over. A listener that wants to caption him wants
/// the text; the one that speaks him wants the key.
const String coachSpeaksEvent = 'coach:speaks';

/// The card carrying it has gone.
const String coachSilenceEvent = 'coach:silence';

/// Announce a line, for a card that has asked to be spoken.
///
/// [key] is empty for a card whose line is not a catalogue string — a pool, or a
/// sentence with a fee in it. Nothing is spoken for those, which is the same
/// answer as a key with no clip recorded.
void announceCoachLine(String text, {String key = ''}) =>
    emit(coachSpeaksEvent, <String, dynamic>{'key': key, 'text': text});

/// And that it is over.
void announceCoachSilence() => emit(coachSilenceEvent);

/// Subscribes [service] to the bus, and hands back the teardown.
///
/// Returned rather than left registered: the bus holds strong references, so a
/// host that forgets this keeps a dead service alive and talking.
void Function() wireVoiceCues(VoiceService service) {
  void speak(Object? args) {
    final key = args is Map<String, dynamic> ? args['key'] : null;
    if (key is String && key.isNotEmpty) service.say(key).ignore();
  }

  void silence(Object? _) => service.silence().ignore();

  on(coachSpeaksEvent, speak);
  on(coachSilenceEvent, silence);
  return () {
    off(coachSpeaksEvent, speak);
    off(coachSilenceEvent, silence);
  };
}
