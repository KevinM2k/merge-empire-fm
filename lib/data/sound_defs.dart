/// Every sound the game makes, as a recipe. Ported from `DEFS` in
/// `utils/sound.js`.
///
/// One entry per effect: how long it lasts, and what to build into the renderer.
/// `util/audio_render.dart` is the machine; this is the score.
///
/// **The two shorthands carry most of it.** [_osc] is a tone with an exponential
/// decay and [_noise] a burst of the same shape, and between them they are what
/// nearly every effect here is made of — a stack of notes at offsets, which is
/// why the definitions read as sheet music rather than as DSP.
///
/// **`_noise`'s volume is applied TWICE, and that is faithful.** The JS fills its
/// buffer with `random * vol` and then puts a gain envelope starting at `vol` on
/// top, so the burst opens at `vol²`. Copied rather than corrected: the numbers
/// in these definitions were tuned by ear against that behaviour, so "fixing" it
/// would make every noise layer in the game about twenty times louder.
///
/// **What is NOT here: the crowd cheers.** The JS carries three
/// (`crowdCheerSmall/Mid/Roar`) built from a formant-synthesis voice model, and
/// its own comment says they are unwired — "the synth is parked pending real
/// samples", `_celebrateCrowd` never calls it. Nothing in the port taps the stand
/// either. Two hundred lines of DSP for a call nobody makes is the thing the
/// standing rules say not to port; when a real cheer is wanted it will be a
/// sample, and the tier→size decision belongs with it.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:typed_data';

import 'package:merge_empire_fc/util/audio_render.dart';

/// A tone at [freq] from [start] for [dur], opening at [vol] and decaying away.
/// The JS's `_osc`.
void _osc(
  Render r,
  Wave wave,
  double freq,
  double start,
  double dur, [
  double vol = 0.14,
]) => r.oscillator(
  wave: wave,
  freq: Env(freq),
  gain: Env(vol)..expTo(0.001, start + dur),
  start: start,
  stop: start + dur,
);

/// A burst of white noise on the same envelope. The JS's `_noise` — see the note
/// at the top of the file about [vol] landing twice.
void _noise(Render r, double start, double dur, [double vol = 0.04]) => r.noise(
  start: start,
  stop: start + dur,
  amplitude: vol,
  gain: Env(vol)..expTo(0.001, start + dur),
);

/// Low rumble: brown noise under a lowpass, swelling in and dying away.
///
/// `attack` matters as much as the tone — a near strike CRACKS (short attack), a
/// distant one just swells.
void _rumble(
  Render r,
  double start,
  double dur, [
  double vol = 0.2,
  double cutoff = 260,
  double attack = 0.02,
]) => r.brownNoise(
  start: start,
  stop: start + dur,
  gain: Env(0.0001)
    ..expTo(vol, start + attack)
    ..expTo(0.0001, start + dur),
  chain: [Biquad.lowpass(cutoff, 0.7, audioSampleRate)],
);

/// A tone that slides from one pitch to another — the shape of anything that
/// falls or rises rather than ringing.
void _sweep(
  Render r, {
  required Wave wave,
  required double from,
  required double to,
  required double start,
  required double dur,
  required Env gain,
  double? lowpass,
}) => r.oscillator(
  wave: wave,
  freq: Env(from)..expTo(to, start + dur),
  gain: gain,
  start: start,
  stop: start + dur,
  chain: lowpass == null
      ? const []
      : [Biquad.lowpass(lowpass, 1, audioSampleRate)],
);

/// How long a sound is, and what it is.
typedef SoundDef = ({double seconds, void Function(Render r) build});

/// **THE LOAN ARRIVING, one rung per player.**
///
/// The tutorial's borrowed side drops into the grid half a second apart, and it
/// did it in silence — the departure has had its `pop` since the cards started
/// coming apart, and the arrival, which is the longer and better-looking of the
/// two, had nothing. Asked for from the couch: a small beep per star, rising.
///
/// **A SCALE, not a formula.** Pitching one cue by a ratio per card is what
/// makes a rising run sound like a modem: nine equal steps land on intervals
/// nothing in the game is tuned to. This is a major pentatonic — the one scale
/// with no semitone in it, so any run up it is consonant however far it gets and
/// whatever it is played over. Twelve rungs, which is more than the loan can
/// ever be (the eleven-man target minus at least one of the player's own).
///
/// The rungs are their own effects rather than one retriggered, and they have to
/// be: `retriggerFloor` collapses two requests for the SAME name inside 70ms,
/// which is exactly what a rising run is.
const List<double> loanStarScale = [
  659.25, // E5
  740.00, // F#5
  880.00, // A5
  987.77, // B5
  1108.73, // C#6
  1318.51, // E6
  1480.00, // F#6
  1760.00, // A6
  1975.53, // B6
  2217.46, // C#7
  2637.02, // E7
  2960.00, // F#7
];

