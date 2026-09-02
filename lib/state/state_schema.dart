/// The canonical fresh save, ported from
/// `../merge-empire-fc/src/state/stateSchema.js`.
///
/// Returned as a plain `Map<String, dynamic>` rather than a typed model, and
/// deliberately so. Cloud saves persist the entire state as a JSON string and
/// the port must round-trip it exactly; a typed model would have to enumerate
/// every field and would silently drop anything a newer build added. Typed
/// views (see `CardInstance`) sit on top of this map where callers want safety.
///
/// Key ORDER matters as much as the values: `jsonEncode` emits insertion order,
/// so a reordered map produces a different string for identical data. That
/// breaks nothing functionally but makes byte-comparison against the JS save
/// useless, which is the main tool for proving the port is faithful.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Mark the tutorial done on a save that has no way of doing it.
///
/// **Nothing in this app can finish a tutorial.** The scripted one is the single
/// part of the JS that is not ported — no screen writes `tutorial.done`, and
/// `createDefaultState` copies the JS's default leaf for leaf, which is `false`.
/// Five finished features read that flag and refuse to appear while it says so:
/// the x-N scout batch control, the auto-sell pill, sponsor offers, rival
/// transfer bids and the auto-tier rules. Every save the port has ever written
/// sat behind all five of them permanently.
///
/// It is applied on the way IN rather than in the default state, because the
/// default state is pinned to the JS's and a test compares them leaf for leaf.
/// This is the same argument `tutorialDoneProvider` already makes about saves
/// written before the flag existed: a save that is not mid-tutorial is not
/// mid-tutorial, and one that cannot leave the tutorial never was.
/// **AND IT ONLY SETTLES A SAVE THAT HAS PLAYED.** This used to mark every save
/// finished on the way in, unconditionally, because there was no tutorial to be
/// in the middle of — the port had the fifty-six strings and no script. There is
/// one now (`engine/tutorial_engine.dart`), so a genuinely NEW save has to be
/// left alone or it would be walked past the only run of it that matters.
///
/// The test is EVIDENCE OF PLAY rather than a version stamp: a save with cards
/// on the grid, a match behind it or a merge in the ledger has been played, and
/// a player who has been playing for weeks must not be handed a welcome screen.
/// A stamp would have to guess when the tutorial landed; this cannot be wrong
/// about a save it has never seen.
void settleTutorial(Map<String, dynamic>? state) {
  final tutorial = state?['tutorial'];
  if (tutorial is! Map<String, dynamic>) return;
  if (tutorial['done'] == true) return;
  if (!_hasPlayed(state)) return;
  tutorial['done'] = true;
}

bool _hasPlayed(Map<String, dynamic>? state) {
  final progression = state?['progression'];
  if (progression is Map<String, dynamic>) {
    final played = progression['matchesPlayed'];
    if (played is num && played > 0) return true;
    final seasons = progression['seasonCount'];
    if (seasons is num && seasons > 1) return true;
  }
  final stats = state?['stats'];
  if (stats is Map<String, dynamic>) {
    final merges = stats['totalMerges'];
    if (merges is num && merges > 0) return true;
  }
  final grid = state?['grid'];
  final cells = grid is Map<String, dynamic> ? grid['cells'] : null;
  if (cells is List && cells.any((c) => c != null)) return true;
  return false;
}

