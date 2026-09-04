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
import 'package:merge_empire_fc/ui/widgets/art_precache.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/weather_providers.dart';
import 'package:merge_empire_fc/state/game_runner.dart';
import 'package:merge_empire_fc/engine/age_verification.dart';
import 'package:merge_empire_fc/services/admob_ads.dart';
import 'package:merge_empire_fc/services/analytics_wiring.dart';
import 'package:merge_empire_fc/engine/cloud_save_policy.dart';
import 'package:merge_empire_fc/providers/boot_gate.dart';
import 'package:merge_empire_fc/services/auth_service.dart';
import 'package:merge_empire_fc/services/play_games_service.dart';
import 'package:merge_empire_fc/services/cloud_sync.dart';
import 'package:merge_empire_fc/ui/popups/boot_popups.dart';
import 'package:merge_empire_fc/ui/popups/cloud_conflict_card.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/services/feedback_service.dart';
import 'package:merge_empire_fc/services/notifications.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/notification_plan.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
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
    // **ANALYTICS GETS THE SAVE HERE, which is the first moment there is one.**
    // `startAnalytics` runs in `main` before the store is read, so every
    // save-derived field — the division, the season, the six user properties,
    // the stable player id — is unanswerable at that point. The JS has the same
    // two-step: `initAnalytics().then(...)` reads its state singleton once boot
    // has one. Installed before `_runner.start()`, so nothing the first tick
    // emits reports `unknown` for a fact the save already knows.
    setAnalyticsStateReader(() => _runner.game.state);
    // The cold-boot half of the same thing — see [_warmArt].
    _warmArt();
    // **AND ONE AD IS WARM BEFORE ANYBODY ASKS.** Every placement serves from
    // a single unit now, so there is exactly one to keep ready and no risk of
    // warming the wrong one — and until this, only the training sheet and the
    // match summary primed it, which left every other offer in the game paying
    // a cold load on the tap. `refresh` fills an empty slot as well as a stale
    // one; it is a no-op once there is an ad in it.
    ref.read(rewardedAdsProvider).refresh();
    logAppBoot();
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
    // **The session, picked back up.** `wireAuthToFirestore` is what gives the
    // REST layer a bearer token at all — until it runs, `firestoreAuthToken`
    // is the stub that answers null — and `restore` turns the refresh token
    // kept beside the save back into a live one. Fired and forgotten: every
    // read the leaderboard makes is public, so a session that never comes back
    // costs a player nothing they can see, and a boot that waited on the
    // network to draw its first frame would be paying for it every launch.
    wireAuthToFirestore();
    unawaited(_restoreSessionAndCloud());
    // **THE STORE, ASKED ONCE AND EARLY.** `wireNativeBilling` also starts the
    // purchase stream, and it has to be listening BEFORE anything is bought:
    // that stream carries purchases this session started and ones the store is
    // redelivering from a session that died mid-payment, and a subscription
    // opened per tap would miss the second kind entirely. Which is how a
    // paid-for pack goes missing.
    wireNativeBilling({for (final product in products) product.sku});
    unawaited(storeCatalogue());
    // **THE LEADERBOARD LISTENS FROM HERE, not from `game_wiring`.** That file
    // is bus listeners that change the SAVE and nothing else, and this one
    // opens a socket — the same split that keeps the toasts and the sounds in
    // the UI layer on the same bus.
    on('match:complete', _submitMatch);
    PlayGamesService.instance.attach();
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

  /// Put a finished match on all four boards.
  ///
  /// **Fired and forgotten, and a failure is silent.** The JS queues a failed
  /// batch and replays it on reconnect; either way a board that is a match
  /// behind is not a save at risk, and there is nothing for the player to do
  /// about it. Signed out it is a no-op — there is no row to write to.
  void _submitMatch(Object? args) {
    final state = _runner.game.state;
    if (state == null || args is! Map<String, dynamic>) return;
    unawaited(
      submitMatchStats(state, args).then((ok) {
        if (ok && mounted) _runner.game.scheduleSave();
      }).catchError((Object _) {}),
    );
  }

  /// The session, then the cloud — **in that order and awaited between**.
  ///
  /// The sync needs a live bearer token, and `restore` is what turns the stored
  /// refresh token into one; running them together means the first Firestore
  /// read goes out unauthenticated and the player's own save comes back 403.
  ///
  /// **It is fired and forgotten from `initState`, not awaited in front of the
  /// first frame.** A boot that waited on the network to draw would pay for it
  /// on every launch, and the fallback at every step is the save already on the
  /// device.
  /// **AND IT LETS THE SPLASH GO when it is done**, whichever way it went.
  ///
  /// The boot draws immediately and this is still fired and forgotten — none
  /// of that changes. What changes is that the splash, which is already on
  /// screen and already going to fade, now knows when the save has stopped
  /// moving. Without it the two halves of the boot ran past each other and a
  /// restore landing a beat late swapped the whole save out from under a
  /// player already looking at their squad. See `providers/boot_gate.dart`,
  /// which also holds the timeout that stops this becoming a trap.
  Future<void> _restoreSessionAndCloud() async {
    try {
      await _restoreSessionAndCloudNow();
    } finally {
      // A restore that failed, went offline or returned early is still a
      // restore that has finished.
      ref.read(bootGateProvider).settle();
    }
  }

  Future<void> _restoreSessionAndCloudNow() async {
    // The card is the UI's half of the decision; the sync service holds the
    // seam so nothing below this layer has to know one exists.
    conflictPrompt = (cloud, local) async {
      final ctx = context;
      if (!mounted) return CloudSaveAction.upload;
      return showCloudConflictCard(ctx, cloud, local);
    };
    await AuthService.instance.restore(_runner.game.state);
    if (!mounted) return;
    // Play Games after the restore, so a Google or Apple session stands and the
    // bridge only runs for a player who has none — see `play_games_service.dart`.
    await PlayGamesService.instance.init(_runner.game);
    if (!mounted) return;
    final outcome = await runCloudBootSync(_runner.game);
    if (!mounted) return;
    if (outcome == CloudSyncOutcome.restored) {
      // The whole save changed underneath every screen watching it.
      _runner.game.notifyChanged();
    }
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
    off('match:complete', _submitMatch);
    PlayGamesService.instance.detach();
    _weatherPoll?.cancel();
    _weather.stop();
    unawaited(network.stop());
    WidgetsBinding.instance.removeObserver(this);
    // The host going away means the app is. Same treatment as a background: the
    // loop stops, the pending save lands, the mirror is flushed.
    _runner.pause();
    // And the reader goes with it: a closure holding a runner this widget has
    // finished with would have analytics describing a save nothing else reads.
    setAnalyticsStateReader(null);
    super.dispose();
  }

  /// Pay for the time the app spent in the background.
  ///
  /// **Stamped immediately, whether or not the card is ever seen.** The window
  /// is `lastSeen` to now, so leaving it unstamped means the next resume — or
  /// the next boot — measures the same hour again and pays twice. The coins
  /// ride on the card exactly as they do at boot; `showWelcomeBack` pays them
  /// however it is closed, which is the arrangement that comment already
  /// describes.
  void _bankTimeAway() {
    final save = _runner.game.state;
    if (save == null) return;
    final offline = processOfflineEarnings(save);
    _runner.game.saveNow();
    if (offline.earned <= 0) return;
    queueOfflineEarnings(
      context: () => context,
      game: _runner.game,
      offline: offline,
    );
  }

  /// Warm the portrait decoder, off the frame.
  ///
  /// Never awaited: it is an optimisation, and a screen must not wait on one.
  void _warmArt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(precacheArt(context, gridArtPaths(_runner.game.state)));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(appHiddenProvider.notifier).state = false;
        // **AND THAT CALCULATION HAS TO ACTUALLY HAPPEN.** `resume` skips the
        // elapsed time because it "belongs to the offline earnings
        // calculation" — and that calculation only ever ran on a COLD BOOT,
        // out of the popup host's `initState`. So an app backgrounded for an
        // hour and brought back had its hour skipped by the loop and banked by
        // nobody. Measured BEFORE `resume`, and before anything else here can
        // stamp `lastSeen`.
        _bankTimeAway();
        // **AND THE PERMISSION IS ASKED FOR HERE, on screen.** `armNotices`
        // used to ask as the app went AWAY, where Android 13+'s runtime dialog
        // cannot be raised — so it was answered false every time and nothing
        // was ever scheduled. Once per process, and only when the player has
        // the setting on: a prompt for a feature somebody has turned off is
        // worse than no reminders.
        if (notificationsEnabled(_runner.game.state)) {
          unawaited(ensureNoticePermission());
        }
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
        // **AND THE WARM AD HAS GONE OFF while the phone was in a pocket.**
        // AdMob expires a loaded rewarded ad about an hour after it loads and
        // says nothing; it fails at the tap, as a dismissal nobody made. A slot
        // that is still fresh is left alone, so this is free when it is not
        // needed — which is why there is no timer.
        ref.read(rewardedAdsProvider).refresh();
        // **AND THE SQUAD'S FACES ARE DECODED AGAIN.** Android trims the image
        // cache when an app goes to the background, so the first scroll back is
        // thirty-eight decodes on the raster thread with a thumb already
        // moving. Reported from a handset in exactly that shape — smooth after
        // a few passes, rough again after leaving and returning. See
        // `art_precache.dart`; a resume that lost nothing costs nothing.
        _warmArt();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        ref.read(appHiddenProvider.notifier).state = true;
        // **THE SESSION'S LAST EVENT, and the churn question's only answer.**
        // A `screen_view` says where the player was; this says what they were
        // in the middle of when they put the phone down and how long they had
        // been at it. Here rather than under `inactive`, which is a
        // notification shade — see the note at the head of this file.
        logAppBackgrounded();
        _runner.pause();
        // **AND THE CLOUD COPY, IMMEDIATELY.** `pause()` lands the local save;
        // the cloud upload is behind a debounce of its own, and a debounce is
        // exactly what the OS suspending the process eats. This is the moment
        // a save most needs to have arrived.
        unawaited(flushSaveToCloud(_runner.game.state));
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
