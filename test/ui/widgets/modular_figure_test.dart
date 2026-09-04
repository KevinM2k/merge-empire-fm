/// Kenney's modular pack was bundled and nothing drew it; the fans do now.
/// A rolled look must only name files that are actually in the bundle.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/modular_figure.dart';

void main() {
  test('every part a rolled look names is in the bundle', () {
    for (var seed = 0; seed < 60; seed++) {
      for (final path in spectatorAssets(spectatorLook(seed))) {
        expect(File(path).existsSync(), isTrue, reason: '$path (seed $seed)');
      }
    }
  });

  test('the same seed is the same fan', () {
    expect(spectatorLook(7), spectatorLook(7));
    expect(spectatorLook(7), isNot(spectatorLook(8)));
  });

  testWidgets('a figure is its ten parts, sized to its height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: ModularFigure(look: (
          skin: 1, shirt: 'blue', shirtStyle: 1, pants: 'Blue1', pantsStyle: 1,
          shoe: 'black', shoeStyle: 1, hair: 'black', woman: false, hairStyle: 1, face: 1,
        ), height: 100)),
      ),
    );
    expect(find.byType(Image), findsNWidgets(14));
    expect(tester.getSize(find.byType(ModularFigure)), const Size(62, 100));
  });
}
