/// The standing card at the top of the leaderboard.
///
/// **It printed a dash for everybody.** `leaderboard.rank_unranked` was hard
/// coded, which was honest while there was no service and stopped being honest
/// the day there was one — the fetch two widgets below it has carried
/// `playerRank` all along. Reported off the screen as "it doesn't show my rank,
/// just has -".
///
/// The two stat tiles under it are gone in the same pass: "Trophies" and
/// "Record" were the trophy room's and the season report's readings, on the one
/// sheet whose subject is a ranked list.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/leaderboard/leaderboard_sheet.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// The function answers this board, and nothing opens a socket. Same seam the
/// service's own test uses.
void serveBoard(Map<String, dynamic> view) {
  leaderboardPost = (url, headers, body) async =>
      (status: 200, data: {'result': view});
}

Map<String, dynamic> signedIn() {
  final s = createDefaultState();
  s['clubName'] = 'Borough United';
  (s['leaderboard'] as Map<String, dynamic>)
    ..['authUid'] = 'u1'
    ..['rankingsVisible'] = true;
  return s;
}

Future<void> pumpSheet(WidgetTester tester, Map<String, dynamic> save) async {
  tester.view.physicalSize = const Size(402 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: const Scaffold(
          body: SingleChildScrollView(child: LeaderboardView()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String rankText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('leaderboard-rank')))
    .data!;

void main() {
  setUp(resetLeaderboardSeams);
  tearDown(resetLeaderboardSeams);

  testWidgets('THE CARD PRINTS THE RANK THE BOARD CAME BACK WITH', (
    tester,
  ) async {
    serveBoard({
      'playerRank': 42,
      'playerEntry': {
        'playerId': 'u1',
        'score': 100,
        'clubName': 'Borough United',
        'rank': 42,
      },
    });
    await pumpSheet(tester, signedIn());
    expect(rankText(tester), '#42');
  });

  testWidgets('and a big rank is abbreviated like every other figure', (
    tester,
  ) async {
    serveBoard({'playerRank': 12345});
    await pumpSheet(tester, signedIn());
    expect(rankText(tester), '#12.3k');
  });

  testWidgets('A BOARD THAT HAS NEVER SEEN YOU STILL SAYS SO', (tester) async {
    // The dash is not gone — it is now reserved for the two cases that really
    // have no rank, which is what makes it mean something.
    serveBoard({'entries': const <Object>[]});
    await pumpSheet(tester, signedIn());
    expect(rankText(tester), t('leaderboard.rank_unranked'));
  });

  testWidgets('and so does a board that would not load', (tester) async {
    leaderboardPost = (url, headers, body) async =>
        throw StateError('no network');
    await pumpSheet(tester, signedIn());
    expect(rankText(tester), t('leaderboard.rank_unranked'));
    expect(find.byKey(const ValueKey('leaderboard-error')), findsOneWidget);
  });

  testWidgets('NEITHER STAT TILE IS ON THE SHEET ANY MORE', (tester) async {
    serveBoard({'playerRank': 3});
    await pumpSheet(tester, signedIn());
    // Both tiles are gone with the widget that drew them, so what this pins is
    // that their COPY is no longer on the page — a tile put back by hand would
    // bring one of these two labels with it.
    expect(find.text(t('scene.dock.trophies').toUpperCase()), findsNothing);
    expect(find.text(t('season.end.stat_record').toUpperCase()), findsNothing);
  });
}
