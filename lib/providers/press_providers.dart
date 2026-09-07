/// **WHAT A PRESS ANSWERS WITH, and its two switches.** The click is the sound
/// engine's — `playUi`, on the Interface channel — and these are the other two:
/// the buzz, and the ripple that follows the finger. All three are fired from
/// one place, the theme's splash factory, so this file is the settings side of
/// what `ui/theme/theme_providers.dart` wires.
///
/// The buzz engine, wired to the save.
///
/// **NOTHING CALLS THE SERVICE'S SWITCH BY HAND**, exactly as with the sound:
/// the settings screen writes `hapticsEnabled` and stops there, and
/// [hapticsSyncProvider] is what carries it to the engine — so a value arriving
/// from a cloud restore or a reset lands the same way a tap does.
///
/// **THE KEY IS ABSENT FROM `state_schema.dart` ON PURPOSE**, for the reason
/// `themeMode` and the interface audio channel are: the schema is compared
/// against the JS's default state field for field, and this is the port's own.
/// So the ABSENT key has to carry the default, and this one ships ON — `!= false`
/// rather than the interface channel's `== true`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/haptics_service.dart';

/// The engine. One per app.
final hapticsServiceProvider = Provider<HapticsService>(
  (ref) => HapticsService(),
);

/// The save value the engine follows. See the header for the default.
final hapticsEnabledProvider = savePick<bool>((s) {
  final settings = s['settings'];
  return settings is Map<String, dynamic>
      ? settings['hapticsEnabled'] != false
      : true;
});

/// The engine, with the save's answer already in it.
///
/// **Watched by the THEME rather than by a host**, which is where the sound's
/// sync differs: the press cue is built into `appThemeProvider` and the theme is
/// alive for the whole session, so the one place that fires the buzz is also the
/// one place that has to have the switch current. There is nothing else to keep
/// alive — no warm-up, no bed, no lifecycle.
final hapticsSyncProvider = Provider<HapticsService>((ref) {
  final service = ref.watch(hapticsServiceProvider);
  service.setEnabled(ref.watch(hapticsEnabledProvider));
  return service;
});

/// Does a press leave rings behind it? See `ui/widgets/tap_ripple.dart`.
///
/// The same absent-key rule as the buzz above, and for the same reason: it is
/// the port's own key, so `state_schema.dart` does not carry it and ON is what
/// a save that has never heard of it means.
final tapRipplesEnabledProvider = savePick<bool>((s) {
  final settings = s['settings'];
  return settings is Map<String, dynamic>
      ? settings['tapRipplesEnabled'] != false
      : true;
});
