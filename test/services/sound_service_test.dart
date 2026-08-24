/// The sound engine's RULES.
///
/// None of them need a device, which is the point of keeping the platform behind
/// a backend: every decision about whether a sound may play is arithmetic on a
/// handful of fields, and it is exactly the part that had gone wrong in the JS
/// often enough to be commented.
library;

import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/sound_defs.dart';
import 'package:merge_empire_fc/services/sound_service.dart';

class FakeBackend implements SoundBackend {
  final List<({String name, double volume, bool overlap, Duration length})>
  sfx = [];
  final List<({String asset, double volume})> assets = [];
  final List<({String? asset, double volume, bool fade})> music = [];
  final List<double> volumes = [];
  int paused = 0;
  int resumed = 0;
  int stopped = 0;

  @override
  Future<void> playSfx(
    String name,
    Uint8List wav, {
    required double volume,
    required bool overlap,
    required Duration length,
  }) async =>
      sfx.add((name: name, volume: volume, overlap: overlap, length: length));

  @override
  Future<void> playAsset(String asset, {required double volume}) async =>
      assets.add((asset: asset, volume: volume));

  @override
  Future<void> setMusic(
    String? asset, {
    required double volume,
    required bool fade,
  }) async => music.add((asset: asset, volume: volume, fade: fade));

  @override
  Future<void> setMusicVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> pauseMusic() async => paused++;

  @override
  Future<void> resumeMusic() async => resumed++;

  @override
  Future<void> stopAllSfx() async => stopped++;
}

/// One byte per sound. The rules do not care what is in it, and a real render is
/// most of a second.
Map<String, Uint8List> fakeRender() => {
  for (final name in [
    'merge',
    'coin',
    'goal',
    'scout',
    'newDiscovery',
    'thunder',
  ])
    name: Uint8List(1),
};

/// A clock the test can wind on, for the rule that two requests for one effect
/// inside a frame are one sound — see [retriggerFloor].
class TestClock {
  Duration now = Duration.zero;
  void tick() => now += retriggerFloor * 2;
}

({SoundService service, FakeBackend backend, TestClock clock}) build() {
  final backend = FakeBackend();
  final clock = TestClock();
  final service = SoundService(
    backend: backend,
    render: fakeRender,
    clock: () => clock.now,
  )..warmUpNow();
  return (service: service, backend: backend, clock: clock);
}

