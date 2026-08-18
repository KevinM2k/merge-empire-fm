/// What a kit id actually PAINTS with. Ported from
/// `../merge-empire-fc/src/data/kitPalette.js`.
///
/// `club.kitPrimaryColor` is usually a hex string, but six of the kits are
/// patterns whose stored value is a NAME rather than a colour. The theming layer
/// knows those names and themes the whole app from them — but everything ELSE
/// that paints in the club's colours (the manager figure, crests, flags,
/// fireworks, the next-match card) was handed the raw id and dropped it straight
/// into a colour slot. `humbug` is not a colour, so the manager's shirt fell back
/// to plain black on both pattern kits instead of showing the kit at all.
///
/// This is the one place that turns a kit id into something paintable:
///
/// - [kitSolidColor] — a single colour, for anything that needs one value: a
///   crest, a firework spark, a scarf tint to mix from.
/// - [kitStripes] — the two bands, for the surfaces that can render the real
///   pattern: the manager's shirt and training top.
/// - [kitSwatchCss] — a CSS background for the kit picker's swatches. Kept as
///   the CSS string the web build emits, since the pattern definitions are the
///   same data either way and a Flutter gradient is a rendering decision for M3.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

/// One kit pattern. Stripe pairs are dark band first, then light.
class KitPattern {
  const KitPattern({required this.solid, this.stripes, this.swatch});

  /// The representative single colour.
  final String solid;

  /// The two bands, for a surface that can draw the real pattern.
  final (String, String)? stripes;

  /// A ready-made CSS background, for the patterns that are gradients rather
  /// than stripes.
  final String? swatch;
}

const Map<String, KitPattern> kitPatterns = {
  // Mown-grass stripes, both taken from the turf theme's own palette — the dark
  // band it mows into the page background, and its accent green. Both are
  // deliberately DARKER than the diorama pitch: the manager is stood on grass,
  // so a light band bright enough to be "fresh turf" is also close enough to the
  // pitch behind him to vanish into it. Reading darker is what keeps the figure
  // off the grass.
  'turf': KitPattern(solid: '#2e7d32', stripes: ('#1f4f21', '#2e7d32')),
  // The app CHROME cannot use true black and white — white body text sits
  // directly on it, which is why the theme pairs near-black with a mid slate —
  // but a shirt carries no text, so the kit itself gets the real humbug.
  'humbug': KitPattern(solid: '#1b1b1b', stripes: ('#111111', '#f0f0f0')),
  'sunset': KitPattern(
    solid: '#ff6b35',
    swatch: 'linear-gradient(135deg,#ff6b35,#f7c59f,#efefd0,#004e89)',
  ),
  'midnight': KitPattern(
    solid: '#4466ff',
    swatch: 'linear-gradient(135deg,#0a0a2e,#1a1a4e,#2d2d6e,#0f0f3d)',
  ),
  'empire': KitPattern(
    solid: '#00c8ff',
    swatch: 'linear-gradient(135deg,#001418,#0099cc,#7ee8fa)',
  ),
  'void': KitPattern(
    solid: '#9933ff',
    swatch: 'linear-gradient(135deg,#0a0014,#7733cc,#cc88ff)',
  ),
};

const String defaultKitColor = '#4caf50';

/// A single paintable colour for a kit id.
///
/// Hex kits pass through and pattern kits resolve to their representative
/// colour. Anything unrecognised — a save from a future build, a retired colour
/// that slipped the migration — falls back to the default green rather than
/// handing the renderer something it cannot paint.
String kitSolidColor(Object? kit) {
  final pattern = kit is String ? kitPatterns[kit] : null;
  if (pattern != null) return pattern.solid;
  return kit is String && kit.startsWith('#') ? kit : defaultKitColor;
}

/// The two stripe bands for a striped kit, or null when it is a plain colour.
(String, String)? kitStripes(Object? kit) =>
    kit is String ? kitPatterns[kit]?.stripes : null;

String _stripeSwatch((String, String) bands) =>
    'repeating-linear-gradient(90deg,${bands.$1} 0,${bands.$1} 6px,'
    '${bands.$2} 6px,${bands.$2} 12px)';

/// The CSS background for a kit swatch.
///
/// Striped kits derive theirs from the SAME bands the manager's shirt uses, so
/// the square you tap in the picker is the kit you get — they used to be two
/// hand-written copies that had already drifted apart.
String kitSwatchCss(Object? kit) {
  final pattern = kit is String ? kitPatterns[kit] : null;
  if (pattern == null) return kitSolidColor(kit);
  if (pattern.swatch != null) return pattern.swatch!;
  return _stripeSwatch(pattern.stripes!);
}
