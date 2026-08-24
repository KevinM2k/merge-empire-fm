/// The parent-or-guardian notice.
///
/// Ten `agegate.*` strings ship in ten languages and none of them had a caller
/// — the sheet had been recorded as blocked on new copy that was already in the
/// catalogue. What is checked here is that the notice says which age Play
/// reported, that Allow records consent, and that the other button leaves the
/// game exactly as playable as it was.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/age_verification.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/age_gate_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

import 'dart:convert';

/// Opens the sheet and hands back the container behind it, plus the future the
/// caller would be awaiting.
Future<(ProviderContainer, Future<bool>)> pumpGate(
  WidgetTester tester, {
  required String status,
  bool consented = false,
}) async {
  final state = createDefaultState()
    ..['ageVerification'] = <String, dynamic>{
      'status': status,
      'parentalConsentGiven': consented,
    };
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  tester.view.physicalSize = const Size(460, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late Future<bool> answer;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: Builder(
            builder: (inner) => TextButton(
              onPressed: () => answer = showAgeGateSheet(inner),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (container, answer);
}

void main() {
  testWidgets('IT NAMES THE AGE PLAY REPORTED', (tester) async {
    // A parent reading it should be told what Play actually said, and the two
    // sentences are different: under 13 is a child, under 18 is a teen.
    await pumpGate(tester, status: 'child');
    expect(
      find.text(t('agegate.intro', {'age': t('agegate.under_13')})),
      findsOneWidget,
    );
  });

  testWidgets('a teen gets the other sentence', (tester) async {
    await pumpGate(tester, status: 'teen');
    expect(
      find.text(t('agegate.intro', {'age': t('agegate.under_18')})),
      findsOneWidget,
    );
  });

  testWidgets('it says what is collected and what can be bought', (
    tester,
  ) async {
    await pumpGate(tester, status: 'child');
    for (final key in [
      'agegate.collect_heading',
      'agegate.collect_progress',
      'agegate.collect_analytics',
      'agegate.collect_ads',
      'agegate.purchases_heading',
      'agegate.safe_note',
    ]) {
      expect(find.text(t(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('ALLOW RECORDS CONSENT AND UNLOCKS BUYING', (tester) async {
    final (container, answer) = await pumpGate(tester, status: 'child');
    expect(isIapAllowed(container.read(gameProvider).state!), isFalse);

    await tester.tap(find.byKey(const ValueKey('age-gate-allow')));
    await tester.pumpAndSettle();
    // The grant arms the debounced save; let it land or the binding rightly
    // complains about a timer outliving the tree.
    await tester.pump(const Duration(seconds: 3));

    expect(await answer, isTrue);
    final save = container.read(gameProvider).state!;
    expect(isIapAllowed(save), isTrue);
    // **The status is not touched.** They are still a minor; the consent is a
    // separate fact about them, and ad targeting reads the status.
    expect(isConfirmedMinor(save), isTrue);
  });

  testWidgets('PLAY WITHOUT PURCHASES BLOCKS NOTHING BUT BUYING', (
    tester,
  ) async {
    // The JS's own first line: gameplay is never blocked by this sheet.
    final (container, answer) = await pumpGate(tester, status: 'child');
    await tester.tap(find.byKey(const ValueKey('age-gate-dismiss')));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
    expect(isIapAllowed(container.read(gameProvider).state!), isFalse);
    expect(find.byKey(const ValueKey('age-gate-sheet')), findsNothing);
  });
}
