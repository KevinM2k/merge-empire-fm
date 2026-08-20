/// What decides WHICH sky is showing, and for how long. Ported from
/// `LeagueScreen._weatherCycle` in `../merge-empire-fc/src/ui/screens/`.
///
/// The engine has always been able to answer "what is the weather"; nothing has
/// ever asked it on a clock. [resolveCondition] is a snapshot, and the two modes
/// it can return want completely different treatment:
///
/// - **Live weather HOLDS.** It is the player's real sky, so it changes when the
///   sky does and not on a timer of ours. All this does is re-ask every
///   [liveRecheck] in case a fresh reading has landed.
/// - **Seasonal weather RUNS SPELLS.** A roll, a spell of that condition, then a
///   clear gap, then another roll. `clear` has no spell of its own because it IS
///   the gap — so it falls straight through to the next roll rather than being
///   scheduled twice.
///
/// The timers are the whole content of this file, which is why it is separate
/// from the layers that draw the result: a spell that is too short or a gap that
/// never re-arms is a bug about scheduling, and it is testable with a fake clock
/// and no widget at all.
library;

import 'dart:async';

import 'package:merge_empire_fc/engine/weather_engine.dart';
import 'package:merge_empire_fc/services/weather_service.dart' show liveRecheck;
import 'package:merge_empire_fc/util/time.dart';

/// What the scene should draw, and what the wind is doing while it draws it.
typedef WeatherView = ({String condition, String source, num windKph});

const WeatherView clearSky = (
  condition: 'clear',
  source: 'seasonal',
  windKph: 0,
);

/// The spell scheduler.
///
/// Nothing here draws and nothing here fetches — [refreshLive] is a callback for
/// the same reason [GameRunner.gates] is: the network belongs to the service and
/// the sky belongs to the widget, and a scheduler that reached for either could
/// not be tested without both.
class WeatherCycle {
  WeatherCycle({
    required this.saveState,
    required this.onCondition,
    this.refreshLive,
    double Function()? rand,
  }) : _rand = rand;

  /// The live save, read fresh on every roll. A cloud restore can replace the
  /// player's whole location under us, so this is a callback rather than a
  /// captured map.
  final Map<String, dynamic>? Function() saveState;

  /// Called every time the sky should change, and once immediately on [start].
  final void Function(WeatherView view) onCondition;

  /// Best-effort nudge to go and fetch a live reading. Fire and forget: every
  /// failure mode is already "carry on with the seasonal model".
  final void Function()? refreshLive;

  final double Function()? _rand;

  /// The re-roll, or the next look at the live cache.
  Timer? _next;

  /// The end of the current spell.
  Timer? _spell;

  bool _running = false;
  bool get isRunning => _running;

  /// The last view handed to [onCondition]. Exposed for the caller that wants to
  /// know what it is showing without keeping its own copy.
  WeatherView get view => _view;
  WeatherView _view = clearSky;

  /// Begin. Idempotent, so a rebuild cannot start a second set of timers.
  ///
  /// Asks for a fresh reading first, exactly as the JS does on mount — otherwise
  /// the first sky a player sees is always the seasonal model's, and the live one
  /// only arrives at the first recheck five minutes later.
  void start() {
    if (_running) return;
    _running = true;
    _requestRefresh();
    _turn();
  }

  /// Stop, and cancel both timers. A stopped cycle leaves whatever it last
  /// showed on screen: the sky is not wrong just because we stopped watching it.
  void stop() {
    _running = false;
    _next?.cancel();
    _next = null;
    _spell?.cancel();
    _spell = null;
  }

  void _requestRefresh() {
    if (shouldRefreshLive(saveState(), now())) refreshLive?.call();
  }

  void _emit(String condition, {String? source, num? windKph}) {
    _view = (
      condition: condition,
      source: source ?? _view.source,
      windKph: windKph ?? _view.windKph,
    );
    onCondition(_view);
  }

  /// One turn, which re-arms itself.
  void _turn() {
    if (!_running) return;
    final resolved = resolveCondition(saveState(), now(), _rand);

    if (resolved.source == 'live') {
      _emit(resolved.condition, source: 'live', windKph: resolved.windKph);
      _next = Timer(liveRecheck, () {
        _next = null;
        _requestRefresh();
        _turn();
      });
      return;
    }

    // Seasonal. The wind speed goes with it — the model has no measured one, and
    // `windAccelFor` would rather fall back to a default than be handed a zero
    // that means "calm".
    _emit(resolved.condition, source: 'seasonal', windKph: resolved.windKph);

    void nextRoll() {
      _next = Timer(Duration(milliseconds: gapDurationMs(_rand).round()), () {
        _next = null;
        _turn();
      });
    }

    final spell = spellDurationMs(resolved.condition, _rand);
    if (spell <= 0) {
      nextRoll();
      return;
    }
    _spell = Timer(Duration(milliseconds: spell.round()), () {
      _spell = null;
      if (!_running) return;
      _emit('clear');
      nextRoll();
    });
  }
}
