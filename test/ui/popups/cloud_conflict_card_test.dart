/// The save-conflict chooser.
///
/// Sixteen `cloud.*` and `cloudsave.*` strings shipped in ten languages with no
/// caller, because `evaluateCloudSave` answers `choose` and stops — the engine
/// may not draw, so the decision had nowhere to go and the whole cloud
/// subsystem was unreachable.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/cloud_save_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/cloud_conflict_card.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

const SaveSummary cloudSave = (
  clubName: 'Cloud City',
  divisionId: 'regional',
  matchesPlayed: 55,
  seasonCount: 3,
  lastSeen: 5000,
);

const SaveSummary localSave = (
  clubName: 'Local Town',
  divisionId: 'sunday',
  matchesPlayed: 40,
  seasonCount: 2,
  lastSeen: 4000,
);

Future<Future<CloudSaveAction>> pumpCard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(460, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late Future<CloudSaveAction> answer;
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: Builder(
            builder: (inner) => TextButton(
              onPressed: () =>
                  answer = showCloudConflictCard(inner, cloudSave, localSave),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  testWidgets('IT SHOWS WHAT EACH SAVE IS, not just where it came from', (
    tester,
  ) async {
    // A player cannot answer "which one" from the words Cloud and Device.
    await pumpCard(tester);
    expect(find.text('Cloud City'), findsOneWidget);
    expect(find.text('Local Town'), findsOneWidget);
    expect(
      find.text(
        '${t('cloud.conflict.season', {'n': 3})} · '
        '${t('cloud.conflict.matches', {'n': 55})}',
      ),
      findsOneWidget,
    );
    expect(find.text(t('cloud.conflict.cloud_badge')), findsOneWidget);
    expect(find.text(t('cloud.conflict.device_badge')), findsOneWidget);
  });

  testWidgets('Use Cloud answers restore', (tester) async {
    final answer = await pumpCard(tester);
    await tester.tap(find.text(t('cloud.conflict.restore')));
    await tester.pumpAndSettle();
    expect(await answer, CloudSaveAction.restore);
  });

  testWidgets('Keep Device answers upload', (tester) async {
    final answer = await pumpCard(tester);
    await tester.tap(find.text(t('cloud.conflict.overwrite')));
    await tester.pumpAndSettle();
    expect(await answer, CloudSaveAction.upload);
  });

  testWidgets('THE BARRIER DOES NOT DISMISS IT', (tester) async {
    // There must be no path out of this card that silently replaces the save in
    // front of the player.
    await pumpCard(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cloud-conflict-card')), findsOneWidget);
  });

  group('how long ago', () {
    test('is the JS\'s own four bands', () {
      const nowMs = 1800000000000;
      expect(cloudRelativeTime(0), '');
      expect(cloudRelativeTime(nowMs - 30000, nowMs: nowMs),
          t('cloudsave.just_now'));
      expect(
        cloudRelativeTime(nowMs - 5 * 60000, nowMs: nowMs),
        t('cloudsave.minutes_ago', {'n': 5}),
      );
      expect(
        cloudRelativeTime(nowMs - 3 * 3600000, nowMs: nowMs),
        t('cloudsave.hours_ago', {'n': 3}),
      );
      expect(
        cloudRelativeTime(nowMs - 2 * 86400000, nowMs: nowMs),
        t('cloudsave.days_ago', {'n': 2}),
      );
    });
  });
}
