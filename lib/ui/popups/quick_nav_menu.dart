/// The quick-nav menu — the third and last popup shape, drawn as the
/// manager's PHONE.
///
/// **A centred grid, deliberately NOT a bottom sheet.** The JS says why in as
/// many words: a 3×3 grid wants the middle of the screen, and the sheet's
/// chrome — a grab handle, a pinned close — promises scrollable content about
/// something that has none. The port had it as a sheet, which put the last
/// group below the fold on a short screen: the exact failure the shape was
/// chosen to avoid.
///
/// Groups come straight from the catalogue's `quicknav.group.*` keys, and the
/// grouping is the point — "where you stand / what there is to do / what you've
/// won" makes eight destinations findable in a way one flat list does not.
library;

import 'dart:math' show Random, max, min, pi;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart' show minFontSize;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class QuickNavItem {
  const QuickNavItem({
    required this.labelKey,
    required this.icon,
    required this.onTap,
    this.dot = false,
    this.badge,
  });

  final String labelKey;
  final IconData icon;
  final VoidCallback onTap;

  /// Something behind this tile wants attention. The burger's own dot is the OR
  /// of these, so nothing that used to nag from the scene goes quiet just
  /// because it moved one tap deeper.
  final bool dot;

  /// A live VALUE in place of the glyph — the table tile carries the league
  /// position its dock button used to, zone colour and all. It is the one thing
  /// in here that is a readout rather than a door, which is why it earns the
  /// exception.
  final Widget? badge;
}

class QuickNavGroup {
  const QuickNavGroup({required this.titleKey, required this.items});

  final String titleKey;
  final List<QuickNavItem> items;
}

/// The name on the phone's screen.
///
/// **A product name, not copy**, which is why it does not go through `t()`: the
/// game's own name is not translated either. It replaces "Quick Nav" — asked
/// for from the couch: "dont need to call it Quick Nav anymore, maybe make it
/// look like a manager app, give it a name". One constant, so renaming it is
/// one edit.
const String dugoutAppName = 'Dugout';

/// A battery at or under this reads red, the way a phone's does.
bool batteryLow(double level) => level <= 0.2;

/// Where the drawn hand lies over the glass, as fractions of the case: the
/// thumb's pad, and how far the fingertips reach in from the left. Public so a
/// test can hold every tile clear of them.
///
/// At the current fit the case covers the hole with room to spare on every
/// side, so the thumb's pad reaches only the bezel and the fingertips are
/// behind the case: nothing lies over the glass, and the screen lays out
/// plainly. Change the fit and these have to be re-derived — the drawn thumb
/// reaches 22% of the card's width in from its right edge, the fingertips 9%
/// in from its left.
const Rect phoneThumbZone = Rect.fromLTRB(0.96, 0.31, 1.0, 0.58);
const double phoneFingerReach = 0;

/// Whether the hand lies far enough over the glass for the screen to lay out
/// round it — see the bands in the menu.
bool get phoneHandOverGlass => phoneThumbZone.left < 0.9 || phoneFingerReach > 0.04;

Future<void> showQuickNavMenu(
  BuildContext context, {
  required List<QuickNavGroup> groups,
  double? battery,
  String? clubName,
  Color? skin,
}) {
  final still = MediaQuery.of(context).disableAnimations;
  // `showGeneralDialog` rather than `showDialog`, so the RAISE rides the
  // route's own animation: it runs forward on open and backwards on dismiss,
  // and "when we close the phone the animation needs to reverse, same as the
  // incoming one but reversed" is then the route's business rather than ours.
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Lighter than a normal dialog's. The menu is real glass, so the scene has
    // to be visible THROUGH it — a 55% barrier put the diorama behind a curtain
    // and the pane had nothing left to be transparent to.
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: still ? Duration.zero : _Raise.duration,
    pageBuilder: (dialogContext, animation, secondary) =>
        _QuickNavMenu(
          groups: groups,
          battery: battery,
          clubName: clubName,
          skin: skin,
        ),
    transitionBuilder: (dialogContext, animation, secondary, child) =>
        _Raise(animation: animation, child: child),
  );
}

