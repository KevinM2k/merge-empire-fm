/// Turns a kit id into a `ThemeData`. The only place a palette string becomes a
/// `Color` — the derivation itself stays Flutter-free in `util/kit_theme.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/stripe_painter.dart';
import 'package:merge_empire_fc/util/kit_theme.dart';

export 'package:merge_empire_fc/ui/theme/stripe_painter.dart';

/// A tier's card body, as a Flutter gradient.
///
/// CSS measures its angle clockwise from "to top" and Flutter takes two points.
/// 160deg and 135deg are the only two the catalogue uses and both read as a
/// top-left to bottom-right sweep, so one alignment pair covers it. Shared
/// because the merge grid's card and the Player Index's draw the same body and
/// a second copy is a second thing to get wrong.
LinearGradient tierBodyGradient(TierGradient g) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [for (final stop in g.stops) cssColor(stop.$1)],
  stops: [for (final stop in g.stops) stop.$2 / 100],
);

final RegExp _hsl = RegExp(r'^hsl\(\s*(-?\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)$');

/// Parse the three forms the palette emits: `#rgb`, `#rrggbb` and `hsl()`.
///
/// Never throws. The value traces back to the save, and a theme that throws is a
/// white screen on launch.
Color cssColor(String value) {
  final v = value.trim();
  if (v.startsWith('#')) {
    final digits = v.substring(1);
    final full = digits.length == 3
        ? digits.split('').map((c) => '$c$c').join()
        : digits;
    final parsed = int.tryParse(full, radix: 16);
    if (parsed != null && full.length == 6) return Color(0xFF000000 | parsed);
    return const Color(0xFF000000);
  }
  final m = _hsl.firstMatch(v);
  if (m != null) {
    return cssColor(
      hslToHex(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ),
    );
  }
  return const Color(0xFF000000);
}

/// The two striped kits' PAGE background — `TURF_BACKGROUND` and
/// `HUMBUG_BACKGROUND` in `kitTheme.js`, as a band pair and a band width.
///
/// **This is NOT the shirt's pair, and the port was using the shirt's.**
/// `kitPatterns` carries humbug as `#111111` / `#f0f0f0` and says in its own
/// comment why: "the app CHROME cannot use true black and white — white body
/// text sits directly on it, which is why the theme pairs near-black with a mid
/// slate — but a shirt carries no text, so the kit itself gets the real
/// humbug". This function reached for that pair anyway, so every screen in the
/// game stood on fourteen bands of true black and true white with body copy
/// over them. Reported as too many stripes, too hard to see and needing to be
/// softer, which is three readings of the one fault.
///
/// The WIDTHS were already the spec's and stay: at `#0e0e0e` against `#3a3a3a`
/// the count stops being something the eye has to fight, so widening the bands
/// as well would be treating the symptom twice.
const Map<String, ({String a, String b, double width})> _stripesDark = {
  'turf': (a: '#1f4f21', b: '#2a6d2d', width: 24),
  'humbug': (a: '#0e0e0e', b: '#3a3a3a', width: 28),
};

/// `TURF_BACKGROUND_LIGHT` / `HUMBUG_BACKGROUND_LIGHT` — the same geometry
/// paled up so the texture still reads on a light page.
///
/// **The port had no light variant at all**, so a light-mode humbug drew dark
/// body text over true-black bands and a light-mode turf drew it over forest
/// green. Both are one lookup, and both were unreadable.
const Map<String, ({String a, String b, double width})> _stripesLight = {
  'turf': (a: '#9fcda1', b: '#b6dfb8', width: 24),
  'humbug': (a: '#e4e4e4', b: '#b4b4b4', width: 28),
};

