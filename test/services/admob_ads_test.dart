/// Rewarded video at the seam. The SDK's own behaviour is NOT tested here and
/// cannot be — see the note at the head of `services/admob_ads.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/ad_app_ids.dart';
import 'package:merge_empire_fc/data/ad_units.dart';
import 'package:merge_empire_fc/services/admob_ads.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/util/analytics.dart';

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

AdMobRewardedAds _ads(
  _Loader loader, {
  bool permitted = true,
  DateTime Function()? clock,
}) => AdMobRewardedAds(
  loader: loader,
  platform: 'android',
  permitted: () => permitted,
  clock: clock,
);

/// A clock the test winds on by hand. Staleness is an age, so it needs one.
class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1, 12);

  DateTime call() => now;
  void advance(Duration by) => now = now.add(by);
}

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

    test('AND iOS ASKS FOR TRACKING, rather than only declaring that it will', () {
      // **The failure this pins was a declared key with no caller.** Fifty
      // SKAdNetwork ids and `NSUserTrackingUsageDescription` shipped in
      // Info.plist and nothing ever called the ATT API, so the prompt never
      // appeared, the IDFA was never available and every iOS impression was
      // contextual. Apple requires the key; only a caller makes it do anything,
      // and `google_mobile_ads` has no ATT API of its own — UMP answers a
      // different question. The reachability check CLAUDE.md asks for, in the
      // one form a cloud container can make it.
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains('NSUserTrackingUsageDescription'),
        reason: 'iOS refuses to show the prompt without the key',
      );
      expect(
        File('lib/services/admob_ads.dart').readAsStringSync(),
        contains('requestTrackingIfNeeded()'),
        reason: 'the prompt is never asked for, so the key is decoration',
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
    test('ASKS FOR THE GLOBAL UNIT, whatever the placement is', () async {
      // The per-placement ids are still on record and are no longer requested
      // against — one unit is what makes a single warm ad able to answer
      // whichever offer is tapped first.
      for (final placement in ['double_match', 'lucky_boot', 'nonesuch']) {
        final loader = _Loader();
        await _ads(loader).show(placement);
        expect(loader.asked.first, globalRewardedUnitAndroid, reason: placement);
      }
    });

    test('watched to the end is a reward; closed early is not', () async {
      expect(await _ads(_Loader()).show('energy_pip'), AdOutcome.rewarded);
      expect(
        await _ads(_Loader(earns: false)).show('energy_pip'),
        AdOutcome.dismissed,
      );
    });

    test('AND A NO-FILL DOES NOT IMMEDIATELY ASK AGAIN', () async {
      // The load that just failed is the evidence there is no inventory.
      // Lining another one up on the spot spends a second request, with
      // `adLoadTimeout` behind it, to be told the same thing.
      final loader = _Loader(fill: false);
      await _ads(loader).show('energy_pip');
      await Future<void>.delayed(Duration.zero);
      expect(loader.asked, hasLength(1));
    });

    test('but a WATCHED one lines the next up before it returns', () async {
      final loader = _Loader();
      await _ads(loader).show('energy_pip');
      expect(loader.asked, hasLength(2));
    });

    test('NO FILL IS `unavailable`, AND THAT IS A REAL ANSWER', () async {
      // A video fails to fill far more often than anyone expects, and every
      // screen above this already handles it: take the single reward, say why.
      expect(
        await _ads(_Loader(fill: false)).show('energy_pip'),
        AdOutcome.unavailable,
      );
    });

  });

  group('ONE WARM AD FOR THE WHOLE APP', () {
    test('the ad warmed HERE is the ad shown THERE', () async {
      // The point of the global unit. Eleven slots meant the warm one was
      // almost never the one that got tapped and the player waited anyway.
      final loader = _Loader();
      final ads = _ads(loader)..prepare('skip_cooldown');
      await Future<void>.delayed(Duration.zero);
      expect(loader.asked, hasLength(1));

      expect(await ads.show('lucky_boot'), AdOutcome.rewarded);
      expect(loader.handed.first.shows, 1, reason: 'the warm ad went unused');
      // Two loads: the prefetch, and the next one lined up after the show. The
      // show itself did not have to load.
      expect(loader.asked, hasLength(2));
    });

    test('and warming twice over two placements still loads once', () async {
      final loader = _Loader();
      final ads = _ads(loader)
        ..prepare('energy_pip')
        ..prepare('daily_double');
      await Future<void>.delayed(Duration.zero);
      ads.prepare('lucky_boot');
      expect(loader.asked, hasLength(1));
    });

    test('A SECOND SHOW MID-VIDEO IS A NO-OP, not a second ad', () async {
      // The UI holds a flag of its own; the adapter must not depend on every
      // caller having behaved. One ad object is one showing.
      final loader = _Loader();
      final ads = _ads(loader);
      final first = ads.show('energy_pip');
      final second = ads.show('lucky_boot');
      expect(await second, AdOutcome.dismissed);
      expect(await first, AdOutcome.rewarded);
      expect(loader.handed.where((h) => h.shows > 0), hasLength(1));
    });
  });

  group('AND A WARM AD GOES OFF', () {
    // AdMob expires a loaded rewarded ad about an hour after it loads and says
    // nothing — it fails at the tap, arriving as a dismissal nobody made.
    test('a stale one is disposed rather than shown', () async {
      final clock = _Clock();
      final loader = _Loader();
      final ads = _ads(loader, clock: clock.call)..prepare('energy_pip');
      await Future<void>.delayed(Duration.zero);
      final stale = loader.handed.first;

      clock.advance(adFreshness + const Duration(minutes: 1));
      expect(await ads.show('energy_pip'), AdOutcome.rewarded);
      expect(stale.disposed, isTrue, reason: 'the expired ad was kept');
      expect(stale.shows, 0, reason: 'the expired ad was SHOWN');
      // [1], not `.last` — the show lines the NEXT one up before it returns.
      expect(loader.handed[1].shows, 1);
    });

    test('and a fresh one is left exactly where it is', () async {
      final clock = _Clock();
      final loader = _Loader();
      final ads = _ads(loader, clock: clock.call)..prepare('energy_pip');
      await Future<void>.delayed(Duration.zero);

      clock.advance(adFreshness - const Duration(minutes: 1));
      await ads.show('energy_pip');
      expect(loader.handed.first.shows, 1);
      expect(loader.handed.first.disposed, isFalse);
    });

    test('REFRESH RELOADS A STALE SLOT, which is what resume is for', () async {
      final clock = _Clock();
      final loader = _Loader();
      final ads = _ads(loader, clock: clock.call)..prepare('energy_pip');
      await Future<void>.delayed(Duration.zero);
      final stale = loader.handed.first;

      clock.advance(adFreshness + const Duration(minutes: 1));
      ads.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(stale.disposed, isTrue);
      expect(loader.asked, hasLength(2), reason: 'nothing was warmed back up');
    });

    test('and refreshing a fresh slot costs nothing at all', () async {
      // A resume must not spend an ad request every time the player glances at
      // the app.
      final clock = _Clock();
      final loader = _Loader();
      final ads = _ads(loader, clock: clock.call)..prepare('energy_pip');
      await Future<void>.delayed(Duration.zero);

      clock.advance(const Duration(minutes: 5));
      ads.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(loader.asked, hasLength(1));
      expect(loader.handed.first.disposed, isFalse);
    });

    test('refreshing an empty slot warms nothing either', () async {
      // Nothing has expired because nothing was ever there; a resume on a
      // screen with no offer on it should not be loading videos.
      final loader = _Loader();
      _ads(loader).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(loader.asked, isEmpty);
    });

    test('and the shipping default has a refresh that does nothing', () {
      expect(() => const NoRewardedAds().refresh(), returnsNormally);
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

  group('EVERY ASK IS ANSWERED ON THE RECORD', () {
    // The three outcomes are three different problems and the dashboard cannot
    // tell them apart without this: `rewarded` is the funnel working,
    // `dismissed` is a player walking away from a reward, and `unavailable` is
    // inventory or consent failing them — which reads to the player as a broken
    // button and to AdMob as nothing at all.
    late List<({String name, Map<String, Object?> params})> sent;

    setUp(() {
      sent = [];
      setAnalyticsSink((name, params) => sent.add((name: name, params: params)));
    });

    tearDown(() => setAnalyticsSink(null));

    test('a watched video is `ad_watched`, with its placement', () async {
      // **THREE NAMES, which are the JS's three.** One event with an `outcome`
      // param is tidier and is the wrong shape here: FC has been sending
      // `ad_watched` / `ad_dismissed` / `ad_failed` into this same Firebase
      // project for the life of the app, and the port ships as an update to
      // it — see the head of `services/analytics_wiring.dart`.
      await _ads(_Loader()).show('lucky_boot');
      expect(sent.single.name, 'ad_watched');
      expect(sent.single.params['outcome'], 'rewarded');
      expect(sent.single.params['placement'], 'lucky_boot');
      expect(sent.single.params['ad_platform'], 'android');
      // The JS's dimension, and load-bearing: a rewarded video the player
      // chose and an interstitial they were shown are different funnels.
      expect(sent.single.params['type'], 'rewarded');
    });

    test('one closed early is `ad_dismissed` rather than missing', () async {
      await _ads(_Loader(earns: false)).show('energy_pip');
      expect(sent.single.name, 'ad_dismissed');
      expect(sent.single.params['outcome'], 'dismissed');
    });

    test('AND A NO-FILL IS REPORTED, which is the one that was invisible', () {
      // No fill emits nothing to AdMob, so without this the placement simply
      // stops appearing and reads as a placement nobody uses.
      expect(_ads(_Loader(fill: false)).show('daily_double'), completion(AdOutcome.unavailable));
    });

    test('a consent refusal is reported too, and it is not an error', () async {
      await _ads(_Loader(), permitted: false).show('heal_all');
      expect(sent.single.name, 'ad_failed');
      expect(sent.single.params['outcome'], 'unavailable');
      expect(sent.single.params['placement'], 'heal_all');
    });

    test('AND CONSENT IS TOLD APART FROM NO-FILL, which one unit hides', () async {
      // Both answer `unavailable` and want opposite responses: one is a choice
      // the player made, the other is inventory. While a placement had its own
      // unit, AdMob's fill rate sat next to it and the split could be read from
      // there; with one unit for everything this is the only place it exists.
      await _ads(_Loader(), permitted: false).show('heal_all');
      expect(sent.single.params['reason'], 'consent');
      sent.clear();
      await _ads(_Loader(fill: false)).show('heal_all');
      expect(sent.single.params['reason'], 'no_fill');
    });

    test('and a watched video carries no reason, because nothing went wrong', () async {
      await _ads(_Loader()).show('energy_pip');
      expect(sent.single.params.containsKey('reason'), isFalse);
    });

    test('A WARM-HERE SHOWN-THERE HOP IS ON THE RECORD', () async {
      // One warm ad for the whole app means the training screen loads ads the
      // shop spends. A per-placement load count that ignored this would read as
      // the training screen wasting inventory.
      final ads = _ads(_Loader())..prepare('skip_cooldown');
      await Future<void>.delayed(Duration.zero);
      await ads.show('lucky_boot');
      expect(sent.single.params['placement'], 'lucky_boot');
      expect(sent.single.params['warmed_for'], 'skip_cooldown');
    });

    test('and it is left off when the two are the same place', () async {
      final ads = _ads(_Loader())..prepare('lucky_boot');
      await Future<void>.delayed(Duration.zero);
      await ads.show('lucky_boot');
      expect(sent.single.params.containsKey('warmed_for'), isFalse);
    });

    test('a double tap is not an ad ask, so it reports nothing', () async {
      final ads = _ads(_Loader());
      final first = ads.show('energy_pip');
      await ads.show('lucky_boot');
      await first;
      expect(sent, hasLength(1));
      expect(sent.single.params['placement'], 'energy_pip');
    });

    test('every outcome carries whether it could be PERSONALISED', () async {
      // On iOS a fill rate is not comparable between an ATT-authorised device
      // and a contextual one, so the eCPM has no explanation without it.
      await _ads(_Loader()).show('energy_pip');
      expect(sent.single.params.containsKey('personalised'), isTrue);
    });
  });
}
