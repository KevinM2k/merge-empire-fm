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

  testWidgets('reads a save planted in the Capacitor native store', (
    tester,
  ) async {
    const payload = '{"version":7,"resources":{"fanCoins":1234}}';
    await plant(payload);

    expect(await bridge.readLegacySave(), payload);
  });

  testWidgets('returns null when the native store has no save', (tester) async {
    await plant(null);

    expect(await bridge.readLegacySave(), isNull);
  });

  testWidgets('survives a payload the size of a real late-game save', (
    tester,
  ) async {
    // Real saves run to tens of KB; SharedPreferences and UserDefaults both
    // handle this, but prove it rather than assume it.
    final big = '{"version":7,"pad":"${'x' * 200000}"}';
    await plant(big);

    expect(await bridge.readLegacySave(), big);
  });
}
