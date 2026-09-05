/// What the reminders need from the native config, checked against the config
/// itself rather than a constant.
///
/// **Both of these had shipped wrong, and neither said a word.** The plugin's
/// `initialize` resolves its icon with `getIdentifier(name, "drawable", pkg)`
/// and the app passed `ic_launcher`, which lives in `mipmap/` — so it answered
/// with a `PlatformException`, every later call died in a `catch` that reports
/// nothing, and `permissionGranted` answers TRUE when it cannot ask, so the
/// Android 13 prompt was never raised either. Nothing was armed on a device.
///
/// And from v19 the plugin declares NOTHING in its own manifest, so the
/// receiver a scheduled alarm fires into is the app's to carry. Without it the
/// alarm has nowhere to land.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/notifications.dart';

void main() {
  test('the small icon is a DRAWABLE, which is where the plugin looks', () {
    final drawables = Directory('android/app/src/main/res')
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.split('/').last.startsWith('drawable'));
    final found = drawables.any(
      (d) => d.listSync().whereType<File>().any(
        (f) => f.path.split('/').last.split('.').first == noticeIconRes,
      ),
    );
    expect(found, isTrue, reason: '$noticeIconRes is not in any drawable/');
  });

  test('and the shrinker is told to keep it — a RELEASE-only failure', () {
    // Nothing references the icon but a runtime name lookup, so R8 stripped it
    // from the APK and left every debug build working.
    expect(
      File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
      contains('@drawable/$noticeIconRes'),
    );
  });

  test('the manifest carries what a SCHEDULED notification needs', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('android.permission.RECEIVE_BOOT_COMPLETED'),
      reason: 'nothing reschedules the four after a reboot',
    );
    for (final receiver in [
      'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
      'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
    ]) {
      expect(manifest, contains(receiver));
    }
  });
}
