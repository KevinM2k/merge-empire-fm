# M0 — Foundation and Save Bridge Implementation Plan

> **DELIVERED — this is history, not a queue.** The checkboxes below are the
> plan-execution skill's own workflow steps ("write the failing test", "run it",
> "commit") and were never ticked as the work went in. They are not open tasks:
> `lib/state/` is eleven files with thirteen test files against it, and the whole save layer runs under plain `dart test`. The tech-stack line still says Flutter
> 3.38.3, which is two minors behind what this repo is pinned to, and is the
> clearest sign of how long ago this ran. Kept whole because the plan and its
> spec are the record of WHY the module is shaped the way it is.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Flutter project and prove — with tests, on both platforms — that the legacy Capacitor save can be read from Dart, round-tripped without loss, and that card rendering holds its frame budget.

**Architecture:** A `flutter create` scaffold with strict lints and CI. A `LegacySaveBridge` behind a `MethodChannel` reads the Capacitor Preferences store natively (Android `SharedPreferences` file `CapacitorStorage`; iOS `UserDefaults.standard` with a `CapacitorStorage.` key prefix). A `SaveCodec` proves byte-faithful JSON round-tripping with an `extras` passthrough. A card-rendering probe measures frame cost.

**Tech Stack:** Flutter 3.38.3, Dart 3.10.1, Riverpod, Kotlin, Swift, `integration_test`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-17-flutter-port-design.md`

## Global Constraints

- Flutter 3.38.3 / Dart 3.10.1.
- Bundle ID on both platforms is exactly `com.mergeempirefc.app` — it must match the shipped app or the save bridge reads nothing and store continuity breaks.
- `lib/engine/` and `lib/data/` must never import `package:flutter/*`. They run under plain `dart test`.
- `SAVE_VERSION` is 7. Save JSON must round-trip exactly; unknown keys are preserved, never dropped.
- Legacy save key is `mergeEmpireFC_save_native`. Android: SharedPreferences file `CapacitorStorage`, key unprefixed. iOS: `UserDefaults.standard`, key `CapacitorStorage.mergeEmpireFC_save_native`.
- Coverage floors (ratchet upward only): `lib/engine/`+`lib/state/` 95%, `lib/data/`+`lib/util/` 90%, `lib/services/` 80%, `lib/ui/` 70%, overall 85%.
- Source of truth for ported behaviour is `../merge-empire-fc/src/`.
- Commit after every task.

---

### Task 1: Project scaffold, lints, and CI

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `test/smoke_test.dart`, `.github/workflows/ci.yml`
- Modify: `android/app/build.gradle.kts`, `ios/Runner.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: nothing.
- Produces: a runnable Flutter app named `merge_empire_fc` with bundle ID `com.mergeempirefc.app`; `flutter test` and `flutter analyze` both green in CI.

- [ ] **Step 1: Generate the scaffold**

Run from the repo root (the directory already contains `.git`, `.gitignore` and `docs/`):

```bash
cd /Users/kevin/code/github/kevinm2k/merge-empire-fc-flutter
flutter create --org com.mergeempirefc --project-name merge_empire_fc \
  --platforms=ios,android --description "Merge Empire FC" .
```

- [ ] **Step 2: Set the bundle ID on Android**

`flutter create` produces `com.mergeempirefc.merge_empire_fc`. It must be `com.mergeempirefc.app`.

In `android/app/build.gradle.kts`, set both:

```kotlin
android {
    namespace = "com.mergeempirefc.app"
    defaultConfig {
        applicationId = "com.mergeempirefc.app"
    }
}
```

Move the generated `MainActivity.kt` to match the new package and update its `package` declaration:

```bash
mkdir -p android/app/src/main/kotlin/com/mergeempirefc/app
git mv android/app/src/main/kotlin/com/mergeempirefc/merge_empire_fc/MainActivity.kt \
       android/app/src/main/kotlin/com/mergeempirefc/app/MainActivity.kt 2>/dev/null || \
  mv android/app/src/main/kotlin/com/mergeempirefc/merge_empire_fc/MainActivity.kt \
     android/app/src/main/kotlin/com/mergeempirefc/app/MainActivity.kt
rmdir android/app/src/main/kotlin/com/mergeempirefc/merge_empire_fc
```

`MainActivity.kt` must read:

```kotlin
package com.mergeempirefc.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

- [ ] **Step 3: Set the bundle ID on iOS**

Replace every occurrence of the generated identifier with `com.mergeempirefc.app`:

```bash
sed -i '' 's/com\.mergeempirefc\.mergeEmpireFc/com.mergeempirefc.app/g' ios/Runner.xcodeproj/project.pbxproj
grep -c "com.mergeempirefc.app" ios/Runner.xcodeproj/project.pbxproj
```

Expected: `3` (Debug, Release, Profile configurations). If the count is 0, inspect the file for the actual generated identifier and repeat with that value. The RunnerTests target keeps its own `.RunnerTests` suffix — leave it.

- [ ] **Step 4: Add dependencies**

Replace the `dependencies` and `dev_dependencies` blocks of `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

Run: `flutter pub get`

- [ ] **Step 5: Enable strict analysis**

Replace `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - prefer_const_constructors
    - prefer_final_locals
    - avoid_print
    - unawaited_futures
```

- [ ] **Step 6: Write the smoke test**

Delete the generated `test/widget_test.dart` and create `test/smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/main.dart';

void main() {
  testWidgets('app boots and renders a MaterialApp', (tester) async {
    await tester.pumpWidget(const MergeEmpireApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run the test to verify it fails**

Run: `flutter test test/smoke_test.dart`
Expected: FAIL — `MergeEmpireApp` is not defined in `main.dart`.

- [ ] **Step 8: Write minimal `main.dart`**

```dart
import 'package:flutter/material.dart';

void main() => runApp(const MergeEmpireApp());

class MergeEmpireApp extends StatelessWidget {
  const MergeEmpireApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Fully const so `prefer_const_constructors` stays quiet — Step 9 expects
    // `flutter analyze` to report no issues.
    return const MaterialApp(
      title: 'Merge Empire FC',
      home: Scaffold(body: Center(child: Text('Merge Empire FC'))),
    );
  }
}
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `flutter test test/smoke_test.dart`
Expected: PASS

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Add CI**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.3'
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info
```

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: Flutter scaffold with strict lints and CI

Bundle ID pinned to com.mergeempirefc.app to match the shipped app."
```

---

### Task 2: Legacy save bridge — Dart API

**Files:**
- Create: `lib/services/legacy_save_bridge.dart`, `test/services/legacy_save_bridge_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class LegacySaveBridge` with `const LegacySaveBridge({MethodChannel channel})`
  - `Future<String?> readLegacySave()` — returns the raw JSON string, or `null` when absent or unreadable
  - `static const MethodChannel defaultChannel = MethodChannel('com.mergeempirefc.app/legacy_save')`
  - Channel method name: `'readLegacySave'`

- [ ] **Step 1: Write the failing test**

Create `test/services/legacy_save_bridge_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/legacy_save_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mergeempirefc.app/legacy_save');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('returns the raw save string from the platform', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readLegacySave');
      return '{"version":7}';
    });

    expect(await const LegacySaveBridge().readLegacySave(), '{"version":7}');
  });

  test('returns null when the platform has no save', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await const LegacySaveBridge().readLegacySave(), isNull);
  });

  test('returns null instead of throwing when the channel fails', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    expect(await const LegacySaveBridge().readLegacySave(), isNull);
  });

  test('returns null when the platform returns a non-string', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 42);
    expect(await const LegacySaveBridge().readLegacySave(), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/legacy_save_bridge_test.dart`
Expected: FAIL — `legacy_save_bridge.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/services/legacy_save_bridge.dart`:

```dart
import 'package:flutter/services.dart';

/// Reads the save written by the Capacitor build's native mirror.
///
/// The primary save lives in the WebView's localStorage, which Dart cannot
/// reach. `nativeSaveMirror.js` also writes it to the native store, and that
/// copy is the only local migration path.
class LegacySaveBridge {
  const LegacySaveBridge({MethodChannel channel = defaultChannel})
      : _channel = channel;

  static const MethodChannel defaultChannel =
      MethodChannel('com.mergeempirefc.app/legacy_save');

  final MethodChannel _channel;

  /// The raw JSON string, or null when absent, unreadable, or off-platform.
  Future<String?> readLegacySave() async {
    try {
      final result = await _channel.invokeMethod<Object?>('readLegacySave');
      return result is String ? result : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/services/legacy_save_bridge_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/services/legacy_save_bridge.dart test/services/legacy_save_bridge_test.dart
git commit -m "feat: legacy save bridge Dart API"
```

---

### Task 3: Legacy save bridge — Android native

**Files:**
- Modify: `android/app/src/main/kotlin/com/mergeempirefc/app/MainActivity.kt`

**Interfaces:**
- Consumes: channel name `com.mergeempirefc.app/legacy_save`, method `readLegacySave` from Task 2.
- Produces: Android returns the `String` at key `mergeEmpireFC_save_native` in SharedPreferences file `CapacitorStorage`, or `null`.

**Why these exact values:** `@capacitor/preferences` `Preferences.java` calls `context.getSharedPreferences(configuration.group, MODE_PRIVATE)` where `PreferencesConfiguration.DEFAULTS.group = "CapacitorStorage"`, and stores keys unprefixed via `editor.putString(key, value)`.

- [ ] **Step 1: Implement the channel handler**

Replace `android/app/src/main/kotlin/com/mergeempirefc/app/MainActivity.kt`:

```kotlin
package com.mergeempirefc.app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "com.mergeempirefc.app/legacy_save"

// Matches @capacitor/preferences: SharedPreferences file "CapacitorStorage",
// keys stored unprefixed.
private const val CAPACITOR_STORE = "CapacitorStorage"
private const val LEGACY_SAVE_KEY = "mergeEmpireFC_save_native"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readLegacySave" -> result.success(readLegacySave())
                    "writeLegacySaveForTest" -> {
                        writeLegacySave(call.argument<String>("value"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readLegacySave(): String? =
        getSharedPreferences(CAPACITOR_STORE, Context.MODE_PRIVATE)
            .getString(LEGACY_SAVE_KEY, null)

    // Test-only seam so the integration test can plant a save the way the
    // Capacitor build would have written it.
    private fun writeLegacySave(value: String?) {
        getSharedPreferences(CAPACITOR_STORE, Context.MODE_PRIVATE)
            .edit()
            .apply { if (value == null) remove(LEGACY_SAVE_KEY) else putString(LEGACY_SAVE_KEY, value) }
            .apply()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter build apk --debug`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add android/
git commit -m "feat: read Capacitor save mirror on Android"
```

---

### Task 4: Legacy save bridge — iOS native

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes: channel name `com.mergeempirefc.app/legacy_save`, method `readLegacySave` from Task 2.
- Produces: iOS returns the `String` at `UserDefaults.standard` key `CapacitorStorage.mergeEmpireFC_save_native`, or `nil`.

**Why the prefix differs from Android:** `@capacitor/preferences` `Preferences.swift` computes `prefix = group + "."` for `.named("CapacitorStorage")` and calls `applyPrefix(to:)` on every access. Android does not prefix. Getting this wrong reads `nil` on a device that has the save.

- [ ] **Step 1: Implement the channel handler**

Replace `ios/Runner/AppDelegate.swift`:

```swift
import Flutter
import UIKit

private let channelName = "com.mergeempirefc.app/legacy_save"

// Matches @capacitor/preferences: UserDefaults.standard, keys prefixed with
// the group name and a dot.
private let legacySaveKey = "CapacitorStorage.mergeEmpireFC_save_native"

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: channelName,
                                       binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "readLegacySave":
        result(UserDefaults.standard.string(forKey: legacySaveKey))
      case "writeLegacySaveForTest":
        // Test-only seam, mirroring how the Capacitor build wrote the key.
        let value = (call.arguments as? [String: Any])?["value"] as? String
        if let value {
          UserDefaults.standard.set(value, forKey: legacySaveKey)
        } else {
          UserDefaults.standard.removeObject(forKey: legacySaveKey)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter build ios --debug --no-codesign`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ios/
git commit -m "feat: read Capacitor save mirror on iOS

Key is prefixed CapacitorStorage. on iOS but not on Android."
```

---

### Task 5: Device integration test proving the bridge

**Files:**
- Create: `integration_test/legacy_save_bridge_test.dart`

**Interfaces:**
- Consumes: `LegacySaveBridge.readLegacySave()`; the `writeLegacySaveForTest` channel method from Tasks 3 and 4.
- Produces: on-device proof that a value written the way Capacitor writes it is readable through the bridge.

This is the task that actually retires Risk 2 from the spec. The unit tests in Task 2 mock the channel and prove nothing about the native store.

- [ ] **Step 1: Write the integration test**

Create `integration_test/legacy_save_bridge_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/services/legacy_save_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const bridge = LegacySaveBridge();
  const channel = LegacySaveBridge.defaultChannel;

  Future<void> plant(String? value) =>
      channel.invokeMethod<void>('writeLegacySaveForTest', {'value': value});

  tearDown(() => plant(null));

  testWidgets('reads a save planted in the Capacitor native store',
      (tester) async {
    const payload = '{"version":7,"resources":{"fanCoins":1234}}';
    await plant(payload);

    expect(await bridge.readLegacySave(), payload);
  });

  testWidgets('returns null when the native store has no save',
      (tester) async {
    await plant(null);

    expect(await bridge.readLegacySave(), isNull);
  });

  testWidgets('survives a payload the size of a real late-game save',
      (tester) async {
    // Real saves run to tens of KB; SharedPreferences and UserDefaults both
    // handle this, but prove it rather than assume it.
    final big = '{"version":7,"pad":"${'x' * 200000}"}';
    await plant(big);

    expect(await bridge.readLegacySave(), big);
  });
}
```

- [ ] **Step 2: Run on Android**

Run: `flutter test integration_test/legacy_save_bridge_test.dart -d <android-device-id>`
Expected: PASS (3 tests). Find the device id with `flutter devices`.

- [ ] **Step 3: Run on iOS**

Run: `flutter test integration_test/legacy_save_bridge_test.dart -d <ios-device-id>`
Expected: PASS (3 tests).

If iOS fails while Android passes, the prefix is the first thing to check — confirm the key against `Preferences.swift` in `../merge-empire-fc/node_modules/@capacitor/preferences/ios/Sources/PreferencesPlugin/Preferences.swift`.

- [ ] **Step 4: Commit**

```bash
git add integration_test/
git commit -m "test: prove the Capacitor save mirror is readable on device"
```

---

### Task 6: Real-save fixture from the source repo

**Files:**
- Create: `test/fixtures/default_save_v7.json`, `tool/dump_default_save.mjs`

**Interfaces:**
- Consumes: `../merge-empire-fc/src/state/stateSchema.js`.
- Produces: `test/fixtures/default_save_v7.json` — a real v7 save shape for Task 7 to round-trip.

- [ ] **Step 1: Write the dump script**

Create `tool/dump_default_save.mjs`:

```javascript
// Dumps a real default v7 save from the JS source so the Dart codec can be
// tested against the actual schema rather than a hand-written approximation.
import { writeFileSync } from 'node:fs';
import { createDefaultState } from '../../merge-empire-fc/src/state/stateSchema.js';

const state = createDefaultState();
writeFileSync(
  new URL('../test/fixtures/default_save_v7.json', import.meta.url),
  JSON.stringify(state, null, 2),
);
console.log('version:', state.version);
```

- [ ] **Step 2: Run it**

```bash
mkdir -p test/fixtures
node tool/dump_default_save.mjs
```

Expected: prints `version: 7` and writes the fixture.

If the import fails because `stateSchema.js` reaches for browser globals through its import chain (it imports `i18n/detect.js`, which may touch `navigator`), add a shim at the top of the script:

```javascript
globalThis.navigator ??= { language: 'en-GB', languages: ['en-GB'] };
globalThis.localStorage ??= {
  getItem: () => null, setItem: () => {}, removeItem: () => {},
};
```

- [ ] **Step 3: Verify the fixture is real**

Run: `node -e "const s=require('./test/fixtures/default_save_v7.json'); console.log(s.version, Object.keys(s).length, s.grid.cells.length)"`
Expected: `7`, a key count above 8, and a non-zero cell count.

- [ ] **Step 4: Commit**

```bash
git add tool/dump_default_save.mjs test/fixtures/default_save_v7.json
git commit -m "test: real v7 save fixture dumped from the JS schema"
```

---

### Task 7: Save codec — lossless round-trip

**Files:**
- Create: `lib/state/save_codec.dart`, `test/state/save_codec_test.dart`

**Interfaces:**
- Consumes: `test/fixtures/default_save_v7.json` from Task 6.
- Produces:
  - `class SaveCodec` with `static Map<String, dynamic>? decode(String raw)` — returns `null` on malformed JSON or a non-object root
  - `static String encode(Map<String, dynamic> save)`
  - `static bool isLossless(String raw)` — decode then encode, compare semantically

This proves the spec's hard constraint: cloud saves persist the whole state as a JSON string, so anything that survives a decode must survive the matching encode.

- [ ] **Step 1: Write the failing test**

Create `test/state/save_codec_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/save_codec.dart';

void main() {
  final fixture = File('test/fixtures/default_save_v7.json').readAsStringSync();

  test('decodes a real v7 save', () {
    final save = SaveCodec.decode(fixture);
    expect(save, isNotNull);
    expect(save!['version'], 7);
  });

  test('round-trips a real v7 save without losing anything', () {
    expect(SaveCodec.isLossless(fixture), isTrue);
  });

  test('preserves keys the model does not know about', () {
    final withUnknown = jsonEncode({
      ...SaveCodec.decode(fixture)!,
      'someFutureField': {'nested': true, 'n': 3},
    });

    final out = SaveCodec.decode(SaveCodec.encode(SaveCodec.decode(withUnknown)!))!;
    expect(out['someFutureField'], {'nested': true, 'n': 3});
  });

  test('preserves nulls inside sparse grid arrays', () {
    // grid.cells is fixed-length and sparse; dropping nulls would shift every
    // card's index and silently rearrange the player's grid.
    final save = SaveCodec.decode(fixture)!;
    final cells = (save['grid'] as Map<String, dynamic>)['cells'] as List;
    final out = SaveCodec.decode(SaveCodec.encode(save))!;
    final outCells = (out['grid'] as Map<String, dynamic>)['cells'] as List;

    expect(outCells.length, cells.length);
    expect(outCells, cells);
  });

  test('returns null on malformed JSON', () {
    expect(SaveCodec.decode('{"version":'), isNull);
  });

  test('returns null when the root is not an object', () {
    expect(SaveCodec.decode('[1,2,3]'), isNull);
  });

  test('returns null on an empty string', () {
    expect(SaveCodec.decode(''), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/state/save_codec_test.dart`
Expected: FAIL — `save_codec.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/state/save_codec.dart`:

```dart
import 'dart:convert';

/// Decodes and encodes the save JSON.
///
/// Cloud saves store the entire state as a JSON string, so a decode followed by
/// an encode must not lose a single field — including fields written by a newer
/// build than this one.
class SaveCodec {
  const SaveCodec._();

  /// Returns the save map, or null when [raw] is not a JSON object.
  static Map<String, dynamic>? decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String encode(Map<String, dynamic> save) => jsonEncode(save);

  /// True when decoding then encoding [raw] preserves every value.
  static bool isLossless(String raw) {
    final decoded = decode(raw);
    if (decoded == null) return false;
    return _deepEquals(decoded, decode(encode(decoded)));
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/state/save_codec_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/state/save_codec.dart test/state/save_codec_test.dart
git commit -m "feat: lossless save codec with unknown-key passthrough"
```

---

### Task 8: End-to-end migration probe

**Files:**
- Create: `integration_test/legacy_save_migration_test.dart`

**Interfaces:**
- Consumes: `LegacySaveBridge`, `SaveCodec`, `test/fixtures/default_save_v7.json`.
- Produces: on-device proof of the whole M0 thesis — a real save planted the Capacitor way is readable and round-trips losslessly.

- [ ] **Step 1: Register the fixture as an asset**

In `pubspec.yaml`, under `flutter:`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - test/fixtures/default_save_v7.json
```

Run: `flutter pub get`

- [ ] **Step 2: Write the integration test**

Create `integration_test/legacy_save_migration_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/services/legacy_save_bridge.dart';
import 'package:merge_empire_fc/state/save_codec.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a real v7 save survives the native store round-trip',
      (tester) async {
    final fixture =
        await rootBundle.loadString('test/fixtures/default_save_v7.json');

    await LegacySaveBridge.defaultChannel
        .invokeMethod<void>('writeLegacySaveForTest', {'value': fixture});

    final raw = await const LegacySaveBridge().readLegacySave();
    expect(raw, isNotNull);

    final save = SaveCodec.decode(raw!);
    expect(save, isNotNull);
    expect(save!['version'], 7);
    expect(SaveCodec.isLossless(raw), isTrue);

    await LegacySaveBridge.defaultChannel
        .invokeMethod<void>('writeLegacySaveForTest', {'value': null});
  });
}
```

- [ ] **Step 3: Run on both platforms**

Run: `flutter test integration_test/legacy_save_migration_test.dart -d <android-device-id>`
Expected: PASS

Run: `flutter test integration_test/legacy_save_migration_test.dart -d <ios-device-id>`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: end-to-end legacy save migration probe on device"
```

---

### Task 9: Card render and frame-budget probe

**Files:**
- Create: `lib/ui/widgets/probe_card.dart`, `test/ui/probe_card_test.dart`, `integration_test/card_perf_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class ProbeCard extends StatelessWidget` with `const ProbeCard({required String name, required int rating, required Color kitColor})`.

This is a *probe*, not the real card. Its job is to answer "does a grid of these hold 60fps", which is driver #1 in the spec. The real `Card` port happens in M2.

- [ ] **Step 1: Write the failing widget test**

Create `test/ui/probe_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_card.dart';

void main() {
  testWidgets('renders name and rating and retints to the kit colour',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProbeCard(name: 'Rookie', rating: 42, kitColor: Color(0xFF4CAF50)),
    ));

    expect(find.text('Rookie'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('probe-card-frame')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFF4CAF50));
  });

  testWidgets('is wrapped in a RepaintBoundary', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProbeCard(name: 'Rookie', rating: 42, kitColor: Color(0xFF4CAF50)),
    ));

    expect(
      find.descendant(
        of: find.byType(ProbeCard),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/probe_card_test.dart`
Expected: FAIL — `probe_card.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/ui/widgets/probe_card.dart`:

```dart
import 'package:flutter/material.dart';

/// A stand-in for the real player card, used to measure frame cost before the
/// full card port in M2. Every card gets its own RepaintBoundary so one card
/// animating does not repaint the whole grid.
class ProbeCard extends StatelessWidget {
  const ProbeCard({
    required this.name,
    required this.rating,
    required this.kitColor,
    super.key,
  });

  final String name;
  final int rating;
  final Color kitColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('probe-card-frame'),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: kitColor, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$rating', style: const TextStyle(fontSize: 20)),
            Text(name, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/probe_card_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Write the performance probe**

Create `integration_test/card_perf_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_card.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a scrolling grid of cards holds its frame budget',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.7,
          ),
          itemCount: 200,
          itemBuilder: (context, i) => ProbeCard(
            name: 'Player $i',
            rating: 40 + (i % 60),
            kitColor: const Color(0xFF4CAF50),
          ),
        ),
      ),
    ));

    await binding.traceAction(
      () async {
        for (var i = 0; i < 5; i++) {
          await tester.fling(find.byType(GridView), const Offset(0, -400), 3000);
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'card_grid_scroll',
    );
  });
}
```

- [ ] **Step 6: Run the performance probe on a real device**

Run: `flutter test integration_test/card_perf_test.dart -d <device-id> --profile`
Expected: PASS. Profile mode matters — debug-mode timings are meaningless.

Record the reported frame timings in the findings doc in Task 10. The bar to clear is a 60fps budget: average frame build under 16ms with no sustained jank.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/widgets/probe_card.dart test/ui/probe_card_test.dart integration_test/card_perf_test.dart
git commit -m "test: card render and frame-budget probe"
```

---

### Task 10: League diorama technique probe

**Files:**
- Create: `lib/ui/widgets/probe_diorama.dart`, `test/ui/probe_diorama_test.dart`, `integration_test/diorama_perf_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class ProbeDiorama extends StatefulWidget` with `const ProbeDiorama({required bool usePainter, int rainDrops = 60})`
  - `class DioramaPainter extends CustomPainter` with `DioramaPainter({required double t, required int rainDrops})`

This task retires Risk 1. `league-scene.css` runs **103 `@keyframes`** concurrently: parallax layers (`psScrollFar`, `psScrollGround`, `psScrollBoards`), a day/night cycle (`psDayNight`), six weather systems (rain, snow, fog, gusts, lightning, sun), crowd motion (`psScarfSway`, `psFlagWave`, `psFanCheer`), drifting clouds, a mowing groundskeeper, and an articulated walker with separate near/far thigh, shin and arm animations (`psvThighN/F`, `psvShinN/F`, `psvArmN/F`).

The open question is not *whether* Flutter can draw this, but *which technique* M3 should commit to: a widget tree of individually-animated children, or one `CustomPainter` driven by a single ticker. The probe builds both and measures them.

- [ ] **Step 1: Write the failing widget test**

Create `test/ui/probe_diorama_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_diorama.dart';

void main() {
  testWidgets('painter mode renders a CustomPaint', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProbeDiorama(usePainter: true),
    ));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.descendant(
        of: find.byType(ProbeDiorama),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('widget mode renders one child per rain drop', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProbeDiorama(usePainter: false, rainDrops: 12),
    ));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const ValueKey('rain-drop')), findsNWidgets(12));
  });

  testWidgets('the painter repaints as time advances', (tester) async {
    const a = DioramaPainter(t: 0, rainDrops: 4);
    const b = DioramaPainter(t: 0.5, rainDrops: 4);

    expect(a.shouldRepaint(b), isTrue);
    expect(a.shouldRepaint(a), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/probe_diorama_test.dart`
Expected: FAIL — `probe_diorama.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/ui/widgets/probe_diorama.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Probe for the League diorama. Renders a representative slice of the scene —
/// three parallax bands, a day/night tint, and a rain system — two ways, so M3
/// can pick a technique on measured evidence rather than preference.
class ProbeDiorama extends StatefulWidget {
  const ProbeDiorama({
    required this.usePainter,
    this.rainDrops = 60,
    super.key,
  });

  final bool usePainter;
  final int rainDrops;

  @override
  State<ProbeDiorama> createState() => _ProbeDioramaState();
}

class _ProbeDioramaState extends State<ProbeDiorama>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return widget.usePainter
            ? CustomPaint(
                painter: DioramaPainter(t: t, rainDrops: widget.rainDrops),
                child: const SizedBox.expand(),
              )
            : _WidgetTreeScene(t: t, rainDrops: widget.rainDrops);
      },
    );
  }
}

/// One painter, one ticker, no per-element widgets.
class DioramaPainter extends CustomPainter {
  const DioramaPainter({required this.t, required this.rainDrops});

  final double t;
  final int rainDrops;

  @override
  void paint(Canvas canvas, Size size) {
    // Day/night tint.
    final night = (math.sin(t * 2 * math.pi) + 1) / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(
        const Color(0xFF87CEEB), const Color(0xFF12203A), night)!,
    );

    // Three parallax bands at different rates.
    for (var band = 0; band < 3; band++) {
      final rate = 0.25 * (band + 1);
      final y = size.height * (0.45 + band * 0.16);
      final offset = (t * rate * size.width) % size.width;
      final paint = Paint()
        ..color = Colors.black.withValues(alpha: 0.12 + band * 0.1);
      for (var x = -size.width; x < size.width * 2; x += 64) {
        canvas.drawRect(Rect.fromLTWH(x + offset, y, 40, 18), paint);
      }
    }

    // Rain.
    final drop = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    for (var i = 0; i < rainDrops; i++) {
      final seed = i / rainDrops;
      final x = seed * size.width;
      final y = ((t + seed) % 1) * size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + 12), drop);
    }
  }

  @override
  bool shouldRepaint(DioramaPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.rainDrops != rainDrops;
}

/// The same scene as a widget tree — one widget per rain drop, which is the
/// structural equivalent of the current DOM approach.
class _WidgetTreeScene extends StatelessWidget {
  const _WidgetTreeScene({required this.t, required this.rainDrops});

  final double t;
  final int rainDrops;

  @override
  Widget build(BuildContext context) {
    final night = (math.sin(t * 2 * math.pi) + 1) / 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Color.lerp(
                  const Color(0xFF87CEEB), const Color(0xFF12203A), night)!,
              ),
            ),
            for (var i = 0; i < rainDrops; i++)
              Positioned(
                key: const ValueKey('rain-drop'),
                left: (i / rainDrops) * w,
                top: ((t + i / rainDrops) % 1) * h,
                child: Container(
                  width: 2,
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/probe_diorama_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Write the comparative performance probe**

Create `integration_test/diorama_perf_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_diorama.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> run(WidgetTester tester, {required bool usePainter}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProbeDiorama(usePainter: usePainter, rainDrops: 120)),
    ));

    await binding.traceAction(
      () async {
        // Four seconds of continuous animation, which is one full cycle.
        for (var i = 0; i < 240; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
      reportKey: usePainter ? 'diorama_painter' : 'diorama_widgets',
    );
  }

  testWidgets('CustomPainter diorama holds its frame budget', (tester) async {
    await run(tester, usePainter: true);
  });

  testWidgets('widget-tree diorama holds its frame budget', (tester) async {
    await run(tester, usePainter: false);
  });
}
```

- [ ] **Step 6: Run both on a real device in profile mode**

Run: `flutter test integration_test/diorama_perf_test.dart -d <device-id> --profile`
Expected: PASS. Record both `diorama_painter` and `diorama_widgets` timings.

The comparison is the deliverable. If the painter is materially cheaper, M3 commits to `CustomPainter` for the diorama and match scenes. If they are comparable, M3 may prefer the widget tree for maintainability. Record the actual numbers either way — this decision governs ~15k lines of M3 work.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/widgets/probe_diorama.dart test/ui/probe_diorama_test.dart integration_test/diorama_perf_test.dart
git commit -m "test: league diorama technique probe, painter vs widget tree"
```

---

### Task 11: M0 findings and go/no-go

**Files:**
- Create: `docs/superpowers/specs/2026-08-17-m0-findings.md`
- Modify: `docs/superpowers/specs/2026-08-17-flutter-port-design.md`

**Interfaces:**
- Consumes: results from Tasks 5, 8, 9 and 10.
- Produces: a written record of what M0 proved, and any spec amendments M1 must respect.

- [ ] **Step 1: Write the findings document**

Create `docs/superpowers/specs/2026-08-17-m0-findings.md` using this structure, replacing every bracket with a measured value — no prose in place of numbers:

```markdown
# M0 Findings

**Date:** [date run]
**Devices:** Android [model, OS] · iOS [model, OS]

## Save bridge

| Check | Android | iOS |
|---|---|---|
| Reads planted Capacitor save | [pass/fail] | [pass/fail] |
| Returns null when absent | [pass/fail] | [pass/fail] |
| 200KB payload survives | [pass/fail] | [pass/fail] |
| Real v7 fixture round-trips lossless | [pass/fail] | [pass/fail] |

iOS key prefix `CapacitorStorage.` required: [yes/no]
Android key unprefixed in file `CapacitorStorage`: [yes/no]

## Card grid frame budget

| Metric | Value |
|---|---|
| Average frame build | [x] ms |
| Worst frame | [x] ms |
| Frames over 16ms | [n] of [total] |
| Verdict vs 60fps budget | [pass/fail] |

## Diorama technique

| Approach | Avg frame build | Worst frame | Frames over 16ms |
|---|---|---|---|
| CustomPainter | [x] ms | [x] ms | [n] |
| Widget tree | [x] ms | [x] ms | [n] |

**Decision for M3:** [CustomPainter / widget tree / mixed], because [reason].

## Spec deviations

[List anything M0 contradicted, or "none".]

## Go/no-go for M1

[Go or no-go, and what must change if no-go.]
```

- [ ] **Step 2: Amend the spec if M0 contradicted it**

If any finding contradicts the design doc, update the design doc in the same commit and note the change in the findings document. Risk 2 in the spec should be marked retired if Tasks 5 and 8 passed on both platforms.

- [ ] **Step 3: Verify the full suite and coverage**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test --coverage`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add docs/
git commit -m "docs: M0 findings and go/no-go for M1"
```

---

## Definition of Done

M0 is complete when all of the following hold:

- `flutter analyze` reports no issues.
- `flutter test` passes, including the codec, bridge and widget tests.
- `flutter test integration_test/` passes on a real Android device **and** a real iOS device.
- A real v7 save planted the Capacitor way is proven readable and lossless on both platforms.
- Frame timings from the card probe are recorded, with a verdict against the 60fps budget.
- Both diorama techniques are measured and a technique is chosen for M3, with the numbers recorded.
- The findings document exists, and the spec's Risk 1 and Risk 2 are each either retired or replaced with what was actually found.

## What M0 deliberately does not do

No engines, no game data, no real UI, no Firebase, no Riverpod wiring beyond the dependency. Those are M1 and M2. M0 exists only to retire the two risks that would invalidate the design if they turned out badly: whether the legacy save is reachable from Dart at all (Risk 2), and whether the diorama can be drawn at frame budget and by which technique (Risk 1).

The two probe widgets (`ProbeCard`, `ProbeDiorama`) are throwaway measurement rigs, not the beginnings of the real UI. M2 and M3 build the real thing; these get deleted.
