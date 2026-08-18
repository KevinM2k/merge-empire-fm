/// The app booting into the shell.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/main.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

Future<void> pumpApp(WidgetTester tester, {String kit = '#4caf50'}) async {
  final state = createDefaultState();
  (state['club'] as Map<String, dynamic>)['kitPrimaryColor'] = kit;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
        ),
      ],
      child: const MergeEmpireApp(),
    ),
  );
  // GameHost announces the load one frame in, and MaterialApp then ANIMATES
  // from the pre-load theme to the real one, so this has to outlast both.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(resetPopupQueue);

  testWidgets('boots to the shell, themed, with the HUD up', (tester) async {
    await pumpApp(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(Hud), findsOneWidget);
    final context = tester.element(find.byType(AppShell));
    expect(Theme.of(context).extension<KitTheme>(), isNotNull);
  });

  testWidgets('the theme follows the club kit', (tester) async {
    await pumpApp(tester, kit: 'humbug');
    final context = tester.element(find.byType(AppShell));
    final kit = Theme.of(context).extension<KitTheme>()!;
    expect(kit.accent, const Color(0xFFD32F2F), reason: 'humbug is red');
  });

  testWidgets('the popup host releases the no-host blocker', (tester) async {
    // Boot queues before any widget exists; the entry must still be waiting,
    // and must open once the host is up.
    var opened = false;
    enqueuePopup(
      PopupEntry(
        id: 'welcome',
        priority: PopupPriority.welcomeBack,
        show: (done) {
          opened = true;
          done();
        },
      ),
    );
    expect(opened, isFalse, reason: 'nowhere to open it yet');

    await pumpApp(tester);
    await tester.pump();
    expect(opened, isTrue);
  });
}
