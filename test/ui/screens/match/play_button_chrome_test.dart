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

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';

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
}
