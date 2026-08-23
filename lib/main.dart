import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/providers/game_host.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/providers/i18n_providers.dart';
import 'package:merge_empire_fc/ui/popups/achievement_unlock.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/popups/toast_host.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_overlay.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/services/admob_ads.dart';
import 'package:merge_empire_fc/services/prefs_save_store.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';

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
  final store = await PrefsSaveStore.open();
  // **The ad SDK, after consent and before the first frame.** `startAds` asks
  // for consent first — serving before that answer exists is what the gate is
  // there to stop — and hands back `NoRewardedAds` on any platform without the
  // SDK, so a desktop or test host is unchanged.
  //
  // Awaited rather than backgrounded because the OVERRIDE is what the whole
  // chain reads: a provider that starts as the null adapter and swaps later
  // would leave the first screen's rewarded buttons saying "coming soon".
  final ads = await startAds();
  runApp(
    ProviderScope(
      overrides: [
        saveStoreProvider.overrideWithValue(store),
        rewardedAdsProvider.overrideWithValue(ads),
      ],
      child: const MergeEmpireApp(),
    ),
  );
}

class MergeEmpireApp extends ConsumerWidget {
  const MergeEmpireApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Merge Empire Football Manager',
      theme: ref.watch(appThemeProvider),
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
      home: const SoundHost(
        child: GameHost(
          // PopupHost sits above the shell: it releases the queue's no-host
          // blocker, so anything queued during boot has waited rather than been
          // dropped for want of somewhere to open.
          // ToastHost inside PopupHost: a toast never blocks and never waits, so
          // it sits under whatever the queue has put up rather than over it. The
          // achievement banner is inside both for the same reason, and it is the
          // innermost of the three: it is the one that is purely a celebration.
          child: PopupHost(
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
    );
  }
}
