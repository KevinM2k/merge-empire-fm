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
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart' show PlayerEnergy;
import 'package:merge_empire_fc/data/players.dart' show getPlayerDef;
import 'package:merge_empire_fc/engine/match_coach.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart'
    show isProMode;
import 'package:merge_empire_fc/engine/tactic_coach.dart'
    show baselineInjuryRisk, injuryCostPoints;
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';
import 'package:merge_empire_fc/services/sound_service.dart';
import 'package:merge_empire_fc/state/card_instance.dart' show CardInstance;
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart'
    show pitchAspect;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/screens/match/goal_replay.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart'
    show reSimulateRemainder;
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart'
    show coachSuggestedTacticProvider;
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show leagueTableProvider, managerLookProvider;
import 'package:merge_empire_fc/engine/league_table.dart' show LeagueRow;
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart'
    show PosChip, PosStanding;
import 'package:merge_empire_fc/engine/lineup_engine.dart'
    show refillLineupFromBench;
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/momentum_arrow.dart';
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart'
    show pitchSlotsProvider;
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart'
    show cardById;
import 'package:merge_empire_fc/ui/screens/settings_controls.dart'
    show settingPick;
import 'package:merge_empire_fc/ui/screens/match/dugout_cam.dart';
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/data/manager_mood.dart' show Gesture, Mood;
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart'
    show CoachBubbleTail, coachPortrait, coachTailSize;
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart' show PlayerFace;
import 'package:merge_empire_fc/ui/theme/sky.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';
import 'package:merge_empire_fc/util/stat_display.dart';

/// One dugout-cam shot, as the screen has decided it. Everything the widget
/// needs and nothing it can work out for itself.
typedef _CamShot = ({
  Mood mood,
  Gesture? gesture,
  CamTone tone,
  String? minute,
  CamVariant variant,
});

