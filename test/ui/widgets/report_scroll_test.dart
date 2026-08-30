/// A report page is CENTRED when it is short and scrolls when it is long.
///
/// Both report screens are a stack of cards over a foot that is pinned so the
/// way out is never more than a thumb away, and the stack is usually shorter
/// than the phone. A `ListView` or a `SingleChildScrollView` puts short content
/// at the TOP of its viewport, so what a player sees is the report crammed
/// against the status bar, a third of a screen of nothing, and then the button.
/// Reported as both screens looking a little ugly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/report_scroll.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SHORT CONTENT SITS IN THE MIDDLE, not against the top', (
    tester,
  ) async {
    await pump(
      tester,
      const ReportScroll(
        child: SizedBox(
          key: ValueKey('card'),
          height: 200,
          child: Text('x'),
        ),
      ),
    );
    final card = tester.getRect(find.byKey(const ValueKey('card')));
    // 200 in an 800 viewport: 300 above and 300 below, rather than 0 and 600.
    expect(card.top, closeTo(300, 1));
    expect(card.bottom, closeTo(500, 1));
  });

  testWidgets('and the gap above equals the gap below', (tester) async {
    // The whole of the claim, stated as the thing a player actually sees.
    await pump(
      tester,
      ReportScroll.list(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
        children: const [
          SizedBox(key: ValueKey('a'), height: 100),
          SizedBox(key: ValueKey('b'), height: 100),
        ],
      ),
    );
    final first = tester.getRect(find.byKey(const ValueKey('a')));
    final last = tester.getRect(find.byKey(const ValueKey('b')));
    expect(first.top - 18, closeTo(800 - 8 - last.bottom, 1.5));
  });

  testWidgets('LONG CONTENT STILL SCROLLS, and starts at the top', (
    tester,
  ) async {
    // Centring must cost nothing when the page is full: the minimum height is
    // the viewport, so anything taller pushes past it and behaves as before.
    await pump(
      tester,
      ReportScroll.list(
        children: const [
          SizedBox(key: ValueKey('a'), height: 600),
          SizedBox(key: ValueKey('b'), height: 600),
        ],
      ),
    );
    expect(tester.getRect(find.byKey(const ValueKey('a'))).top, closeTo(0, 1));
    await tester.drag(find.byType(Scrollable), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('a'))).top,
      closeTo(-400, 1),
    );
  });

  testWidgets('a page exactly the height of the phone does not scroll', (
    tester,
  ) async {
    // The boundary, because the minimum height is what decides it: counting the
    // padding twice would make every short page scroll by exactly the padding.
    await pump(
      tester,
      ReportScroll.list(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: const [SizedBox(key: ValueKey('a'), height: 760)],
      ),
    );
    final position = tester
        .widget<Scrollable>(find.byType(Scrollable))
        .controller
        ?.position;
    expect(position?.maxScrollExtent ?? 0, closeTo(0, 0.5));
  });
}
