/// Local achievement ids mapped to Google Play Games achievement ids, and the
/// Console point value each one is worth. Ported from
/// `../merge-empire-fc/src/data/pgsAchievements.js` and extended with the
/// points, which the JS had no need of — it never built the Console list.
///
/// **EVERY achievement in `achievements.dart` has a row here, including the
/// ones with no Console id yet.** Nine did not, and the effect of a missing key
/// is identical to a null one — `pgsAchievementIds[id]` answers null either way
/// and the unlock is skipped — so the gap was invisible at runtime and only
/// showed up as nine achievements quietly left out of the Console list this
/// file is the checklist for. `pgs_import_test.dart` now fails if the two files
/// disagree, in either direction.
///
/// An entry left null is silently skipped: the in-game achievement still works,
/// it simply does not appear in the Play Games overlay until it is mapped. The
/// ids come out of the Play Console once the list is published — import the zip
/// `tool/pgs/build_import.py` builds, then run `tool/pgs/sync_ids.py` to write
/// the ids back into this file. See `docs/PGS_ACHIEVEMENTS.md`.
///
/// The comment beside each is the in-game title, so a Console entry can be
/// matched to its achievement without opening two files. The order is the
/// CATALOGUE's, which is also the Console list order the import asks for.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

const Map<String, String?> pgsAchievementIds = {
  // Progression — climbing the leagues
  'reach_amateur': 'CgkIq9aYo8oOEAIQAA', // "Going Amateur"
  'reach_regional': 'CgkIq9aYo8oOEAIQAQ', // "Regional Glory"
  'reach_national': 'CgkIq9aYo8oOEAIQAg', // "National Hero"
  'reach_elite': 'CgkIq9aYo8oOEAIQAw', // "Elite Club"
  'reach_continental': 'CgkIq9aYo8oOEAIQBA', // "Continental Scene"
  'reach_champions': 'CgkIq9aYo8oOEAIQBQ', // "Champions Stage"
  'prestige_level_1': 'CgkIq9aYo8oOEAIQGg', // "Legend Reborn"
  'prestige_level_3': 'CgkIq9aYo8oOEAIQNA', // "Dynasty"
  'prestige_level_5': 'CgkIq9aYo8oOEAIQGw', // "Eternal Dynasty"
  'prestige_level_10': 'CgkIq9aYo8oOEAIQOw', // "Immortal"
  // Seasons
  'first_promotion': 'CgkIq9aYo8oOEAIQDA', // "On the Up"
  'relegated_once': 'CgkIq9aYo8oOEAIQTQ', // "Tasting Defeat"
  'first_league_title': 'CgkIq9aYo8oOEAIQDQ', // "Trophy Cabinet"
  'five_league_titles': 'CgkIq9aYo8oOEAIQFw', // "Silverware Collector"
  'play_5_seasons': 'CgkIq9aYo8oOEAIQTw', // "Rookie Manager"
  'play_10_seasons': 'CgkIq9aYo8oOEAIQHA', // "Seasoned Manager"
  'play_20_seasons': 'CgkIq9aYo8oOEAIQRA', // "Veteran Manager"
  'win_league_undefeated': 'CgkIq9aYo8oOEAIQRw', // "Invincibles"
  'first_cup_win': 'CgkIq9aYo8oOEAIQDg', // "Cup Glory"
  'cup_treble': 'CgkIq9aYo8oOEAIQOA', // "Treble Winner"
  'cup_dynasty': 'CgkIq9aYo8oOEAIQNw', // "Cup Dynasty"
  // Merges
  'first_merge': 'CgkIq9aYo8oOEAIQHw', // "First Merge"
  'merge_50': 'CgkIq9aYo8oOEAIQOg', // "Merge Enthusiast"
  'merge_200': 'CgkIq9aYo8oOEAIQUA', // "Merge Master"
  'merge_500': 'CgkIq9aYo8oOEAIQEQ', // "Merge Grandmaster"
  'merge_to_silver': 'CgkIq9aYo8oOEAIQOQ', // "Silver Touch"
  'merge_to_gold': 'CgkIq9aYo8oOEAIQCg', // "Solid Gold"
  'merge_to_superstar': 'CgkIq9aYo8oOEAIQBw', // "Superstar"
  'merge_to_legend': 'CgkIq9aYo8oOEAIQPw', // "Living Legend"
  'merge_to_world': 'CgkIq9aYo8oOEAIQPA', // "World Class"
  // Progression — climbing the leagues
  'first_win': 'CgkIq9aYo8oOEAIQSA', // "First Win"
  'win_25_matches': 'CgkIq9aYo8oOEAIQNg', // "Winning Habit"
  'win_100_matches': 'CgkIq9aYo8oOEAIQRQ', // "Century Maker"
  'win_500_matches': 'CgkIq9aYo8oOEAIQSw', // "Match Mileage"
  // Matches, tactics, money and the odd ones
  'comeback_win': 'CgkIq9aYo8oOEAIQLw', // "Comeback Kings"
  'tactician': 'CgkIq9aYo8oOEAIQMA', // "Tactician"
  'mind_games': 'CgkIq9aYo8oOEAIQTg', // "Mind Games"
  'gaffers_call': 'CgkIq9aYo8oOEAIQHQ', // "Gaffer's Call"
  'iron_curtain': 'CgkIq9aYo8oOEAIQTA', // "Iron Curtain"
  // Pro mode
  'hard_debut': 'CgkIq9aYo8oOEAIQHg', // "Into the Deep End"
  'hard_first_win': 'CgkIq9aYo8oOEAIQRg', // "No Hand-Holding"
  'hard_marathon': 'CgkIq9aYo8oOEAIQLA', // "Marathon Legs"
  'hard_title': 'CgkIq9aYo8oOEAIQDw', // "Hard-Won Glory"
  'hard_champions': 'CgkIq9aYo8oOEAIQGA', // "Ultimate Glory"
  'hard_25_wins': 'CgkIq9aYo8oOEAIQJQ', // "Iron Manager"
  'hard_100_wins': 'CgkIq9aYo8oOEAIQKQ', // "Forged in Fire"
  // Squad
  'use_veteran_7s': 'CgkIq9aYo8oOEAIQSQ', // "Loyal Servant"
  'use_veteran_10s': 'CgkIq9aYo8oOEAIQKg', // "Loyalty Rewarded"
  'full_squad_16': 'CgkIq9aYo8oOEAIQJg', // "Full Squad"
  'first_sponsor': 'CgkIq9aYo8oOEAIQNQ', // "Commercial Appeal"
  'three_sponsors': 'CgkIq9aYo8oOEAIQEA', // "Brand Portfolio"
  'scout_25': 'CgkIq9aYo8oOEAIQQg', // "Scouting Network"
  'scout_100': 'CgkIq9aYo8oOEAIQCA', // "Super Scout"
  'own_tier3_asset': 'CgkIq9aYo8oOEAIQSg', // "Investing In Bricks"
  'own_tier6_asset': 'CgkIq9aYo8oOEAIQQA', // "Empire Builder"
  'own_all_categories': 'CgkIq9aYo8oOEAIQQw', // "Complete Operation"
  // Matches, tactics, money and the odd ones
  'coins_10k': 'CgkIq9aYo8oOEAIQJw', // "Making Bank"
  'coins_100k': 'CgkIq9aYo8oOEAIQIA', // "Fan-Coin Mogul"
  'coins_1m': 'CgkIq9aYo8oOEAIQFg', // "Millionaire Owner"
  'coins_1b': 'CgkIq9aYo8oOEAIQLQ', // "Billionaire Boss"
  'first_transfer_accept': 'CgkIq9aYo8oOEAIQIw', // "Cashed In"
  'five_transfer_accept': 'CgkIq9aYo8oOEAIQKA', // "Player Trader"
  'first_transfer_decline': 'CgkIq9aYo8oOEAIQKw', // "Not For Sale"
  'first_sponsor_decline': 'CgkIq9aYo8oOEAIQLg', // "Integrity First"
  'grudge_revenge': 'CgkIq9aYo8oOEAIQGQ', // "Revenge Served"
  'sell_tier5_player': 'CgkIq9aYo8oOEAIQCQ', // "Big Money Move"
  'penalty_perfect': 'CgkIq9aYo8oOEAIQPQ', // "Spot Kick Specialist"
  'penalty_ten_rounds': 'CgkIq9aYo8oOEAIQIQ', // "Penalty Regular"
  'training_perfect': 'CgkIq9aYo8oOEAIQEw', // "Drill Sergeant"
  'training_streak_10': 'CgkIq9aYo8oOEAIQCw', // "Dedicated Coach"
  'training_streak_30': 'CgkIq9aYo8oOEAIQFQ', // "Iron Discipline"
  'through_ball_perfect': 'CgkIq9aYo8oOEAIQFA', // "Dead-Ball Specialist"
  'whack_clean': 'CgkIq9aYo8oOEAIQQQ', // "Friend of the Steward"
  'whack_dogs_10': 'CgkIq9aYo8oOEAIQMQ', // "Dog on the Pitch"
  'boot_room_cascade': 'CgkIq9aYo8oOEAIQMw', // "Chain Reaction"
  // Events
  'wc_win': 'CgkIq9aYo8oOEAIQMg', // "International Cup 2026"
  // Reset and prestige
  'reset_first': 'CgkIq9aYo8oOEAIQUQ', // "Fresh Start"
  'reset_with_legendary': 'CgkIq9aYo8oOEAIQEg', // "Goodbye, Legend"
  'reset_veteran': 'CgkIq9aYo8oOEAIQPg', // "Retirement"
  'reset_top_division': 'CgkIq9aYo8oOEAIQJA', // "Champions No More"
  'reset_after_prestige': 'CgkIq9aYo8oOEAIQIg', // "Dynasty Rebooted"
};

