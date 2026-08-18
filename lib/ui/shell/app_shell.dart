/// The five-tab shell.
///
/// `IndexedStack` keeps every tab alive so a switch does not throw away scroll
/// position, and `TickerMode` on the offscreen children stops them animating.
/// That pair is the whole of what `screenFreeze.js` hand-builds in the JS —
/// there, a hidden screen keeps running its CSS animations and starves whatever
/// is on top of it, so the code adds a class that restyles ~1,150 elements and
/// schedules it through `requestIdleCallback` to hide the cost.
///
/// The swipe has no exclusion list either. The JS carries
/// `SWIPE_NAV_EXCLUDE_SELECTOR`, a `card-dragging` body class and
/// `preventDefault` calls to arbitrate between a tab swipe and a card drag;
/// Flutter's gesture arena is what all of that was hand-building, and a card's
/// own recogniser wins it without being told to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/placeholder_screen.dart';
import 'package:merge_empire_fc/ui/shell/tab_bar.dart';
import 'package:merge_empire_fc/ui/shell/tab_transition.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => AppShellState();
}

/// Public so a test — and, until Task 6's controller lands, a deep link — can
/// drive [goTab] directly. The same seam Flutter's own ScaffoldState exposes.
class AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  ShellTab _active = defaultTab;
  EnterMode _enter = EnterMode.none;

  late final AnimationController _slide;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: tabSlideDuration);
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void goTab(ShellTab tab, {bool noSlide = false}) {
    if (tab == _active) return;
    final mode = enterModeFor(from: _active, to: tab, noSlide: noSlide);
    setState(() {
      _active = tab;
      _enter = mode;
    });
    if (mode == EnterMode.none) {
      _slide.value = 1;
    } else {
      _slide.forward(from: 0);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity == 0) return;
    final idx = tabOrder.indexOf(_active);
    // No wrap at the ends: the bar has a first and a last tab, and a swipe past
    // either should do nothing rather than teleport across the app.
    final next = velocity < 0 ? idx + 1 : idx - 1;
    if (next < 0 || next >= tabOrder.length) return;
    goTab(tabOrder[next]);
  }

  Offset get _beginOffset => switch (_enter) {
    EnterMode.fromRight => const Offset(1, 0),
    EnterMode.fromLeft => const Offset(-1, 0),
    EnterMode.fromBelow => const Offset(0, 1),
    EnterMode.none => Offset.zero,
  };

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Scaffold(
      body: Container(
        decoration: kit.background,
        child: SafeArea(
          bottom: false,
          child: GestureDetector(
            onHorizontalDragEnd: _onDragEnd,
            child: SlideTransition(
              key: const ValueKey('tab-slide'),
              position: Tween<Offset>(
                begin: _beginOffset,
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
              ),
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
        ),
      ),
      bottomNavigationBar: ShellTabBar(active: _active, onTap: goTab),
    );
  }
}
