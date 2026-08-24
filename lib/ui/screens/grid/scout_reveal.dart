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
/// **The fly-to-slot IS ported**, and it is what joins the reveal to the grid:
/// without it a signing arrived by cut — the backdrop cleared and the card was
/// simply already in a square, with nothing saying which. The JS captures each
/// cell's rect and flies the card home; this does the same, using the grid's
/// own [ScoutLanding] to get there.
///
/// Two things that were once the reason not to. The slot rects are all real —
/// the grid positions every cell inside a `SingleChildScrollView`, so a rect
/// exists whether or not the row is on screen. And the scroll is done EARLY,
/// during the hold, behind a backdrop that is already opaque: by the time the
/// card leaves, the square it is going to is on screen and has not moved.
library;

import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// The grid cell the engine put him in, which is where he flies to. Null when
  /// the caller has no grid to land in — the card settles away instead.
  int? idx,
});

/// The whole reveal: the cards, and the one line underneath them.
typedef ScoutReveal = ({List<ScoutRevealCard> cards, String caption});

/// Where a batch is going: the screen rect of each of [idxs], in the same order,
/// with the grid already scrolled so that every one of them is on it.
///
/// Asked ONCE for the whole batch, because the grid can only scroll to one
/// place — four separate asks would each undo the last one's scroll.
typedef ScoutLanding = Future<List<Rect?>> Function(List<int> idxs);

/// Lent by the mounted grid, which is the only thing that knows where a cell is.
///
/// Null when there is no grid — the Player Index, a test pumping the overlay on
/// its own — and a reveal with nowhere to land settles away as it always did.
final scoutLandingProvider = StateProvider<ScoutLanding?>((_) => null);

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
      idx: idx,
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
///
/// **And a star or a legend gets longer still.** The whole point of scouting is
/// the moment one of them turns over, and the standard hold is tuned for the
/// bronze card that arrives nine times out of ten — long enough to read, not
/// long enough to enjoy. [topTier] is the best tier in the batch.
Duration scoutRevealHold(int cards, {int topTier = 1}) => Duration(
  milliseconds:
      (cards > 1 ? 2300 : 1900) +
      150 +
      (topTier >= 7 ? 900 : (topTier >= 5 ? 450 : 0)),
);

/// The three bands the reveal treats differently: bronze, star, legend.
///
/// **The thresholds are the caption's own** — `merge.signing.star` at 5 and
/// `merge.signing.legendary` at 7 — and the glow's, so a card that is called a
/// legend is lit like one and now arrives like one. Three answers to "how good
/// is this" that disagreed would be worse than one that is only roughly right.
enum RevealTier {
  plain,
  star,
  legend;

  static RevealTier of(int tier) =>
      tier >= 7 ? RevealTier.legend : (tier >= 5 ? RevealTier.star : plain);

  /// How far the card falls in, as a fraction of its own height. A legend
  /// arrives from further away, so the eye follows it in.
  double get drop => switch (this) {
    RevealTier.plain => 0,
    RevealTier.star => 0.22,
    RevealTier.legend => 0.38,
  };

  /// How long the arrival takes. Slower reads as heavier.
  Duration get entrance => switch (this) {
    RevealTier.plain => _popIn,
    RevealTier.star => const Duration(milliseconds: 340),
    RevealTier.legend => const Duration(milliseconds: 460),
  };

  /// A light sweeping across the face once it is turned over. The one thing
  /// here that is pure celebration, so the plain card does not get it.
  bool get shines => this != RevealTier.plain;
}

/// The burst a cashed-in card comes apart with. The backdrop stays up through
/// it — a card exploding over the live UI reads as a glitch rather than a sale.
///
/// The JS's own `VANISH_MS`, and NOT the merge burst's length: the merge is a
/// set-piece that pops and settles over a full second, and holding a black
/// backdrop over the whole game for that long to watch a bronze card be sold is
/// the celebration outstaying the event.
const Duration _vanish = Duration(milliseconds: 520);

/// The keepers settling back into the grid — what a card does when there is no
/// square to fly to.
const Duration _settle = Duration(milliseconds: 320);

