/// Texas App Store Accountability Act (SB 2420) compliance, ported from
/// `../merge-empire-fc/src/utils/ageVerification.js`.
///
/// Google Play's Age Signals API returns an age group for Texas users once the
/// state-mandated verification has been completed on their account. Everywhere
/// else — every other state, every iOS device, and Android before the rollout
/// reaches it — the answer is [AgeGroup.unknown], and the whole point of this
/// file is that unknown means ALLOWED. We only restrict when Play has
/// affirmatively said the user is a minor; guessing from a locale or a birthday
/// prompt would restrict people the law does not.
///
/// **The signal is cached for seven days**, because the JS's is: the native call
/// crosses a plugin bridge and the answer changes at most once, when a parent
/// completes verification. Re-querying every boot buys nothing and costs a
/// bridge round trip on the frame the app is starting.
///
/// **This is pure Dart and it lives in `lib/engine/`**, which is what
/// `test/architecture_test.dart` enforces: the only thing here that touches a
/// platform is [ageSignalSource], which is a function reference a test replaces.
library;

import 'package:merge_empire_fc/util/time.dart';

/// The four values Play's API can hand back.
///
/// The JS carries them as strings because they are written into the save, and
/// so does this: `state['ageVerification']['status']` has to round-trip through
/// JSON and through a legacy save written by the JS build, so the wire value is
/// the enum's [name] and never its index.
enum AgeGroup {
  /// No signal available — non-Texas, iOS, or the API not yet rolled out.
  unknown,

  /// Under 13.
  child,

  /// 13 to 17.
  teen,

  /// 18 and over.
  adult;

  /// Back from the save. An unrecognised string is [unknown], which is the
  /// permissive answer — a save written by a newer build must not lock a player
  /// out of the shop because this one cannot read it.
  static AgeGroup fromName(Object? value) => switch (value) {
    'child' => AgeGroup.child,
    'teen' => AgeGroup.teen,
    'adult' => AgeGroup.adult,
    _ => AgeGroup.unknown,
  };

  /// Play's own numeric values: 0 unknown, 1 child, 2 teen, 3 adult.
  static AgeGroup fromPlayValue(Object? value) => switch (value) {
    1 => AgeGroup.child,
    2 => AgeGroup.teen,
    3 => AgeGroup.adult,
    _ => AgeGroup.unknown,
  };
}

/// Re-query the API after this long.
const int ageSignalCacheTtlMs = 7 * 24 * 60 * 60 * 1000;

/// **THE ONLY PLATFORM IN THIS FILE, and it is a variable.**
///
/// The JS reaches through `window.Capacitor.Plugins.PlayAgeSignals`, which does
/// not exist here and will not until the native plugin is written — so the
/// default is the same answer the JS gives on every platform that has no
/// plugin: [AgeGroup.unknown]. Swapping this is how a test drives the child and
/// teen branches, and it is what the native bridge will assign to when it
/// lands.
///
/// It must never throw. The JS wraps its plugin call in a bare `try/catch`
/// returning UNKNOWN, and [checkAndUpdateAgeSignal] does the same round this —
/// a compliance check that crashes the boot is worse than one that says it does
/// not know.
Future<AgeGroup> Function() ageSignalSource = _noSignal;

Future<AgeGroup> _noSignal() async => AgeGroup.unknown;

/// Put the default back. For tests, and for the same reason `resetClock` exists.
void resetAgeSignalSource() => ageSignalSource = _noSignal;

Map<String, dynamic>? _block(Map<String, dynamic> state) {
  final av = state['ageVerification'];
  return av is Map<String, dynamic> ? av : null;
}

/// Called once per boot. Queries the signal and updates `state`, in place.
///
/// Returns the group the API gave THIS call — not the cached one — which is
/// what the JS returns and is the difference a caller wanting to know whether
/// the API answered would look at.
Future<AgeGroup> checkAndUpdateAgeSignal(Map<String, dynamic> state) async {
  final av = _block(state) ?? const <String, dynamic>{};
  final at = now();

  // Still fresh, and it came from the API rather than from a first-boot stub.
  final checkedAt = av['checkedAt'];
  if (av['source'] == 'play_api' &&
      checkedAt is num &&
      checkedAt > 0 &&
      at - checkedAt < ageSignalCacheTtlMs) {
    return AgeGroup.fromName(av['status']);
  }

  AgeGroup group;
  try {
    group = await ageSignalSource();
  } catch (_) {
    group = AgeGroup.unknown;
  }

  // The consent pair survives every write: it is the parent's answer, and a
  // re-query of the age signal is not a reason to ask them again.
  Map<String, dynamic> written(String? source) => <String, dynamic>{
    ...av,
    'status': group.name,
    'source': source,
    'checkedAt': at,
    'parentalConsentGiven': av['parentalConsentGiven'] ?? false,
    'parentalConsentAt': av['parentalConsentAt'] ?? 0,
  };

  if (group != AgeGroup.unknown) {
    state['ageVerification'] = written('play_api');
  } else if (checkedAt is! num || checkedAt == 0) {
    // First boot on a device with no signal. The attempt is recorded so the
    // block exists — but `source` stays null, so the cache check above will not
    // short-circuit it and a device that gets the API later still asks.
    state['ageVerification'] = written(null);
  }

  return group;
}

/// A parent tapped Allow. **The status is not touched** — they are still a
/// minor, and the consent is a separate fact about them.
void grantParentalConsent(Map<String, dynamic> state) {
  final av = _block(state);
  if (av == null) {
    state['ageVerification'] = <String, dynamic>{
      'status': AgeGroup.unknown.name,
      'source': null,
      'checkedAt': 0,
      'parentalConsentGiven': true,
      'parentalConsentAt': now(),
    };
    return;
  }
  av['parentalConsentGiven'] = true;
  av['parentalConsentAt'] = now();
}

/// Whether this player may spend real money.
///
/// **Unknown is allowed, and that is deliberate rather than lax.** The law asks
/// for consent from users the store has IDENTIFIED as minors; there is no
/// signal for anybody else, and treating a missing signal as a minor would put
/// an age gate in front of every player in the world to satisfy one state.
bool isIapAllowed(Map<String, dynamic> state) {
  final av = _block(state);
  if (av == null) return true;
  final status = AgeGroup.fromName(av['status']);
  if (status == AgeGroup.unknown || status == AgeGroup.adult) return true;
  return av['parentalConsentGiven'] == true;
}

/// Whether Play has told us this is a child or a teen.
bool isConfirmedMinor(Map<String, dynamic> state) {
  final status = AgeGroup.fromName(_block(state)?['status']);
  return status == AgeGroup.child || status == AgeGroup.teen;
}

/// The two flags AdMob's initialiser takes.
///
/// Ad targeting has to be compliant for an identified minor whether or not a
/// parent has consented to PURCHASES — the two are different questions, which
/// is why this reads the status and [isIapAllowed] reads the consent.
({bool tagForChildDirectedTreatment, bool tagForUnderAgeOfConsent})
getAdMobAgeFlags(Map<String, dynamic> state) {
  final status = AgeGroup.fromName(_block(state)?['status']);
  return (
    tagForChildDirectedTreatment: status == AgeGroup.child,
    tagForUnderAgeOfConsent: status == AgeGroup.teen,
  );
}
