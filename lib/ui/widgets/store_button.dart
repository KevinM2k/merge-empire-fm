/// The button every price sits on. Ported from `.store-btn` in
/// `styles/screens.css`.
///
/// **ONE BUTTON, FOUR COLOURS — and the colour always answers "what does this
/// cost me?"** That is the JS's own sentence and it is the whole design:
///
/// | green  | real money        | blue   | gems            |
/// | gold   | in-game coins     | yellow | a rewarded video |
///
/// The card AROUND a button can be coloured for what it IS — a gem chest is
/// blue, the Vault is Looks purple — but the button is coloured for its PRICE.
/// That separation is what lets a purple case hold blue-priced packs and a green
/// buy button without any of the three lying. The port had every one of them as
/// a plain `ElevatedButton` in the kit accent, so a shelf of coin packs, gem
/// packs and cash packs was one green wall and the price was the only thing that
/// told them apart.
///
/// **It is MOULDED, not flat**, and that matters more here than anywhere else in
/// the app: a hard 3px edge underneath, a bright inner line along the top, and a
/// press that drops the face onto its own edge. A shop is the one screen where a
/// control has to look worth pressing, and a flat rectangle in the accent looks
/// like a link.
///
/// **Yellow needs DARK ink**, which is why the tone carries its own ink rather
/// than every caller working it out — `#ffd54a` with white on it is unreadable,
/// and it is the one tone in the set that inverts.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// What the button costs, which is what decides its colour.
enum StoreTone {
  /// Real money. The only tone that leaves the game to be paid.
  cash,

  /// Gems — the same blue the HUD shows the balance in.
  gem,

  /// Coins — the same gold the HUD shows the balance in.
  coin,

  /// A rewarded video. Wears an AD chip, because the label is a verb ("Claim")
  /// and the disclosure has to come from somewhere.
  ad,

  /// Not a price at all: confirm, continue, equip. Takes the club's accent, so
  /// the one button on the screen that is not buying anything does not borrow a
  /// currency's colour.
  neutral,
}

/// Face, edge and ink per tone. The JS's own values.
({Color face, Color edge, Color ink})? _paletteFor(StoreTone tone) =>
    switch (tone) {
      StoreTone.cash => (
        face: const Color(0xFF43A047),
        edge: const Color(0xFF205C23),
        ink: Colors.white,
      ),
      StoreTone.gem => (
        face: const Color(0xFF1E88C7),
        edge: const Color(0xFF12587F),
        ink: Colors.white,
      ),
      StoreTone.coin => (
        face: const Color(0xFFD8A01A),
        edge: const Color(0xFF916709),
        ink: Colors.white,
      ),
      StoreTone.ad => (
        face: const Color(0xFFFFD54A),
        edge: const Color(0xFFA37F10),
        ink: const Color(0xFF171717),
      ),
      // Resolved from the kit at build time — there is no fixed value for it.
      StoreTone.neutral => null,
    };

class StoreButton extends StatefulWidget {
  const StoreButton({
    super.key,
    required this.tone,
    required this.label,
    required this.onTap,
    this.leading,
    this.small = false,
    this.stretch = true,
  });

  final StoreTone tone;

  /// The price, or the verb. Kept as a string rather than a widget so the button
  /// owns its own ink — every caller was picking a colour for the text, and half
  /// of them picked one that only worked on the accent.
  final String label;

  /// Null is dead: flat, faded, and it keeps its label. A button that vanishes
  /// when you cannot afford it takes away the price you needed to see.
  final VoidCallback? onTap;

  /// A glyph before the label — a coin, a gem. Takes the button's ink, so a
  /// caller must not colour it.
  final Widget? leading;

  /// The row-sized variant: same shape and colour language, scaled for a list
  /// line rather than a card footer.
  final bool small;

  /// Fills its parent's width. Off for a button sitting in a row beside text.
  final bool stretch;

  @override
  State<StoreButton> createState() => _StoreButtonState();
}

class _StoreButtonState extends State<StoreButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final dead = widget.onTap == null;
    final palette =
        _paletteFor(widget.tone) ??
        (
          face: kit.accent,
          // The kit has no "deep accent", and the edge cannot be a fixed one:
          // it has to be the SAME hue as the face or the button reads as two
          // colours stuck together. Darkening the accent is what the four fixed
          // tones do by hand, done arithmetically for the one that is themed.
          edge: Color.alphaBlend(
            Colors.black.withValues(alpha: 0.45),
            kit.accent,
          ),
          ink: kit.accentInk,
        );

    final face = dead ? kit.surface2 : palette.face;
    final ink = dead ? kit.textMuted : palette.ink;
    final radius = widget.small ? 9.0 : 10.0;
    // The edge is a hard offset shadow, not a blur — a moulded button has a
    // visible thickness under it, and a blur is a drop shadow instead.
    final lift = widget.small ? 2.0 : 3.0;

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      // Pressed, the face travels DOWN onto its own edge and the edge shortens
      // by the same amount, so the button's outside stays where it was.
      transform: Matrix4.translationValues(0, _down && !dead ? lift - 1 : 0, 0),
      padding: widget.small
          ? const EdgeInsets.symmetric(horizontal: 11, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(radius),
        border: dead ? Border.all(color: kit.border) : null,
        boxShadow: dead
            ? null
            : [
                BoxShadow(
                  color: palette.edge,
                  offset: Offset(0, _down ? 1 : lift),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Row(
        mainAxisSize: widget.stretch ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: ink, size: widget.small ? 11 : 14),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: ink),
                child: widget.leading!,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: widget.small ? 11 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (widget.tone == StoreTone.ad && !dead) ...[
            const SizedBox(width: 4),
            const _AdChip(),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: !dead,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: dead ? null : (_) => setState(() => _down = true),
        onTapUp: dead ? null : (_) => setState(() => _down = false),
        onTapCancel: dead ? null : () => setState(() => _down = false),
        child: Opacity(opacity: dead ? 0.55 : 1, child: body),
      ),
    );
  }
}

/// The disclosure on a rewarded-video button.
///
/// On the button rather than beside it, and always the same two letters: the
/// label says what you get, so this is the only thing saying how it is paid for.
class _AdChip extends StatelessWidget {
  const _AdChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.34),
      borderRadius: BorderRadius.circular(3),
    ),
    child: const Text(
      'AD',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        height: 1.4,
      ),
    ),
  );
}