/// The journey home. Longer than the merge flight (300ms), because it is a
/// longer way across and the card is shrinking to a fifth of its size on the
/// way: at merge speed it read as being flicked off the screen.
const Duration scoutRevealFlyHome = Duration(milliseconds: 460);

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
Future<void> showScoutReveal(
  BuildContext context,
  ScoutReveal reveal, {
  ScoutLanding? landing,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => ScoutRevealOverlay(
      reveal: reveal,
      landing: landing,
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
    this.landing,
  });

  final ScoutReveal reveal;
  final VoidCallback onDone;

  /// How to find the squares the cards are going to. Null flies nothing.
  final ScoutLanding? landing;

  @override
  State<ScoutRevealOverlay> createState() => ScoutRevealOverlayState();
}

class ScoutRevealOverlayState extends State<ScoutRevealOverlay>
    with TickerProviderStateMixin {
  /// The best tier in the batch, which is what decides how the reveal is
  /// paced: one legend in four cards makes it a legend's reveal.
  RevealTier get _band => RevealTier.of(
    widget.reveal.cards.map((c) => c.view.tier).reduce(math.max),
  );

  /// **The clock the whole reveal is read off**, so it has to outlast the last
  /// thing drawn on it — the sweep, which starts where the flip ends. Leaving
  /// it at the flip's own length capped `elapsed` before the sweep had moved,
  /// so a star's shine would have been a stripe that never travelled.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration:
        _popDelay +
        _flipDelay +
        _flip +
        (_band.shines
            ? const Duration(milliseconds: _shineMs)
            : Duration.zero),
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: _vanish + _settle,
  );
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: scoutRevealFlyHome,
  );

  Timer? _hold;
  bool _leaving = false;

  /// This overlay's own box, so a rect measured off the grid can be put in the
  /// coordinates the flight is drawn in. The root overlay usually fills the
  /// window and the two are the same — usually is not a thing to animate on.
  final GlobalKey _root = GlobalKey();

  /// One per card, to measure the rect it is leaving FROM.
  late final List<GlobalKey> _cardKeys = [
    for (final _ in widget.reveal.cards) GlobalKey(),
  ];

  /// Where each card is going, by its place in the reveal. Resolved during the
  /// hold — see [_resolveLanding].
  final Map<int, Rect> _landing = {};

  /// The cards in flight, and the cards hidden in place because they are.
  List<({ScoutRevealCard card, Rect from, Rect to})> _flights = const [];
  final Set<int> _flew = {};

  /// Test seam: how many cards flew home rather than settling.
  int get flyingHome => _flights.length;

  /// Test seam: has the flip finished, so a tap would skip rather than cut the
  /// reveal off before the player has seen anything?
  bool get canSkip => _in.isCompleted;

  bool get _anyVanishing => widget.reveal.cards.any((c) => c.vanish);

  @override
  void initState() {
    super.initState();
    _in.forward();
    _hold = Timer(
      scoutRevealHold(
        widget.reveal.cards.length,
        topTier: widget.reveal.cards.map((c) => c.view.tier).reduce(math.max),
      ),
      _dismiss,
    );
    _resolveLanding();
  }

  /// **`onDone` MUST FIRE EXACTLY ONCE, INCLUDING ON THE WAY OUT.** The caller
  /// awaits a `Completer` this resolves, and it holds a guard while it waits —
  /// `_revealing` in `add_player_button.dart`, which is what stops a second
  /// scout landing on top of the first. Every path out of [_leave] used to be
  /// conditional on `mounted`, so an unmount mid-exit left the completer
  /// hanging for the life of the process and **the Add Player button dead
  /// permanently** — no error, no message, a control that had worked twice and
  /// then did nothing. It was found walking the tutorial, where it stops a new
  /// player at two cards of the three the second step asks for.
  bool _announced = false;

  void _announceDone() {
    if (_announced) return;
    _announced = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _in.dispose();
    _out.dispose();
    _fly.dispose();
    // Last resort, and it has to be after the controllers rather than before:
    // the caller is free to start another reveal the moment this resolves.
    _announceDone();
    super.dispose();
  }

  /// Ask the grid where the keepers are going, NOW rather than on the way out.
  ///
  /// The ask scrolls the grid, and doing that at dismiss time would either show
  /// the player the grid moving under a clearing backdrop or hold the card still
  /// while it did. Here it happens behind a backdrop that is already opaque, and
  /// costs the reveal nothing: the hold is a second and a half.
  ///
  /// A card being cashed in is not asked for. Flying it to a square it is giving
  /// up reads as a bug, which is the same reason it bursts instead of settling.
  Future<void> _resolveLanding() async {
    final landing = widget.landing;
    if (landing == null) return;
    final cards = widget.reveal.cards;
    final at = <int>[];
    final idxs = <int>[];
    for (var i = 0; i < cards.length; i++) {
      final idx = cards[i].idx;
      if (idx == null || cards[i].vanish) continue;
      at.add(i);
      idxs.add(idx);
    }
    if (idxs.isEmpty) return;
    final rects = await landing(idxs);
    if (!mounted) return;
    for (var i = 0; i < at.length && i < rects.length; i++) {
      final rect = rects[i];
      if (rect != null) _landing[at[i]] = rect;
    }
  }

  /// The flights, measured at the moment of leaving: where each card is on
  /// screen right now, and where it is going.
  List<({ScoutRevealCard card, Rect from, Rect to})> _capture() {
    if (_landing.isEmpty) return const [];
    final root = _root.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || !root.hasSize) return const [];
    final flights = <({ScoutRevealCard card, Rect from, Rect to})>[];
    for (final entry in _landing.entries) {
      final box =
          _cardKeys[entry.key].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      flights.add((
        card: widget.reveal.cards[entry.key],
        from: root.globalToLocal(box.localToGlobal(Offset.zero)) & box.size,
        to: Rect.fromPoints(
          root.globalToLocal(entry.value.topLeft),
          root.globalToLocal(entry.value.bottomRight),
        ),
      ));
      _flew.add(entry.key);
    }
    return flights;
  }

  void _skip() {
    if (!canSkip) return;
    _dismiss();
  }

  void _dismiss() {
    if (_leaving) return;
    _hold?.cancel();
    // Reduce-motion keeps the reveal and drops the journey: a card crossing the
    // screen is the decoration, and the square it lands in is on screen either
    // way because the landing has already scrolled to it.
    final flights = MediaQuery.of(context).disableAnimations
        ? const <({ScoutRevealCard card, Rect from, Rect to})>[]
        : _capture();
    setState(() {
      _leaving = true;
      _flights = flights;
    });
    _leave();
  }

  /// The break, then the journey. A reveal with nothing to break skips straight
  /// to the settle, so a plain signing is not held back by an effect it never
  /// uses — and a batch with one card being cashed in still bursts that one
  /// before the keepers set off.
  Future<void> _leave() async {
    final out = _out.forward(
      from: _anyVanishing
          ? 0
          : _vanish.inMilliseconds / _out.duration!.inMilliseconds,
    );
    if (_flights.isEmpty) {
      await out;
    } else {
      if (_anyVanishing) await Future<void>.delayed(_vanish);
      if (!mounted) return;
      await Future.wait<void>([out, _fly.forward()]);
    }
    _announceDone();
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
      animation: Listenable.merge([_in, _out, _fly]),
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

        return Stack(
          key: _root,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _body(context, kit, cards, size, gap, aspect, backdropAt),
            ),
            // Over the backdrop AND over the grid it is clearing to reveal: the
            // card is the only thing on screen that is still moving.
            for (final flight in _flights)
              _FlightHome(
                flight: flight,
                t: Curves.easeInOutCubic.transform(_fly.value),
              ),
          ],
        );
      },
    );
  }

  /// The backdrop, the cards and the caption — everything that is not in flight.
  Widget _body(
    BuildContext context,
    KitTheme kit,
    List<ScoutRevealCard> cards,
    double size,
    double gap,
    double aspect,
    double backdropAt,
  ) {
    return Semantics(
      label: widget.reveal.caption,
      // A transparent Material, because this is an `OverlayEntry` inserted
      // straight into the root overlay: nothing inside it had a Material
      // ancestor, and every Text in the reveal was drawing Flutter's
      // missing-Material double yellow underline over the caption.
      child: Material(
        type: MaterialType.transparency,
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
                          key: _cardKeys[i],
                          card: cards[i],
                          size: size,
                          aspect: aspect,
                          elapsedMs: _elapsed,
                          leaving: _leaving ? _out : null,
                          reduceMotion: MediaQuery.disableAnimationsOf(context),
                          // Hidden rather than removed: it is the same card,
                          // drawn by the flight instead, and taking its space
                          // out of the Wrap would shuffle the ones beside it
                          // sideways as it left.
                          flownAway: _flew.contains(i),
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
      ),
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
    super.key,
    required this.card,
    required this.size,
    required this.aspect,
    required this.elapsedMs,
    required this.leaving,
    required this.reduceMotion,
    this.flownAway = false,
  });

  final ScoutRevealCard card;
  final double size;
  final double aspect;
  final double elapsedMs;
  final AnimationController? leaving;
  final bool reduceMotion;
  final bool flownAway;

  @override
  Widget build(BuildContext context) {
    // Its space, and nothing in it: the flight is drawing this card now.
    if (flownAway) return SizedBox(width: size, height: size * aspect);

    final kit = Theme.of(context).extension<KitTheme>()!;
    final elapsed = elapsedMs;

    // Reduce-motion keeps the reveal — it is information, not decoration — and
    // drops the movement: the card is simply there, face up, with its caption.
    // **THE TOP TIERS ARRIVE DIFFERENTLY.** A star falls further and lands
    // slower than a bronze; a legend further and slower again. Same curve, so
    // it is recognisably the same reveal — what changes is the weight.
    final band = RevealTier.of(card.view.tier);
    final arriving = reduceMotion
        ? 1.0
        : ((elapsed - _popDelay.inMilliseconds) /
                  band.entrance.inMilliseconds)
              .clamp(0.0, 1.0);
    final pop = reduceMotion ? 1.0 : Curves.easeOutBack.transform(arriving);
    final drop = reduceMotion
        ? 0.0
        : (1 - Curves.easeOutCubic.transform(arriving)) * band.drop;
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
          // Counter-rotated: the wrapper is at 180° while the back is showing,
          // which would otherwise mirror the ball and the wordmark. The JS gets
          // this from `preserve-3d` plus its own `rotateY(180deg)` on the back
          // face; with one widget swapped for the other it has to be said.
          : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _CardBack(kit: kit, size: size, tier: card.view.tier),
            ),
    );

    // Every card is rimmed in its own tier's glow, face up or face down — the
    // JS puts this on the wrapper so it survives the rotation.
    body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: revealGlowFor(card.view.tier).withValues(alpha: 0.6),
            blurRadius: card.view.tier >= 7
                ? size * 0.28
                : card.view.tier >= 5
                ? size * 0.2
                : size * 0.12,
          ),
        ],
      ),
      child: body,
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
        duration: _vanish,
        // Money, not the tier he happened to be — and no pop, because a card
        // being cashed in is on its way out and popping it says the opposite.
        coins: true,
        pop: false,
        child: Opacity(opacity: (1 - (out * 2)).clamp(0.0, 1.0), child: body),
      );
    }

    // The sweep, after it is face up: one pass, and only for a star or better.
    if (band.shines && faceUp && !reduceMotion) {
      body = _Shine(
        progress:
            ((elapsed -
                        _popDelay.inMilliseconds -
                        _flipDelay.inMilliseconds -
                        _flip.inMilliseconds) /
                    _shineMs)
                .clamp(0.0, 1.0),
        radius: 14,
        child: body,
      );
    }

    return Transform.translate(
      offset: Offset(0, size * aspect * drop),
      child: Transform.scale(
        scale: pop * (1 - settle * 0.85),
      // A REAL rotation about Y, under the JS's own 1100px perspective. It had
      // been faked as a horizontal squeeze, on the reasoning that the
      // perspective is invisible at this size — it is not: a squeeze reads as
      // the card being crushed rather than turned, and at the halfway point it
      // collapses to a line with no edge to follow.
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 1 / 1100)
          ..rotateY(reduceMotion ? 0 : (1 - flip) * math.pi),
          child: Opacity(opacity: (1 - settle).clamp(0.0, 1.0), child: body),
        ),
      ),
    );
  }
}

