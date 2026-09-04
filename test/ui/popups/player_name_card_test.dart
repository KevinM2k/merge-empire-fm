/// Renaming a player.
///
/// **Nothing in the port could do it.** `util/player_name.dart` is a ported,
/// tested sanitiser and screener with no caller in `lib/`; eight `rename.*`
/// strings sit generated in all ten catalogues with nothing able to reach one;
/// `CardInstance.customName` is read by five surfaces and written by none; and
/// `season_rename` and `season_rename_many` count renamed cards, so both were
/// quests that could never advance.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/player_name_card.dart';
import 'package:merge_empire_fc/ui/popups/toast_host.dart';
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

const String instanceId = 'c0';

Map<String, dynamic> saveWith({String? customName}) {
  final state = createDefaultState();
  // The one-time `_nameOrderFix2026` migration re-rolls every `displayName` on
  // load, which would overwrite the fixture's. Marked done, so the card the
  // test set up is the card the test gets.
  state['_nameOrderFix2026'] = true;
  final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
  cells[0] = {
    'definitionId': players.first.id,
    'instanceId': instanceId,
    'variant': 0,
    'displayName': 'Rolled Name',
    'customName': ?customName,
  };
  return state;
}

Future<ProviderContainer> pumpCard(
  WidgetTester tester, {
  String? customName,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({
          saveKeyPrimary: jsonEncode(saveWith(customName: customName)),
        }),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  // Opened the way the detail sheet opens it, through `showPlayerNameCard`.
  // Mounting the card directly leaves it with no route to close, which is not
  // a state it is ever in.
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-rename'),
                onPressed: () async {
                  lastResult = await showPlayerNameCard(
                    context,
                    instanceId: instanceId,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-rename')));
  await tester.pumpAndSettle();
  return container;
}

/// What the card resolved to, so a test can check the caller is told the new
/// name — the detail sheet behind it needs it to refresh its header.
String? lastResult;

String? storedName(ProviderContainer c) =>
    cardById(c.read(gameProvider).state, instanceId)?.customName;

String effectiveName(ProviderContainer c) =>
    cardById(c.read(gameProvider).state, instanceId)?.name() ?? '';

Future<void> type(WidgetTester tester, String value) async {
  await tester.enterText(
    find.byKey(const ValueKey('player-name-field')),
    value,
  );
  await tester.pumpAndSettle();
}

Future<void> tapAction(WidgetTester tester, String labelKey) async {
  await tester.tap(find.byKey(ValueKey('coach-action-$labelKey')));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) => tapAction(tester, 'rename.confirm');

void main() {
  setUp(() => lastResult = null);
  tearDown(resetLocale);

  test('TWO SEASON QUESTS COUNT RENAMED CARDS', () {
    // Which is why nothing being able to rename one mattered: both were
    // unwinnable, in the same way `trackEvent` made three unwinnable.
    final renameQuests = questBank.where(
      (q) => q.tags.contains(QuestTag.rename),
    );
    expect(renameQuests, isNotEmpty);
    final state = saveWith(customName: 'Ada');
    for (final quest in renameQuests) {
      expect(quest.progress!(state), greaterThan(0), reason: quest.id);
    }
    expect(
      renameQuests.first.progress!(saveWith()),
      0,
      reason: 'an unrenamed squad already counted',
    );
  });

  testWidgets('IT OPENS ON THE NAME THE CARD ALREADY HAS', (tester) async {
    await pumpCard(tester, customName: 'Ada Rovers');
    expect(find.text('Ada Rovers'), findsOneWidget);
    expect(find.text(t('rename.title')), findsOneWidget);
  });

  testWidgets('A TYPED NAME IS STORED, and it is what the card is called', (
    tester,
  ) async {
    final container = await pumpCard(tester);
    await type(tester, 'Ada Lovelace');
    await save(tester);
    expect(storedName(container), 'Ada Lovelace');
    expect(effectiveName(container), 'Ada Lovelace');
    expect(lastResult, 'Ada Lovelace');
  });

  testWidgets('A SCREENED NAME IS REFUSED ON THE CARD, not after it', (
    tester,
  ) async {
    // The card has to stay up, or the rejection appears on a card that has
    // already closed.
    final container = await pumpCard(tester);
    await type(tester, 'shit united');
    await save(tester);
    expect(find.text(t('rename.error_profanity')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-name-field')), findsOneWidget);
    expect(storedName(container), isNull);
  });

  testWidgets('and one too short is refused with the other message', (
    tester,
  ) async {
    final container = await pumpCard(tester);
    await type(tester, 'A');
    await save(tester);
    expect(find.text(t('rename.error_invalid')), findsOneWidget);
    expect(storedName(container), isNull);
  });

  testWidgets('the error clears on the NEXT KEYSTROKE', (tester) async {
    // A message about a name no longer in the field is a message about
    // nothing.
    await pumpCard(tester);
    await type(tester, 'A');
    await save(tester);
    expect(find.text(t('rename.error_invalid')), findsOneWidget);
    await type(tester, 'Ab');
    expect(find.text(t('rename.error_invalid')), findsNothing);
  });

  testWidgets('MARKUP IS DROPPED rather than escaped', (tester) async {
    // The character set is a whitelist, so nothing downstream has to remember
    // to sanitise a name before putting it in a template.
    final container = await pumpCard(tester);
    await type(tester, 'Ada <b>Rovers</b>');
    await save(tester);
    expect(storedName(container), isNot(contains('<')));
    expect(storedName(container), isNot(contains('>')));
  });

  testWidgets('TYPING THE ROLLED NAME BACK IN IS A RESET, not a custom name', (
    tester,
  ) async {
    // Storing it would pin the card to a name it would have had anyway — and
    // would advance a quest about renaming players without renaming one.
    final container = await pumpCard(tester, customName: 'Ada Rovers');
    await type(tester, 'Rolled Name');
    await save(tester);
    expect(storedName(container), isNull);
    expect(effectiveName(container), 'Rolled Name');
  });

  testWidgets('RESET on a card never renamed only puts the field back', (
    tester,
  ) async {
    final container = await pumpCard(tester);
    await type(tester, 'Somebody Else');
    await tapAction(tester, 'rename.reset');
    expect(find.byKey(const ValueKey('player-name-field')), findsOneWidget, reason: 'the sheet closed');
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('player-name-field'))).controller!.text,
      'Rolled Name',
    );
    expect(storedName(container), isNull);
  });

  testWidgets('and it puts the rolled name back', (tester) async {
    final container = await pumpCard(tester, customName: 'Ada Rovers');
    expect(
      find.text(t('rename.reset', {'name': 'Rolled Name'})),
      findsOneWidget,
      reason: 'the button does not name what it resets TO',
    );
    await tapAction(tester, 'rename.reset');
    expect(storedName(container), isNull);
    expect(effectiveName(container), 'Rolled Name');
    expect(lastResult, 'Rolled Name', reason: 'the caller was told nothing');
  });

  testWidgets('RANDOMISE rolls another name into the field', (tester) async {
    // A squad ends up with two of the same man: `pickDisplayName` is
    // `pool[tier % 10]`, so every card of one position, tier and gender is born
    // with the same name. Renaming is the way out and typing was the annoying
    // part.
    final container = await pumpCard(tester);
    addTearDown(container.dispose);
    final before = tester
        .widget<TextField>(find.byKey(const ValueKey('player-name-field')))
        .controller!
        .text;

    await tester.tap(find.byKey(const ValueKey('player-name-randomise')));
    await tester.pumpAndSettle();
    final after = tester
        .widget<TextField>(find.byKey(const ValueKey('player-name-field')))
        .controller!
        .text;

    expect(after, isNot(before), reason: 'the roll changed nothing');
    expect(after, isNotEmpty);
    // It fills the FIELD. The roll is a suggestion; the confirm is still what
    // renames him.
    expect(storedName(container), isNull);
  });

  test('and the roll never hands back the name it was given', () {
    for (final position in ['GK', 'DEF', 'MID', 'FWD']) {
      for (final female in [true, false]) {
        final held = pickDisplayName(position, 3, female: female);
        for (var i = 0; i < 40; i++) {
          expect(
            randomDisplayName(position, female: female, notThis: held),
            isNot(held),
          );
        }
      }
    }
  });

  testWidgets('A TAP OUTSIDE THE BOX changes nothing — there is no Cancel', (
    tester,
  ) async {
    final container = await pumpCard(tester, customName: 'Ada Rovers');
    await type(tester, 'Somebody Else');
    expect(find.byKey(const ValueKey('coach-action-common.cancel')), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(storedName(container), 'Ada Rovers');
    expect(lastResult, isNull);
  });

  group('the toast', () {
    test('says which way round the rename went', () {
      setLocale('en');
      final done = toastFor('player:renamed', {'name': 'Ada', 'reset': false});
      expect(done?.text, t('rename.toast_done', {'name': 'Ada'}));
      expect(done?.good, isTrue);

      final reset = toastFor('player:renamed', {
        'name': 'Rolled Name',
        'reset': true,
      });
      expect(reset?.text, t('rename.toast_reset', {'name': 'Rolled Name'}));
    });

    test('and says nothing at all without a name to say', () {
      expect(toastFor('player:renamed', {'reset': false}), isNull);
    });

    test('it is a listened-for event, not one shouted into the void', () {
      expect(toastEvents, contains('player:renamed'));
    });
  });
}
