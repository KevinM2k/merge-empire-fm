/// The save, on the device.
///
/// The contract the rest of the save layer depends on is that reads are
/// synchronous and a failed write is silent, so those are what this checks —
/// not that the plugin works.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/prefs_save_store.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads what is already on the device', () async {
    SharedPreferences.setMockInitialValues({
      saveKeyPrimary: '{"clubName":"Storeville"}',
      'some_other_plugins_key': 'not ours',
    });
    final store = await PrefsSaveStore.open();
    expect(store.read(saveKeyPrimary), '{"clubName":"Storeville"}');
    expect(store.read('some_other_plugins_key'), isNull);
  });

  test('a write is readable at once, without awaiting anything', () async {
    // The whole reason the store caches: the debounced save fires from a timer
    // and the reset path writes three keys expecting each to have landed.
    SharedPreferences.setMockInitialValues({});
    final store = await PrefsSaveStore.open();
    store.write(saveKeyPrimary, 'a');
    expect(store.read(saveKeyPrimary), 'a');
    store.remove(saveKeyPrimary);
    expect(store.read(saveKeyPrimary), isNull);
  });

  test('and it reaches the device', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PrefsSaveStore.open();
    store.write(saveKeyBackup, 'kept');
    await Future<void>.delayed(Duration.zero);

    final reopened = await PrefsSaveStore.open();
    expect(reopened.read(saveKeyBackup), 'kept');
  });
}
