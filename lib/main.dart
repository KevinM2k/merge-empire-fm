import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/providers/game_host.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/i18n_providers.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/services/prefs_save_store.dart';

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
  runApp(
    ProviderScope(
      overrides: [saveStoreProvider.overrideWithValue(store)],
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
      home: const GameHost(
        // PopupHost sits above the shell: it releases the queue's no-host
        // blocker, so anything queued during boot has waited rather than been
        // dropped for want of somewhere to open.
        child: PopupHost(child: AppShell()),
      ),
    );
  }
}
