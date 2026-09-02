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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
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

/// The rewarded-video yellow, and the dark ink that is the only thing readable
/// on it. Shared because a video is offered in two places now — the shop's
/// buttons and the customiser's locked chips — and an offer has to look the
/// same in both or it stops reading as one.
const Color adOfferInk = Color(0xFFFFD54A);
const Color adOfferOnInk = Color(0xFF171717);

/// **The coin and the gem faces, named.** They were literals inside
/// `_paletteFor` and the HUD's badges want the same two — a coin badge in the
/// bar that is a different gold from the coin button you tap is two golds for
/// one currency. See `hudBadgeColour`.
const Color storeCoinFace = Color(0xFFD8A01A);
const Color storeGemFace = Color(0xFF1E88C7);

/// Face, edge and ink per tone. The JS's own values.
({Color face, Color edge, Color ink})? _paletteFor(StoreTone tone) =>
    switch (tone) {
      StoreTone.cash => (
        face: const Color(0xFF43A047),
        edge: const Color(0xFF205C23),
        ink: Colors.white,
      ),
      StoreTone.gem => (
        face: storeGemFace,
        edge: const Color(0xFF12587F),
        ink: Colors.white,
      ),
      StoreTone.coin => (
        face: storeCoinFace,
        edge: const Color(0xFF916709),
        ink: Colors.white,
      ),
      StoreTone.ad => (
        face: adOfferInk,
        edge: const Color(0xFFA37F10),
        ink: adOfferOnInk,
      ),
      // Resolved from the kit at build time — there is no fixed value for it.
      StoreTone.neutral => null,
    };

class StoreButton extends StatefulWidget {
  const StoreButton({
    super.key,
    required this.tone,
    required this.label,
    this.labelSpans,
    required this.onTap,
    this.leading,
    this.small = false,
    this.stretch = true,
    this.onHold,
  });

  final StoreTone tone;

  /// The price, or the verb. Kept as a string rather than a widget so the button
  /// owns its own ink — every caller was picking a colour for the text, and half
  /// of them picked one that only worked on the accent.
  final String label;

  /// Null is dead: flat, faded, and it keeps its label. A button that vanishes
  /// when you cannot afford it takes away the price you needed to see.
  final VoidCallback? onTap;

  /// **The label as SPANS, for a glyph that belongs INSIDE the sentence.**
  ///
  /// [leading] puts a glyph in front of the words, which is where most priced
  /// controls want one. `club.need_more` does not: "Need {coin} {amount} more"
  /// names the currency mid-line and moves it with the language, so the only
  /// place the coin can go is where the translator put it. Build these with
  /// `withCoinGlyph`, and leave [label] as the plain-text reading of the same
  /// line — it is what the button's semantics announce.
  final List<InlineSpan>? labelSpans;

  /// A glyph before the label — a coin, a gem. Takes the button's ink, so a
  /// caller must not colour it.
  final Widget? leading;

  /// The row-sized variant: same shape and colour language, scaled for a list
  /// line rather than a card footer.
  final bool small;

  /// Fills its parent's width. Off for a button sitting in a row beside text.
  final bool stretch;

  /// **HOLD TO KEEP SPENDING.** Fired every [holdRepeat] once the button has
  /// been held for [holdArms], and null on every control where one press means
  /// one purchase.
  ///
  /// It is here rather than at the call site because the JS puts it on the
  /// button too, and because the interesting part is the ARMING: a hold that
  /// fired immediately would make every ordinary tap spend twice, and one that
  /// fired [onTap] as well on release would spend an extra time at the end. So
  /// a press that arms the repeat swallows its own tap.
  final VoidCallback? onHold;

  @override
  State<StoreButton> createState() => _StoreButtonState();
}

/// How long the button has to be held before it starts repeating, and how often
/// it repeats after that. The JS's own 500 and 150.
const Duration holdArms = Duration(milliseconds: 500);
const Duration holdRepeat = Duration(milliseconds: 150);

class _StoreButtonState extends State<StoreButton> {
  bool _down = false;

  Timer? _arming;
  Timer? _repeating;

  /// The repeat has fired at least once, so the release must NOT also tap.
  bool _repeated = false;

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  void _press() {
    if (widget.onTap == null) return;
    setState(() => _down = true);
    if (widget.onHold == null) return;
    _repeated = false;
    _arming = Timer(holdArms, () {
      _repeating = Timer.periodic(holdRepeat, (_) {
        // **The caller decides when to stop by going dead.** A hold that ran
        // past the last affordable upgrade would spend coins that are not
        // there; `onTap` null is the same signal a tap reads.
        if (widget.onTap == null) {
          _stopHold();
          return;
        }
        _repeated = true;
        widget.onHold!.call();
      });
    });
  }

  void _release({required bool tapped}) {
    final repeated = _repeated;
    _stopHold();
    if (_down) setState(() => _down = false);
    if (tapped && !repeated) widget.onTap?.call();
  }

