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
/// **It opens at the BOTTOM of the screen**, which is where a dialogue box goes
/// and where a thumb already is. Centred, it cut the game in half and left him
/// nowhere to stand; anchored low, the page it interrupts stays visible above it
/// and there is room over the card for a whole man.
///
/// Four things the shape does, and each was a fault in what it replaced:
///
/// 1. **He STANDS BEHIND the card**, and the card is over his chest. A face
///    inside a title row is an avatar beside a heading; a face breaking the
///    frame is someone leaning in; a figure the box is in front of is someone
///    actually there, saying it. That took a cutout — the master is a bust on
///    flat white, which over a lit pitch is a white rectangle with a man in it.
///    See [coachCutout] and `tool/gen_coach_cutout.dart`.
/// 2. **His NAME is under it**, so the voice is attributed and the copy is free
///    to speak in the first person. It said "Coach Colin suggests Balanced" —
///    third person, about himself, while being the one saying it.
/// 3. **The text TYPES IN, and a tap finishes it.** This REVERSES what stood
///    here — "no typing animation: these are decisions, often on a clock" — and
///    that objection was right about the clock rather than about the charm, so
///    it is answered rather than dropped. The whole sentence takes 850ms at the
///    very most; the ANSWERS are live from the first frame rather than the
///    last; a tap anywhere on the card completes it; reduce-motion skips it
///    outright; and the full line is laid out and in the semantics tree from
///    the start, because the untyped tail is drawn TRANSPARENT rather than left
///    out — so nothing reflows line by line and a screen reader is handed a
///    sentence rather than a stutter. See [CoachTypewriter].
/// 4. **The answers are COLOURED.** Yes is green and no is red, so the shape of
///    the decision is readable before the words are.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_cluster.dart' show coinGold;
import 'package:merge_empire_fc/ui/widgets/store_button.dart' show mouldedButtonStyle;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/services/voice_cues.dart';
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

/// **The same drawing with the white taken off it**, for the figure that stands
/// behind a card rather than the face that sits inside a disc.
///
/// [coachPortrait] is a JPEG on flat white — fine in a circle, and a white
/// rectangle with a man in it anywhere else. Written from it by
/// `tool/gen_coach_cutout.dart`, which is where the reasoning lives.
const String coachCutout = 'assets/ui/coach_cutout.png';

/// How tall he stands, and how much of him the card covers.
///
/// **Nearly all of him is above the box.** The sink is only there to hide the
/// crop: the master stops at the chest on a straight horizontal line, and a
/// figure standing clear of the card ends in that line. Anything more than a
/// sliver of cover and he is a head and a pair of shoulders peering over the
/// top, which is not a man standing behind a box.
const double coachStandeeHeight = 260;
const double _coachStandeeSink = 30;

/// The most of the screen he may take, whatever [coachStandeeHeight] says.
///
/// A 320x568 phone is where this bites: 260 of it is nearly half the screen, and
/// what it takes comes off the box he is standing behind — the one part of this
/// that has words in it.
const double _coachStandeeShare = 0.38;

/// The least of him worth drawing, below which he is not there at all.
///
/// A figure squeezed to a thumbnail behind a box is not a man standing behind a
/// box; the box takes the whole card instead.
const double _coachStandeeLeast = 110;

/// What the BOX is owed, whatever else wants the room.
///
/// The title, a line or two of what he says under it and the answers — the
/// reading scrolls below that, and see [CoachCardFrame.build] for why the
/// answers never do. Anything asking for room comes off him first and this
/// second: a card lifted clear of a control had been left 52pt to lay out a
/// footer in and painted 44 straight past its own bottom edge.
const double _coachBoxFloor = 200;

/// The margins the stage keeps: down the sides, off the top, off the bottom.
const double _coachStageSide = 10;
const double _coachStageTop = 16;
const double _coachStageEdge = 10;

/// How far clear of a thing the card keeps when it has to get out of its way.
const double _coachStageGap = 12;

/// Which side he stands on, and how far over.
///
/// Hard over, with a sliver left so he is not welded to the rim. `contain` in a
/// full-width box leaves ~130pt of slack on a 393pt phone; nudging him a third
/// of the way into it just reads as a badly centred figure, so this gives
/// effectively all of it to his right.
const Alignment coachStandeeSide = Alignment(-0.95, 1);

