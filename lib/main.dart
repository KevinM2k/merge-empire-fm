import 'dart:async';

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/providers/boot_gate.dart';
import 'package:merge_empire_fc/providers/game_host.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/providers/voice_providers.dart';
import 'package:merge_empire_fc/ui/shell/screen_covered.dart';
import 'package:merge_empire_fc/providers/i18n_providers.dart';
import 'package:merge_empire_fc/ui/popups/achievement_unlock.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/popups/toast_host.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_overlay.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/shell/orientation_lock.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/services/admob_ads.dart';
import 'package:merge_empire_fc/services/analytics_service.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/providers/low_end_device.dart';
import 'package:merge_empire_fc/services/prefs_save_store.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/boot_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // detect.dart takes the platform locales rather than reading the binding, so
  // it stays testable and Flutter-free. This is the one place that supplies them.
  setDeviceLocales(
    PlatformDispatcher.instance.locales.map((l) => l.toLanguageTag()).toList(),
  );
  // The store is read into memory before the first frame: everything
  // downstream of it is synchronous, and a save layer that answers null while
  // it warms up would boot the player onto a default state.
  // **Analytics and the crash reporter go up FIRST**, before anything that
  // could fail: their whole value is catching what happens next, and a boot
  // that crashes before the reporter is installed is the one crash nobody ever
  // sees. Not awaited beyond its own init — every step inside is guarded, and a
  // build with no Firebase leaves the default sink, which drops.
  unawaited(startAnalytics());
  final store = await PrefsSaveStore.open();
  // **The ad SDK starts AFTER the splash, and nothing waits for it.**
  // `startAds` asks for consent first, and the UMP form's future does not
  // complete until the player dismisses it — awaited here, it held the app on
  // the launch splash for as long as the form was up. The override is the
  // pending adapter, which a tap waits on; see `services/rewarded_ads.dart`.
  final ads = PendingRewardedAds(_adsAfterTheSplash());
  runApp(
    ProviderScope(
      overrides: [
        saveStoreProvider.overrideWithValue(store),
        rewardedAdsProvider.overrideWithValue(ads),
      ],
      // The splash wraps the app rather than living inside it, exactly as the
      // JS's `#splash` is a sibling of `#app` — see `ui/boot_splash.dart`.
      //
      // **The Consumer is only here to hand it the GATE.** The splash itself
      // stays provider-free — it covers the loading of the theme, the locale
      // and the save, so it must not depend on any of them — and this reads
      // the one thing it does wait for: whether the boot's cloud restore has
      // settled. See `providers/boot_gate.dart`.
      child: Consumer(
        builder: (context, ref, child) => BootSplash(
          gate: ref.read(bootGateProvider).settled,
          // **AND NOTHING UNDER IT IS RUNNING.** The splash is a sibling of the
          // app rather than a route — the JS's `#splash` is a sibling of `#app`
          // — so nothing beneath it is ever told it has stopped being looked
          // at: `TickerMode` is untouched and a dialog on the navigator carries
          // on as if it were on screen. Coach Colin's gibberish was the first
          // thing to notice and it noticed loudly, from behind the loading
          // screen.
          //
          // `screenCoveredProvider` is the counter the shell already keeps for
          // exactly this question — a modal sheet is the other thing that
          // covers the app without telling it — so the splash joins it rather
          // than muting one service by hand. Muting was tried first and it
          // traded the fault for a worse one: the line was announced, dropped
          // on the floor, and never heard at all. A card HOLDS its line while
          // this is up; see `CoachTypewriter`.
          onCover: () => ref.read(screenCoveredProvider.notifier).state++,
          onLift: () {
            final n = ref.read(screenCoveredProvider);
            if (n > 0) ref.read(screenCoveredProvider.notifier).state = n - 1;
          },
          child: child!,
        ),
        child: const MergeEmpireApp(),
      ),
    ),
  );
}

/// The ad stack, started once the splash has lifted — the consent form is a
/// dialog over the game, and one over a loading screen is indistinguishable
/// from a hang. `startAds` never throws, so this only completes with an adapter.
Future<RewardedAds> _adsAfterTheSplash() {
  final ready = Completer<RewardedAds>();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(splashWindow);
    ready.complete(await startAds());
  });
  return ready.future;
}

class MergeEmpireApp extends ConsumerWidget {
  const MergeEmpireApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Merge Empire Football Manager',
      theme: ref.watch(appThemeProvider),
      // iOS-style bounce everywhere: Android's clamp-and-stretch read as
      // "not native" on the squad, shop, club and settings lists.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
        overscroll: false,
      ),
      // Arabic reads right to left. This is the whole of what the JS did by
      // setting document.dir.
      locale: Locale(ref.watch(localeProvider)),
      supportedLocales: supportedLocales.map(Locale.new),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // SoundHost OUTSIDE the game host: the engine's warm-up and its
      // lifecycle handling have nothing to do with the save, and putting it
      // inside would tie the first sound to a boot that has to finish first.
      // **NOT `const` any more**, because the tree now reads a provider: the
      // low-end answer decides whether the glass blurs, and a const subtree
      // cannot watch anything.
      // Sideways is blocked on a phone and allowed on a tablet — see
      // [OrientationLock]. Inside `home` because it measures the device through
      // `MediaQuery`, which `MaterialApp` supplies here and not above it.
      home: OrientationLock(
        child: SoundHost(
          // VoiceHost inside SoundHost and outside the game host, for the same
          // reason SoundHost is where it is: it wires the bus and watches the
          // app's lifecycle, and neither has anything to do with the save
          // having finished loading.
          child: VoiceHost(
            child: GameHost(
              // PopupHost sits above the shell: it releases the queue's no-host
              // blocker, so anything queued during boot has waited rather than been
              // dropped for want of somewhere to open.
              // ToastHost inside PopupHost: a toast never blocks and never waits, so
              // it sits under whatever the queue has put up rather than over it. The
              // achievement banner is inside both for the same reason, and it is the
              // innermost of the three: it is the one that is purely a celebration.
              // **THE ONE PLACE THE LOW-END ANSWER IS SUPPLIED.** `util/device.dart`
              // was ported, fixture-tested against the JS and called by NOTHING:
              // every threshold matched, the one-way promotion was implemented, and
              // no widget ever asked. `glass.css` names the backdrop blur as the
              // thing that most wants the opt-out, so the glass is what reads it.
              child: GlassQuality(
                blurAllowed: !ref.watch(lowEndDeviceProvider),
                child: const PopupHost(
                  // **THE TUTORIAL IS THE APP'S, not the shell's.** It draws nothing
                // itself — it opens Colin's card and switches tabs — and it hangs
                // here rather than inside `AppShell` for a reason worth keeping:
                // a shell built for a test is a save that has never been played,
                // which IS a save the tutorial should run for. Seventy-nine tests
                // about the HUD, the tabs and the popups are not about that, and a
                // widget that opens a card over all of them belongs at the app's
                // own root where they never reach it.
                  child: ToastHost(
                    child: AchievementUnlockHost(
                      child: Stack(
                        children: [AppShell(), TutorialHost()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
