/// The release build is signed with a RELEASE key, or it says so out loud.
///
/// **It was signed with the debug key**, which is `flutter create`'s default and
/// shipped in the port behind a TODO. That is not a console task waiting its
/// turn: Play REFUSES a debug-signed artifact at upload, and the signing
/// identity is the one property of an Android app that cannot be corrected
/// afterwards — a different key is a different app, with no upgrade path for
/// anybody who has the live one installed.
///
/// **What can be checked from here, and what cannot.** There is no Android SDK
/// in a cloud container, so nothing here runs Gradle; what this asserts is the
/// SHAPE of the config, which is exactly the part that was wrong. The keystore
/// itself is correctly absent — `android/.gitignore` carries `key.properties`
/// and `**/*.keystore`, and a signing key in a repository is a worse bug than
/// an unsigned build.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('THE RELEASE BUILD IS NOT UNCONDITIONALLY DEBUG-SIGNED', () {
    // The exact line that shipped, and the TODO that excused it.
    expect(
      gradle,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")\n')),
      reason: 'the release build is signed with the debug key',
    );
    expect(
      gradle,
      isNot(contains('TODO: Add your own signing config')),
      reason: "flutter create's TODO is still in the file",
    );
  });

  test('and it reads the key from a file that is NOT in the repository', () {
    // `key.properties` is the Flutter-documented location and is git-ignored.
    expect(gradle, contains('key.properties'));
    expect(gradle, contains('signingConfigs'));
    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, contains('key.properties'));
    expect(
      Directory('android').listSync(recursive: true).any(
        (f) => f.path.endsWith('key.properties') || f.path.endsWith('.keystore'),
      ),
      isFalse,
      reason: 'a signing key is committed',
    );
  });

  test('AND A BUILD WITHOUT THE KEY SAYS SO, rather than shipping quietly', () {
    // The fallback is what keeps `flutter run --release` working on a machine
    // that has never seen the key, and it is the only risk in the change — so
    // it has to be loud. A silent fallback is how a debug-signed artifact
    // reaches the upload step instead of the build log.
    expect(gradle, contains('logger.warn'));
    expect(gradle, contains('cannot be '));
  });
}
