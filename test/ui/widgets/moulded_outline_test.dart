/// The moulded button's hard bottom edge, on a face with nothing in it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// What the button PAINTS, and where in that picture the button's own box is.
Future<({List<int> pixels, int width, Rect button})> shoot(
  WidgetTester tester,
  Widget button,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('shot'),
                  // The boundary captures its own subtree ONLY, so anything the
            // button does not paint comes back transparent — which is exactly
            // the question being asked.
            child: Padding(padding: const EdgeInsets.all(12), child: button),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  // `toByteData` is a real async gap: in a widget test it never completes
  // without `runAsync`, and the test HANGS rather than failing.
  late List<int> pixels;
  late int width;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    width = image.width;
    pixels = data!.buffer.asUint8List();
  });
  final frame = tester.getRect(find.byKey(const ValueKey('shot')));
  return (
    pixels: pixels,
    width: width,
    // The button in the picture's own coordinates, at `toImage`'s 1:1 ratio.
    button: tester.getRect(find.byWidget(button)).shift(-frame.topLeft),
  );
}

Color at(({List<int> pixels, int width, Rect button}) shot, double x, double y) {
  final i = (y.round() * shot.width + x.round()) * 4;
  final p = shot.pixels;
  return Color.fromARGB(p[i + 3], p[i], p[i + 1], p[i + 2]);
}

/// The topmost and bottommost rows the button put any ink on.
(int, int) painted(({List<int> pixels, int width, Rect button}) shot) {
  final rows = shot.pixels.length ~/ (shot.width * 4);
  var top = -1;
  var bottom = -1;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < shot.width; x++) {
      if (at(shot, x.toDouble(), y.toDouble()).a == 0) continue;
      if (top < 0) top = y;
      bottom = y;
      break;
    }
  }
  return (top, bottom);
}

void main() {
  testWidgets('AN OUTLINED BUTTON IS EMPTY, all the way through', (
    tester,
  ) async {
    // **A `BoxShadow` is the whole shape offset down and drawn BEHIND the
    // fill.** On the solid form the face covers the half of it the button sits
    // on and what is left is the hard edge underneath. On the OUTLINE form the
    // fill is transparent by design, so the bar showed straight through the
    // button as a grey slab with a lighter strip along its top — reported as a
    // weird grey 3D border on the bench's buttons.
    final shot = await shoot(
      tester,
      OutlinedButton(onPressed: () {}, child: const Text('BENCH')),
    );
    final b = shot.button;
    expect(
      at(shot, b.left + 6, b.center.dy).a,
      0,
      reason: 'the pane shows through the face',
    );
    // Just inside the button's own rim at the top: a band of edge colour here
    // is the slab starting three points lower than the button does.
    expect(
      at(shot, b.center.dx, b.top + 3).a,
      0,
      reason: 'a ridge along the top edge',
    );
  });

  testWidgets('but the hard edge under it is still there', (tester) async {
    // **The moulding is the same depth on both forms** — the same geometry and
    // the same edge bar, an empty face, which is all `outline` was ever meant
    // to change. So the two paint into exactly the same box: if the bar had
    // gone with the shadow the outlined one would stop 3pt higher.
    final outlined = await shoot(
      tester,
      OutlinedButton(onPressed: () {}, child: const Text('BENCH')),
    );
    final filled = await shoot(
      tester,
      ElevatedButton(onPressed: () {}, child: const Text('BENCH')),
    );
    expect(painted(outlined), painted(filled));
  });

  testWidgets('and a FILLED one keeps its face', (tester) async {
    final shot = await shoot(
      tester,
      ElevatedButton(onPressed: () {}, child: const Text('DONE')),
    );
    expect(at(shot, shot.button.left + 6, shot.button.center.dy).a, 1);
  });
}
