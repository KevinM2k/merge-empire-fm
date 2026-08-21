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
