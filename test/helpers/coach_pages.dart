/// Turning a coach card's pages from a test.
///
/// A widget test draws every glyph as a `fontSize`-wide box, so a line runs
/// about twice as wide as it does on a phone and bodies page here that never
/// page for a player. A test that reads a later line turns pages until it
/// finds it, rather than asserting which page it landed on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tap the box until [finder] is on screen or there is no page left.
Future<void> turnCoachPagesUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 12; i++) {
    if (finder.evaluate().isNotEmpty) return;
    final more = find.byKey(const ValueKey('coach-pages-more'));
    if (more.evaluate().isEmpty) return;
    await tester.tap(find.byKey(const ValueKey('coach-pages')));
    await tester.pumpAndSettle();
  }
}

/// Everything the card's box says, page by page, joined back into one string.
/// A paragraph can be cut mid-sentence at a page's end, so a test reading a
/// whole line reads this rather than one page.
Future<String> readCoachPages(WidgetTester tester) async {
  final parts = <String>[];
  for (var i = 0; i < 12; i++) {
    for (final w in tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('coach-pages')),
        matching: find.byType(Text),
      ),
    )) {
      parts.add(w.data ?? w.textSpan?.toPlainText() ?? '');
    }
    final more = find.byKey(const ValueKey('coach-pages-more'));
    if (more.evaluate().isEmpty) break;
    await tester.tap(find.byKey(const ValueKey('coach-pages')));
    await tester.pumpAndSettle();
  }
  return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
