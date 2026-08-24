import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/shell/coach_floating.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

void main() {
  testWidgets('dump', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: 'classic', light: false),
        home: RepaintBoundary(
          key: key,
          child: const Scaffold(
            body: CoachCorner(
              text: 'More than eleven on the books.',
              idPrefix: 'dump',
              startOpen: true,
              pulse: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/coach_tail.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
