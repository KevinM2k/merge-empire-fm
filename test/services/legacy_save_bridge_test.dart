import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/legacy_save_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mergeempirefc.app/legacy_save');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('returns the raw save string from the platform', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readLegacySave');
      return '{"version":7}';
    });

    expect(await const LegacySaveBridge().readLegacySave(), '{"version":7}');
  });

  test('returns null when the platform has no save', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await const LegacySaveBridge().readLegacySave(), isNull);
  });

  test('returns null instead of throwing when the channel fails', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    expect(await const LegacySaveBridge().readLegacySave(), isNull);
  });

  test('returns null when the platform returns a non-string', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 42);
    expect(await const LegacySaveBridge().readLegacySave(), isNull);
  });
}
