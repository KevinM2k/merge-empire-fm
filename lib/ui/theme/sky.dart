/// The sky the whole game happens under, and whether anything is lit.
///
/// **THE THEME DECIDES DAY OR NIGHT. THE STADIUM TIER DECIDES THE GRANDEUR.**
/// Light mode is a daylight kick-off, dark mode a floodlit night, and the ladder
/// from a park pitch to an arena runs inside whichever of the two you are in.
///
/// The JS runs ONE ramp through all nine tiers — `league-scene.css` goes day at
/// tier 0, sunset at 3–4, floodlit night at 6–8 — and then drifts the whole
/// thing light→dark→light on a ~5-minute clock. Both are dropped. The ramp
/// because it made the sky a readout of the same number the stand and the
/// hoardings already report, so a player with a good stadium never saw
/// daylight; the clock because every panel that floats on this sky — the HUD's
/// glass, the next-match card, the turf — is tuned against a KNOWN backdrop,
/// and a sky on its own timer makes each of those right twice a cycle and wrong
/// the rest of it.
///
/// So there are two ramps, and each keeps one job. Their ends are lifted
/// straight out of the JS rather than invented: the day ramp runs its tier 0 to
/// its tier 2, the night ramp its tier 5 to its tier 8.
///
/// **Three surfaces read this**, and they must agree or arriving at a match is
/// arriving in a different world: the Play diorama, the live match page, and the
/// crowd's own aerial haze, which is the sky seen through the depth of the
/// terrace and so cannot be a colour of its own.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/club_assets.dart' show maxAssetTier;

/// Light mode is day, dark mode is night. The one decision the rest of the file
/// hangs off, named so no caller has to restate it.
bool nightScene(Brightness brightness) => brightness == Brightness.dark;

/// The same question off a context, for the widgets that only have one.
bool nightSceneOf(BuildContext context) =>
    nightScene(Theme.of(context).brightness);

/// The manager's comfort as the SCENE should show it.
///
/// **A blazing sun at midnight was making him sweat.** `sunny` floors the
/// temperature at `sunnyC` — that is the JS's rule and the parity harness's, so
/// it stays in the engine where it is — but the scene draws that same condition
/// under a MOON once the theme is dark. So a manager mopped his brow and ran
/// with a flushed face under a night sky, and the heat he was suffering came
/// from a sun that is not in the picture.
///
/// The divergence belongs HERE rather than in `estimatedTempC`: night is a
/// property of the scene, the engine has no idea there is one, and a temperature
/// a fixture compares cannot be bent to suit a drawing.
///
/// **Only the heat goes.** A cold night is colder than a cold day, so an
/// underdressed gaffer still shivers in the dark — which is the half of this
/// that was never wrong.
String sceneComfort(BuildContext context, String comfort) =>
    comfort == 'hot' && nightSceneOf(context) ? 'ok' : comfort;

/// A park on a bright afternoon — the JS's `data-tier="0"`.
const List<Color> _dayPark = [
  Color(0xFF6DB3E8),
  Color(0xFFA8D8F0),
  Color(0xFFD6ECF7),
];

/// A big ground on the same afternoon — its `data-tier="2"`. Deeper and cleaner
/// rather than a different weather: a stadium does not change the sky, it
/// changes what you are looking at under it.
const List<Color> _dayArena = [
  Color(0xFF4A90D9),
  Color(0xFF8FC4E8),
  Color(0xFFC4E2F2),
];

/// A floodlit night at a modest ground — the JS's `data-tier="5"`.
///
/// **NOT PURPLE.** The ramp climbed to `#6A4A8C` at the horizon, which is a
/// dusk sky rather than a night one and put a violet cast behind every dark-mode
/// panel on the match page. Asked for directly: darker is what was wanted, not
/// a hue. The lift at the horizon stays — a floodlit ground does glow — it is
/// simply the same blue as the sky above it.
const List<Color> _nightPark = [
  Color(0xFF0B1226),
  Color(0xFF162140),
  Color(0xFF2C3E63),
];

/// The Champions League night — its `data-tier="8"`.
///
/// The same correction as [_nightPark], and further down: a big ground under
/// floodlights is the darkest sky in the game.
const List<Color> _nightArena = [
  Color(0xFF02030F),
  Color(0xFF08101F),
  Color(0xFF16233C),
];

/// Where the three stops fall.
///
/// The JS completes its gradient by ~50% of the scene because everything below
/// is behind the stand and the pitch. The port runs it to the bottom instead:
/// the match page stands on this same sky with no diorama over it, so down there
/// the bottom half is what you are actually looking at.
const List<double> _skyStops = [0, 0.55, 1];

/// The sky's three colours at this tier, in this theme.
List<Color> skyColours({required Brightness brightness, required int tier}) {
  final t = (tier / maxAssetTier).clamp(0.0, 1.0);
  final night = nightScene(brightness);
  final from = night ? _nightPark : _dayPark;
  final to = night ? _nightArena : _dayArena;
  return [for (var i = 0; i < from.length; i++) Color.lerp(from[i], to[i], t)!];
}