/// How long the sweep takes to cross the card.
const int _shineMs = 620;

/// A band of light crossing the face, once.
///
/// **Clipped to the card and drawn OVER it**, rather than a glow around it: the
/// rim already carries the tier's colour and a second halo would just be a
/// brighter version of the same statement. A sweep is the card catching the
/// light, which is what a special card in every other game in the genre does.
class _Shine extends StatelessWidget {
  const _Shine({
    required this.progress,
    required this.radius,
    required this.child,
  });

  /// 0 to 1 across the card. At 1 it draws nothing at all.
  final double progress;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    // Diagonal, which is what makes it read as a reflection
                    // rather than as a wipe.
                    begin: const Alignment(-1.6, -1),
                    end: const Alignment(1.6, 1),
                    colors: const [
                      Color(0x00FFFFFF),
                      Color(0x66FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [
                      (progress - 0.22).clamp(0.0, 1.0),
                      progress.clamp(0.0, 1.0),
                      (progress + 0.22).clamp(0.0, 1.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card on its way home: from where it was turned over to the square the
/// engine put him in.
///
/// The rect is LERPED rather than scaled, so it lands on the square exactly — a
/// scale about the centre would leave it a few pixels out at every aspect ratio
/// the grid has, and being a few pixels out is the whole thing this fixes. The
/// real card is already in that square underneath, so the flight simply stops
/// and there is no swap to see.
class _FlightHome extends StatelessWidget {
  const _FlightHome({required this.flight, required this.t});

  final ({ScoutRevealCard card, Rect from, Rect to}) flight;
  final double t;

  @override
  Widget build(BuildContext context) {
    final rect = Rect.lerp(flight.from, flight.to, t)!;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                // Fades out as it arrives, because the card it becomes has no
                // glow: the hand-off is the last thing that would give it away.
                BoxShadow(
                  color: revealGlowFor(
                    flight.card.view.tier,
                  ).withValues(alpha: 0.6 * (1 - t)),
                  blurRadius: rect.width * 0.2,
                ),
              ],
            ),
            child: PlayerCard(
              key: const ValueKey('scout-reveal-flight'),
              view: flight.card.view,
              light: Theme.of(context).brightness == Brightness.light,
            ),
          ),
        ),
      ),
    );
  }
}

