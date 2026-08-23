/// The sound engine. Ported from `utils/sound.js`.
///
/// **THE RULES LIVE HERE AND THE PLATFORM LIVES BEHIND [SoundBackend].** Every
/// decision the JS makes about when a sound may play — enabled, volume,
/// suspended, which music bed the game wants — is arithmetic on a handful of
/// fields, and none of it needs a device. So it is all testable, and the only
/// untested part is the thin adapter that talks to `audioplayers`.
///
/// **VOLUME IS TWO NUMBERS MULTIPLIED**, which is the JS's design and worth
/// keeping straight: a per-channel BASE level that was tuned by ear
/// ([sfxBaseVolume], [musicBaseVolume]) and the player's own 0..1 multiplier on
/// top. That is why a slider at 1 sounds like the old fixed levels rather than
/// like full scale — the music bed at base 0.15 is meant to sit under everything.
///
/// **THE VOLUME SLIDERS WORK ON iOS.** The JS hides them there because every
/// sound goes through an `HTMLAudioElement` and WebKit treats
/// `HTMLMediaElement.volume` as read-only — Apple reserves volume for the
/// hardware buttons. That is a restriction on WebViews, not on the platform: the
/// native player underneath sets its own gain, so the gate does not port and the
/// sliders are shown everywhere.
///
/// **SUSPEND IS NOT OPTIONAL.** Without it the OS keeps playing after the app
/// leaves the foreground and the music carries on until the process is killed.
/// Backgrounded, the bed PAUSES in place — no seek, no teardown — so coming back
/// picks the loop up where it left off, and every SFX call is a no-op until then.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:merge_empire_fc/data/sound_defs.dart';

/// The tuned per-channel levels the player's own slider multiplies. The JS's.
const double sfxBaseVolume = 0.72;
const double musicBaseVolume = 0.15;

/// The recorded sample is hot — keep it well back.
const double fireworkVolume = 0.28;

/// A crossfade between beds.
const Duration musicFade = Duration(milliseconds: 700);

/// Which bed the game wants. Not "what is playing" — the choice is remembered
/// while music is off or the app is backgrounded, so turning it back on mid-match
/// resumes the MATCH bed rather than dropping to the menu loop.
enum MusicBed {
  /// Every screen outside a match.
  menu,

  /// Swapped in for the length of a match.
  match,
}

const Map<MusicBed, String> musicAssets = {
  MusicBed.menu: 'audio/menus.mp3',
  MusicBed.match: 'audio/game.mp3',
};

const String fireworkAsset = 'audio/firework.mp3';

/// Everything that touches the platform, and nothing else.
abstract class SoundBackend {
  /// Play a rendered effect. [overlap] lets copies stack — for a sound whose
  /// tail can still be rolling when the next one starts.
  ///
  /// [length] is how long the rendered effect actually is. Passed in rather than
  /// trusted to the player: **a sound that will not stop is far worse than one
  /// that costs a little to start**, and `ReleaseMode` is a platform promise
  /// about what happens at the end of a clip that has not held everywhere. With
  /// the length known, the backend can stop it itself.
  Future<void> playSfx(
    String name,
    Uint8List wav, {
    required double volume,
    required bool overlap,
    required Duration length,
  });

  /// Play a bundled file, for the one effect that is a recording.
  Future<void> playAsset(String asset, {required double volume});

  /// Put [asset] on the music channel, or silence it with null.
  Future<void> setMusic(
    String? asset, {
    required double volume,
    required bool fade,
  });

  Future<void> setMusicVolume(double volume);

  /// Pause in place — see the note about suspend at the top of the file.
  Future<void> pauseMusic();
  Future<void> resumeMusic();

  /// Cut anything in flight.
  Future<void> stopAllSfx();
}

/// How close together two requests for the SAME effect are one sound.
///
/// **A batch signing places four cards inside one `update`**, so `card:placed`
/// fires four times in the same frame and the acquisition chime was retriggered
/// four times within a few milliseconds. A 0.55s clip restarted four times in
/// one frame is not four sounds — it is a burr, and it reads as the sound
/// playing over and over.
///
/// A frame or two, deliberately, and nowhere near the length of a clip: a repeat
/// at any human pace is still a second sound. This only collapses the ones that
/// arrive together because one action caused all of them.
const Duration retriggerFloor = Duration(milliseconds: 70);

class SoundService {
  SoundService({
    required SoundBackend backend,
    this.render = renderAllSounds,
    Duration Function()? clock,
  }) : _backend = backend,
       _clock = clock ?? _sinceBoot;

  final SoundBackend _backend;

