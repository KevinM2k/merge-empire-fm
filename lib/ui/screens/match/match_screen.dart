/// The live match — a takeover screen, not a popup.
///
/// It plays out a match `simulateMatch` has ALREADY decided. Nothing here
/// changes a result: the clock only chooses when an already-decided event
/// appears, which is what lets the differential harness prove the engine against
/// the JS without a widget anywhere near it.
///
/// It sets `tickGatesProvider.matchOpen` for as long as it is up. That is the
/// whole reason the gates are a record rather than a DOM query: without it the
/// loop would drop a transfer bid or Coach Colin on top of the match.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({
    super.key,
    required this.result,
    this.onFinished,
    this.fast = false,
  });

  /// A finished match, from `simulateMatch`.
  final Map<String, dynamic> result;

  /// Called once, at full time.
  final void Function(Map<String, dynamic> result)? onFinished;

  final bool fast;

  @override
  ConsumerState<MatchScreen> createState() => MatchScreenState();
}

class MatchScreenState extends ConsumerState<MatchScreen> {
  late final List<TimelineEvent> _timeline = timelineOf(widget.result);
  late final int _end =
      fullTime((widget.result['addedTime'] as num?)?.toInt() ?? 0);

  Timer? _timer;
  int _minute = 0;
  bool _reported = false;

  /// Held from initState: `ref` is not usable once the widget is disposed, and
  /// handing the gates back is exactly a teardown job.
  late final StateController<TickGates> _gates;

  MatchFrame get frame =>
      frameAt(widget.result, _minute, timeline: _timeline);

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    // Claim the screen before the first tick can land anything on top of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gates.state = (
        matchOpen: true,
        miniGameOpen: false,
        transferOpen: false,
        colinOnScreen: false,
      );
    });
    _timer = Timer.periodic(minuteDuration(fast: widget.fast), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (_minute >= _end) {
      _finish();
      return;
    }
    setState(() => _minute++);
  }

  /// Jump to full time. The result was decided before the first whistle, so
  /// skipping costs the player the story and nothing else.
  void skipToEnd() {
    if (!mounted) return;
    setState(() => _minute = _end);
    _finish();
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (_reported) return;
    _reported = true;
    widget.onFinished?.call(widget.result);
  }

  @override
  void deactivate() {
    // Hand the screen back, or every later tick still believes a match is on.
    //
    // Deferred off the frame because Riverpod refuses a provider write inside a
    // widget lifecycle, and leaving a route IS one. Guarded because the whole
    // scope can go first — at app teardown, and in a test that disposes its
    // container before the tree unmounts; if the scope has gone there are no
    // ticks left to gate and nothing to put right.
    final gates = _gates;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        gates.state = clearScreenGates;
      } on StateError {
        // Nothing left to tell.
      }
    });
    super.deactivate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final f = frame;
    final home = widget.result['isHome'] == true;
    final us = '${widget.result['clubName'] ?? ''}';
    final them = '${widget.result['opponentName'] ?? ''}';

    return Scaffold(
      key: const ValueKey('match-screen'),
      backgroundColor: kit.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Scoreboard(
              key: const ValueKey('match-scoreboard'),
              left: home ? us : them,
              right: home ? them : us,
              leftGoals: f.homeGoals,
              rightGoals: f.awayGoals,
              minute: f.minute,
              finished: f.finished,
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('match-feed'),
                reverse: true,
                itemCount: f.shown.length,
                itemBuilder: (context, i) {
                  final e = f.shown[f.shown.length - 1 - i];
                  return _FeedLine(event: e);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: f.finished
                    ? ElevatedButton(
                        key: const ValueKey('match-close'),
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(_verdictLabel()),
                      )
                    : OutlinedButton(
                        key: const ValueKey('match-skip'),
                        onPressed: skipToEnd,
                        child: Text(t('common.skip')),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _verdictLabel() {
    if (widget.result['won'] == true) return t('match.victory');
    if (widget.result['drawn'] == true) return t('match.draw');
    return t('match.defeat');
  }
}

/// Restores the gates. Named so the intent survives a refactor of the record.
const clearScreenGates = (
  matchOpen: false,
  miniGameOpen: false,
  transferOpen: false,
  colinOnScreen: false,
);

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    super.key,
    required this.left,
    required this.right,
    required this.leftGoals,
    required this.rightGoals,
    required this.minute,
    required this.finished,
  });

  final String left;
  final String right;
  final int leftGoals;
  final int rightGoals;
  final int minute;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  left,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$leftGoals – $rightGoals',
                  key: const ValueKey('match-score'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: kit.accentBright,
                  ),
                ),
              ),
              Expanded(
                child: Text(right, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            finished ? t('match.full_time') : "$minute'",
            key: const ValueKey('match-clock'),
            style: TextStyle(color: kit.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FeedLine extends StatelessWidget {
  const _FeedLine({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final isGoal = event.type == 'goal';
    // A commentary line is a translation KEY the engine emitted, which is why
    // the i18n layer had to land before any of this.
    final text = switch (event.type) {
      'goal' => event.scorer ?? t('match.goal_card.title'),
      'halftime' => t('match.half_time'),
      'commentary' => event.textKey == null ? '' : t(event.textKey!),
      _ => event.type,
    };
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "${event.minute}'",
              style: TextStyle(color: kit.textMuted, fontSize: 11),
            ),
          ),
          if (isGoal)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.sports_soccer, size: 14),
            ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isGoal ? FontWeight.w700 : FontWeight.w400,
                color: isGoal ? kit.accentBright : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
