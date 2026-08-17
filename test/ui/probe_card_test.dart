import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/probe_card.dart';

void main() {
  testWidgets('renders name and rating and retints to the kit colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProbeCard(name: 'Rookie', rating: 42, kitColor: Color(0xFF4CAF50)),
      ),
    );

    expect(find.text('Rookie'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('probe-card-frame')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFF4CAF50));
  });

  testWidgets('is wrapped in a RepaintBoundary', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProbeCard(name: 'Rookie', rating: 42, kitColor: Color(0xFF4CAF50)),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ProbeCard),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });
}
