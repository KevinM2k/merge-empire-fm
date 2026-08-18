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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_runner.dart';
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
    _ensureRegion(_runner.game, dispatcher.locale.toLanguageTag());
    _runner.start();
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

  @override
  void dispose() {
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
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        ref.read(appHiddenProvider.notifier).state = true;
        _runner.pause();
      case AppLifecycleState.inactive:
        // A banner, the app switcher, a phone call. The player has not left.
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
