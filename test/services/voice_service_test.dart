/// Colin's voice — the rules, which are all of it that does not need a device.
///
/// The interesting ones are the four that are easy to get wrong and impossible
/// to notice in a simulator: **silent when there is no clip** (which is the
/// normal case, and must cost nothing), **one line at a time** (a tip queued
/// behind the welcome-back card is the everyday case, and two Colins talking
/// over each other is worse than either), **cut on suspend rather than pause**
/// (a sentence cannot be resumed thirty seconds later into a different screen),
/// and **the mute takes effect mid-sentence** (a mute that waits for the full
/// stop is not a mute).
///
/// He was the device's own text-to-speech behind this same seam, and it was
/// horrible; the plugin is gone and a line is a KEY now, played from
/// `assets/voice/<locale>/<key>.mp3` when a clip is there.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/voice_cues.dart';
import 'package:merge_empire_fc/services/voice_service.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

class FakeVoice implements VoiceBackend {
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
  late FakeVoice backend;
  late VoiceService voice;
  String locale = 'en';

  /// Every clip the fake bundle holds: two English, one Portuguese.
  const bundled = <String>{
    'voice/en/coachtip.first.mp3',
    'voice/en/coachtip.second.mp3',
    'voice/pt/coachtip.first.mp3',
  };

  setUp(() {
    backend = FakeVoice();
    locale = 'en';
    voice = VoiceService(
      backend: backend,
      locale: () => locale,
      clips: () async => bundled,
    );
  });

  group('whether he may speak at all', () {
    test('he starts SILENT, before the save has said otherwise', () async {
      // The settings arrive a frame or two after boot. A service that talked in
      // the meantime would talk over a player who had muted the game.
      await voice.say('coachtip.first');
      expect(backend.played, isEmpty);
    });

    test('and speaks once the save has been pushed in', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('coachtip.first');
      expect(backend.played, ['voice/en/coachtip.first.mp3']);
    });

    test('a zero volume is a mute, not a quiet voice', () async {
      await voice.apply(enabled: true, volume: 0);
      await voice.say('coachtip.first');
      expect(backend.played, isEmpty);
    });

    test('and turning him off CUTS him mid-sentence', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('coachtip.first');
      await voice.apply(enabled: false, volume: 1);
      expect(backend.stops, 1, reason: 'a mute that waits is not a mute');
      expect(voice.saying, isNull);
    });
  });

  group('what there is a clip for', () {
    test('A KEY WITH NOTHING RECORDED IS SILENT, and that is the normal case',
        () async {
      // Anything with a name or a fee in it, and anything nobody has got to
      // yet: the card is exactly as it was before the voice existed.
      await voice.apply(enabled: true, volume: 1);
      await voice.say('coachtip.nothing_recorded');
      expect(backend.played, isEmpty);
      expect(voice.saying, isNull);
    });

    test('and so is a card that has no key at all', () async {
      // A pooled line, or one assembled around a figure — see
      // `CoachCardFrame.speaksKey`.
      await voice.apply(enabled: true, volume: 1);
      await voice.say('');
      expect(backend.played, isEmpty);
    });

    test('the clip is the LOCALE\'s, and a locale with none stays quiet', () async {
      await voice.apply(enabled: true, volume: 1);
      locale = 'pt';
      await voice.say('coachtip.first');
      expect(backend.played, ['voice/pt/coachtip.first.mp3']);

      // English has a second line recorded and Portuguese does not: no falling
      // back, because a line in the wrong language is worse than silence.
      await voice.say('coachtip.second');
      expect(backend.played, ['voice/pt/coachtip.first.mp3']);
    });

    test('and the manifest is read once, however many lines are said', () async {
      var reads = 0;
      final once = VoiceService(
        backend: backend,
        locale: () => locale,
        clips: () async {
          reads++;
          return bundled;
        },
      );
      await once.apply(enabled: true, volume: 1);
      await once.say('coachtip.first');
      await once.say('coachtip.second');
      await once.say('coachtip.nothing_recorded');
      expect(reads, 1);
    });
  });

  group('one line at a time', () {
    test('a new line stops the one in flight', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('coachtip.first');
      await voice.say('coachtip.second');
      expect(backend.stops, 1);
      expect(backend.played, [
        'voice/en/coachtip.first.mp3',
        'voice/en/coachtip.second.mp3',
      ]);
    });

    test('and silencing twice costs one stop', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('coachtip.first');
      await voice.silence();
      await voice.silence();
      expect(backend.stops, 1);
    });
  });

  group('the app going away', () {
    test('cuts him, and keeps him cut', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('coachtip.first');
      await voice.suspend();
      expect(backend.stops, 1);

      await voice.say('coachtip.second');
      expect(
        backend.played,
        ['voice/en/coachtip.first.mp3'],
        reason: 'nothing starts while away',
      );
    });

    test('and coming back does NOT finish the sentence', () async {
      // Half a line resumed thirty seconds later, over whatever the player is
      // doing now, is worse than not finishing it.
      await voice.apply(enabled: true, volume: 1);
      await voice.say('coachtip.first');
      await voice.suspend();
      await voice.resume();
      expect(backend.played, ['voice/en/coachtip.first.mp3']);

      await voice.say('coachtip.second');
      expect(backend.played, [
        'voice/en/coachtip.first.mp3',
        'voice/en/coachtip.second.mp3',
      ]);
    });
  });

  group('the bus is the wiring', () {
    test('a line announced on it is spoken, and unwiring stops that', () async {
      await voice.apply(enabled: true, volume: 1);
      final unwire = wireVoiceCues(voice);
      addTearDown(clearBus);

      announceCoachLine('Told you.', key: 'coachtip.first');
      await Future<void>.delayed(Duration.zero);
      expect(backend.played, ['voice/en/coachtip.first.mp3']);

      announceCoachSilence();
      await Future<void>.delayed(Duration.zero);
      expect(backend.stops, 1);

      unwire();
      announceCoachLine('Ignored.', key: 'coachtip.second');
      await Future<void>.delayed(Duration.zero);
      expect(backend.played, ['voice/en/coachtip.first.mp3']);
    });

    test('AND A LINE WITH NO KEY IS ANNOUNCED ANYWAY, for its text', () async {
      // The event carries both halves: the key is what the voice plays and the
      // text is what is on screen, which is all a pooled line has.
      final heard = <String>[];
      on(coachSpeaksEvent, (args) {
        final text = args is Map<String, dynamic> ? args['text'] : null;
        if (text is String) heard.add(text);
      });
      addTearDown(clearBus);
      await voice.apply(enabled: true, volume: 1);
      wireVoiceCues(voice);

      announceCoachLine('Nakamura wants 12,500.');
      await Future<void>.delayed(Duration.zero);
      expect(heard, ['Nakamura wants 12,500.']);
      expect(backend.played, isEmpty, reason: 'nothing to play it from');
    });
  });
}
