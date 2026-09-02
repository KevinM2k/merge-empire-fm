// The referee's card, as a shape.
//
// **It lives out here rather than on the match screen** because the subs panel
// draws it too — a sending-off puts you in front of the bench with the card
// over the man — and the screen imports the panel, so leaving it there would
// have been a cycle. Screen depends on widget, the way the rest of them do.
import 'package:flutter/widgets.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart';

/// The referee's card, drawn rather than fetched.
///
/// **A rounded rectangle is the whole picture**, which is why there is no asset
/// for it: the shape and the colour ARE the thing, at any size, in any theme,
/// and a bundled PNG would be a file to ship and a manifest row to keep for
/// eleven by fifteen points of solid colour.
///
/// **A second yellow draws BOTH**, overlapped the way a referee holds them. It
/// is not a red — it is a caution too many — and the row above it says so in
/// words; this says it in the picture, which is the half a player actually
/// looks at. Asked for from the couch.
class CardGlyph extends StatelessWidget {
  const CardGlyph({super.key, required this.card, this.height = 15});

  /// `yellow`, `second_yellow` or `red` — see `booking_engine.dart`.
  final String card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = height * 0.72;
    Widget one(Color fill) => Container(
      width: w,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(height * 0.14),
        border: Border.all(color: const Color(0x33000000), width: 0.5),
      ),
    );
    if (card != cardSecondYellow) {
      return one(card == cardRed ? cardRedInk : cardYellowInk);
    }
    // Fanned, so the two read as two rather than as a thick one.
    return SizedBox(
      key: const ValueKey('card-glyph-second-yellow'),
      width: w * 1.5,
      height: height,
      child: Stack(
        children: [
          Transform.rotate(angle: -0.18, child: one(cardYellowInk)),
          Positioned(
            left: w * 0.5,
            child: Transform.rotate(angle: 0.18, child: one(cardRedInk)),
          ),
        ],
      ),
    );
  }
}

/// The two colours a card is, fixed in both themes: a referee's card is the
/// same object whatever the app is wearing, and these are the only two shades
/// anybody would accept for one.
const Color cardYellowInk = Color(0xFFF6C915);
const Color cardRedInk = Color(0xFFE0342B);

/// What a booking's HEAD is printed in. A second yellow takes the red, because
/// what it means is a sending-off — the word beside it is what says which kind.
Color cardInk(String card) => card == cardYellow ? cardYellowInk : cardRedInk;
