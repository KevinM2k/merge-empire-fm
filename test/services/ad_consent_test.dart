/// The consent gate at the seam.
///
/// **This file exists because of a live revenue bug**, found on 14 Sep 2026 in
/// the GA4 read of the September Google Ads run: `ad_stack_blocked` fired for
/// 611 of 1,414 acquired users — 43% — and only 12% of them ever saw a single
/// impression. The campaign's traffic was Egypt, Indonesia, Nigeria, Iraq and
/// Bangladesh, every one of them OUTSIDE the EEA, where `canRequestAds()`
/// answers true because no consent is required at all. They were not refusing
/// consent; they were never being asked the question, because a step BEFORE it
/// threw and took the answer down with it.
///
/// The SDK's own behaviour is not tested here and cannot be — see the note at
/// the head of `services/admob_ads.dart`. What is tested is the gate's logic:
/// which failures may switch ads off and which may not.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:merge_empire_fc/services/ad_consent.dart';

/// A consent backend with no platform under it, so each step can be failed on
/// its own. `ConsentInformation` is abstract, which is what makes this possible
/// — `ConsentForm`'s entry point is a static and needs the presenter seam.
class _FakeConsent implements ConsentInformation {
  _FakeConsent({
    this.canRequest = true,
    this.privacy = PrivacyOptionsRequirementStatus.notRequired,
    this.updateFails = false,
    this.statusThrows = false,
    this.canRequestThrows = false,
  });

  /// What UMP would answer. Outside the EEA this is true with nothing asked.
  bool canRequest;
  PrivacyOptionsRequirementStatus privacy;
  bool updateFails;
  bool statusThrows;
  bool canRequestThrows;

  int updates = 0;
  int canRequestCalls = 0;

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener success,
    OnConsentInfoUpdateFailureListener failure,
  ) {
    updates += 1;
    if (updateFails) {
      failure(FormError(errorCode: 1, message: 'no network'));
    } else {
      success();
    }
  }

  @override
  Future<bool> canRequestAds() async {
    canRequestCalls += 1;
    if (canRequestThrows) throw StateError('no platform');
    return canRequest;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async {
    if (statusThrows) throw StateError('no platform');
    return privacy;
  }

  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.notRequired;

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<void> reset() async {}
}

/// A presenter that stands in for the UMP form. Counted, because the retry path
/// must never put a form back on screen.
class _Form {
  _Form({this.throws = false});

  final bool throws;
  int shown = 0;

  Future<void> call() async {
    shown += 1;
    if (throws) throw StateError('form would not load');
  }
}

void main() {
  group('A STEP THAT THROWS MUST NOT ANSWER THE PERMISSION QUESTION', () {
    // Each of these is one await in `initAdConsent`. They all used to share a
    // single `try`, and `_canRequestAds` was the LAST assignment in it — so a
    // throw anywhere above simply skipped it and left the gate at its `false`
    // default, with the empty `catch` swallowing any sign of why.
    test('the form failing to load leaves ads permitted', () async {
      final consent = _FakeConsent(canRequest: true);
      final form = _Form(throws: true);

      await initAdConsent(info: consent, presentForm: form.call);

      expect(form.shown, 1, reason: 'the form was attempted');
      expect(
        adsPermitted,
        isTrue,
        reason: 'a form that will not load is not a refusal',
      );
    });

    test('the privacy-options status throwing leaves ads permitted', () async {
      final consent = _FakeConsent(canRequest: true, statusThrows: true);
      final form = _Form();

      await initAdConsent(info: consent, presentForm: form.call);

      expect(adsPermitted, isTrue);
    });

    test('a failed consent update still asks whether ads may be requested', () async {
      // The update reporting failure is NOT an exception — the adapter
      // completes either way — but it must not stop the question being asked.
      final consent = _FakeConsent(canRequest: true, updateFails: true);
      final form = _Form();

      await initAdConsent(info: consent, presentForm: form.call);

      expect(consent.canRequestCalls, greaterThan(0));
      expect(adsPermitted, isTrue);
    });
  });

  group('THE GATE ITSELF IS UNTOUCHED', () {
    // The fix must not become a way to serve an ad to someone who said no.
    // `canRequestAds()` stays the only authority.
    test('a refusal still switches ads off', () async {
      final consent = _FakeConsent(canRequest: false);
      final form = _Form();

      await initAdConsent(info: consent, presentForm: form.call);

      expect(adsPermitted, isFalse);
    });

    test('canRequestAds itself throwing switches ads off', () async {
      // Nothing answered the question, so the answer is no. Fail closed.
      final consent = _FakeConsent(canRequestThrows: true);
      final form = _Form();

      await initAdConsent(info: consent, presentForm: form.call);

      expect(adsPermitted, isFalse);
    });

    test('the privacy-options row follows the status it was given', () async {
      final consent = _FakeConsent(
        privacy: PrivacyOptionsRequirementStatus.required,
      );

      await initAdConsent(info: consent, presentForm: _Form().call);

      expect(adConsentAvailable, isTrue);
    });
  });


  group('RE-RESOLVING WITHOUT RE-PROMPTING', () {
    // One bad moment at boot used to cost the whole session: `startAds` runs
    // once from `main.dart`, so a user whose network was down for that one
    // call never got another chance.
    test('refreshAdConsent re-asks and can turn ads back on', () async {
      final consent = _FakeConsent(canRequest: false);
      await initAdConsent(info: consent, presentForm: _Form().call);
      expect(adsPermitted, isFalse);

      // The network came back.
      consent.canRequest = true;
      final permitted = await refreshAdConsent(info: consent);

      expect(permitted, isTrue);
      expect(adsPermitted, isTrue);
    });

    test('refreshAdConsent never puts the form back on screen', () async {
      // Re-prompting someone who already declined is both bad manners and a
      // policy problem. The retry re-reads STATE; it does not re-ask.
      final consent = _FakeConsent(canRequest: false);
      final form = _Form();
      await initAdConsent(info: consent, presentForm: form.call);
      expect(form.shown, 1);

      await refreshAdConsent(info: consent);

      expect(form.shown, 1, reason: 'no second form');
    });

    test('a refusal that is still a refusal stays off', () async {
      final consent = _FakeConsent(canRequest: false);
      await initAdConsent(info: consent, presentForm: _Form().call);

      expect(await refreshAdConsent(info: consent), isFalse);
      expect(adsPermitted, isFalse);
    });
  });
}
