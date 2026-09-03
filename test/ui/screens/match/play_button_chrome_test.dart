/// The play button's chrome, against `glass.css`.
///
/// **This is not a device pass** — the M5 row asks for one and nobody has
/// looked at this on hardware. What it is: the difference between "matched" as
/// a claim written in a comment and "matched" as something the build re-checks.
/// Pinning it caught the label's shadow at 0.40 where the stylesheet says 0.45.
///
/// Every number below is quoted from
/// `../merge-empire-fc/src/ui/styles/glass.css`:
///
/// ```css
/// .play-match-btn {
///   border: 1px solid rgba(255, 255, 255, 0.55);
///   box-shadow:
///     inset 0 1px 0 rgba(255, 255, 255, 0.55),
///     inset 0 -2px 0 rgba(0, 0, 0, 0.22),
///     0 0 20px 2px var(--color-accent-glow),
///     0 2px 3px rgba(0, 0, 0, 0.4),
///     0 7px 12px rgba(0, 0, 0, 0.34),
///     0 16px 32px rgba(0, 0, 0, 0.46);
/// }
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/util/kit_theme.dart'
    show contrastRatio, whiteInkMinContrast;

/// Real club kits, off `club_art.g.dart` — the reds and yellows the report was
/// about, the greens and blues that must not change, and the pale and grey ends
/// where a light label cannot survive.
const List<Color> kitAccents = [
  Color(0xFFF44336), Color(0xFFD32F2F), Color(0xFF8B0000), Color(0xFFE91E63),
  Color(0xFF9C27B0), Color(0xFF4A148C), Color(0xFF1A237E), Color(0xFF0D47A1),
  Color(0xFF2196F3), Color(0xFF00BCD4), Color(0xFF4CAF50), Color(0xFF1B5E20),
  Color(0xFF8BC34A), Color(0xFFAED581), Color(0xFF827717), Color(0xFFFFEB3B),
  Color(0xFFFFD700), Color(0xFFFFCA28), Color(0xFFFF9800), Color(0xFFFF5722),
  Color(0xFF795548), Color(0xFF9E9E9E), Color(0xFF37474F), Color(0xFF1a1a1a),
  Color(0xFFE8F5E9), Color(0xFFFFF9C4), Color(0xFF87CEEB),
];

/// The worst of the label's two contrasts: the face is a gradient, so it has
/// to hold against both stops.
double labelGap(Color accent) {
  final ink = playButtonInk(accent).computeLuminance();
  return playButtonFace(accent)
      .map((stop) => contrastRatio(stop.computeLuminance(), ink))
      .reduce(math.min);
}

/// Whether the label is lighter than the face it is printed on.
bool labelIsLighter(Color accent) =>
    playButtonInk(accent).computeLuminance() >
    playButtonFace(accent).map((c) => c.computeLuminance()).reduce(math.max);