Decoration _backgroundFor(String kitId, KitSurfaces s, bool light) {
  // Only two of the six kits are stripes; the rest are smooth gradients.
  //
  // Turf's second layer — a 45° hatch of `rgba(255,255,255,0.03)` every 8px,
  // the mow lines — is NOT ported. `StripeDecoration` paints one axis, and at
  // 3% on a dark green it is below what the screenshots resolve; it is here as
  // a known gap rather than a forgotten one.
  final stripes = (light ? _stripesLight : _stripesDark)[kitId];
  if (stripes != null) {
    return StripeDecoration(
      dark: cssColor(stripes.a),
      light: cssColor(stripes.b),
      darkWidth: stripes.width,
      lightWidth: stripes.width,
    );
  }
  // **AND IN LIGHT MODE IT IS TINTED TOWARD THE CLUB.** The dark stack is built
  // from the accent's own hue — `hsl(h, s, 7%)` and up — so a dark page already
  // leans the club's way. The light stack is one fixed neutral for every kit
  // (`#ffffff` over `#eef0f3`), which is the JS's own decision and stays in
  // `kit_palette.dart` where the parity fixture compares it; what it means on
  // screen is that picking claret changes nothing about the page. Reported
  // directly.
  //
  // **THE LIGHT PAGE IS BUILT THE WAY THE DARK ONE IS, rather than lerped
  // toward the accent.** Three passes of "a bit more tint" got nowhere useful
  // because a lerp toward a mid-tone accent darkens the page as much as it
  // colours it — 20% of claret on white is a pink, and a pink page is not what
  // dark mode does.
  //
  // Dark mode's stack is `hsl(h, sat, 7%)` over `hsl(h, sat·0.75, 12%)`: the
  // club's HUE at the club's saturation, placed at a lightness that makes it a
  // page. Mirrored at the top of the scale that is `hsl(h, sat, 97%)` over
  // `hsl(h, sat·0.75, 94%)` — the same construction, the same amount of club,
  // and a page that is unmistakably tinted without being coloured. Which is
  // what was asked for: the equivalent of what dark mode already has.
  //
  // `kitSaturation` is the same clamp the dark stack uses, so a grey kit still
  // has some colour in it and a neon one does not glow.
  final hsl = hexToHsl(s.accent);
  final sat = kitSaturation(hsl.s);
  final page = light
      ? [
          cssColor(hslToHex(hsl.h, sat, 97)),
          cssColor(hslToHex(hsl.h, (sat * 0.75).round(), 94)),
          cssColor(hslToHex(hsl.h, sat, 97)),
        ]
      : [cssColor(s.bg), cssColor(s.surface), cssColor(s.bg)];
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: page,
    ),
  );
}

/// **THE CLUB'S COLOUR, AS THE PLAYER PICKED IT.**
///
/// `KitSurfaces.accentBright` is the JS's own `hsl(h,60%,36%)` in light and
/// `hsl(h,90%,70%)` in dark — a hue re-derived at a fixed saturation and
/// lightness. It is what `kit_theme_reference.json` compares and it stays
/// exactly as it is; what changes is what the SCREEN reads, which is the
/// divergence this repo puts on the screen rather than in the harness.
///
/// The re-derivation is why a chosen `#4CAF50` printed as `#25932A`: two thirds
/// of a kit's identity is its saturation and its lightness, and both were being
/// thrown away and replaced with a constant. Reported directly — the accents
/// are darker, or just not quite the colour that was chosen.
///
/// So the answer is the accent ITSELF, moved only when it cannot be read on the
/// ground it stands on, and only as far as that takes. A kit that is already
/// legible is left completely alone, which is most of them.
String uiAccentBright(String accentHex, {required bool light}) {
  final hsl = hexToHsl(accentHex);
  final ground = light ? lightPaneHex : darkPaneHex;
  var l = hsl.l;
  // Sixteen steps of three points is the whole range, and it stops the moment
  // the colour clears the bar — a mid-tone moves a little, a bad pairing moves
  // a lot, and nothing moves that did not have to.
  for (var i = 0; i < 24; i++) {
    final ratio = contrastRatio(
      relLuminance(hslToHex(hsl.h, hsl.s, l)),
      relLuminance(ground),
    );
    if (ratio >= uiAccentMinContrast(light: light)) break;
    l = light ? math.max(0, l - 3) : math.min(100, l + 3);
  }
  return hslToHex(hsl.h, hsl.s, l);
}

/// What a club colour has to clear against the surface it is printed on.
///
/// **The small-text bar in daylight and the large-text one at night**, which is
/// not an inconsistency: an accent in light mode is nearly always INK — a club
/// name, a heading, a label — where 4.5 is the rule the whole app's light sweep
/// enforces, and `glassAccent` would only take it there anyway one ramp later.
/// In dark mode it is as often a FILL as an ink, the ground gives it far more
/// room, and holding it to 4.5 would bleach a club's colour toward white for no
/// legibility gained.
double uiAccentMinContrast({required bool light}) => light ? 4.5 : 3.0;

/// The two grounds an accent is printed on: the light theme's card stack and
/// the dark theme's. Measured against the surface rather than the page, because
/// an accent is nearly always on a panel.
const String lightPaneHex = '#eef0f3';
const String darkPaneHex = '#151a15';

