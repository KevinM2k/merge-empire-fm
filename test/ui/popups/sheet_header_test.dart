/// One rule for a popup title, and the sweep that finishes it.
///
/// There were at least five: the Energy sheet's accent green at 18 centred,
/// Auto-Sell's plain ink at 16 left-aligned, the Trophy Room's caps, Coach
/// Colin's plain w900 at 17, the quick nav's accent at 18. Each defensible
/// alone; the set of them reads as five different apps, which is what a player
/// notices opening three sheets in a row.
///
/// This pins the rule itself and the one structural claim behind it — that the
/// title is centred on the SHEET rather than on whatever is left beside a close
/// button — plus a sweep over the source tree, so a new sheet cannot quietly
/// grow a sixth style.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

Future<KitTheme> pumpHeader(
  WidgetTester tester, {
  String? subtitle,
  Widget? trailing,
}) async {
  final theme = buildAppTheme(kitId: 'classic', light: false);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SheetHeader(
          title: 'Training Sessions',
          subtitle: subtitle,
          trailing: trailing,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return theme.extension<KitTheme>()!;
}

void main() {
  testWidgets('CAPS, the club accent, centred, 15/w900', (tester) async {
    final kit = await pumpHeader(tester);
    final title = tester.widget<Text>(find.text('TRAINING SESSIONS'));
    expect(title.textAlign, TextAlign.center);
    expect(title.style!.color, kit.accentBright);
    expect(title.style!.fontSize, 15);
    expect(title.style!.fontWeight, FontWeight.w900);
  });

  testWidgets('the case change is in the WIDGET, not in the string', (
    tester,
  ) async {
    // A language with no case — Japanese, Chinese, Arabic — is untouched by an
    // upper-casing widget and would be shouted at by an upper-cased catalogue.
    await pumpHeader(tester);
    expect(find.text('Training Sessions'), findsNothing);
    expect(find.text('TRAINING SESSIONS'), findsOneWidget);
  });

  testWidgets('a subtitle is muted and left in its own case', (tester) async {
    final kit = await pumpHeader(tester, subtitle: 'Pick a drill.');
    final sub = tester.widget<Text>(find.text('Pick a drill.'));
    expect(sub.style!.color, kit.textMuted);
    expect(sub.style!.fontSize, 12);
  });

  testWidgets('A TRAILING CONTROL DOES NOT MOVE THE TITLE', (tester) async {
    // The whole reason it is stacked over the top rather than laid beside: a
    // title that shifts depending on whether a sheet has a close button is the
    // inconsistency this widget exists to stop.
    await pumpHeader(tester);
    final without = tester.getCenter(find.text('TRAINING SESSIONS')).dx;
    await pumpHeader(
      tester,
      trailing: const Icon(Icons.close, key: ValueKey('x')),
    );
    final with_ = tester.getCenter(find.text('TRAINING SESSIONS')).dx;
    expect(with_, without);
    expect(find.byKey(const ValueKey('x')), findsOneWidget);
  });

  test('EVERY SHEET AND TAKEOVER USES IT', () {
    // The sweep. A file listed here draws a title of its own and has not been
    // converted; the three exceptions state their reason in their own headers.
    const exceptions = {
      // His title is him speaking, under his own name plate.
      'lib/ui/popups/coach_card.dart',
      // A celebration, not a heading.
      'lib/ui/popups/achievement_unlock.dart',
      // The title is the player's name across his own portrait.
      'lib/ui/screens/squad/player_detail_sheet.dart',
    };
    final sheets = [
      for (final f in Directory('lib/ui').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            (f.path.contains('sheet') || f.path.contains('minigames/')))
          f,
    ];
    expect(sheets, isNotEmpty);

    // Frames and hosts. Neither draws a title: one IS the sheet chrome, the
    // other hands its whole body to a view that carries the header.
    const frames = {
      'lib/ui/popups/bottom_sheet_popup.dart',
      'lib/ui/screens/minigames/training_sheet.dart',
    };

    final missing = <String>[];
    for (final file in sheets) {
      final path = file.path;
      if (exceptions.contains(path) || frames.contains(path)) continue;
      final src = file.readAsStringSync();
      // A file that renders no title of its own is fine — the providers, the
      // views and the frame itself.
      if (!src.contains('Scaffold(') && !src.contains('showBottomSheetPopup')) {
        continue;
      }
      if (src.contains('SheetHeader') || src.contains('MiniGameHeader')) {
        continue;
      }
      missing.add(path);
    }
    expect(missing, isEmpty, reason: 'these still title themselves');
  });

  test('and the three exceptions SAY they are exceptions', () {
    for (final path in [
      'lib/ui/popups/coach_card.dart',
      'lib/ui/popups/achievement_unlock.dart',
      'lib/ui/screens/squad/player_detail_sheet.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(
        src.toLowerCase(),
        contains('exception'),
        reason: '$path differs without saying why',
      );
    }
  });
}
