import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_diorama.dart';

void main() {
  testWidgets('painter mode renders a CustomPaint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProbeDiorama(usePainter: true)),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.descendant(
        of: find.byType(ProbeDiorama),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('widget mode renders one child per rain drop', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProbeDiorama(usePainter: false, rainDrops: 12)),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('rain-drop-'),
      ),
      findsNWidgets(12),
    );
  });

  testWidgets('the painter repaints as time advances', (tester) async {
    const a = DioramaPainter(t: 0, rainDrops: 4);
    const b = DioramaPainter(t: 0.5, rainDrops: 4);

    expect(a.shouldRepaint(b), isTrue);
    expect(a.shouldRepaint(a), isFalse);
  });
}
