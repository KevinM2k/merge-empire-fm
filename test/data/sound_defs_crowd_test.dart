/// The crowd, and the two boost cues.
///
/// **The crowd is a deferral being cashed in.** `sound_defs.dart` recorded that
/// the JS's three cheers were unwired, that two hundred lines of DSP for a call
/// nobody makes is what the standing rules say not to port, and that a real
/// cheer would be a sample. Crowd Roar is the caller — so the synth came across
/// rather than a sample, because it exists, it is documented, and the bandpass
/// it needs was already here.
///
/// "Does it sound like a crowd" is not a test. What is: the recipes exist, they
/// render to something, the three sizes are three different things, and the
/// tier cue is not loudness — the JS's own note is that the master compressor
/// makes loudness unusable as a cue, so a test that asserted "roar is louder"
/// would be asserting the one thing the design says it is not.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/sound_defs.dart';
import 'package:merge_empire_fc/util/audio_render.dart';

double _rms(Float32List b) =>
    math.sqrt(b.fold<double>(0, (a, v) => a + v * v) / b.length);

double _peak(Float32List b) => b.fold(0, (a, v) => math.max(a, v.abs()));

Float32List _raw(String name) {
  final def = soundDefs[name]!;
  final r = Render(seconds: def.seconds + 0.05);
  def.build(r);
  return r.out;
}

void main() {
  group('the crowd', () {
    const sizes = ['crowdCheerSmall', 'crowdCheerMid', 'crowdCheerRoar'];

    test('THE THREE ARE HERE, at the spec\'s own lengths', () {
      expect(soundDefs['crowdCheerSmall']?.seconds, 0.75);
      expect(soundDefs['crowdCheerMid']?.seconds, 0.95);
      expect(soundDefs['crowdCheerRoar']?.seconds, 1.05);
    });

    test('each renders to a real signal, and a WAV', () {
      for (final name in sizes) {
        expect(_rms(_raw(name)), greaterThan(0.005), reason: name);
        expect(renderSound(name), isNotEmpty, reason: name);
        expect(soundLength(name).inMilliseconds, greaterThan(700), reason: name);
      }
    });

    test('they are three different things, not one at three volumes', () {
      final small = _raw('crowdCheerSmall');
      final roar = _raw('crowdCheerRoar');
      expect(roar.length, greaterThan(small.length));
      final shared = math.min(small.length, roar.length);
      var same = 0;
      for (var i = 0; i < shared; i++) {
        if ((small[i] - roar[i]).abs() < 1e-9) same++;
      }
      expect(same / shared, lessThan(0.5), reason: 'the two are near-identical');
    });

    // The bowl is most of why a big crowd sounds big — the JS calls reverb the
    // strongest of its four cues. So the roar carries energy after every voice
    // has stopped, where the dry small crowd does not.
    test('THE ROAR HAS A TAIL AND THE SMALL CROWD BARELY DOES', () {
      double tail(String name, double from) {
        final out = _raw(name);
        final i = (from * audioSampleRate).round();
        return _rms(Float32List.sublistView(out, i));
      }
      // Small: body ends by 0.75 - 0.05 = 0.70. Roar: body ends by 1.05 - 0.34 = 0.71.
      final small = tail('crowdCheerSmall', 0.72);
      final roar = tail('crowdCheerRoar', 0.72);
      expect(roar, greaterThan(small * 3));
    });
  });

  group('the boost cues', () {
    test('VAR and the sponge each have a recipe that renders', () {
      for (final name in ['boostVar', 'boostPhysio']) {
        final def = soundDefs[name];
        expect(def, isNotNull, reason: name);
        expect(def!.seconds, greaterThan(0));
        expect(_rms(_raw(name)), greaterThan(0.002), reason: name);
      }
    });

    // The drama of a review is the PAUSE: a long low check and a short bright
    // answer, so the check is most of the length.
    test('VAR is a check, then an answer', () {
      final out = _raw('boostVar');
      final def = soundDefs['boostVar']!;
      final split = (def.seconds * 0.6 * audioSampleRate).round();
      final check = Float32List.sublistView(out, 0, split);
      final answer = Float32List.sublistView(out, split);
      // Peaks, not averages: the answer is two short blips in half a second of
      // air, and an average over the air says nothing about whether it rang.
      expect(_peak(check), greaterThan(0.03));
      expect(_peak(answer), greaterThan(0.03));
    });
  });
}
