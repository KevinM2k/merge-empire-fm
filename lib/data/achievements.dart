/// The achievement catalogue. Ported from
/// `../merge-empire-fc/src/data/achievements.js`.
///
/// Each entry is a short id, a title and description, an icon, and a
/// [Achievement.check] that returns true when the achievement is currently met.
/// The engine runs the checks on relevant events — a finished match, a finished
/// season, a merge, a scout, a sale, a transfer answered, or boot — and skips ones
/// already unlocked.
///
/// This is eighty-odd PREDICATES over the save, and that is the whole risk: each
/// takes one line to write and one line to get subtly wrong, and none of it is
/// visible until a player reports a trophy that will not unlock. Every one of them
/// is fired against a crafted state in `test/engine/achievements_parity_test.dart`
/// and compared with the JS.
///
/// ICONS. Four of these are raw HTML/SVG strings in the JS, which a Flutter data
/// file has no business carrying — they are named through [Achievement.iconAsset]
/// instead, for the UI to draw in M3. The other seventy-seven are plain emoji and
/// stay as text.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/players.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;
List<Object?> _list(Object? v) => v is List ? v : const [];
bool _flag(Object? v) => v == true;

/// What happened, as the engine reports it. `boot` is the catch-all sweep.
typedef AchievementEvent = ({String type, Map<String, dynamic>? data});

/// A countable goal's state, shown as a bar on a locked tile.
typedef AchievementProgress = ({num current, num target});

/// A localised description for an achievement that has been earned, when the
/// earning carries a detail worth naming.
typedef UnlockedDescription = ({String i18nKey, Map<String, Object?> params});

/// One achievement.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.check,
    this.icon,
    this.iconAsset,
    this.progress,
    this.progressText,
    this.availability,
    this.availabilityKey,
    this.descriptionWhenUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final String category;

  /// True when the achievement is currently met.
  final bool Function(Map<String, dynamic>? state, AchievementEvent event) check;

  /// A plain emoji, for all but four of these.
  final String? icon;

  /// Names a drawn icon where the JS embedded markup: `coin` or `wcTrophy`.
  final String? iconAsset;

  /// Progress toward a countable goal, for the bar on a locked tile.
  final AchievementProgress Function(Map<String, dynamic>? state)? progress;

  /// Overrides the bar's label where a percentage reads better than a count.
  final String Function(Map<String, dynamic>? state)? progressText;

  /// When this could be earned. Once an event closes it becomes un-earnable for
  /// anyone who missed it, so the window is stated plainly.
  final String? availability;
  final String? availabilityKey;

  /// A richer description once earned, when the earning carries a detail — which
  /// nation you won the International Cup with, say. Null when there is nothing
  /// extra to say.
  final UnlockedDescription? Function(Map<String, dynamic>? state)?
      descriptionWhenUnlocked;
}

/// The ladder, bottom to top. Achievement checks compare POSITION in this list,
/// not the id, so "at or past" works.
const List<String> _divOrder = [
  'sunday_league',
  'amateur_cup',
  'regional_league',
  'national_league',
  'elite_league',
  'continental',
  'champions_cup',
];

List<Object?> _cells(Map<String, dynamic>? state) =>
    _list(_map(state?['grid'])?['cells']);

bool _hasVeteranInGrid(Map<String, dynamic>? state, int minSeasons) {
  for (final c in _cells(state)) {
    if ((_num(_map(c)?['seasonsPlayed']) ?? 0) >= minSeasons) return true;
  }
  return false;
}

bool _hasAssetTierAtLeast(Map<String, dynamic>? state, int minTier) {
  for (final a in (_map(state?['clubAssets']) ?? const {}).values) {
    if (_flag(_map(a)?['owned']) && (_num(_map(a)?['tier']) ?? 0) >= minTier) {
      return true;
    }
  }
  return false;
}

int _divisionIndex(Map<String, dynamic>? state) =>
    _divOrder.indexOf('${_map(state?['progression'])?['currentDivision']}');

bool _atOrPast(Map<String, dynamic>? state, String divId) {
  final current = _divisionIndex(state);
  final target = _divOrder.indexOf(divId);
  return current >= 0 && target >= 0 && current >= target;
}

/// The high-water mark, falling back to the live balance. Null-coalescing, so a
/// recorded zero stops the fallback.
num _coinsProgress(Map<String, dynamic>? state) =>
    _num(_map(state?['stats'])?['maxCoinsReached']) ??
    _num(_map(state?['resources'])?['fanCoins']) ??
    0;

bool _coinsReached(Map<String, dynamic>? state, num threshold) =>
    _coinsProgress(state) >= threshold;

