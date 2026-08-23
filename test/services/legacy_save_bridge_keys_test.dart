/// The keys the migration path hangs off.
///
/// **This is the highest-stakes string pair in the port.** It is the only local
/// route an existing player's save has into the Flutter build: the primary save
/// lives in the WebView's localStorage, which Dart cannot reach at all, and
/// `nativeSaveMirror.js` writing a copy to the native store is what makes a
/// migration possible. One character wrong and every installed player opens the
/// new build to a fresh save — no crash, no error, no way back.
///
/// So the two ends are pinned against the shipped app rather than trusted:
///
/// - The KEY is `NATIVE_SAVE_KEY` in `src/services/nativeSaveMirror.js`.
/// - **iOS carries a prefix and Android does not**, which is not a port
///   decision either: `@capacitor/preferences`'s own `Preferences.swift`
///   prefixes every UserDefaults key with its group name, and the group
///   defaults to `CapacitorStorage`. Android's SharedPreferences plugin stores
///   the key bare. Getting that asymmetry the other way round reads a key that
///   has never existed.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/legacy_save_bridge.dart';

/// `NATIVE_SAVE_KEY`, from the shipped app.
const String _mirrorKey = 'mergeEmpireFC_save_native';

/// `@capacitor/preferences` groups iOS keys; the default group is this.
const String _iosPrefix = 'CapacitorStorage.';

void main() {
  test('ANDROID READS THE BARE KEY', () {
    final activity = File(
      'android/app/src/main/kotlin/com/mergeempirefc/app/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('"$_mirrorKey"'));
    expect(
      activity,
      isNot(contains(_iosPrefix)),
      reason: 'Android stores it bare — the prefix is an iOS plugin detail',
    );
  });

  test('AND iOS READS THE PREFIXED ONE', () {
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      contains('"$_iosPrefix$_mirrorKey"'),
    );
  });

  test('both sides answer on the SAME channel, and it is namespaced', () {
    // A channel name is matched string-for-string across the platform boundary;
    // a mismatch is a `MissingPluginException`, which the bridge swallows as
    // "no legacy save" — the same answer as a genuinely new player.
    const channel = 'com.mergeempirefc.app/legacy_save';
    expect(LegacySaveBridge.defaultChannel.name, channel);
    expect(
      File(
        'android/app/src/main/kotlin/com/mergeempirefc/app/MainActivity.kt',
      ).readAsStringSync(),
      contains('"$channel"'),
    );
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      contains('"$channel"'),
    );
  });
}
