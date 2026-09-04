/// A section heading: a glyph, the name in caps, and a rule out to the edge.
///
/// **THE SHOP'S TREATMENT, and it is here because a second screen wanted it.**
/// Seven shelves' worth of it lived inline in `ShopSectionFrame` and the trophy
/// room had a heading of its own — bare uppercase text, no glyph, no rule — so
/// the two sheets a player scrolls longest disagreed about what a heading looks
/// like. Asked for from the couch: the trophy room's should read like the
/// shop's. One widget rather than two, for the reason every other shared piece
/// in this app is one: there were two and they drifted.
///
/// The caller brings the glyph and the ink. **Each section has its OWN colour**
/// where the sections are things you navigate between — that is what makes a
/// column of them scannable, and painting them all in the club's accent turns a
/// long sheet into one undifferentiated list. Where the sections are a series
/// rather than a menu, the icon carries the difference and the ink stays put.
library;

import 'package:flutter/material.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    required this.icon,
    required this.ink,
    super.key,
  });

  /// Rendered in caps. Pass it in the caller's own words — this does not
  /// translate.
  final String title;

  /// Line art, not emoji: a section heading is interface.
  final IconData icon;

  /// The glyph's colour, and the rule's at a lower alpha.
  final Color ink;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // NO DISC. Every icon in the shop used to sit in a bordered, tinted box
      // and the gem tiles never did — and the gem tiles are the ones that look
      // right. A frame around a glyph adds a rectangle competing with the
      // card's own edge and shrinks the art to pay for it. Bigger glyph, no box.
      Icon(icon, size: 20, color: ink),
      const SizedBox(width: 8),
      // Flexible: "MANAGER-ANPASSUNG" is wider than a 320pt phone once the
      // glyph and the rule either side are paid for. Found by the long-language
      // sweep.
      Flexible(
        child: Text(
          title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
      const SizedBox(width: 8),
      // The rule runs to the right edge and fades out. It stops the heading
      // floating unattached above its content, and does most of the work of
      // "this is a section" without a heavy container round everything.
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ink.withValues(alpha: 0.45), Colors.transparent],
            ),
          ),
        ),
      ),
    ],
  );
}