bool _hasAllClubCategories(Map<String, dynamic>? state) {
  final assets = _map(state?['clubAssets']);
  for (final cat in AssetCategory.all) {
    if (!_flag(_map(assets?[cat])?['owned'])) return false;
  }
  return true;
}

num _maxVeteranSeasons(Map<String, dynamic>? state) {
  num max = 0;
  for (final c in _cells(state)) {
    final s = _num(_map(c)?['seasonsPlayed']) ?? 0;
    if (s > max) max = s;
  }
  return max;
}

num _maxOwnedAssetTier(Map<String, dynamic>? state) {
  num max = 0;
  for (final a in (_map(state?['clubAssets']) ?? const {}).values) {
    final tier = _num(_map(a)?['tier']) ?? 0;
    if (_flag(_map(a)?['owned']) && tier > max) max = tier;
  }
  return max;
}

int _ownedCategoryCount(Map<String, dynamic>? state) {
  var n = 0;
  for (final a in (_map(state?['clubAssets']) ?? const {}).values) {
    if (_flag(_map(a)?['owned'])) n++;
  }
  return n;
}

num _cupsWonCount(Map<String, dynamic>? state) {
  final career = _num(_map(state?['careerStats'])?['cupWins']);
  if (career != null) return career;
  var n = 0;
  for (final h in _list(_map(_map(state?['progression'])?['cups'])?['history'])) {
    if (_map(h)?['outcome'] == 'won') n++;
  }
  return n;
}

int _countSponsored(Map<String, dynamic>? state) {
  var n = 0;
  for (final c in _cells(state)) {
    if (_map(c)?['sponsor'] != null) n++;
  }
  return n;
}

num _careerMatchesWon(Map<String, dynamic>? state) =>
    _num(_map(state?['careerStats'])?['matchesWon']) ??
    _num(_map(state?['progression'])?['matchesWon']) ??
    0;

num _careerTotalMerges(Map<String, dynamic>? state) =>
    _num(_map(state?['careerStats'])?['totalMerges']) ??
    _num(_map(state?['stats'])?['totalMerges']) ??
    0;

/// A stat off the save, defaulting to zero.
num _stat(Map<String, dynamic>? state, String key) =>
    _num(_map(state?['stats'])?[key]) ?? 0;

num _prestigeLevel(Map<String, dynamic>? state) =>
    _num(_map(state?['prestige'])?['level']) ?? 0;

num _seasonCount(Map<String, dynamic>? state) =>
    _num(_map(state?['progression'])?['seasonCount']) ?? 0;

int _leagueTrophyCount(Map<String, dynamic>? state) =>
    _list(_map(state?['progression'])?['leagueTrophies']).length;

num _highestTier(Map<String, dynamic>? state) => _stat(state, 'highestTier');

num _hardModeWins(Map<String, dynamic>? state) =>
    _num(_map(state?['careerStats'])?['hardModeWins']) ?? 0;

num _longestStreak(Map<String, dynamic>? state) =>
    _num(_map(state?['dailyReward'])?['longestStreak']) ?? 0;

bool _isHardMode(Map<String, dynamic>? state) =>
    _flag(_map(state?['settings'])?['hardMode']);

/// Event field readers. `d` is the event's payload, absent on a boot sweep.
Map<String, dynamic>? _d(AchievementEvent e) => e.data;

/// A progress record, for the countable goals.
AchievementProgress _to(num current, num target) =>
    (current: current, target: target);