void main() {
  _sessionGroup();
  group('effects', () {
    test('play at the base level times the player\'s own', () {
      final (service: s, backend: b, clock: clock) = build();
      unawaited(s.play('merge'));
      expect(b.sfx.single.volume, closeTo(sfxBaseVolume, 1e-9));
      s.setSoundVolume(0.5);
      // Past the retrigger floor, or the second one is the same sound as the
      // first and never reaches the backend.
      clock.tick();
      unawaited(s.play('merge'));
      expect(b.sfx.last.volume, closeTo(sfxBaseVolume * 0.5, 1e-9));
    });

    test('and volume clamps rather than trusting the save', () {
      final (service: s, backend: _, clock: _) = build();
      s.setSoundVolume(4);
      expect(s.sfxVolume, 1);
      s.setSoundVolume(-1);
      expect(s.sfxVolume, 0);
    });

    test('FOUR CARDS IN ONE TAP IS ONE SOUND', () async {
      // Signing a batch of four places four cards, so `card:placed` fires four
      // times inside one `update` — and the acquisition chime was retriggered
      // four times within a few milliseconds. A 0.55s clip restarted four times
      // in one frame is not four sounds; it is a burr, and it reads as the sound
      // playing over and over.
      var now = Duration.zero;
      final backend = FakeBackend();
      final service = SoundService(
        backend: backend,
        render: fakeRender,
        clock: () => now,
      );
      service.warmUpNow();

      for (var i = 0; i < 4; i++) {
        await service.play('scout');
      }
      expect(backend.sfx.length, 1, reason: 'four retriggers of one clip');

      // A human-paced repeat is still a second sound: the floor is a frame or
      // two, not the length of the clip.
      now += retriggerFloor + const Duration(milliseconds: 1);
      await service.play('scout');
      expect(backend.sfx.length, 2, reason: 'the second tap was swallowed');
    });

    test('and it is PER SOUND, so a batch does not mute anything else', () async {
      // Placing a card also updates coins and can be a new discovery. Those are
      // different sounds and each should still be heard once.
      final (service: service, backend: backend, clock: _) = build();
      await service.play('scout');
      await service.play('coin');
      await service.play('newDiscovery');
      expect(backend.sfx.map((s) => s.name), [
        'scout',
        'coin',
        'newDiscovery',
      ]);
    });

    test('an OVERLAPPING sound is never coalesced', () async {
      // Overlap exists for the two effects whose whole point is stacking —
      // thunder and fireworks. Collapsing those would be the opposite of what
      // the caller asked for.
      final (service: service, backend: backend, clock: _) = build();
      for (var i = 0; i < 3; i++) {
        await service.play('thunder', overlap: true);
      }
      expect(backend.sfx.length, 3);
    });

    test('nothing plays with sound off', () {
      final (service: s, backend: b, clock: _) = build();
      s.setSoundEnabled(false);
      unawaited(s.play('merge'));
      expect(b.sfx, isEmpty);
    });

    test('nothing plays while the app is away', () async {
      // Without this the OS keeps playing after the app leaves the foreground.
      final (service: s, backend: b, clock: _) = build();
      await s.suspend();
      unawaited(s.play('merge'));
      expect(b.sfx, isEmpty);
      await s.resume();
      unawaited(s.play('merge'));
      expect(b.sfx, hasLength(1));
    });

    test('an unknown or not-yet-rendered sound is silent, not an error', () {
      // A missing effect must never throw: the alternative is a game that
      // crashes on a tap.
      final backend = FakeBackend();
      final cold = SoundService(backend: backend, render: fakeRender);
      expect(() => unawaited(cold.play('merge')), returnsNormally);
      expect(backend.sfx, isEmpty);
      final (service: s, backend: b, clock: _) = build();
      expect(() => unawaited(s.play('nothing-like-this')), returnsNormally);
      expect(b.sfx, isEmpty);
    });

    test('and the clip\'s own LENGTH goes with it', () {
      // The backend stops the sound itself rather than trusting the platform's
      // release mode — a sound that will not stop is far worse than one that
      // costs a little to start.
      final (service: s, backend: b, clock: _) = build();
      unawaited(s.play('merge'));
      expect(b.sfx.single.length, soundLength('merge'));
      expect(b.sfx.single.length.inMilliseconds, greaterThan(0));
    });

    test('overlap is passed through for the ones that need it', () {
      final (service: s, backend: b, clock: _) = build();
      unawaited(s.play('goal', overlap: true));
      expect(b.sfx.single.overlap, isTrue);
    });

    test('the firework is a bundled recording, kept well back', () {
      final (service: s, backend: b, clock: _) = build();
      unawaited(s.playFirework());
      expect(b.assets.single.asset, fireworkAsset);
      expect(
        b.assets.single.volume,
        closeTo(sfxBaseVolume * fireworkVolume, 1e-9),
      );
      expect(b.sfx, isEmpty, reason: 'it is not a synth');
    });
  });

  group('music', () {
    test(
      'ships off, and turning it on starts the bed the game wants',
      () async {
        final (service: s, backend: b, clock: _) = build();
        expect(s.musicEnabled, isFalse);
        expect(b.music, isEmpty);
        await s.setMusicEnabled(true);
        expect(b.music.single.asset, musicAssets[MusicBed.menu]);
      },
    );

    test('at the base level times the player\'s own', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicVolume(0.5);
      await s.setMusicEnabled(true);
      expect(b.music.single.volume, closeTo(musicBaseVolume * 0.5, 1e-9));
    });

    test('turning it off stops the bed', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicEnabled(true);
      await s.setMusicEnabled(false);
      expect(b.music.last.asset, isNull);
      expect(s.playingBed, isNull);
    });

    test('a track change CROSSFADES; starting from silence does not', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicEnabled(true);
      expect(b.music.single.fade, isFalse, reason: 'faded in from nothing');
      await s.setMusicTrack(MusicBed.match);
      expect(b.music.last.asset, musicAssets[MusicBed.match]);
      expect(b.music.last.fade, isTrue);
    });

    test('asking for the bed already playing does not restart it', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicEnabled(true);
      final calls = b.music.length;
      await s.setMusicTrack(MusicBed.menu);
      expect(b.music.length, calls);
    });

    test('the wanted bed is REMEMBERED while music is off', () async {
      // Turning music back on mid-match has to resume the match bed rather than
      // dropping to the menu loop.
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicTrack(MusicBed.match);
      expect(b.music, isEmpty, reason: 'it played with music off');
      expect(s.wantedBed, MusicBed.match);
      await s.setMusicEnabled(true);
      expect(b.music.single.asset, musicAssets[MusicBed.match]);
    });

    test('and while the app is away', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicEnabled(true);
      await s.suspend();
      await s.setMusicTrack(MusicBed.match);
      expect(
        b.music.last.asset,
        musicAssets[MusicBed.menu],
        reason: 'a bed started behind the OS',
      );
      await s.resume();
      expect(b.music.last.asset, musicAssets[MusicBed.match]);
    });

    test('a volume change while playing reaches the channel', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicEnabled(true);
      await s.setMusicVolume(0.25);
      expect(b.volumes.last, closeTo(musicBaseVolume * 0.25, 1e-9));
    });
  });

  group('going away and coming back', () {
    test('pauses the bed in place and cuts anything in flight', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.setMusicEnabled(true);
      await s.suspend();
      expect(b.paused, 1);
      expect(b.stopped, 1);
      // Paused, NOT stopped: coming back picks the loop up where it left off.
      expect(b.music.last.asset, isNotNull);
    });

    test('and both calls are idempotent', () async {
      // The signals that trigger them overlap by platform.
      final (service: s, backend: b, clock: _) = build();
      await s.suspend();
      await s.suspend();
      expect(b.paused, 1);
      await s.resume();
      await s.resume();
      expect(s.suspended, isFalse);
    });

    test('coming back with music off starts nothing', () async {
      final (service: s, backend: b, clock: _) = build();
      await s.suspend();
      await s.resume();
      expect(b.music, isEmpty);
      expect(b.resumed, 0);
    });

    test(
      'and coming back onto the same bed resumes rather than restarts',
      () async {
        final (service: s, backend: b, clock: _) = build();
        await s.setMusicEnabled(true);
        final calls = b.music.length;
        await s.suspend();
        await s.resume();
        expect(
          b.music.length,
          calls,
          reason: 'the loop restarted from the top',
        );
        expect(b.resumed, 1);
      },
    );
  });
  group('EVERY EFFECT IS A ONE-SHOT, with an end the caller can see', () {
    // **Reported as the signing sound playing continuously and never
    // stopping.** The root cause was not reproducible without a device, but a
    // clip whose stop depends on three platform calls all succeeding is a clip
    // that can run forever — and it does not have to be. The backend arms the
    // stop BEFORE anything that can throw now; what this pins is the half the
    // service owns: every cue hands down a finite length, and none of them asks
    // to overlap unless it is one of the two that stack.
    test('the length is finite, short, and matches the definition', () {
      final (service: s, backend: b, clock: clock) = build();
      for (final name in fakeRender().keys) {
        b.sfx.clear();
        clock.tick();
        s.play(name);
        expect(b.sfx, hasLength(1), reason: name);
        final sent = b.sfx.single.length;
        expect(sent, soundLength(name), reason: name);
        expect(sent, greaterThan(Duration.zero), reason: name);
        expect(
          sent,
          lessThan(const Duration(seconds: 5)),
          reason: '$name is long enough to read as stuck',
        );
      }
    });

    test('AND EVERY DEFINITION HAS A LENGTH', () {
      // `soundLength` falls back to 0.4s for an unknown name, which would hand
      // the backend a stop that is nothing to do with the clip it is stopping.
      for (final name in soundDefs.keys) {
        expect(soundDefs[name]!.seconds, greaterThan(0), reason: name);
        expect(
          soundLength(name),
          greaterThan(Duration.zero),
          reason: name,
        );
      }
    });

    test('and a SIGNING does not stack — it retriggers', () {
      // Stacking is the whole point of the two that ask for it and a defect
      // everywhere else: four copies of one cue is a sound that does not stop.
      final (service: s, backend: b, clock: _) = build();
      s.play('scout');
      expect(b.sfx.single.overlap, isFalse);
    });
  });

}

void _sessionGroup() {
  group('THE AUDIO SESSION', () {
    test('MIXES rather than taking the device', () {
      // **The port never set one, and the default takes exclusive focus.**
      // `AudioContextConfigFocus.gain` — what `audioplayers` uses when nobody
      // says otherwise — leaves `mixWithOthers` off on iOS and requests
      // `AndroidAudioFocus.gain` on Android, so the first coin sound PAUSES
      // whatever the player was listening to. The shipped app is WebAudio in a
      // WKWebView and mixes, so this was a regression the port introduced by
      // saying nothing at all — and one that gets reported as "the game
      // stopped my music", never as an audio session being wrong.
      expect(
        AudioPlayersBackend.sessionConfig.focus,
        AudioContextConfigFocus.mixWithOthers,
      );
    });

    test('and does not claim the ring switch either way', () {
      // Making the game obey silent mode is a real question, but it is a
      // CHANGE of behaviour rather than a restoration of it — it wants checking
      // on hardware against the shipped build, so the default stands and this
      // records that it was a decision.
      expect(AudioPlayersBackend.sessionConfig.respectSilence, isFalse);
    });
  });
}
