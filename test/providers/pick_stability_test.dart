/// Every `savePick` provider, asked the same question twice.
///
/// A pick that rebuilds a value with no `==` reports a change on every tick, and
/// the five tabs are all mounted in one `IndexedStack` — so ONE churning pick
/// rebuilds all five, once a second, for ever. Measured before this test
/// existed: 13.6–16.3ms of UI-thread build against an 8.33ms budget, at idle.
///
/// `savePick` holds its last value in a closure SHARED between containers, so
/// reading the same provider from a second container is exactly the second tick
/// — an unchanged value has to come back as the same instance.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/providers/voice_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/hud/hud_boosts.dart';
import 'package:merge_empire_fc/ui/popups/energy_sheet.dart';
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';
import 'package:merge_empire_fc/ui/screens/club/club_stats_panel.dart';
import 'package:merge_empire_fc/ui/screens/club/kit_picker.dart';
import 'package:merge_empire_fc/ui/screens/events/event_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/add_player_button.dart';
import 'package:merge_empire_fc/ui/screens/grid/auto_tier_sheet.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart';
import 'package:merge_empire_fc/ui/screens/home/fixture_caption.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/match_quests_block.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart';
import 'package:merge_empire_fc/ui/screens/home/sub_tab_coach_line.dart';
import 'package:merge_empire_fc/ui/screens/index/player_index_sheet.dart';
import 'package:merge_empire_fc/ui/screens/leaderboard/leaderboard_sheet.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_match_day.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart';
import 'package:merge_empire_fc/ui/screens/trophies/trophy_room_sheet.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_overlay.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

String _save({bool progressed = false}) {
  final s = createDefaultState();
  (s['resources'] as Map)['fanCoins'] = 100000;
  s['clubName'] = 'Testville FC';
  if (progressed) {
    // The collection-valued picks — the trophy room and the player index — are
    // empty on a fresh save, which is the one shape their equality cannot get
    // wrong. So give them something to compare.
    final prog = s['progression'] as Map<String, dynamic>;
    prog['discoveredPlayers'] = ['striker_1:m', 'striker_1:f', 'keeper_1:m'];
    prog['playerFoundCounts'] = {'striker_1:m': 3, 'keeper_1:m': 1};
    prog['leagueTrophies'] = [
      {'division': 'sunday_league', 'season': 1, 'position': 1},
      {'cup': true, 'division': 'sunday_league', 'season': 2, 'position': 1},
    ];
    prog['achievements'] = [
      {'id': 'first_merge', 'count': 1, 'unlockedAt': 1699999999000},
    ];
    // Injured players, so `subTabTip` reaches the one line that BUILDS a params
    // map — `{'n': injured}` — instead of the const empty one every other line
    // uses. A default save's grid cells are all EMPTY, so they have to be
    // filled: without this the pick is only ever compared on a shape whose
    // equality cannot fail, and the test passes over a real bug.
    final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
    for (var i = 0; i < 3; i++) {
      cells[i] = <String, dynamic>{
        'instanceId': 'inj$i',
        'definitionId': 'player_t5_mid',
        // **A NAME, because the migration ROLLS one for a card without it.**
        // A real card carries a rolled name from the moment it is created, so
        // omitting it here made two loads of the same save disagree — which
        // reads exactly like churn and is not: it is two rolls, not two ticks.
        'displayName': 'Fixed Name $i',
        'variant': 0,
        'injured': true,
      };
    }
  }
  return jsonEncode(s);
}

ProviderContainer _container({bool progressed = false}) {
  final c = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: _save(progressed: progressed)}),
      ),
    ],
  );
  addTearDown(c.dispose);
  c.read(gameProvider).load();
  return c;
}

