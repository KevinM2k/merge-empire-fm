/// The shell's half of Colin's post-tutorial tour — see `engine/guide_engine.dart`
/// for the tour itself. This maps the bar's tabs onto the engine's, which is
/// all the shell needs of it: opening a tab is what spends a step.
///
/// **The bar does not glow, and that is deliberate.** There was a
/// `guideHighlightProvider` here feeding a pulsing pill round whichever tab the
/// outstanding step led to — see the note on [GuideStep.leadsTo]. It went
/// because a lit tab is an alert with nothing to say: the corner already
/// speaks the nudge in words.
library;

import 'package:merge_empire_fc/engine/guide_engine.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';

GuideTab guideTabOf(ShellTab tab) => switch (tab) {
  ShellTab.grid => GuideTab.grid,
  ShellTab.squad => GuideTab.squad,
  ShellTab.home => GuideTab.home,
  ShellTab.club => GuideTab.club,
  ShellTab.shop => GuideTab.shop,
};
