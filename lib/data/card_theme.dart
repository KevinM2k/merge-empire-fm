/// The card's per-tier palette and labels. Ported from the tables at the top of
/// `../merge-empire-fc/src/ui/components/Card.js`.
///
/// [TierTheme.accent], [TierTheme.accentLight] and [TierTheme.labelBg] are
/// SIX-DIGIT hex, always. The JS concatenates two-character alpha suffixes onto
/// them (`accent + '18'`), and a three-digit colour turns that into five-digit
/// nonsense — which is why silver cards showed no art tint and no alpha borders
/// until the shorthand was widened. A shorthand added to those three comes back
/// as a silently missing style, and a test enforces it.
///
/// GRADIENT STOPS are exempt and one of them is genuinely shorthand — tier 3's
/// `#111`. Nothing concatenates alpha onto a stop, so it is carried verbatim
/// rather than tidied: widening it would be a diff against the source for no
/// behaviour.
///
/// Deliberately Flutter-free so it runs under plain `dart test`; the widget
/// layer turns these into `Color`s.
library;

/// A tier's gradient, as its angle in degrees and its stops in order.
typedef TierGradient = ({int angleDeg, List<(String, double)> stops});

class TierTheme {
  const TierTheme({
    required this.bg,
    required this.bgLight,
    required this.accent,
    required this.accentLight,
    required this.labelBg,
  });

  /// The card body in dark mode.
  final TierGradient bg;

  /// The card body in light mode — a pale tint of the same rarity, so cards keep
  /// their identity without the heavy black that dominated the merge grid.
  /// Only the BODY changes: the rating and tier chips stay dark so their bright
  /// rarity text stays readable on top.
  final TierGradient bgLight;

  final String accent;
  final String accentLight;
  final String labelBg;
}

/// 1 through 9. Bronze to Icon.
const Map<int, String> tierLabel = {
  1: 'Bronze',
  2: 'Bronze+',
  3: 'Silver',
  4: 'Silver★',
  5: 'Gold',
  6: 'Gold★',
  7: 'Legend',
  // **NOT SHOUTED, and the spec is why they were.** `Card.js` writes these two
  // in caps while the seven below them are in title case — a DOM decision, in a
  // file whose stylesheet has a note about "WORLD CLASS" being 103px of text
  // and needing to be squeezed. The port has no such problem and inherited the
  // shouting anyway, so the top two tiers were the only labels in the game
  // written in a different case from their neighbours. Reported from the couch.
  8: 'World Class',
  9: '⚡ Icon',
};

const Map<int, String> tierEmoji = {
  1: '🟫',
  2: '🟤',
  3: '⚪',
  4: '🔘',
  5: '🟡',
  6: '🟠',
  7: '🟣',
  8: '🌟',
  9: '⚡',
};

const Map<int, TierTheme> tierThemes = {
  1: TierTheme(
    bg: (angleDeg: 160, stops: [('#3b1f00', 0), ('#1a0d00', 100)]),
    bgLight: (angleDeg: 160, stops: [('#efdcc2', 0), ('#e0c9a0', 100)]),
    accent: '#8B5A00',
    accentLight: '#C87F2A',
    labelBg: '#3d2000',
  ),
  2: TierTheme(
    bg: (angleDeg: 160, stops: [('#4a2800', 0), ('#261400', 100)]),
    bgLight: (angleDeg: 160, stops: [('#ecd2b0', 0), ('#d9bd8e', 100)]),
    accent: '#A06820',
    accentLight: '#D4943A',
    labelBg: '#4a2800',
  ),
  3: TierTheme(
    bg: (angleDeg: 160, stops: [('#252525', 0), ('#111', 100)]),
    bgLight: (angleDeg: 160, stops: [('#ededed', 0), ('#d6d6d6', 100)]),
    accent: '#888888',
    accentLight: '#bbbbbb',
    labelBg: '#2a2a2a',
  ),
  4: TierTheme(
    bg: (angleDeg: 160, stops: [('#2d2d2d', 0), ('#181818', 100)]),
    bgLight: (angleDeg: 160, stops: [('#f1f1f1', 0), ('#dcdcdc', 100)]),
    accent: '#999999',
    accentLight: '#cccccc',
    labelBg: '#333333',
  ),
  5: TierTheme(
    bg: (angleDeg: 160, stops: [('#3a2a00', 0), ('#1a1200', 100)]),
    bgLight: (angleDeg: 160, stops: [('#f3e6b0', 0), ('#e6d28a', 100)]),
    accent: '#C8960C',
    accentLight: '#FFD440',
    labelBg: '#3d2e00',
  ),
  6: TierTheme(
    bg: (angleDeg: 160, stops: [('#4a3600', 0), ('#241b00', 100)]),
    bgLight: (angleDeg: 160, stops: [('#f5e4a0', 0), ('#ead07e', 100)]),
    accent: '#FFB300',
    accentLight: '#FFD740',
    labelBg: '#4a3800',
  ),
  7: TierTheme(
    bg: (angleDeg: 160, stops: [('#1f004a', 0), ('#0d0025', 100)]),
    bgLight: (angleDeg: 160, stops: [('#e6d2f5', 0), ('#d2b0ec', 100)]),
    accent: '#A040F0',
    accentLight: '#C880FF',
    labelBg: '#2a0060',
  ),
  8: TierTheme(
    bg: (angleDeg: 135, stops: [('#001a40', 0), ('#003366', 50), ('#000820', 100)]),
    bgLight: (angleDeg: 135, stops: [('#cfe8f5', 0), ('#bfe0f0', 50), ('#d6eef8', 100)]),
    accent: '#00c8ff',
    accentLight: '#80e8ff',
    labelBg: '#001830',
  ),
  9: TierTheme(
    bg: (angleDeg: 135, stops: [('#1a0a00', 0), ('#3d1f00', 30), ('#000820', 70), ('#1a0040', 100)]),
    bgLight: (angleDeg: 135, stops: [('#f5e2c2', 0), ('#f0d2a0', 30), ('#d6e2f5', 70), ('#e0d2f5', 100)]),
    accent: '#ffaa00',
    accentLight: '#ffe066',
    labelBg: '#1a0800',
  ),
};

/// The shirt position a card shows. The data uses FWD; the card says ATK.
const Map<String, String> positionLabel = {
  'FWD': 'ATK',
  'MID': 'MID',
  'DEF': 'DEF',
  'GK': 'GK',
};