/// The catalogue.
///
/// `final`, not `const`: every entry carries a closure, and Dart has no const
/// closures. Order is the display order, and `events` is deliberately last — that
/// category only renders once the player has an unlock inside it, so keeping it at
/// the bottom preserves the surprise for anyone who has not touched a special
/// event.
final List<Achievement> achievements = [
  // ── Progression: climb the leagues ────────────────────────────────────────
  Achievement(
    id: 'reach_amateur',
    title: 'Going Amateur',
    description: 'Reach the Amateur Cup.',
    icon: '🥉',
    category: 'progression',
    check: (s, e) => _atOrPast(s, 'amateur_cup'),
  ),
  Achievement(
    id: 'reach_regional',
    title: 'Regional Glory',
    description: 'Reach the Regional League.',
    icon: '🥈',
    category: 'progression',
    check: (s, e) => _atOrPast(s, 'regional_league'),
  ),
  Achievement(
    id: 'reach_national',
    title: 'National Hero',
    description: 'Reach the National League.',
    icon: '🎖️',
    category: 'progression',
    check: (s, e) => _atOrPast(s, 'national_league'),
  ),
  Achievement(
    id: 'reach_elite',
    title: 'Elite Club',
    description: 'Reach the Elite League.',
    icon: '👑',
    category: 'progression',
    check: (s, e) => _atOrPast(s, 'elite_league'),
  ),
  Achievement(
    id: 'reach_continental',
    title: 'Continental Scene',
    description: 'Reach the Continental Cup.',
    icon: '🌍',
    category: 'progression',
    check: (s, e) => _atOrPast(s, 'continental'),
  ),
  Achievement(
    id: 'reach_champions',
    title: 'Champions Stage',
    description: 'Reach the Champions Cup.',
    icon: '🏆',
    category: 'progression',
    check: (s, e) => _atOrPast(s, 'champions_cup'),
  ),
  Achievement(
    id: 'prestige_level_1',
    title: 'Legend Reborn',
    description: 'Prestige for the first time.',
    icon: '♾️',
    category: 'progression',
    check: (s, e) => _prestigeLevel(s) >= 1,
  ),
  Achievement(
    id: 'prestige_level_3',
    title: 'Dynasty',
    description: 'Reach prestige level 3.',
    icon: '🏰',
    category: 'progression',
    check: (s, e) => _prestigeLevel(s) >= 3,
    progress: (s) => _to(_prestigeLevel(s), 3),
  ),
  Achievement(
    id: 'prestige_level_5',
    title: 'Eternal Dynasty',
    description: 'Reach prestige level 5.',
    icon: '👑',
    category: 'progression',
    check: (s, e) => _prestigeLevel(s) >= 5,
    progress: (s) => _to(_prestigeLevel(s), 5),
  ),
  Achievement(
    id: 'prestige_level_10',
    // NOTE: shares this title with `merge_to_legend`. Duplicated in the JS; see
    // docs/REMAINING.md.
    title: 'Living Legend',
    description: 'Reach prestige level 10.',
    icon: '🌟',
    category: 'progression',
    check: (s, e) => _prestigeLevel(s) >= 10,
    progress: (s) => _to(_prestigeLevel(s), 10),
  ),

  // ── Seasons ───────────────────────────────────────────────────────────────
  Achievement(
    id: 'first_promotion',
    title: 'On the Up',
    description: 'Win promotion from your first league.',
    icon: '⬆️',
    category: 'seasons',
    check: (s, e) =>
        e.type == 'season:ended' && _d(e)?['outcome'] == 'promoted',
  ),
  Achievement(
    id: 'relegated_once',
    title: 'Tasting Defeat',
    description: 'Suffer a relegation. It happens to the best.',
    icon: '⬇️',
    category: 'seasons',
    check: (s, e) =>
        e.type == 'season:ended' && _d(e)?['outcome'] == 'relegated',
  ),
  Achievement(
    id: 'first_league_title',
    title: 'Trophy Cabinet',
    description: 'Win your first league title.',
    icon: '🥇',
    category: 'seasons',
    check: (s, e) => _leagueTrophyCount(s) >= 1,
  ),
  Achievement(
    id: 'five_league_titles',
    title: 'Silverware Collector',
    description: 'Win 5 league titles across your career.',
    icon: '🎗️',
    category: 'seasons',
    check: (s, e) => _leagueTrophyCount(s) >= 5,
    progress: (s) => _to(_leagueTrophyCount(s), 5),
  ),
  Achievement(
    id: 'play_5_seasons',
    title: 'Rookie Manager',
    description: 'Play through 5 seasons.',
    icon: '📅',
    category: 'seasons',
    check: (s, e) => _seasonCount(s) >= 5,
    progress: (s) => _to(_seasonCount(s), 5),
  ),
  Achievement(
    id: 'play_10_seasons',
    title: 'Seasoned Manager',
    description: 'Play through 10 seasons.',
    icon: '📆',
    category: 'seasons',
    check: (s, e) => _seasonCount(s) >= 10,
    progress: (s) => _to(_seasonCount(s), 10),
  ),
  Achievement(
    id: 'play_20_seasons',
    title: 'Veteran Manager',
    description: 'Play through 20 seasons.',
    icon: '🗓️',
    category: 'seasons',
    check: (s, e) => _seasonCount(s) >= 20,
    progress: (s) => _to(_seasonCount(s), 20),
  ),
  Achievement(
    id: 'win_league_undefeated',
    title: 'Invincibles',
    description: 'Win a league unbeaten (1st with zero losses).',
    icon: '🛡️',
    category: 'seasons',
    check: (s, e) =>
        e.type == 'season:ended' &&
        _d(e)?['position'] == 1 &&
        (_num(_d(e)?['seasonLosses']) ?? _num(_d(e)?['losses']) ?? -1) == 0,
  ),

  // ── Cups ──────────────────────────────────────────────────────────────────
  Achievement(
    id: 'first_cup_win',
    title: 'Cup Glory',
    description: 'Win your first cup competition.',
    icon: '🏆',
    category: 'seasons',
    check: (s, e) => _cupsWonCount(s) >= 1,
  ),
  Achievement(
    id: 'cup_treble',
    title: 'Treble Winner',
    description: 'Win 3 cups across your career.',
    icon: '🎖️',
    category: 'seasons',
    check: (s, e) => _cupsWonCount(s) >= 3,
    progress: (s) => _to(_cupsWonCount(s), 3),
  ),
  Achievement(
    id: 'cup_dynasty',
    title: 'Cup Dynasty',
    description: 'Win 10 cups across your career.',
    icon: '👑',
    category: 'seasons',
    check: (s, e) => _cupsWonCount(s) >= 10,
    progress: (s) => _to(_cupsWonCount(s), 10),
  ),

  // ── Merges ────────────────────────────────────────────────────────────────
  Achievement(
    id: 'first_merge',
    title: 'First Merge',
    description: 'Merge any two matching cards.',
    icon: '✨',
    category: 'merges',
    check: (s, e) => e.type == 'merge:happened' || _careerTotalMerges(s) >= 1,
  ),
  Achievement(
    id: 'merge_50',
    title: 'Merge Enthusiast',
    description: 'Perform 50 merges.',
    icon: '🔀',
    category: 'merges',
    check: (s, e) => _careerTotalMerges(s) >= 50,
    progress: (s) => _to(_careerTotalMerges(s), 50),
  ),
  Achievement(
    id: 'merge_200',
    title: 'Merge Master',
    description: 'Perform 200 merges.',
    icon: '⚡',
    category: 'merges',
    check: (s, e) => _careerTotalMerges(s) >= 200,
    progress: (s) => _to(_careerTotalMerges(s), 200),
  ),
  Achievement(
    id: 'merge_500',
    title: 'Merge Grandmaster',
    description: 'Perform 500 merges.',
    icon: '🎭',
    category: 'merges',
    check: (s, e) => _careerTotalMerges(s) >= 500,
    progress: (s) => _to(_careerTotalMerges(s), 500),
  ),
  Achievement(
    id: 'merge_to_silver',
    title: 'Silver Touch',
    description: 'Create a Silver Rising (tier 3) player.',
    icon: '⚪',
    category: 'merges',
    check: (s, e) => _highestTier(s) >= 3,
    progress: (s) => _to(_highestTier(s), 3),
  ),
  Achievement(
    id: 'merge_to_gold',
    title: 'Solid Gold',
    description: 'Create a Gold Elite (tier 5) player.',
    icon: '🟡',
    category: 'merges',
    check: (s, e) => _highestTier(s) >= 5,
    progress: (s) => _to(_highestTier(s), 5),
  ),
  Achievement(
    id: 'merge_to_superstar',
    title: 'Superstar',
    description: 'Create a Gold Superstar (tier 6) player.',
    icon: '🟠',
    category: 'merges',
    check: (s, e) => _highestTier(s) >= 6,
    progress: (s) => _to(_highestTier(s), 6),
  ),
  Achievement(
    id: 'merge_to_legend',
    // NOTE: shares this title with `prestige_level_10`. See docs/REMAINING.md.
    title: 'Living Legend',
    description: 'Create a Legendary Icon (tier 7) player.',
    icon: '🟣',
    category: 'merges',
    check: (s, e) => _highestTier(s) >= 7,
    progress: (s) => _to(_highestTier(s), 7),
  ),
  Achievement(
    id: 'merge_to_world',
    title: 'World Class',
    description: 'Create a World Legend (tier 8) player.',
    icon: '🌐',
    category: 'merges',
    check: (s, e) => _highestTier(s) >= 8,
    progress: (s) => _to(_highestTier(s), 8),
  ),

  // ── Matches ───────────────────────────────────────────────────────────────
  Achievement(
    id: 'first_win',
    title: 'First Win',
    description: 'Win your first match.',
    icon: '🏅',
    category: 'progression',
    check: (s, e) =>
        (e.type == 'match:complete' && _flag(_d(e)?['won'])) ||
        _careerMatchesWon(s) >= 1,
  ),
  Achievement(
    id: 'win_25_matches',
    title: 'Winning Habit',
    description: 'Win 25 matches.',
    icon: '✅',
    category: 'progression',
    check: (s, e) => _careerMatchesWon(s) >= 25,
    progress: (s) => _to(_careerMatchesWon(s), 25),
  ),
  Achievement(
    id: 'win_100_matches',
    title: 'Century Maker',
    description: 'Win 100 matches.',
    icon: '💯',
    category: 'progression',
    check: (s, e) => _careerMatchesWon(s) >= 100,
    progress: (s) => _to(_careerMatchesWon(s), 100),
  ),
  Achievement(
    id: 'win_500_matches',
    title: 'Match Mileage',
    description: 'Win 500 matches.',
    icon: '🎯',
    category: 'progression',
    check: (s, e) => _careerMatchesWon(s) >= 500,
    progress: (s) => _to(_careerMatchesWon(s), 500),
  ),
  Achievement(
    id: 'comeback_win',
    title: 'Comeback Kings',
    description: 'Win a match after being behind at half time.',
    icon: '🔥',
    category: 'weird',
    check: (s, e) =>
        e.type == 'match:complete' &&
        _flag(_d(e)?['won']) &&
        _flag(_d(e)?['wasBehindAtHalftime']),
  ),
  Achievement(
    id: 'tactician',
    title: 'Tactician',
    description: 'Change tactics during a match for the first time.',
    icon: '🧠',
    category: 'weird',
    check: (s, e) =>
        e.type == 'match:complete' && _flag(_d(e)?['strategyChanged']),
  ),
  Achievement(
    id: 'mind_games',
    title: 'Mind Games',
    description: 'Win a match after changing your tactics mid-game.',
    icon: '♟️',
    category: 'weird',
    check: (s, e) =>
        e.type == 'match:complete' &&
        _flag(_d(e)?['won']) &&
        _flag(_d(e)?['strategyChanged']),
  ),
  Achievement(
    id: 'gaffers_call',
    title: "Gaffer's Call",
    description: "Follow the coach's suggestion and win the match.",
    icon: '🎙️',
    category: 'weird',
    check: (s, e) =>
        e.type == 'match:complete' &&
        _flag(_d(e)?['won']) &&
        _flag(_d(e)?['followedCoachSuggestion']),
  ),
  Achievement(
    id: 'iron_curtain',
    title: 'Iron Curtain',
    description: 'Win a match using Park the Bus without conceding.',
    icon: '🧱',
    category: 'weird',
    check: (s, e) =>
        e.type == 'match:complete' &&
        _flag(_d(e)?['won']) &&
        (_num(_d(e)?['theirGoals']) ?? _num(_d(e)?['awayGoals'])) == 0 &&
        _list(_d(e)?['strategiesUsed']).contains('parkTheBus'),
  ),

  // ── Pro mode ──────────────────────────────────────────────────────────────
  Achievement(
    id: 'hard_debut',
    title: 'Into the Deep End',
    description: 'Switch your club to Pro mode.',
    icon: '🔥',
    category: 'hardmode',
    check: (s, e) => _isHardMode(s),
  ),
  Achievement(
    id: 'hard_first_win',
    title: 'No Hand-Holding',
    description: 'Win a match in Pro mode.',
    icon: '🥊',
    category: 'hardmode',
    check: (s, e) =>
        _isHardMode(s) &&
        e.type == 'match:complete' &&
        _flag(_d(e)?['won']),
  ),
  Achievement(
    id: 'hard_marathon',
    title: 'Marathon Legs',
    description: 'Have an Iron Lungs player in your squad.',
    icon: '🫁',
    category: 'hardmode',
    check: (s, e) {
      for (final c in _cells(s)) {
        if (_map(_map(c)?['trait'])?['id'] == 'iron_lungs') return true;
      }
      return false;
    },
  ),
  Achievement(
    id: 'hard_title',
    title: 'Hard-Won Glory',
    description: 'Win a league title in Pro mode.',
    icon: '🏆',
    category: 'hardmode',
    check: (s, e) =>
        _isHardMode(s) &&
        e.type == 'season:ended' &&
        _d(e)?['position'] == 1,
  ),
  Achievement(
    id: 'hard_champions',
    title: 'Ultimate Glory',
    description: 'Win the Champions League in Pro mode.',
    icon: '🌟',
    category: 'hardmode',
    check: (s, e) =>
        _isHardMode(s) &&
        e.type == 'season:ended' &&
        _d(e)?['position'] == 1 &&
        _d(e)?['oldDivision'] == 'champions_cup',
  ),
  Achievement(
    id: 'hard_25_wins',
    title: 'Iron Manager',
    description: 'Win 25 matches in Pro mode.',
    icon: '💪',
    category: 'hardmode',
    check: (s, e) => _hardModeWins(s) >= 25,
    progress: (s) => _to(_hardModeWins(s), 25),
  ),
  Achievement(
    id: 'hard_100_wins',
    title: 'Forged in Fire',
    description: 'Win 100 matches in Pro mode.',
    icon: '🛠️',
    category: 'hardmode',
    check: (s, e) => _hardModeWins(s) >= 100,
    progress: (s) => _to(_hardModeWins(s), 100),
  ),

  // ── Squad and sponsorship ─────────────────────────────────────────────────
  Achievement(
    id: 'use_veteran_7s',
    title: 'Loyal Servant',
    description: 'Field a player with 7+ seasons of service.',
    icon: '🧓',
    category: 'squad',
    check: (s, e) => _hasVeteranInGrid(s, 7),
    progress: (s) => _to(_maxVeteranSeasons(s), 7),
  ),
  Achievement(
    id: 'use_veteran_10s',
    title: 'Loyalty Rewarded',
    description: 'Field a player with 10+ seasons of service.',
    icon: '👴',
    category: 'squad',
    check: (s, e) => _hasVeteranInGrid(s, 10),
    progress: (s) => _to(_maxVeteranSeasons(s), 10),
  ),
  Achievement(
    id: 'full_squad_16',
    title: 'Full Squad',
    description: 'Have 16 players on the squad grid at once.',
    icon: '👥',
    category: 'squad',
    check: (s, e) => _cells(s).where((c) => c != null).length >= 16,
    progress: (s) => _to(_cells(s).where((c) => c != null).length, 16),
  ),
  Achievement(
    id: 'first_sponsor',
    title: 'Commercial Appeal',
    description: 'Sponsor your first player.',
    icon: '🤝',
    category: 'squad',
    check: (s, e) => _countSponsored(s) >= 1,
  ),
  Achievement(
    id: 'three_sponsors',
    title: 'Brand Portfolio',
    description: 'Have 3 sponsored players at once.',
    icon: '📣',
    category: 'squad',
    check: (s, e) => _countSponsored(s) >= 3,
    progress: (s) => _to(_countSponsored(s), 3),
  ),
  Achievement(
    id: 'scout_25',
    title: 'Scouting Network',
    description: 'Scout 25 players.',
    icon: '🔍',
    category: 'squad',
    check: (s, e) => _stat(s, 'totalScouts') >= 25,
    progress: (s) => _to(_stat(s, 'totalScouts'), 25),
  ),
  Achievement(
    id: 'scout_100',
    title: 'Super Scout',
    description: 'Scout 100 players.',
    icon: '🔭',
    category: 'squad',
    check: (s, e) => _stat(s, 'totalScouts') >= 100,
    progress: (s) => _to(_stat(s, 'totalScouts'), 100),
  ),

  // ── Club assets ───────────────────────────────────────────────────────────
  Achievement(
    id: 'own_tier3_asset',
    title: 'Investing In Bricks',
    description: 'Own a tier 3 club asset.',
    icon: '🏗️',
    category: 'squad',
    check: (s, e) => _hasAssetTierAtLeast(s, 3),
    progress: (s) => _to(_maxOwnedAssetTier(s), 3),
  ),
  Achievement(
    id: 'own_tier6_asset',
    title: 'Empire Builder',
    description: 'Own a tier 6 club asset.',
    icon: '🏟️',
    category: 'squad',
    check: (s, e) => _hasAssetTierAtLeast(s, 6),
    progress: (s) => _to(_maxOwnedAssetTier(s), 6),
  ),
  Achievement(
    id: 'own_all_categories',
    title: 'Complete Operation',
    description: 'Own at least one of every club asset type.',
    icon: '🏢',
    category: 'squad',
    check: (s, e) => _hasAllClubCategories(s),
    progress: (s) => _to(_ownedCategoryCount(s), AssetCategory.all.length),
  ),

  // ── Economy ───────────────────────────────────────────────────────────────
  Achievement(
    id: 'coins_10k',
    title: 'Making Bank',
    description: 'Accumulate 10,000 coins.',
    iconAsset: 'coin',
    category: 'weird',
    check: (s, e) => _coinsReached(s, 10000),
    progress: (s) => _to(_coinsProgress(s), 10000),
  ),
  Achievement(
    id: 'coins_100k',
    title: 'Fan-Coin Mogul',
    description: 'Accumulate 100,000 coins.',
    iconAsset: 'coin',
    category: 'weird',
    check: (s, e) => _coinsReached(s, 100000),
    progress: (s) => _to(_coinsProgress(s), 100000),
  ),
  Achievement(
    id: 'coins_1m',
    title: 'Millionaire Owner',
    description: 'Accumulate 1,000,000 coins.',
    iconAsset: 'coin',
    category: 'weird',
    check: (s, e) => _coinsReached(s, 1000000),
    progress: (s) => _to(_coinsProgress(s), 1000000),
    progressText: (s) =>
        '${_pct(_coinsProgress(s) / 1000000)}% / 1M',
  ),
  Achievement(
    id: 'coins_1b',
    title: 'Billionaire Boss',
    description: 'Accumulate 1,000,000,000 coins.',
    icon: '💎',
    category: 'weird',
    check: (s, e) => _coinsReached(s, 1000000000),
    progress: (s) => _to(_coinsProgress(s), 1000000000),
    progressText: (s) =>
        '${_pct(_coinsProgress(s) / 1000000000)}% / 1B',
  ),

  // ── Transfers and rivalries ───────────────────────────────────────────────
  Achievement(
    id: 'first_transfer_accept',
    title: 'Cashed In',
    description: 'Accept a rival transfer offer.',
    icon: '💼',
    category: 'weird',
    check: (s, e) => _stat(s, 'transfersAccepted') >= 1,
  ),
  Achievement(
    id: 'five_transfer_accept',
    title: 'Player Trader',
    description: 'Accept 5 rival transfer offers.',
    icon: '🤑',
    category: 'weird',
    check: (s, e) => _stat(s, 'transfersAccepted') >= 5,
    progress: (s) => _to(_stat(s, 'transfersAccepted'), 5),
  ),
  Achievement(
    id: 'first_transfer_decline',
    title: 'Not For Sale',
    description: 'Decline a rival transfer offer.',
    icon: '🚫',
    category: 'weird',
    check: (s, e) => _stat(s, 'transfersDeclined') >= 1,
  ),
  Achievement(
    id: 'first_sponsor_decline',
    title: 'Integrity First',
    description: 'Decline a sponsorship offer.',
    icon: '🙅',
    category: 'weird',
    check: (s, e) => _stat(s, 'sponsorsDeclined') >= 1,
  ),
  Achievement(
    id: 'grudge_revenge',
    title: 'Revenge Served',
    description: 'Beat a rival holding a grudge against you.',
    icon: '😤',
    category: 'weird',
    check: (s, e) =>
        e.type == 'match:complete' &&
        _flag(_d(e)?['won']) &&
        (_num(_d(e)?['grudgeBoost']) ?? 0) > 0,
  ),
  Achievement(
    id: 'sell_tier5_player',
    title: 'Big Money Move',
    description: 'Sell a tier 5 or higher player.',
    icon: '💸',
    category: 'weird',
    check: (s, e) {
      if (e.type != 'player:sold') return false;
      // The event may carry the definition itself, or just its id.
      final tier = _num(_map(_d(e)?['def'])?['tier']) ??
          getPlayerDef(_d(e)?['definitionId'] as String?)?.tier;
      return tier != null && tier >= 5;
    },
  ),

  // ── Mini-games ────────────────────────────────────────────────────────────
  Achievement(
    id: 'penalty_perfect',
    title: 'Spot Kick Specialist',
    description: 'Score 5/5 in a round of Penalty Training.',
    icon: '⚽',
    category: 'weird',
    check: (s, e) => _stat(s, 'perfectPenalties') >= 1,
  ),
  Achievement(
    id: 'penalty_ten_rounds',
    title: 'Penalty Regular',
    description: 'Play 10 rounds of Penalty Training.',
    icon: '🥅',
    category: 'weird',
    check: (s, e) => _stat(s, 'penaltyRounds') >= 10,
    progress: (s) => _to(_stat(s, 'penaltyRounds'), 10),
  ),
  Achievement(
    id: 'training_perfect',
    title: 'Drill Sergeant',
    description: 'Ace every drill in a training session.',
    icon: '🏃',
    category: 'weird',
    check: (s, e) => _stat(s, 'perfectTrainings') >= 1,
  ),
  Achievement(
    id: 'training_streak_10',
    title: 'Dedicated Coach',
    description: 'Reach a 10-day login streak.',
    icon: '💪',
    category: 'weird',
    check: (s, e) => _longestStreak(s) >= 10,
    progress: (s) => _to(_longestStreak(s), 10),
  ),
  Achievement(
    id: 'training_streak_30',
    title: 'Iron Discipline',
    description: 'Reach a 30-day login streak.',
    icon: '🦾',
    category: 'weird',
    check: (s, e) => _longestStreak(s) >= 30,
    progress: (s) => _to(_longestStreak(s), 30),
  ),
  Achievement(
    id: 'through_ball_perfect',
    title: 'Dead-Ball Specialist',
    description: 'Hit 5/5 in a Through Ball round.',
    icon: '🎪',
    category: 'weird',
    check: (s, e) => _stat(s, 'perfectThroughBalls') >= 1,
  ),
  Achievement(
    id: 'whack_clean',
    title: 'Friend of the Steward',
    description: 'Finish Pitch Invaders without tapping a steward.',
    icon: '👮',
    category: 'weird',
    check: (s, e) => _stat(s, 'whackCleanRounds') >= 1,
  ),
  Achievement(
    id: 'whack_dogs_10',
    title: 'Dog on the Pitch',
    description: 'Catch 10 dogs in Pitch Invaders.',
    icon: '🐕',
    category: 'weird',
    check: (s, e) => _stat(s, 'whackDogs') >= 10,
    progress: (s) => _to(_stat(s, 'whackDogs'), 10),
  ),
  Achievement(
    id: 'boot_room_cascade',
    title: 'Chain Reaction',
    description: 'Set off a four-deep chain in the Boot Room.',
    icon: '👟',
    category: 'weird',
    check: (s, e) => _stat(s, 'bootRoomBestCascade') >= 4,
  ),

  // ── Events ────────────────────────────────────────────────────────────────
  // One achievement per event. The sub-feats — won five times, won as Bolivia —
  // live in the event definitions as in-event challenges paying claimable coins.
  Achievement(
    id: 'wc_win',
    title: 'International Cup 2026',
    description: 'Win the International Cup.',
    availability: 'During International Cup 2026 event',
    availabilityKey: 'ach.availability.wc_win',
    iconAsset: 'wcTrophy',
    category: 'events',
    check: (s, e) {
      // The primary record is set by the event cup engine; the fallback covers
      // trophies written by older saves.
      if (_map(_map(_map(s?['events'])?['progress'])?['wc2026'])?['firstWin'] !=
          null) {
        return true;
      }
      for (final t in _list(_map(s?['progression'])?['leagueTrophies'])) {
        if (_flag(_map(t)?['event']) && _map(t)?['eventId'] == 'wc2026') {
          return true;
        }
      }
      return false;
    },
    descriptionWhenUnlocked: (s) {
      final progress = _map(_map(_map(s?['events'])?['progress'])?['wc2026']);
      Object? nation = _map(progress?['firstWin'])?['playerNation'];
      if (nation == null) {
        for (final t in _list(_map(s?['progression'])?['leagueTrophies'])) {
          if (_flag(_map(t)?['event']) && _map(t)?['eventId'] == 'wc2026') {
            nation = _map(t)?['playerNation'];
            break;
          }
        }
      }
      nation ??= _map(progress?['cup'])?['playerNation'];
      if (nation == null) return null;
      return (i18nKey: 'ach.desc_won.wc_win', params: {'nation': nation});
    },
  ),

  // ── Reset and lifetime ────────────────────────────────────────────────────
  // These fire after Start New Team. The relevant stats are captured pre-wipe and
  // carried into the fresh state.
  Achievement(
    id: 'reset_first',
    title: 'Fresh Start',
    description: 'Reset your team for the first time.',
    icon: '🔄',
    category: 'reset',
    check: (s, e) => _stat(s, 'resetCount') >= 1,
  ),
  Achievement(
    id: 'reset_with_legendary',
    title: 'Goodbye, Legend',
    description: 'Reset while owning a Legendary Icon or higher.',
    icon: '👋',
    category: 'reset',
    check: (s, e) => _map(s?['stats'])?['everHadLegendaryAtReset'] == true,
  ),
  Achievement(
    id: 'reset_veteran',
    title: 'Retirement',
    description: 'Reset after 10+ seasons with your team.',
    icon: '🏖️',
    category: 'reset',
    check: (s, e) => _stat(s, 'maxSeasonsAtReset') >= 10,
  ),
  Achievement(
    id: 'reset_top_division',
    title: 'Champions No More',
    description: 'Reset while sitting in the Champions Cup.',
    icon: '🌟',
    category: 'reset',
    check: (s, e) => _map(s?['stats'])?['everResetFromTopDivision'] == true,
  ),
  Achievement(
    id: 'reset_after_prestige',
    title: 'Dynasty Rebooted',
    description: 'Reset after prestiging at least once.',
    icon: '🔃',
    category: 'reset',
    check: (s, e) => _stat(s, 'maxPrestigeLevelAtReset') >= 1,
  ),
];

/// One decimal place, capped at 100 — JS `toFixed(1)` on a clamped percentage.
String _pct(double share) {
  final capped = share * 100 > 100 ? 100.0 : share * 100;
  return capped.toStringAsFixed(1);
}

final Map<String, Achievement> _byId = {for (final a in achievements) a.id: a};

/// An achievement by id, or null.
Achievement? getAchievementDef(String? id) => id == null ? null : _byId[id];

/// Display order for the Trophy Room's sections.
const List<String> achievementCategories = [
  'progression',
  'seasons',
  'merges',
  'squad',
  'weird',
  'hardmode',
  'reset',
  'events',
];

const Map<String, String> categoryLabels = {
  'progression': 'Climbing the Ladder',
  'seasons': 'Silverware',
  'events': 'Special Events',
  'merges': 'Merge Milestones',
  'squad': 'Squad Building',
  'weird': 'Moments of Glory',
  'hardmode': 'Pro Mode',
  'reset': 'Legacy',
};
