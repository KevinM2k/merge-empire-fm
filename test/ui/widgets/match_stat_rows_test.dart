/// The mirrored ATK/DEF block, on the next-match card and the match page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';

Future<void> pumpRows(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: const Scaffold(
      body: Center(
        child: SizedBox(
          width: 340,
          child: MatchStatRows(
            left: (atk: 74, def: 61),
            right: (atk: 52, def: 80),
            leftRating: 68,
            rightRating: 66,
            leftMods: [],
            rightMods: [],
            leftBoot: false,
            rightBoot: false,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  tearDown(resetLocale);

  testWidgets('the bars are DRAWN, not zero pixels tall', (tester) async {
    // `FractionallySizedBox` with a `widthFactor` and no `heightFactor` passes
    // the incoming height through loose, and a `DecoratedBox` with no child
    // takes the smallest size it is allowed. Both tracks read as empty.
    await pumpRows(tester);
    await tester.pumpAndSettle();

    final fills = tester.widgetList<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fills, isNotEmpty);
    for (final fill in fills) {
      expect(fill.heightFactor, 1, reason: 'or it draws at no height at all');
    }
    for (final box in find.byType(FractionallySizedBox).evaluate()) {
      expect(
        tester.getSize(find.byWidget(box.widget)).height,
        greaterThan(0),
      );
    }
  });

  testWidgets('and the stronger side gets the longer one', (tester) async {
    // ATK 74 against 52: the left track has to be visibly longer, which is the
    // whole reason the block is mirrored.
    await pumpRows(tester);
    await tester.pumpAndSettle();
    final widths = [
      for (final box in find.byType(FractionallySizedBox).evaluate())
        tester.getSize(find.byWidget(box.widget)).width,
    ];
    expect(widths.length, 4, reason: 'ATK and DEF, both sides');
    expect(widths[0], greaterThan(widths[1]), reason: 'our ATK beats theirs');
  });
}