/// His height on THIS screen.
double coachStandeeHeightOn(BuildContext context) => math.min(
  coachStandeeHeight,
  MediaQuery.sizeOf(context).height * _coachStandeeShare,
);

/// What his nameplate is printed on.
///
/// **Dark enough to carry white type over anything.** The name is out on the
/// scene rather than inside the box — see [CoachStage] — so what is behind it
/// is whatever screen the card interrupted, and a drop shadow on its own left
/// it unreadable over a bright one. Not opaque: a plate that hides the page is
/// a slab, and the scrim is already doing the dimming.
const Color coachNamePlate = Color(0xA6101418);

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

/// The dim behind a coach CARD.
///
/// **`showDialog`'s own `black54` was too much of a night.** The card is an
/// interruption, not a modal you have to escape from: the page behind it is
/// what he is usually talking ABOUT — the grid he wants merged, the fixture he
/// wants played — and at 54% the game went black behind him. Asked for from
/// the couch. This is between that and [coachScrim], the bubble's, which is
/// too light to sit a white nameplate on.
const Color coachCardScrim = Colors.black38;

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
    this.coins,
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

  /// A figure this button is agreeing to, shown after the label with the coin
  /// mark and in the coin's own gold.
  ///
  /// **Money on a button should look like money**, which is the same argument
  /// [CoachCardFrame.coins] already makes for the card. "Accept 12,500" put the
  /// price inside a run of white text on a green face, where the one number the
  /// player is actually weighing looked like part of the verb.
  final int? coins;

  /// Whether pressing it closes the card.
  ///
  /// **Only a card that is a ROUTE may say yes.** Closing is
  /// `Navigator.pop`, so on a card drawn inline — the tutorial's spotlight
  /// steps are the one place that does it, because a route would cover the
  /// control being taught — this pops whatever route is actually there, which
  /// is the app's own. That is a black screen, and it is what it did.
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
  bool minimisable = false,
  CoachAction? footer,
  bool speaks = false,

  /// Already-resolved body text, for a caller whose line comes out of a pool or
  /// carries a name the catalogue cannot know.
  String? body,

  /// Whether a tap outside closes it without answering.
  ///
  /// **The tutorial's cards say no.** Everywhere else parking a card is a real
  /// answer — the offer stands, the tip comes back — but a tutorial step
  /// dismissed by a stray tap leaves a player mid-script with nothing on
  /// screen telling them what to do. Skip is on every one of those cards for
  /// the player who genuinely wants out. Asked for directly.
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: coachCardScrim,
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
      minimisable: minimisable,
      footer: footer,
      speaks: speaks,
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
    this.minimisable = false,
    this.footer,
    this.speaks = false,
  });

  final bool minimisable;
  final CoachAction? footer;
  final bool speaks;

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

  @override
  Widget build(BuildContext context) => CoachCardFrame(
    title: t(titleKey, titleParams),
    body: body ?? t(bodyKey, bodyParams),
    extraLines: extraLines,
    extraTexts: extraTexts,
    coins: coins,
    actions: actions,
    minimisable: minimisable,
    footer: footer,
    speaks: speaks,
  );
}

/// Colin, cut out and standing, for the top of a [CoachStage].
///
/// **In front of the page and BEHIND the card.** He is drawn inside the dialog,
/// so he clears the barrier's dim along with everything else the card draws, and
/// the card is painted after him, so it covers him from the chest down.
///
/// [IgnorePointer] because he is scenery rather than a control: a tap on him is
/// a tap on whatever the stage would have done with it.
class CoachStandee extends StatelessWidget {
  const CoachStandee({super.key});

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return IgnorePointer(
      child: ArtImage(
        path: coachCutout,
        fit: BoxFit.contain,
        // **Bottom LEFT.** The bottom is the edge the card meets — a build with
        // no art bundled would otherwise leave the fallback glyph floating in
        // the middle of the dim with nothing under it. The left is because a
        // figure standing dead centre over a centred name plate is a totem
        // pole: off to one side he is standing BESIDE what he is saying, which
        // is what a speaker over a dialogue box looks like everywhere it is
        // done well.
        alignment: coachStandeeSide,
        fallback: Align(
          alignment: coachStandeeSide,
          child: Icon(
            Icons.sports,
            size: coachStandeeHeight * 0.45,
            color: kit.accent,
          ),
        ),
      ),
    );
  }
}

