/// **HIS VOICE, as a run of syllables — the Animal Crossing trick.**
///
/// The device voice went first and a folder of clips replaced it; the folder
/// ships empty and half his lines interpolate a name or a fee, so in practice he
/// has been silent. Asked for from the couch: gibberish instead.
///
/// Everything worth checking is in [animaleseCues], which is pure — the whole of
/// what makes this read as speech rather than as a modem lives there, and none
/// of it needs a device.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/sound_defs.dart';
import 'package:merge_empire_fc/services/voice_service.dart';

void main() {
  group('the syllables', () {
    test('a letter speaks, and the SAME letter speaks the same way', () {
      // Not a hash of the word: two lines that start alike have to start alike,
      // which is what makes it read as a voice saying words.
      expect(animaleseCues('a'), animaleseCues('a'));
      expect(animaleseCues('ab').first, animaleseCues('ac').first);
      expect(animaleseCues('a').first, isNot(animaleseCues('z').first));
    });

    test('and every cue it names is a real effect', () {
      // A cue with no recipe is silence, and `play` swallows a missing name
      // rather than throwing — so nothing else in the game would ever say so.
      for (final cue in animaleseCues('the quick brown fox 1234')) {
        if (cue == null) continue;
        expect(soundDefs[cue], isNotNull, reason: cue);
      }
    });

    test('A SPACE IS A REST, which is what gives it words', () {
      final cues = animaleseCues('ab cd');
      expect(cues, hasLength(5));
      expect(cues[2], isNull);
      expect(cues.where((c) => c == null), hasLength(1));
    });

    test('and two spaces are still one gap', () {
      expect(animaleseCues('ab  cd').where((c) => c == null), hasLength(1));
      expect(animaleseCues('ab\ncd').where((c) => c == null), hasLength(1));
    });

    test('A FULL STOP IS A LONGER ONE, which is what gives it sentences', () {
      final cues = animaleseCues('ab. cd');
      expect(cues.where((c) => c == null), hasLength(2));
      expect(cues[1], isNull);
      expect(cues[2], isNull);
    });

    test('and it never OPENS on a rest', () {
      // A line that starts with a space or a stop would begin in silence, which
      // reads as the voice being late rather than as a pause.
      expect(animaleseCues('  ab').first, isNotNull);
      expect(animaleseCues('. ab').first, isNotNull);
    });

    test('punctuation inside a word is SKIPPED, not voiced', () {
      // A voice that clicks on every comma reads as a fault.
      expect(animaleseCues("don't"), hasLength(4));
      expect(animaleseCues('a,b'), hasLength(2));
    });

    test('and a script the bank has no mapping for stays quiet', () {
      // Twelve rungs and no honest mapping for kana. Silence is the right
      // answer; a rung picked out of a code point is noise keyed to nothing.
      expect(animaleseCues('こんにちは'), isEmpty);
      expect(animaleseCues('   '), isEmpty);
      expect(animaleseCues(''), isEmpty);
    });

    test('IT IS CAPPED AT THE TYPEWRITER\'S OWN CEILING', () {
      // The card types a line in at 30ms a glyph with a 2s cap, so a voice that
      // ran the length of the text would still be talking over a line that
      // finished long ago.
      final long = animaleseCues('lorem ipsum dolor sit amet ' * 20);
      expect(long, hasLength(babbleMost));
      expect(babbleStep * babbleMost, lessThan(const Duration(seconds: 2)));
    });
  });

  /// **A CARD BUILT IS NOT A CARD BEING READ.**
  ///
  /// The line was announced from `initState`, so a coach card constructed behind
  /// a scout reveal — or behind the boot splash, which is a sibling of the app
  /// rather than a route — gibbered at something the player was not looking at.
  /// Reported from the couch. The announce now waits for the typewriter to have
  /// actually typed a character, and an `AnimationController` on a
  /// `SingleTickerProviderStateMixin` does not advance under a muted
  /// `TickerMode`.
  ///
  /// **AND IT IS HELD, NOT DROPPED.** Muting the voice for the splash was the
  /// first answer and it traded the fault for a worse one — the line was
  /// announced, refused, and never heard at all. So the card WAITS: `_announced`
  /// is not set until the line actually goes out, the typewriter is ticking, and
  /// the question is asked again every frame until either the card is on top or
  /// the line has finished typing. A line that finished behind something was
  /// never heard, which is right.
  ///
  /// Two things cover the app without telling it, and neither is a route:
  /// `BootSplash` is a SIBLING of the app, and the scout reveal is an
  /// `OverlayEntry`. Both bump `screenCoveredProvider`, which is the counter the
  /// shell already keeps for a modal sheet — the same hole.
  group('and he is quiet while it is suspended', () {
    test('suspend cuts him and nothing gets through until resume', () async {
      final backend = _Recorder();
      final voice = VoiceService(
        backend: backend,
        locale: () => 'en',
        clips: () async => const <String>{},
      )..enabled = true;

      await voice.suspend();
      await voice.say('', text: 'get in there');
      expect(backend.blips, isEmpty, reason: 'he talked over the splash');

      await voice.resume();
      await voice.say('', text: 'get in there');
      expect(backend.blips, isNotEmpty);
    });
  });

  group('the bank', () {
    test('rises, and every rung of it is a real effect', () {
      for (var i = 0; i < coachBabbleScale.length; i++) {
        expect(soundDefs[coachBabbleCue(i)], isNotNull, reason: 'rung $i');
        if (i > 0) {
          expect(coachBabbleScale[i], greaterThan(coachBabbleScale[i - 1]));
        }
      }
    });

    test('and it is a SPEAKING range, not a run of beeps', () {
      // Low enough to be a voice and high enough to carry on a phone speaker.
      expect(coachBabbleScale.first, greaterThan(200));
      expect(coachBabbleScale.last, lessThan(1200));
    });

    test('a rung past either end sits on the end rather than throwing', () {
      expect(coachBabbleCue(999), coachBabbleCue(coachBabbleScale.length - 1));
      expect(coachBabbleCue(-1), coachBabbleCue(0));
    });
  });
}

class _Recorder implements VoiceBackend {
  final List<String> blips = [];

  @override
  Future<void> play(String asset, {required double volume}) async {}

  @override
  Future<void> blip(String cue, {required double volume}) async =>
      blips.add(cue);

  @override
  Future<void> stop() async {}
}