/// The cue for the [index]th star in, clamped to the top rung.
String loanStarCue(int index) =>
    'loanStar${index < 0 ? 0 : (index >= loanStarScale.length ? loanStarScale.length - 1 : index)}';

/// **COLIN'S VOICE, as a bank of syllables.**
///
/// The device voice went first and a folder of clips replaced it; the folder
/// ships empty, so in practice he has been silent. Asked for from the couch:
/// gibberish, the way Animal Crossing does it — a short blip per letter, pitched
/// off the letter, running under the line as it types in.
///
/// **Which is a bank, not a pitch-shifted sample.** There is no sample: every
/// effect in this game is synthesised from these recipes, and the renderer has
/// no rate control — so a "voice" is a set of pre-rendered syllables and the
/// text picks between them. Twelve rungs over a speaking range, which is enough
/// that a sentence does not repeat itself and few enough that it still sounds
/// like one person.
///
/// The step is a semitone-ish rather than the loan stars' pentatonic, and that
/// is the difference between the two: a rising RUN wants consonance, and speech
/// wants the opposite — a voice that only ever moved in thirds would sing.
const List<double> coachBabbleScale = [
  330, 356, 384, 415, 448, 484, 522, 564, 609, 658, 710, 767,
];

/// The cue for one syllable, clamped to the bank.
String coachBabbleCue(int rung) =>
    'coachBabble${rung < 0 ? 0 : (rung >= coachBabbleScale.length ? coachBabbleScale.length - 1 : rung)}';

