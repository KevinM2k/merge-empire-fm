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
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart'
    show pitchAspect;
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart'
    show skyGradient;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';
import 'package:merge_empire_fc/util/stat_display.dart';

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
  late final int _end = fullTime(
    (widget.result['addedTime'] as num?)?.toInt() ?? 0,
  );

  Timer? _timer;
  int _minute = 0;
  bool _reported = false;

  /// The chance currently playing out on the pitch, or null for the idle one.
  ///
  /// Set when the clock reaches an event worth watching and cleared when the
  /// clip finishes. The clock does NOT wait for it: the passage is a retelling
  /// of something already decided, so a slow clip must not hold the match up.
  CutawayClip? _clip;

  /// The last minute a clip was cut for, so a rebuild does not restart one.
  int _clippedMinute = -1;

  /// Held from initState: `ref` is not usable once the widget is disposed, and
  /// handing the gates back is exactly a teardown job.
  late final StateController<TickGates> _gates;

  MatchFrame get frame => frameAt(widget.result, _minute, timeline: _timeline);

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
    setState(() {
      _minute++;
      _cutIfWorthWatching();
    });
  }

  /// Put the newest event on the pitch, when it is one you can watch.
  void _cutIfWorthWatching() {
    for (final event in _timeline) {
      if (event.minute != _minute || event.minute == _clippedMinute) continue;
      final ours = event.team == 'home'
          ? widget.result['isHome'] == true
          : widget.result['isHome'] != true;
      final clip = clipFor(
        event,
        // We defend the left end, so our attacks run right.
        ourSideLeft: true,
        ours: ours,
        // Seeded off the minute so the same match replays the same chances.
        seed: (widget.result['seed'] as num?)?.toInt() ?? 0 + event.minute,
      );
      if (clip == null) continue;
      _clippedMinute = event.minute;
      _clip = clip;
      return;
    }
  }

  /// Jump to full time. The result was decided before the first whistle, so
  /// skipping costs the player the story and nothing else.
  void skipToEnd() {
    if (!mounted) return;
    // Nothing to watch on the way to full time.
    setState(() {
      _minute = _end;
      _clip = null;
    });
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
    final f = frame;
    final home = widget.result['isHome'] == true;
    final us = '${widget.result['clubName'] ?? ''}';
    final them = '${widget.result['opponentName'] ?? ''}';

    return Scaffold(
      key: const ValueKey('match-screen'),
      // ON THE SKY, not on the app's page colour. This page is a takeover — it
      // is nearly all panel, with no diorama behind it — so a background that
      // followed the theme put pale panels on a pale page in light mode and the
      // whole match went flat. The same sky the Play screen stands under, so
      // kicking off is not arriving somewhere else.
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: skyGradient),
        child: SafeArea(
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
                result: widget.result,
                isHome: home,
              ),
              const Divider(height: 1),
              // THE STAGE: one band, fixed for the whole match, holding the
              // pitch's aspect. At rest it shows the stat board; a chance cuts in
              // ON TOP of it at the same inset and radius. The port mounted the
              // pitch only for a chance and took it away after, so the band itself
              // appeared and vanished — which is what made the pitch look like it
              // was flickering and jumping about.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: ConstrainedBox(
                  // Capped: the pitch is landscape and at its natural aspect would
                  // take a third of a tall phone and all of a short one.
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                  ),
                  child: AspectRatio(
                    aspectRatio: pitchAspect,
                    child: Stack(
                      key: const ValueKey('match-stage'),
                      fit: StackFit.expand,
                      children: [
                        MatchStatboard(
                          stats: liveStatsFor(
                            frame: f,
                            result: widget.result,
                            isHome: home,
                            // The tactic the side went out in. The sim has already
                            // run, so it cannot change mid-replay — which is why
                            // it is read once off the result rather than watched.
                            strategyId:
                                '${widget.result['strategyId'] ?? 'balanced'}',
                          ),
                          isHome: home,
                        ),
                        // Only while a chance is running, and opaque, so it covers
                        // the board whole rather than sitting beside it.
                        if (_clip != null)
                          CutawayStage(
                            clip: _clip,
                            onDone: (_) {
                              if (mounted) setState(() => _clip = null);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('match-feed'),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  // NEWEST FIRST. `reverse: true` put index 0 at the bottom, so the
                  // newest line arrived at the foot of the list and everything
                  // worth reading was off the bottom of a long match. A line should
                  // arrive from ABOVE and push the rest down, which is the
                  // direction the feed actually grows.
                  itemCount: f.shown.length,
                  itemBuilder: (context, i) =>
                      _FeedLine(event: f.shown[f.shown.length - 1 - i]),
                ),
              ),
              if (f.finished) _QuestOutcomes(result: widget.result),
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
      ),
    );
  }

  String _verdictLabel() {
    if (widget.result['won'] == true) return t('match.victory');
    if (widget.result['drawn'] == true) return t('match.draw');
    return t('match.defeat');
  }
}

