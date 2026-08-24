/// The Android SDK levels the update has to be installable on.
///
/// **minSdk is the one that can strand players.** An update whose minSdk is
/// HIGHER than the shipped app's is not offered to the devices below it — those
/// players keep the Capacitor build for ever and never see the port, and Play
/// reports it as a reduced device count rather than as an error. The shipped
/// app is 24, from `android/variables.gradle`, so the port may go lower and
/// must never go higher.
///
/// targetSdk moves the other way: Play REQUIRES a recent one to accept an
/// upload at all, so higher is the safe direction and matching the old build
/// would eventually be rejected.
///
/// Both are read out of the Flutter toolchain's own defaults, which is what
/// `flutter.minSdkVersion` resolves to — the point of this test is that the
/// project takes those defaults, so a toolchain bump that raises minSdk past
/// the shipped app's is caught here rather than in the console.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `android/variables.gradle` in the shipped app.
const int _shippedMinSdk = 24;
const int _shippedTargetSdk = 35;

int _flutterDefault(String field) {
  final root = Platform.environment['FLUTTER_ROOT'] ?? _rootFromPath();
  final file = File(
    '$root/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt',
  );
  if (!file.existsSync()) return -1;
  final match = RegExp(
    'val $field: Int = (\\d+)',
  ).firstMatch(file.readAsStringSync());
  return match == null ? -1 : int.parse(match.group(1)!);
}

String _rootFromPath() {
  final exe = Platform.resolvedExecutable;
  final at = exe.indexOf('/bin/cache/dart-sdk');
  return at < 0 ? '' : exe.substring(0, at);
}

void main() {
  test('THE PROJECT TAKES THE TOOLCHAIN\'S LEVELS, not hand-typed ones', () {
    // Hand-typing them is how a project quietly stops tracking the toolchain,
    // and the levels are exactly the thing a toolchain bump is allowed to move.
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('minSdk = flutter.minSdkVersion'));
    expect(gradle, contains('targetSdk = flutter.targetSdkVersion'));
    expect(gradle, contains('compileSdk = flutter.compileSdkVersion'));
  });

  test('AND minSdk NEVER RISES ABOVE THE SHIPPED APP\'S', () {
    // Higher and the update is not offered to the devices below it: those
    // players keep the Capacitor build for ever, and Play reports it as a
    // smaller device count rather than as an error.
    final min = _flutterDefault('minSdkVersion');
    if (min < 0) return; // no toolchain to read; nothing to assert against
    expect(
      min,
      lessThanOrEqualTo(_shippedMinSdk),
      reason: 'the port would strand every device below API $min',
    );
  });

  test('and targetSdk is at least the shipped one', () {
    // Play requires a recent target to accept an upload at all, so higher is
    // the safe direction here — the opposite of minSdk.
    final target = _flutterDefault('targetSdkVersion');
    if (target < 0) return;
    expect(target, greaterThanOrEqualTo(_shippedTargetSdk));
  });
}
