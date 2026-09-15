# Open crash reports

Crashlytics issues that have been triaged and **not yet fixed**. One section
each, newest first. A section comes out when the fix has shipped AND the issue
has stopped recurring — not when the fix merges.

Console: Firebase → Crashlytics → `com.mergeempirefc.app`.

---

## Unity Ads `GatewayException: unknown error` — open, deliberately not acted on

**Fatal, and entirely inside Unity's SDK.** Not one Flutter or Dart frame
appears on any thread and `main` is parked in the looper. The throw is

```
com.unity3d.ads.core.data.model.exception.GatewayException: unknown error
  at ...AndroidHandleGatewayUniversalResponse.invoke(AndroidHandleGatewayUniversalResponse.kt:18)
  at ...CommonGatewayClient.executeWithRetry(CommonGatewayClient.kt:81)
```

on a `DefaultDispatcher` coroutine worker. Unity's gateway returned something
their SDK could not parse, `executeWithRetry` spent its retries, and the
exception escaped a scope launched with no `CoroutineExceptionHandler` — so the
default handler took the process.

**Nothing app-side can catch it.** It never crosses the platform channel, so
`rewarded_ads.dart`'s `AdOutcome.unavailable` path — written for precisely this,
an ad that will not serve — never runs. The player tapped for a reward and the
game vanished.

**It reaches players through AdMob's waterfall**, not a direct call. `pubspec.yaml`
pins `gma_mediation_unity: 1.6.3`, which bundles `com.unity3d.ads:unity-ads:4.16.3`.

### Why it is not being fixed

**The shape says outage, not defect.** 26 events: 23 in one spike on 12–13 Sep
on 2.0.7, 2 on 2.0.6, 1 on 2.0.9, flat either side. Two builds that were live
together spiked together on the same day and then stopped, which is Unity's
backend having a bad afternoon rather than a bug a release closes.

**The cost per crash is small.** `saveDebounceMs` is 2s against a
`saveMaxWaitMs` of 10s, so a hard kill costs at most ten seconds of progress and
the player relaunches roughly where they were.

**The device mix wants a second look before these are counted as players.**
61% Xiaomi, 27% "LoopDL" — not a retail brand — and 73% Android 16. A quarter of
the events from an unknown manufacturer, concentrated in a single day, is as
often an emulator farm as it is a customer.

### What a fix costs

**The adapter bump is closed off on gma 6.** 1.6.3 is the last release for
`google_mobile_ads: ^6.0.0`; 1.6.4 wants gma 7, 1.7.0 wants 8, and 1.10.0 wants
9.1 and carries `unity-ads` 4.17.0. `gma_mediation_meta` moves in lockstep,
1.5.0 → 1.7.0.

**The Dart side of that bump is free.** Every signature the port uses is
identical between gma 6.0.0 and 9.1.0 — `RewardedAd.load`, `AdRequest`,
`RewardedAdLoadCallback`, `FullScreenContentCallback`, `show(onUserEarnedReward:)`,
`MobileAds.instance.initialize`, `updateRequestConfiguration`,
`RequestConfiguration` and both `Tag*` enums, `ConsentInformation`,
`ConsentForm.loadAndShowConsentFormIfRequired`, `showPrivacyOptionsForm`. The
breaking changes in 7, 8 and 9 are all in native ad templates and anchored
adaptive banner sizes, and the port ships neither. Three files import the plugin:
`admob_ads.dart`, `ad_consent.dart`, `app_tracking.dart`. Flutter ≥3.38.1,
Dart ≥3.10 and an iOS deployment target of 13.0 all clear what is already pinned.

**iOS is the whole of the work.** gma 8 migrated the plugin to `UISceneDelegate`;
`ios/Runner/AppDelegate.swift` still takes the classic `window?.rootViewController`
path and `Info.plist` carries no `UIApplicationSceneManifest`. Whether the plugin
forces the host app to adopt scenes is a device test, not something to reason out.
gma 8 also added Swift Package Manager support, which makes the
`enable-swift-package-manager: false` comment in `pubspec.yaml` stale — a separate
change, not a passenger on this one.

**And no release note claims 4.17.0 fixes this.** `GatewayException: unknown
error` is Unity's catch-all for an unparseable response and is reported across
many of their SDK versions. The bump buys a current AdMob SDK, which is worth
having on its own merits; calling it the fix for this would be a guess.

### The cheap lever, if it recurs

Unity can be dropped from the mediation group in the AdMob console — no code, no
release, effective for everyone immediately. It costs Unity's share of fill,
which is the wrong thing to give up while revenue is the larger problem.

### When this is picked up again

- Read the issue header for events **and users**; the figures above are events.
- Check the crash-free-users rate and where this ranks. Below the top five it is
  noise, and there will be something above it worth the release instead.
- Find out what "LoopDL" is.
