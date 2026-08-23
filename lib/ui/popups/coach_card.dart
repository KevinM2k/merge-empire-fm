/// Coach Colin's card — the shape EVERY decision arrives in.
///
/// **He is who the player talks to.** Not a dialog with a coach's name on it: a
/// centred card with his own face floating on its top edge, his name under it,
/// and the body written as him speaking. Anything the game asks the player to
/// decide — a sponsor's offer, releasing a player, wiping a save — comes through
/// him, because a game that has a manager to talk to should not also have a
/// system voice.
///
/// **A stated exception to `SheetHeader`.** Its title is him speaking and sits
/// under his own name plate, so the sheet rule's caps and club accent would put
/// the game's voice in the middle of his.
///
/// Four things the shape does, and each was a fault in what it replaced:
///
/// 1. **His portrait sits ON the border**, half above the card. A face inside a
///    title row is an avatar beside a heading; a face breaking the frame is
///    someone leaning in.
/// 2. **His NAME is under it**, so the voice is attributed and the copy is free
///    to speak in the first person. It said "Coach Colin suggests Balanced" —
///    third person, about himself, while being the one saying it.
/// 3. **The text is there IMMEDIATELY.** No typing animation: these are
///    decisions, often on a clock, and making someone wait for a sentence they
///    are about to answer is the wrong place to spend charm.
/// 4. **The answers are COLOURED.** Yes is green and no is red, so the shape of
///    the decision is readable before the words are.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// Colin's portrait, as the JS's `COLIN_IMG`.
const String coachPortrait = 'assets/ui/manager_hint.png';

/// **His face, cropped to it.**
///
/// The source is a 512-square of him from the hair down to the chest on white,
/// so the whole drawing dropped into a disc is a white circle with a small man
/// in the middle of it — reported from the home dock as not showing fully and
/// as a weird shape, which is what a full-length figure inscribed in a circle
/// looks like at chip size.
///
/// **One of it, because there were three.** The dock zoomed to his face and the
/// floating head every other tab wears did not, so the same coach was two
/// different men depending which tab you were on. The card's portrait was a
/// third.
class CoachFace extends StatelessWidget {
  const CoachFace({this.fallbackSize = 24, super.key});