  /// Monotonic time, injectable so the coalescing rule can be tested without
  /// waiting for it.
  final Duration Function() _clock;

  static final Stopwatch _boot = Stopwatch()..start();
  static Duration _sinceBoot() => _boot.elapsed;

  /// When each effect was last handed to the backend.
  final Map<String, Duration> _lastPlayed = {};

  /// How the effects get made. Swapped in tests so a case about the RULES does
  /// not pay for a second of DSP.
  final Map<String, Uint8List> Function() render;

  final Map<String, Uint8List> _cache = {};

  bool _soundEnabled = true;
  bool _musicEnabled = false;
  double _sfxVolume = 1;
  double _musicVolume = 1;
  bool _suspended = false;
  bool _rendering = false;

  MusicBed _wanted = MusicBed.menu;
  MusicBed? _playing;

  bool get ready => _cache.isNotEmpty;
  bool get suspended => _suspended;
  MusicBed get wantedBed => _wanted;
  MusicBed? get playingBed => _playing;

  /// Render every effect, once.
  ///
  /// **OFF THE UI THREAD**, because it is the better part of a second of tight
  /// floating-point loops and doing it inline would drop a whole boot animation.
  /// Idempotent, so the settings screen and the first tap can both ask.
  Future<void> warmUp() async {
    if (_cache.isNotEmpty || _rendering) return;
    _rendering = true;
    try {
      final rendered = await compute(_renderInIsolate, render);
      _cache.addAll(rendered);
    } finally {
      _rendering = false;
    }
  }

  /// Synchronous render, for a test or a platform where an isolate is not worth
  /// the hop.
  void warmUpNow() => _cache.addAll(render());

  // ── The switches ───────────────────────────────────────────────────────────

  bool get soundEnabled => _soundEnabled;
  void setSoundEnabled(bool on) => _soundEnabled = on;

  double get sfxVolume => _sfxVolume;
  void setSoundVolume(double v) => _sfxVolume = v.clamp(0.0, 1.0);

  bool get musicEnabled => _musicEnabled;

  /// Turning music off stops the bed; turning it on resumes whichever one the
  /// game currently wants.
  Future<void> setMusicEnabled(bool on) async {
    if (_musicEnabled == on) return;
    _musicEnabled = on;
    if (!on) return stopMusic();
    return startMusic();
  }

  double get musicVolume => _musicVolume;
  Future<void> setMusicVolume(double v) async {
    _musicVolume = v.clamp(0.0, 1.0);
    if (_playing != null) await _backend.setMusicVolume(_musicTarget);
  }

  double get _musicTarget => musicBaseVolume * _musicVolume;

  // ── Effects ────────────────────────────────────────────────────────────────

  /// Play one by name. Silently does nothing when sound is off, the app is
  /// backgrounded, or the render has not landed yet — a missing effect must never
  /// be an error, because the alternative is a game that crashes on a tap.
  Future<void> play(String name, {bool overlap = false}) async {
    if (!_soundEnabled || _suspended) return;
    final wav = _cache[name];
    if (wav == null) return;
    // **ONE ACTION IS ONE SOUND.** See [retriggerFloor]. Overlapping effects are
    // exempt: stacking is the whole point of the two that ask for it.
    if (!overlap) {
      final now = _clock();
      final last = _lastPlayed[name];
      if (last != null && now - last < retriggerFloor) return;
      _lastPlayed[name] = now;
    }
    await _backend.playSfx(
      name,
      wav,
      volume: sfxBaseVolume * _sfxVolume,
      overlap: overlap,
      length: soundLength(name),
    );
  }

  /// The one effect that is a RECORDING rather than a synth, and the reason the
  /// backend has a second entry point at all.
  Future<void> playFirework() async {
    if (!_soundEnabled || _suspended) return;
    await _backend.playAsset(
      fireworkAsset,
      volume: sfxBaseVolume * _sfxVolume * fireworkVolume,
    );
  }

  // ── Music ──────────────────────────────────────────────────────────────────

  Future<void> startMusic() async {
    if (!_musicEnabled || _suspended) return;
    await _switchTo(_wanted, fade: false);
  }

  /// Pick the bed for the current context. Safe to call repeatedly with the same
  /// one, and safe while music is off — the choice is remembered either way.
  Future<void> setMusicTrack(MusicBed bed) async {
    if (_wanted == bed) return;
    _wanted = bed;
    // Backgrounded, the choice is only remembered: [resume] swaps the bed in when
    // the app comes back, so nothing starts playing behind the OS.
    if (_musicEnabled && !_suspended) await _switchTo(bed, fade: true);
  }

  Future<void> stopMusic() async {
    _playing = null;
    await _backend.setMusic(null, volume: 0, fade: false);
  }

