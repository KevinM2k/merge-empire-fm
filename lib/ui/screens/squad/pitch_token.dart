/// One man on the pitch, and the empty slot he stands in. Ported from
/// `_slotHtml` in `ui/screens/SquadScreen.js`.
///
/// **A pitch slot is a TOKEN, not a player card.** The port had been drawing the
/// full merge card here, which is why eleven of them could not fit: a card is
/// sized to be read one at a time on a grid, and this has to be read eleven at a
/// time in a formation. The token is 74 wide, its portrait 58 tall, and it
/// carries only what a manager picking a side needs — the rating IN THIS SLOT,
/// the position, the name, whether he is fit.
///
/// **The rating is not the card's rating.** A striker at left back is the same
/// card and a different player, so the number is what the sim will actually use,
/// and its colour is how much the slot costs him: green for a natural fit, amber
/// for a near one, red for a misfit.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsRedOn;
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart' show TraitBadge;
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';

/// The wrapper's width. The token fills it; the empty slot is inset inside it.
const double pitchTokenWidth = 74;

/// The token's own height at full size, which is what a formation's spacing has
/// to clear. Measured rather than declared — the token is built out of a tier
/// strip, art, a name and a position chip — and pinned by a test, so changing
/// any of those parts fails loudly instead of quietly crowding the pitch.
const double pitchTokenHeight = 97;

/// How much clear grass a pair of tokens must have between them, as a fraction
/// of the token's own size. The knob for "the pitch feels tight": 1.0 would let
/// two tokens touch exactly.
const double pitchTokenBreathing = 1.15;

/// The largest the token can be drawn at on [pitch] without two of them
/// touching, never above its design size.
///
/// **The formations are laid out in percentages and the token is laid out in
/// pixels**, so whether a shape crowds depends on the screen — and eleven tokens
/// that never shrink are what put a back four in the midfield's band on a short
/// phone, and a back FIVE on top of itself on any phone. Rather than hand-check
/// five shapes at three sizes, ask the only question that matters: for every pair
/// of slots, does one axis or the other separate them by more than a token?
///
/// A pair needs clearing on ONE axis, not both — two players side by side in the
/// same band are separated horizontally, and the same two in adjacent bands
/// vertically. Taking the minimum over every pair means the tightest pair in the
/// shape sets the size, so a five-man defence draws slightly smaller cards than a
/// four-man one. That is the honest answer: it has less room per player.
double pitchTokenScale(Iterable<({int x, int y})> slots, Size pitch) {
  if (pitch.isEmpty) return 1;
  final at = slots.toList();
  var scale = 1.0;
  for (var i = 0; i < at.length; i++) {
    for (var j = i + 1; j < at.length; j++) {
      final dx =
          (at[i].x - at[j].x).abs() / 100 * pitch.width / pitchTokenWidth;
      final dy =
          (at[i].y - at[j].y).abs() / 100 * pitch.height / pitchTokenHeight;
      final clears = math.max(dx, dy) / pitchTokenBreathing;
      if (clears < scale) scale = clears;
    }
  }
  // Floored: below about half size the rating and the name stop being readable,
  // and a pitch that cannot fit the shape legibly is better slightly crowded
  // than filled with cards nobody can read.
  return scale.clamp(0.55, 1.0);
}

/// `penaltyColor` / `penaltyBg` from `playerMiniCard.js`.
Color penaltyColor(double p) => p == 0
    ? const Color(0xFF4ADE80)
    : p <= 0.2
    ? const Color(0xFFFBBF24)
    : const Color(0xFFF87171);

Color penaltyBg(double p) => p == 0
    ? const Color(0xFF166534)
    : p <= 0.2
    ? const Color(0xFF78350F)
    : const Color(0xFF7F1D1D);

/// An empty slot: dashed, with a plus and the position it wants.
class PitchEmptySlot extends StatelessWidget {
  const PitchEmptySlot({super.key, required this.position});

  final String position;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: pitchTokenWidth,
      child: Center(
        child: CustomPaint(
          painter: const _DashedSlotPainter(),
          child: SizedBox(
            width: 60,
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '+',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1,
                    color: Color(0x99FFFFFF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  position,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0x99FFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedSlotPainter extends CustomPainter {
  const _DashedSlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(11),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0x24000000));
    final stroke = Paint()
      ..color = const Color(0x61FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + 4).clamp(0, metric.length)),
          stroke,
        );
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSlotPainter old) => false;
}

/// A player on the pitch.
/// The hospital cross a hurt player wears.
///
/// **A cross reads at a glance, and in every language.** It replaces a chip
/// spelling `INJ` — three letters at eight points on a token an inch wide, which
/// is neither glanceable nor the same three letters in the other nine
/// catalogues. The translated word is still on the token for a screen reader,
/// because trading a translated string for an icon outright would be a step
/// back; what the eye gets is the cross.
class InjuryCross extends StatelessWidget {
  const InjuryCross({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: t('card.inj_short'),
    child: CustomPaint(
      key: const ValueKey('injury-cross'),
      size: Size.square(size),
      painter: const _CrossPainter(),
    ),
  );
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFCC2222));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFFF5555)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16,
    );
    // The bar of the cross is a third of the disc, which is the proportion a
    // first-aid cross actually uses — thinner reads as a plus sign.
    final arm = r * 0.62;
    final half = r * 0.19;
    final ink = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromCenter(center: c, width: arm * 2, height: half * 2),
      ink,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c, width: half * 2, height: arm * 2),
      ink,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}

