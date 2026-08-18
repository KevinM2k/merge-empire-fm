/// Which entrance an incoming screen gets.
///
/// Enter-only, as in the JS: the outgoing screen simply hides. The two slides
/// are the tab bar's left/right cue; [EnterMode.fromBelow] is for the Event,
/// which is reached from a strip pinned to the bottom of the Play screen, so
/// rising from under it is the movement the tap implies.
library;

import 'package:merge_empire_fc/ui/shell/tabs.dart';

enum EnterMode { none, fromLeft, fromRight, fromBelow }

/// Distance a horizontal drag must cover to change tab.
const double swipeThreshold = 60;

/// How long the slide runs. The JS's is 220ms.
const Duration tabSlideDuration = Duration(milliseconds: 220);

/// [noSlide] is for a DEEP LINK, which also scrolls the screen to a section the
/// moment it opens. A screen sliding in from the side while its contents jump to
/// an anchor is two movements fighting and reads as a glitch; arriving already
/// in the right place reads as going straight there, which is what the tap
/// asked for.
EnterMode enterModeFor({
  required ShellTab from,
  required ShellTab to,
  required bool noSlide,
}) {
  if (noSlide || from == to) return EnterMode.none;
  return tabOrder.indexOf(to) > tabOrder.indexOf(from)
      ? EnterMode.fromRight
      : EnterMode.fromLeft;
}
