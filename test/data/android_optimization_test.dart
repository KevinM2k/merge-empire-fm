/// The release build is OPTIMISED, SHRUNK and OBFUSCATED — and says so itself.
///
/// **Play grades an uploaded artifact on it.** From February 2027 a category
/// under 25% — optimisation, shrinking or obfuscation of the DEX — costs
/// visibility and publishing capability, and the console reports it against a
/// release that has already shipped rather than against a build you can still
/// change. That is the same shape as the debug-signing and versionCode faults
/// in `docs/RELEASE.md`: a console-only failure whose cause is one line of
/// Gradle.
///
/// **The port was never actually broken here — it was UNSTATED**, which is the
/// thing this file changes. Flutter 3.44.9's `FlutterPlugin.kt` turns R8 on for
/// the release build type by itself, so the artifact was obfuscated; but
/// nothing in this repository said so, no test held it, and `--no-shrink` reads
/// like a switch that would turn it off (its own help text says it has no
/// effect). A property the project depends on and does not assert is a property
/// the next toolchain bump is free to take away.
///
/// **What can be checked from here, and what cannot.** There is no Android SDK
/// in a cloud container, so nothing here runs Gradle or R8 — this asserts the
/// SHAPE of the config, and the release workflow measures the built artifact.
/// Neither is Play's own figure: Play does not publish its algorithm.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Play's bar, in every category, from February 2027.
const int _playThresholdPercent = 25;

/// `FlutterPlugin.kt` out of the pinned toolchain, or null when there is none
/// on PATH — the same read `android_sdk_levels_test` does of `FlutterExtension`.
String? _flutterGradlePlugin() {
  final root = Platform.environment['FLUTTER_ROOT'] ?? _rootFromPath();
  final file = File(
    '$root/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt',
  );
  return file.existsSync() ? file.readAsStringSync() : null;
}

String _rootFromPath() {
  final exe = Platform.resolvedExecutable;
  final at = exe.indexOf('/bin/cache/dart-sdk');
  return at < 0 ? '' : exe.substring(0, at);
}

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('THE RELEASE BUILD TYPE ASKS FOR R8 ITSELF', () {
    // Inherited from the toolchain is not the same as configured, and only one
    // of the two survives a toolchain that changes its mind.
    expect(gradle, contains('isMinifyEnabled = true'));
    expect(gradle, contains('isShrinkResources = true'));
    expect(gradle, isNot(contains('isMinifyEnabled = false')));
    expect(gradle, isNot(contains('isShrinkResources = false')));
  });

  test('and the toolchain has not stopped enabling it either', () {
    // If a future Flutter drops the default, the two lines above are the whole
    // of the port's obfuscation rather than a restatement of it — which is
    // fine, and is worth knowing when it happens rather than after an upload.
    final plugin = _flutterGradlePlugin();
    if (plugin == null) return; // no toolchain to read; nothing to assert
    expect(
      plugin,
      contains('isMinifyEnabled = true'),
      reason: 'the pinned Flutter no longer turns R8 on by default',
    );
  });

  test('DEFERRED COMPONENTS ARE NOT DECLARED — they turn shrinking OFF', () {
    // `flutter_tools`' own `gradle.dart` passes `-Pshrink=false` for a
    // multi-apk build, and prints it as a yellow STATUS line rather than a
    // warning. That is the one route by which this project stops obfuscating
    // without anybody editing a Gradle file, so it is held from pubspec.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      isNot(contains('deferred-components')),
      reason: 'deferred components disable shrinking for the whole build',
    );
  });

  test('and R8 full mode is not switched off', () {
    // Default-on since AGP 8.0 and this project is on 8.11.1, so the only way
    // to lose it is to write the opt-out into gradle.properties.
    final props = File('android/gradle.properties').readAsStringSync();
    expect(props, isNot(contains('android.enableR8.fullMode=false')));
  });

  test('and no keep file quietly opts out of renaming', () {
    // The Flutter plugin adds `android/app/proguard-rules.pro` to
    // `proguardFiles` when it exists, so a file dropped there is live without
    // any wiring — and `-dontobfuscate` in it would answer the console warning
    // with the opposite of the fix.
    final keeps = File('android/app/proguard-rules.pro');
    if (!keeps.existsSync()) return;
    expect(keeps.readAsStringSync(), isNot(contains('-dontobfuscate')));
  });

  test('AND THE RELEASE BUILD MEASURES WHAT IT ACTUALLY PRODUCED', () {
    // Config asserted from Dart is a claim about the build. The workflow reads
    // the DEX out of the APK it just built and counts the renamed classes, so
    // an R8 that was configured and did not run fails the release rather than
    // the console.
    final workflow = File(
      '.github/workflows/build-release.yml',
    ).readAsStringSync();
    expect(workflow, contains('Measure DEX obfuscation'));
    expect(workflow, contains('PLAY_THRESHOLD = $_playThresholdPercent.0'));
    expect(
      workflow,
      isNot(contains('--no-shrink')),
      reason: 'a flag whose help text says it has no effect, read as if it did',
    );
  });
}
