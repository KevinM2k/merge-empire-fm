/// AdMob unit ids, split by placement and by division.
///
/// Ported from the tables in `../merge-empire-fc/src/engine/energyEngine.js`.
/// They live in `lib/data/` rather than beside the engine because the code that
/// uses them is a platform adapter, and the engine has to stay Flutter-free.
///
/// Separate units per placement are what make the AdMob dashboard readable —
/// "2× match coins earned £180/day, Lucky Boot earned £6/day" rather than one
/// lumped total. Separate units per division do the same for season-end
/// interstitials: if Continental players stop watching while Elite players
/// don't, that is a churn signal with a division attached to it.
///
/// The ids are platform-specific because AdMob requires it — an Android unit
/// rejects iOS traffic and the other way about.
library;

const Map<String, String?> rewardedByPlacementAndroid = {
  'energy_pip': 'ca-app-pub-0386196346828968/6780310195',
  'double_match': 'ca-app-pub-0386196346828968/6248828703',
  'skip_cooldown': 'ca-app-pub-0386196346828968/4880426231',
  'heal_all': 'ca-app-pub-0386196346828968/3567344561',
  'idle_boost': 'ca-app-pub-0386196346828968/2254262895',
  'lucky_boot': 'ca-app-pub-0386196346828968/2560243013',
  'match_cooldown': 'ca-app-pub-0386196346828968/3046795346',
  'double_season': 'ca-app-pub-0386196346828968/8214511488',
  'daily_double': 'ca-app-pub-0386196346828968/1355120286',
  'streak_repair': 'ca-app-pub-0386196346828968/7343732572',
  // TODO: the real Android cosmetics unit id, before release. Until then this
  // falls back to energy_pip, which serves ads but files the revenue under the
  // wrong placement — and, more importantly, shares energy_pip's frequency cap,
  // so cosmetic unlocks WOULD eat into the energy budget. Not sharing that cap
  // is the whole point of a separate unit.
  'cosmetic_pack': null,
};

const Map<String, String?> rewardedByPlacementIos = {
  'energy_pip': 'ca-app-pub-0386196346828968/9775306487',
  'double_match': 'ca-app-pub-0386196346828968/1738928006',
  'skip_cooldown': 'ca-app-pub-0386196346828968/9256431730',
  'heal_all': 'ca-app-pub-0386196346828968/4028155787',
  'idle_boost': 'ca-app-pub-0386196346828968/7458158549',
  'lucky_boot': 'ca-app-pub-0386196346828968/5410579705',
  'match_cooldown': 'ca-app-pub-0386196346828968/5486601321',
  'double_season': 'ca-app-pub-0386196346828968/8036743041',
  'daily_double': 'ca-app-pub-0386196346828968/7176211614',
  'streak_repair': 'ca-app-pub-0386196346828968/4717569230',
  // TODO: the real iOS cosmetics unit id — see the Android note.
  'cosmetic_pack': null,
};

const Map<String, String> interstitialByDivisionAndroid = {
  'sunday_league': 'ca-app-pub-0386196346828968/7315017881',
  'amateur_cup': 'ca-app-pub-0386196346828968/7269644217',
  'regional_league': 'ca-app-pub-0386196346828968/5956562547',
  'national_league': 'ca-app-pub-0386196346828968/2309583692',
  'elite_league': 'ca-app-pub-0386196346828968/5981235396',
  'continental': 'ca-app-pub-0386196346828968/4643480878',
  'champions_cup': 'ca-app-pub-0386196346828968/9453515503',
};

const Map<String, String> interstitialByDivisionIos = {
  'sunday_league': 'ca-app-pub-0386196346828968/5678173016',
  'amateur_cup': 'ca-app-pub-0386196346828968/8228314738',
  'regional_league': 'ca-app-pub-0386196346828968/9569405854',
  'national_league': 'ca-app-pub-0386196346828968/6654319124',
  'elite_league': 'ca-app-pub-0386196346828968/3195569194',
  'continental': 'ca-app-pub-0386196346828968/9280482463',
  'champions_cup': 'ca-app-pub-0386196346828968/9541485698',
};

/// NATIVE units, by placement.
///
/// **Recorded ahead of the screen that will show them.** There is no News screen
/// yet and nothing reads this table; it is here so the id lives with the other
/// twenty-eight rather than in a message, and so the placement is named at the
/// point the unit was created rather than reconstructed later from the AdMob
/// dashboard.
///
/// `news` is a native BANNER in the news feed — not a rewarded unit and not an
/// interstitial, so it does not belong in either table above and must not fall
/// back to one: the fallbacks there exist to keep a rewarded tap paying out, and
/// a rewarded unit rendered as a banner is a policy problem rather than a
/// mislabelled row.
const Map<String, String?> nativeByPlacementAndroid = {
  'news': 'ca-app-pub-0386196346828968/7393998147',
};

/// The iOS half. Separate ids because AdMob requires it — an Android unit
/// rejects iOS traffic — and there is deliberately NO fallback for a placement
/// with no unit: see the note above.
const Map<String, String?> nativeByPlacementIos = {
  'news': 'ca-app-pub-0386196346828968/2141671467',
};

Map<String, String?> nativeByPlacement(String platform) =>
    platform == 'ios' ? nativeByPlacementIos : nativeByPlacementAndroid;

/// The native unit for [placement], or null when there is not one for this
/// platform yet. **No fallback** — a caller with no unit shows no ad.
String? nativeUnitFor(String platform, String placement) =>
    nativeByPlacement(platform)[placement];

/// The rewarded table for a platform. Anything that isn't iOS takes the Android
/// ids, matching the JS — the web build has no ad inventory either way.
Map<String, String?> rewardedByPlacement(String platform) =>
    platform == 'ios' ? rewardedByPlacementIos : rewardedByPlacementAndroid;

Map<String, String> interstitialByDivision(String platform) =>
    platform == 'ios' ? interstitialByDivisionIos : interstitialByDivisionAndroid;

/// The unit an unknown placement falls back to — the longest-lived one.
String? fallbackRewardedUnit(String platform) =>
    rewardedByPlacement(platform)['energy_pip'];

String? fallbackInterstitialUnit(String platform) =>
    interstitialByDivision(platform)['champions_cup'];

/// The unit for [placement], falling back when it is unknown or not yet wired.
String? rewardedUnitFor(String platform, String placement) =>
    rewardedByPlacement(platform)[placement] ?? fallbackRewardedUnit(platform);

/// The unit for a division's season-end interstitial, with the same fallback.
String? interstitialUnitFor(String platform, String? divisionId) =>
    (divisionId == null ? null : interstitialByDivision(platform)[divisionId]) ??
    fallbackInterstitialUnit(platform);
