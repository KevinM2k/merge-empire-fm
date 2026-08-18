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