  void _stopHold() {
    _arming?.cancel();
    _repeating?.cancel();
    _arming = null;
    _repeating = null;
  }

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
            child: Builder(
              builder: (context) {
                final style = TextStyle(
                  color: ink,
                  fontSize: widget.small ? 11 : 14,
                  fontWeight: FontWeight.w900,
                );
                // A glyph inside the words comes through as a `WidgetSpan`, and
                // it reads the AMBIENT ink rather than being handed one — the
                // caller has no way to know what colour this face prints in.
                final spans = widget.labelSpans;
                if (spans == null) {
                  return Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
                  );
                }
                return DefaultTextStyle.merge(
                  style: style,
                  child: Text.rich(
                    TextSpan(children: spans),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                );
              },
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
        // **The TAP fires on release, not on `onTap`.** A hold that has already
        // spent must not spend once more when the finger comes off, and
        // `onTap` cannot know whether it did.
        //
        // **The handlers are attached whatever the state**, and the deadness is
        // checked inside them. Dropping them on `dead` looks tidier and is
        // wrong: a button that goes dead DURING a press — which is exactly what
        // the last affordable upgrade does — loses the recogniser mid-gesture,
        // and Flutter reports the release as a spontaneous cancel.
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(tapped: true),
        onTapCancel: () => _release(tapped: false),
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

/// **The `.store-3d` face, for the buttons that are not [StoreButton].**
///
/// The shop's controls have been moulded since the tone palette went in and
/// nothing else in the app was: a Material `ElevatedButton` next to one of these
/// is flat, differently rounded and lights up with a ripple, and the two read as
/// two apps. Reported as every button wanting the same treatment.
///
/// Applied through the THEME rather than at eighty-odd call sites — see
/// `app_theme.dart`. `backgroundBuilder` is the hook: it wraps the padded child
/// inside the button's own `Material`, whose `clipBehavior` is `Clip.none`, so
/// the hard edge underneath survives. The face it paints also covers the ink
/// splash, which is the point — a moulded button answers a press by DROPPING,
/// and a ripple over the top of that is two different answers to one tap.
///
/// [outline] is the secondary form: the same geometry and the same edge bar, an
/// empty face. A cancel that carried a solid face would out-shout the button
/// beside it, which is the one thing the shape is for.
ButtonStyle mouldedButtonStyle({
  required Color face,
  required Color edge,
  required Color ink,
  required Color dead,
  required Color deadInk,
  required Color border,
  bool outline = false,
}) {
  const radius = 10.0;
  const lift = 3.0;
  return ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    side: const WidgetStatePropertyAll(BorderSide.none),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    // Through [controlTextStyle], which names the FAMILY: a button style's
    // textStyle replaces the label's ambient one rather than merging, so a bare
    // literal here put every moulded button in the app in the platform's font.
    textStyle: WidgetStatePropertyAll(controlTextStyle(size: 14)),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? deadInk : ink,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? deadInk : ink,
    ),
    backgroundBuilder: (context, states, child) {
      final off = states.contains(WidgetState.disabled);
      final down = states.contains(WidgetState.pressed) && !off;
      final fill = off ? dead : (outline ? Colors.transparent : face);
      final shape = BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: off || outline
            ? Border.all(color: off ? border : edge, width: outline ? 1.4 : 1)
            : null,
      );
      // **A `BoxShadow` IS ONLY AN EDGE BAR WHEN SOMETHING OPAQUE COVERS THE
      // HALF OF IT THE BUTTON SITS ON.** It is the whole shape offset down and
      // drawn BEHIND the fill, so on the outline form — whose fill is
      // transparent by design — the bar showed straight through the button as a
      // grey slab with a lighter strip along its top edge. Reported as a weird
      // grey 3D border on the bench's buttons. The solid form keeps the shadow;
      // the outline form gets the same bar painted UNDER it — see
      // [_MouldedEdge].
      if (off || !outline) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, down ? lift - 1 : 0, 0),
          decoration: shape.copyWith(
            boxShadow: off
                ? null
                : [
                    BoxShadow(
                      color: edge,
                      offset: Offset(0, down ? 1 : lift),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: child,
        );
      }
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 80),
        tween: Tween<double>(end: down ? 1 : 0),
        builder: (context, t, body) {
          final sink = t * (lift - 1);
          return CustomPaint(
            painter: _MouldedEdge(
              colour: edge,
              radius: radius,
              sink: sink,
              drop: lift - sink,
            ),
            child: Transform.translate(
              offset: Offset(0, sink),
              child: DecoratedBox(decoration: shape, child: body),
            ),
          );
        },
        child: child,
      );
    },
  );
}

/// The moulded button's hard bottom edge, for a face too transparent to hide a
/// shadow — the sliver of the shape that shows below the button, and nothing of
/// the part underneath it.
class _MouldedEdge extends CustomPainter {
  const _MouldedEdge({
    required this.colour,
    required this.radius,
    required this.sink,
    required this.drop,
  });

  final Color colour;
  final double radius;

  /// How far the face has dropped under the press.
  final double sink;

  /// How much of the bar is still showing under it. `sink + drop` is constant,
  /// so the bar's bottom edge never moves — only the button does.
  final double drop;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final face = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, sink, size.width, size.height),
      r,
    );
    final bar = face.shift(Offset(0, drop));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRRect(bar),
        Path()..addRRect(face),
      ),
      Paint()..color = colour,
    );
  }

  @override
  bool shouldRepaint(_MouldedEdge old) =>
      old.colour != colour ||
      old.radius != radius ||
      old.sink != sink ||
      old.drop != drop;
}
