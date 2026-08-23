/// Boot, and the app going away and coming back.
///
/// The JS hangs this off `visibilitychange` and `pagehide`. Flutter's equivalent
/// is [AppLifecycleState], with one important difference: `inactive` fires for
/// every transient interruption — the notification shade, the app switcher, an
/// incoming call banner — and stopping the loop for those would be a visible
/// stall for something the player never left. So only the states that mean the
/// app is actually gone pause it.
///
/// Pausing is not merely stopping the timer: it saves and flushes the durable
/// mirror, because on Android `detached` may be the last code that runs.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/weather_providers.dart';
import 'package:merge_empire_fc/state/game_runner.dart';
import 'package:merge_empire_fc/engine/age_verification.dart';
import 'package:merge_empire_fc/services/admob_ads.dart';
import 'package:merge_empire_fc/services/feedback_service.dart';
import 'package:merge_empire_fc/services/notifications.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';
import 'package:merge_empire_fc/services/weather_service.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/util/region.dart';

class GameHost extends ConsumerStatefulWidget {
  const GameHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GameHost> createState() => _GameHostState();
}

class _GameHostState extends ConsumerState<GameHost>
    with WidgetsBindingObserver {
  /// Held rather than read on demand: `ref` is off limits in `dispose`, and
  /// `dispose` is exactly where the loop has to be stopped.
  late final GameRunner _runner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    // The pure layers cannot read the platform, so the locale is pushed down to
    // them here — before `boot()`, because migration picks a catalogue.
    setDeviceLocales([
      for (final locale in dispatcher.locales) locale.toLanguageTag(),
    ]);
    _runner = ref.read(gameRunnerProvider)..boot();
    _weather = ref.read(weatherProvider.notifier);
    _ensureRegion(_runner.game, dispatcher.locale.toLanguageTag());
    _runner.start();
    // Start listening BEFORE the first reading is asked for, so an offline boot
    // does not burn the weather backoff on a request that cannot land.
    unawaited(network.start());
    // **The feedback queue, drained at boot — the JS's own line.** It can only
    // hold anything once the Send Feedback button exists, and that button is
    // deliberately hidden in the spec too (see `services/feedback_service.dart`);
    // wiring the drain now is what stops a queued message being stranded by the
    // release that unhides it.
    unawaited(flushFeedbackQueue());
    // **THE AGE SIGNAL, once per boot.** Google Play answers for Texas users
    // whose account has completed the state-mandated verification and for
    // nobody else, so on every other device this resolves to `unknown` — which
    // means ALLOWED, and is why it can be fired and forgotten rather than
    // awaited in front of the first frame.
    //
    // It writes into the save, so it is fired against `_runner.game.state`
    // after `boot()` has one. The AdMob flags follow the answer rather than
    // preceding it: an untagged request for a player Play has identified as a
    // child is the one thing this whole chain exists to prevent, and
    // `applyAgeFlagsToAds` is what carries it across to the SDK.
    unawaited(_checkAgeSignal());
    _refreshWeather();
    // And keep looking, on the JS's own cadence. `shouldRefreshLive` decides
    // whether looking is worth a call, so most of these cost nothing.
    //
    // **Here rather than in the diorama's own cycle**, which is where the JS
    // puts it: this widget only exists when the app does, and a network call
    // wired to something a screen watches is a request in every widget test
    // that builds that screen.
    _weatherPoll = Timer.periodic(liveRecheck, (_) => _refreshWeather());
    // Announce the load, one frame later.
    //
    // The theme and the HUD both read a derived value ABOVE this host, so they
    // are computed before boot() has a save to answer with and would hold their
    // pre-load answer until the first tick happened to notify — a second or so
    // of default-green app. It cannot go in boot(): this is initState, and
    // Riverpod refuses a provider write inside a widget lifecycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runner.game.notifyChanged();
      // And the sky starts CHANGING. The scheduler is inert until something
      // starts it, and this is the something: the JS runs its cycle off the
      // League screen's mount, and this widget is the port's answer to "the app
      // is actually running" — see `providers/weather_providers.dart`.
      //
      // A frame late for the same reason the notify is: the first turn emits,
      // and Riverpod refuses a provider write inside a widget lifecycle.
      _weather.start();
    });
  }

  /// Ask Play what age group this player is in, and tell AdMob.
  ///
  /// **Every failure here is silent and permissive**, which is the JS's own
  /// arrangement: a compliance query that throws must not stop a boot, and a
  /// missing signal is not evidence of a minor. The whole thing is a no-op on
  /// every platform without the native plugin, which today is all of them.
  Future<void> _checkAgeSignal() async {
    final state = _runner.game.state;
    if (state == null) return;
    await checkAndUpdateAgeSignal(state);
    if (!mounted) return;
    _runner.game.saveNow();
    await applyAgeFlagsToAds(getAdMobAgeFlags(state));
  }

  /// Detect the leaderboard region once, and keep it.
  ///
  /// `ensurePlayerRegion` reports whether it wrote rather than saving, because
  /// nothing down there knows how. This is the caller it was waiting for.
  void _ensureRegion(GameState game, String locale) {
    final state = game.state;
    if (state == null) return;
    if (ensurePlayerRegion(state, locale).stored) game.scheduleSave();
  }

  /// Ask the sky what it is doing.
  ///
  /// **The pure layers cannot read a timezone**, so this is where it is supplied
  /// — the same arrangement as the locale above it. `DateTime.timeZoneName` is
  /// the abbreviation rather than an IANA zone on some platforms, so the OFFSET
  /// is the fallback: `data/geo_zones.dart` resolves either, and a wrong guess
  /// costs a slightly wrong sky rather than anything.
  ///
  /// Unawaited on purpose. Boot must never wait on a network call for a
  /// backdrop, and every failure mode is already "carry on with the seasonal
  /// model" — see `services/weather_service.dart`.
  Timer? _weatherPoll;

  /// Held rather than read on demand: `ref` is unusable once the widget is
  /// disposed, and [dispose] is exactly where the sky has to be switched off.
  late final WeatherWatch _weather;

  void _refreshWeather() => refreshWeatherForGame(_runner.game);

  @override
  void dispose() {
    _weatherPoll?.cancel();
    _weather.stop();
    unawaited(network.stop());
    WidgetsBinding.instance.removeObserver(this);
    // The host going away means the app is. Same treatment as a background: the
    // loop stops, the pending save lands, the mirror is flushed.
    _runner.pause();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(appHiddenProvider.notifier).state = false;
        // The time away belongs to the offline earnings calculation, so the
        // loop skips it rather than being paid for it twice.
        _runner.resume();
        // And the weather has moved on while the app was away. `shouldRefreshLive`
        // decides whether it is worth a call, so this is cheap when it is not.
        _refreshWeather();
        _weather.start();
        // **AND THE REMINDERS COME DOWN.** They are only ever useful while the
        // app is away; one arriving while the player is looking at the game is
        // the game interrupting itself.
        unawaited(clearNotices());
        unawaited(flushFeedbackQueue());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        ref.read(appHiddenProvider.notifier).state = true;
        _runner.pause();
        // The spells stop with the loop. A sky rolling over every thirty seconds
        // behind a backgrounded app is a save read and a rebuild for something
        // nobody is looking at.
        _weather.stop();
        // **AND THE FOUR REMINDERS GO OUT.** `engine/notification_plan.dart`
        // decides which of them are worth sending; fourteen `notif.*` strings
        // were translated into ten languages with nothing able to print one.
        //
        // **Re-laid on EVERY transition, deliberately.** The deadline
        // appointment is for the next opening only, so opening the app at any
        // point in the day is what covers that evening — see the plan.
        unawaited(
          armNotices(
            _runner.game.state,
            now: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      case AppLifecycleState.inactive:
        // A banner, the app switcher, a phone call. The player has not left.
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Go and look at the real sky, best-effort.
///
/// **One function rather than one per caller.** Boot, resume and the periodic
/// recheck all ask for a reading, and the timezone, the region and the save hook
/// are three chances for three call sites to disagree about what a reading is
/// for.
///
/// Unawaited on purpose. Nothing may wait on a network call for a backdrop, and
/// every failure mode is already "carry on with the seasonal model" — see
/// `services/weather_service.dart`.
void refreshWeatherForGame(GameState game) {
  final state = game.state;
  if (state == null) return;
  unawaited(
    refreshLiveWeather(
      state,
      timeZone: DateTime.now().timeZoneName,
      online: network.isOnline,
      region: getPlayerRegionCode(state),
      onStored: game.scheduleSave,
    ),
  );
}
