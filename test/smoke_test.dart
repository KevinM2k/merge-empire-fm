import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/main.dart';

void main() {
  testWidgets('app boots and renders a MaterialApp', (tester) async {
    await tester.pumpWidget(const MergeEmpireApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