/// The catalogue. Keys are the JS's own names so the two can be diffed.
final Map<String, SoundDef> soundDefs = {
  // See [coachBabbleScale]. A sawtooth under a sine an octave up, both gone
  // inside 60ms: the saw is what gives it the buzzy, VOICED quality a pure tone
  // has none of — the renderer has sine, triangle and saw, and of the three it
  // is the only one with enough harmonics to read as a voice — and the octave
  // is the formant that stops it reading as a beep. Quiet, because a line is
  // thirty of these in a row.
  for (var i = 0; i < coachBabbleScale.length; i++)
    coachBabbleCue(i): (
      seconds: 0.09,
      build: (r) {
        _osc(r, Wave.sawtooth, coachBabbleScale[i], 0, 0.055, 0.030);
        _osc(r, Wave.sine, coachBabbleScale[i] * 2, 0, 0.045, 0.018);
      },
    ),
  // **Not in the JS's `DEFS`, and deliberately so.** These are the port's own —
  // the arrival animation they belong to is the JS's, but its sound is not, and
  // a cue invented here is named so a diff of the two catalogues shows it as an
  // addition rather than as drift. See [loanStarScale].
  for (var i = 0; i < loanStarScale.length; i++)
    loanStarCue(i): (
      seconds: 0.14,
      // A short triangle blip with its own fifth a hair behind it, which is what
      // stops a bare tone reading as a test signal. Quiet: nine of these in a row
      // at the volume of a merge would be an alarm.
      build: (r) {
        _osc(r, Wave.triangle, loanStarScale[i], 0, 0.10, 0.09);
        _osc(r, Wave.sine, loanStarScale[i] * 1.5, 0.012, 0.07, 0.04);
      },
    ),
  'scout': (
    seconds: 0.55,
    build: (r) {
      _osc(r, Wave.sine, 523, 0, 0.12);
      _osc(r, Wave.sine, 659, 0.08, 0.12);
      _osc(r, Wave.sine, 784, 0.16, 0.15);
      _osc(r, Wave.sine, 1047, 0.24, 0.2);
    },
  ),
  'merge': (
    seconds: 0.45,
    build: (r) {
      _osc(r, Wave.sine, 392, 0, 0.2);
      _osc(r, Wave.sine, 494, 0.05, 0.2);
      _osc(r, Wave.sine, 587, 0.05, 0.25);
      _osc(r, Wave.triangle, 784, 0.1, 0.3);
      _noise(r, 0, 0.08, 0.03);
    },
  ),
  'epicMerge': (
    seconds: 1.0,
    build: (r) {
      _osc(r, Wave.sine, 523, 0, 0.15);
      _osc(r, Wave.sine, 659, 0.12, 0.15);
      _osc(r, Wave.sine, 784, 0.24, 0.15);
      _osc(r, Wave.triangle, 1047, 0.36, 0.3);
      _osc(r, Wave.sine, 1175, 0.42, 0.35);
      _osc(r, Wave.triangle, 1319, 0.5, 0.4);
      _noise(r, 0.36, 0.15, 0.04);
    },
  ),
  // Thunder over the diorama. THREE overlapping rumbles rather than one — the
  // crack of the strike, the body rolling in behind it, and a long tail dying
  // away. One flat noise burst sounds like a washing machine; the offsets are
  // what make it roll.
  'thunder': (
    seconds: 3.4,
    build: (r) {
      _rumble(r, 0, 1.1, 0.30, 420, 0.012); // crack — fast attack, brighter
      _rumble(r, 0.14, 2.2, 0.26, 210, 0.09); // body
      _rumble(r, 0.5, 2.8, 0.20, 130, 0.35); // tail, swelling in and fading
      _osc(r, Wave.sine, 48, 0.05, 1.6, 0.16); // sub-bass under the crack
      _osc(r, Wave.sine, 33, 0.3, 2.2, 0.11);
    },
  ),
  'coin': (
    seconds: 0.12,
    build: (r) {
      _osc(r, Wave.triangle, 1200, 0, 0.04, 0.09);
      _osc(r, Wave.triangle, 1800, 0.04, 0.06, 0.09);
    },
  ),
  'goal': (
    seconds: 0.55,
    build: (r) {
      _osc(r, Wave.triangle, 523, 0, 0.12);
      _osc(r, Wave.triangle, 659, 0.07, 0.12);
      _osc(r, Wave.triangle, 784, 0.14, 0.14);
      _osc(r, Wave.triangle, 1047, 0.22, 0.22);
      _noise(r, 0, 0.5, 0.05);
      _noise(r, 0.15, 0.35, 0.04);
      _osc(r, Wave.sine, 2800, 0.05, 0.22, 0.12);
      _osc(r, Wave.sine, 3200, 0.12, 0.18, 0.10);
    },
  ),
  'goalAgainst': (
    seconds: 0.6,
    build: (r) {
      // A groan: a sawtooth falling away under a lowpass. Two of them a hair
      // apart, because one is a synth and two beating against each other is a
      // crowd's disappointment.
      void groan(double sf, double ef, double st, double d, [double vol = 0.12]) =>
          _sweep(
            r,
            wave: Wave.sawtooth,
            from: sf,
            to: ef,
            start: st,
            dur: d,
            gain: Env(0.001)
              ..expTo(vol, st + 0.05)
              ..expTo(0.001, st + d),
            lowpass: 900,
          );
      groan(330, 140, 0, 0.55);
      groan(220, 95, 0.02, 0.55, 0.08);
      _osc(r, Wave.sine, 110, 0, 0.25);
      _noise(r, 0, 0.15, 0.025);
    },
  ),
  // A referee's peep. Short and quiet BY DESIGN — players found the long, loud
  // version harsh at kickoff, and it fires at the start of every match.
  'whistle': (
    seconds: 0.15,
    build: (r) {
      const dur = 0.11;
      // Two sines a few Hz apart through a narrow bandpass: the beat between
      // them is the pea rattling. The 32Hz tremolo on the gain is the same
      // effect from the other direction.
      final body = Env(0)
        ..linTo(0.035, 0.018)
        ..setAt(0.035, dur - 0.05)
        ..expTo(0.001, dur);
      for (final f in [2850.0, 2910.0]) {
        r.oscillator(
          wave: Wave.sine,
          freq: Env(f),
          gain: body,
          start: 0,
          stop: dur,
          lfoHz: 32,
          lfoDepthHz: 12,
          chain: [Biquad.bandpass(2900, 10, audioSampleRate)],
        );
      }
      // The chiff of breath at the start. Without it the whistle is a tone
      // rather than something someone blew.
      r.noise(
        start: 0,
        stop: 0.05,
        gain: Env(0.008)..expTo(0.001, 0.04),
        chain: [Biquad.bandpass(2800, 4, audioSampleRate)],
      );
    },
  ),
  'injury': (
    seconds: 0.5,
    build: (r) {
      _osc(r, Wave.sine, 180, 0, 0.2);
      _osc(r, Wave.sine, 140, 0.1, 0.3);
      _osc(r, Wave.sine, 1200, 0.15, 0.15, 0.1);
      _noise(r, 0, 0.15, 0.05);
    },
  ),
  // An ascending fanfare with each note WELL SEPARATED — the JS's note says
  // sequential playback is what stays clean on mobile audio pipelines.
  'victory': (
    seconds: 1.2,
    build: (r) {
      _osc(r, Wave.triangle, 523, 0.00, 0.18, 0.28);
      _osc(r, Wave.triangle, 659, 0.18, 0.18, 0.28);
      _osc(r, Wave.triangle, 784, 0.36, 0.22, 0.3);
      _osc(r, Wave.triangle, 1047, 0.58, 0.40, 0.32);
      _osc(r, Wave.triangle, 1319, 0.58, 0.40, 0.22);
      _noise(r, 0.58, 0.35, 0.06);
    },
  ),
  'defeat': (
    seconds: 1.0,
    build: (r) {
      _osc(r, Wave.sine, 392, 0, 0.3);
      _osc(r, Wave.sine, 349, 0.25, 0.3);
      _osc(r, Wave.sine, 294, 0.5, 0.4);
    },
  ),
  'draw': (
    seconds: 0.8,
    build: (r) {
      _osc(r, Wave.triangle, 440, 0, 0.25);
      _osc(r, Wave.triangle, 523, 0.18, 0.25);
      _osc(r, Wave.triangle, 440, 0.38, 0.35);
      _noise(r, 0.1, 0.2, 0.025);
    },
  ),
  'tap': (
    seconds: 0.05,
    build: (r) => _osc(r, Wave.triangle, 800, 0, 0.03, 0.07),
  ),
  'pop': (
    seconds: 0.1,
    build: (r) => _sweep(
      r,
      wave: Wave.sine,
      from: 380,
      to: 620,
      start: 0,
      dur: 0.09,
      gain: Env(0.08)..expTo(0.001, 0.08),
    ),
  ),
  // **A LOAN DEPARTURE IS A CARD LEAVING, and `pop` was standing in for it.**
  //
  // `pop` is a 0.09s sine sweep — the sound of a bubble, which is right for a
  // tutorial step and wrong for a player being sent to another club. The queue
  // carried it as "needs audio, not code", and that was the wrong read: every
  // cue in this file is SYNTHESISED, so a shatter is a build function like the
  // rest of them.
  //
  // The shape of one is a hard transient and then a scatter. The noise burst is
  // the break; the five partials are the fragments, deliberately inharmonic —
  // ratios near 1.9, 2.7, 3.6 and 5.1 rather than whole multiples, because
  // whole ones ring as a NOTE and glass does not — and each is given its own
  // start and its own decay so they come apart rather than fading together. The
  // filtered tail is the pieces settling.
  'shatter': (
    seconds: 0.6,
    build: (r) {
      // The break itself: bright, and over almost before it starts.
      _noise(r, 0, 0.03, 0.24);
      // The fragments. Staggered by a few milliseconds each, which is what
      // makes one break rather than one chord.
      _osc(r, Wave.triangle, 2400, 0.005, 0.16, 0.085);
      _osc(r, Wave.triangle, 3420, 0.012, 0.24, 0.065);
      _osc(r, Wave.triangle, 4550, 0.02, 0.19, 0.05);
      _osc(r, Wave.triangle, 6100, 0.035, 0.30, 0.038);
      _osc(r, Wave.triangle, 8700, 0.05, 0.22, 0.022);
      // A low knock under it, or the whole thing is all treble and reads as a
      // cymbal rather than as something hitting the floor.
      _sweep(
        r,
        wave: Wave.sine,
        from: 240,
        to: 90,
        start: 0,
        dur: 0.12,
        gain: Env(0.10)..expTo(0.001, 0.11),
      );
      // The pieces settling — quiet, and long enough to be a room rather than
      // a click.
      _noise(r, 0.06, 0.42, 0.028);
    },
  ),
  'error': (
    seconds: 0.25,
    build: (r) {
      _osc(r, Wave.triangle, 200, 0, 0.12);
      _osc(r, Wave.triangle, 180, 0.06, 0.12);
    },
  ),
  'sell': (
    seconds: 0.25,
    build: (r) {
      _osc(r, Wave.sine, 880, 0, 0.08);
      _osc(r, Wave.sine, 1320, 0.06, 0.1);
      _osc(r, Wave.sine, 1760, 0.12, 0.12);
    },
  ),
  'promotion': (
    seconds: 0.9,
    build: (r) {
      const notes = [392.0, 494.0, 587.0, 784.0, 988.0, 1175.0];
      for (var i = 0; i < notes.length; i++) {
        _osc(r, Wave.triangle, notes[i], i * 0.1, 0.25);
      }
      _noise(r, 0.3, 0.6, 0.06);
    },
  ),
  'challenge': (
    seconds: 0.5,
    build: (r) {
      _osc(r, Wave.sine, 880, 0, 0.15);
      _osc(r, Wave.sine, 1175, 0.1, 0.2);
      _osc(r, Wave.triangle, 1760, 0.2, 0.25);
    },
  ),
  // The post. An impact crack, then INHARMONIC partials — a hollow steel tube
  // does not ring in a musical series, and spacing them off the harmonic grid is
  // the whole difference between a post and a bell.
  'woodwork': (
    seconds: 0.7,
    build: (r) {
      _noise(r, 0, 0.025, 0.22);
      _osc(r, Wave.triangle, 265, 0, 0.65, 0.20);
      _osc(r, Wave.triangle, 418, 0, 0.50, 0.12);
      _osc(r, Wave.triangle, 790, 0, 0.35, 0.07);
      _osc(r, Wave.triangle, 1580, 0, 0.15, 0.02);
    },
  ),
  'kick': (
    seconds: 0.12,
    build: (r) {
      _sweep(
        r,
        wave: Wave.sine,
        from: 180,
        to: 65,
        start: 0,
        dur: 0.11,
        gain: Env(0.28)..expTo(0.001, 0.10),
      );
      // The click of leather, without which the thump is a drum.
      _noise(r, 0, 0.035, 0.10);
    },
  ),
  'shotKick': (
    seconds: 0.18,
    build: (r) {
      _sweep(
        r,
        wave: Wave.sine,
        from: 240,
        to: 50,
        start: 0,
        dur: 0.16,
        gain: Env(0.40)..expTo(0.001, 0.15),
      );
      _noise(r, 0, 0.05, 0.16);
    },
  ),
  // "Ooooh" for a near miss: a swell of bandpassed noise with a couple of
  // falling vowel-ish tones underneath. Not a cheer — see the note at the top of
  // the file about what is deliberately not ported.
  'crowdOoh': (
    seconds: 0.8,
    build: (r) {
      r.noise(
        start: 0,
        stop: 0.8,
        gain: Env(0.003)
          ..expTo(0.16, 0.16)
          ..expTo(0.001, 0.75),
        chain: [Biquad.bandpass(480, 0.7, audioSampleRate)],
      );
      void vowel(double f0, double f1, double vol) => _sweep(
        r,
        wave: Wave.sawtooth,
        from: f0,
        to: f1,
        start: 0.02,
        dur: 0.7,
        gain: Env(0.001)
          ..expTo(vol, 0.18)
          ..expTo(0.001, 0.7),
        lowpass: 700,
      );
      vowel(300, 190, 0.07);
      vowel(225, 150, 0.05);
    },
  ),
  'rouletteClick': (
    seconds: 0.04,
    build: (r) {
      _noise(r, 0, 0.018, 0.08);
      _osc(r, Wave.triangle, 1800, 0, 0.022, 0.05);
    },
  ),
  // A major chord spread WIDE — C4 E4 G4 C5 E5 at 180ms apart, so each note
  // rings clearly instead of the five arriving as one chord.
  'newDiscovery': (
    seconds: 1.6,
    build: (r) {
      _osc(r, Wave.sine, 523, 0.00, 0.30, 0.40);
      _osc(r, Wave.sine, 659, 0.18, 0.30, 0.38);
      _osc(r, Wave.sine, 784, 0.36, 0.30, 0.36);
      _osc(r, Wave.sine, 1047, 0.54, 0.35, 0.34);
      _osc(r, Wave.sine, 1319, 0.72, 0.60, 0.30);
      _osc(r, Wave.triangle, 2094, 0.54, 0.20, 0.10);
      _osc(r, Wave.triangle, 2637, 0.72, 0.50, 0.09);
      _noise(r, 0.54, 0.25, 0.03);
      _noise(r, 0.72, 0.40, 0.025);
    },
  ),
};

/// Render one definition to a playable WAV.
///
/// The `+0.05` tail is the JS's: a filter and a decay both run past the note that
/// started them, and cutting the buffer at the last scheduled event clips them.
Uint8List? renderSound(String name) {
  final def = soundDefs[name];
  if (def == null) return null;
  final r = Render(seconds: def.seconds + 0.05);
  def.build(r);
  return encodeWav(masterProcess(r.out));
}

/// How long one effect runs for, tail included.
///
/// The service hands this to the player so it can stop the clip itself rather
/// than trusting the platform's release mode — see `SoundBackend.playSfx`.
Duration soundLength(String name) => Duration(
  microseconds: (((soundDefs[name]?.seconds ?? 0.4) + 0.05) * 1e6).round(),
);

/// Every sound, rendered. Run in an isolate — see `services/sound_service.dart`.
Map<String, Uint8List> renderAllSounds() => {
  for (final name in soundDefs.keys) name: renderSound(name)!,
};