void main() {
  test('THREE SHADOWS, not one, and the tight one is first', () {
    // The stylesheet's own reason: "the diffuse far shadow alone reads as a
    // glow; what actually lifts a button off the pitch is the tight contact
    // shadow right under its edge, with the mid and far passes carrying the
    // height."
    expect(playButtonChrome, hasLength(3));
    expect(playButtonChrome[0], (dy: 2.0, blur: 3.0, spread: 0.0, alpha: 0.4));
    expect(playButtonChrome[1], (dy: 7.0, blur: 12.0, spread: 0.0, alpha: 0.34));
    expect(playButtonChrome[2], (dy: 16.0, blur: 32.0, spread: 0.0, alpha: 0.46));
  });

  test('and they get further and softer, in that order', () {
    for (var i = 1; i < playButtonChrome.length; i++) {
      expect(playButtonChrome[i].dy, greaterThan(playButtonChrome[i - 1].dy));
      expect(
        playButtonChrome[i].blur,
        greaterThan(playButtonChrome[i - 1].blur),
      );
    }
  });

  test('the glow is centred and spread, which is what makes it a GLOW', () {
    // `0 0 20px 2px` — no offset at all, unlike every shadow above it.
    expect(playButtonGlow.dy, 0);
    expect(playButtonGlow.blur, 20);
    expect(playButtonGlow.spread, 2);
  });

  test('THE RIM IS ONE PIXEL, not two', () {
    // The pop was never the border's boldness — it is the bevel and the
    // shadows, and a heavy white stroke over those reads as a sticker.
    expect(playButtonRimWidth, 1);
    expect(playButtonRimAlpha, 0.55);
  });

  test('and the label clears the gradient at the stylesheet\'s own alpha', () {
    expect(playButtonLabelShadowAlpha, 0.45);
  });

  /// **A LIGHTER SHADE OF THE CLUB, and darker only where that cannot read.**
  ///
  /// Reported from the couch on a light-mode red club: the label came out
  /// black. The flip was `HSL lightness > 0.5`, and a mid red sits at 0.51
  /// while a pure yellow sits at 0.50 — the same number for two colours that
  /// are nothing like as bright as each other.
  group('the label is the club colour', () {
    test('A RED CLUB GETS A LIGHTER RED, not a near-black', () {
      for (final accent in [
        const Color(0xFFF44336),
        const Color(0xFFD32F2F),
        const Color(0xFF8B0000),
      ]) {
        expect(labelIsLighter(accent), isTrue, reason: '$accent');
        final ink = HSLColor.fromColor(playButtonInk(accent));
        // A degree or so of drift: a pale tint is three 8-bit channels close
        // together, and the hue read back off them quantises.
        expect(
          ink.hue,
          closeTo(HSLColor.fromColor(accent).hue, 3),
          reason: '$accent: the label stopped being red',
        );
        expect(
          ink.saturation,
          greaterThan(0.2),
          reason: '$accent: a label walked all the way to white',
        );
      }
    });

    test('and a YELLOW one gets a darker yellow', () {
      // The one exception that was asked for by name, and the oranges and
      // cyans go with it: white disappears on all of them.
      for (final accent in [
        const Color(0xFFFFEB3B),
        const Color(0xFFFFD700),
        const Color(0xFFFF9800),
        const Color(0xFF00BCD4),
      ]) {
        expect(labelIsLighter(accent), isFalse, reason: '$accent');
        final ink = HSLColor.fromColor(playButtonInk(accent));
        expect(ink.hue, closeTo(HSLColor.fromColor(accent).hue, 1));
        expect(ink.lightness, greaterThan(0.05), reason: '$accent: black');
      }
    });

    test('the direction is the house rule, measured off the FACE', () {
      // `whiteInkMinContrast` — white unless white genuinely disappears — is
      // the same test the HUD, the tab bar and every filled button use.
      for (final accent in kitAccents) {
        final lit = playButtonFace(accent)
            .map((c) => c.computeLuminance())
            .reduce(math.max);
        expect(
          labelIsLighter(accent),
          contrastRatio(lit, 1) >= whiteInkMinContrast,
          reason: '$accent went the wrong way',
        );
      }
    });

    test('and every kit reads on its own button', () {
      for (final accent in kitAccents) {
        // A light label on a mid face is the low end, and it is what the
        // label's drop shadow is for; a dark one is asked for more.
        // A light label on a MID face is the low end: no tint of a red or a
        // green reaches four without going white, so that case takes the cap
        // and leans on the label's drop shadow. Everything else clears the bar.
        final least = labelIsLighter(accent) ? 1.9 : playButtonInkContrast;
        expect(
          labelGap(accent),
          greaterThanOrEqualTo(least),
          reason: '$accent: ${labelGap(accent).toStringAsFixed(2)}',
        );
      }
    });
  });

  group('THE COOLDOWN LABEL IS READ OVER THE MASK, not over the face', () {
    // Reported from the couch: "the coach cooldown text is pretty much
    // unreadable in some themes — until the bar fills anyways." That last
    // clause is the diagnosis. `_CooldownMask` lays [cooldownMaskAlpha] black
    // over the part of the face the clock has not given back, and the label
    // above it was inked with `playButtonInk` — a colour measured against the
    // BRIGHT face. On a pale club that ink is a deep bronze, so it spent the
    // wait as a dark label on a nearly black panel and only became readable as
    // the sweep uncovered the face beneath it.

    /// The face's stops with the cooldown mask over them.
    List<Color> masked(Color accent) => [
      for (final stop in playButtonFace(accent))
        Color.lerp(stop, Colors.black, cooldownMaskAlpha)!,
    ];

    /// The worst contrast [ink] holds against a masked face.
    double gapOn(Color accent, Color ink) => masked(accent)
        .map(
          (stop) => contrastRatio(
            stop.computeLuminance(),
            ink.computeLuminance(),
          ),
        )
        .reduce(math.min);

    test('WHITE CLEARS IT ON EVERY KIT IN THE GAME', () {
      for (final accent in kitAccents) {
        expect(
          gapOn(accent, Colors.white),
          greaterThanOrEqualTo(whiteInkMinContrast),
          reason: 'white is unreadable over the mask on $accent',
        );
      }
    });

    test('AND THE OLD INK DID NOT, which is the report', () {
      // Not "some kits fail" as a hedge — the pale end of the kit list is where
      // it happened, and naming it is what stops the fix being reverted as
      // unnecessary.
      final failed = [
        for (final accent in kitAccents)
          if (gapOn(accent, playButtonInk(accent)) < whiteInkMinContrast) accent,
      ];
      expect(
        failed,
        isNotEmpty,
        reason: 'if no kit fails, the report had another cause',
      );
    });
  });


}
