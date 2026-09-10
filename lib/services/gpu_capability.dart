/// Whether a decode hint is safe to give the engine on this device.
///
/// **Impeller resizes on the GPU whenever a decoded bitmap differs from the
/// size asked for**, which is every `cacheWidth` on a PNG — PNG cannot
/// downscale in-decoder. That resize is `BlitResizeTextureCommandGLES`, which
/// needs `glBlitFramebuffer`; GLES 2 does not have it and the engine has no
/// fallback, so the blit encode fails and `fml::KillProcess` takes the app
/// down. Vulkan and GLES 3 devices never reach that path, so they keep their
/// hints — the whole point of asking rather than dropping hints everywhere.
library;

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.mergeempirefc.app/gpu');

/// True when decode hints must be withheld. Read once at boot.
bool decodeHintsUnsafe = false;

/// Ask the platform once, before the first frame.
Future<void> initGpuCapability() async {
  if (!Platform.isAndroid) return;
  try {
    final major = await _channel.invokeMethod<int>('glesMajorVersion');
    decodeHintsUnsafe = major == null || major < 3;
  } catch (_) {
    // Android that would not answer: withhold the hints rather than risk it.
    decodeHintsUnsafe = true;
  }
}
