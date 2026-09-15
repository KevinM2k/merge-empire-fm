/// The player sheet's own controls, shared by both trait slots.
///
/// These lived inside `player_detail_sheet.dart` as private classes. The second
/// trait slot wanted the same gold pill and the same medal, and a widget that
/// imports the sheet for them while the sheet imports it back is a cycle — so
/// the two moved out to where both blocks can reach them.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart' show TraitGlyph;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart'
    show mouldedButtonStyle, storeGemFace;

/// I, II, III — the levels, in the one place they are written.
const List<String> romanLevels = ['I', 'II', 'III'];

/// One of the hero's two controls, and the trait roll.
///
/// **The old note said a Material button would not do, and the half of it that
/// was right is kept.** Two things were true: the theme's `ElevatedButton`
/// brings the club's own accent, which on half the kits in the game is a Replace
/// button the same green as the shirt behind it; and the pair has to be legible
/// whatever the man is wearing. The first is what the slot actions' scrim
/// already answers, and the second is what a SOLID face answers, which is what
/// `mouldedButtonStyle(face:)` paints. Neither of them argues for a different
/// shape, which is all the couch was looking at.
///
/// So the affirmative one keeps its gold and the other takes the theme's own
/// button outright; what changes is that both are now the shape the other
/// eighty-odd buttons in the app are.
class HeroPill extends StatelessWidget {
  const HeroPill({
    super.key,
    required this.buttonKey,
    required this.glyph,
    required this.label,
    required this.gold,
    required this.onTap,
    this.gem = false,
  });

  final Key buttonKey;

  /// The shop's gem button — blue face, white ink — for a control that
  /// SPENDS A GEM. Wins over [gold].
  final bool gem;

  /// A name from the app's own icon set — see `game_icon.dart`. It was a
  /// literal `⇄`, `↩`, `⇡`: three glyphs the font renders differently on every
  /// platform, on a sheet where every other mark in the game is drawn. Reported
  /// from the couch along with the buttons themselves.
  final String glyph;
  final String label;

  /// The affirmative one. Gold is the game's own "this is the thing to press";
  /// the other is the same pill in white, so the pair reads as a choice rather
  /// than as one button and one link.
  final bool gold;

  /// Null when the pill is dead — mid-spin, or with nothing in the bank. It is
  /// the same signal `ElevatedButton.onPressed` carried, kept nullable rather
  /// than wrapped in an `Opacity`, so "is this pressable" stays one question
  /// with one answer.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        key: buttonKey,
        onPressed: onTap,
        // **THROUGH THE HELPER, because a moulded face cannot be coloured any
        // other way.** The face is painted in a `backgroundBuilder` over a
        // transparent Material, so `styleFrom(backgroundColor:)` would land
        // UNDERNEATH it and `side:` would draw a second outline clear of the
        // moulded one. Null for the other one on purpose: that IS the theme's
        // `ElevatedButton`, which is the whole point of the change.
        style: gem
            ? gemMould(kit)
            : gold
                ? goldMould(kit)
                : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // No colour: `GameIcon` falls back to the ambient
            // `DefaultTextStyle`, which inside a button is the style's own
            // resolved foreground — so the glyph greys out with the label
            // rather than staying dark ink on the disabled face.
            GameIcon(glyph, size: 15),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gold face the affirmative controls wear.
///
/// Gold is the game's own "this is the thing to press", and it is not a colour
/// of the kit — a club that plays in gold would otherwise have a Bench button
/// indistinguishable from its Replace one — so the three tones are literals
/// here the way `dangerInk` is a literal in `kit_theme_ext.dart`. The edge is
/// the face's own shade, so the button is one object rather than a colour in a
/// frame.
ButtonStyle goldMould(KitTheme kit) => mouldedButtonStyle(
  face: heroGoldFace,
  edge: heroGoldEdge,
  ink: heroGoldInk,
  dead: kit.surface2,
  deadInk: kit.textMuted,
  border: kit.border,
);

/// The gem face, in the shop's own blue — see `StoreTone.gem`.
ButtonStyle gemMould(KitTheme kit) => mouldedButtonStyle(
  face: storeGemFace,
  edge: const Color(0xFF12587F),
  ink: Colors.white,
  dead: kit.surface2,
  deadInk: kit.textMuted,
  border: kit.border,
);

const Color heroGoldFace = Color(0xFFE8C877);
const Color heroGoldEdge = Color(0xFF8F681F);
const Color heroGoldInk = Color(0xFF3A2A08);

/// The trait's face — a MEDAL, not a circle with a glyph in it.
///
/// **It is the most interesting thing on this sheet and looked the least like
/// it.** A 1.4px outlined disc is the shape this app uses for a filter chip; a
/// trait is a thing you spent coins to win, and a thing you won has a rim, a
/// light on it and a level stamped on its corner. The level moved here off the
/// block's title row for the same reason: a numeral in a header is a
/// specification, and on the medal it is what the medal is worth.
class TraitDisc extends StatelessWidget {
  const TraitDisc({
    super.key,
    required this.glyph,
    required this.colour,
    required this.fill,
    this.level,
    this.levelInk,
    this.levelKey = const ValueKey('detail-trait-level'),
    this.child,
    this.compact = false,
    this.selected = false,
  });

  /// The lit slot: a heavier ring, since the tile round it has no box now.
  final bool selected;

  /// A 40pt medal rather than 52, for the two slot tiles side by side.
  final bool compact;

  final String glyph;

  /// Drawn in place of [glyph] — the gem on a slot not yet open.
  final Widget? child;
  final Color colour;
  final Color fill;

  /// The roman numeral, or null for a card with no trait yet.
  final String? level;
  final Color? levelInk;

  /// The chip's key — two medals on one sheet need two.
  final Key levelKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 58 : 56,
    height: compact ? 58 : 56,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Centred in its box: the box is 4pt bigger than the medal to give
        // the level chip somewhere to hang, and the medal sat in the top-left
        // of it — reported as the circle not lining up under its label.
        Center(
        child: Container(
          width: compact ? 54 : 52,
          height: compact ? 54 : 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // A rounded square rather than a coin, so the two slot tiles read
            // as cards in a row. Asked for from the couch.
            borderRadius: BorderRadius.circular(12),
            // Lit from the top left, the way anything struck out of metal is.
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              radius: 0.95,
              colors: [
                Color.lerp(fill, Colors.white, 0.22)!,
                fill,
                Color.lerp(fill, Colors.black, 0.18)!,
              ],
              stops: const [0, 0.55, 1],
            ),
            border: Border.all(
              color: colour.withValues(alpha: selected ? 1 : 0.85),
              width: selected ? 2.6 : 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colour.withValues(alpha: 0.30),
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child ??
              (glyph == '?'
                  ? Text(
                      glyph,
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: colour,
                      ),
                    )
                  : TraitGlyph(glyph, size: compact ? 24 : 28, color: colour)),
        ),
        ),
        if (level != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Theme.of(context).extension<KitTheme>()!.surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                level!,
                key: levelKey,
                style: TextStyle(
                  color: levelInk ?? Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
