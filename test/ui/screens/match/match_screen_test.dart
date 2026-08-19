/// The live match takeover.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> matchResult({
  bool won = true,
  bool drawn = false,
  int addedTime = 2,
  List<Map<String, dynamic>> events = const [],
}) => {
  'clubName': 'Testville',
  'opponentName': 'Ayton',
  'isHome': true,
  'won': won,
  'drawn': drawn,
  'addedTime': addedTime,
  'events': events,
};

Future<ProviderContainer> pumpMatch(
  WidgetTester tester,
  Map<String, dynamic> result, {
  void Function(Map<String, dynamic>)? onFinished,
  // Distinct per pump, so pumping a second match into the same tester builds a
  // fresh State rather than reusing one whose clock has already run out.
  String instance = 'a',
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: MatchScreen(
            key: ValueKey('match-$instance'),
            result: result,
            onFinished: onFinished,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

MatchScreenState stateOf(WidgetTester tester) =>
    tester.state<MatchScreenState>(find.byType(MatchScreen));

void main() {
  tearDown(resetLocale);

  testWidgets('opens goalless, on the clock', (tester) async {
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
        ],
      ),
    );
    expect(find.text('0 – 0'), findsOneWidget);
    expect(stateOf(tester).frame.minute, 0);
  });

  testWidgets('claims the tick gates while it is up', (tester) async {
    // Without this the loop drops a transfer bid or Coach Colin on top of the
    // match — the whole reason the gates are a record.
    final container = await pumpMatch(tester, matchResult());
    await tester.pump();
    expect(container.read(tickGatesProvider).matchOpen, isTrue);
  });

  testWidgets('and hands them back when it goes', (tester) async {
    final container = await pumpMatch(tester, matchResult());
    await tester.pump();
    expect(container.read(tickGatesProvider).matchOpen, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(container.read(tickGatesProvider).matchOpen, isFalse);
  });

  testWidgets('the score only moves when its goal is shown', (tester) async {
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
          {'minute': 80, 'type': 'goal', 'team': 'away', 'scorer': 'Them'},
        ],
      ),
    );
    // Nine minutes in, nothing yet.
    await tester.pump(minuteDurationFor(9));
    expect(find.text('0 – 0'), findsOneWidget);

    await tester.pump(minuteDurationFor(2));
    expect(find.text('1 – 0'), findsOneWidget);
  });

  testWidgets('runs to full time and says so', (tester) async {
    var finished = 0;
    await pumpMatch(
      tester,
      matchResult(addedTime: 1),
      onFinished: (_) => finished++,
    );
    await tester.pump(minuteDurationFor(95));
    await tester.pumpAndSettle();

    expect(stateOf(tester).frame.finished, isTrue);
    expect(find.text(t('match.full_time')), findsOneWidget);
    expect(finished, 1);
  });

  testWidgets('reports finishing exactly once', (tester) async {
    var finished = 0;
    await pumpMatch(
      tester,
      matchResult(addedTime: 0),
      onFinished: (_) => finished++,
    );
    await tester.pump(minuteDurationFor(120));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('skipping jumps to the end without changing the result', (
    tester,
  ) async {
    // The match was decided before the first whistle, so a skip costs the
    // player the story and nothing else.
    Map<String, dynamic>? reported;
    await pumpMatch(
      tester,
      matchResult(
        addedTime: 3,
        events: [
          {'minute': 10, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
          {'minute': 88, 'type': 'goal', 'team': 'home', 'scorer': 'Bobby'},
        ],
      ),
      onFinished: (r) => reported = r,
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();

    expect(find.text('2 – 0'), findsOneWidget);
    expect(stateOf(tester).frame.finished, isTrue);
    expect(reported, isNotNull);
  });

  for (final (label, result) in [
    ('victory', matchResult()),
    ('draw', matchResult(won: false, drawn: true)),
    ('defeat', matchResult(won: false)),
  ]) {
    testWidgets('the verdict names a $label', (tester) async {
      await pumpMatch(tester, result, instance: label);
      await tester.tap(find.byKey(const ValueKey('match-skip')));
      await tester.pumpAndSettle();
      expect(find.text(t('match.$label')), findsOneWidget, reason: label);
    });
  }

  testWidgets('a commentary line resolves its translation key', (tester) async {
    // The engine emits KEYS, which is why the i18n layer had to land first.
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {
            'minute': 5,
            'type': 'commentary',
            'team': 'home',
            'textKey': 'commentary.halftime_level',
          },
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    expect(find.text(t('commentary.halftime_level')), findsOneWidget);
    expect(find.text('commentary.halftime_level'), findsNothing);
  });

  group('the match quests at full time', () {
    /// The shape `settleMatch` writes onto the result once the track is judged.
    List<Map<String, dynamic>> outcomes() => [
      {
        'id': 'match_clean_sheet',
        'icon': '🧱',
        'target': 1,
        'passed': true,
        'coins': 120,
      },
      {
        'id': 'match_win_margin',
        'icon': '💪',
        'target': 2,
        'passed': false,
        'coins': 0,
      },
    ];

    testWidgets('are not shown while the match is still running', (
      tester,
    ) async {
      await pumpMatch(tester, {...matchResult(), 'questResults': outcomes()});
      expect(find.byKey(const ValueKey('match-quests')), findsNothing);
    });

    testWidgets('list what was won AND what was missed', (tester) async {
      // The misses are the point of showing all three: they are what makes the
      // next set worth reading.
      await pumpMatch(tester, {...matchResult(), 'questResults': outcomes()});
      stateOf(tester).skipToEnd();
      await tester.pump();

      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-quest-match_clean_sheet')),
        findsOneWidget,
      );
      expect(find.text(t('quests.missed')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-quests-total')),
        findsOneWidget,
        reason: 'one of them paid',
      );
    });

    testWidgets('and a match with no track shows nothing at all', (
      tester,
    ) async {
      await pumpMatch(tester, matchResult());
      stateOf(tester).skipToEnd();
      await tester.pump();
      expect(find.byKey(const ValueKey('match-quests')), findsNothing);
    });

    testWidgets('a track where nothing came off has no total', (tester) async {
      await pumpMatch(tester, {
        ...matchResult(),
        'questResults': [
          {
            'id': 'match_clean_sheet',
            'icon': '🧱',
            'target': 1,
            'passed': false,
            'coins': 0,
          },
        ],
      });
      stateOf(tester).skipToEnd();
      await tester.pump();
      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-quests-total')), findsNothing);
    });
  });

  testWidgets('half time is named rather than shown as a type', (tester) async {
    await pumpMatch(
      tester,
      matchResult(
        events: [
          {'minute': 45, 'type': 'halftime'},
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    expect(find.text(t('match.half_time')), findsOneWidget);
  });

  testWidgets('a match with no events still finishes', (tester) async {
    var finished = 0;
    await pumpMatch(tester, matchResult(), onFinished: (_) => finished++);
    await tester.tap(find.byKey(const ValueKey('match-skip')));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(find.byKey(const ValueKey('match-close')), findsOneWidget);
  });
}

/// [n] minutes of playback at the default pace.
Duration minuteDurationFor(int n) => minuteDuration(fast: false) * n;
