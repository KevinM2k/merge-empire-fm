/// The adapter the app boots with, before the SDK behind it has started. The
/// SDK's own behaviour is not tested here — see `test/services/admob_ads_test.dart`.
library;

import 'dart:async';

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
}
