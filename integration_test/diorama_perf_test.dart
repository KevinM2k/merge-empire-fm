import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_diorama.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> run(WidgetTester tester, {required bool usePainter}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProbeDiorama(usePainter: usePainter, rainDrops: 120),
        ),
      ),
    );

    await binding.traceAction(
      () async {
        // Four seconds of continuous animation, which is one full cycle.
        for (var i = 0; i < 240; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
      reportKey: usePainter ? 'diorama_painter' : 'diorama_widgets',
    );
  }

  testWidgets('CustomPainter diorama holds its frame budget', (tester) async {
    await run(tester, usePainter: true);
  });

  testWidgets('widget-tree diorama holds its frame budget', (tester) async {
    await run(tester, usePainter: false);
  });
}
