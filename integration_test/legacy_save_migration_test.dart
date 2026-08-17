import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/services/legacy_save_bridge.dart';
import 'package:merge_empire_fc/state/save_codec.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a real v7 save survives the native store round-trip', (
    tester,
  ) async {
    final fixture = await rootBundle.loadString(
      'test/fixtures/default_save_v7.json',
    );

    await LegacySaveBridge.defaultChannel.invokeMethod<void>(
      'writeLegacySaveForTest',
      {'value': fixture},
    );

    final raw = await const LegacySaveBridge().readLegacySave();
    expect(raw, isNotNull);

    final save = SaveCodec.decode(raw!);
    expect(save, isNotNull);
    expect(save!['version'], 7);
    expect(SaveCodec.isLossless(raw), isTrue);

    await LegacySaveBridge.defaultChannel.invokeMethod<void>(
      'writeLegacySaveForTest',
      {'value': null},
    );
  });
}
