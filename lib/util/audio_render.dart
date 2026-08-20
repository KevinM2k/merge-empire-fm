/// An offline audio renderer, and the WAV encoder that gets its output to a
/// player. Ported from the Web Audio graph in `utils/sound.js`.
///
/// **THE GAME'S SOUND EFFECTS ARE SYNTHESISED, NOT SAMPLED**, and that is the
/// JS's decision rather than this file's: two dozen effects at 44.1kHz would be
/// megabytes of assets, and the JS renders them through an `OfflineAudioContext`
/// at boot instead. There is no `OfflineAudioContext` here, so this is it — a
/// few hundred lines of DSP that produce the same waveforms.
///
/// **WHY OFFLINE AT ALL, rather than a live synth?** The JS's own reason, and it
/// survives the port: rendering to a buffer touches no audio hardware, which is
/// what kept it clear of the Samsung AAudio crash loop that a live context
/// triggered. Here it buys something else as well — the output is plain PCM, so
/// every sound can be rendered once, cached, and played through one ordinary
/// audio player, and the whole engine is testable without a device.
///
/// **EVERY CHAIN RENDERS INTO A SCRATCH BUFFER, THEN MIXES.** That is the model
/// Web Audio gives you for free: each `_osc`/`_noise` in the JS builds an
/// independent source → gain → filter chain and connects it to the destination,
/// so the destination is a sum. Filters are per-sample recursive and cannot be
/// applied to a mix, so the buffer has to be per chain.
///
/// **The randomness is SEEDED**, unlike the JS's `Math.random()`. A synth
/// rendered once at boot has nothing to gain from being different every run, and
/// a seed means a test can assert what came out.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// The rate everything renders at. The JS's own.
const int audioSampleRate = 44100;

/// Oscillator shapes. The three the sound definitions use.
enum Wave { sine, triangle, sawtooth }

/// A Web Audio `AudioParam`: a value that changes over time by scheduled events.
///
/// The two ramp kinds are not interchangeable and the definitions use both. An
/// EXPONENTIAL ramp is how a decay reads as a decay — a linear fade to silence
/// sounds like someone turning a knob — and it is why every envelope here ends at
/// a small positive number rather than at zero: geometric interpolation through
/// zero is undefined, so Web Audio forbids it and the JS uses 0.001 sentinels.
class Env {
  Env(double initial)
    : _events = [(t: 0.0, v: initial, kind: _EnvKind.step)];

  final List<({double t, double v, _EnvKind kind})> _events;

  /// A STEP, not a ramp — the value holds at whatever it was until this time and
  /// then jumps. Getting this wrong is the difference between a whistle that
  /// opens and one that fades in from nothing.
  void setAt(double value, double time) =>
      _events.add((t: time, v: value, kind: _EnvKind.step));

  void expTo(double value, double time) =>
      _events.add((t: time, v: value, kind: _EnvKind.exponential));

  void linTo(double value, double time) =>
      _events.add((t: time, v: value, kind: _EnvKind.linear));

  /// The value at [time], interpolating between the surrounding events.
  double at(double time) {
    var prev = _events.first;
    for (var i = 1; i < _events.length; i++) {
      final next = _events[i];
      if (time >= next.t) {
        prev = next;
        continue;
      }
      // Before a step, nothing is moving.
      if (next.kind == _EnvKind.step) return prev.v;
      final span = next.t - prev.t;
      if (span <= 0) return next.v;
      final k = (time - prev.t) / span;
      if (next.kind == _EnvKind.linear) return prev.v + (next.v - prev.v) * k;
      // Geometric, and it needs both ends positive — see the note above.
      final from = prev.v <= 0 ? 1e-5 : prev.v;
      final to = next.v <= 0 ? 1e-5 : next.v;
      return from * math.pow(to / from, k).toDouble();
    }
    return prev.v;
  }
}

enum _EnvKind { step, linear, exponential }

/// A two-pole IIR filter, at the RBJ cookbook coefficients Web Audio uses.
///
/// Recursive, so it has to run sample by sample over one chain's own buffer —
/// which is the reason a chain cannot be mixed before it is filtered.
class Biquad {
  Biquad._(this._b0, this._b1, this._b2, this._a1, this._a2);

