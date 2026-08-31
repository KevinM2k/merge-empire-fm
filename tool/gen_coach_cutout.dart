/// Cuts Colin out of his white square, so he can STAND behind a dialog box.
///
/// `assets/ui/manager_hint.png` is a JPEG despite the name — a 512 square of him
/// from the hair down to the chest on flat white, with no alpha channel at all.
/// That is fine for the thing it was drawn for, a face inside a disc, and it is
/// the one thing a figure standing over the game cannot be: a white rectangle
/// with a man in it, floating on the pitch.
///
/// So this writes `assets/ui/coach_cutout.png` — the same drawing with the
/// background keyed out, the white fringe unmatted, and the result trimmed to
/// what is left. It is a GENERATOR: the JPEG is the master, this is the output,
/// and the output is committed because the app cannot run a node script at boot.
///
/// **Keyed by FLOOD FILL from the border, not by thresholding the whole image.**
/// His shirt and collar are white too — a global "white becomes transparent"
/// pass punches a hole through the middle of him, which is exactly what a
/// `ColorFilter` doing it at draw time would have done. Only white the outside
/// can reach is background.
///
/// Run it with the repo's own toolchain — no image package, `dart:ui` decodes
/// the JPEG and encodes the PNG:
///
/// ```bash
/// flutter test tool/gen_coach_cutout.dart
/// ```
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Where the master lives, and where the cutout goes.
const String _master = 'assets/ui/manager_hint.png';
const String _out = 'assets/ui/coach_cutout.png';

/// A pixel this bright, in every channel, is background — IF the outside can
/// reach it. Deliberately high: the flood fill only has to get started, and the
/// fringe below softens whatever it leaves behind.
const int _bgFloor = 234;

/// How far the soft edge reaches in from the keyed region, in pixels.
///
/// One ring is not enough on a JPEG: the codec rings around a hard edge, so the
/// two pixels either side of his shoulder are a smear of white and suit rather
/// than one or the other.
const int _feather = 2;

/// Where the soft edge finishes. A pixel this dark on the boundary is him.
const double _opaqueBelow = 200;

void main() {
  test('writes the coach cutout', () async {
    final bytes = await File(_master).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final w = image.width;
    final h = image.height;
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final src = raw!.buffer.asUint8List();

    bool isBg(int i) =>
        src[i] >= _bgFloor && src[i + 1] >= _bgFloor && src[i + 2] >= _bgFloor;

    // Every border pixel that is background seeds the fill; the queue is a plain
    // list rather than recursion because 512x512 of white overflows a stack.
    final outside = List<bool>.filled(w * h, false);
    final queue = <int>[];
    void seed(int x, int y) {
      final p = y * w + x;
      if (outside[p] || !isBg(p * 4)) return;
      outside[p] = true;
      queue.add(p);
    }

    for (var x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      final x = p % w;
      final y = p ~/ w;
      if (x > 0) seed(x - 1, y);
      if (x < w - 1) seed(x + 1, y);
      if (y > 0) seed(x, y - 1);
      if (y < h - 1) seed(x, y + 1);
    }

    // How far each kept pixel is from the keyed region, out to [_feather]. A
    // breadth-first sweep off the boundary, so ring 2 is found from ring 1
    // rather than by measuring every pixel against every other.
    final ring = List<int>.filled(w * h, 1 << 20);
    var front = <int>[];
    for (var p = 0; p < w * h; p++) {
      if (!outside[p]) continue;
      ring[p] = 0;
      front.add(p);
    }
    for (var d = 1; d <= _feather; d++) {
      final next = <int>[];
      for (final p in front) {
        final x = p % w;
        final y = p ~/ w;
        void step(int nx, int ny) {
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
          final q = ny * w + nx;
          if (ring[q] <= d) return;
          ring[q] = d;
          next.add(q);
        }

        step(x - 1, y);
        step(x + 1, y);
        step(x, y - 1);
        step(x, y + 1);
      }
      front = next;
    }

    // **PREMULTIPLIED, both ends.** `rawRgba` hands back premultiplied bytes and
    // `decodeImageFromPixels` wants them back the same way, and unmatting white
    // is simpler there anyway: a pixel composited over white is
    // `straight * a + 255 * (1 - a)`, so the premultiplied colour is just the
    // pixel with the white it borrowed taken back off it.
    final dst = Uint8List(w * h * 4);
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var p = 0; p < w * h; p++) {
      final i = p * 4;
      if (outside[p]) continue;
      var a = 1.0;
      if (ring[p] <= _feather) {
        final lightest = [
          src[i],
          src[i + 1],
          src[i + 2],
        ].reduce((v, e) => v > e ? v : e).toDouble();
        a = ((255 - lightest) / (255 - _opaqueBelow)).clamp(0.0, 1.0);
      }
      if (a <= 0) continue;
      final borrowed = 255 * (1 - a);
      for (var c = 0; c < 3; c++) {
        dst[i + c] = (src[i + c] - borrowed).clamp(0, 255 * a).round();
      }
      dst[i + 3] = (a * 255).round();
      final x = p % w;
      final y = p ~/ w;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    expect(maxX, greaterThan(minX), reason: 'the fill ate the whole picture');

    // Trimmed to what is left, so a caller sizing him by height gets HIM and not
    // the margin the square was drawn with.
    final cw = maxX - minX + 1;
    final ch = maxY - minY + 1;
    final cut = Uint8List(cw * ch * 4);
    for (var y = 0; y < ch; y++) {
      cut.setRange(
        y * cw * 4,
        (y + 1) * cw * 4,
        dst,
        ((y + minY) * w + minX) * 4,
      );
    }

    final trimmed = await _fromPixels(cut, cw, ch);
    final png = await trimmed.toByteData(format: ui.ImageByteFormat.png);
    await File(_out).writeAsBytes(png!.buffer.asUint8List());
    stdout.writeln('$_out — ${cw}x$ch, from ${w}x$h');
  });
}

Future<ui.Image> _fromPixels(Uint8List pixels, int w, int h) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}
