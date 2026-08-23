/// The Deadline Day strip in the home footer. Ported from `_eventBannerHtml`
/// and `.ps-event-strip` in `styles/league-scene.css`.
///
/// **A newspaper, in two bands.** A gold headline bar carrying the event and its
/// clock, and a black news strip under it carrying a rolling line of transfer
/// talk. The pairing is the point — gold is what a breaking-news bar looks like,
/// and the dark strip under it is where the words go. The port had one flat
/// surface-coloured row with an emoji on it, which is a menu item.
///
/// **Identical in BOTH themes.** Light mode's gold is a bronze and its surfaces
/// are pale, so a theme-aware version of this is a beige bar with grey text —
/// which is not a news bar.
///
/// **Nothing sweeps across the type.** The only motion here is the live dot and
/// the crawl. A white sheen travelling over the headline washed it out, and
/// there is no backdrop blur either: the strip sits over a scene whose ground
/// animates every frame, and a blur has to re-sample that region continuously,
/// which is a flicker across the bottom of the screen.
///
/// **The crawl carries TWO copies of the copy and travels exactly one of them.**
/// The obvious version — one copy travelling its whole width — leaves the strip
/// blank for as long as it takes the tail to clear, and an empty ticker reads as
/// a broken one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/screens/home/home_screen.dart' show playPageGap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/deadline_news_engine.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/events/event_providers.dart';
import 'package:merge_empire_fc/ui/screens/events/event_screen.dart';
import 'package:merge_empire_fc/util/time.dart';

/// The gold. Fixed, not themed — see the header.
const Color _gold = Color(0xFFFFCD2E);
const Color _goldDeep = Color(0xFFF2A900);
const Color _newsInk = Color(0xFF17130A);
const Color _paper = Color(0xFF0D0F14);
const Color _red = Color(0xFFC62828);

/// The JS's `NEWS_SEP`. The trailing one matters as much as the joins: without
/// it the last headline runs straight into the first on the wrap.
const String _sep = '   •   ';

/// How fast the crawl reads, in logical pixels a second. The duration is
/// DERIVED from this and the measured copy, not picked: a fixed duration crawls
/// through a short set and races through a long one, and the length swings
/// wildly between an idle build-up and a window with three deals in it.
const double _crawlSpeed = 34;

String _clock(int ms) {
  const min = 60000, hour = 60 * min, day = 24 * hour;
  // Coarse units above an hour. The live window is an hour by design so mm:ss
  // normally covers it, but a forced window can be a whole day and "540:00" is
  // not a clock — anything that long stops being a countdown and becomes a
  // duration.
  if (ms >= day) return '${ms ~/ day}d ${(ms % day) ~/ hour}h';
  if (ms >= hour) return '${ms ~/ hour}h ${(ms % hour) ~/ min}m';
  return '${ms ~/ min}:${((ms % min) ~/ 1000).toString().padLeft(2, '0')}';
}

class EventStrip extends ConsumerWidget {
  const EventStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveId = ref.watch(activeEventProvider);
    final id = liveId ?? ref.watch(upcomingEventProvider);
    final event = id == null ? null : getEventById(id);
    // For most of the year there is no window within a week, and the strip is
    // off the page entirely rather than sitting there reading "in 108d". That
    // is also why the CLOCK lives one level down: no event, no ticking timer.
    if (event == null) return const SizedBox.shrink();
    return _Strip(event: event, live: liveId != null);
  }
}

class _Strip extends ConsumerStatefulWidget {
  const _Strip({required this.event, required this.live});

  final EventDef event;
  final bool live;

  @override
  ConsumerState<_Strip> createState() => _StripState();
}

class _StripState extends ConsumerState<_Strip> {
  Timer? _clockTick;