  factory Biquad.lowpass(double freq, double q, int sampleRate) {
    final w = 2 * math.pi * freq / sampleRate;
    final alpha = math.sin(w) / (2 * q);
    final cosw = math.cos(w);
    final a0 = 1 + alpha;
    return Biquad._(
      (1 - cosw) / 2 / a0,
      (1 - cosw) / a0,
      (1 - cosw) / 2 / a0,
      -2 * cosw / a0,
      (1 - alpha) / a0,
    );
  }

  /// The constant-0dB-peak-gain form, which is the one Web Audio's `bandpass`
  /// uses — the other cookbook bandpass has a constant skirt and a peak that
  /// climbs with Q, so a Q of 7 would come out seven times louder.
  factory Biquad.bandpass(double freq, double q, int sampleRate) {
    final w = 2 * math.pi * freq / sampleRate;
    final alpha = math.sin(w) / (2 * q);
    final cosw = math.cos(w);
    final a0 = 1 + alpha;
    return Biquad._(
      alpha / a0,
      0,
      -alpha / a0,
      -2 * cosw / a0,
      (1 - alpha) / a0,
    );
  }

  /// The master chain's `-9dB @ 6kHz` shelf.
  factory Biquad.highshelf(double freq, double dbGain, int sampleRate) {
    final a = math.pow(10, dbGain / 40).toDouble();
    final w = 2 * math.pi * freq / sampleRate;
    final cosw = math.cos(w);
    final alpha = math.sin(w) / 2 * math.sqrt(2);
    final twoSqrtAAlpha = 2 * math.sqrt(a) * alpha;
    final a0 = (a + 1) - (a - 1) * cosw + twoSqrtAAlpha;
    return Biquad._(
      a * ((a + 1) + (a - 1) * cosw + twoSqrtAAlpha) / a0,
      -2 * a * ((a - 1) + (a + 1) * cosw) / a0,
      a * ((a + 1) + (a - 1) * cosw - twoSqrtAAlpha) / a0,
      2 * ((a - 1) - (a + 1) * cosw) / a0,
      ((a + 1) - (a - 1) * cosw - twoSqrtAAlpha) / a0,
    );
  }

  final double _b0, _b1, _b2, _a1, _a2;

  /// In place, over [from]..[to].
  void run(Float32List buf, int from, int to) {
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    for (var i = from; i < to; i++) {
      final x = buf[i];
      final y = _b0 * x + _b1 * x1 + _b2 * x2 - _a1 * y1 - _a2 * y2;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      buf[i] = y;
    }
  }
}

/// One sound being built: a master buffer, and a scratch buffer every chain
/// borrows.
class Render {
  Render({required this.seconds, int? seed})
    : frames = (audioSampleRate * seconds).ceil(),
      _rng = math.Random(seed ?? 20250820) {
    out = Float32List(frames);
    _scratch = Float32List(frames);
  }

  final double seconds;
  final int frames;
  final math.Random _rng;
  late final Float32List out;
  late Float32List _scratch;

  int _index(double time) => (time * audioSampleRate).round().clamp(0, frames);

  void _clearScratch(int from, int to) {
    for (var i = from; i < to; i++) {
      _scratch[i] = 0;
    }
  }

  void _mix(int from, int to) {
    for (var i = from; i < to; i++) {
      out[i] += _scratch[i];
    }
  }

  double _wave(Wave wave, double phase) {
    final p = phase - phase.floorToDouble();
    return switch (wave) {
      Wave.sine => math.sin(2 * math.pi * p),
      // A naive triangle and saw. Web Audio band-limits both, which matters for
      // a sustained tone at the top of the range and not at all for a 120ms
      // blip — and every use here is a blip.
      Wave.triangle => 1 - 4 * (p - 0.5).abs(),
      Wave.sawtooth => 2 * p - 1,
    };
  }

  /// One oscillator through one gain envelope, optionally vibratoed and
  /// filtered. The general form the definitions' own helpers are built from.
  void oscillator({
    required Wave wave,
    required Env freq,
    required Env gain,
    required double start,
    required double stop,
    double lfoHz = 0,
    double lfoDepthHz = 0,
    List<Biquad> chain = const [],
  }) {
    final from = _index(start), to = _index(stop);
    if (to <= from) return;
    _clearScratch(from, to);
    var phase = 0.0;
    var lfoPhase = 0.0;
    const dt = 1 / audioSampleRate;
    for (var i = from; i < to; i++) {
      final t = i * dt;
      var f = freq.at(t);
      if (lfoDepthHz != 0) {
        f += lfoDepthHz * math.sin(2 * math.pi * lfoPhase);
        lfoPhase += lfoHz * dt;
      }
      _scratch[i] = _wave(wave, phase) * gain.at(t);
      phase += f * dt;
    }
    for (final f in chain) {
      f.run(_scratch, from, to);
    }
    _mix(from, to);
  }

