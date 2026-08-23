/// The identifiers the stores hold this app under.
///
/// **These are primary keys, not names.** `com.mergeempirefc.app` is what Play
/// Console and App Store Connect have an already-published app filed under, and
/// the AdMob app ids are what let a build serve at all. A Flutter port that
/// picks its own — which is what `flutter create` does — is a second app: new
/// listing, no reviews, no installs, and every existing player stranded.
///
/// Read straight out of the native config rather than a constant, because the
/// native config is what actually ships.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shipped app's, from `../merge-empire-fc/capacitor.config.ts`.
const String _appId = 'com.mergeempirefc.app';
const String _admobAndroid = 'ca-app-pub-0386196346828968~9406473537';
const String _admobIos = 'ca-app-pub-0386196346828968~3098217491';

void main() {
  test('ANDROID SHIPS UNDER THE PUBLISHED APPLICATION ID', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "$_appId"'));
    expect(gradle, contains('namespace = "$_appId"'));
  });

  test('AND iOS UNDER THE PUBLISHED BUNDLE ID', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = $_appId;'));
  });

  test('the AdMob APP ids are the shipped ones, per platform', () {
    // Not the unit ids — the APP id, which is what the SDK refuses to start
    // without. Wrong here and nothing serves at all.
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains(_admobAndroid),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains(_admobIos),
    );
  });

  test('AND THE TWO PLATFORMS DO NOT SHARE ONE', () {
    expect(_admobAndroid, isNot(_admobIos));
  });
}
