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
/// **A tree walk is what `querySelector` is**, and the cost is the same: it is
/// run when the step changes and on a slow repositioning tick, not per frame.
/// The alternative — a `GlobalKey` registry every anchored widget has to opt
/// into — puts tutorial plumbing inside the scout button, the play button and
/// anything the script ever points at next.
///
/// Null is a normal answer: the control may be on a tab that is still animating
/// in, or scrolled out of the viewport. The overlay dims the whole screen and
/// hides the ring when it gets one, which is the JS's own "no target" branch.
library;

import 'package:flutter/widgets.dart';

/// The rect of the widget keyed `ValueKey(id)`, in global coordinates.
///
/// [from] narrows the search to one subtree; the default is the whole app,
/// which is what a selector searches.
Rect? tutorialAnchorRect(String id, {Element? from}) {
  final element = _find(from ?? WidgetsBinding.instance.rootElement, id);
  final object = element?.renderObject;
  if (object is! RenderBox || !object.hasSize || !object.attached) return null;
  final origin = object.localToGlobal(Offset.zero);
  final size = object.size;
  if (size.isEmpty) return null;
  return origin & size;
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
