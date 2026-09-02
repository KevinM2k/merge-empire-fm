/// How a tactic LOOKS — icon, colour, tint, ink. Ported from `ui/tacticStyle.js`.
///
/// Three screens render tactics (the Squad picker and its header chip, the Play
/// screen's coach suggestion, the in-match strip) and each used to keep its own
/// copy of the icon map, which had already drifted — High Press was a flame in
/// one place and a bolt in two others. One map here, one colour per tactic.
///
/// **Colour carries meaning.** A tactic is the same hue everywhere, so a manager
/// learns to read the strip at a glance mid-match without parsing the label.
/// Never hardcode one of these hexes at a call site.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The line icon per tactic, by name in the game's own icon set.
const Map<String, String> tacticIcons = {
  'balanced': 'scales',
  'allOutAttack': 'swords',
  'parkTheBus': 'shield',
  'counterAttack': 'target',
  'highPress': 'flame',
};

/// The icon for a tactic id, falling back to the ball for anything unknown.
String tacticIconName(String id) => tacticIcons[id] ?? 'ball';

const _dark = <String, Color>{
  'allOutAttack': Color(0xFFFF6B4A),
  'parkTheBus': Color(0xFF4FA8FF),
  'counterAttack': Color(0xFFB98BFF),
  'highPress': Color(0xFFFFC247),
  // **BALANCED IS GREY, not the club's accent.** It used to fall through to
  // `accentBright` on the reasoning that the neutral choice should wear the
  // club's own colour rather than a fifth hue — and what that produced is the
  // one tactic that means "no particular plan" being drawn in the loudest
  // colour on the screen, and a different colour per club. Asked for from the
  // couch: grey. Attack is red, defence blue, counter purple, press yellow, and
  // the one that is none of those looks like none of those.
  'balanced': Color(0xFFB8C0C8),
};

const _light = <String, Color>{
  'allOutAttack': Color(0xFFCC3D1C),
  'parkTheBus': Color(0xFF1565C0),
  'counterAttack': Color(0xFF6B32C9),
  // **STILL A YELLOW in daylight.** It was `#97600A`, which is a brown: the
  // light table exists because the dark hues are unreadable on white, and this
  // one had been taken so far down that it stopped being the colour it names.
  // Reported from the couch — it is yellow in dark mode, make it yellow here.
  // This is the app's own daylight amber, the one `semanticInk` already hands
  // out for exactly this problem.
  'highPress': Color(0xFFC2650B),
  'balanced': Color(0xFF5A646E),
};

/// The tactic's hue.
///
/// Five now: red for attack, blue for defence, purple for a counter, yellow for
/// a press, and a NEUTRAL GREY for balanced — see the tables. The fallback
/// remains the kit accent for an id no table knows, which is a shape a data file
/// could still produce.
Color tacticColor(BuildContext context, String id) {
  final light = Theme.of(context).brightness == Brightness.light;
  final table = light ? _light : _dark;
  return table[id] ?? Theme.of(context).extension<KitTheme>()!.accentBright;
}

/// A translucent wash of the tactic's hue, for a selected row or chip.
/// [pct] is how much colour survives the mix with the page beneath.
Color tacticTint(BuildContext context, String id, [int pct = 14]) =>
    tacticColor(context, id).withValues(alpha: pct / 100);

/// Text colour to use ON a solid [tacticColor].
///
/// **No longer a special case for balanced.** It was the kit's `accentBrightInk`
/// because balanced's face WAS the kit accent; it is a grey of its own now, and
/// the same rule that serves the other four serves it.
Color tacticInk(BuildContext context, String id) =>
    Theme.of(context).brightness == Brightness.light
    ? Colors.white
    : const Color(0xFF16120F);