/// **THE FACE THE WHOLE APP IS SET IN**, bundled rather than the platform's.
///
/// It ran on the system font, which is San Francisco on iOS and Roboto on
/// Android: two different widths for the same league table, so a column of
/// figures that fitted on one wrapped on the other and no screen could be
/// trusted to look the way it was built. Asked for from the couch, in exactly
/// those terms.
///
/// **AND IT IS THE NORMAL WIDTH, not one of the condensed cuts.** Barlow
/// Condensed and Semi Condensed were both tried on the device and both came
/// back "too condensed" — a narrow face saves a couple of characters a line and
/// spends the whole screen looking compressed to do it. Barlow proper is the
/// grotesk the specimen everybody recognises actually is.
const String uiFontFamily = 'Barlow';

/// **AND A SECOND, HEAVIER FACE FOR THE THINGS THAT SHOUT.**
///
/// "VICTORY!", a scoreline, a payout — one word or one number, read at a
/// glance, where Barlow's `w900` is still a text weight rather than a poster
/// one. Lilita One is a single weight by design, so it is never asked for a
/// bold it does not have: see [displayText].
const String displayFontFamily = 'Lilita One';

/// Set a run in the display face — see [displayFontFamily].
///
/// **It carries its own weight**, because Lilita One ships ONE and a
/// `fontWeight` beside it is a synthesised smear rather than a heavier cut. So
/// this drops whatever weight the caller's style asked for; that is the point
/// of it rather than an oversight.
TextStyle displayText(TextStyle style) =>
    style.copyWith(fontFamily: displayFontFamily, fontWeight: FontWeight.w400);

/// **THE WEIGHT EVERY TEXT STYLE STARTS AT, when it does not say.**
///
/// Barlow's `w400` is lighter than the system faces it replaced — San Francisco
/// and Roboto both carry more weight at the same nominal 400 — so swapping the
/// family made the whole app read thinner at a stroke. Medium was the first
/// answer and it was still light; this is the second nudge, and both were asked
/// for from the couch in the same words: slightly bolder.
///
/// **It is a real cut, not a synthesised one.** `Barlow-SemiBold` is one of the
/// six weights in `pubspec.yaml`. Asking for a weight that is NOT bundled makes
/// the engine smear the nearest one, which is what makes a fake bold look
/// muddy — so this constant may only ever name a file that exists.
///
/// One place, because the next nudge should be one number.
const FontWeight uiBaseWeight = FontWeight.w600;

/// **NOTHING IN THIS APP IS SMALLER THAN THIS.**
///
/// The UI had drifted to 246 declared sizes under it — a spread of 7.5, 8, 8.5,
/// 9, 9.5, 10, 10.5, 11 and 11.5 — because every tight slot was solved by taking
/// a point off the type. On a phone that is a caption nobody reads, and a wall
/// of them is a screen nobody reads. Asked for from the couch, by pointing at a
/// line that was legible — the daily reward's "come back tomorrow" — and saying
/// that size is the floor everywhere.
///
/// **The escape hatch is `FittedBox`, not a smaller literal.** A slot that
/// genuinely cannot hold twelve points of type in every language — a chip in a
/// row of chips, a badge on a tile — shrinks what is in it at DRAW time, so the
/// declared size stays honest and the shrinking happens only where and when it
/// is actually needed. The position chip and the ratings' modifier band both do
/// this, and the type floor is what drove them to.
///
/// `architecture_test.dart` fails the build on a literal under it.
const double minFontSize = 12;

