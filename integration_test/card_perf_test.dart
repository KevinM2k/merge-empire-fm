import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_card.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a scrolling grid of cards holds its frame budget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridView.builder(
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.7,
                ),
            itemCount: 200,
            itemBuilder: (context, i) => ProbeCard(
              name: 'Player $i',
              rating: 40 + (i % 60),
              kitColor: const Color(0xFF4CAF50),
            ),
          ),
        ),
      ),
    );

    await binding.traceAction(() async {
      for (var i = 0; i < 5; i++) {
        await tester.fling(find.byType(GridView), const Offset(0, -400), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'card_grid_scroll');
  });
}