LinearGradient skyGradient({
  required Brightness brightness,
  required int tier,
}) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: skyColours(brightness: brightness, tier: tier),
  stops: _skyStops,
);

/// What a MATCH stands under: **the Play screen's own sky, in BOTH themes.**
///
/// **This is the spec's answer and two attempts at improving on it were
/// wrong.** `.match-page` in `match-page.css` says it outright — the ground
/// "used to be a hardcoded near-black in both, which made light mode a black
/// hole in an otherwise light app. It is the PLAY SCREEN'S SKY at the same
/// stadium tier, so the match opens under the sky the diorama you just left was
/// drawn under."
///
/// The purple that got reported was never the sky's fault. The spec's next
/// paragraph is the half the port had missed: "there is NO light-mode flip, and
/// that is the whole point. Every panel is the scorecard's glass in both
/// themes, because the ground is the sky." The port's panels flipped with the
/// theme, so in dark mode they were thin enough to let the night sky's violet
/// through and in light mode they were pale panes on a bright sky. Pinning the
/// glass is what makes the sky right — see `GlassPanel.darkGlass`.
/// **[brightness] OVERRIDES the context's**, for a page that forces its own.
///
/// The match and its full-time report wrap themselves in the kit's DARK theme —
/// they are dark glass in both, and the ink has to match. But a `Theme` wraps
/// what has already been BUILT, so a `Theme.of(context)` made while building
/// the page still reads the theme outside it: in light mode the sky came out a
/// daylight blue under dark-glass panels with dark-theme ink on them. That is
/// the "Play screen is hard to read in light mode" that survived the takeover.
Decoration matchBackdrop({
  required BuildContext context,
  required int tier,
  Brightness? brightness,
}) => BoxDecoration(
  gradient: skyGradient(
    brightness: brightness ?? Theme.of(context).brightness,
    tier: tier,
  ),
);

/// The colour the distance hazes TO, which is the sky at the horizon rather than
/// the sky overhead.
///
/// The crowd used to haze to a hard-coded `#1B3A57` — the old fixed dusk sky's
/// top stop — so under a daylit sky the terrace would have receded into a
/// twilight that was nowhere else on the screen. Anything that fades into the
/// distance takes this.
Color skyHaze({required Brightness brightness, required int tier}) =>
    skyColours(brightness: brightness, tier: tier).last;

/// The ink for text drawn DIRECTLY on the sky, with the halo that keeps it
/// legible against a gradient.
///
/// The fixture caption's own note used to say why it was white in both themes:
/// "this line sits directly on the diorama, whose sky runs from bright noon to
/// floodlit night, and no theme colour survives both ends of that." That was
/// true of a sky on a clock. It is not true of a sky that follows the theme —
/// there are two known backdrops now, so there are two right answers, and white
/// on a daylit sky is the one thing that was never legible.
///
/// The halo inverts with the ink: dark text needs a light glow behind it and
/// light text needs a dark one, and either way the shadow is what stops the line
/// dissolving where the gradient passes through its own tone.
({Color ink, Color inkSoft, List<Shadow> shadows}) skyInk(
  BuildContext context,
) {
  if (nightSceneOf(context)) {
    return (
      ink: Colors.white,
      inkSoft: const Color(0xCCFFFFFF),
      shadows: const [
        Shadow(color: Color(0xBF000000), blurRadius: 4, offset: Offset(0, 1)),
        Shadow(color: Color(0x80000000), blurRadius: 10),
      ],
    );
  }
  // **DAYLIGHT NEEDS NO HALO.** A white glow behind dark text on a bright sky is
  // a smudge — it has nothing to lift the letters off, because they are already
  // the darkest thing on the screen, and all it does is fur their edges. One
  // hairline of white directly under the baseline is enough to stop the ink
  // dissolving where the sky's gradient runs darkest, and that is all.
  final ink = Theme.of(context).colorScheme.onSurface;
  return (
    ink: ink,
    inkSoft: ink.withValues(alpha: 0.72),
    shadows: const [
      Shadow(color: Color(0x66FFFFFF), blurRadius: 1.5, offset: Offset(0, 1)),
    ],
  );
}

/// How many floodlight pylons stand behind the terrace.
///
/// The JS's own counts, and keyed on the TIER on purpose: a pylon is BUILT, not
/// switched on. It stands there in daylight too — unlit, which is the whole
/// difference between the two themes at the same tier.
int floodlightCount(int tier) => tier >= 7
    ? 2
    : tier >= 4
    ? 1
    : 0;

/// Whether those pylons are burning, which is the part that follows the theme.
bool floodlightsLit({required Brightness brightness, required int tier}) =>
    nightScene(brightness) && floodlightCount(tier) > 0;
