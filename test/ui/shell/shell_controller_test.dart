/// Navigation intent, and the bus adapting onto it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

void main() {
  tearDown(() {
    detachShellBusListeners();
    clearBus();
  });

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('opens on the Play tab', () {
    expect(container().read(shellControllerProvider).tab, ShellTab.home);
  });

  test('goTab moves the tab and asks for a slide', () {
    final c = container();
    c.read(shellControllerProvider.notifier).goTab(ShellTab.shop);
    expect(c.read(shellControllerProvider).tab, ShellTab.shop);
    expect(c.read(shellControllerProvider).noSlide, isFalse);
  });

  test('a shop deep link arrives with no slide and a section to scroll to', () {
    final c = container();
    c.read(shellControllerProvider.notifier).deepLinkShop(ShopSection.gems);
    final s = c.read(shellControllerProvider);
    expect(s.tab, ShellTab.shop);
    expect(s.noSlide, isTrue);
    expect(s.pendingShopSection, ShopSection.gems);
  });

  test(
    'the pending section is consumed once, so a rebuild does not re-scroll',
    () {
      final c = container();
      c.read(shellControllerProvider.notifier).deepLinkShop(ShopSection.coins);
      c.read(shellControllerProvider.notifier).consumePendingShopSection();
      expect(c.read(shellControllerProvider).pendingShopSection, isNull);
      expect(
        c.read(shellControllerProvider).tab,
        ShellTab.shop,
        reason: 'still there',
      );
    },
  );

  test('an ordinary tab move clears a stale pending section', () {
    final c = container();
    c.read(shellControllerProvider.notifier).deepLinkShop(ShopSection.coins);
    c.read(shellControllerProvider.notifier).goTab(ShellTab.grid);
    expect(c.read(shellControllerProvider).pendingShopSection, isNull);
    expect(c.read(shellControllerProvider).noSlide, isFalse);
  });

  test('the sheet heights are the ones the JS ships', () {
    expect(ShellSheet.trophies.heightFraction, 0.75);
    expect(ShellSheet.playerIndex.heightFraction, 0.92);
    expect(ShellSheet.leaderboard.heightFraction, 0.92);
  });

  group('the bus adapts onto the controller', () {
    test('nav:tab-squad switches tab', () {
      final c = container();
      attachShellBusListeners(c.read(shellControllerProvider.notifier));
      emit('nav:tab-squad');
      expect(c.read(shellControllerProvider).tab, ShellTab.squad);
    });

    test('nav:shop-gems deep-links', () {
      final c = container();
      attachShellBusListeners(c.read(shellControllerProvider.notifier));
      emit('nav:shop-gems');
      final s = c.read(shellControllerProvider);
      expect(s.tab, ShellTab.shop);
      expect(s.noSlide, isTrue);
      expect(s.pendingShopSection, ShopSection.gems);
    });

    test('nav:shop-coins deep-links', () {
      final c = container();
      attachShellBusListeners(c.read(shellControllerProvider.notifier));
      emit('nav:shop-coins');
      expect(
        c.read(shellControllerProvider).pendingShopSection,
        ShopSection.coins,
      );
    });

    test('attaching twice does not double-handle', () {
      final c = container();
      final notifier = c.read(shellControllerProvider.notifier);
      attachShellBusListeners(notifier);
      attachShellBusListeners(notifier);
      expect(busListenerCount('nav:tab-squad'), 1);
    });

    test('detaching stops the listeners', () {
      final c = container();
      attachShellBusListeners(c.read(shellControllerProvider.notifier));
      detachShellBusListeners();
      emit('nav:tab-squad');
      expect(c.read(shellControllerProvider).tab, ShellTab.home);
      expect(busListenerCount('nav:tab-squad'), 0);
    });
  });
}