  Future<void> _switchTo(MusicBed bed, {required bool fade}) async {
    if (_playing == bed) {
      // Already on this one — just make sure it is audible and running.
      await _backend.setMusicVolume(_musicTarget);
      await _backend.resumeMusic();
      return;
    }
    _playing = bed;
    await _backend.setMusic(musicAssets[bed], volume: _musicTarget, fade: fade);
  }

  // ── Background and foreground ─────────────────────────────────────────────

  /// The app went away: pause the bed in place and kill anything in flight.
  /// Idempotent, because the signals that trigger it overlap by platform.
  Future<void> suspend() async {
    if (_suspended) return;
    _suspended = true;
    await _backend.pauseMusic();
    await _backend.stopAllSfx();
  }

  /// The app came back: resume the bed the game currently WANTS, which may not be
  /// the one that was playing — a match can have started or ended while it was
  /// away.
  Future<void> resume() async {
    if (!_suspended) return;
    _suspended = false;
    if (!_musicEnabled) return;
    if (_playing == _wanted) {
      await _backend.setMusicVolume(_musicTarget);
      await _backend.resumeMusic();
      return;
    }
    await _switchTo(_wanted, fade: false);
  }
}

/// `compute` needs a top-level function, and the payload has to be the renderer
/// rather than its result.
Map<String, Uint8List> _renderInIsolate(
  Map<String, Uint8List> Function() render,
) => render();

// ── The platform half ────────────────────────────────────────────────────────

/// `audioplayers`, and the small amount of bookkeeping it needs.
///
/// **ONE PLAYER PER EFFECT, and its source is set ONCE.** Not an optimisation: on
/// iOS, macOS and Linux `audioplayers` implements a bytes source by writing the
/// bytes to a temp file, so re-setting the source on every tap would be a disk
/// write per sound. Set once and replayed with a seek, a tap costs nothing.
class AudioPlayersBackend implements SoundBackend {
  /// Every platform call goes through here.
  ///
  /// **A SOUND THAT FAILS MUST NEVER SURFACE.** The JS wraps every one of these
  /// in a bare `catch` and the reason carries: the audio session can be taken by
  /// a call, a device can refuse a format, and under a widget test there is no
  /// plugin at all — and in none of those cases is the right answer for the game
  /// to throw. These are all fire-and-forget from the caller's side, so an
  /// unhandled rejection here would surface as a crash somewhere unrelated.
  /// Stop and dispose whatever is playing for [name], and forget it.
  ///
  /// Idempotent: a stop timer, a completion callback and the next play of the
  /// same effect can all reach this, in any order.
  Future<void> _quietlyKill(AudioPlayer player) async {
    await _quietly(player.stop);
    await _quietly(player.dispose);
  }

