/// **THE APP IS SET IN ONE FACE AT ONE FLOOR, and buttons were escaping both.**
///
/// `pubspec.yaml` bundles a single Barlow cut — SemiBold — so every weight the
/// several hundred `TextStyle` literals in `lib/ui` name resolves to it, and
/// the app reads as one face without any of them being edited. `uiBaseWeight`
/// is the same floor for the styles that never chose.
///
/// Neither reaches a `ButtonStyle.textStyle`. Material installs that as the
/// label's `DefaultTextStyle` WHOLESALE rather than merging it, so a field it
/// leaves null is null at the `Text` — and `ThemeData.fontFamily` only ever
/// touched the `TextTheme`. Every moulded button in the app was therefore
/// labelled in the platform's own font, and the match row's 2×/Subs/Skip, which
/// reach it through `ButtonStyle.copyWith` — a whole-property swap — lost the
/// weight with the family and rendered at `w400`.
///
/// Reported from the couch twice, in those terms: the wrong font, then those
/// three defo not being `w600`. Nothing threw and nothing analysed, which is
/// why this is a test.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart'
    show matchControlStyle;
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// Every `Text` on screen, with the style it will actually be painted in.
///
/// The resolution a `Text` does for itself: the ambient `DefaultTextStyle`
/// merged with whatever the widget was given. Reading the widget's own `style`
/// would answer the question the bug was hiding behind — the offending labels
/// each had no style at all.
Iterable<(String, TextStyle)> painted(WidgetTester tester) sync* {
  for (final el in find.byType(Text).evaluate()) {
    final text = el.widget as Text;
    if (text.data == null) continue;
    final ambient = DefaultTextStyle.of(el).style;
    yield (text.data!, text.style == null ? ambient : ambient.merge(text.style));
  }
}

void main() {
  testWidgets('EVERY CONTROL IS IN THE APP FACE, at or over the base weight', (
    tester,
  ) async {
    // The four shapes a label can arrive in: the theme's moulded buttons, the
    // match row's `copyWith` override, and `StoreButton`, which is not a
    // Material button at all and styles its own `Text`.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: 'classic', light: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('elevated')),
                FilledButton(onPressed: () {}, child: const Text('filled')),
                OutlinedButton(onPressed: () {}, child: const Text('outlined')),
                OutlinedButton(
                  style: matchControlStyle(context),
                  onPressed: () {},
                  child: const Text('skip'),
                ),
                StoreButton(
                  tone: StoreTone.ad,
                  label: 'store',
                  onTap: () {},
                ),
                const Text('body'),
              ],
            ),
          ),
        ),
      ),
    );

    final wrong = <String>[];
    for (final (label, style) in painted(tester)) {
      final weight = style.fontWeight ?? FontWeight.w400;
      // Lilita One is a single-weight display face and carries its own — see
      // `displayText`. Nothing here should be in it, but the rule is the rule.
      if (style.fontFamily == displayFontFamily) continue;
      if (style.fontFamily != uiFontFamily) {
        wrong.add('"$label" is in ${style.fontFamily ?? 'the PLATFORM font'}');
      }
      if (weight.value < uiBaseWeight.value) {
        wrong.add('"$label" is w${weight.value}, under w${uiBaseWeight.value}');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('and no button style names a size without naming the face', () {
    // The source half, because the render half can only see the buttons it was
    // given. A `ButtonStyle.textStyle` replaces rather than merges, so a
    // literal there has to carry the family itself — which is what
    // [controlTextStyle] is for, and it applies the weight floor too.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_theme.dart')) continue;
      final src = entity.readAsStringSync();
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('textStyle:')) continue;
        // The property and whatever it was handed, which may wrap.
        final window = lines.skip(i).take(6).join(' ');
        if (window.contains('controlTextStyle')) continue;
        if (!window.contains('TextStyle(')) continue;
        offenders.add('${entity.path}:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A ButtonStyle.textStyle REPLACES the label\'s ambient style, so a '
          'bare TextStyle literal there drops the family and renders the '
          'label in the platform font. Ask controlTextStyle(size:) '
          'instead:\n${offenders.join('\n')}',
    );
  });

  test('and NOTHING in lib/ui asks for a weight under the floor', () {
    // The literals, which the render half cannot reach without pumping every
    // screen in the app. `w400` and `w500` are weights the bundled face does
    // not have — asking for one is asking the engine to pick something else.
    // Four had shipped: Colin's Deadline Day line, the quiet half of a coach
    // card's pair, a player card's non-bold label, and the `<text>` in a club
    // crest.
    final under = RegExp(r'FontWeight\.(w[1-5]00|normal|light|thin)');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The theme is where the floor is DEFINED — see `_atBaseWeight`, which
      // has to name the weight it is raising from, and `displayText`, which
      // strips a weight the display face does not have.
      if (entity.path.endsWith('app_theme.dart')) continue;
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (under.hasMatch(lines[i])) offenders.add('${entity.path}:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'pubspec.yaml bundles ONE Barlow cut, at w${uiBaseWeight.value}. A '
          'style asking for less is asking for a face that is not there:\n'
          '${offenders.join('\n')}',
    );
  });

  test('and the single bundled cut is still what the floor rests on', () {
    // Guards the rule above from passing because the app stopped bundling a
    // face, which would make it true and pointless at once. `uiBaseWeight` may
    // only ever name a weight that has a file: asking for one that does not is
    // what makes the engine smear the nearest.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/fonts/Barlow-SemiBold.ttf'));
    expect(pubspec, contains('weight: ${uiBaseWeight.value}'));
    expect(
      File('assets/fonts/Barlow-SemiBold.ttf').existsSync(),
      isTrue,
      reason: 'the cut every weight in the app resolves to',
    );
  });
}
