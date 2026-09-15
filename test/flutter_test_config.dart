/// Package-wide setup for every widget test in the suite.
///
/// **AN AMBIENT ANIMATION HANGS `pumpAndSettle`, and that is not a bug in
/// either of them.** `pumpAndSettle` returns when the tree stops changing;
/// something that repeats for as long as it is on screen never lets it. The
/// shop's tile shine is exactly that, and shop tiles are rendered by the
/// shell's tests, the home screen's, the club's and the light-mode contrast
/// sweep as well as the shop's own — so gating it on each harness would leave
/// the next test anybody writes hanging with no clue as to why.
///
/// Dart's test runner looks for this file once per package and wraps the whole
/// run in it, which makes it the one honest place for a switch like this.
/// `shopShineEnabled` is off for tests and on for players; a test that wants
/// the animation can set it back for its own duration.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_shine.dart';

/// **THE AUDIO PLUGIN IS NOT THERE, AND IT SAYS SO ASYNCHRONOUSLY.**
///
/// `audioplayers` opens a global EVENT channel as soon as anything touches it,
/// and under `flutter test` there is no platform implementation behind any of
/// its channels. The resulting `MissingPluginException` is thrown from an
/// `await` inside `EventChannel.receiveBroadcastStream`, which means it does
/// not belong to the test that caused it — it surfaces on whichever test the
/// framework happens to be running when the future completes, and fails THAT
/// one.
///
/// That is the whole of the suite's flakiness outside `cup_launcher_test`: a
/// different innocent test died on every full run — the home diorama's repaint
/// scope, eight of the shop's look packs, the season-end screen, the boot room
/// — while every one of them passed alone. The `-j` fan-out decides who is
/// unlucky, which is why it never reproduced twice in the same place and why
/// running the file on its own always looked fine.
///
/// Stubbed for the whole package rather than per harness: the channels are
/// touched by anything that plays a sound, which by now is most of the screens,
/// and a test that forgets the stub does not fail — it fails somebody else.
///
/// The names are `audioplayers_platform_interface`'s own. The per-player event
/// channel carries a player id in its name and cannot be registered up front;
/// it is also not the one that throws, because the global scope is opened
/// first and `SoundService` is what the screens reach.
void _silenceAudioPlugin() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // **THE RAW MESSAGE HANDLER, not `setMockMethodCallHandler` or
  // `setMockStreamHandler`.** Both of those register an `addTearDown`, which
  // only exists inside a running test — from here they throw "addTearDown()
  // may only be called within a test" before a single test has loaded. This
  // seam takes bytes and is happy to be installed once for the whole package.
  //
  // An empty success envelope is what "the plugin is there and has nothing to
  // say" looks like on the wire. Answering with `null` instead would be read as
  // no implementation at all, which is the exception being stubbed out.
  const codec = StandardMethodCodec();
  for (final name in const [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    // The `listen` and `cancel` of the global event channel — the one whose
    // unhandled `listen` was failing other people's tests.
    'xyz.luan/audioplayers.global/events',
  ]) {
    messenger.setMockMessageHandler(
      name,
      (message) async => codec.encodeSuccessEnvelope(null),
    );
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _silenceAudioPlugin();
  shopShineEnabled = false;
  await testMain();
}
