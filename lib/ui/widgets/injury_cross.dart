// The hospital cross, out here rather than on the pitch token.
//
// **It lives in the widgets layer because BOTH sides draw it now.** The token
// has always had it; a `PlayerCard` on the bench got it when the tier stopped
// being replaced by `INJ`, and the token imports the card — so leaving it there
// would have been a cycle. Screen depends on widget, the way the rest of them
// do. `pitch_token.dart` re-exports it so its own callers are unchanged.
import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// The hospital cross a hurt player wears.
///
/// **A cross reads at a glance, and in every language.** It replaces a chip
/// spelling `INJ` — three letters at eight points on a token an inch wide, which
/// is neither glanceable nor the same three letters in the other nine
/// catalogues. The translated word is still on the token for a screen reader,
/// because trading a translated string for an icon outright would be a step
/// back; what the eye gets is the cross.
class InjuryCross extends StatelessWidget {
  const InjuryCross({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: t('card.inj_short'),
    child: CustomPaint(
      key: const ValueKey('injury-cross'),
      size: Size.square(size),
      painter: const _CrossPainter(),
    ),
  );
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFCC2222));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFFF5555)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16,
    );
    // The bar of the cross is a third of the disc, which is the proportion a
    // first-aid cross actually uses — thinner reads as a plus sign.
    final arm = r * 0.62;
    final half = r * 0.19;
    final ink = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromCenter(center: c, width: arm * 2, height: half * 2),
      ink,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c, width: half * 2, height: arm * 2),
      ink,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}
