/// Where on screen a named control actually is — the port's
/// `document.querySelector`.
///
/// **The JS anchors every tutorial step to a CSS selector**, and the port's
/// overlay used to say a selector "is not a thing this port has" and drop the
/// spotlight, the ring and the hand along with it. That left a card telling a
/// player to press something without saying which something.
///
/// It does have one: a `ValueKey`. Every control the script points at already
/// carries one, because the widget tests find them by it. What was missing was
/// a way to turn a key into a RECTANGLE from outside the widget that owns it,
/// and that is the whole of this file — a walk of the live element tree looking
/// for the key, then the render box's position in global coordinates.
///
/// **A tree walk is what `querySelector` is**, and it is too expensive to do
/// every frame — so [TutorialAnchor] walks ONCE and then re-measures the render
/// box it found, which is a matrix multiply. That split matters more than it
/// looks: the hole has to follow the control every frame, because the control
/// MOVES. The scout reveal scrolls the grid to the square the new card is
/// flying into, and a hole left where the button used to be is a hole that eats
/// the next tap — the player presses the thing the tutorial is pointing at and
/// nothing happens.
///
/// The alternative — a `GlobalKey` registry every anchored widget has to opt
/// into — puts tutorial plumbing inside the scout button, the play button and
/// anything the script ever points at next.
///
/// **AND IT HAS TO ASK WHETHER THE CONTROL IS ON SCREEN**, not just whether it
/// exists. The shell keeps every tab alive in an `IndexedStack` so a switch does
/// not throw away scroll positions — which means the scout button is in the
/// element tree, laid out and sized, while the player is looking at a different
/// tab entirely. A walk that stopped at "found it" put the hole, the ring and
/// the hand over a control nobody could see, on whatever part of the screen it
/// happened to occupy behind the visible tab. `querySelector` has the same
/// trap and the JS's version reads `getBoundingClientRect`, which is zero for a
/// hidden element; this is that check.
///
/// Null is a normal answer: the control may be on a tab that has not been
/// switched to yet, or scrolled out of the viewport. The overlay dims the whole
/// screen and hides the ring when it gets one, which is the JS's own "no
/// target" branch.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One control, found once and then followed.
///
/// The walk is the expensive half and the measurement is not, so the element is
/// held and only re-found when it has gone — a tab switch, a rebuild that
/// replaced it, a step that points somewhere else.
class TutorialAnchor {
  TutorialAnchor(this.id);

  final String id;

  Element? _element;

  /// Where it is now, or null when it is not on screen.
  Rect? measure() {
    var element = _element;
    if (element == null || !element.mounted) {
      element = _find(WidgetsBinding.instance.rootElement, id);
      _element = element;
    }
    return _rectOf(element);
  }
}

/// The rect of the widget keyed `ValueKey(id)`, in global coordinates.
///
/// [from] narrows the search to one subtree; the default is the whole app,
/// which is what a selector searches. For a control that has to be FOLLOWED
/// rather than found once, use [TutorialAnchor].
Rect? tutorialAnchorRect(String id, {Element? from}) {
  return _rectOf(_find(from ?? WidgetsBinding.instance.rootElement, id));
}

Rect? _rectOf(Element? element) {
  final object = element?.renderObject;
  if (object is! RenderBox || !object.hasSize || !object.attached) return null;
  if (!_onScreen(object)) return null;
  final origin = object.localToGlobal(Offset.zero);
  final size = object.size;
  if (size.isEmpty) return null;
  return origin & size;
}

/// Is anything between this and the root refusing to paint it?
///
/// The two that matter are the two the app uses to keep a widget alive without
/// showing it: the shell's `IndexedStack`, which paints only the selected tab,
/// and `Offstage`. Both lay their children out — that is the whole point of
/// them — so a size is no evidence at all.
bool _onScreen(RenderObject object) {
  RenderObject child = object;
  var parent = child.parent;
  while (parent != null) {
    if (parent is RenderIndexedStack && !_isPaintedChild(parent, child)) {
      return false;
    }
    if (parent is RenderOffstage && parent.offstage) return false;
    child = parent;
    parent = parent.parent;
  }
  return true;
}

bool _isPaintedChild(RenderIndexedStack stack, RenderObject child) {
  final index = stack.index;
  if (index == null) return false;
  var i = 0;
  var painted = false;
  stack.visitChildren((candidate) {
    if (i == index && identical(candidate, child)) painted = true;
    i++;
  });
  return painted;
}

Element? _find(Element? root, String id) {
  if (root == null) return null;
  Element? hit;
  void visit(Element element) {
    if (hit != null) return;
    final key = element.widget.key;
    if (key is ValueKey && key.value == id) {
      hit = element;
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return hit;
}