  /// The stand-in glyph's size, for a build with no art bundled.
  final double fallbackSize;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // Scaled about his EYES rather than about the middle of the picture, which
    // at 1.5x fills the disc with a face. `ClipOval` is belt and braces over
    // whatever circular clip the container has already — a `Transform` painting
    // outside its bounds is the first thing a decoration clip loses.
    return ClipOval(
      child: SizedBox.expand(
        child: Transform.scale(
          scale: 1.5,
          alignment: const Alignment(0, -0.45),
          child: ArtImage(
            path: coachPortrait,
            fit: BoxFit.cover,
            fallback: Center(
              child: Icon(Icons.sports, size: fallbackSize, color: kit.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far the portrait hangs above the card's top edge.
const double _portrait = 68;

/// The red on an unread nudge.
///
/// **Not the kit accent.** A badge in the club's own colour reads as decoration
/// on a screen already wearing it, and this is the one thing in the corner asking
/// to be pressed — red is what an unread thing looks like everywhere else on a
/// phone.
const Color coachAlert = Color(0xFFE23B3B);

/// A speech bubble's tail: a wedge dropping out of its bottom-left corner
/// toward Colin's face, drawn with the bubble's own fill and stroke so the two
/// read as one shape rather than a box and a triangle.
///
/// **Shared, because a bubble with no tail is not somebody SAYING something.**
/// The home page's had one and the floating one — every other screen in the game
/// — was a plain panel with no speaker, which is a caption rather than a line of
/// dialogue.
class CoachBubbleTail extends CustomPainter {
  const CoachBubbleTail({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      // Down and to the LEFT: the head is below and behind the bubble's corner,
      // so a tail dropping straight down would point at the grass beside him.
      ..lineTo(coachTailTipX, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    // **ONLY THE TWO SLOPES ARE STROKED, and the top edge never is.** It used to
    // stroke the closed triangle and then paint a fill rectangle back over the
    // top edge to hide it, which is a seam waiting to happen — an antialiased
    // 1px line under a 2px cover leaves its ends showing, and it did: a border
    // across the top of the wedge, reported from a phone. An open path has no
    // top edge to hide.
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(coachTailTipX, size.height)
        ..lineTo(0, 0),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CoachBubbleTail old) =>
      old.fill != fill || old.edge != edge;
}

/// The size that wedge is drawn at, so every bubble's tail is the same tail.
const Size coachTailSize = Size(18, 12);

/// The dim behind an open coach bubble.
///
/// **One value, because there were two and only one of them existed.** The home
/// page's bubble opens on a `barrierColor` and the floating coach — every other
/// tab — dismissed on a fully transparent layer, so the same speech bubble had
/// a page pushed back behind it on one screen and not on the others. Light
/// enough that the game is still legible underneath: it is a dim, not a modal.
const Color coachScrim = Colors.black26;

/// The bubble's rim, and how far a tail has to be lifted to cover it.
///
/// A wedge sitting flush under a four-sided rim has that rim across its own top
/// edge, which reads as a tick stuck to the bubble rather than part of it —
/// reported from every screen except the home page, whose tail has overlapped
/// all along.
const double coachBubbleEdge = 2;

/// Where the wedge's POINT sits inside its own box.
///
/// **Not the middle, and that is what the callers kept getting wrong.** The
/// wedge leans left, so centring the BOX on the head leaves the point about
/// seven pixels to the left of it — close enough to look deliberate and wrong
/// enough that the bubble reads as pointing past him. Anything placing a tail
/// aims THIS at what is speaking.
const double coachTailTipX = 1.5;


/// His name over the line, in the one size and weight both bubbles use.
TextStyle coachLabelStyle(BuildContext context) => TextStyle(
  color: Theme.of(context).extension<KitTheme>()!.accentBright,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.5,
);

/// And the line itself.
TextStyle coachBubbleTextStyle(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurface,
  fontSize: 13,
  height: 1.5,
  fontWeight: FontWeight.w600,
);

/// The panel Colin speaks out of, wherever he is standing.
///
/// **One bubble, because there were two.** The home dock's was a translucent
/// panel with a 1px rim and the X hanging off the outside of its corner; the
/// floating one on every other tab was a 2px-rimmed card with a shadow and the
/// X in its header row — the same coach saying the same kind of thing through
/// two different windows, in two type sizes. What varies between the callers is
/// the label, what goes under it and which string the X reads out; the chrome
/// does not.
class CoachSpeechBubble extends StatelessWidget {
  const CoachSpeechBubble({
    required this.label,
    required this.dismissLabel,
    required this.onClose,
    required this.child,
    this.maxWidth,
    this.closeKey,
    super.key,
  });

  /// What sits over the line — his name, or his name and the tactic he would
  /// play.
  final Widget label;

  /// What a screen reader calls the X.
  final String dismissLabel;

  final VoidCallback onClose;

  final Widget child;

  /// Set where the bubble is placed by hand and the screen is what bounds it.
  final double? maxWidth;

  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      constraints: maxWidth == null
          ? const BoxConstraints()
          : BoxConstraints(maxWidth: maxWidth!),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        // Barely translucent rather than glass: it sits over a lit diorama on
        // one screen and a live one on the rest, and a sentence on either has
        // to be read off the panel rather than off what is behind it.
        color: kit.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kit.accent, width: coachBubbleEdge),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: label),
              Semantics(
                button: true,
                label: dismissLabel,
                child: GestureDetector(
                  key: closeKey,
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: kit.textMuted),
                  ),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

/// What kind of answer a button is, which is the whole of its colour.
enum CoachTone {
  /// Go ahead. Green.
  confirm,

  /// Don't. Red — and the same red for "no thanks" as for "delete everything",
  /// because both are the answer that stops something happening.
  decline,

  /// Neither: dismissing, or reading on.
  neutral,
}

class CoachAction {
  const CoachAction({
    required this.labelKey,
    required this.onTap,
    this.tone = CoachTone.neutral,
    this.dismisses = true,
    this.result,
    this.labelParams = const {},
  });

  final String labelKey;

  /// Anything the label needs filling in — a bid's own figure, so the button
  /// says what it is agreeing to rather than just "Accept".
  final Map<String, Object?> labelParams;
  final VoidCallback onTap;

  /// What [showCoachCard] resolves to when this is the answer.
  ///
  /// **A yes/no question should be able to just ANSWER.** Without this the only
  /// way to hear which button was pressed is a captured variable and an
  /// `onTap` that writes to it, which is how three squad confirmations ended up
  /// as `AlertDialog`s instead — the plumbing was easier than the card's.
  final Object? result;

  /// Yes, no, or neither.
  final CoachTone tone;

  /// Whether pressing it closes the card.
  ///
  /// Almost always yes — an answer given is an answer, and the card goes. False
  /// is for a card the player can get WRONG: one carrying a name to validate
  /// keeps its own card up so the error has somewhere to appear, and pops itself
  /// once the answer is good. Without this the frame popped before the handler
  /// ran, so a rejected name closed the card it was rejected on.
  final bool dismisses;
}

/// One more line under the body, in its own right.
///
/// A reward card is the case that needs it: the offer is one sentence and the
/// TERMS are another, and burying "lasts until the end of the season" inside the
/// offer is how a player agrees to something they did not read.
typedef CoachLine = ({String key, Map<String, Object?> params, bool strong});

Future<T?> showCoachCard<T>(
  BuildContext context, {
  required String titleKey,
  required String bodyKey,
  Map<String, Object?> titleParams = const {},
  List<CoachAction> actions = const [],
  Map<String, Object?> bodyParams = const {},
  List<CoachLine> extraLines = const [],
  List<String> extraTexts = const [],
  int? coins,
  String? badge,

  /// Already-resolved body text, for a caller whose line comes out of a pool or
  /// carries a name the catalogue cannot know.
  String? body,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => _CoachCard<T>(
      titleKey: titleKey,
      titleParams: titleParams,
      bodyKey: bodyKey,
      body: body,
      bodyParams: bodyParams,
      extraLines: extraLines,
      extraTexts: extraTexts,
      coins: coins,
      actions: actions,
      badge: badge,
    ),
  );
}

class _CoachCard<T> extends StatelessWidget {
  const _CoachCard({
    required this.titleKey,
    required this.titleParams,
    required this.bodyKey,
    required this.body,
    required this.bodyParams,
    required this.extraLines,
    required this.extraTexts,
    required this.coins,
    required this.actions,
    required this.badge,
  });

  final String titleKey;

  /// **A TITLE CAN CARRY A NAME.** `sell.title` is `Sell {name}?` and there was
  /// no way to fill it, so the card asked "Sell {name}?" with the braces showing.
  final Map<String, Object?> titleParams;
  final String bodyKey;
  final String? body;
  final Map<String, Object?> bodyParams;
  final List<CoachLine> extraLines;
  final List<String> extraTexts;
  final int? coins;
  final List<CoachAction> actions;
  final String? badge;

  @override
  Widget build(BuildContext context) => CoachCardFrame(
    title: t(titleKey, titleParams),
    body: body ?? t(bodyKey, bodyParams),
    extraLines: extraLines,
    extraTexts: extraTexts,
    coins: coins,
    actions: actions,
    badge: badge,
  );
}

/// Colin's chrome, on its own, for a card whose CONTENT is more than a
/// sentence — a sponsor's terms, a player's portrait, a bid to weigh up.
///
/// The whole point of exposing it: every one of those is still a question Colin
/// is asking, so none of them should invent its own frame. The sponsor offer had
/// a company logo where his head goes and a pair of uncoloured buttons at the
/// bottom, which read as the app talking rather than the coach.
class CoachCardFrame extends StatelessWidget {
  const CoachCardFrame({
    super.key,
    required this.title,
    this.body,
    this.child,
    this.extraLines = const [],
    this.extraTexts = const [],
    this.coins,
    this.actions = const [],
    this.badge,
  });

  final String title;

  /// A subject badge on the card's corner, beside his head.
  ///
  /// **The one place an emoji is right in this app.** Everything else is drawn
  /// in the app's own line art, but a milestone tip's badge is a hospital, a
  /// trophy, a stadium or a pair of lungs — sixteen unrelated subjects used once
  /// each, which is not the same trade as drawing an icon set.
  final String? badge;

  /// What he says. Shown immediately.
  final String? body;

  /// Anything more than words: a portrait, a list of terms, a comparison.
  final Widget? child;

  final List<CoachLine> extraLines;

  /// Already-resolved lines, for what the catalogue cannot know.
  ///
  /// The same escape hatch [body] is, and for the same reason: a figure the
  /// engine works out — what a sale costs the club per second — is not a
  /// catalogue string with a parameter in it, it is a sentence assembled from
  /// one.
  final List<String> extraTexts;

  /// A figure to show with a COIN beside it.
  ///
  /// **Money on a card should look like money.** It was a number in the middle of
  /// a sentence, which on a card whose whole subject is a price reads as a
  /// quantity of nothing in particular.
  final int? coins;

  final List<CoachAction> actions;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    return Dialog(
      key: const ValueKey('coach-card'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            // Room for the half of his head that hangs over the top.
            padding: const EdgeInsets.only(top: _portrait / 2),
            child: Container(
              decoration: BoxDecoration(
                color: kit.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kit.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(
                20,
                _portrait / 2 + 10,
                20,
                14,
              ),
              // **THE READING MATTER SCROLLS; THE ANSWERS DO NOT.**
              //
              // What he says is a sentence in whichever of ten languages the
              // player has picked — German is the measured worst case — and a
              // card carrying a portrait, a set of terms and three answers has
              // no slack left. A `Column` in a loose box takes its natural
              // height and paints straight past the bottom of the screen.
              //
              // Scrolling the WHOLE card is the other half of the same bug,
              // though: it put a rival's Decline below the fold, where a tap
              // found the barrier instead of the button. A question whose
              // answers you have to go looking for is worse than one that
              // overflows — so the buttons sit outside the scroll region and the
              // reading moves under them.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            t('coachtip.name').toUpperCase(),
                            key: const ValueKey('coach-card-name'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kit.accentBright,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (child != null) ...[
                            const SizedBox(height: 10),
                            child!,
                          ],
                          if (body != null) ...[
                            const SizedBox(height: 8),
                            // What he says. Straight away — see the note at the top.
                            Text(
                              body!,
                              key: const ValueKey('coach-card-body'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kit.textMuted,
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                          if (coins != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // One currency in the pair: the disc takes the
                                // figure's ink — see `coinFigureInk`.
                                CoinIcon(
                                  size: 18,
                                  solid: true,
                                  color: coinFigureInk(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formatCoins(coins!),
                                  key: const ValueKey('coach-card-coins'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: coinFigureInk(context),
                                    shadows: coinFigureShadows(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          for (final text in extraTexts)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: kit.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          for (final line in extraLines)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                t(line.key, line.params),
                                key: ValueKey('coach-line-${line.key}'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: line.strong
                                      ? kit.accentBright
                                      : kit.textMuted,
                                  fontSize: line.strong ? 15 : 12,
                                  fontWeight: line.strong
                                      ? FontWeight.w900
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Actions(actions: actions),
                  ],
                ],
              ),
            ),
          ),
          // His head, ON the border rather than inside the card.
          Container(
            width: _portrait,
            height: _portrait,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kit.surface2,
              border: Border.all(color: kit.accent, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const CoachFace(
              key: ValueKey('coach-card-portrait'),
              fallbackSize: 30,
            ),
          ),
          // The milestone, beside his head and clear of it — the JS hangs it off
          // the same top edge at `right: calc(50% - 56px)`.
          if (badge != null)
            Positioned(
              top: -6,
              left: MediaQuery.sizeOf(context).width / 2 + 4,
              child: Text(
                badge!,
                key: const ValueKey('coach-card-badge'),
                style: const TextStyle(
                  fontSize: 28,
                  shadows: [
                    Shadow(
                      color: Color(0x80000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The answers, in a LINE and the same width as each other: two answers to one
/// question should not be different sizes. Three or more stack, because at that
/// point a row makes every label too narrow to read.
class _Actions extends StatelessWidget {
  const _Actions({required this.actions});

  final List<CoachAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.length > 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CoachButton(action: action),
            ),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _CoachButton(action: actions[i])),
        ],
      ],
    );
  }
}

class _CoachButton extends StatelessWidget {
  const _CoachButton({required this.action});

  final CoachAction action;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final (fill, ink) = switch (action.tone) {
      CoachTone.confirm => (const Color(0xFF2E9E4F), Colors.white),
      CoachTone.decline => (const Color(0xFFC0392B), Colors.white),
      CoachTone.neutral => (kit.surface2, kit.textMuted),
    };

    return ElevatedButton(
      key: ValueKey('coach-action-${action.labelKey}'),
      onPressed: () {
        if (action.dismisses) Navigator.of(context).pop(action.result);
        action.onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: ink,
        elevation: action.tone == CoachTone.neutral ? 0 : 2,
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: action.tone == CoachTone.neutral
            ? BorderSide(color: kit.border)
            : null,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
      ),
      child: Text(
        t(action.labelKey, action.labelParams),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    );
  }
}

/// Something in here wants attention.
///
/// **ONE OF IT, because there were two and only one moved.** The home dock's
/// badge has bounced since it was written and the floating coach's — the same
/// eighteen pixels, the same white ring, the same drop shadow, on every other
/// tab — was a still copy of it. A mark whose whole job is to be noticed,
/// holding perfectly still, on the screens the player spends most of their time
/// on.
///
/// A RED EXCLAMATION, and it bounces. It was a flat accent-coloured dot, which
/// on a green kit is a green pip on a green pitch — the one mark on this screen
/// whose entire job is to be noticed, in the one colour that cannot be. Red is
/// not the club's to choose, and a mark that moves is seen without being looked
/// for.
class CoachAlertBadge extends StatefulWidget {
  const CoachAlertBadge({super.key, this.dotKey});

  final Key? dotKey;

  @override
  State<CoachAlertBadge> createState() => _CoachAlertBadgeState();
}

class _CoachAlertBadgeState extends State<CoachAlertBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  void _sync() {
    // A badge that never stops moving is exactly what reduce-motion is asking
    // us not to run. It stays — red on its own still reads — it just holds
    // still.
    if (MediaQuery.of(context).disableAnimations) {
      if (_bounce.isAnimating) _bounce.stop();
      return;
    }
    if (!_bounce.isAnimating) _bounce.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        // Two hops and a rest, rather than a sine that never settles: a badge
        // bobbing continuously reads as a loading spinner.
        final phase = (_bounce.value * 2).clamp(0.0, 1.0);
        final hop = math.sin(phase * math.pi * 2).clamp(0.0, 1.0) * 4;
        return Transform.translate(offset: Offset(0, -hop), child: child);
      },
      child: Container(
        key: widget.dotKey,
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: coachAlert,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '!',
          style: TextStyle(
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
