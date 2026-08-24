/// The version the stores will accept.
///
/// **Play refuses an upload whose versionCode is not higher than the live
/// one**, and the App Store does the same for `CFBundleVersion` — so the
/// `1.0.0+1` that `flutter create` writes could not have been uploaded at all.
/// It fails in a console, months after the code was written, which is exactly
/// the shape of failure this repo pins rather than discovers.
///
/// **The live figure is recorded here rather than read**, because
/// `../merge-empire-fc` is a separate repo and is not cloned in a cloud
/// container — the same reason `legacy_save_bridge_keys_test` carries its
/// string pair. Update it when the old build ships again.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';

/// `../merge-empire-fc/android/app/build.gradle`, at the time of the port.
const int shippedVersionCode = 10112;
const String shippedVersionName = '1.1.12';

/// The scheme the shipped app uses: major×10000 + minor×100 + patch.
int codeFor(String name) {
  final parts = name.split('.').map(int.parse).toList();
  return parts[0] * 10000 + parts[1] * 100 + parts[2];
}

void main() {
  late String name;
  late int code;

  setUpAll(() {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final value = line.split(':')[1].trim();
    name = value.split('+').first;
    code = int.parse(value.split('+').last);
  });

  test('THE BUILD NUMBER IS ABOVE THE LIVE ONE', () {
    // Not equal: Play refuses that too. An update the store will not take is
    // an update nobody gets, reported as a smaller device count rather than as
    // an error.
    expect(
      code,
      greaterThan(shippedVersionCode),
      reason: 'Play would refuse this upload',
    );
  });

  test('and the name is not a DOWNGRADE in the listing', () {
    expect(
      codeFor(name),
      greaterThan(codeFor(shippedVersionName)),
      reason: 'the store page would show a lower version than is installed',
    );
  });

  test('the two agree, on the shipped app\'s own scheme', () {
    // major×10000 + minor×100 + patch. They can drift apart silently — one is
    // what the store sorts by and the other is what a player reads — and a
    // build number that does not follow the name is how a hotfix ends up
    // sorting below the release it fixes.
    expect(code, codeFor(name));
  });

  test('the DART constant matches, because the footer prints it', () {
    // `appVersion` is hand-kept — there is no runtime read of pubspec without a
    // plugin — so it is the one link in the chain that can drift silently.
    expect(appVersion, name);
  });

  group('THE NATIVE CONFIGS DERIVE IT, rather than carrying their own', () {
    // A hardcoded number here is the worst version bug available: the build
    // succeeds, the binary is fine, and the upload is refused — or accepted
    // under a version nobody meant. Both platforms have a variable that Flutter
    // fills from pubspec, and the only correct answer is to use it.

    test('Android reads flutter.versionCode', () {
      final gradle = File('android/app/build.gradle.kts').existsSync()
          ? File('android/app/build.gradle.kts').readAsStringSync()
          : File('android/app/build.gradle').readAsStringSync();
      expect(gradle, contains('flutter.versionCode'));
      expect(gradle, contains('flutter.versionName'));
    });

    test('and the iOS plist reads FLUTTER_BUILD_NAME/NUMBER', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      // CFBundleShortVersionString is the one on the store page and
      // CFBundleVersion is the one the store sorts by; neither may be a
      // literal. The RunnerTests bundle DOES carry its own and that is fine —
      // it is never uploaded.
      expect(plist, contains(r'$(FLUTTER_BUILD_NAME)'));
      expect(plist, contains(r'$(FLUTTER_BUILD_NUMBER)'));
    });
  });

  test('the recorded live figures are consistent with each other', () {
    // A guard on the constants above rather than on the port: if somebody
    // updates one and not the other, this says so.
    expect(shippedVersionCode, codeFor(shippedVersionName));
  });
}