class PitchToken extends StatelessWidget {
  const PitchToken({
    super.key,
    required this.slot,
    required this.proMode,
    this.highlighted = false,
  });

  final PitchSlot slot;
  final bool proMode;

  /// A drop is hovering, so the ring brightens.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final card = slot.card!;
    final theme = tierThemes[card.tier] ?? tierThemes[1]!;
    final accent = cssColor(theme.accent);
    final accentLight = cssColor(theme.accentLight);
    // The ring sits on the page, not on the token's own dark plate, so it
    // takes the theme's red. The CHIPS below keep theirs: they carry a
    // `0xB8000000` ground of their own and are dark in both themes by design.
    final ring = card.injured ? vsRedOn(context) : accentLight;
    final pColor = penaltyColor(slot.penalty);
    final pBg = penaltyBg(slot.penalty);

    // Shrink the name to fit rather than clipping it — a cut-off name reads
    // worse than a small one.
    final surname = card.name.split(' ').last;
    final nameSize = surname.length > 14
        ? 7.0
        : surname.length > 12
        ? 8.0
        : surname.length > 9
        ? 9.0
        : 10.0;

    return SizedBox(
      width: pitchTokenWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cssColor(theme.bg.stops.last.$1),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(
                color: highlighted ? Colors.white : ring,
                width: 2,
              ),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
                // A legend glows, unless he is hurt.
                if (card.tier >= 7 && !card.injured)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.67),
                    blurRadius: 12,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The tier strip: the one part of the merge card that carries
                  // over, so a legend on the pitch is the same gold as on the
                  // grid.
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accentLight, accent],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 58,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accent.withValues(alpha: 0.13),
                                accent.withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                        ),
                        if (card.variant != null)
                          ArtImage(
                            path: playerImagePath(
                              card.position,
                              card.tier,
                              card.variant!,
                            ),
                            // `cover`, anchored to the top: the token is shorter
                            // than the art is tall, and the face is what has to
                            // survive the crop.
                            fit: BoxFit.cover,
                            dimmed: card.injured,
                            fallback: PlayerPortrait(
                              variantIndex: card.variant!,
                              kitColor: accent,
                            ),
                          ),
                        if (card.injured)
                          const ColoredBox(
                            color: Color(0x80640000),
                            child: Center(
                              child: InjuryCross(size: pitchTokenWidth * 0.34),
                            ),
                          ),
                        // The rating IN THIS SLOT, coloured by what the slot
                        // costs him.
                        Positioned(
                          top: 2,
                          left: 2,
                          child: _Chip(
                            label: '${slot.effRating}',
                            fill: pBg.withValues(alpha: 0.93),
                            edge: pColor,
                            ink: pColor,
                            size: 9.5,
                          ),
                        ),
                        // **The same badge the bench draws**, at the foot of
                        // the art where the token has room: the eleven and the
                        // men waiting to come on have to say the same thing
                        // about the same player.
                        if (card.trait case final trait?)
                          Positioned(
                            bottom: 2,
                            left: 2,
                            child: TraitBadge(
                              icon: trait.icon,
                              level: trait.level,
                              title: trait.title,
                              size: 8,
                            ),
                          ),
                        if (slot.seasons > 0)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: _Chip(
                              label: 'S${slot.seasons}',
                              fill: const Color(0xB8000000),
                              edge: Colors.transparent,
                              ink: slot.seasons >= 14
                                  ? const Color(0xFFF87171)
                                  : slot.seasons >= 10
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xD9FFFFFF),
                              size: 7,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: const Color(0x8C000000),
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 3),
                    child: Text(
                      surname,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: nameSize,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Pro mode plays the legs as much as the ratings, so the
                  // energy is on the token there and nowhere else.
                  if (proMode && card.fitness != null)
                    Container(
                      width: double.infinity,
                      color: const Color(0x8C000000),
                      padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: card.fitness!.clamp(0, 1),
                          minHeight: 3,
                          backgroundColor: const Color(0x59000000),
                          valueColor: AlwaysStoppedAnimation(
                            card.fitness! < 0.34
                                ? const Color(0xFFF87171)
                                : card.fitness! < 0.67
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF4ADE80),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          _Chip(
            label: slot.slotPosition,
            fill: pBg.withValues(alpha: 0.93),
            edge: pColor,
            ink: pColor,
            size: 8,
            spacing: 0.6,
            padding: const EdgeInsets.symmetric(horizontal: 7),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.fill,
    required this.edge,
    required this.ink,
    required this.size,
    this.spacing = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: 3),
  });

  final String label;
  final Color fill;
  final Color edge;
  final Color ink;
  final double size;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: edge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: size,
          height: 1.5,
          fontWeight: FontWeight.w900,
          letterSpacing: spacing,
          color: ink,
        ),
      ),
    );
  }
}
