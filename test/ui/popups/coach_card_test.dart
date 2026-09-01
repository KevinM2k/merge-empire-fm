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
import 'package:merge_empire_fc/services/voice_cues.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

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
  bool speaks = false,
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
                speaks: speaks,
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


/// The card drawn INLINE over a page, which is how a tutorial step shows it —
/// on the host's own tree rather than the navigator, so the route does not
/// cover the control the step is pointing at.
Future<void> pumpFrame(
  WidgetTester tester, {
  Rect? avoid,
  String body = longBody,
}) => pumpFrameWithSkip(tester, avoid: avoid, body: body, onSkip: () {});

Future<void> pumpFrameWithSkip(
  WidgetTester tester, {
  required VoidCallback onSkip,
  Rect? avoid,
  String body = longBody,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: Scaffold(
        body: Stack(
          children: [
            CoachCardFrame(
              avoid: avoid,
              title: 'Scout a player',
              body: body,
              // The shape the overflow was found in: a card with no answers and
              // a way out under them.
              footer: CoachAction(labelKey: 'tut.skip', onTap: onSkip),
            ),
          ],
        ),
      ),
    ),
  );
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

  testWidgets('HIS NAME IS THE FIRST LINE IN THE BOX, hard left', (
    tester,
  ) async {
    // It sat out on the scene above the box and off to the right for a while —
    // a nameplate opposite the figure — and it has been asked back inside:
    // left-aligned, above what he says. Both halves of that are the report.
    await openCard(tester);
    await tester.pumpAndSettle();

    final box = tester.getRect(find.byKey(const ValueKey('coach-box')));
    final name = tester.getRect(find.byKey(const ValueKey('coach-card-name')));
    final title = tester.getRect(find.text(t('app.offline_title')));

    expect(box.contains(name.center), isTrue, reason: 'still out on the scene');
    expect(name.bottom, lessThanOrEqualTo(title.top), reason: 'not above it');
    // Hard left, which is what makes it a speaker label rather than a heading:
    // flush against the box's own padding. Measured off the LEFT edge rather
    // than by comparing the two gaps — the test font is far wider than the
    // device's, so the run of text very nearly fills the box either way.
    expect(name.left - box.left, lessThan(24));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('coach-card-name')))
          .textAlign,
      TextAlign.left,
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

      // On the line itself: anywhere on the BOX that is not a control. It used
      // to be his name plate, which has moved out onto the scene above the box
      // — and out there it is scenery, so a tap on it falls through to the
      // barrier the way a tap beside his head always has.
      await tester.tap(find.byKey(const ValueKey('coach-card-body')));
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

  group('and some cards are SPOKEN', () {
    /// What the card put on the bus. Announced rather than spoken directly, so
    /// the popup layer never imports a speech engine and a test never touches a
    /// device — see `services/voice_cues.dart`.
    late List<String> said;
    late int silences;

    setUp(() {
      said = [];
      silences = 0;
      on(coachSpeaksEvent, (args) {
        final text = args is Map<String, dynamic> ? args['text'] : null;
        if (text is String) said.add(text);
      });
      on(coachSilenceEvent, (_) => silences++);
      addTearDown(clearBus);
    });

    testWidgets('a card that asks announces the WHOLE line, at the start', (
      tester,
    ) async {
      // The whole line, not the typed prefix: the voice and the typing are one
      // delivery, so he says the sentence while it appears rather than after.
      await openCard(tester, speaks: true);
      expect(typedSoFar(tester, 'coach-card-body'), isNot(longBody));
      expect(said, [longBody]);
    });

    testWidgets('and stops when the card goes', (tester) async {
      await openCard(
        tester,
        speaks: true,
        actions: [CoachAction(labelKey: 'common.confirm', onTap: () {})],
      );
      await tester.tap(
        find.byKey(const ValueKey('coach-action-common.confirm')),
      );
      await tester.pumpAndSettle();
      expect(silences, 1, reason: 'a coach still talking over the screen you '
          'went back to is what this is for');
    });

    testWidgets('but a card that does not ask stays silent', (tester) async {
      // Which is every confirmation, every bid and every sponsor: the default
      // is off, and the story and information cards opt in.
      await openCard(tester);
      await tester.pumpAndSettle();
      expect(said, isEmpty);
      expect(silences, 0);
    });
  });

  /// **A card that has to keep off a control, which is every spotlight step.**
  ///
  /// The lift used to be worked out by the caller from the target's top edge
  /// alone, so it fired for anything not against the bottom edge: the scout
  /// step's button sits a third of the way down a screen the card never
  /// reached, and it threw the card to the top, squeezed the box to a 52pt
  /// sliver, overflowed it by 44 and stood Colin over the HUD and the very
  /// button he was pointing at. Reported from the couch.
  group('keeping off a control', () {
    /// The screen, and the two ends of it a control can be at.
    Size screen(WidgetTester tester) =>
        tester.view.physicalSize / tester.view.devicePixelRatio;

    testWidgets('a control DOWN THERE lifts the box clear of it', (
      tester,
    ) async {
      final hole = Rect.fromLTWH(300, screen(tester).height - 100, 200, 40);
      await pumpFrame(tester, avoid: hole);

      final box = tester.getRect(find.byKey(const ValueKey('coach-box')));
      expect(
        box.bottom,
        lessThanOrEqualTo(hole.top),
        reason: 'the play button is under where the card opens, and the box '
            'eats its own taps — the step could not be finished at all',
      );
      expect(find.byType(CoachStandee), findsOneWidget);
    });

    testWidgets('and a control UP THERE leaves the card where it opens', (
      tester,
    ) async {
      final hole = const Rect.fromLTWH(300, 100, 200, 40);
      await pumpFrame(tester, avoid: hole);

      final box = tester.getRect(find.byKey(const ValueKey('coach-box')));
      expect(
        screen(tester).height - box.bottom,
        lessThan(24),
        reason: 'a card at the bottom was never in the way of a control at the '
            'top; moving it is the bug',
      );
      expect(
        box.top,
        greaterThan(hole.bottom),
        reason: 'and it still does not reach the hole',
      );
    });

    testWidgets('and HE gives the room up before the words do', (tester) async {
      // A hole with almost nothing under it and a line far too long for what
      // is left: the card can be neither lifted clear nor opened below, so
      // every point that is left has to go to the box.
      var left = 0;
      await pumpFrameWithSkip(
        tester,
        avoid: Rect.fromLTWH(0, 0, screen(tester).width, screen(tester).height - 40),
        body: List.filled(6, longBody).join(' '),
        onSkip: () => left++,
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'no room is not a licence to paint 44 past the bottom edge',
      );
      expect(
        find.byType(CoachStandee),
        findsNothing,
        reason: 'a figure squeezed to a thumbnail is not a man standing '
            'behind a box, and the words need the room more than he does',
      );

      // And the way out is still there to be PRESSED, which is the whole
      // reason the answers sit outside the scroll region: the overflow ate
      // exactly this, so a tap is the assertion rather than a `findsOneWidget`.
      await tester.tap(find.byKey(const ValueKey('coach-footer-tut.skip')));
      await tester.pump();
      expect(left, 1);
    });
  });
}
