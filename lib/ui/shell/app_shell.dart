/// The five-tab shell.
///
/// `IndexedStack` keeps every tab alive so a switch does not throw away scroll
/// position, and `TickerMode` on the offscreen children stops them animating.
/// That pair is the whole of what `screenFreeze.js` hand-builds in the JS —
/// there, a hidden screen keeps running its CSS animations and starves whatever
/// is on top of it, so the code adds a class that restyles ~1,150 elements and
/// schedules it through `requestIdleCallback` to hide the cost.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/placeholder_screen.dart';
import 'package:merge_empire_fc/ui/shell/tab_bar.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  ShellTab _active = defaultTab;

  void _goTab(ShellTab tab) {
    if (tab == _active) return;
    setState(() => _active = tab);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Scaffold(
      body: Container(
        decoration: kit.background,
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: tabOrder.indexOf(_active),
            children: [
              for (final tab in tabOrder)
                TickerMode(
                  enabled: tab == _active,
                  child: PlaceholderScreen(
                    key: ValueKey('screen-${tab.name}'),
                    label: t(tab.labelKey),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ShellTabBar(active: _active, onTap: _goTab),
    );
  }
}
