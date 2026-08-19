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
};

const _light = <String, Color>{
  'allOutAttack': Color(0xFFCC3D1C),
  'parkTheBus': Color(0xFF1565C0),
  'counterAttack': Color(0xFF6B32C9),
  'highPress': Color(0xFF97600A),
};

/// The tactic's hue.
///
/// Balanced maps to the KIT accent on purpose: it is the neutral choice, so it
/// wears the club's own colour rather than a fifth hue competing with the four
/// that mean something.
Color tacticColor(BuildContext context, String id) {
  final light = Theme.of(context).brightness == Brightness.light;
  final table = light ? _light : _dark;
  return table[id] ?? Theme.of(context).extension<KitTheme>()!.accentBright;
}

/// A translucent wash of the tactic's hue, for a selected row or chip.
/// [pct] is how much colour survives the mix with the page beneath.
Color tacticTint(BuildContext context, String id, [int pct = 14]) =>
    tacticColor(context, id).withValues(alpha: pct / 100);

/// Text colour to use ON a solid [tacticColor]. Balanced follows the kit's own
/// accent ink, since its face is the kit accent.
Color tacticInk(BuildContext context, String id) => id == 'balanced'
    ? Theme.of(context).extension<KitTheme>()!.accentBrightInk
    : (Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF16120F));
