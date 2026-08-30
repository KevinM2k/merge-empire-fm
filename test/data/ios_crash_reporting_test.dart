/// **iOS had no crash reporting and no analytics at all**, and both halves of
/// that failed the way this repo's notes keep warning about: silently.
///
/// `analytics_service.dart` calls `Firebase.initializeApp()` with no options,
/// so on iOS the native SDK reads `GoogleService-Info.plist` **out of the app
/// bundle**. The plist was on disk in `ios/Runner/` and was never in the Xcode
/// project — no file reference, nothing in the Resources phase — so it was
/// never copied into the bundle, `configure` found no project, and
/// `startAnalytics`'s own `catch (_)` returned. No crash, no log line, no
/// events: exactly the failure the JS's comment records on the other platform.
///
/// The second half only matters once the first is fixed. Crashlytics symbolises
/// an iOS report from the dSYM, which **nothing uploads by default** — the
/// reports arrive as hex addresses. That is the M7 row "watch for
/// save-migration failures in Crashlytics" quietly not working: the reports
/// would be there and unreadable.
///
/// **What can be checked from here.** There is no Mac in a cloud container, so
/// nothing here builds the project; what this asserts is the SHAPE of the
/// Xcode config, which is the part that was wrong — the same bargain
/// `android_signing_test` makes about Gradle. The plist itself is correctly
/// absent: it is git-ignored, and this asserts the reference, never the file.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  /// The `buildPhases = ( ... )` list of the Runner application target, in
  /// order. Xcode writes each entry as `<id> /* <name> */`, and the order is
  /// the whole point of two of these assertions.
  List<String> runnerPhases() {
    final target = pbx.indexOf('97C146ED1CF9000F007C117D /* Runner */ = {');
    final open = pbx.indexOf('buildPhases = (', target);
    final list = pbx.substring(open, pbx.indexOf(');', open));
    return RegExp(r'/\* (.+?) \*/')
        .allMatches(list)
        .map((m) => m.group(1)!)
        .toList();
  }

  group('the Firebase project reaches the app', () {
    test('GoogleService-Info.plist IS COPIED INTO THE BUNDLE', () {
      // Both halves are needed and only one of them is visible in Xcode's
      // navigator, which is how this stayed missing: a file reference alone
      // lists the plist in the project and still ships a bundle without it.
      expect(
        pbx,
        contains('/* GoogleService-Info.plist */ = {isa = PBXFileReference;'),
        reason: 'the plist is not in the Xcode project at all',
      );
      expect(
        pbx,
        contains('/* GoogleService-Info.plist in Resources */'),
        reason: 'the plist is referenced but never copied into the bundle',
      );
      final resources = pbx.substring(
        pbx.indexOf('97C146EC1CF9000F007C117D /* Resources */ = {'),
      );
      expect(
        resources.substring(0, resources.indexOf('};')),
        contains('GoogleService-Info.plist in Resources'),
        reason: "it is in some other target's Resources phase, not Runner's",
      );
    });

    test('and the plist itself is NOT committed', () {
      // It carries the live project's own keys, and the repo has decided that
      // question already — this only ever asserts the reference.
      expect(
        File('.gitignore').readAsStringSync(),
        contains('GoogleService-Info.plist'),
      );
    });
  });

  group('AND A CRASH REPORT CAN BE READ WHEN IT ARRIVES', () {
    test('the dSYM upload phase exists and runs Firebase\'s own script', () {
      expect(
        pbx,
        contains('name = "[firebase_crashlytics] Upload dSYMs"'),
        reason: 'nothing uploads the dSYM, so every iOS report is hex',
      );
      expect(pbx, contains(r'${PODS_ROOT}/FirebaseCrashlytics/run'));
      expect(
        pbx,
        contains(r'${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}'),
        reason: 'the phase declares no dSYM input',
      );
    });

    test('IT IS IN THE RUNNER TARGET, AFTER Thin Binary', () {
      // Order is not cosmetic. `Thin Binary` is where Flutter's own
      // `xcode_backend.sh embed_and_thin` puts the engine and the app's dSYM
      // in place; a phase that runs before it uploads whatever the last build
      // left behind, which is the worst kind of green.
      final phases = runnerPhases();
      expect(phases, contains('[firebase_crashlytics] Upload dSYMs'));
      expect(
        phases.indexOf('[firebase_crashlytics] Upload dSYMs'),
        greaterThan(phases.indexOf('Thin Binary')),
      );
    });

    test('and Release BUILDS a dSYM for it to upload', () {
      // A phase uploading nothing looks identical in the log to one that
      // worked. Debug is deliberately left at `dwarf` — there is nothing to
      // symbolise for a build nobody ships — and Firebase's script no-ops
      // there of its own accord.
      final block = RegExp(
        r'isa = XCBuildConfiguration;(.*?)\n\t\t\};',
        dotAll: true,
      );
      final configs = block
          .allMatches(pbx)
          .map((m) => m.group(1)!)
          .where(
            (c) =>
                c.contains('name = Release;') &&
                c.contains('DEBUG_INFORMATION_FORMAT'),
          );
      expect(configs, isNotEmpty, reason: 'no Release config sets the format');
      for (final config in configs) {
        expect(
          config,
          contains('DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"'),
        );
      }
    });

    test('AND A CHECKOUT WITH NO PODS WARNS rather than failing the build', () {
      // Same bargain as the Android signing fallback: the risky path is the
      // quiet one, so it is the one that has to be loud.
      expect(pbx, contains('warning: '));
      expect(pbx, contains('unsymbolicated'));
      expect(pbx, contains(r'exit 0'));
    });
  });
}