/// "Stop typing and show the whole line."
///
/// A counter on the stage rather than a handle on one text, because a card can
/// carry more than one of his sentences and a tap answers all of them at once.
class CoachTypingSkip extends InheritedNotifier<ValueNotifier<int>> {
  const CoachTypingSkip({
    required super.notifier,
    required super.child,
    super.key,
  });

  static ValueNotifier<int>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoachTypingSkip>()?.notifier;
}

/// How fast he talks, and the ceiling on it.
///
/// The ceiling is the part that matters: a sentence is 40 characters in English
/// and can be twice that in German, and a card whose reading time scales with
/// the translation is a card that is slow in exactly the languages that already
/// have the most to read.
///
/// **12ms a glyph read as a flicker rather than as typing.** A 40 character
/// line finished in half a second, which is under the time it takes to look
/// down at the box, so the animation happened before the player was watching
/// it. Reported from the couch as the text loading in too quickly. 30ms is
/// about where a dialogue box types everywhere it is done well, and the ceiling
/// moved with it so a long line still gets to be typed rather than being
/// dumped: 2s is the longest he holds the floor.
const int _msPerGlyph = 30;
const int _maxTypeMs = 2000;

/// A line of his, arriving a character at a time.
///
/// **The whole string is laid out from the first frame** and only the untyped
/// tail is painted transparent. Revealing a `substring` instead reflows the card
/// line by line as it types — the buttons walk down the screen under the
/// player's thumb — and hands a screen reader a fragment. This way the box is
/// the size it will be, the semantics are the sentence, and `find.text` sees
/// what he is going to say rather than what he has said so far.
///
/// It finishes on a tap ([CoachTypingSkip]), and it does not run at all under
/// reduce-motion.
class CoachTypewriter extends StatefulWidget {
  const CoachTypewriter({
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.textKey,
    this.speaks = false,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Whether this line is also SAID. See [CoachCardFrame.speaks] — the flag is
  /// the card's, and it is off by default.
  ///
  /// Announced on the bus rather than spoken here: the popup layer does not
  /// import a speech engine, and a widget test emits into an empty bus. See
  /// `services/voice_cues.dart`.
  final bool speaks;

  /// The key the rendered text carries, so a caller's own hooks survive being
  /// typed rather than printed.
  final Key? textKey;

  @override
  State<CoachTypewriter> createState() => _CoachTypewriterState();
}

class _CoachTypewriterState extends State<CoachTypewriter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this);

  /// Graphemes, not code units. `substring` splits a surrogate pair and a
  /// half-emoji is a rendering bug rather than a character arriving.
  late List<String> _glyphs;

  /// The last skip this text has already obeyed.
  int _skipsSeen = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _glyphs = widget.text.characters.toList();
    // At the START of the line, not the end of it: the voice and the typing are
    // the same delivery, and a sentence read out after it has finished
    // appearing is a second telling rather than the same one.
    if (widget.speaks) announceCoachLine(widget.text);
    _run
      ..duration = Duration(
        milliseconds: math.min(_maxTypeMs, math.max(1, _glyphs.length * _msPerGlyph)),
      )
      ..value = 0
      ..forward();
  }

  @override
  void didUpdateWidget(CoachTypewriter old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final skips = CoachTypingSkip.of(context);
    if (skips != null && skips.value != _skipsSeen) {
      _skipsSeen = skips.value;
      _run.value = 1;
    }
    // Setting `value` stops the controller, so this both skips a run in flight
    // and keeps a later one from starting.
    if (MediaQuery.of(context).disableAnimations) _run.value = 1;
  }

  @override
  void dispose() {
    // The card has gone, so the line goes with it — a coach still talking over
    // the screen you went back to is the thing this is for.
    if (widget.speaks) announceCoachSilence();
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _run,
      builder: (context, _) {
        final shown = (_run.value * _glyphs.length).ceil().clamp(
          0,
          _glyphs.length,
        );
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: _glyphs.take(shown).join()),
              TextSpan(
                text: _glyphs.skip(shown).join(),
                style: const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
          key: widget.textKey,
          textAlign: widget.textAlign,
          style: widget.style,
        );
      },
    );
  }
}

