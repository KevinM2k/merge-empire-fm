/// Recolouring the manager's generated parts.
///
/// `manager_art.g.dart` carries every part with its colours BAKED IN, because a
/// `CustomPainter` has no CSS custom properties: the generator resolved each
/// `var(--hair, #3a2a1c)` to its fallback, which is the colour the JS paints
/// before a kit or a look is applied.
///
/// This is the other half of that decision — the substitution the CSS variable
/// was doing, one level down. The defaults are the KEYS: a part painted
/// `#3a2a1c` is painted "the hair colour", so swapping the hex is swapping the
/// slot. It is exact rather than fuzzy on purpose; a part that used an
/// off-default shade keeps it, which is how the coat's lining stays a lining.
///
/// Deliberately Flutter-free: it is string work on data, and the painter that
/// draws the result lives next to the widgets.
library;

/// The colour each slot is baked as, straight out of `tool/gen_manager_art.mjs`.
///
/// Kept in step with the generator's own `VARS` by
/// `test/data/manager_art_test.dart`, which reads the tool and compares.
const Map<String, String> managerArtDefaults = {
  'hair': '#3a2a1c',
  'kit': '#4caf50',
  'kitDark': '#2e6b30',
  'kitLight': '#6fbf73',
  'skin': '#e8b48c',
  'skinShade': '#c9946f',
};

/// A hex colour, in the form the artwork writes: `#rrggbb`, lower case.
String hexOf(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// One compiled pattern per slot, because there are six of them and they are
/// built from constants.
///
/// It was a `RegExp(...)` constructed inside the swap, so a dressed manager
/// compiled up to six patterns per LAYER and the rig re-ran the whole recolour
/// on every frame — tens of compilations a frame at 120Hz, for a result that
/// only changes when the player edits their look.
final Map<String, RegExp> _slotPatterns = {};

RegExp _slotPattern(String slot, String from) =>
    _slotPatterns[slot] ??= RegExp(from, caseSensitive: false);

/// Repaint [svg]'s slots.
///
/// Every argument is optional: a part with no hair in it is unaffected by a hair
/// colour, and passing nothing hands back the string untouched rather than a
/// copy with the defaults written over themselves.
String recolourManagerArt(
  String svg, {
  String? hair,
  String? kit,
  String? kitDark,
  String? kitLight,
  String? skin,
  String? skinShade,
}) {
  var out = svg;
  void swap(String slot, String? to) {
    if (to == null || to.isEmpty) return;
    final from = managerArtDefaults[slot]!;
    if (from.toLowerCase() == to.toLowerCase()) return;
    // Case-insensitively, because a look's colour may arrive upper case and the
    // artwork writes both — `#3A2A1C` and `#3a2a1c` are the same slot.
    out = out.replaceAll(_slotPattern(slot, from), to);
  }

  // Skin BEFORE hair is deliberate and the pair is the reason: nothing else
  // shares a value, but a look whose hair colour happens to be the default skin
  // tone would otherwise repaint the face when its hair was swapped.
  swap('skinShade', skinShade);
  swap('skin', skin);
  swap('hair', hair);
  swap('kitLight', kitLight);
  swap('kitDark', kitDark);
  swap('kit', kit);
  return out;
}
