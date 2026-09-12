/// The adapter the app boots with, before the SDK behind it has started, and
/// the one gate every offer in the game goes through. The SDK's own behaviour
/// is not tested here — see `test/services/admob_ads_test.dart`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

class _Recording implements RewardedAds {
  final List<String> shown = [];

  @override
  Future<AdOutcome> show(String placement, {void Function()? onShown}) async {
    shown.add(placement);
    onShown?.call();
    return AdOutcome.rewarded;
  }
}

/// One whose video the test decides the length of, and the moment it goes up.
class _Held implements RewardedAds {
  final Completer<AdOutcome> gate = Completer<AdOutcome>();
  final List<String> shown = [];
  void Function()? _announce;

  /// Put the video on screen — what the SDK's own presented callback does.
  void present() => _announce?.call();

  @override
  Future<AdOutcome> show(String placement, {void Function()? onShown}) {
    shown.add(placement);
    _announce = onShown;
    return gate.future;
  }
}

/// And one that falls over, which is what the `finally` is for.
class _Throwing implements RewardedAds {
  @override
  Future<AdOutcome> show(String placement, {void Function()? onShown}) async =>
      throw StateError('no');
}

/// One that never fills, which is the answer the toast is for.
class _Empty implements RewardedAds {
  @override
  Future<AdOutcome> show(String placement, {void Function()? onShown}) async =>
      AdOutcome.unavailable;
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

    test('and the presented signal is carried across the seam', () async {
      // The adapter in front must not swallow it: the button's spinner comes
      // off on this and nothing else.
      final ads = PendingRewardedAds(Future.value(_Recording()));
      var announced = false;
      await ads.show('energy_pip', onShown: () => announced = true);
      expect(announced, isTrue);
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

    testWidgets('AND IT IS STILL SHUT WHILE THE VIDEO IS PLAYING', (
      tester,
    ) async {
      // The button behind the ad stops spinning, which is not the same thing as
      // the app being open for a second ask.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final first = watchRewardedAd(ref, 'energy_pip');
      ads.present();
      await tester.pump();

      expect(await watchRewardedAd(ref, 'lucky_boot'), AdOutcome.dismissed);
      expect(ads.shown, ['energy_pip']);
      ads.gate.complete(AdOutcome.rewarded);
      await first;
    });

    testWidgets('AND A THROW STILL PUTS THE FLAG DOWN', (tester) async {
      // A stuck flag is every offer in the app dead for the session, which is
      // a worse failure than the one that caused it.
      final ref = await _pumpRef(tester, _Throwing());
      await expectLater(watchRewardedAd(ref, 'energy_pip'), throwsStateError);
      expect(ref.read(adBusyProvider), isNull);
    });
  });

  group('THE BUTTON THAT WAS TAPPED SAYS SO', () {
    testWidgets('it is loading from the tap, with no delay at all', (
      tester,
    ) async {
      // **NOTHING IS PRELOADED**, so a tap with no answer yet is the normal
      // case rather than the exception, and a control that waits 150ms to admit
      // it has been pressed reads as a button that missed the press.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');

      expect(ref.read(adLoadingProvider('energy_pip')), isTrue);
      ads.gate.complete(AdOutcome.dismissed);
      await watching;
      expect(ref.read(adLoadingProvider('energy_pip')), isFalse);
    });

    testWidgets('AND ONLY THAT ONE — the others are shut, not spinning', (
      tester,
    ) async {
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');

      expect(ref.read(adLoadingProvider('lucky_boot')), isFalse);
      ads.gate.complete(AdOutcome.rewarded);
      await watching;
    });

    testWidgets('IT STOPS WHEN THE VIDEO GOES UP, not when it ends', (
      tester,
    ) async {
      // A spinner held to the dismissal is still turning under a video that is
      // already playing, and the player comes back to a control that looks like
      // it is waiting on the thing they just watched.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');
      expect(ref.read(adLoadingProvider('energy_pip')), isTrue);

      ads.present();
      expect(ref.read(adLoadingProvider('energy_pip')), isFalse);
      expect(
        ref.read(adBusyProvider)?.showing,
        isTrue,
        reason: 'the video is up and the flag does not say so',
      );

      ads.gate.complete(AdOutcome.rewarded);
      await watching;
    });

    testWidgets('and the caller is told at the same moment', (tester) async {
      // The energy sheet comes down when the video goes up rather than on the
      // tap, so the button the player pressed is still there to spin.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      var announced = false;
      final watching = watchRewardedAd(
        ref,
        'energy_pip',
        onShown: () => announced = true,
      );

      expect(announced, isFalse);
      ads.present();
      expect(announced, isTrue);

      ads.gate.complete(AdOutcome.rewarded);
      await watching;
    });

    testWidgets('a failure never says the video went up', (tester) async {
      final ref = await _pumpRef(tester, _Empty());
      var announced = false;
      await watchRewardedAd(ref, 'energy_pip', onShown: () => announced = true);
      expect(announced, isFalse);
    });

    testWidgets('the scrim waits, and comes down when the video is up', (
      tester,
    ) async {
      // The heavier cue is the delayed one: an ask that answers in a frame or
      // two would otherwise flash a full-screen scrim on every offer.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');

      await tester.pump(adSpinnerDelay - const Duration(milliseconds: 20));
      expect(ref.read(adBusyProvider)?.slow, isFalse);
      await tester.pump(const Duration(milliseconds: 40));
      expect(ref.read(adBusyProvider)?.slow, isTrue);

      ads.present();
      expect(ref.read(adBusyProvider)?.slow, isFalse);
      ads.gate.complete(AdOutcome.dismissed);
      await watching;
      expect(ref.read(adBusyProvider), isNull);
    });

    testWidgets('and a late spinner cannot fire after the answer', (
      tester,
    ) async {
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');
      ads.gate.complete(AdOutcome.rewarded);
      await watching;

      await tester.pump(adSpinnerDelay * 2);
      expect(ref.read(adBusyProvider), isNull, reason: 'a late spinner fired');
    });
  });

  group('AND A FAILURE IS SAID OUT LOUD', () {
    late List<String> lines;
    late BusHandler listener;

    setUp(() {
      lines = [];
      listener = (args) => lines.add('$args');
      on('toast:error', listener);
    });

    tearDown(() => off('toast:error', listener));

    testWidgets('every offer gets the line, because it is raised HERE', (
      tester,
    ) async {
      // Six of the eight raised their own and two raised nothing, across three
      // different keys saying the same sentence — so an offer that failed told
      // the player so only if whoever wrote that screen had remembered.
      final ref = await _pumpRef(tester, _Empty());
      for (final placement in ['energy_pip', 'lucky_boot', 'daily_double']) {
        expect(await watchRewardedAd(ref, placement), AdOutcome.unavailable);
      }
      expect(lines, hasLength(3));
      expect(lines.first, isNotEmpty);
    });

    testWidgets('a video the player closed early says nothing', (tester) async {
      // Backing out is a choice, not a fault.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final watching = watchRewardedAd(ref, 'energy_pip');
      ads.gate.complete(AdOutcome.dismissed);
      await watching;
      expect(lines, isEmpty);
    });

    testWidgets('AND NEITHER DOES A DOUBLE TAP', (tester) async {
      // A tap that never asked for an ad is not an ad that failed.
      final ads = _Held();
      final ref = await _pumpRef(tester, ads);
      final first = watchRewardedAd(ref, 'energy_pip');
      expect(await watchRewardedAd(ref, 'energy_pip'), AdOutcome.dismissed);
      expect(lines, isEmpty);

      ads.gate.complete(AdOutcome.rewarded);
      await first;
    });
  });
}
