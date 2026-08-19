/// The turn-over a signing lands with. Ported from `showCenterCardReveal` and
/// `showMultiCardReveal` in `ui/components/MergeAnimation.js`.
///
/// Without it Add Player was a button that took coins and quietly changed a
/// square somewhere down the grid — often below the fold, so the one thing the
/// player had just paid for was the one thing they could not see.
///
/// **Not a fourth popup shape.** A reveal asks nothing, holds nothing and is
/// never the thing a player is answering: it is an animation layer, the same
/// kind of thing as `merge_burst.dart` and the toast host. The three shapes are
/// for decisions.
///
/// The JS keeps two functions for one card and for several, because the
/// single-card beat carries per-card DOM plumbing that folding N-up layout into
/// would branch. Here it is one widget: Flutter composes the two layouts out of
/// the same subtree, and a second implementation would be the thing that drifts.
///
/// **The fly-to-slot is deliberately not ported.** The JS captures each cell's
/// rect and flies the card home; the port's grid is a scrolling `GridView`
/// whose rows are built on demand, so the slot a card is going to usually is
/// not on screen — and animating toward a rect that does not exist is worse
/// than not animating at all. The keepers shrink away as the backdrop clears,
/// which says the same thing without lying about where they went.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_burst.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One card being turned over.
typedef ScoutRevealCard = ({
  CardView view,

  /// A pill pinned to the card itself, or null. It has to live on the card
  /// rather than above it: in a batch the cards are packed too tightly for a
  /// caption between them, and one that moved depending on how many you scouted
  /// would read as two different features.
  String? badge,

  /// A first-ever sighting, which the card is haloed in gold for.
  bool isNewDiscovery,

  /// Bursts into coins instead of settling — a card the tier rules are about to
  /// cash in. Flying it to a slot it is giving up reads as a bug.
  bool vanish,
});

/// The whole reveal: the cards, and the one line underneath them.
typedef ScoutReveal = ({List<ScoutRevealCard> cards, String caption});

/// What to show for what a batch delivered, or null when it delivered nothing.
///
/// The caption rules are the JS's, and the ORDER matters. Auto-sold outranks
/// everything: "you found this and it is already gone" is the thing the player
/// has to understand, and there is only one line to say it in. The voucher
/// caption sits next, because the voucher is WHY this card is here and the
/// promise it made is what wants checking against it. A first sighting comes
/// last, and can be said alongside a voucher — the pill on the card, the line
/// below it.
///
/// The voucher line does NOT name the tier: the card it captions is right there
/// at full size wearing that tier's colours, so the floor was saying twice over
/// what the card says better.
ScoutReveal? scoutRevealFor(Map<String, dynamic>? state, List<Signing> placed) {
  final cells = gridCells(state);
  final pro = isProMode(state);

  String? badgeFor(Signing s) => s.autoSell
      ? t('grid.auto_sell_badge', {'coins': formatCoins(s.sellCoins)})
      : (s.voucherFloor != null || s.voucherRandom)
      ? t('grid.voucher_badge')
      : null;

  final cards = <ScoutRevealCard>[];
  final single = placed.length == 1;
  for (final signing in placed) {
    final idx = signing.idx;
    if (idx == null || idx >= cells.length) continue;
    final view = cardViewFor(cells[idx], proMode: pro);
    if (view == null) continue;
    cards.add((
      view: view,
      // One card that is being cashed in takes the LINE instead of a pill: that
      // is a verdict on the card rather than a label for it, and the card is
      // about to come apart anyway.
      badge: single && signing.autoSell ? null : badgeFor(signing),
      isNewDiscovery: signing.isNewDiscovery,
      vanish: signing.autoSell,
    ));
  }
  if (cards.isEmpty) return null;

  if (!single) {
    return (
      cards: cards,
      caption: t('grid.scouted_batch', {'n': cards.length}),
    );
  }

  final only = placed.first;
  final tier = cards.first.view.tier;
  final caption = only.autoSell
      ? badgeFor(only)!
      : only.isNewDiscovery
      ? t('grid.new_player_found')
      : tier >= 7
      ? '⭐ ${t('merge.signing.legendary')}'
      : tier >= 5
      ? '🌟 ${t('merge.signing.star')}'
      : '✅ ${t('merge.signing.new')}';
  return (cards: cards, caption: caption);
}

// ── The beats ───────────────────────────────────────────────────────────────
//
// The JS's own timings, kept because they are tuned: the pause before the card
// arrives is what makes the flip land, and the skip is locked until the flip has
// finished so a quick tap cannot whisk the card away before it has been seen.

