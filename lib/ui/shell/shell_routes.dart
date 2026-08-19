/// Screens that present OVER the tabs rather than inside them.
///
/// The JS has one mechanism — it re-parents a screen's wrapper into a sheet
/// container and moves it back on close — and a hand-rolled `nav:back` that has
/// to ask whether a sheet is open before deciding what back means. Routes and
/// modal sheets are the two mechanisms that were being approximated, and
/// `Navigator` already knows the answer to that question.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tab_transition.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<T?> openRoute<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// The Event rises rather than sliding in from the side: the way in is the strip
/// pinned to the BOTTOM of the Play screen, so coming up from under it is the
/// movement the tap implies.
///
/// [hasPalette] is a property of the EVENT, not of the screen. A themed event is
/// a fixed dark showpiece and forces dark for as long as it is up; an event with
/// no palette — Deadline Day — keeps the player's own light mode. Restoring it
/// in `whenComplete` is what makes the Android back button restore it too.
Future<T?> openEventRoute<T>(
  BuildContext context,
  WidgetRef ref,
  Widget page, {
  required bool hasPalette,
}) {
  if (hasPalette) ref.read(forcedDarkProvider.notifier).state = true;
  return Navigator.of(context)
      .push<T>(
        PageRouteBuilder<T>(
          transitionDuration: tabSlideDuration,
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, _, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        ),
      )
      .whenComplete(() {
        if (hasPalette) ref.read(forcedDarkProvider.notifier).state = false;
      });
}

Future<void> openShellSheet(
  BuildContext context,
  ShellSheet sheet,
  Widget child,
) {
  final kit = Theme.of(context).extension<KitTheme>()!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      key: const ValueKey('shell-sheet'),
      expand: false,
      initialChildSize: sheet.heightFraction,
      minChildSize: 0.3,
      maxChildSize: sheet.heightFraction,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: kit.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: kit.border),
        ),
        child: ListView(controller: controller, children: [child]),
      ),
    ),
  );
}
