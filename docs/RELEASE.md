# Release and cutover — a runbook

**Not a port queue, and no longer a checklist.** These rows moved out of
`REMAINING.md`, which calls itself "the running list for the Flutter port" and
had stopped being one: it was carrying "buy a sandbox purchase" and "register
the iPhone" alongside modules to write, so its count answered no useful
question. The porting is done; this is what stands between a finished port and
a shipped app.

**Every step below needs something a repository does not have** — a Mac with
signing identities, two store consoles, physical devices, or the old Capacitor
repo. That is why they are written as an ordered procedure rather than as
tickets: a checkbox in this file could only ever be ticked by a person at a
keyboard somewhere else, and a queue whose items no session can close reads as
work outstanding for ever. Each step says what THIS REPO has already done and
pinned with a test, and then what the operator has to bring.

**Do them in order.** Step 1 is on the critical path and is irreversible in the
one direction that matters.

**What changed most recently:** four defects that were sitting behind "console
task" wording and were not console tasks at all — the Android release build
signed with the DEBUG key, `GoogleService-Info.plist` missing from the iOS
bundle, no dSYM upload phase, and a lapsed VIP's re-purchase dead-ending on
"payment failed". All four are fixed here and pinned by `android_signing_test`,
`ios_crash_reporting_test` and `iap_purchase_test`; see steps 2, 3, 7a and 12.

---

## 1. A final Capacitor release that force-writes the native save mirror

**On the critical path, and it must ship BEFORE the Flutter build.** Without
it the Flutter build cannot read an existing player's local save.

**The port's end is pinned**, and it is the highest-stakes string pair in the
whole port: one character wrong and every installed player opens the new build
to a fresh save, with no crash, no error and no way back.
`legacy_save_bridge_keys_test` compares the key against `NATIVE_SAVE_KEY` in
`nativeSaveMirror.js` on both platforms, and asserts the ASYMMETRY that is easy
to get backwards: iOS carries a `CapacitorStorage.` prefix and Android does
not — which is not a port decision but `@capacitor/preferences`'s own
`Preferences.swift`, whose group name prefixes every UserDefaults key. It also
pins the method channel, because a mismatch there raises
`MissingPluginException`, which the bridge swallows as "no legacy save" — the
same answer as a genuinely new player.

**Yours:** a release from `../merge-empire-fc`, out to both stores, with enough
soak time for players to run it once before the Flutter build lands.

## 2. Put `key.properties` and the keystore on the build machine

**The release build was signed with the DEBUG key** — `flutter create`'s
default, behind a TODO — which was never a console task waiting its turn: Play
REFUSES a debug-signed artifact at upload, and the signing identity is the one
property of an Android app that cannot be corrected afterwards.

**The repo's half is done.** `android/app/build.gradle.kts` reads
`android/key.properties` and falls back to the debug key with a LOUD warning, so
a machine that has never seen the key can still run a release build without
quietly producing something unshippable. `android_signing_test` holds that shape
from Dart, since there is no Android SDK here to run Gradle.

**Yours:** `key.properties` (`storeFile`, `storePassword`, `keyAlias`,
`keyPassword`) and the keystore itself, both from the old Capacitor repo, both
correctly git-ignored here. A signing key in a repository is a worse bug than
an unsigned build — do not commit them to fix this step.

## 3. Put the two Firebase config files on the build machine

`google-services.json` and `GoogleService-Info.plist` are the shipped app's own
and are git-ignored (line 24 and 25 of `.gitignore`), so a fresh clone has
neither. Both builds fail loudly without them, which is the intended behaviour:
the Android `com.google.gms.google-services` plugin names the file it wants, and
Xcode now reports the plist as a missing build input.

**The repo's half is done, and one half of it was silently broken.** The plist
was on disk and had never been added to the Xcode project — no file reference,
nothing in the Resources phase — so it was never copied into the app bundle,
`Firebase.initializeApp()` found no project, and `startAnalytics`'s own
`catch (_)` returned. No crash, no log line, no events: iOS had neither
analytics nor crash reporting, and nothing said so. `ios_crash_reporting_test`
pins the reference and the Resources entry, never the file.

**Yours:** copy both across from the old repo before building either platform.

## 4. iOS: signing and App Store Connect

**Yours entirely** — a Mac, the distribution certificate and provisioning
profile, and the App Store Connect record. Steps 3 and 12 are the parts of the
iOS release that were this repo's, and both are now done.

## 5. Android: the release pipeline

**The SDK LEVELS half is done and pinned.** minSdk is the one that can strand
players: an update whose minSdk is HIGHER than the shipped app's is not offered
to the devices below it — those players keep the Capacitor build for ever, and
Play reports it as a smaller device count rather than as an error. The shipped
app is 24 and Flutter 3.44's default is 24, so the port is level;
`android_sdk_levels_test` reads the toolchain's own value so a version bump that
raises it is caught here rather than in the console. targetSdk moves the OTHER
way — Play requires a recent one to accept an upload at all — so that assertion
is a floor rather than a ceiling.

**The VERSION half is done too, and it was wrong.** The port carried
`flutter create`'s `1.0.0+1` — versionCode 1, against a live build of 10112.
Play refuses an upload whose code is not higher than the shipped one, so the
port as it stood could not have been uploaded at all, and `1.0.0` would have
read as a downgrade on the listing beside 1.1.12. Now 1.2.0+10200, on the
shipped app's own major×10000 scheme, pinned by `native_version_test` along with
the Dart `appVersion` the Settings footer prints and the two native configs —
both DERIVE from pubspec, and a hardcoded number there is the same console-only
failure.