  /// Repainted every second, and ONLY the clock is: the headlines are rebuilt
  /// when the state moves, because re-deriving them each tick would restart the
  /// crawl once a second.
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _clockTick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _tick++),
    );
  }

  @override
  void dispose() {
    _clockTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final live = widget.live;
    final state = ref.watch(gameProvider).state;

    final ms = live ? eventEndsAtMs(event) - now() : eventStartsInMs(event);
    final clock = _clock(ms < 0 ? 0 : ms);

    return Padding(
      // The Play page's own seam — see `playPageGap`.
      padding: const EdgeInsets.only(bottom: playPageGap),
      child: GestureDetector(
        key: const ValueKey('home-event-strip'),
        onTap: () => openEventScreen(context, ref),
        child: Semantics(
          button: true,
          label: eventName(event),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(11),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x57000000),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Headline(
                    name: eventName(event),
                    // Live counts DOWN TO the doors shutting; upcoming counts to
                    // them opening, and says so rather than quoting a bare
                    // figure that would read as time left.
                    clock: live
                        ? clock
                        : t('event.banner.starts_in_short', {'time': clock}),
                    live: live,
                  ),
                  _Ticker(
                    lines: [
                      for (final line in deadlineHeadlines(
                        state ?? const <String, dynamic>{},
                        live: live,
                        clubName:
                            state?['clubName'] as String? ??
                            t('common.your_club'),
                      ))
                        t(line.key, line.params),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Black on gold, the highest-contrast pairing in the palette — which is what
/// lets this be the loudest thing in the footer without being the brightest.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.name,
    required this.clock,
    required this.live,
  });

  final String name;
  final String clock;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 5, 8, 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gold, _goldDeep],
        ),
      ),
      child: Row(
        children: [
          if (live) ...[const _LiveDot(), const SizedBox(width: 8)],
          Expanded(
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: 0.2,
                color: _newsInk,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // A chip, not loose text. It is the one number here, and the inset
          // well is what stops it reading as part of the title.
          Container(
            key: const ValueKey('event-strip-clock'),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              clock,
              style: TextStyle(
                fontSize: live ? 15 : 14,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFD970),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Points UP, into the screen this opens. Pointing back would read as
          // "return" on a strip that goes forward.
          const Icon(
            Icons.keyboard_arrow_up,
            size: 18,
            color: Color(0x9917130A),
          ),
        ],
      ),
    );
  }
}

/// Pulses because the doors are open. It is absent rather than dimmed when they
/// are not: a red dot means LIVE, and showing a grey one would be lying about
/// the same thing in a quieter voice.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  void _sync() {
    if (MediaQuery.of(context).disableAnimations) {
      if (_c.isAnimating) _c.stop();
      return;
    }
    if (!_c.isAnimating) _c.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      // A ring expanding out of the dot and fading, which is a broadcast's
      // on-air light rather than a blinking cursor.
      final t = Curves.easeOut.transform(_c.value.clamp(0, 0.7) / 0.7);
      return SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: 0.7 * (1 - t)),
                spreadRadius: 6 * t,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The crawl: a red NEWS chip and the headlines strung together, running right
/// to left forever the way a broadcast ticker does.
class _Ticker extends StatefulWidget {
  const _Ticker({required this.lines});

  final List<String> lines;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  String get _copy =>
      widget.lines.isEmpty ? '' : '${widget.lines.join(_sep)}$_sep';

  /// Measured, not guessed. Pixels per second is the thing that has to stay
  /// constant, so the time comes from the width — see [_crawlSpeed].
  double _segmentWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: _copy, style: _style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    // The leading padding travels with the copy, so it is part of the period.
    return painter.width + _leadPad;
  }

  static const double _leadPad = 22;
  static const TextStyle _style = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: Color(0xDBFFFFFF),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) return const SizedBox.shrink();
    final width = _segmentWidth(context);
    // A crawl that never stops is exactly what reduce-motion is asking us not
    // to do. The strip holds its first headline instead — nothing here is
    // unavailable elsewhere, and the Deadline Day screen carries the same
    // business in full.
    final still = MediaQuery.of(context).disableAnimations;

    final seconds = (width / _crawlSpeed).clamp(6.0, 90.0);
    final want = Duration(milliseconds: (seconds * 1000).round());
    if (_c.duration != want) {
      final running = _c.isAnimating;
      _c.stop();
      _c.duration = want;
      if (running) _c.repeat();
    }
    if (still) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.32))),
      ),
      // The chip has to run the full height of the copy beside it, and the
      // copy's height is what it is — so the row's height has to be measured
      // before it can be handed down. Stretch alone asks for infinity here,
      // because nothing above this in the footer's column bounds it.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _red,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Text(
                t('event.news.chip'),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: still
                      ? Padding(
                          padding: const EdgeInsets.only(left: _leadPad),
                          child: Text(
                            widget.lines.first,
                            key: const ValueKey('event-news'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _style,
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _c,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(-_c.value * width, 0),
                            child: child,
                          ),
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            maxWidth: width * 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 2; i++)
                                  SizedBox(
                                    width: width,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: _leadPad,
                                      ),
                                      child: Text(
                                        _copy,
                                        key: i == 0
                                            ? const ValueKey('event-news')
                                            : null,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.clip,
                                        style: _style,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
