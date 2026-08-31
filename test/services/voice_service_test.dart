/// Colin's voice — the rules, which are all of it that does not need a device.
///
/// The interesting ones are the three that are easy to get wrong and impossible
/// to notice in a simulator: **one line at a time** (a tip queued behind the
/// welcome-back card is the everyday case, and two Colins talking over each
/// other is worse than either), **cut on suspend rather than pause** (a sentence
/// cannot be resumed thirty seconds later into a different screen), and **the
/// mute takes effect mid-sentence** (a mute that waits for the full stop is not
/// a mute).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/services/voice_cues.dart';
import 'package:merge_empire_fc/services/voice_service.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

class FakeVoice implements VoiceBackend {
  final List<String> spoken = [];
  final List<String> locales = [];
  final List<double> volumes = [];
  int stops = 0;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required double volume,
    required double rate,
    required double pitch,
  }) async {
    spoken.add(text);
    locales.add(locale);
    volumes.add(volume);
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  late FakeVoice backend;
  late VoiceService voice;
  String locale = 'en';

  setUp(() {
    backend = FakeVoice();
    locale = 'en';
    voice = VoiceService(backend: backend, locale: () => locale);
  });

  group('whether he may speak at all', () {
    test('he starts SILENT, before the save has said otherwise', () async {
      // The settings arrive a frame or two after boot. A service that talked in
      // the meantime would talk over a player who had muted the game.
      await voice.say('Back at last, boss.');
      expect(backend.spoken, isEmpty);
    });

    test('and speaks once the save has been pushed in', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('Back at last, boss.');
      expect(backend.spoken, ['Back at last, boss.']);
    });

    test('a zero volume is a mute, not a quiet voice', () async {
      await voice.apply(enabled: true, volume: 0);
      await voice.say('Back at last, boss.');
      expect(backend.spoken, isEmpty);
    });

    test('and turning him off CUTS him mid-sentence', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('Back at last, boss.');
      await voice.apply(enabled: false, volume: 1);
      expect(backend.stops, 1, reason: 'a mute that waits is not a mute');
      expect(voice.saying, isNull);
    });
  });

  group('one line at a time', () {
    test('a new line stops the one in flight', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('First.');
      await voice.say('Second.');
      expect(backend.stops, 1);
      expect(backend.spoken, ['First.', 'Second.']);
    });

    test('and silencing twice costs one stop', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('First.');
      await voice.silence();
      await voice.silence();
      expect(backend.stops, 1);
    });
  });

  group('the app going away', () {
    test('cuts him, and keeps him cut', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('First.');
      await voice.suspend();
      expect(backend.stops, 1);

      await voice.say('Second.');
      expect(backend.spoken, ['First.'], reason: 'nothing starts while away');
    });

    test('and coming back does NOT finish the sentence', () async {
      // Half a line resumed thirty seconds later, over whatever the player is
      // doing now, is worse than not finishing it.
      await voice.apply(enabled: true, volume: 1);
      await voice.say('First.');
      await voice.suspend();
      await voice.resume();
      expect(backend.spoken, ['First.']);

      await voice.say('Second.');
      expect(backend.spoken, ['First.', 'Second.']);
    });
  });

  group('what he is handed', () {
    test('the emoji a milestone card carries is not read out', () async {
      // The badge is the card's; the sentence sometimes carries one too, and
      // "grinning face with smiling eyes" is not a sentence.
      expect(speakable('Promoted! 🏆 Onwards.'), 'Promoted! Onwards.');
      expect(speakable('Up ↑ 12'), 'Up 12');
    });

    test('a line that is nothing BUT symbols is not spoken', () async {
      await voice.apply(enabled: true, volume: 1);
      await voice.say('⚽ 🏆');
      expect(backend.spoken, isEmpty);
    });

    test('the words are otherwise left exactly alone', () {
      const line = "Nakamura wants 12,500 — that's steep, boss.";
      expect(speakable(line), line);
    });
  });

  group('the locale', () {
    test('is the catalogue that is loaded, as a SPEECH locale', () async {
      // `pt` and `zh` are languages, not voices: an engine handed a bare code
      // picks a region for you, which for Portuguese is Lisbon or São Paulo.
      await voice.apply(enabled: true, volume: 1);
      await voice.say('One.');
      locale = 'pt';
      await voice.say('Two.');
      expect(backend.locales, ['en-GB', 'pt-BR']);
    });

    test('and every shipped catalogue has one', () {
      expect(voiceLocales.keys.toSet(), localeIds.toSet());
    });

    test('an unknown catalogue falls back to English rather than failing', () async {
      await voice.apply(enabled: true, volume: 1);
      locale = 'xx';
      await voice.say('One.');
      expect(backend.locales, ['en-GB']);
    });
  });

  group('the bus is the wiring', () {
    test('a line announced on it is spoken, and unwiring stops that', () async {
      await voice.apply(enabled: true, volume: 1);
      final unwire = wireVoiceCues(voice);
      addTearDown(clearBus);

      announceCoachLine('Told you.');
      await Future<void>.delayed(Duration.zero);
      expect(backend.spoken, ['Told you.']);

      announceCoachSilence();
      await Future<void>.delayed(Duration.zero);
      expect(backend.stops, 1);

      unwire();
      announceCoachLine('Ignored.');
      await Future<void>.delayed(Duration.zero);
      expect(backend.spoken, ['Told you.']);
    });
  });
}
