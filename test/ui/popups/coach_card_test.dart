/// The shape Colin arrives in, after it moved.
///
/// It used to be a centred card with his face in a disc on its top border and
/// its body printed all at once. It is now a box along the BOTTOM of the screen
/// with him standing behind it, cut out of his own white background, and his
/// line typed in. Three of those are things a widget test can hold still:
///
/// - **where the box is** — bottom-anchored, not centred, on any screen;
/// - **where HE is** — above the box and overlapping it, so the card is over his
///   chest rather than under a floating bust;
/// - **what "typed" means for everything that is not the animation** — the whole
///   sentence laid out and in the tree from the first frame, a tap that finishes
///   it without answering the card, and reduce-motion that skips it.
///
/// That last group is the one worth writing down. A typewriter that reveals a
/// `substring` passes an eyeball test and fails all three: the card reflows line
/// by line as it types, a screen reader is handed a fragment, and every
/// `find.text` in the suite starts depending on how long the test pumped for.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// A body long enough that the animation has somewhere to go: at 12ms a glyph,
/// anything under a dozen characters is finished before the second frame.
const String longBody =
    'Back at last, boss. The backroom staff put in a shift without you, and it '
    'adds up over eight hours.';

/// What the card is actually PAINTING right now — the leading span, which is
/// the run that has been typed. The trailing one is the rest of the sentence in
/// transparent ink, which is what keeps the layout still.
String typedSoFar(WidgetTester tester, String key) {
  final span = tester.widget<Text>(find.byKey(ValueKey(key))).textSpan!;
  return ((span as TextSpan).children!.first as TextSpan).text!;
}

/// Everything the card would say if it were finished.
String wholeLine(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).textSpan!.toPlainText();

Future<void> openCard(
  WidgetTester tester, {
  String body = longBody,
  bool disableAnimations = false,
  List<CoachAction> actions = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showCoachCard<void>(
                context,
                titleKey: 'app.offline_title',
                bodyKey: 'unused.body',
                body: body,
                actions: actions,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Past the route's own transition, so nothing below is measuring a card that
  // is still sliding in.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('the card sits at the BOTTOM of the screen', (tester) async {
    await openCard(tester);
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final card = tester.getRect(find.byKey(const ValueKey('coach-box')));

    expect(
      screen.height - card.bottom,
      lessThan(24),
      reason: 'anchored low, where a dialogue box goes and a thumb already is',
    );
    expect(
      card.center.dy,
      greaterThan(screen.height / 2),
      reason: 'and not centred, which cut the game in half',
    );
  });

  testWidgets('and Colin STANDS behind it, overlapping its top edge', (
    tester,
  ) async {
    await openCard(tester);
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byKey(const ValueKey('coach-box')));
    final him = tester.getRect(find.byType(CoachStandee));

    expect(him.top, lessThan(card.top), reason: 'his head clears the box');
    expect(
      him.bottom,
      greaterThan(card.top),
      reason:
          'and the box is in front of his chest — the master is cropped there, '
          'so a figure that stops above the card is a severed bust',
    );
    expect(
      him.bottom - card.top,
      lessThan(him.height / 3),
      reason:
          'a sliver of him, not a third: the card covering more than the crop '
          'leaves a head and shoulders peering over the top',
    );

    // He stands to one SIDE of his box rather than in the middle of it. Dead
    // centre, over a centred name plate, he is a totem pole.
    final art = tester.widget<ArtImage>(
      find.descendant(of: find.byType(CoachStandee), matching: find.byType(ArtImage)),
    );
    expect(art.alignment.x, lessThan(-0.5));
    expect(art.alignment.y, 1, reason: 'and stands ON the card, not floating');
  });

  group('his line is typed', () {
    testWidgets('a character at a time', (tester) async {
      await openCard(tester);

      final early = typedSoFar(tester, 'coach-card-body');
      expect(early.length, lessThan(longBody.length));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        typedSoFar(tester, 'coach-card-body').length,
        greaterThan(early.length),
      );

      await tester.pumpAndSettle();
      expect(typedSoFar(tester, 'coach-card-body'), longBody);
    });

    testWidgets('but the WHOLE sentence is laid out from the first frame', (
      tester,
    ) async {
      // The untyped tail is transparent, not absent. Revealing a substring
      // instead grows the card line by line under the player's thumb, and hands
      // a screen reader a fragment of a sentence.
      await openCard(tester);

      expect(typedSoFar(tester, 'coach-card-body'), isNot(longBody));
      expect(wholeLine(tester, 'coach-card-body'), longBody);
      expect(
        find.text(longBody),
        findsOneWidget,
        reason: 'so the rest of the suite does not depend on how long it pumped',
      );
    });

    testWidgets('a tap finishes it, and does not answer the card', (
      tester,
    ) async {
      var answered = false;
      await openCard(
        tester,
        actions: [
          CoachAction(
            labelKey: 'common.confirm',
            onTap: () => answered = true,
          ),
        ],
      );
      expect(typedSoFar(tester, 'coach-card-body'), isNot(longBody));

      // On his name plate: anywhere on the card that is not a control.
      await tester.tap(find.byKey(const ValueKey('coach-card-name')));
      await tester.pump();

      expect(typedSoFar(tester, 'coach-card-body'), longBody);
      expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);
      expect(answered, isFalse, reason: 'skipping a line is not an answer');
    });

    testWidgets('and reduce-motion does not type at all', (tester) async {
      // A card whose text is still arriving is exactly what the setting is
      // asking us not to run — and these are decisions, often on a clock.
      await openCard(tester, disableAnimations: true);
      expect(typedSoFar(tester, 'coach-card-body'), longBody);
    });
  });

  testWidgets('the ANSWERS are live while it is still typing', (tester) async {
    // The objection to a typewriter here was the clock, and this is the answer
    // to it: nothing waits for the last character.
    var answered = false;
    await openCard(
      tester,
      actions: [
        CoachAction(labelKey: 'common.confirm', onTap: () => answered = true),
      ],
    );
    expect(typedSoFar(tester, 'coach-card-body'), isNot(longBody));

    await tester.tap(find.byKey(const ValueKey('coach-action-common.confirm')));
    await tester.pumpAndSettle();

    expect(answered, isTrue);
    expect(find.byKey(const ValueKey('coach-card')), findsNothing);
  });

  testWidgets('an empty body types nothing and throws nothing', (tester) async {
    // `_msPerGlyph * 0` is a zero-length controller, which is a real state a
    // card with a `child:` and no sentence gets into.
    await openCard(tester, body: '');
    await tester.pumpAndSettle();
    expect(typedSoFar(tester, 'coach-card-body'), '');
  });

  testWidgets('the title is NOT typed — only what he says', (tester) async {
    await openCard(tester);
    expect(find.text(t('app.offline_title')), findsOneWidget);
  });
}