/// What each achievement is worth in Play Games XP points.
///
/// **Play caps the whole game at 2,000 points**, each value a multiple of 5
/// between 5 and 200, and Google's own advice is to keep some back for
/// achievements added later — so these 81 spend 1680 and leave 320. The bands come
/// off the in-game coin reward in `achievement_engine.dart` (a 10,000-coin
/// achievement is a 50-point one, a 100-coin achievement a 5-point one), with
/// hand-set values where the coin reward does not describe the difficulty:
/// prestige pays no coins at all by design, and Pro mode pays the flat default.
///
/// This is Console configuration rather than game data — nothing in `lib/`
/// reads it — but it lives beside the id map because it is the same list, kept
/// in the same order, and a second file would be a second thing to forget.
/// `pgs_import_test.dart` enforces the cap.
const Map<String, int> pgsAchievementPoints = {
  // Progression — climbing the leagues
  'reach_amateur': 10, // "Going Amateur"
  'reach_regional': 15, // "Regional Glory"
  'reach_national': 20, // "National Hero"
  'reach_elite': 30, // "Elite Club"
  'reach_continental': 40, // "Continental Scene"
  'reach_champions': 50, // "Champions Stage"
  'prestige_level_1': 25, // "Legend Reborn"
  'prestige_level_3': 40, // "Dynasty"
  'prestige_level_5': 50, // "Eternal Dynasty"
  'prestige_level_10': 75, // "Immortal"
  // Seasons
  'first_promotion': 10, // "On the Up"
  'relegated_once': 5, // "Tasting Defeat"
  'first_league_title': 20, // "Trophy Cabinet"
  'five_league_titles': 30, // "Silverware Collector"
  'play_5_seasons': 10, // "Rookie Manager"
  'play_10_seasons': 15, // "Seasoned Manager"
  'play_20_seasons': 20, // "Veteran Manager"
  'win_league_undefeated': 40, // "Invincibles"
  'first_cup_win': 15, // "Cup Glory"
  'cup_treble': 40, // "Treble Winner"
  'cup_dynasty': 50, // "Cup Dynasty"
  // Merges
  'first_merge': 5, // "First Merge"
  'merge_50': 10, // "Merge Enthusiast"
  'merge_200': 15, // "Merge Master"
  'merge_500': 20, // "Merge Grandmaster"
  'merge_to_silver': 10, // "Silver Touch"
  'merge_to_gold': 15, // "Solid Gold"
  'merge_to_superstar': 20, // "Superstar"
  'merge_to_legend': 30, // "Living Legend"
  'merge_to_world': 40, // "World Class"
  // Progression — climbing the leagues
  'first_win': 5, // "First Win"
  'win_25_matches': 10, // "Winning Habit"
  'win_100_matches': 20, // "Century Maker"
  'win_500_matches': 40, // "Match Mileage"
  // Matches, tactics, money and the odd ones
  'comeback_win': 15, // "Comeback Kings"
  'tactician': 10, // "Tactician"
  'mind_games': 10, // "Mind Games"
  'gaffers_call': 10, // "Gaffer's Call"
  'iron_curtain': 15, // "Iron Curtain"
  // Pro mode
  'hard_debut': 10, // "Into the Deep End"
  'hard_first_win': 15, // "No Hand-Holding"
  'hard_marathon': 30, // "Marathon Legs"
  'hard_title': 40, // "Hard-Won Glory"
  'hard_champions': 60, // "Ultimate Glory"
  'hard_25_wins': 25, // "Iron Manager"
  'hard_100_wins': 50, // "Forged in Fire"
  // Squad
  'use_veteran_7s': 10, // "Loyal Servant"
  'use_veteran_10s': 20, // "Loyalty Rewarded"
  'full_squad_16': 15, // "Full Squad"
  'first_sponsor': 10, // "Commercial Appeal"
  'three_sponsors': 15, // "Brand Portfolio"
  'scout_25': 10, // "Scouting Network"
  'scout_100': 15, // "Super Scout"
  'own_tier3_asset': 10, // "Investing In Bricks"
  'own_tier6_asset': 20, // "Empire Builder"
  'own_all_categories': 30, // "Complete Operation"
  // Matches, tactics, money and the odd ones
  'coins_10k': 15, // "Making Bank"
  'coins_100k': 30, // "Fan-Coin Mogul"
  'coins_1m': 50, // "Millionaire Owner"
  'coins_1b': 50, // "Billionaire Boss"
  'first_transfer_accept': 10, // "Cashed In"
  'five_transfer_accept': 15, // "Player Trader"
  'first_transfer_decline': 5, // "Not For Sale"
  'first_sponsor_decline': 5, // "Integrity First"
  'grudge_revenge': 15, // "Revenge Served"
  'sell_tier5_player': 15, // "Big Money Move"
  'penalty_perfect': 10, // "Spot Kick Specialist"
  'penalty_ten_rounds': 15, // "Penalty Regular"
  'training_perfect': 10, // "Drill Sergeant"
  'training_streak_10': 5, // "Dedicated Coach"
  'training_streak_30': 5, // "Iron Discipline"
  'through_ball_perfect': 10, // "Dead-Ball Specialist"
  'whack_clean': 10, // "Friend of the Steward"
  'whack_dogs_10': 10, // "Dog on the Pitch"
  'boot_room_cascade': 10, // "Chain Reaction"
  // Events
  'wc_win': 30, // "International Cup 2026"
  // Reset and prestige
  'reset_first': 5, // "Fresh Start"
  'reset_with_legendary': 10, // "Goodbye, Legend"
  'reset_veteran': 10, // "Retirement"
  'reset_top_division': 15, // "Champions No More"
  'reset_after_prestige': 20, // "Dynasty Rebooted"
};

/// The Play Games id for a local achievement, or null when it has not been
/// mapped yet — which the caller treats as "do not report it".
String? pgsAchievementId(String? localId) => pgsAchievementIds[localId];