**The PIPELINE half is done.** `.github/workflows/build-release.yml` is the old
repo's `build-release.yml` ported to Flutter: a `v*` tag builds the signed
bundle and APK, checks the tag against pubspec and the Play notes against the
500-character cap, creates the GitHub Release and uploads to the internal track.
It does NOT run the test suite — run it locally before tagging; `ci.yml` only
analyzes. It needs four repository secrets, named as in the old repo so the
same values carry over: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD` (store and key,
alias `merge-empire-fc`), `GOOGLE_SERVICES_JSON` (base64) and
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. The Play Games and AdMob ids the old job
injected are already in the manifest here.

**Yours:** the four secrets, and `distribution/whatsnew/whatsnew-en-GB` — the
notes Play shows for the release, under 500 characters.

## 6. Store listings, whatsnew, changelog

**The IDENTIFIERS half is done and pinned.** `native_identifiers_test` reads the
application id, the bundle id and both AdMob APP ids straight out of the native
config and compares them to `capacitor.config.ts`. Those are primary keys: a
Flutter port that takes what `flutter create` gives it is a SECOND app, with no
reviews, no installs and every existing player stranded.

**Yours:** copy and screenshots, in both consoles.

## 7. Confirm the eleven in-app products are still Active, under the same ids

Eleven SKUs, each matching `IapProduct.sku` character for character, with the
consumable / non-consumable flag matching `IapProduct.type` — the store is what
refuses a repeat purchase of a one-time product, not our code. They already
exist for the live app; this is a check, not a creation, and the check matters
because a renamed product id is an unbuyable product.

**The port's side is pinned.** `iap_catalogue_parity_test` compares all eleven
ids and types against a node-dumped fixture, so a rename here fails a build
rather than a console.

**Yours:** open both consoles and confirm the eleven, under those exact ids.

### 7a. And while you are there: buy VIP, let it lapse, buy it AGAIN

**That was the one case that could be silently broken, and the port's half of
it is now fixed.** `vip_pass` is registered with the store as a NON-CONSUMABLE
and is deliberately not `oneTime`, so the port offers a lapsed VIP the buy
button while the store is entitled to refuse a second purchase of something the
account already bought — Play answers ITEM_ALREADY_OWNED. Neither store has a
code for that beyond a generic failure, so the player got "payment failed" and
no way forward: the shop's one dead end.

**The store is now asked what it OWNS rather than what its error meant**, which
is the part that needed no console. A failed non-consumable purchase runs the
restore that `restorePurchases` already used, and an owned SKU is granted
instead of refused — so the lapsed VIP's tap does what they meant by it. Not on
a cancel, which is an answer; not on a consumable, which a restore never lists;
and a store that will not answer leaves the original refusal standing.
`iap_purchase_test` pins all four. Branching on the numeric error code would
have been the guess — the codes in `iap_billing_policy.dart` are
`cordova-plugin-purchase`'s and have never been re-pointed at this plugin's —
and ownership is a question every store answers the same way.

**Yours:** run it anyway. StoreKit tends to hand a repeat purchase of a
non-consumable back as a restore rather than an error, so iOS may never reach
that path at all, and how `vip_pass` is really declared in the two consoles
cannot be read from this repo.

## 8. Sandbox purchase pass on both platforms

Every SKU bought once, plus a restore on a clean install. **Yours** — sandbox
accounts on both stores and a device or simulator signed in to them.

---

**Steps 9 to 12 are the cutover itself.**

## 9. Internal-track build, device pass on both platforms

**Yours.** Before the iOS half of it, **register the iPhone at
developer.apple.com** → Certificates, Identifiers & Profiles → Devices. It
unblocks every iOS device pass, and has been blocking since v1.15.9 of the old
app.

## 10. Profile-mode timings on physical hardware

Gates the M3 diorama technique choice. The iOS Simulator cannot run profile
mode; `test_driver/integration_test.dart` is committed so the real run is a
one-liner once a device is attached.

## 11. Staged rollout

**Yours**, in both consoles.

## 12. Watch for save-migration failures in Crashlytics

**This step did not work, and would have looked as though it did.** Two separate
faults, both now fixed and pinned by `ios_crash_reporting_test`:

- **iOS never started Firebase at all** — see step 3. The reports would simply
  not have arrived, and `startAnalytics` swallows the reason.
- **Nothing uploaded the dSYM.** Crashlytics symbolises an iOS report from the
  dSYM, and no build phase sent one, so every report would have arrived as hex
  addresses. There is now a `[firebase_crashlytics] Upload dSYMs` phase, last in
  the Runner target so the dSYM exists by the time it runs; a checkout with no
  pods gets a warning rather than a failed build, on the same reasoning as the
  Android signing fallback in step 2 — the quiet path is the dangerous one, so
  it is the one that has to be loud.

**Yours:** watch the dashboard through the rollout in step 11. The migration is
step 1's bridge, so the signature to look for is the bridge raising rather than
the game crashing — a player opening a fresh save is a SILENT failure and will
not appear here at all. Cross-check against the install-to-save-restore rate in
analytics.