/// A control's OWN text style, for the one place a style does not inherit.
///
/// **A `ButtonStyle.textStyle` REPLACES the ambient style rather than merging
/// with it.** Material installs it as the label's `DefaultTextStyle` wholesale,
/// so whatever it leaves null is null at the `Text` — not inherited from the
/// page. And `ThemeData.fontFamily` reaches the `TextTheme`, not a style
/// literal: a bare `TextStyle(fontSize: 13)` in a button style therefore
/// renders its label in the PLATFORM's font at `w400`, which is the whole of
/// the app that escapes Barlow.
///
/// It was every moulded button — [mouldedButtonStyle]'s own literal names a
/// weight and no family, so eighty-odd labels were San Francisco or Roboto on a
/// page set in Barlow — and the match row's 2×/Subs/Skip were worse again:
/// `matchControlStyle` reaches them through `ButtonStyle.copyWith`, which swaps
/// the whole property out, so those three lost the `w900` with the family and
/// came out at `w400`. Reported from the couch as the wrong font, and then as
/// those three defo not being `w600`.
///
/// So this names both, every time, and [uiBaseWeight] is the floor.
/// A splash that also CLICKS.
///
/// **THE BUTTONS WERE SILENT, and they always had been.** `'tap'` is in
/// `sound_defs.dart` — a 50ms blip — and the only things that ever played it
/// were the five mini-games. Reported from the couch as having been lost;
/// nothing was lost, it was never wired. Behind the sound toggle by
/// construction: `SoundService.play` returns early unless it is on.
///
/// **ON THE SPLASH FACTORY rather than on eighty call sites.** Material makes
/// exactly one of these per press, for every button and every `InkWell` in the
/// app, which is the same set as "things that visibly respond to a press" — so
/// the framework decides what counts as a button rather than a list of widgets
/// somebody has to keep up to date. It delegates the ink itself, so the splash
/// looks exactly as it did.
///
/// A raw `GestureDetector` has no ink and so gets no click; [StoreButton] asks
/// for its own.
class TapSoundSplash extends InteractiveInkFeatureFactory {
  const TapSoundSplash({required this.ink, required this.onPress});

  /// The real splash, which draws the thing.
  final InteractiveInkFeatureFactory ink;

  final VoidCallback onPress;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    onPress();
    return ink.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}

TextStyle controlTextStyle({
  required double size,
  FontWeight weight = FontWeight.w900,
  TextDecoration? decoration,
}) => TextStyle(
  fontFamily: uiFontFamily,
  fontSize: size,
  fontWeight: weight.value < uiBaseWeight.value ? uiBaseWeight : weight,
  decoration: decoration,
);

/// Raise every theme text style that never chose a weight to [uiBaseWeight].
///
/// **Only the styles that never said.** Anything already heavier is left exactly
/// as it is — the several hundred explicit `w700`/`w800`/`w900` literals in
/// `lib/ui` were each chosen against something, and dragging them up too would
/// flatten the difference between a heading and its body. That is also why this
/// raises rather than shifts: a delta saturates at `w900` and quietly closes the
/// gap at the top end.
///
/// Written out field by field because `TextTheme.apply` has no
/// `fontWeightDelta` — `TextStyle.apply` does, and it asserts on a null weight,
/// which is precisely the case this has to handle. Compared on `value` rather
/// than `index`: the numeric weight is the thing being reasoned about, and
/// `index` is deprecated for exactly that reason.
TextTheme _atBaseWeight(TextTheme base) {
  TextStyle? up(TextStyle? style) {
    if (style == null) return null;
    final weight = style.fontWeight ?? FontWeight.w400;
    return weight.value >= uiBaseWeight.value
        ? style
        : style.copyWith(fontWeight: uiBaseWeight);
  }

  return TextTheme(
    displayLarge: up(base.displayLarge),
    displayMedium: up(base.displayMedium),
    displaySmall: up(base.displaySmall),
    headlineLarge: up(base.headlineLarge),
    headlineMedium: up(base.headlineMedium),
    headlineSmall: up(base.headlineSmall),
    titleLarge: up(base.titleLarge),
    titleMedium: up(base.titleMedium),
    titleSmall: up(base.titleSmall),
    bodyLarge: up(base.bodyLarge),
    bodyMedium: up(base.bodyMedium),
    bodySmall: up(base.bodySmall),
    labelLarge: up(base.labelLarge),
    labelMedium: up(base.labelMedium),
    labelSmall: up(base.labelSmall),
  );
}

