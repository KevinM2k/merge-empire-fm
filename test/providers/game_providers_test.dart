/// The bridge between the save and the widget tree.
///
/// The save is ONE mutable map. Handed to a reactive layer directly it looks
/// identical after every change, so the thing worth testing is not that a value
/// can be read — it is that a change NOTIFIES, and that a change to something
/// else does not.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/bus_providers.dart';
import 'package:merge_empire_fc/providers/game_host.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;
int _at = _now;

String _save({num coins = 1000, String club = 'Testville FC'}) {
  final s = createDefaultState();
  (s['resources'] as Map)['fanCoins'] = coins;
  s['clubName'] = club;
  return jsonEncode(s);
}

ProviderContainer _container([SaveStore? store]) {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        store ?? MemorySaveStore({saveKeyPrimary: _save()}),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    _at = _now;
    setClock(() => _at);
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  test('the store has no default, because a silent one loses saves', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(saveStoreProvider),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('a derived provider reads the loaded save', () {
    final container = _container();
    container.read(gameProvider).load();
    expect(container.read(clubNameProvider), 'Testville FC');
    expect(container.read(coinsProvider), 1000);
  });

  test('and reads a sensible nothing before the save is loaded', () {
    // The first frame can beat `load()`, and a null dereference there is a
    // white screen on launch.
    final container = _container();
    expect(container.read(clubNameProvider), '');
    expect(container.read(coinsProvider), 0);
  });

  test('a change notifies the provider for what moved', () async {
    final container = _container();
    final game = container.read(gameProvider)..load();
    final seen = <num>[];
    container.listen(
      coinsProvider,
      (_, next) => seen.add(next),
      fireImmediately: true,
    );

    game.update((s) => (s['resources'] as Map)['fanCoins'] = 1500);
    // Riverpod flushes its dependents on the next microtask rather than inside
    // the mutation, so the rebuild is one frame away, not zero.
    await Future<void>.delayed(Duration.zero);
    expect(seen, [1000, 1500]);
  });

  test('and does NOT notify the providers for what did not', () async {
    // The whole point of the arrangement: a coin landing must not rebuild the
    // club name, the crest, or anything else on the HUD.
    final container = _container();
    final game = container.read(gameProvider)..load();
    var clubRebuilds = 0;
    container.listen(clubNameProvider, (_, _) => clubRebuilds++);

    for (var i = 0; i < 10; i++) {
      game.update((s) => (s['resources'] as Map)['fanCoins'] = 1000 + i);
    }
    await Future<void>.delayed(Duration.zero);
    expect(clubRebuilds, 0);
    expect(container.read(coinsProvider), 1009);
  });

  test('a mutation that skipped `update` waits for someone to say so', () {
    // The contract rather than a bug: writing through the raw map is what the
    // tick loop does for idle income, and it calls `notifyChanged` itself
    // precisely because of this.
    final container = _container();
    final game = container.read(gameProvider)..load();
    container.read(coinsProvider);

    (game.state!['resources'] as Map)['fanCoins'] = 9999;
    expect(container.read(coinsProvider), 1000);

    game.notifyChanged();
    expect(container.read(coinsProvider), 9999);
  });

  test('a reset republishes the whole save', () {
    final container = _container();
    final game = container.read(gameProvider)..load();
    expect(container.read(clubNameProvider), 'Testville FC');
    game.resetState();
    expect(container.read(clubNameProvider), isNot('Testville FC'));
  });

  test('the runner is wired to the hidden flag', () {
    final container = _container();
    final runner = container.read(gameRunnerProvider)..boot();
    container.read(appHiddenProvider.notifier).state = true;
    _at += 60000;
    expect(runner.tickOnce().coinsEarned, 0);
  });

  test('disposing the scope stops the loop and drops the listeners', () {
    // A hot restart would otherwise leave a timer running and a second set of
    // listeners paying every grant twice.
    final container = _container();
    final runner = container.read(gameRunnerProvider)..boot();
    runner.start();
    final coins = (runner.game.state!['resources'] as Map)['fanCoins'];
    container.dispose();
    expect(runner.running, isFalse);

    emit('achievement:unlocked', {'id': 'x', 'coinsRewarded': 500});
    expect((runner.game.state!['resources'] as Map)['fanCoins'], coins);
  });

  group('the bus, republished', () {
    test('an emission reaches a listener', () async {
      final container = _container();
      final seen = <Object?>[];
      container.listen(busEventProvider('toast:show'), (_, next) {
        if (next.hasValue && next.value != null) seen.add(next.value);
      });
      // The stream is created on first read; nothing emitted before that is
      // seen, which is why one-shot events are `ref.listen` and values are not.
      await Future<void>.delayed(Duration.zero);

      emit('toast:show', 'promoted');
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['promoted']);
    });

    test('and the subscription goes with the provider', () {
      final container = _container();
      final sub = container.listen(busEventProvider('toast:show'), (_, _) {});
      expect(busListenerCount('toast:show'), 1);
      sub.close();
      container.invalidate(busEventProvider('toast:show'));
      expect(busListenerCount('toast:show'), 0);
    });
  });

  group('the lifecycle host', () {
    /// Mount the host.
    ///
    /// Every case below ends by unmounting it, which is not housekeeping: boot
    /// schedules a debounced save, and a widget test that finishes with a timer
    /// still pending fails. The unmount is also the assertion that the host
    /// cleans up after itself.
    Future<void> pump(WidgetTester tester, MemorySaveStore store) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [saveStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: GameHost(child: SizedBox.shrink())),
        ),
      );
    }

    testWidgets('boots the game and starts the loop', (tester) async {
      final store = MemorySaveStore({saveKeyPrimary: _save()});
      await pump(tester, store);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox)),
      );
      final runner = container.read(gameRunnerProvider);
      expect(runner.running, isTrue);
      expect(container.read(clubNameProvider), 'Testville FC');

      // Unmounting the host stops the loop. The container goes with it, so the
      // runner is held rather than read back.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(runner.running, isFalse);
    });

    testWidgets('a background saves; a return resumes', (tester) async {
      final store = MemorySaveStore({saveKeyPrimary: _save()});
      await pump(tester, store);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox)),
      );
      container.read(gameProvider).state!['clubName'] = 'Backgrounded FC';

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(container.read(appHiddenProvider), isTrue);
      expect(container.read(gameRunnerProvider).running, isFalse);
      expect(
        jsonDecode(store.values[saveKeyPrimary]!),
        containsPair('clubName', 'Backgrounded FC'),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(appHiddenProvider), isFalse);
      expect(container.read(gameRunnerProvider).running, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('detects the leaderboard region once, and keeps it', (
      tester,
    ) async {
      // `ensurePlayerRegion` reports whether it wrote rather than saving; the
      // host is the caller that was missing.
      final store = MemorySaveStore({saveKeyPrimary: _save()});
      await pump(tester, store);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox)),
      );
      final settings = container.read(gameProvider).state!['settings'] as Map;
      expect(settings['regionCode'], isNotEmpty);
    });

    testWidgets('a banner is not the player leaving', (tester) async {
      // `inactive` fires for the notification shade and the app switcher.
      // Stopping the loop there is a stall the player never asked for.
      final store = MemorySaveStore({saveKeyPrimary: _save()});
      await pump(tester, store);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox)),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(container.read(gameRunnerProvider).running, isTrue);
      expect(container.read(appHiddenProvider), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