const Duration _backdropIn = Duration(milliseconds: 120);
const Duration _popDelay = Duration(milliseconds: 150);
const Duration _popIn = Duration(milliseconds: 240);
const Duration _flipDelay = Duration(milliseconds: 420);
const Duration _flip = Duration(milliseconds: 600);
const Duration _captionDelay = Duration(milliseconds: 360);

/// How long the cards are held before dismissing themselves. A batch gets
/// longer: there is more to take in.
Duration scoutRevealHold(int cards) =>
    Duration(milliseconds: (cards > 1 ? 2300 : 1900) + 150);

/// The burst a cashed-in card comes apart with. The backdrop stays up through
/// it — a card exploding over the live UI reads as a glitch rather than a sale.
const Duration _vanish = mergeBurstDuration;

/// The keepers settling back into the grid.
const Duration _settle = Duration(milliseconds: 320);

/// The halo a first-ever sighting wears. Gold whatever the kit is: it means the
/// same thing in every club's colours, and the tier palette already owns the
/// card's own edge.
const Color _discoveryGold = Color(0xFFFFD700);

/// When the tap-to-skip becomes live: once the flip has fully landed.
Duration get scoutRevealSkipAfter => _popDelay + _flipDelay + _flip;

/// Put a reveal on screen, and complete once it is gone.
///
/// An overlay entry rather than a route: nothing here is navigated to, and a
/// route would put a reveal in the back stack, where an Android back press
/// would "return" from an animation.
Future<void> showScoutReveal(BuildContext context, ScoutReveal reveal) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => ScoutRevealOverlay(
      reveal: reveal,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class ScoutRevealOverlay extends StatefulWidget {
  const ScoutRevealOverlay({
    super.key,
    required this.reveal,
    required this.onDone,
  });

  final ScoutReveal reveal;
  final VoidCallback onDone;

  @override
  State<ScoutRevealOverlay> createState() => ScoutRevealOverlayState();
}

class ScoutRevealOverlayState extends State<ScoutRevealOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: _popDelay + _flipDelay + _flip,
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: _vanish + _settle,
  );

  Timer? _hold;
  bool _leaving = false;

  /// Test seam: has the flip finished, so a tap would skip rather than cut the
  /// reveal off before the player has seen anything?
  bool get canSkip => _in.isCompleted;

  bool get _anyVanishing => widget.reveal.cards.any((c) => c.vanish);

  @override
  void initState() {
    super.initState();
    _in.forward();
    _hold = Timer(scoutRevealHold(widget.reveal.cards.length), _dismiss);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  void _skip() {
    if (!canSkip) return;
    _dismiss();
  }

  void _dismiss() {
    if (_leaving) return;
    _hold?.cancel();
    setState(() => _leaving = true);
    // A reveal with nothing to break skips straight to the settle, so a plain
    // signing is not held back by an effect it never uses.
    _out
        .forward(
          from: _anyVanishing
              ? 0
              : _vanish.inMilliseconds / _out.duration!.inMilliseconds,
        )
        .then((_) {
          if (mounted) widget.onDone();
        });
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final media = MediaQuery.of(context);
    final cards = widget.reveal.cards;
    final cols = cards.length <= 2 ? cards.length : 2;
    final rows = (cards.length / cols).ceil();

    // Fitted to BOTH axes. Four cards two deep is height-bound on a short
    // phone, and a width-only cap pushed the bottom row — and the caption —
    // off the screen.
    const gap = 12.0;
    const aspect = 1.44;
    final size = [
      (media.size.width * 0.86 - (cols - 1) * gap) / cols,
      (media.size.height * 0.62 - (rows - 1) * gap) / (rows * aspect),
      cards.length == 1 ? 220.0 : 165.0,
    ].reduce((a, b) => a < b ? a : b).clamp(64.0, 260.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      builder: (context, _) {
        final leaving = _out.value;
        // The backdrop holds through the break and clears for the settle.
        final backdropAt = _leaving
            ? (1 -
                  ((leaving * _out.duration!.inMilliseconds -
                              _vanish.inMilliseconds) /
                          _settle.inMilliseconds)
                      .clamp(0.0, 1.0))
            : (_elapsed / _backdropIn.inMilliseconds).clamp(0.0, 1.0);

        return Semantics(
          label: widget.reveal.caption,
          child: GestureDetector(
            key: const ValueKey('scout-reveal'),
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kit.surface.withValues(alpha: 0.72 * backdropAt),
                    Colors.black.withValues(alpha: 0.92 * backdropAt),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          _RevealCard(
                            card: cards[i],
                            size: size,
                            aspect: aspect,
                            elapsedMs: _elapsed,
                            leaving: _leaving ? _out : null,
                            reduceMotion: media.disableAnimations,
                          ),
                      ],
                    ),
                    SizedBox(height: cards.length > 1 ? 16 : 18),
                    Opacity(
                      opacity: _leaving ? 0 : _captionOpacity,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: size * 1.25),
                        child: Text(
                          widget.reveal.caption,
                          key: const ValueKey('scout-reveal-caption'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kit.accentBright,
                            fontSize: 14,
                            height: 1.3,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Where the arrival is up to, in milliseconds.
  ///
  /// Off the controller's VALUE rather than its last tick: a frame that lands
  /// past the end of the animation has no last tick, and the cards were reading
  /// as still face down at the very moment they had finished turning over.
  double get _elapsed => _in.value * _in.duration!.inMilliseconds;

  /// The line rises once the flip is on its way, not before: it is a verdict on
  /// a card the player can already see.
  double get _captionOpacity =>
      ((_elapsed - _captionDelay.inMilliseconds) / 280).clamp(0.0, 1.0);
}

/// One card: pops in face down, flips to its face, wears its pill, and either
/// settles away or comes apart.
class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.card,
    required this.size,
    required this.aspect,
    required this.elapsedMs,
    required this.leaving,
    required this.reduceMotion,
  });

  final ScoutRevealCard card;
  final double size;
  final double aspect;
  final double elapsedMs;
  final AnimationController? leaving;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final elapsed = elapsedMs;

    // Reduce-motion keeps the reveal — it is information, not decoration — and
    // drops the movement: the card is simply there, face up, with its caption.
    final pop = reduceMotion
        ? 1.0
        : Curves.easeOutBack.transform(
            ((elapsed - _popDelay.inMilliseconds) / _popIn.inMilliseconds)
                .clamp(0.0, 1.0),
          );
    final flip = reduceMotion
        ? 1.0
        : ((elapsed - _popDelay.inMilliseconds - _flipDelay.inMilliseconds) /
                  _flip.inMilliseconds)
              .clamp(0.0, 1.0);
    final faceUp = flip >= 0.5;

    final out = leaving?.value ?? 0;
    final settle = leaving == null
        ? 0.0
        : ((out * (_vanish + _settle).inMilliseconds - _vanish.inMilliseconds) /
                  _settle.inMilliseconds)
              .clamp(0.0, 1.0);

    Widget body = SizedBox(
      width: size,
      height: size * aspect,
      child: faceUp
          ? PlayerCard(
              key: const ValueKey('scout-reveal-card'),
              view: card.view,
              light: Theme.of(context).brightness == Brightness.light,
            )
          : _CardBack(kit: kit, size: size),
    );

    // A first sighting is haloed rather than confettied. The JS rains pieces
    // over the whole overlay, which is a per-card effect drawn app-wide: at ×4
    // it would be four rains on top of each other with no telling which card
    // earned them, where a glow belongs to the card it is around.
    if (card.isNewDiscovery && faceUp) {
      body = DecoratedBox(
        key: const ValueKey('scout-reveal-discovery'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _discoveryGold.withValues(alpha: 0.55),
              blurRadius: size * 0.22,
              spreadRadius: size * 0.03,
            ),
          ],
        ),
        child: body,
      );
    }

    if (card.badge != null && faceUp) {
      body = Stack(
        alignment: Alignment.bottomCenter,
        children: [
          body,
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _Pill(text: card.badge!, size: size),
          ),
        ],
      );
    }

    if (card.vanish && leaving != null) {
      body = MergeBurst(
        tier: card.view.tier,
        playing: true,
        child: Opacity(opacity: (1 - (out * 2)).clamp(0.0, 1.0), child: body),
      );
    }

    return Transform.scale(
      scale: pop * (1 - settle * 0.85),
      // The flip is drawn as a horizontal squeeze rather than a real 3D
      // rotation: at these sizes the perspective is invisible, and a scale is
      // one matrix instead of a transform hierarchy per card.
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          reduceMotion ? 1 : (flip - 0.5).abs() * 2,
          1,
          1,
        ),
        child: Opacity(opacity: (1 - settle).clamp(0.0, 1.0), child: body),
      ),
    );
  }
}

/// The face-down card. No question mark: the flip shows the real player, so the
/// back is the club's own, not a placeholder for one.
class _CardBack extends StatelessWidget {
  const _CardBack({required this.kit, required this.size});

  final KitTheme kit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kit.accent.withValues(alpha: 0.4), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kit.surface2, kit.bg],
        ),
      ),
      child: Center(
        child: Text('⚽', style: TextStyle(fontSize: size * 0.36)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('scout-reveal-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kit.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        // Scaled off the card's own size, so it stays in proportion from a hero
        // card down to one in a two-by-two.
        style: TextStyle(
          color: kit.accentBright,
          fontSize: (size * 0.08).clamp(8, 13),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