ThemeData buildAppTheme({
  required String kitId,
  required bool light,
  /// The press cue, or null for a silent theme — see [TapSoundSplash].
  ///
  /// Optional so the several dozen tests that build a theme directly get the
  /// stock splash and no sound engine, which is what they want.
  VoidCallback? onPress,
}) {
  final s = buildKitSurfaces(kitId: kitId, light: light);
  final kit = KitTheme(
    bg: cssColor(s.bg),
    surface: cssColor(s.surface),
    surface2: cssColor(s.surface2),
    border: cssColor(s.border),
    textMuted: cssColor(s.textMuted),
    accent: cssColor(s.accent),
    accentBright: cssColor(uiAccentBright(s.accent, light: light)),
    accentBrightInk: cssColor(
      inkFor(uiAccentBright(s.accent, light: light)),
    ),
    accentInk: cssColor(s.accentInk),
    background: _backgroundFor(kitId, s, light),
  );
  final brightness = light ? Brightness.light : Brightness.dark;
  final theme = ThemeData(
    // Every button and every `InkWell` clicks — see [TapSoundSplash].
    splashFactory: onPress == null
        ? null
        : TapSoundSplash(ink: InkSparkle.splashFactory, onPress: onPress),
    useMaterial3: true,
    brightness: brightness,
    // **ONE PLACE, and it reaches every `Text` in the app.** A bare
    // `TextStyle(fontSize: 12)` inherits the family from the ambient
    // `DefaultTextStyle`, which this is the root of — so none of the several
    // hundred style literals in `lib/ui` had to name a font.
    //
    // No fallback list is declared on purpose: the engine already falls back
    // per GLYPH to the platform's own face, which is what keeps ja/ko/zh/ar
    // readable in a Latin-only family. Naming iOS's and Android's CJK faces
    // here would be two more strings to be wrong about.
    fontFamily: uiFontFamily,
    scaffoldBackgroundColor: kit.bg,
    // **A BAR THAT CHANGES COLOUR WHEN YOU SCROLL IS MATERIAL 3's IDEA, NOT
    // OURS.** `AppBar` tints itself with the primary colour the moment content
    // passes UNDER it — so the Settings header sat white at rest and went a
    // tinted lilac on the first scroll, for no reason a player could connect to
    // anything they did. Reported from the couch as exactly that. The app draws
    // its own grounds everywhere else and nothing in it lifts on scroll, so the
    // bar is pinned to the page it heads.
    appBarTheme: AppBarTheme(
      backgroundColor: kit.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: kit.accent,
      brightness: brightness,
    ),
    extensions: [kit],
    // **A TOOLTIP IS THE APP'S BUBBLE, NOT MATERIAL'S INVERTED ONE.**
    //
    // Flutter's default deliberately inverts the theme — a dark app gets a
    // WHITE bubble with black text, a light app a dark grey one — which is a
    // desktop convention for a hover hint that has to shout over a document.
    // In here it reads as a stray piece of another app: the modifier tips on
    // the next-match card are tapped, not hovered, and they sat white-on-black
    // in the middle of a dark page. Reported from the couch, with the fix
    // named: inverse it.
    //
    // Set here rather than on the call sites because there are eight of them —
    // the kit picker, three in the league sheets, the subs panel, the squad
    // page, the merge grid and the modifier tips — and a bubble that matches on
    // seven pages is worse than one that matches on none.
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        // The page's own surface. In DARK it is lifted a little off the card
        // it floats over, so the bubble has a body of its own; in light there
        // is nowhere to lift TO — the surface is already near white — and
        // darkening it instead would be the inversion this is here to undo, so
        // the border and the shadow do that job on their own.
        color: light
            ? kit.surface
            : Color.alphaBlend(
                Colors.white.withValues(alpha: 0.07),
                kit.surface,
              ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kit.border),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      textStyle: TextStyle(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: light ? const Color(0xFF1A1F26) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    ),
    // **EVERY BUTTON WEARS THE SHOP'S FACE.** Reported as the shop's controls
    // being moulded and nothing else in the app being — see
    // [mouldedButtonStyle]. Set here so it reaches all eighty-odd Material
    // buttons without eighty-odd edits, and so a new one is moulded by
    // default rather than by remembering.
    //
    // `TextButton` is deliberately left alone: it is a text link — "Maybe
    // later", "Load", "Export" — and a moulded face on one would make the
    // cancel look like the action.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: mouldedButtonStyle(
        face: kit.accent,
        edge: Color.alphaBlend(Colors.black.withValues(alpha: 0.45), kit.accent),
        ink: kit.accentInk,
        dead: kit.surface2,
        deadInk: kit.textMuted,
        border: kit.border,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: mouldedButtonStyle(
        face: kit.accent,
        edge: Color.alphaBlend(Colors.black.withValues(alpha: 0.45), kit.accent),
        ink: kit.accentInk,
        dead: kit.surface2,
        deadInk: kit.textMuted,
        border: kit.border,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: mouldedButtonStyle(
        face: kit.accent,
        edge: kit.border,
        ink: kit.accent,
        dead: kit.surface2,
        deadInk: kit.textMuted,
        border: kit.border,
        outline: true,
      ),
    ),
  );
  // Applied after the fact rather than inline: the weights being bumped are
  // the ones `ThemeData` itself just derived from `Typography`, so there is
  // nothing to shift until it has.
  return theme.copyWith(textTheme: _atBaseWeight(theme.textTheme));
}