/// Where he speaks from: a box along the BOTTOM of the screen with him standing
/// over it.
///
/// **The chrome on its own, because there were two of it.** [CoachCardFrame] is
/// one caller and the welcome-back card is the other, and that one had its own
/// `AlertDialog`, its own disc, its own name plate in its own size — the same
/// coach, in a different window, on the one screen every single launch opens
/// with. What varies between callers is what goes IN the box.
///
/// Painting order is the whole trick: the standee is the first child, so the
/// card lands on top of him; both are inside the dialog, so both are over the
/// barrier's dim.
class CoachStage extends StatefulWidget {
  const CoachStage({
    required this.child,
    this.dialogKey,
    this.minimisable = false,
    this.avoid,
    super.key,
  });

  /// What goes in the box.
  final Widget child;

  /// The key the dialog itself carries — each caller's own.
  final Key? dialogKey;

  /// See [CoachCardFrame.minimisable].
  final bool minimisable;

  /// See [CoachCardFrame.avoid].
  final Rect? avoid;

  @override
  State<CoachStage> createState() => _CoachStageState();
}

class _CoachStageState extends State<CoachStage> {
  final ValueNotifier<int> _skips = ValueNotifier<int>(0);

  @override
  void dispose() {
    _skips.dispose();
    super.dispose();
  }

  /// The room the card is given on this screen, and where in it the card sits.
  ///
  /// **The top inset does NOT reserve room for him — his own padding already
  /// does**, inside this child. Asking for both is asking for his height twice,
  /// which on a 320x568 phone left the box 82pt to lay out in and overflowed it
  /// by twelve.
  ///
  /// **Whichever side of [CoachStage.avoid] has the room, and the card never
  /// moves further than it has to.** Pushing the box above the thing it points
  /// at is right for a control down at the bottom — the kick-off step's PLAY
  /// button is under where the card opens — and wrong for everything else: the
  /// first version lifted for ANY target that was not against the bottom edge,
  /// so the scout step, whose button sits a third of the way down, threw the
  /// card at the top of the screen, left the box a 52pt sliver and put Colin
  /// over the HUD and the button he was pointing at. Reported from the couch as
  /// him being messed up, and it overflowed by 44 on the way.
  ///
  /// So the two sides are measured and the roomier one wins. Above means a
  /// bottom inset that lifts the box clear; below — the common case — means the
  /// card stays exactly where every card in the game opens, with the hole's own
  /// bottom edge as its ceiling so a long line scrolls rather than creeping up
  /// over the control.
  EdgeInsets _insets(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    // `Dialog` folds in the keyboard's inset and nothing else, so the gesture
    // bar is ours to clear.
    final resting = _coachStageEdge + MediaQuery.paddingOf(context).bottom;
    final hole = widget.avoid;
    if (hole == null) {
      return EdgeInsets.fromLTRB(
        _coachStageSide,
        _coachStageTop,
        _coachStageSide,
        resting,
      );
    }

    final above = hole.top - _coachStageGap - _coachStageTop;
    final below = height - resting - hole.bottom - _coachStageGap;
    if (above > below) {
      return EdgeInsets.fromLTRB(
        _coachStageSide,
        _coachStageTop,
        _coachStageSide,
        // Clamped both ways: never below where the card rests anyway, and never
        // so far up that the box is left less than it is owed.
        (height - hole.top + _coachStageGap).clamp(
          resting,
          math.max(resting, height - _coachStageTop - _coachBoxFloor),
        ),
      );
    }
    return EdgeInsets.fromLTRB(
      _coachStageSide,
      (hole.bottom + _coachStageGap).clamp(
        _coachStageTop,
        math.max(_coachStageTop, height - resting - _coachBoxFloor),
      ),
      _coachStageSide,
      resting,
    );
  }

