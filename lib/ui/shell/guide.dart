/// The shell's half of Colin's post-tutorial tour — see `engine/guide_engine.dart`
/// for the tour itself. This maps the engine's tabs onto the bar's and asks
/// which tab the bar should be drawing attention to.
library;

import 'package:merge_empire_fc/engine/guide_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';

GuideTab guideTabOf(ShellTab tab) => switch (tab) {
  ShellTab.grid => GuideTab.grid,
  ShellTab.squad => GuideTab.squad,
  ShellTab.home => GuideTab.home,
  ShellTab.club => GuideTab.club,
  ShellTab.shop => GuideTab.shop,
};

ShellTab? shellTabOf(GuideTab? tab) => switch (tab) {
  null => null,
  GuideTab.grid => ShellTab.grid,
  GuideTab.squad => ShellTab.squad,
  GuideTab.home => ShellTab.home,
  GuideTab.club => ShellTab.club,
  GuideTab.shop => ShellTab.shop,
};

/// The tab the bar glows, or null. Follows the save, so it goes out the moment
/// the step it belongs to is done.
final guideHighlightProvider = savePick<ShellTab?>(
  (s) => shellTabOf(guideHighlight(s)),
);
