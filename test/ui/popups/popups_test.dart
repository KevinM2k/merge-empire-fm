/// The three popup shapes, and the host the queue opens them into.
///
/// Three, and only three. A fourth is a change to the spec, not a new file.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/util/time.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

late BuildContext hostContext;

Future<void> pumpHost(WidgetTester tester) async {
  // Today's reward already claimed, so the HOST's own boot popups stay out of
  // the way of the tests about the shapes themselves.
  final state = createDefaultState();
  // The branch is created lazily by the engine, so it may not be in a fresh
  // save at all.
  state['dailyReward'] = <String, dynamic>{
    'cycleDay': 1,
    'lastClaimDayKey': dateString(),
    'streak': 1,
    'longestStreak': 1,
    'totalClaims': 1,
    'lastAutoPopupDayKey': dateString(),
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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: PopupHost(
          child: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A queue entry that opens a Coach card and closes the entry when it is
/// dismissed — the shape every real caller uses.
PopupEntry cardEntry(String id, int priority, {VoidCallback? onClose}) {
  return PopupEntry(
    id: id,
    priority: priority,
    show: (done) {
      showCoachCard<void>(
        hostContext,
        titleKey: 'nav.squad',
        bodyKey: 'nav.club',
        actions: [CoachAction(labelKey: 'common.close', onTap: () {})],
      ).then((_) {
        onClose?.call();
        done();
      });
    },
  );
}

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  group('the coach card', () {
    testWidgets('shows its title, body and actions, all translated', (
      tester,
    ) async {
      await pumpHost(tester);
      unawaitedShow(
        showCoachCard<void>(
          hostContext,
          titleKey: 'nav.squad',
          bodyKey: 'nav.club',
          actions: [CoachAction(labelKey: 'common.close', onTap: () {})],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t('nav.squad')), findsOneWidget);
      expect(find.text(t('nav.club')), findsOneWidget);
      expect(find.text(t('common.close')), findsOneWidget);
    });

    testWidgets('an action closes the card and then runs', (tester) async {
      await pumpHost(tester);
      var ran = 0;
      unawaitedShow(
        showCoachCard<void>(
          hostContext,
          titleKey: 'nav.squad',
          bodyKey: 'nav.club',
          actions: [CoachAction(labelKey: 'common.close', onTap: () => ran++)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('common.close')));
      await tester.pumpAndSettle();
      expect(ran, 1);
      expect(find.byKey(const ValueKey('coach-card')), findsNothing);
    });
  });

  group('the bottom sheet', () {
    testWidgets('rises with its content and closes on back', (tester) async {
      await pumpHost(tester);
      unawaitedShow(
        showBottomSheetPopup<void>(
          hostContext,
          child: const Text('sheet body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsNothing);
    });
  });

  group('the quick-nav menu', () {
    testWidgets('groups its shortcuts and runs the one tapped', (tester) async {
      await pumpHost(tester);
      var went = 0;
      unawaitedShow(
        showQuickNavMenu(
          hostContext,
          groups: [
            QuickNavGroup(
              titleKey: 'quicknav.group.league',
              items: [
                QuickNavItem(
                  labelKey: 'nav.squad',
                  icon: Icons.groups,
                  onTap: () => went++,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      // The phone's app has a name of its own now; see `dugoutAppName`.
      expect(find.text(dugoutAppName), findsOneWidget);
      expect(
        find.text(t('quicknav.group.league').toUpperCase()),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('quick-nav-nav.squad')));
      await tester.pumpAndSettle();
      expect(went, 1);
    });
  });

  group('the host drains the queue', () {
    testWidgets('opens a popup queued before it mounted', (tester) async {
      // Boot queues the welcome-back card before any widget exists; it must
      // open as soon as there is somewhere to put it.
      enqueuePopup(cardEntry('boot', PopupPriority.welcomeBack));
      await pumpHost(tester);
      expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);
    });

    testWidgets('a second popup waits for the first to close', (tester) async {
      await pumpHost(tester);
      enqueuePopup(cardEntry('first', PopupPriority.welcomeBack));
      enqueuePopup(cardEntry('second', PopupPriority.dailyReward));
      await tester.pumpAndSettle();
      expect(activePopupId(), 'first');
      expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);

      await tester.tap(find.text(t('common.close')));
      await tester.pumpAndSettle();
      expect(activePopupId(), 'second');
      expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);
    });

    testWidgets('a blocker keeps a popup off the screen until released', (
      tester,
    ) async {
      await pumpHost(tester);
      blockPopups('match');
      enqueuePopup(cardEntry('held', PopupPriority.welcomeBack));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('coach-card')), findsNothing);
      expect(hasPopupWork(), isTrue, reason: 'it waits, it does not expire');

      unblockPopups('match');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);
    });
  });
}

/// The dialog futures are fire-and-forget here; the test drives them by tapping.
void unawaitedShow(Future<void> future) {
  future.ignore();
}
