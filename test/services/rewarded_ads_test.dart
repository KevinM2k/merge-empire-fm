/// The adapter the app boots with, before the SDK behind it has started. The
/// SDK's own behaviour is not tested here — see `test/services/admob_ads_test.dart`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';

class _Recording implements RewardedAds {
  final List<String> shown = [];
  final List<String> prepared = [];

  @override
  Future<AdOutcome> show(String placement) async {
    shown.add(placement);
    return AdOutcome.rewarded;
  }

  @override
  void prepare(String placement) => prepared.add(placement);

  @override
  void refresh() => refreshed += 1;

  int refreshed = 0;
}

/// One whose video the test decides the length of.
class _Held implements RewardedAds {
  final Completer<AdOutcome> gate = Completer<AdOutcome>();
  final List<String> shown = [];

  @override
  Future<AdOutcome> show(String placement) {
    shown.add(placement);
    return gate.future;
  }

  @override
  void prepare(String placement) {}

  @override
  void refresh() {}
}

/// And one that falls over, which is what the `finally` is for.
class _Throwing implements RewardedAds {
  @override
  Future<AdOutcome> show(String placement) async => throw StateError('no');

  @override
  void prepare(String placement) {}

  @override
  void refresh() {}
}

/// A real `WidgetRef`, which is what `watchRewardedAd` takes and what a
/// `ProviderContainer` cannot hand out.
Future<WidgetRef> _pumpRef(WidgetTester tester, RewardedAds ads) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [rewardedAdsProvider.overrideWithValue(ads)],
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group('THE APP BOOTS WITHOUT THE AD SDK', () {
    test('a show that lands before the SDK is up waits for it', () async {
      final ready = Completer<RewardedAds>();
      final live = _Recording();
      final ads = PendingRewardedAds(ready.future);

      final pending = ads.show('energy_pip');
      ready.complete(live);

      expect(await pending, AdOutcome.rewarded);
      expect(live.shown, ['energy_pip']);
    });

    test('and a prepare is replayed onto it', () async {
      final live = _Recording();
      final ads = PendingRewardedAds(Future.value(live));

      ads.prepare('double_or_nothing');
      await Future<void>.delayed(Duration.zero);

      expect(live.prepared, ['double_or_nothing']);
    });

    test('a consent form nobody answers is unavailable, not a hang', () async {
      // The form's future does not complete until it is dismissed. A player
      // who leaves it up must still get an honest answer from the button.
      final ads = PendingRewardedAds(
        Completer<RewardedAds>().future,
        settle: const Duration(milliseconds: 10),
      );

      expect(await ads.show('energy_pip'), AdOutcome.unavailable);
    });

    test('and the next tap asks again rather than staying unavailable', () async {
      final ready = Completer<RewardedAds>();
      final live = _Recording();
      final ads = PendingRewardedAds(
        ready.future,
        settle: const Duration(milliseconds: 10),
      );

      expect(await ads.show('energy_pip'), AdOutcome.unavailable);
      ready.complete(live);

      expect(await ads.show('energy_pip'), AdOutcome.rewarded);
      expect(live.shown, ['energy_pip']);
    });
  });

  group('ONE VIDEO AT A TIME, ANYWHERE IN THE APP', () {
    // Three of the six offers had a busy field of their own and three had
    // nothing, so the shop's free shelf and the energy sheet could both be
    // double-tapped into two videos against one reward.
    testWidgets('the flag goes up on the ask and down on the answer', (
      tester,
    ) async {
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      expect(ref.read(adBusyProvider), isNull);

      final watching = watchRewardedAd(ref, 'energy_pip');
      expect(ref.read(adBusyProvider)?.placement, 'energy_pip');

      ads.gate.complete(AdOutcome.rewarded);
      expect(await watching, AdOutcome.rewarded);
      expect(ref.read(adBusyProvider), isNull);
    });

    testWidgets('A SECOND TAP NEVER REACHES THE SDK', (tester) async {
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);

      final first = watchRewardedAd(ref, 'energy_pip');
      // A different offer, which is the case a per-screen flag never caught.
      expect(await watchRewardedAd(ref, 'lucky_boot'), AdOutcome.dismissed);
      expect(ads.shown, ['energy_pip'], reason: 'two videos, one reward');

      ads.gate.complete(AdOutcome.rewarded);
      await first;
    });

    testWidgets('AND A THROW STILL PUTS THE FLAG DOWN', (tester) async {
      // A stuck flag is every offer in the app dead for the session, which is
      // a worse failure than the one that caused it.
      final ref = await _pumpRef(tester, _Throwing());
      await expectLater(
        watchRewardedAd(ref, 'energy_pip'),
        throwsStateError,
      );
      expect(ref.read(adBusyProvider), isNull);
    });

    testWidgets('a warm ad never asks for a spinner', (tester) async {
      // It opens on the tap. A spinner shown unconditionally is a one-frame
      // flicker on every offer in the game.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');
      expect(ref.read(adBusyProvider)?.slow, isFalse);

      ads.gate.complete(AdOutcome.rewarded);
      await watching;
      await tester.pump(adSpinnerDelay * 2);
      expect(ref.read(adBusyProvider), isNull, reason: 'a late spinner fired');
    });

    testWidgets('and one that is really loading does ask, after the delay', (
      tester,
    ) async {
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');

      await tester.pump(adSpinnerDelay - const Duration(milliseconds: 20));
      expect(ref.read(adBusyProvider)?.slow, isFalse);
      await tester.pump(const Duration(milliseconds: 40));
      expect(ref.read(adBusyProvider)?.slow, isTrue);

      ads.gate.complete(AdOutcome.dismissed);
      await watching;
      expect(ref.read(adBusyProvider), isNull);
    });
  });
}