class _QuickNavMenu extends StatelessWidget {
  const _QuickNavMenu({
    required this.groups,
    this.battery,
    this.clubName,
    this.skin,
  });

  final List<QuickNavGroup> groups;

  /// The hand's colour — the MANAGER'S, off his look. Null is the scene's own
  /// default skin, the hex the home screen hands `ManagerWalker`.
  final Color? skin;

  /// The club signed in to the app — data, not copy — under its name in the
  /// app bar. Null leaves the bar to the name alone.
  final String? clubName;

  /// **THE BATTERY IS THE GAME'S ENERGY**, 0..1. Asked for from the couch: "if
  /// we only have 1/10 left the battery is red and looks like its at 10%". Null
  /// reads full, for a caller with no save behind it.
  final double? battery;

  /// Tiles per row, and the gap between them. The spec's `.qn-tile` is an exact
  /// third of the row for the same reason: three across is what makes the
  /// groups read as a home screen, and it was wrapping to two.
  static const int columns = 3;
  static const double tileGap = 8;

  /// The handset's outside corner, the screen's inside it, and the case
  /// between them.
  static const double bezelRadius = 30;
  static const double screenRadius = 22;
  static const double bezel = 9;

  /// Height over width, and the widest it goes. A modern handset is about
  /// 2.1 and 330 points; this is squarer and wider than that on purpose —
  /// "the phone needs to be wider", from the couch, twice — because it is a
  /// menu first and a phone second, and three tiles a row want the room.
  static const double aspect = 1.75;
  static const double maxWidth = 330;

