/// The live theme, derived from the save.
library;

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

final lightModeProvider = savePick<bool>((s) {
  final settings = s['settings'];
  // Defaults true, matching the schema: light reads better across the redesign.
  return settings is Map<String, dynamic> ? settings['lightMode'] != false : true;
});

/// Set by the Event route while a THEMED event is open.
///
/// A themed event is a fixed dark showpiece and forces dark for as long as it is
/// up. An event with no palette — Deadline Day — must inherit the player's own
/// light mode: this is a property of the event, not of the screen, and forcing
/// dark on the way in once overrode light mode for an event that never asked.
final forcedDarkProvider = StateProvider<bool>((ref) => false);

final appThemeProvider = Provider<ThemeData>((ref) {
  final forcedDark = ref.watch(forcedDarkProvider);
  return buildAppTheme(
    kitId: ref.watch(kitIdProvider),
    light: forcedDark ? false : ref.watch(lightModeProvider),
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
