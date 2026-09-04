/// A press makes a noise.
///
/// **THE BUTTONS WERE SILENT.** `'tap'` is in `sound_defs.dart` and the only
/// things that ever played it were the five mini-games — reported from the couch
/// as having been lost, and as the bottom HUD buttons in particular having once
/// clicked. Nothing was lost; it was never wired outside the drills. It hangs
/// off the splash factory now, so the framework decides what counts as a button
/// rather than a list somebody has to keep current. See [TapSoundSplash].
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/sound_service.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// A backend that only remembers what it was asked to play.
class _EarBackend implements SoundBackend {
  final List<String> played = [];

  @override
  Future<void> playSfx(
    String name,
    Uint8List wav, {
    required double volume,
    required bool overlap,
    required Duration length,
  }) async => played.add(name);

  @override
  Future<void> playAsset(String asset, {required double volume}) async {}
  @override
  Future<void> setMusic(
    String? asset, {
    required double volume,
    required bool fade,
  }) async {}
  @override
  Future<void> setMusicVolume(double volume) async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> resumeMusic() async {}
  @override
  Future<void> stopAllSfx() async {}
}

void main() {
  late _EarBackend ear;
  late int presses;

  setUp(() {
    ear = _EarBackend();
    presses = 0;
  });

  /// The real theme, with the cue counted rather than played — the engine
  /// synthesises its cache in an isolate and a widget test has no business
  /// waiting for it.
  ThemeData theme() => buildAppTheme(
    kitId: 'red_white',
    light: false,
    onPress: () => presses++,
  );

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: theme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('a Material button clicks when pressed', (tester) async {
    await pump(
      tester,
      ElevatedButton(onPressed: () {}, child: const Text('go')),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(presses, 1);
  });

  testWidgets('AND SO DOES AN INKWELL, which is what the bottom HUD is', (
    tester,
  ) async {
    // `shell/tab_bar.dart` builds its tabs out of `InkWell`, so the same hook
    // covers the row the report was actually about.
    await pump(
      tester,
      InkWell(onTap: () {}, child: const SizedBox(width: 60, height: 60)),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(presses, 1);
  });

  testWidgets('a StoreButton clicks too, having no ink to hang one off', (
    tester,
  ) async {
    await pump(
      tester,
      StoreButton(label: 'buy', tone: StoreTone.gem, onTap: () {}),
    );
    await tester.tap(find.text('buy'));
    await tester.pumpAndSettle();
    expect(presses, 1);
  });

  testWidgets('a dead StoreButton does not', (tester) async {
    await pump(
      tester,
      const StoreButton(label: 'buy', tone: StoreTone.gem, onTap: null),
    );
    await tester.tap(find.text('buy'));
    await tester.pumpAndSettle();
    expect(presses, 0);
  });

  testWidgets('a theme built with no cue is silent', (tester) async {
    // Which is every test that builds a theme directly, and is why the
    // parameter is optional.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: 'red_white', light: false),
        home: Scaffold(
          body: ElevatedButton(onPressed: () {}, child: const Text('go')),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(presses, 0);
  });

  test('THE TOGGLE IS THE GATE, and the service already is one', () async {
    // `play` returns before it reaches the backend unless sound is on, so the
    // cue needs no gate of its own — which is the whole reason it is wired to
    // the service rather than to the backend.
    final service = SoundService(backend: ear);
    service.setSoundEnabled(false);
    await service.play('tap');
    expect(ear.played, isEmpty);
  });
}