  /// How tall he stands here, once the box has what it needs.
  ///
  /// **He is the one who gives the room up.** The box holds the words and the
  /// answers; he is a figure standing behind it, and a card with nowhere to put
  /// its footer is broken in a way a shorter Colin is not.
  double _standee(BuildContext context, EdgeInsets insets) {
    final room = MediaQuery.sizeOf(context).height - insets.vertical;
    final tallest = math.min(
      coachStandeeHeightOn(context),
      room - _coachBoxFloor + _coachStandeeSink,
    );
    return tallest >= _coachStandeeLeast ? tallest : 0;
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final insets = _insets(context);
    final standee = _standee(context, insets);
    final rise = standee > 0 ? standee - _coachStandeeSink : 0.0;
    return Dialog(
      key: widget.dialogKey,
      alignment: Alignment.bottomCenter,
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insets,
      child: CoachTypingSkip(
        notifier: _skips,
        // `deferToChild`, which is the default: a tap on the card finishes his
        // line, and a tap on the transparent space around his head still falls
        // through to the barrier the way it always has.
        child: GestureDetector(
          onTap: () => _skips.value++,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Nothing of him when there is not room for a figure — see
              // [_standee].
              if (standee > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: standee,
                  // **AND NOTHING BESIDE HIM.** A milestone tip used to hang
                  // its subject emoji in the air over his shoulder — a
                  // hospital, a trophy, a pair of lungs — which on a card that
                  // is a man standing behind a box reads as a sticker floating
                  // in the room. Asked for from the couch. The subject is in
                  // the title he is saying it under; it does not need a mascot.
                  child: const CoachStandee(),
                ),
              // **HIS NAME IS OUT ON THE SCENE, not the first line inside the
              // box.** It sat above the title in the club's accent, which
              // spends the top of a card that is already short on room saying
              // something the figure beside it has just said — and put the
              // game's voice in the middle of his. Above the box and hard
              // RIGHT it is a nameplate on a dialogue box: he stands on the
              // left, his name stands opposite him, and the box below is
              // nothing but what he is saying. Asked for from the couch.
              //
              // White rather than the accent, because it is over the scrim and
              // the page rather than over a surface. The plate needs the height
              // he is standing in — no him, no plate.
              //
              // **AND IT SITS ON A PLATE OF ITS OWN.** A drop shadow was all
              // it had, and what is behind it is whatever screen the card
              // interrupted — a bright sky, a pale panel, mown turf — so
              // sometimes it simply could not be read. Reported from the
              // couch, and it is the only thing wrong with it: a nameplate in
              // a dialogue box is a plate. Moving the words inside the box was
              // the other answer and it was worse — see the reverted commit.
              if (rise > 0)
                Positioned(
                  left: 0,
                  right: 10,
                  top: 0,
                  height: rise,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: coachNamePlate,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            child: Text(
                              t('coachtip.name').toUpperCase(),
                              key: const ValueKey('coach-card-name'),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(top: rise),
                child: Container(
                  // The BOX, as opposed to the dialog — which is the whole
                  // screen, barrier and all, and measures like it.
                  key: const ValueKey('coach-box'),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: kit.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kit.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x8C000000),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: widget.child,
                ),
              ),
              if (widget.minimisable)
                Positioned(
                  top: rise + 12,
                  right: 12,
                  child: const _MinimiseButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `−` that parks a card. See [CoachCardFrame.minimisable].
class _MinimiseButton extends StatelessWidget {
  const _MinimiseButton();

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Semantics(
      button: true,
      label: t('transfer.minimize'),
      child: InkWell(
        key: const ValueKey('coach-card-minimise'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kit.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kit.border),
          ),
          child: Icon(Icons.remove, size: 16, color: kit.textMuted),
        ),
      ),
    );
  }
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
    this.avoid,
    required this.title,
    this.body,
    this.child,
    this.extraLines = const [],
    this.extraTexts = const [],
    this.coins,
    this.actions = const [],
    this.minimisable = false,
    this.footer,
    this.speaks = false,
  });

  /// Whether what he says is also SAID OUT LOUD.
  ///
  /// **Off, and opt-in per card, because the shape carries two different kinds
  /// of thing.** A story beat — the club reaching a competition with a cup in
  /// it, a milestone he has been waiting to tell you about — is exactly what a
  /// voice is for. A confirmation dialog is not: "Sell Nakamura?" read aloud
  /// every time a thumb lands on sell would have the player muting the game
  /// inside a session, and the transfer bids and sponsor offers arrive on a
  /// timer several times an hour.
  ///
  /// So the story and information cards ask for it and the decisions do not.
  /// The line goes out on the bus; see `services/voice_cues.dart` for why it is
  /// announced rather than spoken here.
  final bool speaks;

  /// A `−` in the top corner that closes the card without answering it.
  ///
  /// **Parking is not an answer, so it is not a button in the row.** It was a
  /// third full-width action beside Accept and Decline, which made the one
  /// control that decides nothing the same size and shape as the two that
  /// decide everything. Tapping the barrier has always done the same thing;
  /// this is the visible version of it, where a close control is expected.
  final bool minimisable;

  /// A way out, under the buttons, as a line of text rather than a control of
  /// its own.
  ///
  /// **Not everything a card offers is an ANSWER.** Skipping the tutorial is the
  /// case: it was a full-width button beside "Let's go", so leaving and starting
  /// had the same weight and the primary action was half the card wide. A link
  /// under the button is what it is.
  final CoachAction? footer;

  final String title;

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

  /// A rectangle on the screen the card may not cover.
  ///
  /// **The card belongs at the bottom, and it must not cover what it is
  /// pointing at.** Every card in the game opens against the bottom edge, which
  /// is where a thumb already is — except a tutorial step, whose whole job is
  /// to point at a control the player then has to press. The kick-off step
  /// points at the PLAY button, which is down there too: the card landed on top
  /// of it, and since the box eats its own taps the tutorial could not be
  /// finished at all. Reported from the couch.
  ///
  /// **The rectangle rather than a distance, because the card is the only thing
  /// that knows how much room it needs.** This was a lift in points, worked out
  /// by the caller, and a caller cannot tell whether the card was in the way to
  /// begin with: it lifted for every target that was not against the bottom
  /// edge and wrecked the two scout steps, whose button sits a third of the way
  /// down a screen the card never reached. Given the rectangle, [CoachStage]
  /// takes whichever side of it has the room and leaves the card alone when the
  /// answer is below — which it usually is.
  ///
  /// See `tutorial_overlay.dart`, the one caller that passes it.
  final Rect? avoid;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    return CoachStage(
      dialogKey: const ValueKey('coach-card'),
      minimisable: minimisable,
      avoid: avoid,
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
                  // His name is on the SCENE now, above the box and off to the
                  // right — see [CoachStage]. The box opens with the subject.
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
                    // What he says, typed — see the note at the top, and
                    // [CoachTypewriter] for what "typed" does and does not mean
                    // for the layout and the semantics.
                    CoachTypewriter(
                      text: body!,
                      textKey: const ValueKey('coach-card-body'),
                      speaks: speaks,
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
          // A card with a footer and no answers is still a card with
          // something to press — the tutorial's spotlight steps are
          // exactly that: perform the thing, or leave.
          if (actions.isNotEmpty || footer != null) ...[
            const SizedBox(height: 16),
            if (actions.isNotEmpty) _Actions(actions: actions),
            if (footer case final link?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  key: ValueKey('coach-footer-${link.labelKey}'),
                  onPressed: () {
                    if (link.dismisses) {
                      Navigator.of(context).pop(link.result);
                    }
                    link.onTap();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: kit.textMuted,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: Text(t(link.labelKey, link.labelParams)),
                ),
              ),
          ],
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

    // **THE APP'S OWN MOULDING, not `styleFrom`'s.**
    //
    // Every button in the game is moulded from the BOTTOM — a hard edge
    // underneath, a bright inner line along the top, a press that drops the face
    // onto its own edge — and it is applied through the theme, by
    // `mouldedButtonStyle`'s `backgroundBuilder`. Passing `backgroundColor` to
    // `styleFrom` does not reach that builder: it colours the Material
    // UNDERNEATH the face the builder then paints over the top, so a coach
    // card's buttons wore the theme's default face and lost their own colour,
    // and the neutral one came out a pale slab whose lit top edge was the only
    // shaping left on it. Reported as the cancel buttons being three-dimensional
    // the wrong way up.
    //
    // Asking the shared helper for the tone's own face is the fix, and it is the
    // same three colours the shop's buttons are built from.
    return ElevatedButton(
      key: ValueKey('coach-action-${action.labelKey}'),
      onPressed: () {
        if (action.dismisses) Navigator.of(context).pop(action.result);
        action.onTap();
      },
      style: mouldedButtonStyle(
        face: fill,
        edge: Color.lerp(fill, Colors.black, 0.34)!,
        ink: ink,
        dead: kit.surface2,
        deadInk: kit.textMuted,
        border: kit.border,
      ).copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
        ),
      ),
      child: action.coins == null
          ? Text(
              t(action.labelKey, action.labelParams),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    t(action.labelKey, action.labelParams),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
                const SizedBox(width: 6),
                const CoinIcon(size: 13, solid: true),
                const SizedBox(width: 3),
                Text(
                  formatCoins(action.coins!),
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(color: coinGold),
                ),
              ],
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
