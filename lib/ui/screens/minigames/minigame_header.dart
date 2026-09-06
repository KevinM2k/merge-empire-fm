/// The title bar every drill wears.
///
/// **A drill is a takeover, not a page**, and a Material `AppBar` said the
/// opposite: sentence-case ink at the left with a back arrow, which is the
/// chrome of somewhere you navigated to rather than something that opened over
/// what you were doing. All seven wore one, so the set of them read as seven
/// screens in a different app from every sheet in the game.
///
/// `SheetHeader`'s rule instead — caps, the club's accent, centred — with the
/// close where `trailing` is documented to put it: over the top, out of the
/// centring, so the title sits on the middle of the screen rather than on
/// whatever is left beside it.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class MiniGameHeader extends StatelessWidget implements PreferredSizeWidget {
  const MiniGameHeader({super.key, required this.titleKey});

  final String titleKey;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => SafeArea(
    // Bottom off: `Scaffold` gives an app bar the top inset and nothing else,
    // so taking the bottom one here would add padding for a notch that is at
    // the other end of the screen.
    bottom: false,
    child: SheetHeader(
      title: t(titleKey),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      trailing: IconButton(
        key: const ValueKey('minigame-close'),
        icon: const Icon(Icons.close),
        tooltip: t('common.close'),
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}

/// One figure off a drill's full-time card: a muted label with a big number
/// under it.
///
/// **One of these, not one per drill.** Pairs and Pitch Invaders each carried a
/// byte-identical private `_Stat`, and the Boot Room was about to be given a
/// third. They live here for the same reason the header does: a drill's
/// full-time card is a shape the set of them shares, and three copies of it is
/// three places for it to drift.
class MiniGameStat extends StatelessWidget {
  const MiniGameStat({
    super.key,
    required this.kit,
    required this.label,
    required this.value,
    required this.valueKey,
    required this.colour,
  });

  final KitTheme kit;
  final String label, value;
  final Key valueKey;
  final Color colour;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: TextStyle(color: kit.textMuted, fontSize: 12)),
      Text(
        value,
        key: valueKey,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: colour,
        ),
      ),
    ],
  );
}

/// A drill's full-time card: the two or three figures it finished on.
///
/// **AND IT SCALES DOWN RATHER THAN OVERFLOWING.** Three [MiniGameStat]s and
/// their gutters come to 378pt at these type sizes, which is wider than a small
/// phone's page — the Boot Room's row of three overflowed by ten as soon as the
/// drills were held to a frame instead of to the whole of a wide window. There
/// is nothing in a figure to drop and nothing to wrap, so on a page too narrow
/// for the row it is the row that gives way.
///
/// One of these rather than one per drill, for the reason [MiniGameStat] gives.
class MiniGameStats extends StatelessWidget {
  const MiniGameStats({super.key, required this.children});

  final List<Widget> children;

  /// The air between two figures.
  static const double gutter = 18;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: gutter),
          children[i],
        ],
      ],
    ),
  );
}
