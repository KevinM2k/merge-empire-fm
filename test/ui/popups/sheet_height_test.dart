/// A sheet is as tall as what is in it, up to a cap.
///
/// The spec's own rule — `.ps-sheet .ps-panel` is `height: auto; max-height:
/// min(85vh, 780px)` over "tall sections all clamp to the same height, short
/// ones don't leave a void below their content" — and the port had it as a
/// fixed fraction, so a sheet holding three quests was 80% of the phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// Opens a sheet over a bare page and returns the frame's height.
Future<double> openAndMeasure(
  WidgetTester tester,
  Widget child, {
  double heightFraction = 0.8,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBottomSheetPopup<void>(
              context,
              heightFraction: heightFraction,
              child: child,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return tester.getSize(find.byKey(const ValueKey('bottom-sheet-popup'))).height;
}

void main() {
  testWidgets('a short sheet is short', (tester) async {
    // The whole point: a sheet with one tile in it is one tile tall, and the
    // fraction never comes into it.
    final height = await openAndMeasure(
      tester,
      const SizedBox(height: 120, child: Text('a little')),
    );
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      height,
      lessThan(200),
      reason: 'the content is 120pt; the rest is the sheet\'s own chrome',
    );
    expect(
      height,
      lessThan(screen * 0.8),
      reason: 'the fraction is a ceiling, not a height',
    );
  });

  testWidgets('and a tall one stops at the fraction', (tester) async {
    final height = await openAndMeasure(
      tester,
      SingleChildScrollView(child: Container(height: 5000, color: Colors.red)),
    );
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(height, closeTo(screen * 0.8, 0.5));
  });

  testWidgets('AND AT 780 WHATEVER THE PHONE IS', (tester) async {
    // `min(85vh, 780px)`. A fraction on its own keeps growing with the screen,
    // and past this a sheet is a page that arrived from the wrong direction.
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final height = await openAndMeasure(
      tester,
      SingleChildScrollView(child: Container(height: 5000, color: Colors.red)),
    );
    expect(height, closeTo(780, 0.5));
  });
}
