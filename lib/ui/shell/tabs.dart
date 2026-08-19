/// The five tabs, in bar order.
library;

enum ShellTab {
  grid('nav.players'),
  squad('nav.squad'),
  // The house, not a play triangle: this is the home screen — the diorama, the
  // next fixture, and the two orbs that reach everything else — not a "start"
  // control.
  home('nav.play'),
  club('nav.club'),
  shop('nav.shop');

  const ShellTab(this.labelKey);

  final String labelKey;
}

const List<ShellTab> tabOrder = ShellTab.values;

/// Where the app opens.
const ShellTab defaultTab = ShellTab.home;
