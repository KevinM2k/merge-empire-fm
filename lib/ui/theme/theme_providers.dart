/// The live theme, derived from the save.
library;

import 'dart:async';

import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/kit_palette.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

final kitIdProvider = savePick<String>((s) {
  final club = s['club'];
  final id = club is Map<String, dynamic> ? club['kitPrimaryColor'] : null;
  return id is String ? id : defaultKitColor;
});

/// **LIGHT, DARK OR WHATEVER THE PHONE IS ON.**
///
/// It was one switch called "Light Mode", which is a setting that can only ever
/// disagree with the device: a player whose phone goes dark at sunset had to
/// come in here and flip it themselves, twice a day. Asked for from the couch.
enum ThemeChoice { light, dark, system }

/// What the PHONE is set to.
///
/// A provider rather than a direct read of `PlatformDispatcher`, because
/// [ThemeChoice.system] has to REACT to the phone changing under a running app
/// and a plain read cannot rebuild anything. `MergeEmpireApp` keeps it in step
/// off `MediaQuery`, which is the one place above the app that hears about it.
final systemBrightnessProvider = StateProvider<Brightness>(
  (ref) => PlatformDispatcher.instance.platformBrightness,
);

/// The saved preference.
///
/// **`lightMode` is still read, and has to be.** It is the key every existing
/// save carries and the only one the JS knows about, so a save written before
/// this — or written by the web build — still resolves to the theme its owner
/// chose. `themeMode` wins where it exists.
final themeChoiceProvider = savePick<ThemeChoice>((s) {
  final settings = s['settings'];
  if (settings is! Map<String, dynamic>) return ThemeChoice.light;
  final mode = settings['themeMode'];
  return switch (mode) {
    'dark' => ThemeChoice.dark,
    'light' => ThemeChoice.light,
    'system' => ThemeChoice.system,
    // Defaults true, matching the schema: light reads better across the
    // redesign.
    _ => settings['lightMode'] != false ? ThemeChoice.light : ThemeChoice.dark,
  };
});

/// Whether the app is drawing light RIGHT NOW, which is not the same question
/// as what the player chose — see [ThemeChoice.system].
final lightModeProvider = Provider<bool>(
  (ref) => switch (ref.watch(themeChoiceProvider)) {
    ThemeChoice.light => true,
    ThemeChoice.dark => false,
    ThemeChoice.system =>
      ref.watch(systemBrightnessProvider) == Brightness.light,
  },
);

/// Set by the Event route while a THEMED event is open.
///
/// A themed event is a fixed dark showpiece and forces dark for as long as it is
/// up. An event with no palette — Deadline Day — must inherit the player's own
/// light mode: this is a property of the event, not of the screen, and forcing
/// dark on the way in once overrode light mode for an event that never asked.
final forcedDarkProvider = StateProvider<bool>((ref) => false);

final appThemeProvider = Provider<ThemeData>((ref) {
  final forcedDark = ref.watch(forcedDarkProvider);
  // **THE PRESS CUE IS WIRED HERE**, which is the only place that has both the
  // theme and the sound engine. `read`, not `watch`: the service is a singleton
  // and watching it would rebuild the whole theme for nothing.
  final sound = ref.read(soundServiceProvider);
  return buildAppTheme(
    kitId: ref.watch(kitIdProvider),
    light: forcedDark ? false : ref.watch(lightModeProvider),
    // On the INTERFACE channel, not the SFX one — see `SoundService.playUi`.
    // **`pop`, not `tap`.** The JS answers a tab tap or a swipe with `playPop`
    // — the soft sine sweep — and keeps the sharper 800Hz `tap` for the
    // mini-games and the shop's own controls, which call it themselves here
    // too. The port had every press on `tap`, and it was reported as not the
    // sound the game used to make.
    onPress: () => unawaited(sound.playUi('pop')),
  );
});

/// The dark palette of the club's own kit, for a screen that is a DARK TAKEOVER
/// in both themes.
///
/// **The match and its summary are nearly all panel, on a sky.** Both were
/// written as dark glass whichever theme is on — a pale panel on a pale page
/// makes the whole match go flat — and then hung the app's own ink on it, which
/// in light mode is near-black text on near-black glass. Reported as the play
/// screen being hard to read in light mode, the commentary worst of all, and as
/// the end-of-game screen being unreadable.
///
/// Wrapping the page in the kit's DARK theme is the fix rather than a colour
/// per widget: the surfaces were already dark, so it is the ink that was out of
/// step, and every one of them reads it from the same place.
final darkTakeoverThemeProvider = Provider<ThemeData>(
  (ref) => buildAppTheme(kitId: ref.watch(kitIdProvider), light: false),
);
