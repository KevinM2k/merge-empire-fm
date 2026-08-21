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
import 'package:merge_empire_fc/data/quests.dart' show questBank;
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/quest_match.dart'
    show QuestLive, liveMatchQuestStatus, partialMatchResult;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/services/sound_service.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart'
    show pitchAspect;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart'
    show reSimulateRemainder;
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart'
    show coachSuggestedTacticProvider;
import 'package:merge_empire_fc/engine/lineup_engine.dart'
    show refillLineupFromBench;
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart'
    show QuestRow, matchQuestsProvider;
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart'
    show cardById;
import 'package:merge_empire_fc/ui/screens/settings_controls.dart'
    show settingPick;
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';
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
  /// Rebuilt whenever the tactic changes — see [applyStrategy]. Not `final`:
  /// the remainder of the match is genuinely re-decided, so the list of what is
  /// left to show is replaced.
  late List<TimelineEvent> _timeline = timelineOf(widget.result);
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

  /// What the side is playing right now.
  late String _strategy = '${widget.result['strategyId'] ?? defaultStrategy}';

  /// What Colin would have played, captured when the screen opens.
  ///
  /// Null when he agreed with the tactic that was already set. Switching TO his
  /// pick mid-match is what sets `followedCoachSuggestion`, which is the whole
  /// of one achievement and one quest.
  String? _coachSuggestion;

  /// A second's grace after a change, so the strip cannot be strummed.
  bool _tacticCooldown = false;
  Timer? _cooldownTimer;

  /// The tactic changes, as feed lines. They are not events on the timeline —
  /// nothing decided them — so they ride alongside it and merge in by minute.
  final List<FeedLine> _notes = [];

  /// How many changes have been made, and the eleven that started.
  ///
  /// The kickoff lineup is captured because it has to go BACK: a substitution
  /// is a change for this match, and letting it stand would make it next week's
  /// team by accident.
  int _subsUsed = 0;
  List<Map<String, dynamic>> _kickoffLineup = const [];
  bool _lineupRestored = false;

  /// The clock waits while the panel is open — choosing is not watching.
  bool _paused = false;

  /// Which of the two the body is showing.
  bool _onQuests = false;

  /// Double speed, starting from the player's own setting.
  ///
  /// **It is a live control, not a preference read once.** The setting decides
  /// how a match OPENS; the button is for the moment ten minutes in when the
  /// manager decides they have seen enough of this one. It does not skip
  /// anything — a match that skips events is a match whose story the player did
  /// not get — it just halves the wait.
  late bool _fast = widget.fast;

  /// Test seams.
  bool get fast => _fast;
  String get strategy => _strategy;
  bool get tacticOnCooldown => _tacticCooldown;
  int get subsUsed => _subsUsed;
  bool get paused => _paused;

  /// Held from initState: `ref` is not usable once the widget is disposed, and
  /// handing the gates back is exactly a teardown job.
  late final StateController<TickGates> _gates;

  /// Held for the same reason — the bed has to go back to the menu on the way
  /// out, and by then `ref` is gone.
  late final SoundService _sound;

  /// The delayed sound cues, so they can be cancelled.
  ///
  /// Several of them are a beat AFTER the thing they belong to — the crowd
  /// reacting to a goal, the result after the final whistle — and a timer that
  /// outlives this screen would play a fanfare over whatever came next.
  final List<Timer> _cues = [];

  void _cue(Duration after, void Function() play) {
    late Timer timer;
    timer = Timer(after, () {
      _cues.remove(timer);
      if (mounted) play();
    });
    _cues.add(timer);
  }

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
    // Read ONCE, before the first minute: it is derived from the save, and the
    // save moves under a long match.
    _coachSuggestion = ref.read(coachSuggestedTacticProvider);
    _kickoffLineup = _lineupSnapshot();
    _startClock();
    // **THE MATCH HAS ITS OWN BED, and the whistle starts it.** The sounds here
    // belong to the CLOCK rather than to the simulation: the whole ninety
    // minutes was decided before this screen opened, so an event fired when the
    // maths was done would have played every goal at once. See
    // `services/sound_cues.dart` for the ones that do ride the bus.
    _sound = ref.read(soundServiceProvider);
    unawaited(_sound.setMusicTrack(MusicBed.match));
    unawaited(_sound.play('whistle'));
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(minuteDuration(fast: _fast), (_) => _tick());
  }

  /// Halve the wait, or put it back. The clock is restarted rather than
  /// retimed, which is the only way to change a periodic timer's period.
  void toggleSpeed() {
    if (frame.finished) return;
    setState(() => _fast = !_fast);
    _startClock();
  }

  void _tick() {
    if (!mounted) return;
    // Choosing a substitution is not watching the match.
    if (_paused) return;
    // **THE CLOCK STOPS WHILE A CHANCE IS ON THE PITCH.** It did not, and that is
    // what made the minute jump: the cutaway takes a second or two to play out
    // and the clock kept counting under it, so the passage ended three or four
    // minutes after the one it belongs to and the feed lurched to catch up. A
    // chance is a RETELLING of a minute — the minute cannot have moved on while
    // it is being retold.
    if (_clip != null) return;
    if (_minute >= _end) {
      _finish();
      return;
    }
    setState(() {
      _minute++;
      _cutIfWorthWatching();
    });
    _soundFor(_minute);
  }

  /// Whatever landed on this minute, in sound.
  ///
  /// Read off the timeline rather than off the cutaway, because a chance the 2D
  /// pitch is not showing — the player has it switched off, or it is the
  /// opponent's — still happened and still deserves the crowd's reaction.
  void _soundFor(int minute) {
    final sound = ref.read(soundServiceProvider);
    for (final event in _timeline) {
      if (event.minute != minute) continue;
      // `home` is US on an event, whichever ground we are on — see
      // `MatchFrame`. Reading it through `isHome` played the crowd's
      // disappointment for our own goals in every away fixture.
      final ours = event.team != 'away';
      switch (event.type) {
        case 'goal':
          // The kick is what makes a goal an event rather than a chime: the ball
          // is struck and then the reaction arrives, which is the order it
          // happens in.
          unawaited(sound.play('shotKick'));
          _cue(
            const Duration(milliseconds: 180),
            () => unawaited(sound.play(ours ? 'goal' : 'goalAgainst')),
          );
        case 'chance':
          unawaited(sound.play('kick'));
          // A chance that hit the target and stayed out is the one the crowd
          // reacts to; a wild one off target is not worth a sound.
          if (event.shotResult == 'on_target') {
            _cue(
              const Duration(milliseconds: 200),
              () => unawaited(sound.play(ours ? 'crowdOoh' : 'woodwork')),
            );
          }
        case 'injury':
          unawaited(sound.play('injury'));
        case 'halftime':
        case 'fulltime':
          unawaited(sound.play('whistle'));
        default:
          break;
      }
    }
  }

  /// When the last CHANCE cutaway played, for the pacing gap. Goals do not set
  /// it: they bypass the gap, and letting one push the next chance out would
  /// hide a passage of play because something better happened.
  int? _lastChanceCutMinute;

  /// Put the newest event on the pitch, when it is one you can watch.
  void _cutIfWorthWatching() {
    for (final event in _timeline) {
      if (event.minute != _minute || event.minute == _clippedMinute) continue;
      // `home` is US on an event, whichever ground we are on — see
      // `MatchFrame`. Reading it through `isHome` played the crowd's
      // disappointment for our own goals in every away fixture.
      final ours = event.team != 'away';
      final clip = clipFor(
        event,
        // We defend the left end, so our attacks run right.
        ourSideLeft: true,
        ours: ours,
        // Seeded off the minute so the same match replays the same chances.
        seed: (widget.result['seed'] as num?)?.toInt() ?? 0 + event.minute,
        // **The two switches on the Settings screen**, which nothing read: they
        // are independent, so the cutaway can be on for both sides, one, or
        // neither.
        ourTeamOn: ref.read(settingPick<bool>('cutawayOurTeam', true)),
        opponentOn: ref.read(settingPick<bool>('cutawayOpponent', true)),
        // The pacing gap. A goal is exempt and does not set it either — it is
        // always worth showing, and it must not push the next chance out.
        lastCutawayMinute: _lastChanceCutMinute,
      );
      if (clip == null) continue;
      _clippedMinute = event.minute;
      if (event.type == 'chance') _lastChanceCutMinute = event.minute;
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
    _restoreKickoffLineup();
    final sound = ref.read(soundServiceProvider);
    unawaited(sound.play('whistle'));
    // The result, a beat after the final whistle rather than under it.
    final f = frame;
    // Ours and theirs already — see `MatchFrame`. Flipping on `isHome` here
    // played the defeat sting for an away WIN.
    final ours = f.ourGoals;
    final theirs = f.theirGoals;
    _cue(
      const Duration(milliseconds: 450),
      () => unawaited(
        sound.play(
          ours > theirs
              ? 'victory'
              : ours == theirs
              ? 'draw'
              : 'defeat',
        ),
      ),
    );
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
    _cooldownTimer?.cancel();
    for (final cue in _cues) {
      cue.cancel();
    }
    _cues.clear();
    // Back to the menu bed. In `dispose` rather than `deactivate` because the
    // match popup that follows this screen is still the match as far as the
    // player is concerned.
    unawaited(_sound.setMusicTrack(MusicBed.menu));
    super.dispose();
  }

  /// The eleven as it stands, as plain maps.
  List<Map<String, dynamic>> _lineupSnapshot() {
    final lineup =
        (ref.read(gameProvider).state?['squad']
            as Map<String, dynamic>?)?['lineup'];
    return [
      for (final row in lineup is List ? lineup : const [])
        if (row is Map<String, dynamic>)
          {'slotId': row['slotId'], 'cardInstanceId': row['cardInstanceId']},
    ];
  }

  /// Open the panel, holding the match while it is up.
  Future<void> openSubs() async {
    if (frame.finished || _paused) return;
    setState(() => _paused = true);
    await showSubsPanel(context, used: _subsUsed, onSub: _onSub);
    if (mounted) setState(() => _paused = false);
  }

  /// Record a change the panel has already written to the save.
  ///
  /// **What the quests read is stamped here.** `subsUsed` and `subbedOnIds` are
  /// things the MANAGER did rather than things the dice did, which is the whole
  /// appeal of asking for them — and until there was a panel neither could move
  /// off its kickoff value, so `match_use_subs` and `match_sub_scores` were two
  /// quests that could not advance.
  void _onSub(SubMade sub) {
    _subsUsed++;
    widget.result['subsUsed'] = _subsUsed;
    final on = widget.result['subbedOnIds'];
    final onList = on is List ? on : <Object?>[];
    onList.add(sub.onId);
    widget.result['subbedOnIds'] = onList;

    final state = ref.read(gameProvider).state;
    final onName = cardById(state, sub.onId)?.name() ?? '';
    final offName = sub.offId == null
        ? null
        : cardById(state, sub.offId!)?.name();
    setState(() {
      _notes.add((
        minute: _minute,
        type: 'subs',
        // Filling a hole — an injury, or a slot that started the match empty —
        // has no outgoing player, so the line cannot name one.
        key: offName == null || offName.isEmpty
            ? 'match.subs.feed_on'
            : 'match.subs.feed',
        params: {'on': onName, 'off': offName ?? ''},
        seed: 'sub-$_minute-${sub.onId}',
      ));
    });
  }

  /// Put the kickoff eleven back, then cover whatever hole the match left in it.
  ///
  /// A substitution is a change for THIS match. Leaving it standing would make
  /// the manager's 70th-minute gamble next week's team without them asking. The
  /// refill is the other half: carrying an injury's gap forward means kicking
  /// off the next fixture with ten men and no warning.
  /// **Only when a change was actually made.** The source restores at every
  /// full time and refills the bench with it; here the screen puts back what IT
  /// altered and nothing else, because a save write on the end of every match
  /// that changed nothing is a write for nothing. The post-match refill of an
  /// injury's hole belongs to whoever applies the injuries, not to the replay.
  void _restoreKickoffLineup() {
    if (_lineupRestored || _subsUsed == 0 || _kickoffLineup.isEmpty) return;
    _lineupRestored = true;
    ref.read(gameProvider).update((s) {
      final squad = s['squad'];
      if (squad is! Map<String, dynamic>) return;
      final lineup = squad['lineup'];
      if (lineup is! List) return;
      final kickoff = {
        for (final row in _kickoffLineup) row['slotId']: row['cardInstanceId'],
      };
      for (final row in lineup) {
        if (row is! Map<String, dynamic>) continue;
        if (!kickoff.containsKey(row['slotId'])) continue;
        row['cardInstanceId'] = kickoff[row['slotId']];
      }
      refillLineupFromBench(s);
    });
  }

  /// Change the tactic, and RE-DECIDE the rest of the match under it.
  ///
  /// **`reSimulateRemainder` is 350 ported, tested lines with no caller in
  /// `lib/`** — which is why five quests and four achievements that read
  /// `strategyChanged`, `strategiesUsed`, `finalStrategy` and
  /// `followedCoachSuggestion` could only ever see their kickoff defaults.
  /// Three of those achievements were unwinnable.
  ///
  /// The split is the JS's and its reasoning is worth keeping: events whose
  /// minute has PASSED are kept — they have either fired or are guaranteed to,
  /// a goal whose cutaway is still playing being the case that matters — and
  /// the baseline goals are counted from those kept EVENTS rather than from the
  /// scoreboard tally. Passing the tally would drop a goal the feed has already
  /// promised, and the screen would end 2-1 with the engine calling it a draw.
  void applyStrategy(String id) {
    if (frame.finished || id == _strategy || _tacticCooldown) return;
    final strat = strategies[id];
    if (strat == null) return;

    final at = _minute;
    final raw = widget.result['events'];
    final kept = [
      for (final e in raw is List ? raw : const [])
        if (e is Map<String, dynamic> && ((e['minute'] as num?) ?? 0) <= at) e,
    ];
    var ours = 0;
    var theirs = 0;
    for (final e in kept) {
      if (e['type'] != 'goal') continue;
      // `home` is us — see `MatchFrame`.
      if (e['team'] == 'away') {
        theirs++;
      } else {
        ours++;
      }
    }

    final fresh = reSimulateRemainder(
      widget.result,
      at,
      id,
      ours,
      theirs,
      ref.read(gameProvider).state,
    );
    widget.result['events'] = [...kept, ...fresh];

    // What the quests and the achievements read. `strategiesUsed` opens with
    // the tactic the side kicked off in, so a switch is genuinely a second
    // entry rather than the first.
    widget.result['strategyChanged'] = true;
    final used = widget.result['strategiesUsed'];
    final usedList = used is List ? used : <Object?>[_strategy];
    if (!usedList.contains(id)) usedList.add(id);
    widget.result['strategiesUsed'] = usedList;
    widget.result['finalStrategy'] = id;
    if (id == _coachSuggestion) {
      widget.result['followedCoachSuggestion'] = true;
    }

    setState(() {
      _strategy = id;
      _timeline = timelineOf(widget.result);
      _notes.add((
        minute: at,
        type: 'tactics',
        key: 'pause.tactics_change',
        params: {
          'name': t('strategy.$id.name'),
          'hint': t('strategy.$id.hint'),
        },
        seed: 'tactic-$at-$id',
      ));
      _tacticCooldown = true;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(tacticCooldown, () {
      if (mounted) setState(() => _tacticCooldown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = frame;
    final home = widget.result['isHome'] == true;
    final us = '${widget.result['clubName'] ?? ''}';
    final them = '${widget.result['opponentName'] ?? ''}';
    // Only what has been SHOWN, so the feed can never run ahead of the clock —
    // and built off the whole shown list, because whether a chance earns a line
    // depends on how long it has been since the last one did.
    final questRows = ref.watch(matchQuestsProvider);
    final raw = widget.result['events'];
    final events = feedOf(f.shown, ourName: us, theirName: them, isHome: home);
    // The tactic changes, merged in by minute. A stable merge rather than a
    // sort: `_notes` is already in order, and a note belongs AFTER the events
    // of the minute it was made in — the switch answers what just happened.
    final lines = <FeedLine>[];
    var next = 0;
    for (final line in events) {
      while (next < _notes.length &&
          _notes[next].minute < line.minute &&
          _notes[next].minute <= f.minute) {
        lines.add(_notes[next++]);
      }
      lines.add(line);
    }
    while (next < _notes.length && _notes[next].minute <= f.minute) {
      lines.add(_notes[next++]);
    }

    return Scaffold(
      key: const ValueKey('match-screen'),
      // ON THE SKY, not on the app's page colour. This page is a takeover — it
      // is nearly all panel, with no diorama behind it — so a background that
      // followed the theme put pale panels on a pale page in light mode and the
      // whole match went flat. The same sky the Play screen stands under, at the
      // same tier, so kicking off is not arriving somewhere else.
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: skyGradient(
            brightness: Theme.of(context).brightness,
            tier: ref.watch(stadiumTierProvider),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Scoreboard(
                key: const ValueKey('match-scoreboard'),
                left: home ? us : them,
                right: home ? them : us,
                // The board is laid out HOME SIDE LEFT and the tally is ours
                // and theirs — see `MatchFrame`. Handing it the tally straight
                // put our score under their name for every away fixture.
                leftGoals: home ? f.ourGoals : f.theirGoals,
                rightGoals: home ? f.theirGoals : f.ourGoals,
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
              // **DIRECTLY UNDER THE PITCH IT ACTS ON** — the JS's own band
              // order, and the reason for it: a control for the thing above it
              // reads as belonging to it.
              if (!f.finished)
                _TacticStrip(
                  active: _strategy,
                  onPick: applyStrategy,
                  cooldown: _tacticCooldown,
                ),
              // **THE LIVE QUEST TRACKER.** `partialMatchResult` and
              // `liveMatchQuestStatus` are ported, documented and tested, and
              // had no caller — so the three quests a match is being played FOR
              // were invisible until the whistle told the player how they did.
              if (questRows.isNotEmpty)
                _BodyTabs(
                  onQuests: _onQuests,
                  onPick: (q) => setState(() => _onQuests = q),
                ),
              if (_onQuests && questRows.isNotEmpty)
                Expanded(
                  child: _LiveQuests(
                    rows: questRows,
                    partial: partialMatchResult(
                      widget.result,
                      [
                        for (final e in raw is List ? raw : const [])
                          if (e is Map<String, dynamic> &&
                              ((e['minute'] as num?) ?? 0) <= f.minute)
                            e,
                      ],
                      f.minute,
                      _end,
                    ),
                    state: ref.read(gameProvider).state,
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('match-feed'),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    // NEWEST FIRST. `reverse: true` put index 0 at the bottom, so the
                    // newest line arrived at the foot of the list and everything
                    // worth reading was off the bottom of a long match. A line should
                    // arrive from ABOVE and push the rest down, which is the
                    // direction the feed actually grows.
                    itemCount: lines.length,
                    itemBuilder: (context, i) =>
                        _FeedLine(line: lines[lines.length - 1 - i]),
                  ),
                ),
              if (f.finished) _QuestOutcomes(result: widget.result),
              Padding(
                padding: const EdgeInsets.all(12),
                child: f.finished
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const ValueKey('match-close'),
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Text(_verdictLabel()),
                        ),
                      )
                    : Row(
                        children: [
                          OutlinedButton(
                            key: const ValueKey('match-speed'),
                            onPressed: toggleSpeed,
                            child: Text(_fast ? '2×' : '1×'),
                          ),
                          const SizedBox(width: 8),
                          // Subs before skip: one is a decision and the other is
                          // giving up on watching, and the one that takes a
                          // thought should not be the afterthought.
                          OutlinedButton(
                            key: const ValueKey('match-subs'),
                            onPressed: openSubs,
                            child: Text(t('match.subs')),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey('match-skip'),
                              onPressed: skipToEnd,
                              child: Text(t('common.skip')),
                            ),
                          ),
                        ],
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

/// Commentary, or the three quests this match is being played for.
class _BodyTabs extends StatelessWidget {
  const _BodyTabs({required this.onQuests, required this.onPick});

  final bool onQuests;
  final void Function(bool) onPick;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    Widget tab(String label, bool quests, Key key) => Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(quests),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: onQuests == quests ? kit.accentBright : kit.border,
                width: onQuests == quests ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: onQuests == quests ? kit.accentBright : kit.textMuted,
            ),
          ),
        ),
      ),
    );

    return Padding(
      key: const ValueKey('match-tabs'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          tab(t('match.tab.commentary'), false, const ValueKey('tab-feed')),
          tab(t('quests.title'), true, const ValueKey('tab-quests')),
        ],
      ),
    );
  }
}

/// The three quests, as they stand right now.
///
/// **Only two answers can be given early**, and that is `liveMatchQuestStatus`'s
/// whole design: something that HAPPENED cannot un-happen, and something that
/// can no longer happen is gone. Everything else is undecided — "win by two" is
/// not missed at 0-0 in the 89th — and putting a cross against a quest the
/// player then goes on to win is worse than saying nothing.
class _LiveQuests extends StatelessWidget {
  const _LiveQuests({
    required this.rows,
    required this.partial,
    required this.state,
  });

  final List<QuestRow> rows;
  final Map<String, dynamic> partial;
  final Map<String, dynamic>? state;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ListView(
      key: const ValueKey('match-live-quests'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      children: [
        for (final row in rows)
          () {
            final def = questBank.where((q) => q.id == row.id).firstOrNull;
            final status = liveMatchQuestStatus(
              state,
              def,
              row.target.toInt(),
              partial,
            );
            final (mark, colour) = switch (status) {
              QuestLive.done => ('✓', kit.accentBright),
              QuestLive.missed => ('✕', Colors.redAccent),
              QuestLive.pending => ('·', kit.textMuted),
            };
            return Padding(
              key: ValueKey('live-quest-${row.id}'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      mark,
                      key: ValueKey('live-quest-mark-${row.id}'),
                      style: TextStyle(
                        color: colour,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: status == QuestLive.missed
                            ? kit.textMuted
                            : null,
                        decoration: status == QuestLive.missed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

/// How long the strip stays shut after a change.
///
/// The JS's second, and its reason: the remainder is genuinely re-rolled on
/// every switch, so a strummed strip is a player re-rolling the result until
/// they like it.
const Duration tacticCooldown = Duration(seconds: 1);

/// The order the five are offered in. The JS's own, and it is not alphabetical
/// or by strength: Balanced first because it is the neutral one, then the two
/// extremes, then the two reads.
const List<String> strategyStrip = [
  'balanced',
  'allOutAttack',
  'parkTheBus',
  'counterAttack',
  'highPress',
];

/// Five buttons and a cooldown bar.
///
/// **Every tactic carries its own hue, lit or not.** The strip reads as five
/// distinct options rather than one lit cell in a row of grey — and the icons
/// are 14px line art on a mid-tone panel, so dimming the inactive ones on top
/// of that took them below readable, which is all the hue had to work with.
///
/// The ATK/DEF deltas are deliberately left off: this is a quick switcher, and
/// the full breakdown lives on the Squad page.
class _TacticStrip extends StatelessWidget {
  const _TacticStrip({
    required this.active,
    required this.onPick,
    required this.cooldown,
  });

  final String active;
  final void Function(String) onPick;
  final bool cooldown;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('match-tactics'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: Row(
            children: [
              for (final id in strategyStrip)
                Expanded(
                  child: _TacticButton(
                    id: id,
                    active: id == active,
                    last: id == strategyStrip.last,
                    enabled: !cooldown,
                    onTap: () => onPick(id),
                  ),
                ),
            ],
          ),
        ),
        // Only while it is shut. A bar that is always there, empty, is a
        // control the player has to learn to ignore.
        SizedBox(
          height: 2,
          child: cooldown
              ? TweenAnimationBuilder<double>(
                  key: const ValueKey('match-tactic-cooldown'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: tacticCooldown,
                  curve: Curves.linear,
                  builder: (context, t, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: t,
                      child: ColoredBox(color: kit.accentBright),
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _TacticButton extends StatelessWidget {
  const _TacticButton({
    required this.id,
    required this.active,
    required this.last,
    required this.enabled,
    required this.onTap,
  });

  final String id;
  final bool active, last, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final hue = tacticColor(context, id);
    return GestureDetector(
      key: ValueKey('match-tactic-$id'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? hue : kit.surface2,
          border: last ? null : Border(right: BorderSide(color: kit.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameIcon(
                tacticIconName(id),
                size: 17,
                color: active ? tacticInk(context, id) : hue,
              ),
              const SizedBox(height: 1),
              Text(
                t('strategy.$id.short'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  color: active ? tacticInk(context, id) : kit.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
  const _FeedLine({required this.line});

  final FeedLine line;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final isGoal = line.type == 'goal';
    // **WHICH events earn a line, and what each says, is `feedOf`.** This used
    // to fall through to printing `event.type` — so a corner read as the word
    // "corner", a chance as "chance" and full time as "fulltime": three raw,
    // untranslated strings from the engine on the one screen a player watches
    // for ninety minutes.
    //
    // `tPoolStable` rather than `tPool`: a goal has nine ways of being
    // described and the feed rebuilds on every tick of the clock, so an
    // unseeded pick would reroll the sentence under the reader.
    final text = tPoolStable(line.key, line.seed, line.params);
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "${line.minute}'",
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
