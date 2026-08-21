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

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// Colin's portrait, as the JS's `COLIN_IMG`.
const String coachPortrait = 'assets/ui/manager_hint.png';

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
      ..lineTo(1.5, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // The bubble's own bottom stroke runs across the top of this wedge; cover
    // the span the tail opens into it so the join is not a seam.
    canvas.drawRect(
      Rect.fromLTWH(0.5, -1, size.width - 1, 2),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(CoachBubbleTail old) =>
      old.fill != fill || old.edge != edge;
}

/// The size that wedge is drawn at, so every bubble's tail is the same tail.
const Size coachTailSize = Size(18, 12);

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
  List<CoachAction> actions = const [],
  Map<String, Object?> bodyParams = const {},
  List<CoachLine> extraLines = const [],
  String? badge,

  /// Already-resolved body text, for a caller whose line comes out of a pool or
  /// carries a name the catalogue cannot know.
  String? body,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => _CoachCard<T>(
      titleKey: titleKey,
      bodyKey: bodyKey,
      body: body,
      bodyParams: bodyParams,
      extraLines: extraLines,
      actions: actions,
      badge: badge,
    ),
  );
}

class _CoachCard<T> extends StatelessWidget {
  const _CoachCard({
    required this.titleKey,
    required this.bodyKey,
    required this.body,
    required this.bodyParams,
    required this.extraLines,
    required this.actions,
    required this.badge,
  });

  final String titleKey;
  final String bodyKey;
  final String? body;
  final Map<String, Object?> bodyParams;
  final List<CoachLine> extraLines;
  final List<CoachAction> actions;
  final String? badge;

  @override
  Widget build(BuildContext context) => CoachCardFrame(
    title: t(titleKey),
    body: body ?? t(bodyKey, bodyParams),
    extraLines: extraLines,
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
            child: ArtImage(
              key: const ValueKey('coach-card-portrait'),
              path: coachPortrait,
              fit: BoxFit.cover,
              fallback: Center(
                child: Icon(Icons.sports, size: 30, color: kit.accent),
              ),
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
