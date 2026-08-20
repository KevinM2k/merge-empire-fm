/// The title at the top of anything that rises: a bottom sheet, a menu, a
/// takeover panel.
///
/// **ONE RULE, EVERYWHERE, AND THAT IS THE WHOLE POINT.** There were at least
/// five: the Energy sheet's accent green at 18 centred; Auto-Sell's plain ink at
/// 16 left-aligned; the Trophy Room's caps; Coach Colin's plain w900 at 17; the
/// quick nav's accent at 18 with a centred subtitle. Every one of them defensible
/// on its own and the set of them reads as five different apps — which is exactly
/// what a player notices when they open three sheets in a row.
///
/// The rule:
///
/// - **CAPS.** The app is already full of them — group headings, the fixture
///   caption, the tactic line, the tab strip — so a sentence-case title was the
///   odd one out rather than the calm one.
/// - **The club's ACCENT.** A sheet is the game talking, and the accent is the
///   game's voice. Plain ink made a title read as the first line of the content.
/// - **CENTRED.** A sheet is a modal, not a page: it has no navigation rail to
///   align to and no breadcrumb above it, and a left-aligned title in a
///   rounded box drifts away from the box's own symmetry.
/// - **15px, w900, +0.8 tracking.** 18 was shouting at a subtitle two points
///   below it; caps buy back the presence that costs.
/// - **A subtitle is MUTED and sentence-case**, because it is a sentence.
///
/// Anything with a genuine reason to differ states it at the call site. There are
/// two so far: Coach Colin's card, whose title is him speaking and sits under his
/// own name plate, and the achievement banner, which is a celebration rather than
/// a heading.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 10),
  });

  /// As the catalogue writes it. Upper-cased here rather than in the string, so
  /// a language that has no case — Japanese, Chinese, Arabic — is untouched.
  final String title;

  /// One sentence under it. Not a second heading.
  final String? subtitle;

  /// A close button, a counter, a filter. Kept OUT of the centring: the title
  /// stays centred on the sheet rather than on whatever is left beside it.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kit.accentBright,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kit.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: trailing == null
          ? heading
          : Stack(
              alignment: Alignment.center,
              children: [
                heading,
                // Over the top rather than in a row: a trailing control that
                // takes width off the middle moves the title off centre, and a
                // title that shifts depending on whether a sheet has a close
                // button is the inconsistency this file exists to stop.
                Positioned(top: 0, right: 0, child: trailing!),
              ],
            ),
    );
  }
}