  Future<void> _kill(String name) async {
    _stops.remove(name)?.cancel();
    final player = _players.remove(name);
    if (player == null) return;
    await _quietlyKill(player);
  }

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Silent by design.
    }
  }

  /// A player with its release mode already set. The cascade form leaves an
  /// un-awaited platform call behind, and on a slow first frame that raced the
  /// `play` that followed it.
  static Future<AudioPlayer> _newPlayer(ReleaseMode mode) async {
    final player = AudioPlayer();
    await player.setReleaseMode(mode);
    return player;
  }

  final Map<String, AudioPlayer> _players = {};
  final Set<AudioPlayer> _oneShots = {};
  AudioPlayer? _music;
  Timer? _fade;

  /// One stop timer per named effect, so a retrigger re-arms rather than leaving
  /// the previous one to cut the new play short.
  final Map<String, Timer> _stops = {};

  @override
  Future<void> playSfx(
    String name,
    Uint8List wav, {
    required double volume,
    required bool overlap,
    required Duration length,
  }) => _quietly(() async {
    if (overlap) {
      // A copy of its own, disposed when it finishes — a sound whose tail can
      // still be rolling when the next one starts must not cut itself off.
      final player = await _newPlayer(ReleaseMode.stop);
      _oneShots.add(player);
      unawaited(
        player.onPlayerComplete.first.whenComplete(() {
          _oneShots.remove(player);
          unawaited(player.dispose());
        }),
      );
      await player.setVolume(volume);
      await player.play(BytesSource(wav, mimeType: 'audio/wav'));
      return;
    }
    // **A FRESH PLAYER PER SOUND, and the cached one is gone.**
    //
    // It used to keep one `AudioPlayer` per effect for the life of the process
    // and retrigger it with `seek(0)` then `resume()`. That is a state machine
    // — created, played, stopped by a timer, sought, resumed — and it is the
    // only thing in this file that could produce what was reported twice: the
    // signing sound running continuously, and more than one of it at a time.
    // `resume()` on a player the stop timer has already `stop()`ped is asking a
    // released source to play again, and what a platform does there is not
    // something this code should be relying on.
    //
    // **It is not reproducible from here** — it needs a device — so this
    // removes the mechanism rather than claiming a diagnosis. One player, one
    // sound, disposed when it ends. The cost is creating a player per effect,
    // which is the trade this file's own note already makes: "a sound that will
    // not stop is far worse than one that costs a little to start".
    //
    // The retrigger rule survives and is now literal: the previous copy of THIS
    // effect is stopped before the new one starts, which is what "back to the
    // top rather than a second copy" means.
    await _kill(name);
    final player = await _newPlayer(ReleaseMode.stop);
    _players[name] = player;

    // **ARMED BEFORE ANYTHING THAT CAN THROW.** The whole block is inside
    // `_quietly`, so a platform call that failed part-way through used to skip
    // the stop and leave whatever was playing with nothing scheduled to end it.
    _stops[name] = Timer(length + const Duration(milliseconds: 60), () {
      _stops.remove(name);
      unawaited(_kill(name));
    });

    unawaited(
      player.onPlayerComplete.first.whenComplete(() {
        if (_players[name] == player) unawaited(_kill(name));
      }),
    );
    await player.setVolume(volume);
    await player.play(BytesSource(wav, mimeType: 'audio/wav'));
  });

  @override
  Future<void> playAsset(String asset, {required double volume}) =>
      _quietly(() async {
        final player = await _newPlayer(ReleaseMode.stop);
        _oneShots.add(player);
        unawaited(
          player.onPlayerComplete.first.whenComplete(() {
            _oneShots.remove(player);
            unawaited(player.dispose());
          }),
        );
        await player.setVolume(volume);
        await player.play(AssetSource(asset));
      });

  @override
  Future<void> setMusic(
    String? asset, {
    required double volume,
    required bool fade,
  }) => _quietly(() async {
    _fade?.cancel();
    final old = _music;
    if (asset == null) {
      _music = null;
      await old?.stop();
      await old?.dispose();
      return;
    }
    final next = await _newPlayer(ReleaseMode.loop);
    _music = next;
    await next.setVolume(fade ? 0 : volume);
    await next.play(AssetSource(asset));
    if (old != null) {
      if (fade) {
        _rampOut(old);
      } else {
        await old.stop();
        await old.dispose();
      }
    }
    if (fade) _ramp(next, volume);
  });

  /// A stepped volume ramp. `audioplayers` has no gain automation, so the fade is
  /// a timer — the same shape the JS uses for the same reason.
  void _ramp(AudioPlayer player, double to) {
    const step = Duration(milliseconds: 50);
    final steps = musicFade.inMilliseconds ~/ step.inMilliseconds;
    var i = 0;
    _fade?.cancel();
    _fade = Timer.periodic(step, (timer) {
      i++;
      unawaited(player.setVolume(to * i / steps));
      if (i >= steps) timer.cancel();
    });
  }

  void _rampOut(AudioPlayer player) {
    const step = Duration(milliseconds: 50);
    final steps = musicFade.inMilliseconds ~/ step.inMilliseconds;
    var i = 0;
    // Its OWN timer: the outgoing bed has to keep ramping while the incoming one
    // ramps up, and one shared timer would leave whichever started second in
    // charge of both.
    Timer.periodic(step, (timer) {
      i++;
      unawaited(player.setVolume(musicBaseVolume * (1 - i / steps)));
      if (i >= steps) {
        timer.cancel();
        unawaited(player.stop().then((_) => player.dispose()));
      }
    });
  }

  @override
  Future<void> setMusicVolume(double volume) => _quietly(() async {
    _fade?.cancel();
    await _music?.setVolume(volume);
  });

  @override
  Future<void> pauseMusic() => _quietly(() async {
    _fade?.cancel();
    await _music?.pause();
  });

  @override
  Future<void> resumeMusic() => _quietly(() async => _music?.resume());

  @override
  Future<void> stopAllSfx() => _quietly(() async {
    // **DISPOSED, not merely stopped.** Every player here is a one-shot now —
    // see `playSfx` — so leaving a stopped one in the map is a platform handle
    // nothing will ever come back for.
    for (final name in _players.keys.toList()) {
      await _kill(name);
    }
    for (final timer in _stops.values) {
      timer.cancel();
    }
    _stops.clear();
    for (final player in _oneShots.toList()) {
      await _quietlyKill(player);
    }
    _oneShots.clear();
  });
}
