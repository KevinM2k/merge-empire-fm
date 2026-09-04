// Ground truth for the TS port of buildKitSurfaces. Run from repo root:
//   dart run design-system/tool/dump_kit_tokens.dart > design-system/fixtures/kit_tokens.json
import 'dart:convert';

import 'package:merge_empire_fc/util/kit_theme.dart';
import 'package:merge_empire_fc/data/card_theme.dart';

// The six patterns, plus hexes chosen for the ink and saturation edges the
// engine's own comments call out: green keeps white, yellow and orange flip,
// grey clamps up to the saturation floor, neon clamps down to the ceiling.
const _ids = [
  'turf', 'humbug', 'sunset', 'midnight', 'empire', 'void',
  '#4caf50', '#ffeb3b', '#ff9800', '#00bcd4', '#9e9e9e', '#00ff88',
  '#d32f2f', '#3355ee', '#ffffff', '#000000',
  'not-a-kit',
];

Map<String, Object> _row(KitSurfaces s) => {
  'bg': s.bg,
  'surface': s.surface,
  'surface2': s.surface2,
  'border': s.border,
  'textMuted': s.textMuted,
  'accent': s.accent,
  'accentBright': s.accentBright,
  'accentBrightInk': s.accentBrightInk,
  'accentInk': s.accentInk,
  'hueRotate': s.hueRotate,
};

void main() {
  final out = <String, Object>{};
  for (final id in _ids) {
    for (final light in [false, true]) {
      out['$id|${light ? 'light' : 'dark'}'] =
          _row(buildKitSurfaces(kitId: id, light: light));
    }
  }
  // The primitives too: a surface table that matches tells us little if the
  // arithmetic under it drifted on a value no kit happens to hit.
  final prims = <String, Object>{};
  for (final hex in ['#4caf50', '#ffeb3b', '#ff9800', '#00bcd4', '#9e9e9e',
                     '#ffffff', '#000000', '#2e7d32', '#7733cc']) {
    final hsl = hexToHsl(hex);
    prims[hex] = {
      'hsl': [hsl.h, hsl.s, hsl.l],
      'roundTrip': hslToHex(hsl.h, hsl.s, hsl.l),
      'relLuminance': relLuminance(hex),
      'inkFor': inkFor(hex),
      'kitSaturation': kitSaturation(hsl.s),
      'kitHueRotate': kitHueRotate(hsl.h),
    };
  }
  // The tier palette is Flutter-free too, so it is generated rather than
  // retyped — same rule as the surfaces above.
  Map<String, Object> grad(TierGradient g) => {
    'angleDeg': g.angleDeg,
    'stops': [for (final s in g.stops) [s.$1, s.$2]],
  };
  final tiers = <String, Object>{};
  tierThemes.forEach((tier, t) {
    tiers['$tier'] = {
      'bg': grad(t.bg),
      'bgLight': grad(t.bgLight),
      'accent': t.accent,
      'accentLight': t.accentLight,
      'labelBg': t.labelBg,
      'label': tierLabel[tier],
      'emoji': tierEmoji[tier],
    };
  });

  print(const JsonEncoder.withIndent('  ').convert({
    'surfaces': out,
    'primitives': prims,
    'tiers': tiers,
  }));
}
