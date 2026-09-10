/// The decode-size hint `ArtImage` hands the engine.
///
/// A zero-width box is a real layout state — the Club tab is laid out at
/// width 0 at boot, before it is ever shown — and a hint derived from it was
/// `1`. dart:ui fills in the other side with integer division, so on the
/// 1024x572 stadium backdrop that is a 1x0 decode: Skia logs and refuses,
/// Impeller allocates a 1x0 texture and blits into it, which some GLES
/// drivers reject fatally (`blit_pass_gles.cc`, `fml::KillProcess`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/services/gpu_capability.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// 1024x572, the widest asset `ArtImage` serves.
const double _stadiumAspect = 1024 / 572;

Future<ImageProvider> pumpIn(WidgetTester tester, Size box) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: ArtImage(
            path: stadiumBackgroundPath(1),
            fallback: const SizedBox(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.widget<Image>(find.byType(Image)).image;
}

void main() {
  testWidgets('a zero-width box never asks for a decode with a zero side', (
    tester,
  ) async {
    final resize = await pumpIn(tester, const Size(0, 62)) as ResizeImage;
    expect(resize.height, isNull, reason: 'one side, so the aspect is kept');
    // dart:ui: `targetHeight = targetWidth ~/ (width / height)`.
    expect(resize.width! ~/ _stadiumAspect, greaterThanOrEqualTo(1));
  });

  testWidgets('and a real box still decodes at its own size', (tester) async {
    // The test binding's pixel ratio is 3.
    final resize = await pumpIn(tester, const Size(300, 168)) as ResizeImage;
    expect(resize.width, 900);
    expect(resize.height, isNull);
  });

  group('on a driver that cannot resize on the GPU', () {
    setUp(() => decodeHintsUnsafe = true);
    tearDown(() => decodeHintsUnsafe = false);

    testWidgets('no hint is given at all, so nothing is resized', (
      tester,
    ) async {
      // A hint is what wraps the asset in a ResizeImage; without one there is
      // nothing for the engine to resize, which is the whole fix.
      expect(
        await pumpIn(tester, const Size(300, 168)),
        isNot(isA<ResizeImage>()),
      );
    });
  });
}