/// **ONE INSET AND ONE GAP for every band on this screen.**
///
/// It was 13, 12 and 14 down the page with gaps of 6, 7 and 8 between them, and
/// a page of panels at four insets reads as unfinished before anything on it is
/// read — which is exactly how it was reported. The radius belongs to
/// `GlassPanel`, so nothing here draws its own.
const double matchInset = 13;
const double matchGap = 8;

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

  /// What Colin is saying, and when he last said anything.
  ///
  /// **He had NOTHING to say for the whole match.** Twenty-four pooled
  /// `coach.match.*` strings, translated ten times over, and not one caller —
  /// see `engine/match_coach.dart`.
  String? _coachLine;
  int _lastCoachMinute = -1;
  String? _lastCoachSuggestion;
  Timer? _coachTimer;

  /// Whose goal the clip on the pitch is, when it is one of ours and the save
  /// still holds him. Null for everything else.
  String? _clipScorerId;

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

  /// The arrow's own figure, handed to the idle pitch so the shape it holds and
  /// the arrow over it are the same reading rather than two.
  final ValueNotifier<double> _momentum = ValueNotifier<double>(0);

  /// Which of the two the body is showing.
  /// Which of the three the body is showing.
  ///
  /// The STATISTICS used to be the stage's resting state, which is what made
  /// the pitch flip in and out; they are a tab now. `match.tab.stats` was in
  /// all ten catalogues with nothing able to reach it.

  /// Double speed, starting from the player's own setting.
  ///
  /// **It is a live control, not a preference read once.** The setting decides
  /// how a match OPENS; the button is for the moment ten minutes in when the
  /// manager decides they have seen enough of this one. It does not skip
  /// anything — a match that skips events is a match whose story the player did
  /// not get — it just halves the wait.
  late bool _fast = widget.fast;

  /// Where the two clubs stood when the whistle went.
  ///
  /// **A SNAPSHOT, not a watch.** `finalizeMatchOutcome` runs at full time with
  /// this screen still up, so a live table would move the chips under the player
  /// at the final whistle — and a fixture card describes the fixture as it was
  /// played. Null for either side that has no table row: a cup tie has no table,
  /// and a chip with nothing in it draws nothing.
  late final ({PosStanding ours, PosStanding theirs}) _standings;

  ({PosStanding ours, PosStanding theirs}) _standingsAtKickoff() {
    final table = ref.read(leagueTableProvider);
    final opponent = widget.result['opponentName'];
    PosStanding find(bool Function(LeagueRow row) match) {
      final i = table.indexWhere(match);
      return i < 0
          ? (position: null, delta: 0)
          : (position: i + 1, delta: table[i].posDelta ?? 0);
    }

    return (
      ours: find((r) => r.isPlayer),
      theirs: find((r) => !r.isPlayer && r.name == opponent),
    );
  }

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

  /// Test seam: a passage is on the pitch right now.
  bool get clipPlaying => _clip != null;

  /// The match as the player has been TOLD it, which is not the same question as
  /// where the clock is.
  ///
  /// **The scoreboard used to give the goal away before the 2D pitch played
  /// it.** The minute ticked, `frameAt` counted the goal into the tally and the
  /// feed, and the cutaway then acted out a move whose ending had already been
  /// printed above it — so the number explained the animation instead of the
  /// animation explaining the number, and the one moment of suspense the match
  /// has was spent before it started.
  ///
  /// A cutaway is a RETELLING of a minute, and until it has been told, its
  /// events have not happened as far as the screen is concerned. So the tally
  /// and the feed are counted to the minute BEFORE the one being retold, while
  /// [MatchFrame.minute] and [MatchFrame.finished] stay on the clock: a chance
  /// genuinely is happening at 22, and a clock that ran backwards under a clip
  /// would be a second bug.
  ///
  /// It holds for a chance and an injury too, and it should: "forces a save" is
  /// no better read before you watch the save than after.
  MatchFrame get frame {
    final told = frameAt(
      widget.result,
      _clip == null ? _minute : _minute - 1,
      timeline: _timeline,
    );
    return (
      minute: _minute,
      ourGoals: told.ourGoals,
      theirGoals: told.theirGoals,
      shown: told.shown,
      finished: _minute >= _end,
    );
  }

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
    _standings = _standingsAtKickoff();
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
    // **THE ONE SCREEN THE PLAYER WATCHES WITHOUT TOUCHING**, which is the JS's
    // own reason for taking a wake lock here and nowhere else: everything else
    // in the game takes taps every few seconds, so only this one can be blacked
    // out mid-way by the phone's sleep timer.
    unawaited(wakeLock.acquire());
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
    // A goal the pitch is retelling has not been TOLD yet — the cutaway's own
    // `onDone` cuts to him instead, so his reaction lands after the move
    // rather than over it.
    if (_clip == null) _dugoutCamFor(_minute);
    // Half time is a TEAM TALK, so it jumps the cadence; everything else waits
    // its turn.
    _maybeCoach(
      force: _timeline.any((e) => e.minute == _minute && e.type == 'halftime'),
    );
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
          // Ours only: the opponent's physio is not our problem, and there is
          // no hole in OUR side to cover.
          if (ours) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _onInjuryShown(),
            );
          }
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

  // ── The dugout cam ───────────────────────────────────────────────────────
  //
  // A broadcast cut-in on the MANAGER, reacting to what just happened. When it
  // may fire lives in `data/dugout_cam_policy.dart` and what it looks like in
  // `dugout_cam.dart`; everything here is about whether the screen is free to
  // show it.
  //
  // **The clock does NOT stop for it.** A cutaway is a retelling and holds the
  // minute; this is a reaction to a minute already told, and a match that
  // paused for the manager's face would be a match watching him instead of
  // itself.

  /// The shot currently up, or null.
  _CamShot? _cam;

  /// The minute the last cut-in went up, and how many GOAL cut-ins have been
  /// spent. Full time is exempt from both.
  int? _lastCamMinute;
  int _camGoalCuts = 0;

  /// Set by the goal that wins it late, and it has to be captured AS IT
  /// HAPPENS: by full time a 1-0 is just a 1-0, and the whistle is where the
  /// rush actually lands.
  bool _lateWinner = false;

  /// The shot when it is the full-time one, which is the only variant the
  /// feed carries. The float lives over the pitch, and mounting the same
  /// record in both places would put two of him on screen at once.
  _CamShot? get _inlineCam => _cam?.variant == CamVariant.inline ? _cam : null;

  /// Test seams.
  bool get camUp => _cam != null;
  int get camGoalCuts => _camGoalCuts;

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
        // **AT HOME WE ATTACK RIGHT, AWAY WE ATTACK LEFT.** It was pinned to
        // "we defend the left end" for every fixture, so on the road the 2D
        // pitch played our chances running the opposite way from the arrow and
        // from the scoreboard, which reads home side left.
        ourSideLeft: widget.result['isHome'] == true,
        ours: ours,
        // Seeded off the minute so the same match replays the same chances —
        // and BRACKETED, because `??` binds looser than `+`: without them the
        // minute was only added when the result carried no seed at all, so
        // every chance in a match drew the same sequence.
        seed: ((widget.result['seed'] as num?)?.toInt() ?? 0) + event.minute,
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
      // **THE GRASS BELONGS TO THE CHANCE.** The float shot sits bottom-right
      // OVER the pitch, which is fine while nothing is happening on it and is
      // exactly wrong the moment something is — a goal's cut-in was still up
      // when the next chance began, so the move it covered was one the player
      // never saw. He gives way rather than sharing it; the shot he loses is a
      // reaction to something already over, and the thing replacing it is
      // happening now.
      _closeDugoutCam();
      _clip = clip;
      // Ours only: the engine picks scorers from OUR squad, so a face for one
      // of theirs cannot be drawn.
      _clipScorerId = event.type == 'goal' && ours ? event.scorerId : null;
      return;
    }
  }

  /// How long a bubble stays up, in real time. The JS's 11 seconds.
  static const Duration _coachDwell = Duration(seconds: 11);

  /// Let Colin have his say, if he has one and the cadence allows it.
  ///
  /// **Casual only.** Pro mode buys the numbers and gives up the advice, which
  /// is the same bargain the subs panel strikes — see `_coachHelpOn` in the JS.
  void _maybeCoach({bool force = false}) {
    final state = ref.read(gameProvider).state;
    if (state == null || isProMode(state)) return;
    final f = frame;
    if (f.finished) return;
    final margin = f.ourGoals - f.theirGoals;
    num asNum(Object? v) => v is num ? v : 50;
    final healthy = _healthyCards(state);
    final theirAtk = asNum(widget.result['effOppAttackRating']).toDouble();
    final theirDef = asNum(widget.result['effOppDefenceRating']).toDouble();
    final suggestion = matchCoachSuggestion(
      ourAttack: asNum(widget.result['ourAttackRating']).toDouble(),
      ourDefence: asNum(widget.result['ourDefenceRating']).toDouble(),
      theirAttack: theirAtk,
      theirDefence: theirDef,
      activeStrategy: _strategy,
      minute: _minute,
      duration: _end,
      margin: margin,
      benchCover: (healthy - 11).toDouble(),
      injuryRisk: baselineInjuryRisk(state),
      injuryCost: injuryCostPoints(state, theirAtk, theirDef),
      oppAttackRatio: (widget.result['oppAttackRatio'] as num?)?.toDouble(),
    );
    if (!coachShouldSpeak(
      minute: _minute,
      lastSpokeMinute: _lastCoachMinute,
      activeStrategy: _strategy,
      suggestion: suggestion,
      lastSuggestion: _lastCoachSuggestion,
      force: force,
    )) {
      _lastCoachSuggestion = suggestion;
      return;
    }
    _lastCoachSuggestion = suggestion;
    _lastCoachMinute = _minute;
    _say(
      matchCoachOpinion(
        halftime: force,
        margin: margin,
        minute: _minute,
        activeStrategy: _strategy,
        // The minute he said it, so the pooled picks hold while it is up.
        seed: 'coach-$_minute',
        suggestion: suggestion,
      ),
    );
  }

  /// Bodies who could actually take the field.
  int _healthyCards(Map<String, dynamic> state) {
    final cells = (state['grid'] as Map<String, dynamic>?)?['cells'];
    if (cells is! List) return 0;
    var n = 0;
    for (final raw in cells) {
      final card = CardInstance.from(raw);
      if (card == null || card.injured || !card.isSelectable) continue;
      n++;
    }
    return n;
  }

  /// Put a line in his mouth, and take it away again after [_coachDwell].
  void _say(String line) {
    _coachTimer?.cancel();
    setState(() => _coachLine = line);
    _coachTimer = Timer(_coachDwell, () {
      if (mounted) setState(() => _coachLine = null);
    });
  }

  /// Cut to the manager, if the screen and the rules both allow it.
  ///
  /// [minute] is the minute being reacted TO, which for a goal shown behind a
  /// cutaway is the clip's minute rather than wherever the clock has got to.
  void _maybeDugoutCam(CamTrigger trigger, int minute) {
    // The whistle always takes the camera back. A goal in the 90th leaves its
    // floating window on screen into full time, where it would hang over the
    // result while the full-time shot is printed inside the feed — two of him
    // at once, and the second is the one that matters.
    if (trigger == CamTrigger.fullTime) _closeDugoutCam();
    if (_cam != null) return;
    // Full time is exempt, as it is from the gap and the budget alike. A goal
    // cut-in must not land on top of a 2D clip, but the full-time shot is laid
    // INTO the feed rather than over the pitch, so a clip cannot be in its way.
    // Left un-exempted this is the one rule that could silently drop the shot
    // the whole feature exists for.
    if (trigger != CamTrigger.fullTime && _clip != null) return;
    if (!shouldCutIn(
      trigger: trigger,
      minute: minute,
      lastCutMinute: _lastCamMinute,
      goalCuts: _camGoalCuts,
      settings: {
        'cutawayOurTeam': ref.read(settingPick<bool>('cutawayOurTeam', true)),
        'cutawayOpponent': ref.read(settingPick<bool>('cutawayOpponent', true)),
      },
      reducedFx: MediaQuery.of(context).disableAnimations,
    )) {
      return;
    }

    final fullTime = trigger == CamTrigger.fullTime;
    final f = frame;
    final swing = _swing();
    // Null on the fixtures the engine does not rate, and `?? 0` would quietly
    // turn a missing opponent into a fifty-point mismatch.
    final ours = (widget.result['squadRating'] as num?)?.toDouble();
    final theirs = (widget.result['opponentRating'] as num?)?.toDouble();
    final mood = camMood(
      trigger: trigger,
      ourGoals: f.ourGoals,
      theirGoals: f.theirGoals,
      trophiesEarned: (widget.result['trophiesEarned'] as num?) ?? 0,
      lateWinner: _lateWinner,
      ratingGap: ours != null && theirs != null ? theirs - ours : 0,
      // A cup tie is always at home, so "at home" carries none of the meaning
      // it does in the league — better to say nothing.
      isHome: widget.result['isCup'] == true
          ? null
          : widget.result['isHome'] == true,
      led: swing.led,
      trailed: swing.trailed,
    );
    final gesture = camGesture(
      mood,
      null,
      ref.read(gameProvider).state,
      fullTime,
    );

    // A goal deep in stoppage time starts a window the whistle would cut in
    // half, and the full-time shot — about the same goal, and the better
    // picture — is seconds away. So the late goal gives up the camera rather
    // than sharing it. REAL milliseconds off the live tick rate: the same 88th
    // minute is twice as close at 2×. Checked BEFORE the counters below,
    // because a cut-in that never happened must not spend one of the three or
    // start the gap.
    if (!fullTime) {
      final left = minuteDuration(fast: _fast) * (_end - minute).clamp(0, _end);
      if (!camFitsBeforeFullTime(
        Duration(milliseconds: gesture?.ms ?? 0),
        left,
      )) {
        return;
      }
    }

    final margin = f.ourGoals - f.theirGoals;
    setState(() {
      _lastCamMinute = minute;
      if (!fullTime) _camGoalCuts++;
      _cam = (
        mood: mood,
        gesture: gesture,
        tone: margin > 0
            ? CamTone.good
            : margin < 0
            ? CamTone.bad
            : CamTone.flat,
        // Full time is a reaction to the whole match, not to a minute of it.
        minute: fullTime ? null : "$minute'",
        variant: fullTime ? CamVariant.inline : CamVariant.float,
      );
    });
  }

  void _closeDugoutCam() {
    if (_cam == null) return;
    setState(() => _cam = null);
  }

  /// Whether the match has been in front and behind, off the events already
  /// SHOWN.
  ///
  /// A point is only worth what it was taken against, so a full-time draw needs
  /// to know which way the night swung — otherwise every 2-2 gets the same
  /// shrug. Folded over the shown list rather than tracked as the clock runs,
  /// so a tactic change that re-simulates the remainder cannot leave a stale
  /// flag behind.
  ({bool led, bool trailed}) _swing() {
    var ours = 0;
    var theirs = 0;
    var led = false;
    var trailed = false;
    for (final event in frame.shown) {
      if (event.type != 'goal') continue;
      if (event.team != 'away') {
        ours++;
      } else {
        theirs++;
      }
      if (ours > theirs) led = true;
      if (theirs > ours) trailed = true;
    }
    return (led: led, trailed: trailed);
  }

  /// The goals landing on [minute], as the camera sees them: ours or theirs.
  ///
  /// Called when the minute has been TOLD, which for a goal behind a cutaway is
  /// when the clip ends — his reaction to a goal must not arrive before the
  /// move that scored it, for the same reason the scoreboard's does not.
  void _dugoutCamFor(int minute) {
    for (final event in _timeline) {
      if (event.minute != minute || event.type != 'goal') continue;
      final ours = event.team != 'away';
      if (ours) {
        // Captured as it happens: by full time a 1-0 is just a 1-0.
        final f = frame;
        if (isLateWinner(
          minute: minute,
          duration: _end,
          ourGoals: f.ourGoals,
          theirGoals: f.theirGoals,
        )) {
          _lateWinner = true;
        }
      }
      _maybeDugoutCam(
        ours ? CamTrigger.goalFor : CamTrigger.goalAgainst,
        minute,
      );
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
    // **NO FULL-TIME SHOT HERE ANY MORE.** It was the payoff the whole feature
    // was for, laid into the head of the feed — and this screen now leaves at
    // the whistle for the summary, which opens ON him. Two of him a second
    // apart is one too many, and the second is the one with the room.
    _closeDugoutCam();
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
    // **AND THEN IT LEAVES.** Full time on the commentary page is a screen with
    // nothing left to say: the tactic strip has gone, the clock has stopped and
    // the payoff is on the summary. Long enough for the whistle and the sting to
    // land first. `maybePop` rather than `pop`, because in a test this screen is
    // the root route and there is nothing under it to go back to.
    _cue(const Duration(milliseconds: 1400), _leaveFullTime);
  }

  /// Leave the commentary page — but only if it is still the page on top.
  ///
  /// **`maybePop` pops whatever is topmost**, and at full time that need not be
  /// this screen: a replay opened on the goal that had just gone in is a route
  /// the PLAYER put there, and the whistle's own timer would close it and leave
  /// the finished match sitting behind it. The replay asks again on its way
  /// out, so the screen still leaves — a beat later, when the player is done.
  void _leaveFullTime() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    Navigator.of(context).maybePop();
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
    _coachTimer?.cancel();
    _momentum.dispose();
    for (final cue in _cues) {
      cue.cancel();
    }
    _cues.clear();
    // Back to the menu bed. In `dispose` rather than `deactivate` because the
    // match popup that follows this screen is still the match as far as the
    // player is concerned.
    unawaited(_sound.setMusicTrack(MusicBed.menu));
    unawaited(wakeLock.release());
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
  ///
  /// [openOn] arrives already picked — the injury case, where the sim has
  /// vacated a slot and the manager only has to name a replacement.
  Future<void> openSubs({String? openOn}) async {
    if (frame.finished || _paused) return;
    setState(() => _paused = true);
    await showSubsPanel(
      context,
      used: _subsUsed,
      withdrawn: _withdrawn,
      onSub: _onSub,
      openOn: openOn,
    );
    if (mounted) setState(() => _paused = false);
  }

  /// The statistics, on demand, from the board's own chart button.
  ///
  /// **The tab bar they used to live behind has gone** — a full row of chrome on
  /// a screen with none to spare, serving a panel nobody watches while a match
  /// is running. Deleting them outright would have stranded `MatchStatboard`
  /// and `match.tab.stats`, which is precisely the fault this repo's sweeps
  /// exist to find, so they moved rather than went.
  ///
  /// **It does NOT pause the match**, which the subs panel does: subs are a
  /// decision the manager makes about what happens next, and this is a look at
  /// what has already happened. Stopping the clock to read a number would make
  /// checking possession a way to buy time.
  Future<void> _showStats(LiveStats stats, bool home) => showBottomSheetPopup<void>(
    context,
    heightFraction: 0.6,
    child: SingleChildScrollView(
      key: const ValueKey('match-stats-sheet'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: MatchStatboard(stats: stats, isHome: home),
    ),
  );

  /// **AN INJURY STOPS THE MATCH AND PUTS YOU IN FRONT OF THE BENCH.**
  ///
  /// Nobody is ever subbed on automatically — that is the manager's call — so
  /// the alternative is a side quietly finishing with ten men because the
  /// player was reading the feed. The source opens the panel itself for exactly
  /// this reason.
  ///
  /// The slot is found rather than carried: the port's injury event has the
  /// casualty's NAME and nothing else, and the sim vacates their slot before
  /// the screen opens. One hole is the ordinary case and it is preselected;
  /// with two the manager chooses, which is the honest answer rather than a
  /// guess.
  void _onInjuryShown() {
    if (_paused || frame.finished) return;
    if (_subsUsed >= PlayerEnergy.maxSubs) return;
    final holes = [
      for (final slot in ref.read(pitchSlotsProvider))
        if (slot.cardInstanceId == null) slot.slotId,
    ];
    if (holes.isEmpty) return;
    unawaited(openSubs(openOn: holes.length == 1 ? holes.first : null));
  }

  /// Everyone taken off this match.
  ///
  /// **On the SCREEN, not the panel**, and that is the whole of the fix: the
  /// panel used to own this while `used` was passed in from here, so closing and
  /// reopening it forgot who had been withdrawn and two taps put a substituted
  /// man back on the pitch. It belongs with [_kickoffLineup] — both are facts
  /// about the match rather than about the sheet that happens to be open.
  final Set<String> _withdrawn = <String>{};

  /// Record a change the panel has already written to the save.
  ///
  /// **What the quests read is stamped here.** `subsUsed` and `subbedOnIds` are
  /// things the MANAGER did rather than things the dice did, which is the whole
  /// appeal of asking for them — and until there was a panel neither could move
  /// off its kickoff value, so `match_use_subs` and `match_sub_scores` were two
  /// quests that could not advance.
  void _onSub(SubMade sub) {
    _subsUsed++;
    // Filling a hole withdraws nobody, so there is nothing to remember.
    if (sub.offId != null) _withdrawn.add(sub.offId!);
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
        goal: null,
        // The man coming ON is who the line is about, and the row can draw him.
        aboutId: sub.onId,
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
        goal: null,
        aboutId: null,
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
    // Read once and used twice — by the arrow on the pitch and by the statistics
    // sheet, which must not be able to disagree about the same match.
    final stats = liveStatsFor(
      frame: f,
      result: widget.result,
      isHome: home,
      // The tactic the side went out in. The sim has already run, so it cannot
      // change mid-replay — which is why it is read once off the result rather
      // than watched.
      strategyId: '${widget.result['strategyId'] ?? 'balanced'}',
    );
    final events = feedOf(f.shown, ourName: us, theirName: them, isHome: home);
    // **ONE reading, two things drawing it.** The arrow and the idle pitch's
    // shape are the same figure; handed over rather than computed twice, so
    // they cannot drift apart.
    _momentum.value = momentumBias(
      dangerHome: stats.dangerHome,
      isHome: home,
    );
    // **THE LIVE QUEST TRACKER IS GONE FROM THIS SCREEN, deliberately.** The
    // three quests auto-pay at the whistle and the summary reports all three —
    // winners and misses — so a running count here bought a tab bar's worth of
    // height to tell the player something nobody can act on mid-match.
    // `partialMatchResult` and `liveMatchQuestStatus` keep their caller in the
    // summary's own track; nothing was stranded by this.

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
          child: Stack(
            children: [
              Column(
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
                    result: widget.result,
                    isHome: home,
                    standings: _standings,
                    minute: f.minute,
                    finished: f.finished,
                    onStats: () => _showStats(stats, home),
                    // **Localised HERE, not in the engine.** The result
                    // map is stamped by `match_orchestration`, whose fields
                    // the parity harness compares against the JS's — so
                    // `divisionName` stays the English one there and the
                    // screen resolves it. A CUP tie puts its own already-
                    // localised, decorated string in that field under a cup
                    // id, which has no `division.` key, so it falls straight
                    // back to what the launcher built.
                    label:
                        '${tName('division', {
                          'id': widget.result['divisionId'],
                          'name': widget.result['divisionName'] ?? '',
                        })} · '
                        '${t(home ? 'play.home' : 'play.away')}',
                  ),
                  // THE STAGE: one band, fixed for the whole match, holding the
                  // pitch's aspect. At rest it shows the stat board; a chance cuts in
                  // ON TOP of it at the same inset and radius. The port mounted the
                  // pitch only for a chance and took it away after, so the band itself
                  // appeared and vanished — which is what made the pitch look like it
                  // was flickering and jumping about.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      matchInset,
                      matchGap,
                      matchInset,
                      matchGap,
                    ),
                    child: ConstrainedBox(
                      // Capped: the pitch is landscape and at its natural aspect would
                      // take a third of a tall phone and all of a short one.
                      //
                      // 0.28 rather than 0.3 since the board took a standings band:
                      // at full time on a 600pt screen the feed is down to single
                      // figures, and the pitch is the one band here that is a
                      // fraction of the screen rather than a thing being read.
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.28,
                      ),
                      child: AspectRatio(
                        aspectRatio: pitchAspect,
                        child: Stack(
                          key: const ValueKey('match-stage'),
                          fit: StackFit.expand,
                          children: [
                            // **THE PITCH IS ALWAYS THERE.** The band never
                            // moved, but what was IN it flipped between a
                            // football pitch and a table of numbers every few
                            // minutes, which is the jarring bit: the stage was
                            // the statistics at rest and the pitch only for a
                            // chance. It is one pitch for the whole match now,
                            // a clip cuts in on the same grass, and the
                            // statistics have a tab of their own. `CutawayStage`
                            // has drawn the idle markings all along — nothing
                            // was mounting it.
                            CutawayStage(
                              clip: _clip,
                              // **The match, between the chances.** The stage
                              // keeps twenty-two bodies on the grass and slides
                              // their shape with the same figure the arrow
                              // reads, so the two cannot disagree and a clip
                              // arrives out of a game rather than out of an
                              // empty field.
                              momentum: _momentum,
                              attackingRight: home,
                              // **THE SCORER, ON HIS OWN TOUCHLINE.** He arrives
                              // with the VERDICT, not with the clip — shown from
                              // the first beat he would give away that the ball
                              // was going in.
                              scorer: _scorerBadge(),
                              scorerFromLeft: home,
                              onDone: (_) {
                                if (!mounted) return;
                                final told = _clippedMinute;
                                setState(() => _clip = null);
                                // Now it has been told, he can react to it.
                                _dugoutCamFor(told);
                              },
                            ),
                            // Between chances: which way the game is going, on
                            // the pitch it is going on. Off while a clip runs —
                            // there is a real move on the grass to watch.
                            if (_clip == null)
                              MomentumArrow(
                                bias: momentumBias(
                                  dangerHome: stats.dangerHome,
                                  isHome: home,
                                ),
                                attackingRight: home,
                                // Shades of the TURF, not of the kit: a solid
                                // mark on the grass rather than a tint over it.
                                ours: momentumOurs,
                                theirs: momentumTheirs,
                              ),
                            // **OVER THE PITCH, bottom right**, which is where a
                            // broadcast puts a cut-in and the one corner of this
                            // band that carries no statistic. A cutaway owns the
                            // stage while it plays and the rules above keep the
                            // two off it at once.
                            if (_cam case final shot?
                                when shot.variant == CamVariant.float)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: LayoutBuilder(
                                      builder: (context, box) => SizedBox(
                                        width: (box.maxWidth * camFloatFraction)
                                            .clamp(
                                              camFloatMinWidth,
                                              camFloatMaxWidth,
                                            )
                                            .clamp(0.0, box.maxWidth),
                                        child: _dugoutCam(shot),
                                      ),
                                    ),
                                  ),
                                ),
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
                  // **THE COMMENTARY IS IN A BOX.** The tabs and the feed sat
                  // loose on the sky gradient — the one band on the screen with no
                  // surface under it, on a page where the scoreboard, the stage and
                  // the tactic strip are all panels. It read as the background
                  // having text on it rather than as a thing being read.
                  // **THE TAB BAR HAS GONE, and the commentary is what it
                  // paid for.** It was a full row of chrome serving two panels
                  // nobody watches during a match: the QUESTS auto-pay at the
                  // whistle and are reported on the summary, which is where the
                  // money is, and the STATISTICS are behind the board's own
                  // chart button now. What is left in this box is the one thing
                  // on the screen a player actually reads, in the whole box.
                  //
                  // **And it is a `GlassPanel`**, which is what every other
                  // surface on this screen and on the summary is. It was a
                  // hand-rolled `DecoratedBox` with its own colour, radius and
                  // border — one pane of glass and one painted box, side by
                  // side, on a page whose backdrop is a sky.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        matchInset,
                        0,
                        matchInset,
                        matchGap,
                      ),
                      child: GlassPanel(
                        density: GlassDensity.deep,
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                        child: Column(
                            children: [
                              Expanded(
                                  child: ListView.builder(
                                    key: const ValueKey('match-feed'),
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      12,
                                    ),
                                    // NEWEST FIRST. `reverse: true` put index 0 at the bottom, so the
                                    // newest line arrived at the foot of the list and everything
                                    // worth reading was off the bottom of a long match. A line should
                                    // arrive from ABOVE and push the rest down, which is the
                                    // direction the feed actually grows.
                                    // **THE FULL-TIME SHOT IS THE HEAD OF THE FEED**, above
                                    // the newest line, which is where a broadcast cuts to the
                                    // bench before the graphic. It goes here rather than in
                                    // the corner of the pitch for two reasons: at the whistle
                                    // the band above is the final statistics, which is the one
                                    // thing on the page a manager actually reads; and this is
                                    // the better shot anyway — a reaction still printed beside
                                    // the result. It also SCROLLS, so it costs the feed no
                                    // permanent height on a short screen.
                                    itemCount:
                                        lines.length +
                                        (_inlineCam == null ? 0 : 1),
                                    itemBuilder: (context, i) {
                                      final shot = _inlineCam;
                                      if (shot != null) {
                                        if (i == 0) {
                                          return Padding(
                                            // Air above it: the shot sat flush
                                            // against the top of the feed with
                                            // the tab strip's rule cutting into
                                            // its frame.
                                            padding: const EdgeInsets.only(
                                              top: 12,
                                              bottom: 10,
                                            ),
                                            child: Center(
                                              child: LayoutBuilder(
                                                builder: (context, box) => SizedBox(
                                                  width:
                                                      (box.maxWidth *
                                                              camInlineFraction)
                                                          .clamp(
                                                            camInlineMinWidth,
                                                            camInlineMaxWidth,
                                                          )
                                                          .clamp(
                                                            0.0,
                                                            box.maxWidth,
                                                          ),
                                                  child: _dugoutCam(shot),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return _feedLine(
                                          lines[lines.length - i],
                                          them,
                                        );
                                      }
                                      return _feedLine(
                                        lines[lines.length - 1 - i],
                                        them,
                                      );
                                    },
                                  ),
                              ),
                            ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    // **NO BUTTON AT FULL TIME.** The whistle already leaves
                    // this page on its own — see `_leaveFullTime`, 1.4s after
                    // the sting — so a full-width "VICTORY" button was a
                    // control for something that was going to happen anyway,
                    // holding a row of height on the one screen with none, and
                    // inviting a tap that raced the timer.
                    child: f.finished
                        ? const SizedBox.shrink()
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
              // **COLIN, ON THE TOUCHLINE.** Floating rather than a band of his
              // own: a strip that appears and disappears shoves the feed about,
              // which is the same fault the pitch had.
              //
              // **Higher, and bigger.** Reported as hard to see at the foot of
              // the screen — and the 26 Aug note already had the answer in it:
              // of the three ways to make him more visible, a bigger head was
              // the one never tried. The position stays a touchline, because
              // that is what he is standing on; what changes is that he is not
              // crowding the row of buttons any more and his face is a face.
              if (_coachLine case final line?)
                Positioned(
                  left: matchInset,
                  right: matchInset,
                  bottom: 82,
                  child: _CoachSay(key: ValueKey(line), text: line),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// One row of the feed, with a replay on it when there is one to play.
  ///
  /// The chip is offered only where a clip can actually be built — the same
  /// question `clipFor` answers for the live cut — so a goal the cutaway has no
  /// passage for shows no control rather than a control that does nothing.
  Widget _feedLine(FeedLine line, String them) {
    final goal = line.goal;
    final canReplay =
        goal != null && _replayClip(line.minute, ours: goal.ours) != null;
    return _FeedLine(
      line: line,
      state: ref.read(gameProvider).state,
      onReplay: !canReplay
          ? null
          : () => unawaited(
              replayGoal(
                line.minute,
                ours: goal.ours,
                // The head the card carries: the word for one of ours, their
                // name for one of theirs.
                title: goal.ours ? t('match.goal_card.title') : them,
              ),
            ),
    );
  }

  /// The scorer's face for the clip on the pitch, or null when there is nobody
  /// to name.
  Widget? _scorerBadge() => _scorerBadgeFor(_clipScorerId, _clippedMinute);

  /// The same badge for any goal, which is what a replay needs: it plays a
  /// minute the clock left behind, so the caption cannot come off the live one.
  Widget? _scorerBadgeFor(String? id, int? minute) {
    if (id == null || minute == null) return null;
    final card = cardById(ref.read(gameProvider).state, id);
    final def = getPlayerDef(card?.definitionId);
    if (card == null || def == null) return null;
    final kit = Theme.of(context).extension<KitTheme>()!;
    return _ScorerBadge(
      face: PlayerFace(
        position: def.position,
        tier: def.tier,
        variant: card.variant,
        size: 72,
        ring: kit.accentBright,
      ),
      // The SURNAME, as a broadcast caption gives it, and the minute it went
      // in. His full name would not fit under a 72px circle.
      caption: "${card.name(def.name).split(' ').last} $minute'",
    );
  }

  /// The goal that happened in [minute], ours or theirs, or null when the
  /// timeline has no such thing.
  TimelineEvent? _goalAt(int minute, {required bool ours}) {
    for (final event in _timeline) {
      if (event.type != 'goal' || event.minute != minute) continue;
      if ((event.team == 'home') != ours) continue;
      return event;
    }
    return null;
  }

  /// The clip a replay would play, or null when there is none to play.
  ///
  /// **The switches are not consulted, and neither is the gap.** Both exist to
  /// keep the screen from cutting away on its own; this is the player asking,
  /// and a control that refuses the thing it offers is worse than no control.
  CutawayClip? _replayClip(int minute, {required bool ours}) {
    final event = _goalAt(minute, ours: ours);
    if (event == null) return null;
    return clipFor(
      event,
      ourSideLeft: widget.result['isHome'] == true,
      ours: ours,
      // The same seed the live cut used, so the replay is the passage that was
      // watched rather than another one from the same table.
      seed: ((widget.result['seed'] as num?)?.toInt() ?? 0) + minute,
    );
  }

  /// What a replay of that goal would play. **A test seam**, and the same
  /// question the chip asks before it offers itself.
  CutawayClip? replayClipFor(int minute, {required bool ours}) =>
      _replayClip(minute, ours: ours);

  /// Play it again, holding the match while it is up.
  ///
  /// The same bargain the subs panel strikes: the clock stops, because coming
  /// back to a match that had run on without you is what a popup over a live
  /// game does if it does not.
  Future<void> replayGoal(
    int minute, {
    required bool ours,
    String title = '',
  }) async {
    if (_paused) return;
    final clip = _replayClip(minute, ours: ours);
    if (clip == null) return;
    final event = _goalAt(minute, ours: ours);
    setState(() => _paused = true);
    await showGoalReplay(
      context,
      clip: clip,
      minute: minute,
      title: title,
      ours: ours,
      scorer: ours ? _scorerBadgeFor(event?.scorerId, minute) : null,
      scorerFromLeft: widget.result['isHome'] == true,
    );
    if (!mounted) return;
    setState(() => _paused = false);
    // The whistle asked to leave while this was up and was refused. It is the
    // same screen with nothing left to say, so it goes now.
    if (frame.finished) _leaveFullTime();
  }

  /// The shot, wrapped in the two things it must never be: interactive, or
  /// something a screen reader reads out. It is a picture of a man's face — it
  /// carries no information the score and the feed do not already give in
  /// words, and its caption bar is decoration.
  Widget _dugoutCam(_CamShot shot) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: DugoutCam(
          // The shot is keyed on the minute it is about, so a second goal
          // genuinely replaces the first rather than reusing its clocks.
          key: ValueKey('dugout-cam-${shot.variant.name}-$_lastCamMinute'),
          mood: shot.mood,
          kit: kit.accent,
          skin: const Color(0xFFEEBB8C),
          hair: const Color(0xFF3A2A1C),
          look: ref.read(managerLookProvider),
          gesture: shot.gesture,
          minute: shot.minute,
          tone: shot.tone,
          variant: shot.variant,
          // Only the full-time shot keeps going: it is still there thirty
          // seconds later, and one reaction followed by a frozen man read as
          // him having got over it already.
          rota: shot.variant == CamVariant.inline
              ? (recent) => camRotaBeat(
                  shot.mood,
                  null,
                  ref.read(gameProvider).state,
                  recent,
                )
              : null,
          onDone: _closeDugoutCam,
        ),
      ),
    );
  }

}

/// Colin, saying one thing, from the touchline.
///
/// **His head and the SHARED tail**, not a plain panel: a bubble with no tail is
/// a caption rather than somebody speaking, which is what every screen but the
/// home page used to get — see `CoachBubbleTail`.
class _CoachSay extends StatelessWidget {
  const _CoachSay({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kit.surface2,
                border: Border.all(color: kit.accentBright, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const ClipOval(
                child: ArtImage(
                  path: coachPortrait,
                  fit: BoxFit.cover,
                  fallback: Center(child: Text('🧢')),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // **IT HAS TO WIN AGAINST THE COMMENTARY UNDER IT.** Same
                  // `surface` and same hairline as the box it floats over, and
                  // it disappeared into it — a bubble the same colour as the
                  // page is a paragraph. It gets the accent edge, a raised
                  // surface and a real shadow: the point of him is that he is
                  // interrupting.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        kit.accent.withValues(alpha: 0.14),
                        kit.surface2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kit.accentBright, width: 1.4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      key: const ValueKey('match-coach-line'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // The wedge hangs off the bubble's bottom-left, pointing back
                  // down at his face.
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: CustomPaint(
                      size: coachTailSize,
                      painter: CoachBubbleTail(
                        fill: Color.alphaBlend(
                          kit.accent.withValues(alpha: 0.14),
                          kit.surface2,
                        ),
                        edge: kit.accentBright,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scorer's face and caption, as a broadcast puts them on the touchline.
class _ScorerBadge extends StatelessWidget {
  const _ScorerBadge({required this.face, required this.caption});

  final Widget face;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      face,
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );
}

/// What the body of the screen is showing.
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
    return Padding(
      // The page's own 13 either side. The strip ran edge to edge while every
      // other band on the screen was inset, so the one control that is ABOUT
      // the pitch above it was the one thing not lined up with it.
      padding: const EdgeInsets.symmetric(horizontal: matchInset),
      child: Column(
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
      ),
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
/// The competition, the minute and the bar — a card of its own.
///
/// **Split off the scoreboard.** It used to be the board's opening band, which
/// put the one thing that changes every tick at the top of the one card whose
/// job is to hold still: every minute the whole score card was a widget whose
/// contents had moved. They are also different questions. The board is WHO and
/// what the score is; this is HOW FAR IN, and it belongs with the bar that says
/// the same thing without arithmetic.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    super.key,
    required this.left,
    required this.right,
    required this.leftGoals,
    required this.rightGoals,
    required this.result,
    required this.isHome,
    required this.standings,
    required this.minute,
    required this.finished,
    required this.label,
    required this.onStats,
  });

  final String left;
  final String right;
  final int leftGoals;
  final int rightGoals;
  final Map<String, dynamic> result;
  final bool isHome;

  /// Where the two clubs stood at kick-off, home side first once laid out.
  final ({PosStanding ours, PosStanding theirs}) standings;

  /// **THE CLOCK IS BACK INSIDE THE BOARD, and that reverses a decision this
  /// repo recorded as done.** It was split into `_ClockCard` on the reasoning
  /// that the one band changing every tick should not sit on the one card whose
  /// job is holding still — which is true, and is overruled by the SPACE. Two
  /// panels with a rule and a gap between them cost a match screen that has
  /// none to spare, and the minute is small and the bar is a hairline; neither
  /// moves the score.
  ///
  /// It goes at the FOOT rather than where it used to be at the head, so the
  /// half of the card that ticks is the half furthest from the half that does
  /// not.
  final int minute;
  final bool finished;

  /// The competition and which end we are — `SUNDAY LEAGUE · HOME`.
  final String label;

  /// **The statistics' only door now that the tab bar has gone.** They were a
  /// full row of chrome on a screen with no room, serving a panel nobody watches
  /// during a match — but deleting them outright would strand `MatchStatboard`
  /// and `match.tab.stats`, which is the fault this whole queue exists to find.
  final VoidCallback onStats;

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
    // The board is laid out HOME SIDE LEFT, the same way the fixture card is.
    final leftStanding = isHome ? standings.ours : standings.theirs;
    final rightStanding = isHome ? standings.theirs : standings.ours;

    return Padding(
      // **TIGHTER THAN IT WAS, because it grew a band.** The standings row is
      // worth its height and the screen is not: at full time on a short phone
      // the feed is already down to a few pixels, so the row pays for itself out
      // of the board's own padding and the gap it replaced.
      padding: const EdgeInsets.fromLTRB(
        matchInset,
        matchGap,
        matchInset,
        0,
      ),
      // **THE CARD, not just the contents of one.** The board shares the
      // next-match card's rows — `MatchRow`, `PosChip`, the mirrored split — but
      // it was drawing them loose on the sky with no pane behind them, so the
      // fixture you accepted and the fixture you are watching did not look like
      // the same object. Same `GlassPanel`, same density, same insets.
      child: GlassPanel(
        density: GlassDensity.deep,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Column(
          children: [
            // **THE SAME BAND THE NEXT-MATCH CARD OPENS WITH.** It is the same
            // fixture ten seconds later and the home page's version is the one
            // that got the design work — so the standings come with it, on their
            // own row, through the same chip.
            MatchRow(
              left: PosChip(
                position: leftStanding.position,
                delta: leftStanding.delta,
                ours: isHome,
              ),
              right: PosChip(
                position: rightStanding.position,
                delta: rightStanding.delta,
                ours: !isHome,
              ),
              gutter: const SizedBox.shrink(),
              bottomSpacing: 4,
            ),
            MatchRow(
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
            MatchRow(
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: kit.textMuted,
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('match-stats-button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onStats,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.bar_chart,
                      size: 16,
                      color: kit.textMuted,
                    ),
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
            const SizedBox(height: 4),
            // The clock as a bar, so how far through the match is readable
            // without doing arithmetic on the minute.
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
          ],
        ),
      ),
    );
  }
}

class _FeedLine extends StatelessWidget {
  const _FeedLine({required this.line, required this.state, this.onReplay});

  final FeedLine line;

  /// Play this goal again, or null when there is no passage to play — a line
  /// that is not a goal, or a goal the cutaway cannot build a clip for.
  final VoidCallback? onReplay;

  /// The save, for resolving [FeedLine.aboutId] into a face. Handed in rather
  /// than watched: the feed rebuilds on every tick of the clock, and a hundred
  /// rows each subscribing to the whole save is a hundred rebuilds a minute for
  /// a portrait that cannot change.
  final Map<String, dynamic>? state;

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

    // **A LINE NAMING A PLAYER, BESIDE THE ART OF THE PLAYER IT NAMES.** The
    // portraits are bundled and `playerImagePath` already resolves them; what
    // was missing was the row knowing who it was about. Null for a line that is
    // about nobody, and for a man who has since left — a sale mid-season must
    // not take a goal off the feed.
    final about = line.aboutId == null ? null : cardById(state, line.aboutId!);
    final def = getPlayerDef(about?.definitionId);
    final face = about == null || def == null
        ? null
        : PlayerFace(
            position: def.position,
            tier: def.tier,
            variant: about.variant,
            size: isGoal ? 30 : 24,
            ring: isGoal ? kit.accentBright : kit.border,
          );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            "${line.minute}'",
            style: TextStyle(color: kit.textMuted, fontSize: 11),
          ),
        ),
        // The face stands IN FOR the ball glyph rather than beside it: two marks
        // in front of one sentence is a row with two subjects. A GOAL never
        // reaches this row — it is a card, and its head carries both.
        if (face != null)
          Padding(padding: const EdgeInsets.only(right: 8), child: face),
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
    );

    // **A GOAL IS A CARD, not a row.** Every line was the same shape in the
    // same column — a transcript — and the single most important thing that
    // happens in a match read exactly like "nerves jangling all around the
    // ground". It gets a head (the minute, the word GOAL, the score it made),
    // the scorer with his face and his tally, and the sentence underneath as
    // the caption it always was. `match.goal_card.title`, `match.career_goal`
    // and `match.career_goals` were translated ten times over with nothing able
    // to reach one of them.
    final goal = line.goal;
    if (goal != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          // **THEIRS IS RED.** The kit's green is what the game uses for a thing
          // going well for US; a goal against wearing it read as a goal for.
          decoration: BoxDecoration(
            color: (goal.ours ? kit.accent : conceded).withValues(
              alpha: goal.ours ? 0.13 : 0.12,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: goal.ours ? kit.accentBright : conceded,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    "${line.minute}'",
                    style: TextStyle(
                      color: kit.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The ball marks OUR goal in the head. Theirs is headed by
                  // their name, which is mark enough for a goal that is not
                  // being celebrated.
                  if (goal.ours) ...[
                    Icon(
                      Icons.sports_soccer,
                      size: 14,
                      color: kit.accentBright,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      // Theirs carries their NAME instead of the word — we
                      // hold no card for their players, so the head is the
                      // only place left to say whose goal it was.
                      goal.ours
                          ? t('match.goal_card.title')
                          : '${line.params['them'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: goal.ours ? kit.accentBright : conceded,
                      ),
                    ),
                  ),
                  Text(
                    '${goal.left}–${goal.right}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              // No scorer row for theirs, and none for one of ours whose card
              // has since gone: a face for a man the save has never heard of
              // cannot be drawn, and inventing a name is worse than the gap.
              if (about != null && def != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    PlayerFace(
                      position: def.position,
                      tier: def.tier,
                      variant: about.variant,
                      size: 34,
                      ring: kit.accentBright,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            about.name(def.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (_careerGoals(about, goal.tallyInMatch)
                              case final total?)
                            Text(
                              t(
                                total == 1
                                    ? 'match.career_goal'
                                    : 'match.career_goals',
                                {'n': total},
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: kit.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 12.5, color: kit.textMuted),
                    ),
                  ),
                  // **THE ONE THING WORTH SEEING TWICE.** A goal goes past
                  // while the manager is reading the line above it, and the
                  // passage is rebuilt from the minute rather than recorded —
                  // so asking for it again costs nothing but the chip.
                  //
                  // No label on it, and that is deliberate: the catalogues are
                  // generated from the JS's own `en.js`, which has never had a
                  // word for this, and inventing a key would print English in
                  // ten languages. The glyph is the control.
                  if (onReplay case final replay?)
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        key: ValueKey('feed-replay-${line.minute}'),
                        padding: EdgeInsets.zero,
                        iconSize: 17,
                        visualDensity: VisualDensity.compact,
                        color: goal.ours ? kit.accentBright : conceded,
                        icon: const Icon(Icons.replay),
                        onPressed: replay,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

/// His goals in the book plus the ones he has scored today, or null for a card
/// that keeps no record.
///
/// The save is not written until the whistle, so the stored figure is always one
/// match behind what the player just watched.
int? _careerGoals(CardInstance card, int today) {
  final stats = card.raw['stats'];
  if (stats is! Map<String, dynamic>) return null;
  final scored = stats['goals'];
  return (scored is num ? scored.toInt() : 0) + today;
}