  /// White noise through a gain envelope, optionally filtered.
  void noise({
    required double start,
    required double stop,
    required Env gain,
    double amplitude = 1,
    List<Biquad> chain = const [],
  }) {
    final from = _index(start), to = _index(stop);
    if (to <= from) return;
    _clearScratch(from, to);
    const dt = 1 / audioSampleRate;
    for (var i = from; i < to; i++) {
      _scratch[i] = (_rng.nextDouble() * 2 - 1) * amplitude * gain.at(i * dt);
    }
    for (final f in chain) {
      f.run(_scratch, from, to);
    }
    _mix(from, to);
  }

  /// BROWN noise — white integrated with a leak, which is the whole character of
  /// distant thunder.
  ///
  /// White noise is flat across the spectrum and reads as hiss; integrating it
  /// concentrates the energy at the bottom end. The `3.5` and the `0.02` leak are
  /// the JS's, and they are what set how far down the energy piles up.
  void brownNoise({
    required double start,
    required double stop,
    required Env gain,
    List<Biquad> chain = const [],
  }) {
    final from = _index(start), to = _index(stop);
    if (to <= from) return;
    _clearScratch(from, to);
    const dt = 1 / audioSampleRate;
    var last = 0.0;
    for (var i = from; i < to; i++) {
      last = (last + 0.02 * (_rng.nextDouble() * 2 - 1)) / 1.02;
      _scratch[i] = last * 3.5 * gain.at(i * dt);
    }
    for (final f in chain) {
      f.run(_scratch, from, to);
    }
    _mix(from, to);
  }

  double random() => _rng.nextDouble();
}

// ── The master chain ─────────────────────────────────────────────────────────

/// The JS's `_masterProcess`: compress, then take the top off.
///
/// Both halves matter and neither is polish. The COMPRESSOR is why loudness is
/// not a usable cue anywhere in this engine — at ratio 6 over a -18dB threshold,
/// a 6dB gap between two sounds comes out about 1dB apart, so anything that
/// wants to feel bigger has to do it with texture. The SHELF is because these
/// play through a phone speaker, where synthesised harmonics above 6kHz are the
/// part that reads as cheap.
Float32List masterProcess(Float32List input, {int sampleRate = audioSampleRate}) {
  const threshold = -18.0;
  const knee = 20.0;
  const ratio = 6.0;
  const attack = 0.003;
  const release = 0.15;

  // A standard soft-knee feed-forward compressor at Web Audio's parameters —
  // not a reimplementation of Blink's internals, which are not specified.
  final out = Float32List.fromList(input);
  final attackCoef = math.exp(-1 / (attack * sampleRate));
  final releaseCoef = math.exp(-1 / (release * sampleRate));
  var envelope = 0.0;
  for (var i = 0; i < out.length; i++) {
    final level = out[i].abs();
    final coef = level > envelope ? attackCoef : releaseCoef;
    envelope = level + coef * (envelope - level);
    final db = 20 * math.log(math.max(envelope, 1e-9)) / math.ln10;
    double reduction;
    if (db < threshold - knee / 2) {
      reduction = 0;
    } else if (db > threshold + knee / 2) {
      reduction = (db - threshold) * (1 / ratio - 1);
    } else {
      // Quadratic through the knee, so the onset of compression is not audible
      // as a step.
      final over = db - threshold + knee / 2;
      reduction = (1 / ratio - 1) * over * over / (2 * knee);
    }
    out[i] *= math.pow(10, reduction / 20).toDouble();
  }
  Biquad.highshelf(6000, -9, sampleRate).run(out, 0, out.length);
  return out;
}

// ── WAV ──────────────────────────────────────────────────────────────────────

/// 16-bit mono PCM in a RIFF container — the JS's `_toWav`, and the one format
/// every platform's audio player reads without a codec.
Uint8List encodeWav(Float32List samples, {int sampleRate = audioSampleRate}) {
  final bytes = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    // Clipped, not wrapped: a sample past full scale that overflows the int16
    // comes back as the opposite polarity, which is a click rather than
    // distortion.
    final v = samples[i].clamp(-1.0, 1.0);
    bytes.setInt16(44 + i * 2, (v < 0 ? v * 0x8000 : v * 0x7fff).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}
