/// Rewarded video at the seam. The SDK's own behaviour is NOT tested here and
/// cannot be — see the note at the head of `services/admob_ads.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/ad_app_ids.dart';
import 'package:merge_empire_fc/data/ad_units.dart';
import 'package:merge_empire_fc/services/admob_ads.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';

class _Handle implements RewardedHandle {
  _Handle({this.earns = true});

  final bool earns;
  int shows = 0;
  bool disposed = false;

  @override
  Future<bool> show() async {
    shows += 1;
    return earns;
  }

  @override
  void dispose() => disposed = true;
}

class _Loader implements RewardedAdLoader {
  _Loader({this.fill = true, this.earns = true});

  bool fill;
  bool earns;
  final List<String> asked = [];
  final List<_Handle> handed = [];

  @override
  Future<RewardedHandle?> load(String unitId) async {
    asked.add(unitId);
    if (!fill) return null;
    final handle = _Handle(earns: earns);
    handed.add(handle);
    return handle;
  }
}

AdMobRewardedAds _ads(_Loader loader, {bool permitted = true}) =>
    AdMobRewardedAds(
      loader: loader,
      platform: 'android',
      permitted: () => permitted,
    );

void main() {
  group('the manifests carry the APP ids, and a wrong one CRASHES on start', () {
    // Android does not degrade — a missing or wrong APPLICATION_ID takes the
    // app down at initialisation rather than quietly serving nothing. This is
    // the only check that keeps the two manifests honest.
    test('AND BOTH MANIFESTS SAY WHAT ad_app_ids.dart SAYS', () {
      // The SDK reads these from the native manifests, not from Dart, so
      // nothing in the suite would otherwise notice one going stale.
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains(admobAppIdAndroid),
        reason: 'AndroidManifest is missing the APPLICATION_ID',
      );
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains(admobAppIdIos),
        reason: 'Info.plist is missing GADApplicationIdentifier',
      );
    });

    test('AND THE RELEASE MANIFEST DECLARES ITS OWN PERMISSIONS', () {
      // The merger would supply all three from the plugins, which is the
      // problem: a plugin bump that drops one is invisible until a release
      // build cannot reach the network or Play refuses the upload. INTERNET was
      // in the DEBUG manifest only — the Flutter template's doing.
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      for (final permission in [
        'android.permission.INTERNET',
        'com.google.android.gms.permission.AD_ID',
        'com.android.vending.BILLING',
      ]) {
        expect(manifest, contains(permission), reason: permission);
      }
    });

    test('AND iOS CAN ATTRIBUTE AN INSTALL, which is revenue not paperwork', () {
      // Without `SKAdNetworkItems` an install cannot be attributed to the
      // network that served the ad, so AdMob's mediation partners are paid
      // nothing for it and bid accordingly. The list is AdMob's own and is
      // copied verbatim from the shipped app — a count rather than a set,
      // because curating it is not this repo's job.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        RegExp('SKAdNetworkIdentifier').allMatches(plist).length,
        greaterThanOrEqualTo(50),
        reason: 'the SKAdNetwork list has been trimmed',
      );
      // And without this key iOS refuses to show the ATT prompt at all, so the
      // consent flow has nothing to ask with.
      expect(plist, contains('NSUserTrackingUsageDescription'));
    });

    test('and they are the shipped listing\'s own', () {
      expect(admobAppIdAndroid, startsWith('ca-app-pub-'));
      expect(admobAppIdIos, startsWith('ca-app-pub-'));
      expect(admobAppIdAndroid, contains('~'), reason: 'that is a UNIT id');
      expect(admobAppIdIos, contains('~'), reason: 'that is a UNIT id');
      expect(admobAppIdAndroid, isNot(admobAppIdIos));
    });
  });

  group('showing one', () {
    test('asks for THIS placement\'s unit, not a generic one', () async {
      final loader = _Loader();
      await _ads(loader).show('double_match');
      expect(loader.asked.first, rewardedUnitFor('android', 'double_match'));
    });

    test('watched to the end is a reward; closed early is not', () async {
      expect(await _ads(_Loader()).show('energy_pip'), AdOutcome.rewarded);
      expect(
        await _ads(_Loader(earns: false)).show('energy_pip'),
        AdOutcome.dismissed,
      );
    });

    test('NO FILL IS `unavailable`, AND THAT IS A REAL ANSWER', () async {
      // A video fails to fill far more often than anyone expects, and every
      // screen above this already handles it: take the single reward, say why.
      expect(
        await _ads(_Loader(fill: false)).show('energy_pip'),
        AdOutcome.unavailable,
      );
    });

    test('and an unknown placement falls back rather than failing', () async {
      // `rewardedUnitFor` falls back to the energy unit, which is the JS's own
      // arrangement — a placement with no unit of its own still shows an ad.
      final loader = _Loader();
      await _ads(loader).show('nonesuch');
      expect(loader.asked.first, fallbackRewardedUnit('android'));
    });
  });

  group('ONE AD OBJECT IS ONE SHOWING', () {
    test('so a warmed ad is consumed, not re-shown', () async {
      // The SDK's rewarded ad is not reusable: loaded, shown once, disposed. A
      // second tap that re-showed the same object is an SDK error rather than a
      // second video.
      final loader = _Loader();
      final ads = _ads(loader);
      ads.prepare('energy_pip');
      await Future<void>.delayed(Duration.zero);
      expect(loader.asked, hasLength(1), reason: 'the prefetch did not run');

      await ads.show('energy_pip');
      expect(loader.handed.first.shows, 1);
      // And it lines up the NEXT one while the player is still on the screen.
      await Future<void>.delayed(Duration.zero);
      expect(loader.asked, hasLength(2));

      await ads.show('energy_pip');
      expect(loader.handed[0].shows, 1, reason: 'shown twice');
      expect(loader.handed[1].shows, 1);
    });

    test('and preparing twice loads once', () async {
      final loader = _Loader();
      final ads = _ads(loader)
        ..prepare('lucky_boot')
        ..prepare('lucky_boot');
      await Future<void>.delayed(Duration.zero);
      ads.prepare('lucky_boot');
      expect(loader.asked, hasLength(1));
    });
  });

  group('AND WITHOUT CONSENT NOTHING SERVES', () {
    test('the gate is checked on every show, not once at construction', () async {
      // Consent can be REVOKED from Settings mid-session, and an adapter built
      // while it was granted must not carry on serving afterwards.
      var granted = true;
      final loader = _Loader();
      final ads = AdMobRewardedAds(
        loader: loader,
        platform: 'android',
        permitted: () => granted,
      );
      expect(await ads.show('energy_pip'), AdOutcome.rewarded);
      granted = false;
      expect(await ads.show('energy_pip'), AdOutcome.unavailable);
    });

    test('and the shipping default answers unavailable, honestly', () async {
      expect(
        await const NoRewardedAds().show('energy_pip'),
        AdOutcome.unavailable,
      );
    });
  });
}
