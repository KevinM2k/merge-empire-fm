import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

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
            // The REAL card now, not the M0 probe. The probe existed to measure
            // this budget before there was anything to measure; keeping it once
            // the card shipped would mean profiling a widget nobody renders.
            itemBuilder: (context, i) => PlayerCard(
              view: (
                name: 'Player $i',
                tier: 1 + (i % 9),
                rating: 40 + (i % 60),
                position: ['FWD', 'MID', 'DEF', 'GK'][i % 4],
                injured: i % 11 == 0,
                onLoan: i % 17 == 0,
                // Pro mode: the bar is the extra paint the budget has to hold.
                variant: 0,
                fitness: (i % 100) / 100,
                incomePerSec: null,
                maxed: false,
                atCap: false,
                // A badge on most of them: it is a Container and a Text over
                // the art, and the budget has to hold it on a full grid.
                trait: i % 3 == 0
                    ? null
                    : (icon: '⚽', level: 'III', title: 'Finisher III'),
                // An arrow on two thirds of them, both directions: it is a
                // Text in the caption row and the budget has to hold it.
                form: i % 3 == 0 ? 0 : (i % 2 == 0 ? 1 : -1),
              ),
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