void main() {
  setUp(() => setClock(() => 1700000000000));
  tearDown(() {
    resetClock();
    clearBus();
  });

  final picks = <String, ProviderListenable<Object?>>{
    'dailyRewardUnclaimed': dailyRewardUnclaimedProvider,
    'dailyStreak': dailyStreakProvider,
    'clubStats': clubStatsProvider,
    'anyAssetOwned': anyAssetOwnedProvider,
    'kitColour': kitColourProvider,
    'seasonQuests': seasonQuestsProvider,
    'matchQuests': matchQuestsProvider,
    'claimableQuests': claimableQuestsProvider,
    'questReroll': questRerollProvider,
    'nextMatch': nextMatchProvider,
    'assetTiles': assetTilesProvider,
    'ownedAssetCount': ownedAssetCountProvider,
    'fixtureLabel': fixtureLabelProvider,
    'matchQuestRows': matchQuestRowsProvider,
    'matchQuestTotal': matchQuestTotalProvider,
    'coachTips': coachTipsProvider,
    'coachTipKey': coachTipKeyProvider,
    'coachTacticPick': coachTacticPickProvider,
    'coachSuggestedTactic': coachSuggestedTacticProvider,
    'ourCupTies': ourCupTiesProvider,
    'ourFixtures': ourFixturesProvider,
    'leagueTable': leagueTableProvider,
    'lastSeasonStatus': lastSeasonStatusProvider,
    'divisionName': divisionNameProvider,
    'seasonNumber': seasonNumberProvider,
    'fixtures': fixturesProvider,
    'nextMatchNumber': nextMatchNumberProvider,
    'managerLook': managerLookProvider,
    'managerMood': managerMoodProvider,
    'leagueForm': leagueFormProvider,
    'leagueRatings': leagueRatingsProvider,
    'subTabTip': subTabTipProvider,
    'tutorialStep': tutorialStepProvider,
    'matchReaction': matchReactionProvider,
    'tutorialCondition': tutorialConditionProvider,
    'tutorialClub': tutorialClubProvider,
    'tutorialGridCount': tutorialGridCountProvider,
    'tutorialScore': tutorialScoreProvider,
    'miniGames': miniGamesProvider,
    'miniGamesReady': miniGamesReadyProvider,
    'divisionIndex': divisionIndexProvider,
    'skipsLeftToday': skipsLeftTodayProvider,
    'matchBlocked': matchBlockedProvider,
    'cupRound': cupRoundProvider,
    'matchDay': matchDayProvider,
    'trophyRoom': trophyRoomProvider,
    'consumableTiles': consumableTilesProvider,
    'paidTiles': paidTilesProvider,
    'coinMult': coinMultProvider,
    'gemItemTiles': gemItemTilesProvider,
    'voucherTiles': voucherTilesProvider,
    'styleVaultOwned': styleVaultOwnedProvider,
    'lookTiles': lookTilesProvider,
    'localStanding': localStandingProvider,
    'pendingOffer': pendingOfferProvider,
    'strategyId': strategyIdProvider,
    'formationId': formationIdProvider,
    'pitchSlots': pitchSlotsProvider,
    'bench': benchProvider,
    'squadRatings': squadRatingsProvider,
    'injuredCount': injuredCountProvider,
    'healAllUsed': healAllUsedProvider,
    'seasonComplete': seasonCompleteProvider,
    'seasonJustEnded': seasonJustEndedProvider,
    'playerIndexProgress': playerIndexProgressProvider,
    'autoTierSummary': autoTierSummaryProvider,
    'autoTierActive': autoTierActiveProvider,
    'tutorialDone': tutorialDoneProvider,
    'activeEvent': activeEventProvider,
    'upcomingEvent': upcomingEventProvider,
    'gridCount': gridCountProvider,
    'maxMergeTier': maxMergeTierProvider,
    'mergeablePairs': mergeablePairsProvider,
    'mergeAllCost': mergeAllCostProvider,
    'gridNeedsSort': gridNeedsSortProvider,
    'proMode': proModeProvider,
    'mergeableCells': mergeableCellsProvider,
    'signBlocked': signBlockedProvider,
    'signCost': signCostProvider,
    'signIsFree': signIsFreeProvider,
    'signFullCost': signFullCostProvider,
    'scoutVoucherTier': scoutVoucherTierProvider,
    'scoutBatch': scoutBatchProvider,
    'scoutBatchSizes': scoutBatchSizesProvider,
    'energyStatus': energyStatusProvider,
    'kitId': kitIdProvider,
    'themeChoice': themeChoiceProvider,
    'hudBoosts': hudBoostsProvider,
    'energyMax': energyMaxProvider,
    'prestigeLevel': prestigeLevelProvider,
    'equippedBadge': equippedBadgeProvider,
    'soundSettings': soundSettingsProvider,
    'voiceSettings': voiceSettingsProvider,
  };

  List<String> churnOn({required bool progressed}) {
    final a = _container(progressed: progressed);
    final b = _container(progressed: progressed);
    return [
      for (final e in picks.entries)
        if (!identical(a.read(e.value), b.read(e.value)))
          '${e.key} (${a.read(e.value).runtimeType})',
    ];
  }

  test('every pick hands back the same instance for an unchanged save', () {
    expect(churnOn(progressed: false), isEmpty);
  });

  test('and still does once there is something in the collections', () {
    expect(churnOn(progressed: true), isEmpty);
  });
}