  /// How far the case's bottom sits above the bottom of the screen.
  static const double bottomInset = 40;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **IT IS THE MANAGER'S PHONE, IN HIS HAND.** The JS draws this as a glass
    // panel of tiles (`.qn-menu`); the port drew the same panel as an opaque
    // plate, and was asked from the couch to make it a mobile phone instead —
    // "same buttons etc but its a mobile phone screen that the user opened up,
    // i think thats more interesting than a standard menu" — and then for a
    // hand to hold it. A deliberate divergence from the spec, at the user's
    // call. The GROUPS and the TILES are untouched: they are the app icons on
    // the phone's home screen, and the grouping was the point of the menu
    // before it had a case round it.
    //
    // The case is hardware, so it is black and metal-rimmed whatever the kit
    // — the same way the dock's orbs are black glass on every club. The SCREEN
    // is the kit's: the phone runs the club's own app.
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // The case sits [bottomInset] off the bottom of the screen; the hand's
      // wrist is then pinned to the screen's edge from that — see `_HandArt`.
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(12, 32, 12, bottomInset),
      child: LayoutBuilder(
        builder: (context, box) {
          // The case: a handset's proportions, never wider than a phone is,
          // with at least a finger's width of screen either side for the hand,
          // and short enough that the hand's wrist still fits beneath it.
          // **THE PHONE IS SIZED AND PLACED BY ITSELF.** Its box is the case
          // and nothing else; the hand is painted relative to it and runs off
          // the box — and the screen — wherever it must, so no hand knob can
          // move the phone. "Do not touch the phone."
          var width = min(maxWidth, box.maxWidth);
          if (width * aspect > box.maxHeight) width = box.maxHeight / aspect;
          final height = width * aspect;
          // **A TAP ANYWHERE OFF THE GLASS PUTS THE PHONE AWAY** — the bezel,
          // the hand, the pitch — asked for from the couch. The barrier covers
          // everything outside this box; this covers the box, and the screen
          // inside the case swallows its own taps so only its tiles act there.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: _case(kit, width, height)),
                // **THE HAND, AT ONE SCALE.** The drawing's hand is 1.7 times
                // the width of the card it holds; the hole is laid exactly on
                // the case and the fingers and thumb run off the screen edges
                // at the same scale — squeezing them into the strips beside
                // the case read as a stretched hand and was taken out. Tinted
                // to the manager's skin; taps pass through.
                Positioned.fill(
                  child: IgnorePointer(
                    key: const ValueKey('quick-nav-hand'),
                    child: _SlicedHand(
                      caseRect: Rect.fromLTWH(0, 0, width, height),
                      tint: Color.lerp(
                        skin ?? const Color(0xFFEEBB8C),
                        Colors.white,
                        _HandArt.lift,
                      )!,
                    ),
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  /// The handset: black case, side buttons, and the club's screen inside.
  Widget _case(KitTheme kit, double caseWidth, double caseHeight) => Stack(
    key: const ValueKey('quick-nav-phone'),
    clipBehavior: Clip.none,
    children: [
      // The side buttons, on the case rather than in it. Painted first so
      // the case sits on them.
      _sideButton(top: 96, height: 30, right: false),
      _sideButton(top: 136, height: 52, right: false),
      _sideButton(top: 116, height: 68, right: true),
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(bezelRadius),
          color: Colors.black,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(bezel),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(screenRadius),
            // The glass keeps its taps: a miss between tiles is not a
            // dismissal — see the detector round the whole box.
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: DecoratedBox(
              // The wallpaper: the kit's dark ground with a soft glow off the
              // top-left, the way a phone's wallpaper lifts behind its icons.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kit.surface, kit.bg],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.9),
                    radius: 1.1,
                    colors: [
                      kit.accent.withValues(alpha: 0.16),
                      kit.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusBar(kit: kit, battery: battery ?? 1),
                    Expanded(
                      // **THREE BANDS, CLEAR OF THE HAND.** The thumb lies
                      // over the right of the glass through the middle of the
                      // screen and the fingertips over its left edge, so the
                      // app bar and the first group go ABOVE the thumb, the
                      // smallest group sits BESIDE it on the left, and the rest
                      // go BELOW. Each band shrinks its contents to fit rather
                      // than overflow, which is what keeps the bands where the
                      // hand is on every size of screen — the case scales,
                      // the type does not, so the bands have to give.
                      child: LayoutBuilder(
                        builder: (context, room) {
                          if (!phoneHandOverGlass) return _plain(kit, room);
                          // The thumb's band, in this screen's own pixels: the
                          // case fractions less the status bar above us.
                          const barH = 34.0;
                          final top = (caseHeight * _HandArt.thumb.top - bezel - barH)
                              .clamp(60.0, room.maxHeight * 0.6);
                          final bottom = (caseHeight * _HandArt.thumb.bottom - bezel - barH)
                              .clamp(top + 40, room.maxHeight * 0.85);
                          final inset = max(14.0, caseWidth * _HandArt.fingers - bezel);
                          final rowWidth = room.maxWidth - inset - 14;
                          final tileW = (rowWidth - tileGap * (columns - 1)) / columns;
                          final ordered = [...groups]
                            ..sort((a, b) => a.items.length.compareTo(b.items.length));
                          final beside = ordered.isEmpty ? null : ordered.first;
                          final rest = [for (final g in groups) if (g != beside) g];
                          final above = rest.isEmpty ? null : rest.first;
                          final below = rest.skip(1).toList();
                          return Padding(
                            key: const ValueKey('quick-nav'),
                            padding: EdgeInsets.fromLTRB(inset, 0, 14, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: top,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: rowWidth,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _appBar(kit),
                                          if (above != null)
                                            _group(kit, above, tileW),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: bottom - top,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        // Left of the thumb only.
                                        width: caseWidth * _HandArt.thumb.left - bezel - inset - 6,
                                        child: beside == null
                                            ? const SizedBox.shrink()
                                            : _group(
                                                kit,
                                                beside,
                                                tileW,
                                                align: WrapAlignment.start,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: rowWidth,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (final g in below) ...[
                                            _group(kit, g, tileW),
                                            const SizedBox(height: 10),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    _HomeBar(kit: kit),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    ],
  );

  /// The screen when nothing lies over the glass: the app bar, then the groups
  /// spread evenly down the screen like a home screen's icons, scrolling only
  /// when they are taller than it.
  Widget _plain(KitTheme kit, BoxConstraints room) {
    const inset = 14.0;
    final rowWidth = room.maxWidth - inset * 2;
    final tileW = (rowWidth - tileGap * (columns - 1)) / columns;
    return SingleChildScrollView(
      key: const ValueKey('quick-nav'),
      padding: const EdgeInsets.fromLTRB(inset, 0, inset, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: room.maxHeight - 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _appBar(kit),
            for (final group in groups) _group(kit, group, tileW),
          ],
        ),
      ),
    );
  }

  /// **AN APP BAR, not a title.** The icon, the name and the club signed in,
  /// left-aligned the way an app opens — asked for from the couch: "we have
  /// more room to make this 'dugout' look like an app".
  Widget _appBar(KitTheme kit) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kit.accent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.sports_soccer, size: 26, color: kit.accentInk),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dugoutAppName,
                style: TextStyle(
                  color: kit.accentBright,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              if (clubName case final club? when club.isNotEmpty)
                Text(
                  club,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kit.textMuted,
                    fontSize: minFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  /// One group: its heading over its tiles, each tile an exact share of the
  /// row so three always fit — see [columns]. Wrap rather than a fixed grid: a
  /// group of two centres rather than left-packing beside an empty third cell,
  /// unless it is the group beside the thumb, which packs left on purpose.
  Widget _group(
    KitTheme kit,
    QuickNavGroup group,
    double tileWidth, {
    WrapAlignment align = WrapAlignment.center,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t(group.titleKey).toUpperCase(),
          textAlign: align == WrapAlignment.start
              ? TextAlign.left
              : TextAlign.center,
          style: TextStyle(
            color: kit.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      Wrap(
        alignment: align,
        spacing: tileGap,
        runSpacing: tileGap,
        children: [
          for (final item in group.items)
            _QuickNavTile(item: item, width: tileWidth),
        ],
      ),
    ],
  );

  /// A volume or power button: a sliver of the case standing proud of the edge.
  Widget _sideButton({
    required double top,
    required double height,
    required bool right,
  }) => Positioned(
    top: top,
    left: right ? null : -3,
    right: right ? -3 : null,
    child: Container(
      width: 5,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2E),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
    ),
  );
}

/// The hand, as drawn: where the card it holds sits in the picture.
///
/// `assets/phone/hand.png` is the user's own cut-out of a hand gripping a
/// blank card, so the card is a hole. **THE KNOBS ARE HERE**, and only here:
///
/// - [card] is the hole, in the picture's pixels: left, top, width, height.
///   The case is laid exactly on it, so this is the hand's SCALE against the
///   phone. Shrink the rect (keep its centre) and the hand grows relative to
///   the case, with its fingertips slipping behind the case's edges; grow it
///   and the hand shrinks, with pitch showing inside the hole's edges. Move its
///   bottom to move the palm up or down the case.
/// - [scale] and [shiftX] size and place the hand against the case.
/// - `maxWidth` and `aspect` on `_QuickNavMenu` are the phone's own size.
///
/// The fingers and thumb are drawn compressed into whatever the screen leaves
/// either side of the case — see `_SlicedHandPainter`.
class _HandArt {
  const _HandArt._();

  static const _HandArt self = _HandArt._();
  static const String asset = 'assets/phone/hand.png';

  /// The picture's pixel size after the cut.
  final Size size = const Size(600, 720);

  /// Where the hole is in it, in the same pixels — see [fit].
  final Rect card = const Rect.fromLTWH(144, 49, 354, 620);

  /// **THE HAND'S SIZE against the phone**: 1 lays the drawn hole exactly on
  /// the case; under 1 shrinks the whole hand about the hole's centre, so the
  /// case covers past the hole's edges and the fingertips and thumb slip a
  /// little behind it. "Reduce the size of the hand by 10%."
  static const double scale = 0.81;

  /// How far the hand sits from centred on its hole over the case, in points:
  /// right, and down. **Down has a ceiling**: the case's bottom sits about 85
  /// points below the hole's, and a drop past about 75 opens a sliver of pitch
  /// between the case and the palm that no patch has hidden. 60 puts the wrist
  /// on the floor of the screen without that.
  static const double shiftX = 15;
  static const double shiftY = 60;

  /// Where the hand lies over the glass — see [phoneThumbZone].
  static const Rect thumb = phoneThumbZone;
  static const double fingers = phoneFingerReach;

  /// The asset's base tone is 92% white; the tint lifts the skin back by that.
  static const double lift = 0.08;
}

/// The hand drawn off one image at one scale, its hole centred on the case —
/// see `_HandArt.scale`. The image is decoded once and held.
class _SlicedHand extends StatefulWidget {
  const _SlicedHand({required this.caseRect, required this.tint});

  final Rect caseRect;
  final Color tint;

  @override
  State<_SlicedHand> createState() => _SlicedHandState();
}

class _SlicedHandState extends State<_SlicedHand> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = const AssetImage(
      _HandArt.asset,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detach();
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _image = info.image);
    });
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SlicedHandPainter(
      image: _image,
      caseRect: widget.caseRect,
      tint: widget.tint,
    ),
  );
}

class _SlicedHandPainter extends CustomPainter {
  const _SlicedHandPainter({
    required this.image,
    required this.caseRect,
    required this.tint,
  });

  final ui.Image? image;
  final Rect caseRect;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final art = _HandArt.self;
    final hole = art.card;
    final s = (caseRect.width / hole.width) * _HandArt.scale;
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate)
      ..filterQuality = FilterQuality.medium;
    // One scale, no distortion: the hole's centre on the case's centre, and the
    // fingers and thumb run off the screen where they must.
    // **THE SLIVER UNDER THE CASE IS BLACK.** Between the case's bottom edge
    // and the palm a few points of pitch showed; a palm-toned patch there never
    // read as palm, but a black band does read as the phone's shadow on the
    // hand. Painted BEHIND the picture, inset from the case's rounded corners,
    // so it is only ever seen where the drawing has nothing.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        // Further in on the left, where the palm's edge curves away under the
        // case's corner and a band that wide overhung it.
        Rect.fromLTRB(
          caseRect.left + 19,
          caseRect.bottom - 9,
          caseRect.right - 26,
          caseRect.bottom + 11,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.black,
    );
    final left = caseRect.center.dx + _HandArt.shiftX - hole.center.dx * s;
    // **The hole centred on the case**, not the wrist pinned to the screen:
    // pinning slid the hand down against the case and opened a sliver of pitch
    // between the case's bottom and the palm, and no painted patch could hide
    // it. Centred, the case's bottom sits well below the hole's and covers the
    // palm's top and the notch by the little finger; the wrist still runs off
    // the screen at the case's placement.
    final top = caseRect.center.dy + _HandArt.shiftY - hole.center.dy * s;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, art.size.width, art.size.height),
      Rect.fromLTWH(left, top, art.size.width * s, art.size.height * s),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SlicedHandPainter old) =>
      old.image != image || old.caseRect != caseRect || old.tint != tint;
}

/// The top of the screen: the time, the radios, the battery, and the island
/// the camera lives in. All glyphs — no copy, so nothing to translate.
///
/// **It reads the real clock**, so the phone feels alive rather than propped;
/// **the battery is the game's energy**, red when it is nearly gone; and the
/// signal and wifi bars are rolled off a seed that turns over every five
/// minutes — "randomise the signal quality, only every so often" — so they
/// vary between openings without flickering within one.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.kit, required this.battery});

  final KitTheme kit;
  final double battery;

  /// How often the radios re-roll, in minutes.
  static const int radioSlot = 5;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final clock = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    final rng = Random(now.day * 24 * 60 + now.hour * 60 + now.minute ~/ radioSlot);
    final signal = 1 + rng.nextInt(4);
    final wifi = 1 + rng.nextInt(3);
    final level = battery.clamp(0.0, 1.0);
    final ink = kit.accentBright;
    final batteryInk = batteryLow(level) ? dangerInk : ink;
    return SizedBox(
      key: const ValueKey('quick-nav-status'),
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            // Tight to the right edge, where a phone keeps its radios.
            padding: const EdgeInsets.fromLTRB(20, 8, 6, 0),
            // Two halves that each scale down rather than overflow: on the
            // narrowest case a short screen allows, the radios shrink a touch
            // instead of throwing.
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      clock,
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                // `Expanded`, not `Flexible`: a loose slot shrinks to the
                // radios and sits where the clock's half ends — under the
                // island. A tight one fills its half and pins them right.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Painted rather than the Material glyphs, because a
                        // weak signal still shows the EMPTY bars — "so you can
                        // see what it is", asked for from the couch — and the
                        // icon set has no hollow ones.
                        CustomPaint(
                          key: const ValueKey('quick-nav-signal'),
                          size: const Size(16, 12),
                          painter: _SignalPainter(bars: signal, ink: ink),
                        ),
                        const SizedBox(width: 5),
                        CustomPaint(
                          key: const ValueKey('quick-nav-wifi'),
                          size: const Size(16, 12),
                          painter: _WifiPainter(arcs: wifi, ink: ink),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(level * 100).round()}%',
                          key: const ValueKey('quick-nav-battery-pct'),
                          style: TextStyle(
                            color: batteryInk,
                            fontSize: minFontSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 3),
                        CustomPaint(
                          key: const ValueKey('quick-nav-battery'),
                          size: const Size(24, 11),
                          painter: _BatteryPainter(level: level, ink: batteryInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The island: the one black thing on the screen, because it is not
          // screen.
          Positioned(
            top: 7,
            child: Container(
              width: 84,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four rising bars, [bars] of them lit and the rest hollow.
class _SignalPainter extends CustomPainter {
  const _SignalPainter({required this.bars, required this.ink});

  final int bars;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 4;
    final gap = size.width * 0.08;
    final barW = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final barH = size.height * (0.4 + 0.2 * i);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (barW + gap), size.height - barH, barW, barH),
        const Radius.circular(1),
      );
      canvas.drawRRect(
        r,
        Paint()..color = i < bars ? ink : ink.withValues(alpha: 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(_SignalPainter old) => old.bars != bars || old.ink != ink;
}

/// Three arcs over a dot, [arcs] of them lit and the rest hollow.
class _WifiPainter extends CustomPainter {
  const _WifiPainter({required this.arcs, required this.ink});

  final int arcs;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height);
    canvas.drawCircle(centre, size.height * 0.13, Paint()..color = ink);
    for (var i = 0; i < 3; i++) {
      final radius = size.height * (0.38 + 0.3 * i);
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        // A quarter turn each side of straight up.
        -pi * 0.75,
        pi * 0.5,
        false,
        Paint()
          ..color = i < arcs ? ink : ink.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.16
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_WifiPainter old) => old.arcs != arcs || old.ink != ink;
}

/// A phone's battery glyph: the case, the nub, and a fill as long as the charge.
class _BatteryPainter extends CustomPainter {
  const _BatteryPainter({required this.level, required this.ink});

  final double level;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width - 3, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2.5)),
      Paint()
        ..color = ink.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 2.5, size.height * 0.3, 2.5, size.height * 0.4),
        const Radius.circular(1),
      ),
      Paint()..color = ink.withValues(alpha: 0.7),
    );
    final inner = body.deflate(2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, inner.top, inner.width * level, inner.height),
        const Radius.circular(1.2),
      ),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_BatteryPainter old) =>
      old.level != level || old.ink != ink;
}

/// The home indicator along the bottom edge. Decorative: the barrier and the
/// tiles are how the menu closes, and a bar you could swipe would promise a
/// gesture the popup contract does not have.
class _HomeBar extends StatelessWidget {
  const _HomeBar({required this.kit});

  final KitTheme kit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Center(
      child: Container(
        key: const ValueKey('quick-nav-home-bar'),
        width: 96,
        height: 4,
        decoration: BoxDecoration(
          color: kit.textMuted.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// The phone is RAISED into view — from the bottom-right corner, swivelling —
/// and LOWERED the same way when it is put away.
///
/// The menu used to bounce in where it stood, on the JS's `coachBubblePop`
/// curve — `cubic-bezier(0.34, 1.56, 0.64, 1)`, which overshoots and settles —
/// because a menu that appears instantly reads as a page you were navigated
/// to, and one that springs in reads as something you OPENED. Now that it is a
/// phone in a right hand the same curve drives a different picture, asked for
/// from the couch: "rather than fading in, animate in from the corner, the
/// phone swivelling as if they are raising it in front of them". So it starts
/// low and to the right, tilted the way a phone lies in a hand at the hip, and
/// comes up and level on the spring — no fade, because it starts off the
/// screen and has nothing to fade from. It rides the ROUTE's animation, which
/// is what makes the dismissal the same movement backwards. Reduce-motion
/// makes the route instant, so it simply appears.
class _Raise extends StatelessWidget {
  const _Raise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  // Slower than the old bounce: a phone is lifted, not flicked. "Too fast".
  static const Duration duration = Duration(milliseconds: 640);

  /// Where the raise starts and the lowering ends, as a share of the SCREEN.
  /// **`dx` is a TRANSLATION off the dialog's own centred position, not a
  /// point on the screen**: any non-zero dx slides the phone sideways as it
  /// rises, which is what made it read as coming in from the right. Zero is a
  /// straight vertical lift from under the bottom edge.
  static const Offset from = Offset(0, 1.0);
  static const double tilt = 0;

  @override
  Widget build(BuildContext context) {
    // `Cubic(0.34, 1.56, 0.64, 1)` returns values above 1 through the middle, so
    // the swing overshoots level and settles back, the way a raised arm does.
    // **Only on the way UP.** Played backwards it dipped before it dropped, and
    // that was asked off from the couch: the lowering is a plain ease, straight
    // back down to the corner it came from.
    // **No overshoot either way**: the spring swung the picture past level and
    // showed the end of the drawn wrist for a frame. "Get rid of the bounce."
    final t = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final screen = MediaQuery.sizeOf(context);
    final start = Offset(screen.width * from.dx, screen.height * from.dy);
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) {
        final left = 1 - t.value;
        return Transform.translate(
          offset: start * left,
          child: Transform.rotate(
            angle: tilt * left,
            // About the bottom-center: the hand holding it from below.
            alignment: Alignment.bottomCenter,
            child: Transform.scale(scale: 0.9 + 0.1 * t.value, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _QuickNavTile extends StatelessWidget {
  const _QuickNavTile({required this.item, required this.width});

  final QuickNavItem item;

  /// An exact share of the row — see [_QuickNavMenu.columns].
  final double width;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      width: width,
      child: InkWell(
        key: ValueKey('quick-nav-${item.labelKey}'),
        borderRadius: BorderRadius.circular(12),
        // **THE PHONE STAYS OPEN.** Every door here is a sheet, and it opens
        // OVER the phone; closing it lands the player back on the phone rather
        // than on the pitch — "when we close them, the phone is still open".
        // Asked for from the couch. Putting the phone away is the barrier's
        // job.
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
          decoration: BoxDecoration(
            color: kit.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  item.badge ?? Icon(item.icon, color: kit.accent, size: 28),
                  if (item.dot)
                    Positioned(
                      right: -3,
                      top: -2,
                      child: Container(
                        key: ValueKey('quick-nav-dot-${item.labelKey}'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dangerInk,
                          border: Border.all(color: kit.surface2, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // CAPS, and no ellipsis — a label that scales is readable and a
              // label that is cut off is not.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  t(item.labelKey).toUpperCase(),
                  textAlign: TextAlign.center,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
