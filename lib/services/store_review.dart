/// The OS review sheet, and the store page it falls back to. Ported from
/// `requestNativeReview` and `_openStorePage` in `engine/ratingEngine.js`.
///
/// **The two platforms give different things and the JS accepts both.**
///   - **iOS** — `SKStoreReviewController`: stars only, and Apple may silently
///     not show it at all (rate-limited to roughly three a year in production).
///     An accepted trade-off rather than a bug to work around.
///   - **Android** — the Play in-app review card: stars plus a written review
///     without leaving the app. It only actually SUBMITS when the build was
///     installed through Play, so a sideloaded debug build shows the card and
///     swallows the result.
///
/// Anything else — the sheet unavailable, no Play services, a desktop build —
/// falls through to the store's write-review page. `engine/rating_prompt.dart`
/// decides WHETHER; this only knows how.
library;

import 'dart:io' show Platform;

import 'package:in_app_review/in_app_review.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';

/// **The identifiers deliberately still read `mergeempirefc`.** `com.mergeempirefc.app`
/// on both stores is the primary key of an already-published app; the display
/// name changing did not and could not change it.
const String androidPackage = 'com.mergeempirefc.app';
const String iosAppStoreId = '6766095870';

/// The write-review page for a platform. `web` is the JS's third branch and the
/// port's answer for a desktop build.
///
/// **https rather than `itms-apps://` on iOS**, which is the JS's own note: the
/// scheme URL was less reliable, and the https one redirects to the App Store
/// app on a device anyway. Android takes the https form too rather than
/// `market://` — [openExternalUrl] refuses a non-http scheme on purpose, and
/// Play resolves its own web URL into the app.
String storeReviewUrl({String? platform}) {
  final id = platform ?? _platform();
  if (id == 'ios') {
    return 'https://apps.apple.com/app/id$iosAppStoreId?action=write-review';
  }
  return 'https://play.google.com/store/apps/details?id=$androidPackage';
}

String _platform() {
  try {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
  } catch (_) {
    // No platform to ask — a plain `dart test`.
  }
  return 'web';
}

/// Ask for a review, the best way this device can.
///
/// Never throws and never reports: a review sheet that will not open is not
/// something to tell the player about.
Future<void> requestNativeReview({InAppReview? review}) async {
  final platform = _platform();
  if (platform == 'ios' || platform == 'android') {
    try {
      final sheet = review ?? InAppReview.instance;
      if (await sheet.isAvailable()) {
        await sheet.requestReview();
        return;
      }
    } catch (_) {
      // Fall through to the store page, exactly as the JS does.
    }
  }
  await openExternalUrl(storeReviewUrl(platform: platform));
}