/// What the match's three quests came to.
///
/// All three, not just the winners: the player is being shown what they MISSED
/// as much as what they won, which is what makes the next set worth reading. The
/// coins have already been paid — a match quest auto-pays at full time — so this
/// is a report, not a claim.
class _QuestOutcomes extends StatelessWidget {
  const _QuestOutcomes({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final raw = result['questResults'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final rows = [
      for (final entry in raw)
        if (entry is Map<String, dynamic>) entry,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = rows.fold<num>(
      0,
      (sum, r) => sum + ((r['coins'] as num?) ?? 0),
    );

    return Padding(
      key: const ValueKey('match-quests'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      // Per-division text, interpolated off the target the quest
                      // was set at rather than today's — a quest is judged on
                      // what it asked for when it was drawn.
                      t('quest.${row['id']}', {'n': row['target'] ?? 0}),
                      style: TextStyle(
                        color: row['passed'] == true
                            ? kit.accentBright
                            : kit.textMuted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row['passed'] == true
                        ? t('quests.reward_coins', {'n': row['coins'] ?? 0})
                        : t('quests.missed'),
                    key: ValueKey('match-quest-${row['id']}'),
                    style: TextStyle(
                      color: row['passed'] == true
                          ? kit.accentBright
                          : kit.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${t('quests.total_reward')}: '
                '${t('quests.reward_coins', {'n': total.toInt()})}',
                key: const ValueKey('match-quests-total'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: kit.accentBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Restores the gates. Named so the intent survives a refactor of the record.
const clearScreenGates = (
  matchOpen: false,
  miniGameOpen: false,
  transferOpen: false,
  colinOnScreen: false,
);

/// The competition, the clock, the names, the score, and the SAME mirrored
/// ATK/DEF block the Play screen's next-match card draws.
///
/// Sharing that block is the point of it: the fixture you accepted and the
/// fixture you are watching are visibly the same object, and two copies of the
/// markup would drift apart the first time either surface was touched.
///
/// Home on the LEFT, as on the card and as football writes a scoreline.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    super.key,
    required this.left,
    required this.right,
    required this.leftGoals,
    required this.rightGoals,
    required this.minute,
    required this.finished,
    required this.result,
    required this.isHome,
  });

  final String left;
  final String right;
  final int leftGoals;
  final int rightGoals;
  final int minute;
  final bool finished;
  final Map<String, dynamic> result;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;

    num asNum(Object? v) => v is num ? v : 0;
    // Composed the way the next-match card composes it: OUR split carries the
    // tactic's multipliers, theirs never does. The two screens print the same
    // numbers because they do the same arithmetic on the same fields.
    final strat =
        strategies['${result['strategyId'] ?? defaultStrategy}'] ??
        strategies[defaultStrategy]!;
    final mult = tacticMultipliers(
      strat,
      (result['oppAttackRatio'] as num?)?.toDouble(),
    );
    final ourFifa = fifaSplitTactic(
      asNum(result['ourAttackRating']),
      asNum(result['ourDefenceRating']),
      mult.atk,
      mult.def,
    );
    final theirFifa = fifaSplit(
      asNum(result['effOppAttackRating']),
      asNum(result['effOppDefenceRating']),
    );
    final ourSplit = (atk: ourFifa.atk, def: ourFifa.def);
    final theirSplit = (atk: theirFifa.atk, def: theirFifa.def);
    final ourRating = asNum(result['effectiveSquadRating']).round();
    final theirRating = asNum(result['effectiveOppRating']).round();
    // A cup tie or an older save may carry no split at all, and four zeroes
    // would be worse than nothing.
    final hasSplit = result['ourAttackRating'] != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      child: Column(
        children: [
          // What this is, and how far in.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${result['divisionName'] ?? ''} · '
                '${t(isHome ? 'play.home' : 'play.away')}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: kit.textMuted,
                ),
              ),
              Text(
                finished ? t('match.full_time') : "$minute'",
                key: const ValueKey('match-clock'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: kit.accentBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // The clock as a bar, so how far through the match is readable without
          // doing arithmetic on the minute.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: (minute / 90).clamp(0.0, 1.0),
                backgroundColor: kit.border,
                valueColor: AlwaysStoppedAnimation(kit.accentBright),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _TeamRow(
            left: Text(
              left,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: isHome ? kit.accentBright : ink,
              ),
            ),
            gutter: const SizedBox.shrink(),
            right: Text(
              right,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: isHome ? ink : kit.accentBright,
              ),
            ),
          ),
          _TeamRow(
            left: Text(
              '$leftGoals',
              key: const ValueKey('match-score-left'),
              style: TextStyle(
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w900,
                color: ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            gutter: Text(
              t('common.vs').toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: kit.textMuted,
              ),
            ),
            right: Text(
              '$rightGoals',
              key: const ValueKey('match-score-right'),
              style: TextStyle(
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w900,
                color: ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Only when the result carries the split. A cup tie or an older save
          // may not, and four zeroes would be worse than nothing.
          if (hasSplit)
            MatchStatRows(
              left: isHome ? ourSplit : theirSplit,
              right: isHome ? theirSplit : ourSplit,
              leftRating: isHome ? ourRating : theirRating,
              rightRating: isHome ? theirRating : ourRating,
            ),
        ],
      ),
    );
  }
}

/// The card's `[1fr | gutter | 1fr]` shape, so the score, the names and the
/// ratings below them all line up on the same three tracks.
class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.left,
    required this.gutter,
    required this.right,
  });

  final Widget left;
  final Widget gutter;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Center(child: left)),
      const SizedBox(width: nmGap),
      SizedBox(
        width: nmGutter,
        child: Center(child: gutter),
      ),
      const SizedBox(width: nmGap),
      Expanded(child: Center(child: right)),
    ],
  );
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