/// The tier glow a reveal is lit by — purple for a legend, gold for a star,
/// green for everyone else. The card back is rimmed in it, so a legendary turns
/// up behind a legendary-coloured back.
Color revealGlowFor(int tier) => tier >= 7
    ? const Color(0xFFB06AFF)
    : tier >= 5
    ? const Color(0xFFFFD700)
    : const Color(0xFF4CAF50);

/// The face-down card. No question mark: the flip shows the real player, so the
/// back is the club's OWN, not a placeholder for one.
///
/// It had been drawn from the kit's surfaces, which on most kits is the same
/// near-black as the overlay behind it — so the back of the card was invisible
/// and the flip looked like a card appearing out of nothing. This is the JS's
/// own back: a deep navy-to-indigo plate, rimmed in the tier's glow, carrying
/// the ball and the club wordmark.
class _CardBack extends StatelessWidget {
  const _CardBack({required this.kit, required this.size, this.tier = 1});

  final KitTheme kit;
  final double size;
  final int tier;

  @override
  Widget build(BuildContext context) {
    final glow = revealGlowFor(tier);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glow.withValues(alpha: 0.4), width: 2),
        gradient: const LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.7, 1),
          colors: [Color(0xFF0D1B2A), Color(0xFF100030)],
        ),
      ),
      child: Stack(
        children: [
          // `inset 0 0 24px rgba(0,0,0,0.55)` — a vignette, which a BoxShadow
          // cannot draw inward, so it is a gradient overlay instead.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: RadialGradient(
                  radius: 0.9,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '⚽',
                  style: TextStyle(
                    fontSize: size * 0.34,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: glow.withValues(alpha: 0.53),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: size * 0.06),
                Text(
                  'MERGE EMPIRE FC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (size * 0.072).clamp(6, 12),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
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
