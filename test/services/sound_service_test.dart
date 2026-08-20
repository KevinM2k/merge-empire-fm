/// The sound engine's RULES.
///
/// None of them need a device, which is the point of keeping the platform behind
/// a backend: every decision about whether a sound may play is arithmetic on a
/// handful of fields, and it is exactly the part that had gone wrong in the JS
/// often enough to be commented.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/sound_service.dart';

class FakeBackend implements SoundBackend {
  final List<({String name, double volume, bool overlap})> sfx = [];
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
  }) async => sfx.add((name: name, volume: volume, overlap: overlap));

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
  for (final name in ['merge', 'coin', 'goal']) name: Uint8List(1),
};

({SoundService service, FakeBackend backend}) build() {
  final backend = FakeBackend();
  final service = SoundService(backend: backend, render: fakeRender)
    ..warmUpNow();
  return (service: service, backend: backend);
}

void main() {
  group('effects', () {
    test('play at the base level times the player\'s own', () {
      final (service: s, backend: b) = build();
      s.play('merge');
      expect(b.sfx.single.volume, closeTo(sfxBaseVolume, 1e-9));
      s.setSoundVolume(0.5);
      s.play('merge');
      expect(b.sfx.last.volume, closeTo(sfxBaseVolume * 0.5, 1e-9));
    });

    test('and volume clamps rather than trusting the save', () {
      final (service: s, backend: _) = build();
      s.setSoundVolume(4);
      expect(s.sfxVolume, 1);
      s.setSoundVolume(-1);
      expect(s.sfxVolume, 0);
    });

    test('nothing plays with sound off', () {
      final (service: s, backend: b) = build();
      s.setSoundEnabled(false);
      s.play('merge');
      expect(b.sfx, isEmpty);
    });

    test('nothing plays while the app is away', () async {
      // Without this the OS keeps playing after the app leaves the foreground.
      final (service: s, backend: b) = build();
      await s.suspend();
      s.play('merge');
      expect(b.sfx, isEmpty);
      await s.resume();
      s.play('merge');
      expect(b.sfx, hasLength(1));
    });

    test('an unknown or not-yet-rendered sound is silent, not an error', () {
      // A missing effect must never throw: the alternative is a game that
      // crashes on a tap.
      final backend = FakeBackend();
      final cold = SoundService(backend: backend, render: fakeRender);
      expect(() => unawaited(cold.play('merge')), returnsNormally);
      expect(backend.sfx, isEmpty);
      final (service: s, backend: b) = build();
      expect(() => unawaited(s.play('nothing-like-this')), returnsNormally);
      expect(b.sfx, isEmpty);
    });

    test('overlap is passed through for the ones that need it', () {
      final (service: s, backend: b) = build();
      s.play('goal', overlap: true);
      expect(b.sfx.single.overlap, isTrue);
    });

    test('the firework is a bundled recording, kept well back', () {
      final (service: s, backend: b) = build();
      s.playFirework();
      expect(b.assets.single.asset, fireworkAsset);
      expect(
        b.assets.single.volume,
        closeTo(sfxBaseVolume * fireworkVolume, 1e-9),
      );
      expect(b.sfx, isEmpty, reason: 'it is not a synth');
    });
  });

  group('music', () {
    test('ships off, and turning it on starts the bed the game wants', () async {
      final (service: s, backend: b) = build();
      expect(s.musicEnabled, isFalse);
      expect(b.music, isEmpty);
      await s.setMusicEnabled(true);
      expect(b.music.single.asset, musicAssets[MusicBed.menu]);
    });

    test('at the base level times the player\'s own', () async {
      final (service: s, backend: b) = build();
      await s.setMusicVolume(0.5);
      await s.setMusicEnabled(true);
      expect(b.music.single.volume, closeTo(musicBaseVolume * 0.5, 1e-9));
    });

    test('turning it off stops the bed', () async {
      final (service: s, backend: b) = build();
      await s.setMusicEnabled(true);
      await s.setMusicEnabled(false);
      expect(b.music.last.asset, isNull);
      expect(s.playingBed, isNull);
    });

    test('a track change CROSSFADES; starting from silence does not', () async {
      final (service: s, backend: b) = build();
      await s.setMusicEnabled(true);
      expect(b.music.single.fade, isFalse, reason: 'faded in from nothing');
      await s.setMusicTrack(MusicBed.match);
      expect(b.music.last.asset, musicAssets[MusicBed.match]);
      expect(b.music.last.fade, isTrue);
    });

    test('asking for the bed already playing does not restart it', () async {
      final (service: s, backend: b) = build();
      await s.setMusicEnabled(true);
      final calls = b.music.length;
      await s.setMusicTrack(MusicBed.menu);
      expect(b.music.length, calls);
    });

    test('the wanted bed is REMEMBERED while music is off', () async {
      // Turning music back on mid-match has to resume the match bed rather than
      // dropping to the menu loop.
      final (service: s, backend: b) = build();
      await s.setMusicTrack(MusicBed.match);
      expect(b.music, isEmpty, reason: 'it played with music off');
      expect(s.wantedBed, MusicBed.match);
      await s.setMusicEnabled(true);
      expect(b.music.single.asset, musicAssets[MusicBed.match]);
    });

    test('and while the app is away', () async {
      final (service: s, backend: b) = build();
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
      final (service: s, backend: b) = build();
      await s.setMusicEnabled(true);
      await s.setMusicVolume(0.25);
      expect(b.volumes.last, closeTo(musicBaseVolume * 0.25, 1e-9));
    });
  });

  group('going away and coming back', () {
    test('pauses the bed in place and cuts anything in flight', () async {
      final (service: s, backend: b) = build();
      await s.setMusicEnabled(true);
      await s.suspend();
      expect(b.paused, 1);
      expect(b.stopped, 1);
      // Paused, NOT stopped: coming back picks the loop up where it left off.
      expect(b.music.last.asset, isNotNull);
    });

    test('and both calls are idempotent', () async {
      // The signals that trigger them overlap by platform.
      final (service: s, backend: b) = build();
      await s.suspend();
      await s.suspend();
      expect(b.paused, 1);
      await s.resume();
      await s.resume();
      expect(s.suspended, isFalse);
    });

    test('coming back with music off starts nothing', () async {
      final (service: s, backend: b) = build();
      await s.suspend();
      await s.resume();
      expect(b.music, isEmpty);
      expect(b.resumed, 0);
    });

    test('and coming back onto the same bed resumes rather than restarts',
        () async {
      final (service: s, backend: b) = build();
      await s.setMusicEnabled(true);
      final calls = b.music.length;
      await s.suspend();
      await s.resume();
      expect(b.music.length, calls, reason: 'the loop restarted from the top');
      expect(b.resumed, 1);
    });
  });
}