Map<String, dynamic> createDefaultState() {
  final createdAt = now();

  return <String, dynamic>{
    'version': saveVersion,
    'createdAt': createdAt,
    'lastSeen': createdAt,

    'resources': <String, dynamic>{
      'fanCoins': startingCoins,
      // Hard currency. Earned by lifting cups, or bought — never converted from
      // coins, which would hand it the run's inflation. Survives New Team and
      // prestige, which is what makes everything it buys permanent too.
      'gems': 0,
      'matchRevenue': 0,
      'trophies': 0,
    },

    'energy': <String, dynamic>{
      'current': Energy.max,
      'lastRegenAt': createdAt,
    },

    'boosts': <String, dynamic>{
      'incomeBoostActive': false,
      'incomeBoostEndsAt': 0,
      // Sponsor buffs are tied to the season they were bought for, so buying
      // mid-season expires at the next season boundary rather than after an
      // arbitrary 14-match counter.
      'kitSponsorSeason': null, // kit sponsor: x1.25 income this season
      'matchRevBoostSeason': null, // TV deal: x1.5 match revenue this season
    },

    'grid': <String, dynamic>{
      'cells': List<dynamic>.filled(Grid.totalCells, null, growable: true),
    },

    'clubAssets': defaultClubAssets(),

    'club': <String, dynamic>{
      'kitPrimaryColor': '#4caf50',
      'polishLevel': 0,
      // Manager-avatar cosmetics for the League diorama walker. Null until
      // first render, when a random look is generated and saved.
      'managerAvatar': null,
      // Unlocked look packs. No route runs through the run's coins, so every
      // entry survives a New Team reset and prestige.
      'lookPacks': <dynamic>[],
      // Individual cosmetics unlocked one rewarded video at a time. A pack
      // becomes yours once you own everything in it.
      'lookItems': <dynamic>[],
    },

    // Local mirror of AdMob's per-unit frequency caps, so the UI can show a
    // countdown instead of a button that silently fails.
    'ads': <String, dynamic>{
      // Epoch-ms stamps of look-pack unlock videos that paid out, pruned to
      // the last 5 minutes.
      'packUnlocks': <dynamic>[],
    },

    'squad': <String, dynamic>{
      'formation': '4-3-3',
      'lineup': null, // null until first migration; 11 slot objects after
    },

    'progression': <String, dynamic>{
      'currentDivision': 'sunday_league',
      'trophiesTotal': 0,
      'matchesPlayed': 0,
      'matchesWon': 0,
      'matchesDrawn': 0,
      // Lifetime counters — survive prestige. The all-time leaderboard derives
      // from these so a soft reset never wipes the player's global standing.
      'careerWins': 0,
      'careerDraws': 0,
      'careerGoalsFor': 0,
      'careerBackfillDone': true, // new saves have nothing to recover
      'careerResetRecoveryDone': true,
      'lastMatchAt': 0,
      'divisionsUnlocked': <dynamic>['sunday_league'],
      // Season system
      'seasonOpponents': <dynamic>[],
      'seasonFixtures': null, // full 56-fixture schedule
      'seasonCount': 1,
      'seasonMatchesPlayed': 0,
      'seasonWins': 0,
      'seasonDraws': 0,
      'seasonLosses': 0,
      'seasonComplete': false,
      'seasonHistory': <dynamic>[],
      // Who won the top flight, came up or went down LAST season, badged in
      // this season's tables. Written by endSeason; null until one has ended.
      'lastSeasonStatus': null,
      'lastMatchResult': null,
      'achievements': <dynamic>[],
      // Ids earned since last reset; cleared on prestige to allow re-unlock.
      'achievementIdsThisRun': <dynamic>[],
      'leagueTrophies': <dynamic>[],
      // Achievement id shown on the leaderboard; null = default badge.
      'equippedBadgeId': null,
      // True once the player picks a badge; until then it auto-tracks their
      // newest achievement.
      'badgeManuallySet': false,

      'discoveredPlayers': <dynamic>[], // "{definitionId}:{gender}"
      'playerFoundCounts': <String, dynamic>{},
      'cups': <String, dynamic>{
        'active': null,
        'history': <dynamic>[],
        'availableThisSeason': true, // reset at each new league season
      },
    },

    'shop': <String, dynamic>{
      'freeScoutReady': false,
      // Guaranteed Scout: the floor tier armed for the next scout, or null. A
      // scalar rather than a queue on purpose — one at a time. Old saves have
      // no key at all and read as null.
      'scoutVoucherTier': null,
      'luckyBootReady': false,
      'luckyBootUses': 0,
    },

    'transferMarket': <String, dynamic>{
      'pendingOffer': null,
      'grudges':
          <String, dynamic>{}, // teamName -> { matchesLeft, boost, reason }
    },

    // Transfer Deadline Day — one live, wall-clock trading session per daily
    // window during the event.
    'deadlineDay': <String, dynamic>{
      'session': <String, dynamic>{
        'windowStart': 0,
        'startedAt': 0,
        'endsAt': 0,
        'listings': <dynamic>[],
        'spawned': 0,
        'marquees': 0,
        'done': false,
        'summary': null,
      },
      'history': <dynamic>[], // newest first, capped
      'notifiedWindows': <dynamic>[],
    },

    // Quests — two tracks with different resolution models.
    'quests': <String, dynamic>{
      // Match track: 3 quests tied to one fixture, EVALUATED at full time and
      // auto-paid. `fixtureKey` pins them so a re-render cannot silently redraw
      // them under the player.
      'match': <String, dynamic>{'fixtureKey': null, 'active': <dynamic>[]},
      // Season track: 3 quests ACCUMULATED over the season, claimed by hand.
      'season': <dynamic>[],
      // Recently-rolled ids, so the next roll does not repeat itself.
      'recent': <dynamic>[],
      'lastRolledSeason': 0,
      // Everything this season has done, by action, whether or not a quest was
      // watching. A quest rolled at match 10 starts from this rather than zero.
      'seasonTally': <String, dynamic>{},
      // Where each delta-measuring derived quest's reader stood at kick-off.
      'seasonBaselines': <String, dynamic>{},
      // Current runs for the streak quests. Progress here can go DOWN, which is
      // why streak quests bypass the incrementing path.
      'streaks': <String, dynamic>{
        'cleanSheet': 0,
        'win': 0,
        'unbeaten': 0,
        'scoring': 0,
      },
    },

    'miniGames': <String, dynamic>{
      'penaltyLastPlayed': 0,
      'trainingLastPlayed': 0,
    },

    // Event framework — limited-time content. Events are activated by trigger
    // evaluation on boot; only active ones surface UI.
    'events': <String, dynamic>{
      'active': <dynamic>[],
      'progress': <String, dynamic>{},
      'history': <dynamic>[],
      'devOverride': null,
    },

    'stats': <String, dynamic>{
      'totalMerges': 0,
      'totalScouts': 0,
      'highestTier': 1,
      'sessionCount': 0,
      // Achievement tracking — populated on the relevant events.
      'maxCoinsReached': 300,
      'transfersAccepted': 0,
      'transfersDeclined': 0,
      'penaltyRounds': 0,
      'penaltiesScored': 0,
      'perfectPenalties': 0,
      'perfectTrainings': 0,
    },

    'settings': <String, dynamic>{
      'soundEnabled': true,
      'musicEnabled': false,
      'soundVolume': 1, // 0..1 multiplier on SFX base level
      'musicVolume': 1,
      'notificationsEnabled': true,
      // Device language on first boot, narrowed to a shipped catalogue.
      'locale': detectLocale(),
      'regionCode': null, // ISO country code for the regional leaderboard
      'matchSpeedFast': false,
      'shownStrategyTip': false,
      // **`themeMode` is deliberately NOT here beside it.** The tri-state the
      // Settings screen writes — light, dark, or follow the phone — falls back
      // to this key whenever it is absent, so a fresh save needs nothing extra
      // and `game_state_test`'s reset parity still matches the JS's own default
      // state field for field. The key appears the first time a player picks.
      // See `themeChoiceProvider`.
      'lightMode': true, // reads better across the redesigned UI
      'cutawayOurTeam': true,
      'cutawayOpponent': true,
      // Per-player fatigue, no auto-lineup, no tactic tips. Changed only via
      // the new-team flow. Named for the old "Hard" label; the UI says Pro.
      'hardMode': false,
      // Auto-sell rules — { [tier]: 'sell' }. Tiers you still want are absent.
      'autoTierActions': <String, dynamic>{},
      // Saved custom team-name pyramids. Lives in settings so presets survive a
      // New Team reset.
      'customPyramids': <dynamic>[],
    },

    // Permanent gem entitlements. Deliberately NOT shop.purchasedIds: that
    // array is filtered on reset, which would silently drop these.
    'gemUnlocks': <dynamic>[],

    // Ledger for the one-time gem faucets. These fields are LIFETIME — they
    // must survive every reset, or New Team spam becomes a way to farm gems.
    'gemGrants': <String, dynamic>{
      'tutorialGranted': false,
      // True from the start on a NEW save: there is nothing to back-fill for a
      // player who has not done the tutorial yet. The flag only means something
      // to saves predating the gem system.
      'tutorialBackfilled': true,
      'divisionFirsts': <dynamic>[],
      'cupFirsts': <dynamic>[],
      'firstPrestigeDone': false,
      'chlTitleThisRun': false,
      // Divisions whose season-quest capstone gem has been paid. Seven
      // divisions, so quests can never pay more than 7 gems, ever.
      'questDivisionFirsts': <dynamic>[],
    },

    'prestige': <String, dynamic>{
      'level': 0,
      'incomeMultiplier': 1.0,
      'totalTrophies': 0,
      'points': 0,
    },

    // Career totals that persist across resets — incremented at source.
    'careerStats': <String, dynamic>{
      'leagueWins': 0,
      'cupWins': 0,
      'matchesWon': 0,
      'totalMerges': 0,
      'hardModeWins': 0,
    },

    // FALSE here, and true by the time anyone reads it — see `settleTutorial`.
    // This map is pinned to the JS's default save leaf for leaf, so the fix for
    // a tutorial that cannot be finished does not belong in it.
    'tutorial': <String, dynamic>{
      'done': false,
      'step': 0,
      'borrowedPlayersAdded': false,
      'borrowedPlayersRemoved': false,
    },

    // Contextual coach tips. Each tip id is pushed here once shown so it never
    // fires again — cleared only on a full reset.
    'seenTips': <dynamic>[],

    'rating': <String, dynamic>{
      'status': 'pending', // 'pending' | 'later' | 'never' | 'done'
      'promptCount': 0,
      'lastPromptAt': 0,
      'nextPromptAt': 0,
    },

    // Per-definition ATK/DEF split ratios — rolled once per new team or
    // prestige so every instance of a card has identical stats within a save.
    'definitionRatios': generateDefinitionRatios(),

    'clubName': '', // set on first launch via the name picker
    // Online leaderboard identity — anonymous UUID until optional sign-in.
    'leaderboard': <String, dynamic>{
      'playerId': null, // generated on first boot
      'authUid': null,
      // Email username (before @) — local only, never published.
      'accountName': null,
      'authProvider': null, // 'google' | 'apple'
      'pgsPlayerId': null,
      'lastSubmittedAt': 0,
      'careerSeeded': false,
      'anonymousLinked': false,
      'rankingsVisible': true, // false = opted out of public leaderboards
      'optOutApplied': false,
      'metaClubName': null,
      'allTimeRepairDone': false,
    },

    // Weather over the League diorama. lat/lon are a city-rounded position
    // derived from the device TIMEZONE, never from a location permission.
    'weather': <String, dynamic>{
      'timeZone': null,
      'lat': null, // rounded to 2dp — a city, not a person
      'lon': null,
      'locationSource': null, // 'timezone' | 'region' | 'default'
      'live': null,
      'failedAt': null,
    },

    // Texas SB 2420 / Google Play Age Signals API. Populated on Android when
    // Play has verified the user's age.
    'ageVerification': <String, dynamic>{
      'status': 'unknown', // 'unknown' | 'child' | 'teen' | 'adult'
      'source': null, // 'play_api' | null
      'checkedAt': 0,
      'parentalConsentGiven': false,
      'parentalConsentAt': 0,
    },
  };
}
