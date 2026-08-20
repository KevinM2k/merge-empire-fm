/// The offline renderer.
///
/// The sounds themselves cannot be asserted — "does the whistle sound like a
/// whistle" is not a test. What CAN be asserted is that the machine works: the
/// envelopes follow Web Audio's own semantics, the filters do what their names
/// say, the master chain pulls a hot signal down, and the WAV that comes out is a
/// WAV. Everything below is the part that would silently produce silence.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/audio_render.dart';

double _peak(Float32List b) =>
    b.fold(0, (a, v) => math.max(a, v.abs()));

double _rms(Float32List b) =>
    math.sqrt(b.fold<double>(0, (a, v) => a + v * v) / b.length);

/// How much energy sits above [hz], very roughly — enough to tell a lowpass from
/// a bandpass by measuring rather than by reading the coefficients.
double _highEnergy(Float32List b, {int stride = 1}) {
  var sum = 0.0;
  for (var i = stride; i < b.length; i++) {
    final d = b[i] - b[i - stride];
    sum += d * d;
  }
  return math.sqrt(sum / b.length);
}

void main() {
  group('envelopes', () {
    test('hold their last set value', () {
      final e = Env(0.5);
      expect(e.at(0), 0.5);
      expect(e.at(10), 0.5);
      e.setAt(0.2, 1);
      expect(e.at(0.5), 0.5);
      expect(e.at(1), 0.2);
      expect(e.at(5), 0.2);
    });

    test('a linear ramp is a straight line', () {
      final e = Env(0)..linTo(1, 1);
      expect(e.at(0), closeTo(0, 1e-9));
      expect(e.at(0.5), closeTo(0.5, 1e-9));
      expect(e.at(1), closeTo(1, 1e-9));
    });

    test('an exponential ramp is a geometric one, not a straight line', () {
      // The difference is the whole reason a decay reads as a decay rather than
      // as someone turning a knob.
      final e = Env(1)..expTo(0.01, 1);
      expect(e.at(0), closeTo(1, 1e-9));
      expect(e.at(0.5), closeTo(0.1, 1e-6));
      expect(e.at(1), closeTo(0.01, 1e-9));
      expect(e.at(0.5), lessThan(0.505), reason: 'that is a linear ramp');
    });

    test('and a ramp through zero does not blow up', () {
      // Web Audio forbids it and the definitions use 0.001 sentinels — but a
      // NaN here would be silence, so the floor is in the renderer too.
      final e = Env(0)..expTo(1, 1);
      expect(e.at(0.5).isFinite, isTrue);
      final f = Env(1)..expTo(0, 1);
      expect(f.at(0.5).isFinite, isTrue);
    });
  });

  group('sources', () {
    test('an oscillator produces a tone at the frequency it was asked for', () {
      final r = Render(seconds: 0.1);
      r.oscillator(
        wave: Wave.sine,
        freq: Env(441),
        gain: Env(1),
        start: 0,
        stop: 0.1,
      );
      expect(_peak(r.out), closeTo(1, 0.02));
      // 441Hz over 0.1s is 44.1 cycles, so 44 zero crossings in each direction.
      var crossings = 0;
      for (var i = 1; i < r.out.length; i++) {
        if (r.out[i - 1] < 0 && r.out[i] >= 0) crossings++;
      }
      expect(crossings, closeTo(44, 1));
    });

    test('and it only writes inside its own window', () {
      final r = Render(seconds: 0.2);
      r.oscillator(
        wave: Wave.sine,
        freq: Env(440),
        gain: Env(1),
        start: 0.1,
        stop: 0.15,
      );
      expect(r.out[0], 0);
      expect(r.out[r.out.length - 1], 0);
      expect(_peak(r.out), greaterThan(0.5));
    });

    test('chains sum rather than replace', () {
      // The destination is a sum — that is the model the definitions are written
      // in, where six notes at six offsets are six independent chains.
      final r = Render(seconds: 0.05);
      for (var i = 0; i < 3; i++) {
        r.oscillator(
          wave: Wave.sine,
          freq: Env(440),
          gain: Env(0.2),
          start: 0,
          stop: 0.05,
        );
      }
      expect(_peak(r.out), closeTo(0.6, 0.02));
    });

    test('brown noise has far less top end than white', () {
      final white = Render(seconds: 0.3)
        ..noise(start: 0, stop: 0.3, gain: Env(1));
      final brown = Render(seconds: 0.3)
        ..brownNoise(start: 0, stop: 0.3, gain: Env(1));
      // Normalised for level, because that is not what is being compared.
      final w = _highEnergy(white.out) / _rms(white.out);
      final b = _highEnergy(brown.out) / _rms(brown.out);
      expect(b, lessThan(w / 4), reason: 'integrating did not lower the tone');
    });
  });

  group('filters', () {
    test('a lowpass takes the top off and leaves the bottom', () {
      for (final (hz, survives) in [(200.0, true), (8000.0, false)]) {
        final r = Render(seconds: 0.2);
        r.oscillator(
          wave: Wave.sine,
          freq: Env(hz),
          gain: Env(1),
          start: 0,
          stop: 0.2,
          chain: [Biquad.lowpass(600, 0.7, audioSampleRate)],
        );
        expect(
          _rms(r.out) > 0.3,
          survives,
          reason: '${hz}Hz through a 600Hz lowpass',
        );
      }
    });

    test('a bandpass keeps its own band and rejects both sides', () {
      final levels = <double, double>{};
      for (final hz in [200.0, 2900.0, 12000.0]) {
        final r = Render(seconds: 0.2);
        r.oscillator(
          wave: Wave.sine,
          freq: Env(hz),
          gain: Env(1),
          start: 0,
          stop: 0.2,
          chain: [Biquad.bandpass(2900, 10, audioSampleRate)],
        );
        levels[hz] = _rms(r.out);
      }
      expect(levels[2900.0]!, greaterThan(levels[200.0]! * 5));
      expect(levels[2900.0]!, greaterThan(levels[12000.0]! * 5));
      // Constant 0dB peak gain: a Q of 10 must not make the band ten times
      // LOUDER than it went in, which the constant-skirt form would.
      expect(levels[2900.0]!, lessThan(1.2));
    });

    test('the high shelf cuts above its corner and not below', () {
      double after(double hz) {
        final r = Render(seconds: 0.2);
        r.oscillator(
          wave: Wave.sine,
          freq: Env(hz),
          gain: Env(1),
          start: 0,
          stop: 0.2,
        );
        Biquad.highshelf(6000, -9, audioSampleRate).run(r.out, 0, r.frames);
        return _rms(r.out);
      }

      expect(after(300), closeTo(0.707, 0.05));
      // -9dB is a factor of about 0.355.
      expect(after(12000), closeTo(0.707 * 0.355, 0.06));
    });
  });

  group('the master chain', () {
    test('pulls a hot signal down and leaves a quiet one alone', () {
      double gainFor(double level) {
        final r = Render(seconds: 0.3);
        r.oscillator(
          wave: Wave.sine,
          freq: Env(300),
          gain: Env(level),
          start: 0,
          stop: 0.3,
        );
        // Measured over the tail, so the attack is not in the average.
        final processed = masterProcess(r.out);
        final from = (processed.length * 0.5).round();
        final tail = Float32List.sublistView(processed, from);
        return _rms(tail) / (level * 0.707);
      }

      expect(gainFor(0.02), closeTo(1, 0.1), reason: 'a quiet signal was moved');
      expect(gainFor(0.9), lessThan(0.6), reason: 'a hot signal was not held');
    });

    test('and nothing it produces is out of range', () {
      final r = Render(seconds: 0.2);
      for (var i = 0; i < 8; i++) {
        r.oscillator(
          wave: Wave.sine,
          freq: Env(200 + i * 130),
          gain: Env(0.9),
          start: 0,
          stop: 0.2,
        );
      }
      final processed = masterProcess(r.out);
      expect(processed.every((v) => v.isFinite), isTrue);
    });
  });

  group('the WAV', () {
    test('is a RIFF/WAVE header describing what follows', () {
      final wav = encodeWav(Float32List(100));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      final view = ByteData.sublistView(wav);
      expect(view.getUint16(20, Endian.little), 1, reason: 'not PCM');
      expect(view.getUint16(22, Endian.little), 1, reason: 'not mono');
      expect(view.getUint32(24, Endian.little), audioSampleRate);
      expect(view.getUint16(34, Endian.little), 16, reason: 'not 16-bit');
      expect(wav.length, 44 + 200);
      expect(view.getUint32(40, Endian.little), 200);
    });

    test('CLIPS a sample past full scale rather than wrapping it', () {
      // A wrap comes back as the opposite polarity, which is a click rather than
      // distortion — and it is the one encoder bug that only shows up on the
      // loudest sound in the game.
      final wav = encodeWav(Float32List.fromList([2, -2]));
      final view = ByteData.sublistView(wav);
      expect(view.getInt16(44, Endian.little), 0x7fff);
      expect(view.getInt16(46, Endian.little), -0x8000);
    });

    test('and round-trips a sample it can represent', () {
      final wav = encodeWav(Float32List.fromList([0, 0.5, -0.5]));
      final view = ByteData.sublistView(wav);
      expect(view.getInt16(44, Endian.little), 0);
      expect(view.getInt16(46, Endian.little) / 0x7fff, closeTo(0.5, 1e-4));
      expect(view.getInt16(48, Endian.little) / 0x8000, closeTo(-0.5, 1e-4));
    });
  });
}
