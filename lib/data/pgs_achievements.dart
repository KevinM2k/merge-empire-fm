/// Local achievement ids mapped to Google Play Games achievement ids. Ported
/// from `../merge-empire-fc/src/data/pgsAchievements.js`.
///
/// An entry left null is silently skipped: the in-game achievement still works,
/// it simply does not appear in the Play Games overlay until it is mapped. The
/// ids come out of the Play Console after the achievement list is published, and
/// only the six league-climb ones exist there so far.
///
/// The comment beside each is the in-game title, so a Console entry can be
/// matched to its achievement without opening two files.
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
  'prestige_level_1': null, // "Legend Reborn"
  'prestige_level_3': null, // "Dynasty"
  // Seasons
  'first_promotion': null, // "On the Up"
  'relegated_once': null, // "Tasting Defeat"
  'first_league_title': null, // "Trophy Cabinet"
  'five_league_titles': null, // "Silverware Collector"
  'play_5_seasons': null, // "Rookie Manager"
  'play_10_seasons': null, // "Seasoned Manager"
  'play_20_seasons': null, // "Veteran Manager"
  'win_league_undefeated': null, // "Invincibles"
  'first_cup_win': null, // "Cup Glory"
  'cup_treble': null, // "Treble Winner"
  'cup_dynasty': null, // "Cup Dynasty"
  // Merges
  'first_merge': null, // "First Merge"
  'merge_50': null, // "Merge Enthusiast"
  'merge_200': null, // "Merge Master"
  'merge_500': null, // "Merge Grandmaster"
  'merge_to_silver': null, // "Silver Touch"
  'merge_to_gold': null, // "Solid Gold"
  'merge_to_superstar': null, // "Superstar"
  'merge_to_legend': null, // "Living Legend"
  'merge_to_world': null, // "World Class"
  // Match wins
  'first_win': null, // "First Win"
  'win_25_matches': null, // "Winning Habit"
  'win_100_matches': null, // "Century Maker"
  'win_500_matches': null, // "Match Mileage"
  // Tactics and the odd ones
  'comeback_win': null, // "Comeback Kings"
  'tactician': null, // "Tactician"
  'mind_games': null, // "Mind Games"
  'gaffers_call': null, // "Gaffer's Call"
  'iron_curtain': null, // "Iron Curtain"
  // Squad
  'use_veteran_7s': null, // "Loyal Servant"
  'use_veteran_10s': null, // "Loyalty Rewarded"
  'full_squad_16': null, // "Full Squad"
  'first_sponsor': null, // "Commercial Appeal"
  'three_sponsors': null, // "Brand Portfolio"
  'scout_25': null, // "Scouting Network"
  'scout_100': null, // "Super Scout"
  'own_tier3_asset': null, // "Investing In Bricks"
  'own_tier6_asset': null, // "Empire Builder"
  'own_all_categories': null, // "Complete Operation"
  // Economy
  'coins_10k': null, // "Making Bank"
  'coins_100k': null, // "Fan-Coin Mogul"
  'coins_1m': null, // "Millionaire Owner"
  'coins_1b': null, // "Billionaire Boss"
  // Transfers and rivalries
  'first_transfer_accept': null, // "Cashed In"
  'five_transfer_accept': null, // "Player Trader"
  'first_transfer_decline': null, // "Not For Sale"
  'first_sponsor_decline': null, // "Integrity First"
  'grudge_revenge': null, // "Revenge Served"
  'sell_tier5_player': null, // "Big Money Move"
  // Mini-games
  'penalty_perfect': null, // "Spot Kick Specialist"
  'penalty_ten_rounds': null, // "Penalty Regular"
  'training_perfect': null, // "Drill Sergeant"
  'training_streak_10': null, // "Dedicated Coach"
  'training_streak_30': null, // "Iron Discipline"
  'through_ball_perfect': null, // "Dead-Ball Specialist"
  'whack_clean': null, // "Friend of the Steward"
  'whack_dogs_10': null, // "Dog on the Pitch"
  'boot_room_cascade': null, // "Chain Reaction"
  // Events
  'wc_win': null, // "International Cup Winner"
  // Reset and prestige
  'reset_first': null, // "Fresh Start"
  'reset_with_legendary': null, // "Goodbye, Legend"
  'reset_veteran': null, // "Retirement"
  'reset_top_division': null, // "Champions No More"
  'reset_after_prestige': null, // "Dynasty Rebooted"
};

/// The Play Games id for a local achievement, or null when it has not been
/// mapped yet — which the caller treats as "do not report it".
String? pgsAchievementId(String? localId) => pgsAchievementIds[localId];
