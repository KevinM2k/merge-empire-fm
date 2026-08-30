# Release and cutover

**Not a port queue.** These rows moved out of `REMAINING.md`, which calls itself
"the running list for the Flutter port" and had stopped being one: it was
carrying "buy a sandbox purchase" and "register the iPhone" alongside modules to
write, so its count answered no useful question. The porting is done; this is
what stands between a finished port and a shipped app.

**Every one of them needs something a repository does not have** — a Mac with
signing identities, two store consoles, physical devices, or the old Capacitor
repo. They are listed with the half that IS this repo's marked done, because
several of them had one and it was worth doing: the SDK levels, the version
codes, the identifiers, the IAP catalogue and now the Android signing CONFIG are
all pinned by tests, so what is left in each row is genuinely the console.

**What changed here most recently:** the Android release build was signed with
the DEBUG key — `flutter create`'s default, behind a TODO — which is not a
console task waiting its turn but an artifact Play refuses at upload. It reads
`android/key.properties` now, git-ignored and absent, and falls back to the
debug key with a LOUD warning so a keyless machine can still run a release build
without quietly producing something unshippable. `android_signing_test` holds
the shape of that from Dart, since there is no Android SDK here to run Gradle.

---

## M6 — release

- [ ] **A final Capacitor release from the OLD repo that force-writes the native
      save mirror.** On the critical path: without it the Flutter build cannot
      read an existing player's local save. Must ship before cutover — that
      part is a publish and is not this repo's to do.
      **THE PORT'S END IS NOW PINNED**, though, and it is the highest-stakes
      string pair in the whole port: one character wrong and every installed
      player opens the new build to a fresh save, with no crash, no error and no
      way back. `legacy_save_bridge_keys_test` compares the key against
      `NATIVE_SAVE_KEY` in `nativeSaveMirror.js` on both platforms, and asserts
      the ASYMMETRY that is easy to get backwards: iOS carries a
      `CapacitorStorage.` prefix and Android does not — which is not a port
      decision but `@capacitor/preferences`'s own `Preferences.swift`, whose
      group name prefixes every UserDefaults key. It also pins the method
      channel, because a mismatch there raises `MissingPluginException`, which
      the bridge swallows as "no legacy save" — the same answer as a genuinely
      new player.
- [ ] iOS: signing, dSYM upload, App Store Connect
- [ ] Android: the CI-generated build config, AGP/Gradle, and the signing
      keystore. **THE SIGNING CONFIG IS NOW DONE — the keystore is what is
      left.** The release build was signed with the DEBUG key, which is not a
      console task waiting its turn: Play refuses a debug-signed artifact at
      upload, and the signing identity is the one property of an Android app
      that cannot be corrected afterwards. `build.gradle.kts` reads
      `android/key.properties` (git-ignored, and correctly not in this repo) and
      falls back to the debug key with a loud warning, so a machine that has
      never seen the key can still run a release build without silently
      producing something unshippable. `android_signing_test` pins that shape.
      **The SDK LEVELS half is done and pinned.** minSdk is the one
      that can strand players: an update whose minSdk is HIGHER than the shipped
      app's is not offered to the devices below it — those players keep the
      Capacitor build for ever, and Play reports it as a smaller device count
      rather than as an error. The shipped app is 24 and Flutter 3.44's default
      is 24, so the port is level; the test reads the toolchain's own value so a
      version bump that raises it is caught here rather than in the console.
      targetSdk moves the OTHER way — Play requires a recent one to accept an
      upload at all — so that assertion is a floor rather than a ceiling.
      **The VERSION half is done too, and it was wrong.** The port carried
      `flutter create`'s `1.0.0+1` — versionCode 1, against a live build of
      10112. Play refuses an upload whose code is not higher than the shipped
      one, so the port as it stood could not have been uploaded at all, and
      `1.0.0` would have read as a downgrade on the listing beside 1.1.12. Now
      1.2.0+10200, on the shipped app's own major×10000 scheme, pinned by
      `native_version_test` along with the Dart `appVersion` the Settings footer
      prints and the two native configs — both DERIVE from pubspec, and a
      hardcoded number there is the same console-only failure.
      What is left is signing (`keystore.properties` is in the old repo and is
      not committed here) and the release pipeline.
- [ ] Store listings, whatsnew, changelog. **The IDENTIFIERS half is done and
      pinned** — `native_identifiers_test` reads the application id, the bundle
      id and both AdMob APP ids straight out of the native config and compares
      them to `capacitor.config.ts`. Those are primary keys: a Flutter port that
      takes what `flutter create` gives it is a SECOND app, with no reviews, no
      installs and every existing player stranded. What is left is copy and
      screenshots in the consoles.
- [ ] **The in-app products themselves, in both consoles.** Eleven SKUs, each
      matching `IapProduct.sku` character for character, with the consumable /
      non-consumable flag matching `IapProduct.type` — the store is what refuses a
      repeat purchase of a one-time product, not our code. They already exist for
      the live app; this is a check, not a creation, and the check matters because
      a renamed product id is an unbuyable product.
      **The PORT's side of that is already pinned** — `iap_catalogue_parity_test`
      compares all eleven ids and types against a node-dumped fixture, so a
      rename here fails a build rather than a console. What is left is genuinely
      the console: confirming the eleven are still Active under those exact ids.
- [ ] **Buy VIP, let it lapse, buy it AGAIN — that is the one case that can be
      silently broken.** `vip_pass` is registered with the store as a
      NON-CONSUMABLE and is deliberately not `oneTime`, so the port offers a
      lapsed VIP the buy button while the store is entitled to refuse a second
      purchase of something the account already owns. Neither store has a code
      for that beyond a generic failure, so the player would get "payment
      failed" and no way forward. This is the JS's arrangement exactly — the
      port matches it product for product — so it is a property of the LIVE
      app rather than a port regression, and it must not be "fixed" here on a
      guess: whether it works at all depends on how `vip_pass` is really
      declared in the two consoles, which cannot be read from this repo.
- [ ] Sandbox purchase pass on both platforms: every SKU bought once, plus a
      restore on a clean install.

---

## M7 — cutover

- [ ] Internal-track build, device pass on both platforms
- [ ] Staged rollout
- [ ] Watch for save-migration failures in Crashlytics
- [ ] **Profile-mode timings on physical hardware.** Gates the M3 diorama
      technique choice. The iOS Simulator can't run profile mode;
      `test_driver/integration_test.dart` is committed so the real run is a
      one-liner once a device is attached.
- [ ] **Register the iPhone at developer.apple.com** → Certificates, Identifiers
      & Profiles → Devices. It unblocks every iOS device pass, and has been
      blocking since v1.15.9 of the old app.
