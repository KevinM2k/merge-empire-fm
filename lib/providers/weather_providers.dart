/// The sky, as something a widget can watch.
///
/// [WeatherCycle] owns the timers and `pitch_weather.dart` owns the paint; this
/// is the seam between them, and it is the only place either has to know about
/// Riverpod.
///
/// **NOTHING HERE STARTS ITSELF.** [GameHost] starts the cycle and stops it with
/// the game loop, which is the JS's arrangement — `_weatherCycle` runs from
/// `LeagueScreen`'s mount — routed through the one widget that only exists when
/// the app really is running.
///
/// The alternative was starting on first watch, and it does not survive contact
/// with the test suite: `flutter_test` asserts on pending timers while the tree
/// is still mounted, so a provider that armed a spell timer the moment a screen
/// read it failed every widget test that so much as built the home tab — fifty
/// of them, all about something else. The same reasoning keeps the network out
/// of here: the host owns every call to the sky, boot, resume and recheck alike.
///
/// A test that wants weather on screen hands `PitchScene` a condition. A test
/// that wants the SCHEDULE drives [WeatherCycle] with a fake clock. Neither
/// needs this file, which is the point of it being this thin.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/weather_cycle.dart';

/// What the diorama should be drawing.
final weatherProvider = NotifierProvider<WeatherWatch, WeatherView>(
  WeatherWatch.new,
);

class WeatherWatch extends Notifier<WeatherView> {
  late final WeatherCycle _cycle;

  @override
  WeatherView build() {
    _cycle = WeatherCycle(
      saveState: () => ref.read(gameProvider).state,
      onCondition: (view) => state = view,
    );
    ref.onDispose(_cycle.stop);
    return _cycle.view;
  }

  /// Begin watching the sky. Emits the first condition immediately, so the
  /// scene is right on the frame after this rather than at the first spell.
  void start() => _cycle.start();

  /// Stop. Whatever it last showed stays on screen: the sky is not wrong just
  /// because nobody is looking at it.
  void stop() => _cycle.stop();
}
