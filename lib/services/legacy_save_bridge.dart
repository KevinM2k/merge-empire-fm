import 'package:flutter/services.dart';

/// Reads the save written by the Capacitor build's native mirror.
///
/// The primary save lives in the WebView's localStorage, which Dart cannot
/// reach. `nativeSaveMirror.js` also writes it to the native store, and that
/// copy is the only local migration path.
class LegacySaveBridge {
  const LegacySaveBridge({MethodChannel channel = defaultChannel})
    : _channel = channel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.mergeempirefc.app/legacy_save',
  );

  final MethodChannel _channel;

  /// The raw JSON string, or null when absent, unreadable, or off-platform.
  Future<String?> readLegacySave() async {
    try {
      final result = await _channel.invokeMethod<Object?>('readLegacySave');
      return result is String ? result : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
