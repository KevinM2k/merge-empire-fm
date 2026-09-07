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

import 'package:merge_empire_fc/data/manager_art.g.dart';

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

/// **ART THIS REPO OWNS, LAID OVER THE GENERATED PARTS.**
///
/// Same arrangement as `lib/i18n/en_copy.dart` and for the same reason:
/// `manager_art.g.dart` is generated out of the JS's `managerAvatar.js`, so a
/// part cannot be edited in place — the next generator run would put it back.
/// This map is laid over it at read time by [managerFaceArt], and nothing
/// generated is touched.
///
/// **BUBBLEGUM IS THE REASON IT EXISTS.** The wardrobe shipped a lit CIGAR as a
/// buyable face item, complete with drifting smoke, in a game aimed at
/// children; pulled from the couch in as many words. Gum keeps the slot doing
/// the same job — something at the mouth with something moving off it — and is
/// a real touchline habit rather than an invention. The generated wardrobe has
/// no art for it, so the part lives here.
///
/// **THE STILL PART IS ALMOST NOTHING, and that is the point.** The gum is IN
/// HIS MOUTH: what you see of it is a flash of pink between the teeth as the
/// jaw works, and a bubble every few seconds. Asked for from the couch in those
/// words, after a version that had a pink ball riding on his lip.
///
/// **So the still part draws NOTHING**, and that is deliberate rather than
/// unfinished. A pink shape in the mouth's own gap was the version before this
/// one and it was still visible past the lips the painter draws over it —
/// reported from the couch as seeing the gum when it is meant to be hidden.
/// There is no size of pink that is reliably behind a jaw that moves, so the
/// only thing that is definitely hidden is nothing at all.
///
/// Everything the item IS lives in `_GumChew` in `manager_walker.dart`: the jaw
/// working for most of the loop, and a bubble for the rest. A rig with its
/// clock stopped — the customiser's chips — sits at the top of that loop with
/// the bubble at full size, so the item still says what it is when it is not
/// moving.
///
/// The entry stays, rather than the id simply having no art: it is what makes
/// `bubblegum` a wardrobe part the resolver knows about, and where the drawing
/// would go if it ever needs one.
const Map<String, String> managerFaceOverrides = {
  'bubblegum': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 170"/>',
};

/// The face part for [id] — this repo's, if it has one.
String? managerFaceArt(String id) =>
    managerFaceOverrides[id] ?? managerFaces[id];
