/// AdMob UMP consent. Ported from `../merge-empire-fc/src/utils/adConsent.js`.
///
/// **Required for personalised ads in the EEA, the UK and Switzerland**, and
/// Google's policy also requires that a player can REVOKE consent at any time —
/// which is what the Privacy options row in Settings is for.
///
/// **The port is simpler than the JS's, and it is the plugin that changed rather
/// than the rule.** The JS's own comment records a workaround: "Plugin doesn't
/// expose `presentPrivacyOptionsForm`, so the workaround is reset → request →
/// show to force the form to re-render". `google_mobile_ads` exposes both
/// `loadAndShowConsentFormIfRequired` and `showPrivacyOptionsForm`, so neither
/// the reset nor the re-request is needed — and the reset was the risky half,
/// since it throws away an answer the player already gave.
///
/// **Everything here is best-effort and nothing throws.** No SDK, no network, a
/// form that will not load: all the same outcome, which is that the game runs
/// and the ads that need consent do not serve.
library;

import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Whether a Privacy options entry point has to be offered.
///
/// **Cached at boot so Settings can decide SYNCHRONOUSLY**, exactly as the JS
/// caches it: the row is either there or it is not, and a row that appears a
/// second after the screen does is worse than one that is always there.
bool _privacyOptionsRequired = false;

bool get adConsentAvailable => _privacyOptionsRequired;

/// Whether the SDK is allowed to request an ad yet. False until consent has
/// been resolved one way or the other.
bool _canRequestAds = false;

bool get adsPermitted => _canRequestAds;

/// Putting the consent form on screen. A seam because `ConsentForm`'s own entry
/// point is a STATIC, so a test cannot reach past it to the channel underneath.
typedef ConsentFormPresenter = Future<void> Function();

Future<void> _showFormIfRequired() =>
    ConsentForm.loadAndShowConsentFormIfRequired((_) {});

/// Ask once, at boot, and show the form if the region requires one.
Future<void> initAdConsent({
  ConsentInformation? info,
  ConsentFormPresenter? presentForm,
}) async {
  final consent = info ?? ConsentInformation.instance;
  final showForm = presentForm ?? _showFormIfRequired;
  // **FOUR STEPS, FOUR CATCHES.** Sharing one `try` meant a throw in the form
  // skipped the permission read below it and left the gate at its `false`
  // default — ads off for the session, in regions that needed no consent.
  try {
    await _requestUpdate(consent);
  } catch (_) {}
  // REQUIRED means show it now; it is a no-op when it is not.
  try {
    await showForm();
  } catch (_) {}
  try {
    _privacyOptionsRequired =
        await consent.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  } catch (_) {}
  // The only authority on whether an ad may be requested, so it is asked last
  // and asked unconditionally. Still false when consent was genuinely refused.
  try {
    _canRequestAds = await consent.canRequestAds();
  } catch (_) {}
}

/// Re-read the consent state after a failed boot, WITHOUT re-showing the form.
///
/// `startAds` runs once per launch, so one bad moment on the network used to
/// cost the whole session. Re-prompting someone who already declined would be a
/// policy problem, so this re-reads the answer rather than asking again.
Future<bool> refreshAdConsent({ConsentInformation? info}) async {
  final consent = info ?? ConsentInformation.instance;
  try {
    await _requestUpdate(consent);
  } catch (_) {}
  try {
    _canRequestAds = await consent.canRequestAds();
  } catch (_) {}
  return _canRequestAds;
}

Future<void> _requestUpdate(ConsentInformation consent) {
  // The listener API is a callback pair rather than a Future, so this is the
  // adapter — and a FAILURE completes it too. A consent update that never
  // answers must not hold boot.
  final done = Completer<void>();
  consent.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () => done.complete(),
    (_) => done.complete(),
  );
  return done.future.timeout(
    const Duration(seconds: 8),
    onTimeout: () {},
  );
}

/// What the Settings row did.
enum AdConsentFormResult { shown, unavailable, unsupported }

/// Re-open the form so a player can change their mind. Google requires this to
/// be reachable at any time.
Future<AdConsentFormResult> showAdConsentForm() async {
  if (!_privacyOptionsRequired) return AdConsentFormResult.unavailable;
  try {
    await ConsentForm.showPrivacyOptionsForm((_) {});
    return AdConsentFormResult.shown;
  } catch (_) {
    return AdConsentFormResult.unsupported;
  }
}
