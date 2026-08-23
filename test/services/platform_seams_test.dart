/// The three platform seams, tested at the seam rather than at the platform.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';
import 'package:merge_empire_fc/services/store_review.dart';

/// A wake lock with no platform under it, so the refcount can be watched.
class _FakeLock extends WakeLock {
  final List<bool> calls = [];
  bool fail = false;

  @override
  Future<void> enable(bool on) async {
    calls.add(on);
    if (fail) throw StateError('battery saver');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('openExternalUrl refuses anything that is not a web page', () {
    // Every URL this game has is a store page or a policy, so an app scheme
    // arriving here is a bug rather than a feature to support — and `launchUrl`
    // would happily fire a `tel:` or a `mailto:`.
    test('and says so by returning false rather than throwing', () async {
      for (final url in [
        null,
        '',
        'tel:+441234567890',
        'mailto:a@b.c',
        'javascript:alert(1)',
        'market://details?id=com.mergeempirefc.app',
        'not a url at all',
      ]) {
        expect(await openExternalUrl(url), isFalse, reason: '$url');
      }
    });
  });

  group('THE WAKE LOCK IS REFCOUNTED', () {
    test('and the platform is only told when the count crosses zero', () async {
      final lock = _FakeLock();
      await lock.acquire();
      await lock.acquire();
      expect(lock.calls, [true], reason: 'asked twice');
      expect(lock.holds, 2);

      await lock.release();
      expect(lock.calls, [true], reason: 'released while another holds it');
      expect(lock.held, isTrue);

      await lock.release();
      expect(lock.calls, [true, false]);
      expect(lock.held, isFalse);
    });

    test('and a release with nobody holding it cannot go negative', () async {
      final lock = _FakeLock();
      await lock.release();
      await lock.release();
      expect(lock.holds, 0);
      await lock.acquire();
      expect(lock.calls, [true], reason: 'the count was below zero');
    });

    test('A REFUSAL IS A NO-OP, not an error', () async {
      // Battery saver and OS policy both decline, and the game plays exactly as
      // it did before — the JS swallows it too.
      final lock = _FakeLock()..fail = true;
      await lock.acquire();
      expect(lock.held, isFalse, reason: 'a refusal was believed');
      await lock.release();
    });
  });

  group('the store link', () {
    test('is the write-review page on iOS and the listing on Play', () {
      expect(
        storeReviewUrl(platform: 'ios'),
        'https://apps.apple.com/app/id$iosAppStoreId?action=write-review',
      );
      for (final p in ['android', 'web']) {
        expect(
          storeReviewUrl(platform: p),
          'https://play.google.com/store/apps/details?id=$androidPackage',
          reason: p,
        );
      }
    });

    test('and BOTH are https, which openExternalUrl requires', () async {
      // The JS uses `market://` on Android and its own note says the https form
      // is the reliable one on iOS. Here they are both https, because the seam
      // refuses every other scheme — see above.
      for (final p in ['ios', 'android', 'web']) {
        expect(storeReviewUrl(platform: p), startsWith('https://'), reason: p);
      }
    });

    test('and the identifiers are the PUBLISHED app\'s, not the new name', () {
      // `com.mergeempirefc.app` is the primary key of an app already on both
      // stores. The display name changing did not and could not change it.
      expect(androidPackage, 'com.mergeempirefc.app');
      expect(iosAppStoreId, '6766095870');
    });
  });

  group('the network reading', () {
    test('is ONLINE when it cannot tell', () async {
      // No platform channel — a plain widget test, or a desktop build with no
      // plugin. Online is the safe answer: it only ever costs a request that
      // was going to fail harmlessly.
      final net = Network();
      expect(net.isOnline, isTrue);
      await net.start();
      expect(net.isOnline, isTrue);
      await net.stop();
    });
  });
}
