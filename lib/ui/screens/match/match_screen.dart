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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart' show PlayerEnergy;
import 'package:merge_empire_fc/data/players.dart'
    show PlayerDef, getPlayerDef;
import 'package:merge_empire_fc/engine/match_coach.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart'
    show isProMode;
import 'package:merge_empire_fc/engine/tactic_coach.dart'
    show baselineInjuryRisk, injuryCostPoints;
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/coach_tip_engine.dart'
    show hasSeenTip, markTipSeen;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';
import 'package:merge_empire_fc/services/sound_service.dart';
import 'package:merge_empire_fc/state/card_instance.dart' show CardInstance;
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart'
    show CutawayOutcome;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart';
import 'package:merge_empire_fc/ui/screens/match/goal_replay.dart'
    show conceded;
import 'package:merge_empire_fc/engine/match_orchestration.dart'
    show reSimulateRemainder;
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart'
    show coachSuggestedTacticProvider;
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show leagueTableProvider, managerLookProvider;
import 'package:merge_empire_fc/engine/league_table.dart' show LeagueRow;
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart'
    show PosStanding;
import 'package:merge_empire_fc/engine/lineup_engine.dart'
    show restoreKickoffLineup;
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/momentum_arrow.dart';
import 'package:merge_empire_fc/ui/widgets/card_glyph.dart';
import 'package:merge_empire_fc/ui/screens/match/match_report_card.dart';
import 'package:merge_empire_fc/ui/screens/match/shootout_row.dart'
    show shootoutFrom;
import 'package:merge_empire_fc/ui/screens/match/subs_panel.dart';
export 'package:merge_empire_fc/ui/widgets/card_glyph.dart'
    show CardGlyph, cardYellowInk, cardRedInk, cardInk;
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart'
    show pitchSlotsProvider, slotCandidatesProvider, SlotCandidate, PitchSlot;
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart'
    show cardById;
import 'package:merge_empire_fc/ui/screens/settings_controls.dart'
    show settingPick, writeSetting;
import 'package:merge_empire_fc/ui/screens/match/dugout_cam.dart';
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/data/manager_mood.dart' show Gesture, Mood;
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/shell/coach_floating.dart' show CoachCorner;
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart' show PlayerFace;
import 'package:merge_empire_fc/ui/widgets/store_button.dart'
    show mouldedButtonStyle;
import 'package:merge_empire_fc/ui/theme/sky.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';
import 'package:merge_empire_fc/util/stat_display.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart'
    show CoachAction, showCoachCard;

/// One dugout-cam shot, as the screen has decided it. Everything the widget
/// needs and nothing it can work out for itself.
typedef _CamShot = ({
  Mood mood,
  Gesture? gesture,
  CamTone tone,
  String? minute,
  CamVariant variant,
});

/// The tactic the side KICKED OFF in.
///
/// **The SAVE's, not the result's**, and that is the whole of a report from the
/// couch: picking a tactic on the next-match card did not filter through, and it
/// had to be picked again on the strip. `playMatch` never stamps a `strategyId`
/// — neither does the JS's — because `reSimulateRemainder` is the only thing
/// that writes one, and it only runs when the manager switches mid-match. So
/// reading the result alone meant every kickoff was Balanced: the strip lit the
/// wrong chip, the scoreboard's ATK/DEF carried the wrong multipliers, and the
/// arrow read a tactic nobody had chosen.
///
/// `../merge-empire-fc/src/ui/components/MatchPopup.js` opens on
/// `state.squad.strategyId` and this is that line. The result still wins where
/// it has one, which is a screen re-entered after a switch.
String kickoffStrategy(
  Map<String, dynamic> result,
  Map<String, dynamic>? state,
) {
  final onResult = result['strategyId'];
  if (onResult is String && onResult.isNotEmpty) return onResult;
  final squad = state?['squad'];
  final saved = squad is Map ? squad['strategyId'] : null;
  return saved is String && saved.isNotEmpty ? saved : defaultStrategy;
}

/// **ONE INSET AND ONE GAP for every band on this screen.**
///
/// It was 13, 12 and 14 down the page with gaps of 6, 7 and 8 between them, and
/// a page of panels at four insets reads as unfinished before anything on it is
/// read — which is exactly how it was reported. The radius belongs to
/// `GlassPanel`, so nothing here draws its own.
const double matchInset = 13;

/// **TWELVE, the same seam the Play page uses.** It was six here and twelve
/// there, so walking from one to the other halved the spacing — reported as the
/// margins on the play-match popup not being fixed, immediately after the Play
/// page's own were set to twelve. One number for both, and the band heights are
/// what give the room: the pitch takes only what the tilted pitch needs and the
/// commentary is `Expanded`.
const double matchGap = 12;

/// Below this a move on the 2D pitch stops being readable. `STAGE_MIN_HEIGHT`.
const double stageMinHeight = 132;

/// Below this the commentary stops being a feed. `BODY_MIN_HEIGHT`, and sized
/// in the spec to hold one whole goal card rather than one line of text.
const double feedMinHeight = 168;

/// What the tactic strip takes out of the pool when it is up. Measured, and
/// only ever spent defending [feedMinHeight], so a point or two either way
/// changes nothing.
const double tacticStripHeight = 44;

/// How tall the pitch band gets — `_syncShellHeight` in `MatchPopup.js`.
///
/// **THE BAND HOLDS THE PITCH'S ASPECT.** It was 16% of screen height, which on
/// a 402x874 phone is 140 points against the spec's 226 — the pitch drawn at 62%
/// of the size it is designed for. At that scale a player is about four points
/// across, so a chance cutting in is a few dots twitching in a letterboxed
/// strip: reported as the 2D pitch being cut off, and separately as nothing
/// happening on it while the commentary and the sounds reported shots.
///
/// The two floors are the spec's own and they are what stops the aspect eating
/// the commentary — [stageMinHeight] and [feedMinHeight]. [pool] is what the
/// stage and the feed have to share, measured rather than summed from the fixed
/// bands, which is the mistake the spec records itself making.
///
/// [width] is the INSET width. The clip mounts inside the same padding, so
/// measuring the aspect off the full width would overshoot by the inset every
/// time — the spec's own note.
double stageBandHeight({
  required double width,
  required double pool,
  required bool hasTacticStrip,
}) {
  if (!width.isFinite || width <= 0) return stageMinHeight;
  final ideal = width / pitchAspect;
  if (!pool.isFinite) return ideal;
  final forTheFeed =
      feedMinHeight + (hasTacticStrip ? tacticStripHeight : 0) + matchGap * 2;
  return math.max(
    stageMinHeight,
    math.min(ideal, math.max(0, pool - forTheFeed)),
  );
}

/// The face the match's own controls wear.
///
/// **Solid, where every other `OutlinedButton` in the app is not.** The outline
/// form is a transparent face by design and that is right nearly everywhere —
/// a cancel that carried a face would out-shout the action beside it. This row
/// is not that: it is the only row of controls on the page, and its ground is a
/// stadium at dusk, so three empty outlines read as holes cut in the page.
/// Asked for directly.
///
/// **AND THE THREE ARE NOT ONE CONTROL.** They all wore `kit.surface2`, so the
/// speed toggle, the substitution and the give-up button were three identical
/// grey slabs — reported from the couch as just grey, wanting the themed
/// colours and wanting them to mean something. [face] is what each one is FOR:
///
/// - the speed toggle is a STATE, so it lights in the club's accent when 2× is
///   on and sits neutral when it is not — the one control on the page whose
///   colour is information;
/// - Subs and Skip are both neutral. Subs was the substitution green for a
///   while, on the reasoning that it is the only decision in the row — and
///   three buttons in three colours read as three unrelated things rather than
///   as one row, with the green one looking like a confirmation. Reported from
///   the couch: "not sure why Subs is green, it should just be the same as
///   Skip Match." So the colour is left to the one control it is genuinely
///   information for, and what tells the other two apart is a glyph.
///
/// Through `mouldedButtonStyle` rather than `styleFrom`, because a moulded
/// button's face is painted in a `backgroundBuilder` over a transparent
/// Material — `backgroundColor:` colours the layer underneath it and fails
/// silently. `architecture_test.dart` checks exactly this.
/// A glyph and a word, for one of the three controls under the pitch.
///
/// **All three carry one**, asked for from the couch alongside the colours:
/// with the green gone, Subs and Skip are the same shape in the same face and
/// the word is doing all of the work. `FittedBox` rather than a smaller type:
/// `common.skip` is two words in several languages and the row is fixed.
class _ControlFace extends StatelessWidget {
  const _ControlFace({required this.glyph, required this.label});

  final String glyph;
  final String label;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(glyph, size: 16),
        const SizedBox(width: 6),
        Text(label, maxLines: 1, softWrap: false),
      ],
    ),
  );
}

Color _onFace(Color face) {
  final l = face.computeLuminance();
  return 1.05 / (l + 0.05) >= (l + 0.05) / 0.0575
      ? Colors.white
      : const Color(0xFF10141A);
}

ButtonStyle matchControlStyle(BuildContext context, {Color? face}) {
  final kit = Theme.of(context).extension<KitTheme>()!;
  final fill = face ?? kit.surface2;
  return mouldedButtonStyle(
    face: fill,
    // The edge is the face's own shade, so a coloured button is one object
    // rather than a colour inside a grey frame.
    edge: face == null ? kit.border : Color.lerp(fill, Colors.black, 0.3)!,
    // Whichever of the two reads better on the face, MEASURED — the same pick
    // `CornerBanner` makes, because a brightness guess is what puts white on a
    // mid green at 2.9:1. The neutral face keeps the page's own body colour.
    ink: face == null
        ? Theme.of(context).colorScheme.onSurface
        : _onFace(fill),
    dead: kit.surface2,
    deadInk: kit.textMuted,
    border: kit.border,
  ).copyWith(
    // **THE SAME SIZE AS THE PAGE, not a point bigger.** `mouldedButtonStyle`
    // sets 14 for every button in the app; on this row that is a point over the
    // commentary directly under it, and with one weight everywhere the size was
    // the only thing making these three shout. Reported from the couch — not
    // liking them being bigger, bold is fine.
    // **`copyWith` SWAPS THE WHOLE PROPERTY**, so a bare `TextStyle(fontSize:
    // 13)` here threw away the moulded style's family AND its weight — these
    // three came out at `w400` in the platform's font while every other button
    // in the app was `w900`. Reported from the couch, twice: the wrong font,
    // then these three defo not being `w600`.
    //
    // **AND THEY ARE THE COMMENTARY'S OWN STYLE, deliberately.** The moulded
    // `w900` is a weight `pubspec.yaml` does not bundle a cut for, and these
    // three sit directly over the feed — asked for as needing to be the SAME
    // as the commentary, which is 13 at [uiBaseWeight] and nothing else. So
    // the row matches the thing it sits on rather than the other eighty
    // buttons in the app, which is what makes it part of the page.
    textStyle: WidgetStatePropertyAll(
      controlTextStyle(size: 13, weight: uiBaseWeight),
    ),
  );
}

/// The commentary's own side inset.
///
/// **Nothing, and the BAND's inset comes off too.** Every line used to carry 14
/// either side inside a panel that was itself inset 13 from the page, so a line
/// of commentary started 27 points in on a 320pt phone — a quarter of the
/// screen gone before the first word, on the one band here that is read rather
/// than looked at. Halving it was not enough; the plates are the only thing in
/// this band now, so they take the page's own margin and nothing on top of it.
/// See [feedBandInset].
const double feedInset = 0;

/// What the commentary band itself is inset by.
///
/// **[matchInset], the same as every other band — and that is the whole fix.**
/// The feed used to pay twice: [matchInset] for the band and another 7 inside
/// it for each plate, so the commentary started 20 points in while the tactic
/// strip directly above it started at 13. Reported as the commentary having
/// more margin than the tactics. One inset, paid once, and the two line up.
const double feedBandInset = matchInset;

/// The ground under one line of commentary.
///
/// **It had almost none.** A 4% white wash was the whole plate, which on the
/// sky behind it is a rumour of a box rather than a box — and with the outer
/// panel gone there is nothing else holding the lines apart. Reported directly:
/// the boxes need more of a background.
const double feedPlateFill = 0.13;
const double feedPlateEdge = 0.16;

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({
    super.key,
    required this.result,
    this.onFinished,
    this.onLeave,
    this.fast = false,
  });

  /// A finished match, from `simulateMatch`.
  final Map<String, dynamic> result;

  /// Called once, at full time.
  final void Function(Map<String, dynamic> result)? onFinished;

  /// How this screen LEAVES, given its own context.
  ///
  /// **Because popping is not how it should leave.** Pop removes the match and
  /// only then can the summary be pushed, so the home page is on screen behind
  /// the summary's own entrance — reported twice as the home page showing
  /// before the end-of-match page. The caller replaces this route with the
  /// summary instead, which slides in over the match and takes it with it.
  /// Null pops, which is what a test that mounts this screen alone wants.
  final void Function(BuildContext context)? onLeave;

  final bool fast;

  @override
  ConsumerState<MatchScreen> createState() => MatchScreenState();
}

class MatchScreenState extends ConsumerState<MatchScreen> {
  /// Rebuilt whenever the tactic changes — see [applyStrategy]. Not `final`:
  /// the remainder of the match is genuinely re-decided, so the list of what is
  /// left to show is replaced.
  /// **THE REFEREE, and he is the PORT'S referee.**
  ///
  /// Nothing in the spec books anybody, and bookings cannot ride in the result
  /// or its event array — both are compared field for field against the JS, and
  /// forty-six tests said so, twice. So they are minted here, from the fixture's
  /// own key and the eleven who started, and merged into the timeline. See
  /// `booking_engine.dart`.
  late final List<Map<String, dynamic>> _bookings = _rollBookings();

  /// The cards this match produced. **A test seam**, and the same list the
  /// suspension will be written from.
  List<Map<String, dynamic>> get bookings => _bookings;

  /// What the opposition's own referee has cost them so far.
  ///
  /// Exposed for the test that holds watching and skipping to the same tally —
  /// see [_oppCardsSeen]. `bookings` above is exposed for the same kind of
  /// reason.
  ({int yellows, int sendOffs}) get oppCards =>
      (yellows: _oppYellows, sendOffs: _oppSendOffs);

  late List<TimelineEvent> _timeline = timelineOf(
    widget.result,
    bookings: _bookings,
  );

  /// One match's cards, decided once. Seeded off the FIXTURE KEY — `s3_m7` —
  /// so a match books the same players every time it is watched, which is the
  /// promise the cutaway already makes about its passages.
  /// The same cards as [_bookings], in the shape the engine speaks — kept so
  /// the whistle can write the record without re-parsing its own feed rows.
  List<Booking> _bookingRecords = const [];

  List<Map<String, dynamic>> _rollBookings() {
    final state = ref.read(gameProvider).state;
    final squadMap = state?['squad'];
    final lineup = squadMap is Map<String, dynamic>
        ? squadMap['lineup']
        : null;
    final ids = <String>{
      if (lineup is List)
        for (final slot in lineup)
          if (slot is Map<String, dynamic>)
            if (slot['cardInstanceId'] case final String id) id,
    };
    final squad = <BookingCandidate>[
      for (final id in ids)
        if (cardById(state, id) case final card?)
          if (getPlayerDef(card.definitionId) case final def?)
            (instanceId: id, name: card.name(def.name), position: def.position),
    ];
    if (squad.isEmpty) return const [];
    final key = '${widget.result['fixtureKey'] ?? ''}';
    var seed = 0;
    for (final unit in key.codeUnits) {
      seed = (seed * 31 + unit).toSigned(32);
    }
    _bookingRecords = rollBookings(squad: squad, seed: seed);
    // **AND THE REFEREE HAS A POCKET FOR BOTH SIDES.** Asked for from the
    // couch: "they can get yellow cards as well, its not just us." Their eleven
    // is synthetic — the port never names an opposition player, at a goal or
    // anywhere else — so this is a shape to weight the draw by lines, and the
    // copy is about the CLUB. Its own seed, so their afternoon is not a mirror
    // of ours.
    final theirs = rollBookings(
      squad: [
        for (var i = 0; i < 11; i++)
          (
            instanceId: 'opp-$i',
            name: '',
            position: i == 0
                ? 'GK'
                : i < 5
                ? 'DEF'
                : i < 9
                ? 'MID'
                : 'FWD',
          ),
      ],
      seed: (seed ^ 0x00A1_1A7).toSigned(32),
    );
    return [
      for (final b in _bookingRecords)
        {
          'minute': b.minute,
          'type': 'booking',
          'team': 'home',
          'player': b.name,
          'playerInstanceId': b.instanceId,
          'card': b.card,
        },
      // **AN ID, EVEN THOUGH NOBODY IS NAMED.** Their eleven is synthetic and
      // the copy is about the club, so there is no player for this to point at
      // — it exists so a card can be counted ONCE. The live dispatch tallies
      // their bookings as the clock reaches them and `_catchUpSendingsOff`
      // tallies every booking at the whistle, so without something to key on, a
      // fully WATCHED match double-counted every opposition card at full time
      // and re-rolled the remainder against a side punished twice.
      for (var i = 0; i < theirs.length; i++)
        {
          'minute': theirs[i].minute,
          'type': 'booking',
          'team': 'away',
          'playerInstanceId': 'oppcard-$i',
          'card': theirs[i].card,
        },
    ];
  }
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

  /// The event the 2D pitch is retelling right now, or null between clips.
  ///
  /// Its shot and its crowd are played off the CLIP's beats rather than off the
  /// minute — see [_soundFor] and [_clipStruck].
  TimelineEvent? _clippedEvent;

  /// How each retold chance ENDED, as a commentary key by minute — what the
  /// feed prints for it. See `feedOf`'s `clippedChanceKeys`.
  final Map<int, String> _clippedChanceKeys = {};

  /// **EVERY MOMENT THE PITCH ACTUALLY RETOLD**, in the order it told them.
  ///
  /// The full-time panel offers each of them back — see [PitchStatOverlay] —
  /// and this is the only record of which ones there were: `clipFor` refuses a
  /// chance for the pacing gap or for a switch the player has turned off, so
  /// the timeline alone cannot answer "what did I actually see".
  final List<TimelineEvent> _retold = [];

  /// **WHAT EACH LINE ACTUALLY SAID, by its seed.**
  ///
  /// The feed rebuilds on every tick of the clock, so the sentence for a given
  /// line has to be decided ONCE — that is what `tPoolStable` was for. It is
  /// also what stops a no-repeat rule from working, because a rule that
  /// remembers what it has said cannot be re-run sixty times a minute against
  /// the same lines. So the pick happens here, once per line, and the answer is
  /// kept: stable across rebuilds because it is cached, and unrepeated because
  /// [_poolUsed] is the match's own memory.
  final Map<String, String> _lineText = {};

  /// Which variants each pool has already given out this match — see
  /// [tPoolUnused]. Asked for from the couch: never the same story twice in one
  /// match.
  final Map<String, Set<int>> _poolUsed = {};

  /// A replay the PLAYER asked for, rather than the clock cutting away.
  ///
  /// The dugout cam reacts to a clip when it ends; a replay of a goal from ten
  /// minutes ago is not news, so it does not.
  bool _replaying = false;

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

  /// What the side is playing right now. See [kickoffStrategy] for where the
  /// opening value comes from and why it is not the result's.
  late String _strategy = kickoffStrategy(
    widget.result,
    ref.read(gameProvider).state,
  );

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

  /// The pitch band, so Colin's scrim can leave it alone — see
  /// [CoachCorner.litArea].
  final GlobalKey _stageKey = GlobalKey();

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
    // **THE RESULT IS THE RECORD.** Full match reports are the stated
    // direction — AI-versus-AI ones too, with nothing but the result to read —
    // so what the side set up as goes on it here, the way the bookings and
    // the switches already do. `strategyId` is the engine's and a switch
    // overwrites it. Nothing reads this yet; it is there so the report can.
    widget.result['kickoffStrategy'] = _strategy;
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
  ///
  /// **AND IT STICKS.** It was live-only, so a manager who had settled on 2x
  /// re-tapped it every game — reported directly. `matchSpeedFast` is the
  /// setting the settings screen already writes and `PlayMatchButton` now
  /// opens on, so the button and the segment are two doors onto one preference
  /// rather than two speeds that disagree.
  void toggleSpeed() {
    if (frame.finished) return;
    setState(() => _fast = !_fast);
    writeSetting(ref, 'matchSpeedFast', _fast);
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
  ///
  /// **EXCEPT THE ONE THE PITCH IS RETELLING.** That event's shot and crowd ride
  /// the clip's own beats instead — see [_clipStruck] and [_clipVerdict]. This
  /// method fires on the MINUTE TICK, and a passage runs a second or two of
  /// run-ups and passes before anybody shoots, so a goal was heard while the
  /// ball was still in midfield and the net then bulged in silence. The fixed
  /// 180ms and 200ms gaps below are right for a chance with no clip, where there
  /// is no picture to be late for; they were never a flight time.
  void _soundFor(int minute) {
    final sound = ref.read(soundServiceProvider);
    // The chances the feed will actually print, up to and including this
    // minute — the same window the screen is drawing. The gap filter counts
    // from the last SHOWN chance, so it has to be run over the run of events
    // rather than asked about one. See [feedChanceMinutes].
    final heard = feedChanceMinutes(
      [
        for (final e in _timeline)
          if (e.minute <= minute) e,
      ],
      clippedChanceKeys: _clippedChanceKeys,
    );
    for (final event in _timeline) {
      if (event.minute != minute) continue;
      // The clip will play this one's shot when it takes it.
      if (event == _clippedEvent) continue;
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
          // **AND ONLY IF THE PLAYER IS SHOWN IT.** The feed prints three or
          // four of a match's thirteen chances — big, on target, and clear of
          // the last one — and this fired on all thirteen, so nine or ten kicks
          // a match landed with nothing on screen to belong to, half of them
          // with the crowd's groan behind them. Reported as miss noises with no
          // action, and the report states the rule: if no action, no noise.
          // See [feedChanceMinutes], which asks the feed rather than repeating
          // its arithmetic.
          if (!heard.contains(event.minute)) break;
          unawaited(sound.play('kick'));
          // A chance that hit the target and stayed out is the one the crowd
          // reacts to; a wild one off target is not worth a sound. **The crowd,
          // not the post**: nothing on this path was shown hitting anything,
          // and `woodwork` played for every one of their saves.
          if (event.shotResult == 'on_target') {
            _cue(
              const Duration(milliseconds: 200),
              () => unawaited(sound.play('crowdOoh')),
            );
          }
        case 'injury':
          unawaited(sound.play('injury'));
          // Ours only: the opponent's physio is not our problem, and there is
          // no hole in OUR side to cover.
          if (ours) {
            WidgetsBinding.instance.addPostFrameCallback(
              // **THE CASUALTY'S NAME TRAVELS WITH IT.** The event carries it
              // and nothing read it, so the announcement had nobody to name —
              // see [_onInjuryShown].
              (_) => unawaited(_onInjuryShown(event.player)),
            );
          }
        // **A SENDING-OFF PUTS YOU IN FRONT OF THE BENCH, and you cannot fix
        // it.** The same reasoning as an injury: nobody is moved automatically,
        // so a manager reading the feed would otherwise finish the half with a
        // hole where a defender was. The difference is the whole point of it —
        // there is no replacement, only the ten who are left and where they
        // stand. Asked for from the couch, along with Colin explaining why.
        case 'booking':
          unawaited(sound.play('error'));
          final who = event.playerId;
          // **THEIR CARD IS NOT NOTHING ANY MORE.** There is still no bench of
          // theirs to open and no ban of theirs to write — but it used to leave
          // the maths untouched as well, so a sending-off for the opposition
          // was a sentence in the feed and a side that went on playing at full
          // strength. Reported from the couch. A second yellow is a sending-off
          // and stops counting as a caution: he is off, not booked.
          if (event.team == 'away') {
            // Counted once — see the note where these ids are minted.
            if (!_oppCardsSeen.add(who ?? '${event.minute}-${event.card}')) {
              break;
            }
            if (cardSendsOff(event.card ?? cardYellow)) {
              _oppSendOffs++;
              if (event.card == cardSecondYellow && _oppYellows > 0) {
                _oppYellows--;
              }
            } else {
              _oppYellows++;
            }
            _resimulate(event.minute, _strategy, rerollInjuries: false);
            if (mounted) {
              setState(
                () => _timeline = timelineOf(
                  widget.result,
                  bookings: _bookings,
                ),
              );
            }
            break;
          }
          if (cardSendsOff(event.card ?? cardYellow)) {
            if (who != null) {
              _cautioned.remove(who);
              _sentOff.add(who);
              // **AND THE SIDE IS ACTUALLY A MAN SHORT.** Before this the card
              // was theatre: the man stayed in the lineup, the squad rating did
              // not move, and the rest of the match was played out by a
              // scoreline decided at kickoff by eleven players. Reported from
              // the couch — "my rating didn't update so I don't know if the
              // loss of that player actually counted."
              _playerSentOff(who, event.minute);
            }
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => unawaited(_onSendingOff(event.player ?? '')),
            );
          } else if (who != null) {
            _cautioned.add(who);
            // **AND THE TEN PER CENT REACHES THE SCORELINE.** It used to come
            // off the pitch token's number and off what the bench compared
            // against, and stop there — so the rest of the match was rolled by
            // a side nobody had booked. Asked for directly: "the new number
            // should be what the SIM rerolls with."
            //
            // `rerollInjuries: false` for the same reason a substitution passes
            // it: a caution is not a change of approach, so the injuries the
            // match had coming still come.
            _resimulate(event.minute, _strategy, rerollInjuries: false);
            if (mounted) {
              setState(
                () => _timeline = timelineOf(
                  widget.result,
                  bookings: _bookings,
                ),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => unawaited(_onBooked(who, event.player ?? '')),
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

  /// The clip's boot has hit the ball: the shot, on the frame it is struck.
  ///
  /// Which sound is still the EVENT's decision, exactly as it is on the minute
  /// path — a goal is struck harder than a half-chance — so nothing about what
  /// plays has changed. Only when.
  void _clipStruck() {
    final event = _clippedEvent;
    if (event == null || !mounted) return;
    final sound = ref.read(soundServiceProvider);
    switch (event.type) {
      case 'goal':
        unawaited(sound.play('shotKick'));
      case 'chance':
        unawaited(sound.play('kick'));
      default:
        break;
    }
  }

  /// The ball has arrived, so now the crowd knows.
  ///
  /// Off the CLIP's arrival rather than a fixed gap after the kick: a shot from
  /// the edge of the box and a tap-in are not the same wait, and the whole
  /// complaint was a reaction that did not land with the thing it was reacting
  /// to. The outcome the clip reports is the one the event gave it, so this
  /// still reads the event.
  ///
  /// **And the sound is the OUTCOME's**, which is the whole point of waiting
  /// for it: `woodwork` is the post being hit, so it plays when the clip has
  /// drawn the ball hitting the post and at no other time. It used to play for
  /// every save of theirs, so a match rattled the frame a dozen times without
  /// a shot ever touching it. A save draws the crowd's reaction whoever made
  /// it; a shot that misses everything gets nothing.
  void _clipVerdict(CutawayOutcome outcome) {
    final event = _clippedEvent;
    if (event == null || !mounted) return;
    final ours = event.team != 'away';
    final sound = ref.read(soundServiceProvider);
    switch (outcome) {
      case CutawayOutcome.goal:
        unawaited(sound.play(ours ? 'goal' : 'goalAgainst'));
      case CutawayOutcome.post:
        unawaited(sound.play('woodwork'));
      case CutawayOutcome.saved:
        unawaited(sound.play('crowdOoh'));
      case CutawayOutcome.over:
      case CutawayOutcome.wide:
      case CutawayOutcome.tackled:
        break;
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
        names: lineupNames(ref.read(gameProvider).state),
        // Live, then the name the result recorded — see [clipScorerName].
        scorerName: clipScorerName(
          ref.read(gameProvider).state,
          event,
          ours: ours,
          nameOf: cardDisplayName,
        ),
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
      // **WHICH event, not just which minute.** Two things can land on the same
      // minute — a chance and an injury — and only the one the pitch is
      // retelling has its sounds moved onto the clip's beats. See [_soundFor].
      _clippedEvent = event;
      if (event.type == 'chance') {
        _lastChanceCutMinute = event.minute;
        _clippedChanceKeys[event.minute] = commentaryKeyFor(clip.outcome);
      }
      // **THE GRASS BELONGS TO THE CHANCE.** The float shot sits bottom-right
      // OVER the pitch, which is fine while nothing is happening on it and is
      // exactly wrong the moment something is — a goal's cut-in was still up
      // when the next chance began, so the move it covered was one the player
      // never saw. He gives way rather than sharing it; the shot he loses is a
      // reaction to something already over, and the thing replacing it is
      // happening now.
      _closeDugoutCam();
      _retold.add(event);
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

  /// **HIS WORD AT THE WHISTLE, and it is HIS rather than the feed's.**
  ///
  /// The nine `commentary.*` result lines — `thriller_*`, `demolition`,
  /// `drubbing`, `high_scoring_*`, `nervy_one_nil`, `nil_nil` — spent a round
  /// being printed as the last row of the commentary, and they cannot be: every
  /// one is written in the first person, and the feed is an independent
  /// commentator describing two clubs. "We took West Ham apart" went out to a
  /// player in a commentary feed and was reported straight back. See
  /// `fullTimeReactionKey`, which still picks which one and is still silent
  /// after an ordinary afternoon.
  ///
  /// **NOT gated on Pro mode, which is the one place this parts company with
  /// [_maybeCoach].** That gate buys the numbers by giving up the ADVICE — a
  /// read of the game with a tactic switch attached to it — and this is a
  /// remark about a result that has already happened. Gating it would delete
  /// nine translated strings for half the players in the name of a bargain
  /// they did not make; the pro manager gets no tips, not no manager.
  ///
  /// **The goals are the ones ON SCREEN.** `frame` counts them off the shown
  /// events, which is the rule the feed followed here before it: the number in
  /// his sentence can never run ahead of the goals that explain it, and a
  /// skipped match is the case that proves it.
  void _sayFullTimeWord() {
    if (!mounted) return;
    final f = frame;
    final key = fullTimeReactionKey(ours: f.ourGoals, theirs: f.theirGoals);
    if (key == null) return;
    final opponent = '${widget.result['opponentName'] ?? ''}';
    // **THE OPPONENT IS IN THE SEED, not just the score.** `fullTimeReactionKey`
    // already picks the pool off the scoreline, so seeding the LINE on the
    // scoreline too meant every 2-1 he ever won said the same sentence. The
    // club is what makes one 2-1 a different afternoon from the next.
    _say(
      tPoolStable(key, 'ft-${f.ourGoals}-${f.theirGoals}-$opponent', {
        // `{us}`–`{them}` is the SCORELINE in our order, and `{opp}` is the
        // club. Not the venue ordering the scoreboard uses: "a 1-0 win over
        // Ayton" is his sentence whichever ground it was won on.
        'us': f.ourGoals,
        'them': f.theirGoals,
        'opp': opponent,
      }),
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
    // Nothing to watch on the way to full time — and nothing left to hear for
    // it either, so the clip's own cues go with it.
    setState(() {
      _minute = _end;
      _clip = null;
      _clippedEvent = null;
    });
    _finish();
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (_reported) return;
    _reported = true;
    _catchUpSendingsOff();
    // **AND THE BANS ARE WRITTEN AT THE WHISTLE.** A sending-off costs the next
    // match as well as the rest of this one — see `applySuspensions`. It goes
    // here rather than in `settleMatch` because the bookings are the port's own
    // and live on this screen; the engine's result has never heard of them.
    //
    // **BEFORE `_restoreKickoffLineup`, which is the ordering that matters.**
    // That sweep puts the kickoff eleven back and refuses anybody it considers
    // unavailable — and a ban is exactly that, so the ban has to be on the card
    // before it runs. Written after it instead, the sweep put the sent-off man
    // straight back into the side and the next match was played with twelve
    // legs too many. Reported from the couch: he was still in the team
    // afterwards, with nothing on him to say why.
    //
    // Also before `onFinished`, which is what commits the match count.
    final off = [
      for (final b in _bookings)
        if (cardSendsOff('${b['card']}')) '${b['playerInstanceId']}',
    ];
    // **AND THE REPORT NEEDS THEM.** The summary is the next screen and it is
    // handed this same map — see `MatchReportCard`, which counts the cards to
    // decide whether the referee gets a sentence. Both sides' rows travel; the
    // ones with no `playerInstanceId` are theirs.
    widget.result['bookings'] = _bookings;
    if (_bookingRecords.isNotEmpty) {
      final game = ref.read(gameProvider);
      game.update((state) {
        final prog = state['progression'];
        // **PLUS ONE, because this match has not been counted yet.**
        // `onFinished` is what increments `matchesPlayed`, and it runs after
        // this — so passing the stored figure wrote a ban that expired the
        // instant the whistle was recorded, and the man was available for the
        // very fixture he was supposed to miss. `applySuspensions` wants the
        // count INCLUDING the match just played; the save does not have it yet.
        applySuspensions(
          state,
          off,
          playedSoFar:
              (prog is Map<String, dynamic>
                  ? (prog['matchesPlayed'] as num?)?.toInt() ?? 0
                  : 0) +
              1,
        );
        // And the cards themselves go on the record, beside his goals.
        recordBookings(state, _bookingRecords);
      });
    }
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
    // **A CUP TIE CANNOT END LEVEL, so it never plays the draw sting.** The
    // feed carries the ninety minutes only — the shootout's winning goal is
    // taken back out of it, see `cup_launcher` — so a tie settled on penalties
    // reached this line as a draw and the whistle chimed for one, seconds
    // before the summary declared the club through or out. Reported from the
    // couch as a level cup scoreline followed by the victory screen with
    // nothing in between to explain it. The shootout is the only thing that
    // knows, so it is what is asked.
    final penalties = shootoutFrom(widget.result);
    final wonOnPens = penalties?.won;
    _cue(
      const Duration(milliseconds: 450),
      () => unawaited(
        sound.play(
          ours > theirs
              ? 'victory'
              : ours == theirs
              ? (wonOnPens == null
                    ? 'draw'
                    : wonOnPens
                    ? 'victory'
                    : 'defeat')
              : 'defeat',
        ),
      ),
    );
    widget.onFinished?.call(widget.result);
    // And Colin's word on the afternoon, after the sting rather than under it.
    _cue(const Duration(milliseconds: 1100), _sayFullTimeWord);
    // **AND THEN IT WAITS.** It used to leave on a 1,400ms timer, on the
    // reasoning that full time here is a screen with nothing left to say: the
    // tactic strip has gone, the clock has stopped and the payoff is on the
    // summary.
    //
    // What that missed is the FEED. Ninety minutes of commentary scroll past at
    // one minute per 350ms and the last thing a player wants at the whistle is
    // often the thing they half-read at 71 — and the timer took the page away
    // before they could. Asked for from the couch, and the answer was theirs:
    // the row of controls becomes one CONTINUE button, and the report comes up
    // when it is pressed. See the footer's `f.finished` branch.
    //
    // The sting still plays; nothing else happens on its own.
  }

  /// Leave the commentary page — but only if it is still the page on top.
  ///
  /// **`maybePop` pops whatever is topmost**, and at full time that need not be
  /// this screen: a subs panel or a coach card is a route the PLAYER put there,
  /// and the whistle's own timer would close it and leave the finished match
  /// sitting behind it. Whatever is on top asks again on its way out, so the
  /// screen still leaves — a beat later, when the player is done.
  void _leaveFullTime() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final leave = widget.onLeave;
    if (leave != null) {
      leave(context);
      return;
    }
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
      sentOff: _sentOff,
      sentOffSlots: _sentOffSlots,
      cautioned: _cautioned,
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
  ///
  /// **AND IT SAYS SO OUT LOUD FIRST, which is the half that was missing.**
  /// Every one of the four guards below used to be a silent `return`, so an
  /// injury that arrived while another card was up, or with the changes spent,
  /// or with nobody fit on the bench, was a line in a scrolling feed and
  /// nothing else — the manager finished a man light having never been told.
  /// Reported from the couch: a player got injured during a game and there was
  /// no notification of it at all.
  ///
  /// So the card comes first and the bench comes after it, and each refusal
  /// says which one it is. `match.subs.injury_head_any`,
  /// `match.subs.injury_tip`, `match.subs.injury_tip_none` and
  /// `match.subs.injury_tip_full` are four shipped strings in ten languages
  /// with no caller in `lib/` — the whole of this announcement was already
  /// written and nothing could print a word of it.
  ///
  /// **A SENT-OFF MAN'S SQUARE IS NOT AN INJURY HOLE.** `_playerSentOff`
  /// empties his row too — that is what makes the engine field ten — so after
  /// a red card this counted his square among the holes: two holes made the
  /// panel open with nothing preselected, and one hole (his) opened the bench
  /// straight onto the square nobody may fill. See [_sentOffSlots].
  Future<void> _onInjuryShown([String? player]) async {
    if (frame.finished) return;
    final holes = [
      for (final slot in ref.read(pitchSlotsProvider))
        if (slot.cardInstanceId == null)
          if (!_sentOffSlots.containsKey(slot.slotId)) slot.slotId,
    ];
    if (holes.isEmpty) return;

    // Who is left to bring on, at the hole's own position when there is only
    // one — the same list the bench sheet will offer.
    final cover = holes.length == 1
        ? ref
              .read(
                slotCandidatesProvider(
                  ref
                          .read(pitchSlotsProvider)
                          .where((s) => s.slotId == holes.first)
                          .firstOrNull
                          ?.slotPosition ??
                      'MID',
                ),
              )
              .where((SlotCandidate c) => !_withdrawn.contains(c.instanceId))
              .firstOrNull
        : null;
    final spent = _subsUsed >= PlayerEnergy.maxSubs;
    final nobody = holes.length == 1 && cover == null;

    // **HELD, so the card is not read over a match still running.** A
    // substitution is the manager's answer to this and `openSubs` holds it
    // anyway; the difference is that the question now holds it too.
    if (_paused) return;
    setState(() => _paused = true);
    await showCoachCard<void>(
      context,
      titleKey: 'match.subs',
      bodyKey: 'match.subs.injury_head_any',
      bodyParams: {'name': player ?? t('common.player')},
      extraTexts: [
        if (spent)
          t('match.subs.injury_tip_full')
        else if (nobody)
          t('match.subs.injury_tip_none')
        else if (cover != null)
          t('match.subs.injury_tip', {'name': cover.card.name}),
      ],
      actions: [
        CoachAction(
          labelKey: spent || nobody ? 'common.ok' : 'match.subs',
          onTap: () {},
        ),
      ],
    );
    if (!mounted) return;
    setState(() => _paused = false);
    if (spent || nobody) return;
    if (frame.finished) return;
    await openSubs(openOn: holes.length == 1 ? holes.first : null);
  }

  /// **THE CARD IS EXPLAINED, then the bench is opened.**
  ///
  /// A red is the one thing that happens in a match with rules a player may not
  /// know: the man is gone, he cannot be replaced, the substitution is NOT
  /// spent, and he misses the next one as well. That is four facts, which is a
  /// coach card rather than a toast — asked for from the couch in those words.
  ///
  /// The panel opens behind it because the ten who are left are now in the
  /// wrong shape, and moving them is the only thing the manager can still do
  /// about it.
  /// Who is carrying a caution, and who has gone.
  ///
  /// Live sets rather than a re-read of `_bookings`, because what the panel
  /// needs is the state at THIS minute — a card shown in the eightieth is not
  /// something the manager was living with at half time.
  final Set<String> _cautioned = <String>{};

  /// **THEIR referee, counted rather than named.** The port never names an
  /// opposition player — see the feed's own note on why their card reads about
  /// the club — so there is no id to hang a multiplier on and no lineup to take
  /// a man out of. What there is, is a tally, and
  /// `booking_engine.oppTeamRatingMult` is what turns it into the same cut our
  /// own side takes by construction.
  int _oppYellows = 0;
  int _oppSendOffs = 0;

  /// Which of their cards have already been counted, so watching and skipping
  /// cannot both count the same one. Ours are guarded by [_cautioned] and
  /// [_sentOff] being sets; theirs had nothing until this, and a fully watched
  /// match re-tallied every opposition card at the whistle.
  final Set<String> _oppCardsSeen = <String>{};

  /// **WHAT THE LAST RE-SIM ROLLED WITH, and why it is not on the result.**
  ///
  /// `reSimulateRemainder` fills this rather than stamping the result, because
  /// the result is compared field for field against a node dump and bookings
  /// are a mechanic the JS has never had. So the divergence lives on the
  /// screen, which is where this repo's rule puts one. Empty until something
  /// re-simulates, and the board falls back on the kickoff figures then.
  final Map<String, dynamic> _liveRatings = <String, dynamic>{};
  final Set<String> _sentOff = <String>{};

  /// Colin has already spoken about a booking this match.
  ///
  /// **Once, and only once.** The nudge is worth having; a card that reappears
  /// every time the referee reaches for a pocket is the game interrupting a
  /// match to say something the manager has already heard.
  bool _bookingAdvised = false;

  /// **A CAUTION MAKES HIM WORSE, and the bench might already be better.**
  ///
  /// Asked for in exactly that shape: the ten per cent comes off, and if that
  /// puts somebody on the bench above him, Colin says so. It is a nudge and not
  /// a change — the swap is the manager's, through the panel they were already
  /// going to use.
  ///
  /// Silent when there is nobody better, nobody left to bring on, or the man
  /// has already been withdrawn. A prompt to make a substitution you cannot
  /// make is worse than no prompt.
  Future<void> _onBooked(String id, String player) async {
    if (!mounted || frame.finished || _bookingAdvised) return;
    if (_withdrawn.contains(id)) return;
    if (_subsUsed >= PlayerEnergy.maxSubs) return;
    final slot = ref
        .read(pitchSlotsProvider)
        .where((s) => s.cardInstanceId == id)
        .firstOrNull;
    if (slot == null) return;
    final booked = (slot.effRating * yellowCardRatingMult).round();
    final best = ref
        .read(slotCandidatesProvider(slot.slotPosition))
        .where((SlotCandidate c) => !_withdrawn.contains(c.instanceId))
        .firstOrNull;
    if (best == null || best.effRating <= booked) return;
    _bookingAdvised = true;
    if (!mounted) return;
    // **IT IS A REMARK, so it behaves like every other thing he says.**
    //
    // It went through a card, then through a small bespoke bubble, and both
    // were wrong in the same way: it paused the match, it lost his head, the
    // bubble was narrower than the one every other line uses, and it carried a
    // button that made the substitution for you. Reported from the couch, in
    // those terms — "it shouldn't pause game, it shouldn't have a button to
    // take them off, its our decision at that point."
    //
    // So it is `_say`, which is the same channel as his reaction to a goal:
    // the head, the full-width bubble, the pitch still lit and still running,
    // and it clears itself after [_coachDwell]. The manager opens the subs
    // panel if they want to; the tip's job is to tell them there is a decision
    // to make, not to make it.
    _say(
      t('coach.booked.body', {
        'player': player,
        'rating': booked,
        'sub': best.card.name,
        'subRating': best.effRating,
      }),
    );
  }

  /// **THE EXPLANATION IS A TUTORIAL, SO IT IS SPENT ONCE.**
  ///
  /// A sending-off is the one event in a match whose RULES are not obvious —
  /// the man is gone and the substitution is not refunded — so it is worth a
  /// card the first time it happens to somebody. It is worth nothing the
  /// second time, and reported as exactly that from the couch: "this can
  /// happen once as a tutorial, but after this one time it should just go
  /// straight to the bench." So it goes through `seenTips`, the same ledger
  /// every other once-only explanation in the game is spent from.
  Future<void> _onSendingOff(String player) async {
    if (!mounted || frame.finished) return;
    final game = ref.read(gameProvider);
    if (!hasSeenTip(game.state, redCardTipId)) {
      game.update((s) => markTipSeen(s, redCardTipId));
      setState(() => _paused = true);
      await showCoachCard<void>(
        context,
        titleKey: 'coach.red_card.title',
        bodyKey: 'coach.red_card.body',
        bodyParams: {'player': player},
        actions: [
          CoachAction(labelKey: 'coachtip.tap_dismiss', onTap: () {}),
        ],
      );
      if (!mounted) return;
      setState(() => _paused = false);
    }
    if (!mounted || frame.finished) return;
    await openSubs();
  }

  /// The ledger id the red-card explanation is spent from.
  static const String redCardTipId = 'red_card_rules';

  /// Everyone taken off this match.
  ///
  /// **On the SCREEN, not the panel**, and that is the whole of the fix: the
  /// panel used to own this while `used` was passed in from here, so closing and
  /// reopening it forgot who had been withdrawn and two taps put a substituted
  /// man back on the pitch. It belongs with [_kickoffLineup] — both are facts
  /// about the match rather than about the sheet that happens to be open.
  final Set<String> _withdrawn = <String>{};

  /// Slot id → the man the referee took out of it. See [_playerSentOff].
  final Map<String, PitchSlot> _sentOffSlots = <String, PitchSlot>{};

  /// Record a change the panel has already written to the save.
  ///
  /// **What the quests read is stamped here.** `subsUsed` and `subbedOnIds` are
  /// things the MANAGER did rather than things the dice did, which is the whole
  /// appeal of asking for them — and until there was a panel neither could move
  /// off its kickoff value, so `match_use_subs` and `match_sub_scores` were two
  /// quests that could not advance.
  void _onSub(SubMade sub) {
    _subsUsed++;
    // **And an injured man counts as withdrawn**, which he now is: the panel
    // resolves an empty square to whoever the hole belongs to, so `offId` is
    // the casualty rather than null. He must not come back on either, and this
    // is the set that stops it. Still null for a slot that started empty —
    // there is genuinely nobody to remember.
    if (sub.offId != null) _withdrawn.add(sub.offId!);
    widget.result['subsUsed'] = _subsUsed;
    final on = widget.result['subbedOnIds'];
    final onList = on is List ? on : <Object?>[];
    onList.add(sub.onId);
    widget.result['subbedOnIds'] = onList;
    // Both names and the minute, for the full report that is coming: the list
    // above is for the quests, and it knows neither who went off nor when.
    final made = widget.result['subs'];
    final madeList = made is List ? made : <Object?>[];
    madeList.add({
      'minute': _minute,
      'onId': sub.onId,
      'offId': sub.offId,
      'on': cardById(ref.read(gameProvider).state, sub.onId)?.name() ?? '',
      'off': sub.offId == null
          ? ''
          : cardById(ref.read(gameProvider).state, sub.offId!)?.name() ?? '',
    });
    widget.result['subs'] = madeList;

    // **AND THE REST OF THE MATCH IS PLAYED BY THE SIDE THAT IS ON IT.**
    //
    // The scoreline is generated at kickoff, and everything that changes the
    // ELEVEN re-rolls what is left: a tactic switch has always done it, a
    // sending-off does it now, and a substitution did not — so bringing your
    // best striker on at 60' changed nothing at all about the result.
    //
    // **`match_sub_scores` is the proof rather than the opinion.** That quest
    // asks for a goal attributed to a man who came on, `reSimulateRemainder`
    // draws its scorers from the LIVE lineup, and nothing re-drew them after a
    // change — so no such event could exist and the quest was unwinnable. The
    // panel writes the swap to the save before this runs, so the lineup this
    // re-rolls against is the one with him on it.
    // **The injuries are LEFT ALONE.** A substitution changes who is on the
    // pitch, not how dangerously the side is playing — see the flag's own note.
    _resimulate(_minute, _strategy, rerollInjuries: false);

    final state = ref.read(gameProvider).state;
    final onName = cardById(state, sub.onId)?.name() ?? '';
    // **A HOLE HAS A NAME, and the panel is the one that knows it.**
    //
    // `SubMade.offId` is who came off, and it used to be null for an INJURY —
    // which is not "nobody" at all: the sim vacated that square before the
    // screen opened, so somebody walked off it. So the row read
    // `match.subs.feed_on` — "{on} comes on." — under the head SUBS, and the
    // one change a manager did not choose to make was the one nothing would
    // explain. `SubsPanelState` fills it from the hole's `vacatedById` on both
    // its paths now, so this reads one field and there is no second answer
    // here to disagree with it.
    final offName = sub.offId == null
        ? null
        : cardById(state, sub.offId!)?.name();
    setState(() {
      _notes.add((
        minute: _minute,
        type: 'subs',
        // Only a slot that started the match EMPTY has nobody to name now.
        key: offName == null || offName.isEmpty
            ? 'match.subs.feed_on'
            : 'match.subs.feed',
        params: {'on': onName, 'off': offName ?? ''},
        seed: 'sub-$_minute-${sub.onId}',
        goal: null,
        // **BOTH MEN, because a substitution is two of them.** The row used to
        // carry only the arrival — see [FeedLine.offId].
        aboutId: sub.onId,
        card: null,
        playerId: null,
        offId: offName == null || offName.isEmpty ? null : sub.offId,
      ));
      _timeline = timelineOf(widget.result, bookings: _bookings);
    });
  }

  /// Put the kickoff eleven back, then cover whatever hole the match left in it.
  ///
  /// The rule itself is `restoreKickoffLineup` in `engine/lineup_engine.dart`,
  /// which is where it can be tested without a match running: what a slot goes
  /// back to depends on what it held at the FIRST whistle, and an injured man
  /// never goes back at all.
  ///
  /// **It runs at every full time, not only after a substitution.** The old
  /// guard was `_subsUsed == 0`, on the reasoning that the screen should put
  /// back what it altered and nothing else — but an injury is a hole this screen
  /// did not make and is the one thing that MUST be covered before the next
  /// fixture, and a manager who saw the casualty and made no change is exactly
  /// the case that left the side a man light with no warning. The write is one
  /// at the end of a match that has just written a result anyway, and the
  /// engine answers whether anything actually moved, and a match that changed
  /// nothing writes nothing — which is what the old guard was really protecting
  /// and it protects it without also skipping the injury case.
  void _restoreKickoffLineup() {
    if (_lineupRestored || _kickoffLineup.isEmpty) return;
    _lineupRestored = true;
    final game = ref.read(gameProvider);
    final state = game.state;
    if (state == null) return;
    final kickoff = <String, String?>{
      for (final row in _kickoffLineup)
        '${row['slotId']}': row['cardInstanceId'] as String?,
    };
    // Mutated in place and the save armed only if it moved: `update` schedules
    // a write unconditionally, and a debounced write at the end of EVERY match
    // is a timer left running behind a screen that has already gone.
    if (!restoreKickoffLineup(state, kickoff)) return;
    game
      ..scheduleSave()
      ..notifyChanged();
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
  /// **A SENDING-OFF IS A CHANGE TO THE SIDE, so the rest of the match is
  /// played by the side that is left.**
  ///
  /// The card used to be pure theatre. The scoreline is decided at kickoff by
  /// `generateMatchEvents` and the port cannot touch that — it is pinned field
  /// for field — but `reSimulateRemainder` exists for exactly this shape of
  /// problem and reads the LIVE lineup out of the save. It is what a mid-match
  /// tactic switch already goes through.
  ///
  /// So the slot is emptied first and the remainder re-rolled against ten men,
  /// under the tactic already being played. Reported from the couch: the rating
  /// did not move, so there was no way to tell whether losing the player had
  /// counted for anything.
  void _playerSentOff(String instanceId, int minute) {
    // **WHERE HE WAS STANDING, taken before the square is cleared.** The
    // clearing is what makes the engine field ten, and it is also what turned
    // his square into an ordinary hole the bench offered to fill. The panel
    // draws him back into it from this.
    final was = ref
        .read(pitchSlotsProvider)
        .where((s) => s.cardInstanceId == instanceId)
        .firstOrNull;
    if (was != null) _sentOffSlots[was.slotId] = was;
    ref.read(gameProvider).update((state) {
      final squad = state['squad'];
      if (squad is! Map<String, dynamic>) return;
      final lineup = squad['lineup'];
      if (lineup is! List) return;
      for (final row in lineup) {
        if (row is Map<String, dynamic> && row['cardInstanceId'] == instanceId) {
          row['cardInstanceId'] = null;
        }
      }
    });
    // Same reasoning as a substitution: losing a man is not a change of
    // approach, so the injuries the match had coming still come.
    _resimulate(minute, _strategy, rerollInjuries: false);
    if (mounted) {
      setState(() => _timeline = timelineOf(widget.result, bookings: _bookings));
    }
  }

  /// **A SKIPPED MATCH IS STILL A MATCH SOMEBODY WAS SENT OFF IN.**
  ///
  /// `skipToEnd` jumps the clock rather than running it, so the per-minute
  /// dispatch never fires and a red card the player skipped past had no effect
  /// at all: eleven men for the whole ninety, and a scoreline decided as though
  /// nothing had happened. Watching and skipping have to agree about what the
  /// match WAS.
  ///
  /// Earliest first, so two dismissals compose the way they would have on the
  /// clock. The ban itself is written separately and was never affected — it
  /// comes off `_bookingRecords` at the whistle.
  void _catchUpSendingsOff() {
    // **EVERY CARD, not only the ones that ended somebody's afternoon.** This
    // caught up the sendings-off and nothing else, which was right while a
    // dismissal was the only card that changed anything. It is not any more: a
    // caution takes ten per cent off the man who got it and the opposition's
    // own referee now cuts their rating too, so a skipped match that ignored
    // both would go back to being decided by a scoreline nobody's cards had
    // touched — the exact fault this method was written for.
    //
    // In MINUTE ORDER, each one re-simulating from its own minute, because that
    // is what watching does. Composing them any other way would have an
    // eightieth-minute booking retro-actively weakening a side for the twentieth
    // minute of the same match.
    final missed = [
      for (final b in _bookings)
        if (b['type'] == 'booking') b,
    ]..sort((a, b) => ((a['minute'] as num?) ?? 0).compareTo((b['minute'] as num?) ?? 0));

    for (final b in missed) {
      final minute = ((b['minute'] as num?) ?? 0).toInt();
      final card = '${b['card'] ?? cardYellow}';
      final sendsOff = cardSendsOff(card);
      if (b['team'] == 'away') {
        final id = b['playerInstanceId'];
        if (!_oppCardsSeen.add(id is String ? id : '$minute-$card')) continue;
        if (sendsOff) {
          _oppSendOffs++;
          if (card == cardSecondYellow && _oppYellows > 0) _oppYellows--;
        } else {
          _oppYellows++;
        }
        _resimulate(minute, _strategy, rerollInjuries: false);
        continue;
      }
      final who = b['playerInstanceId'];
      if (who is! String) continue;
      if (sendsOff) {
        if (_sentOff.contains(who)) continue;
        _cautioned.remove(who);
        _sentOff.add(who);
        // Vacates his slot and re-simulates from his minute.
        _playerSentOff(who, minute);
      } else {
        if (!_cautioned.add(who)) continue;
        _resimulate(minute, _strategy, rerollInjuries: false);
      }
    }
  }

  /// Re-roll `[minute + 1, 90]` against the save as it stands now.
  ///
  /// **The split is the JS's and its reasoning is worth keeping:** events whose
  /// minute has PASSED are kept — they have either fired or are guaranteed to,
  /// a goal whose cutaway is still playing being the case that matters — and
  /// the baseline goals are counted from those kept EVENTS rather than from the
  /// scoreboard tally. Passing the tally would drop a goal the feed has already
  /// promised, and the screen would end 2-1 with the engine calling it a draw.
  void _resimulate(int at, String strategyId, {bool rerollInjuries = true}) {
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
      strategyId,
      ours,
      theirs,
      ref.read(gameProvider).state,
      rerollInjuries: rerollInjuries,
      // **EVERY re-sim carries the cards, not just the one a card caused.** A
      // tactic switch after a booking must not quietly un-book anybody, so the
      // referee's state is read here rather than passed by the caller that
      // happens to know about it. A man already sent off is not in `_cautioned`
      // and is out of the lineup anyway; one already withdrawn is off the
      // pitch, so his caution stops costing.
      bookedMultipliers: bookedRatingMultipliers(
        _cautioned.where((id) => !_withdrawn.contains(id)),
      ),
      oppRatingMult: oppTeamRatingMult(_oppYellows, _oppSendOffs),
      liveRatingsOut: _liveRatings,
    );
    widget.result['events'] = [...kept, ...fresh];
  }

  void applyStrategy(String id) {
    if (frame.finished || id == _strategy || _tacticCooldown) return;
    final strat = strategies[id];
    if (strat == null) return;

    final at = _minute;
    _resimulate(at, id);

    // What the quests and the achievements read. `strategiesUsed` opens with
    // the tactic the side kicked off in, so a switch is genuinely a second
    // entry rather than the first.
    widget.result['strategyChanged'] = true;
    final used = widget.result['strategiesUsed'];
    final usedList = used is List ? used : <Object?>[_strategy];
    if (!usedList.contains(id)) usedList.add(id);
    widget.result['strategiesUsed'] = usedList;
    widget.result['finalStrategy'] = id;
    // **AND WHEN, which nothing recorded.** `strategiesUsed` says a side played
    // Counter at some point and `finalStrategy` says it finished there; neither
    // says the manager went defensive on the hour and saw it out. That is the
    // half a report wants — see `match_report.dart`. Asked for from the couch:
    // "we know the context of the tactics used… we have that info so we should
    // use it."
    final log = widget.result['strategyLog'];
    final logList = log is List ? log : <Object?>[];
    logList.add({'minute': at, 'id': id});
    widget.result['strategyLog'] = logList;
    if (id == _coachSuggestion) {
      widget.result['followedCoachSuggestion'] = true;
    }

    setState(() {
      _strategy = id;
      _timeline = timelineOf(widget.result, bookings: _bookings);
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
        card: null,
        playerId: null,
        offId: null,
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
      // **The tactic the side is playing, which on this screen CAN change.**
      // It was read off the result — a field nothing writes until a switch has
      // already happened — so the arrow spent every match before the first
      // switch reading Balanced. See [kickoffStrategy].
      strategyId: _strategy,
    );
    final events = feedOf(
      f.shown,
      ourName: us,
      theirName: them,
      isHome: home,
      // **THE CLOCK, so the atmosphere lines cannot run ahead of it.** Every
      // other line in the feed comes from an event `f.shown` has already
      // released; the kick-off pool's spares are minted by the feed itself and
      // were arriving whole. See [feedOf]'s own note.
      minute: f.minute,
      clippedChanceKeys: _clippedChanceKeys,
      // One source for the scorer's name, shared with the clip and the replay
      // badge below — see [feedOf]'s own note.
      nameOf: (id) => cardDisplayName(ref.read(gameProvider).state, id),
    );
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

    // **A DARK TAKEOVER IN BOTH THEMES** — see [darkTakeoverThemeProvider].
    // Every surface on this page was already dark glass and the ink over them
    // was the app's own, so in light mode the commentary was near-black on
    // near-black. Held in a local rather than wrapped inline: the page below is
    // four hundred lines and re-indenting all of it would bury the change.
    final page = Scaffold(
      key: const ValueKey('match-screen'),
      // ON THE SKY, not on the app's page colour. This page is a takeover — it
      // is nearly all panel, with no diorama behind it — so a background that
      // followed the theme put pale panels on a pale page in light mode and the
      // whole match went flat. The same sky the Play screen stands under, at the
      // same tier, so kicking off is not arriving somewhere else.
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: matchBackdrop(
          context: context,
          tier: ref.watch(stadiumTierProvider),
        ),
        // **THE SCRIM IS OUTSIDE THE SAFE AREA, and everything else is inside
        // it.** Colin's dim used to be a `Positioned.fill` in the same Stack as
        // the page, which the `SafeArea` had already inset — so the strip under
        // the notch and the strip over the home indicator stayed at full
        // brightness while the rest of the screen went dark, and the overlay
        // read as a panel rather than as the page being pushed back. Reported
        // directly. His BUBBLE keeps its own `SafeArea(top: false)`, so the
        // words still clear the indicator; only the dim runs edge to edge.
        child: Stack(
          children: [
            SafeArea(
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
                    live: _liveRatings,
                    strategyId: _strategy,
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
                  // **THE POOL, MEASURED — `_syncShellHeight`'s own invariant.**
                  //
                  // The stage and the feed are the two bands that flex and
                  // everything else on the column is fixed, so what they share is
                  // a number worth reading off the layout rather than summing the
                  // fixed bands and hoping. The spec says so in as many words, and
                  // says the first version got it wrong by doing the sum.
                  //
                  // They could not share a pool before because the stage sat at
                  // `Flexible(flex: 0)` in the OUTER column, which `RenderFlex`
                  // lays out with an unbounded main axis — so a `LayoutBuilder`
                  // there measured infinity and the cap had to come from
                  // `MediaQuery` instead. One Expanded around the three of them is
                  // what makes the height askable.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, pool) {
                        final stageHeight = stageBandHeight(
                          width: pool.maxWidth - matchInset * 2,
                          pool: pool.maxHeight,
                          hasTacticStrip: !f.finished,
                        );
                        return Column(
                          children: [
                    SizedBox(
                      // The band, plus the gaps either side of it — those are
                      // inside this box, and `stageBandHeight` measures the
                      // pitch.
                      height: stageHeight + matchGap * 2,
                      child: Padding(
                      // **THE SAME GAP AS EVERY OTHER BAND.** This one was on
                      // `matchGap / 2` to buy back height, which made it the one
                      // seam on the page that did not match the others — read
                      // straight off the screen as the spacing being uneven. The
                      // height it was buying came out of `matchGap` itself
                      // instead, so the column is no taller and the seams agree.
                      padding: const EdgeInsets.fromLTRB(
                        matchInset,
                        matchGap,
                        matchInset,
                        matchGap,
                      ),
                      // As wide as every other box on the page; the height is
                      // [stageBandHeight]'s, decided against the pool above.
                      child: SizedBox(
                        key: _stageKey,
                        width: double.infinity,
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
                                // `2x` is the whole screen's speed, not just
                                // the clock's.
                                fast: _fast,
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
                                // **THE SOUND RIDES THE PICTURE.** Both cues
                                // used to fire on the minute tick, a second or
                                // two before the passage got anywhere near the
                                // shot. See [_clipStruck].
                                onStruck: _clipStruck,
                                onVerdict: _clipVerdict,
                                // Between chances: which way the game is going,
                                // ON the pitch it is going on — in its
                                // perspective and under its lines, where a
                                // sibling in screen space lay flat across the
                                // tilt and spilled over the surround. The stage
                                // drops it while a clip runs.
                                // **THE ARROW GOES AT THE WHISTLE; THE END
                                // NAMES STAY.** Once the numbers are on the
                                // grass, which way the run of play was heading
                                // is a question nobody is asking any more —
                                // two marks over one pitch, one of them about a
                                // match that has finished. Asked for from the
                                // couch, and then dropping the whole widget
                                // took HOME and AWAY off the turf with it, on
                                // the one screen where a column of statistics
                                // most needs them to say which side is which.
                                // Reported from the couch in turn. See
                                // `MomentumArrow.arrow`.
                                onGrass: MomentumArrow(
                                    arrow: !f.finished,
                                    bias: momentumBias(
                                      dangerHome: stats.dangerHome,
                                      isHome: home,
                                    ),
                                    attackingRight: home,
                                    // Shades of the TURF, not of the kit: a solid
                                    // mark on the grass rather than a tint over it.
                                    ours: momentumOurs,
                                    theirs: momentumTheirs,
                                    // **WHOSE END IS WHICH, painted on the
                                    // grass.** The markings are symmetric, so
                                    // "pointing right" carries no information
                                    // unless you already know which end you are
                                    // attacking — which is why the arrow was
                                    // reported as pointing the wrong way when it
                                    // was pointing the right way.
                                    //
                                    // **HOME and AWAY rather than the club
                                    // names.** Two words that fit the goalmouth
                                    // at any club, against a name that has to be
                                    // shrunk or clipped — asked for from the
                                    // couch. They are also the LOUDER answer:
                                    // the board above reads home-side-left, so
                                    // the two words say the same thing the board
                                    // does in the same order, and `play.home` /
                                    // `play.away` are already the words it uses
                                    // for the venue.
                                    leftEnd: t('play.home'),
                                    rightEnd: t('play.away'),
                                  ),
                                onDone: (_) {
                                  if (!mounted) return;
                                  final told = _clippedMinute;
                                  final asked = _replaying;
                                  setState(() {
                                    _clip = null;
                                    _clippedEvent = null;
                                    _replaying = false;
                                  });
                                  // Now it has been told, he can react to it —
                                  // unless the player asked to see it again,
                                  // which is not news.
                                  if (!asked) _dugoutCamFor(told);
                                },
                              ),
                              // **THE WHISTLE FILLS THE PITCH WITH THE
                              // NUMBERS.** The page holds at full time now
                              // instead of leaving on a timer, so the stage has
                              // a job it never had: at the whistle it is a pitch
                              // with nothing happening on it, while what the
                              // ninety minutes came to sat behind the board one
                              // tap away. Asked for from the couch. Only once
                              // the clock has stopped and only while no clip is
                              // running — a replay still owns the grass.
                              if (f.finished && _clip == null)
                                PitchStatOverlay(stats: stats, isHome: home),
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
                    // **THE COMMENTARY IS NOT IN A BOX OF ITS OWN.** Every
                    // line already draws its own plate — that is what makes a
                    // line a line rather than a paragraph — so the `GlassPanel`
                    // around the lot was a box full of boxes, and the two
                    // borders 8px apart down each side were the only thing it
                    // added. Asked for directly. The tab bar it used to hold is
                    // long gone: what is left here is the one thing on the
                    // screen a player actually reads, and the plates carry it.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          feedBandInset,
                          0,
                          feedBandInset,
                          matchGap,
                        ),
                        child: Padding(
                          key: const ValueKey('match-commentary'),
                          // **NOTHING OF ITS OWN.** Six points of air over the
                          // first line, on top of the [matchGap] the band above
                          // already ends in — see the ListView's own padding for
                          // the other half of this.
                          padding: EdgeInsets.zero,
                          child: Stack(
                            children: [
                          Column(
                              children: [
                                Expanded(
                                    child: ListView.builder(
                                      key: const ValueKey('match-feed'),
                                      // **THE BAND'S INSET IS PAID ONCE.**
                                      // [feedInset] went to nothing and
                                      // [feedBandInset] became [matchInset] so
                                      // the commentary would line up with the
                                      // tactic strip above it — and this twelve
                                      // was left putting it straight back, so a
                                      // line still started 25 points in against
                                      // the strip's 13. Reported again from the
                                      // couch as too much margin at the top and
                                      // down both sides. The bottom stays: it is
                                      // what keeps the last line off the buttons.
                                      padding: const EdgeInsets.only(bottom: 12),
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
                                      // **AND THE WRITE-UP IS THE LAST WORD.**
                                      // The feed is newest-first, so the head
                                      // of the list is the end of the match —
                                      // which is where a paragraph about the
                                      // whole of it belongs. It went on the
                                      // summary screen first and was moved on
                                      // sight: the commentary is where a match
                                      // is told.
                                      itemCount:
                                          lines.length +
                                          (_inlineCam == null ? 0 : 1) +
                                          (f.finished ? 1 : 0),
                                      itemBuilder: (context, i) {
                                        if (f.finished) {
                                          if (i == 0) {
                                            // **NO PADDING OF ITS OWN.** The
                                            // card already carries the feed
                                            // plate's own vertical inset, and a
                                            // wrapper on top of it put a second
                                            // margin under the band above —
                                            // reported from the couch as the
                                            // summary being double-margined
                                            // once the tactic strip had gone.
                                            return MatchReportCard(
                                              result: widget.result,
                                              // The match the SCREEN told —
                                              // see the card's own note.
                                              frame: f,
                                            );
                                          }
                                          i -= 1;
                                        }
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
                                          );
                                        }
                                        return _feedLine(
                                          lines[lines.length - 1 - i],
                                        );
                                      },
                                    ),
                                ),
                              ],
                          ),
                              // **THE CUT-IN IS OFF THE GRASS.** It floated
                              // bottom-right over the pitch, which is where a
                              // broadcast puts one — over a stat board. This
                              // stage is a live pitch for the whole match, so
                              // the goal he was reacting to was followed by a
                              // move he was standing in front of. The corner of
                              // the commentary is the one place on the page
                              // nothing is happening: the feed is newest-first,
                              // so what he covers is the oldest lines.
                              if (_cam case final shot?
                                  when shot.variant == CamVariant.float)
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: LayoutBuilder(
                                    builder: (context, box) => SizedBox(
                                      width: (box.maxWidth * camFloatFraction)
                                          .clamp(camFloatMinWidth, camFloatMaxWidth)
                                          .clamp(0.0, box.maxWidth),
                                      child: _dugoutCam(shot),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    // **NO AIR OF ITS OWN ABOVE IT.** The commentary panel
                    // already ends in `matchGap`, and twelve more here made the
                    // one seam on the page that was twice the others — read
                    // straight off the screen as too much space between the
                    // feed and the buttons.
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    // **ONE BUTTON AT FULL TIME, and it is the way out.**
                    //
                    // This was empty, because the whistle used to leave the page
                    // on a timer and a button for something that was going to
                    // happen anyway is a tap that races it. The timer has gone —
                    // it was taking the commentary away from a player who wanted
                    // to read it back — so the row that held speed, subs and
                    // skip becomes the one control there is anything left to do
                    // with. The three it replaces are all dead by now anyway:
                    // there is no clock to speed up, no substitution to make and
                    // nothing left to skip.
                    child: f.finished
                        ? SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const ValueKey('match-continue'),
                              style: matchControlStyle(
                                context,
                                face: Theme.of(
                                  context,
                                ).extension<KitTheme>()!.accent,
                              ),
                              onPressed: _leaveFullTime,
                              child: _ControlFace(
                                glyph: 'play',
                                label: t('common.continue'),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              // **A FACE, not a hole.** The outline form's face
                              // is transparent by design — right for a cancel
                              // beside an action, wrong for the only row of
                              // controls on a page whose ground is a sky, where
                              // it read as three empty outlines with the
                              // stadium showing through. Reported directly.
                              // `mouldedButtonStyle` rather than `styleFrom`:
                              // a moulded button's face is painted in a
                              // `backgroundBuilder`, so `backgroundColor:`
                              // colours the layer UNDERNEATH it and fails
                              // silently. See `store_button.dart`.
                              OutlinedButton(
                                key: const ValueKey('match-speed'),
                                // **THE COLOUR IS THE STATE.** It is a toggle
                                // that said which speed it was on in text
                                // alone, in the same grey either way.
                                style: matchControlStyle(
                                  context,
                                  face: _fast
                                      ? Theme.of(
                                          context,
                                        ).extension<KitTheme>()!.accent
                                      : null,
                                ),
                                onPressed: toggleSpeed,
                                child: Text(_fast ? '2×' : '1×'),
                              ),
                              const SizedBox(width: 8),
                              // Subs before skip: one is a decision and the other is
                              // giving up on watching, and the one that takes a
                              // thought should not be the afterthought.
                              Expanded(
                                child: OutlinedButton(
                                  key: const ValueKey('match-subs'),
                                  // **THE SAME FACE AS SKIP.** It wore
                                  // `vsGreenPlate`, which put three different
                                  // colours in a row of three buttons and made
                                  // the green one look like a confirmation.
                                  // Reported from the couch: "not sure why
                                  // Subs is green, it should just be the same
                                  // as Skip Match." The speed toggle keeps its
                                  // colour because there the colour IS the
                                  // state.
                                  style: matchControlStyle(context),
                                  onPressed: openSubs,
                                  child: _ControlFace(
                                    glyph: 'squad',
                                    label: t('match.subs'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  key: const ValueKey('match-skip'),
                                  style: matchControlStyle(context),
                                  onPressed: skipToEnd,
                                  child: _ControlFace(
                                    glyph: 'skip',
                                    label: t('common.skip'),
                                  ),
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
              // **THE SAME SHAPE HE TAKES EVERYWHERE ELSE**, which is what
              // was asked for: up from the bottom-left corner, the page dimmed
              // a little behind it, and a tap anywhere is done with it. It was
              // a head-and-bubble of its own, laid across the width of the
              // screen at a fixed height, with no scrim and no way to dismiss
              // it but waiting.
              //
              // `startOpen`, because this one is a REACTION — something just
              // happened on the pitch — and a reaction that waits to be tapped
              // is not one. See [CoachCorner.startOpen].
            ],
          ),
            ),
            if (_coachLine case final line?)
              Positioned.fill(
                child: CoachCorner(
                  key: ValueKey(line),
                  idPrefix: 'match-coach',
                  bubbleKey: const ValueKey('match-coach-line'),
                  text: line,
                  startOpen: true,
                  pulse: false,
                  // **THE PITCH STAYS LIT.** He is reacting to something
                  // that just happened on it, and the match does not stop
                  // while he says so — dimming the grass dimmed the one
                  // thing on the page still moving. Asked for directly.
                  litArea: _stageKey,
                  onDismissed: () => setState(() => _coachLine = null),
                ),
              ),
          ],
        ),
      ),
    );
    return page;
  }

  /// One row of the feed, with a replay on it once the whistle has gone.
  ///
  /// **NOT DURING THE MATCH, which is the whole of the rule.** `MatchPopup.js`
  /// tags every goal's feed item with `feed-replay-icon` and the port carried
  /// that across; asked for from the couch to take it out, because the ninety
  /// minutes are a thing you WATCH and a control that stops the clock to show
  /// you a passage you are still in the middle of is the wrong offer at the
  /// wrong moment.
  ///
  /// At full time it is the right offer, and this is where it goes: on the LINE
  /// that describes the moment, where the player is already reading about it. It
  /// spent one round as a strip of minute chips on the stats panel over the
  /// pitch and was asked for here instead — a `10'` on a panel is a reference to
  /// a sentence three inches away, and the sentence can carry the button itself.
  ///
  /// **Only what the pitch actually SHOWED.** `clipFor` refuses a chance for the
  /// pacing gap or for a switch the player has turned off, so `retoldMinutes` is
  /// the only honest answer to "is there a passage here" — offering a replay of
  /// something that was never played is a control that does nothing.
  Widget _feedLine(FeedLine line) => _FeedLine(
    line: line,
    text: _textFor(line),
    state: ref.read(gameProvider).state,
    // **AND ONLY ON THE LINE THAT IS ABOUT IT.** The gate was the minute
    // alone, and two things can land on the same one — a tactic change made
    // during a goal's own minute came out carrying that goal's Replay,
    // reported from the couch. A passage belongs to the row that describes it,
    // which is the goal or the chance.
    onReplay:
        !frame.finished ||
            !_replayableLine.contains(line.type) ||
            !retoldMinutes.contains(line.minute)
        ? null
        : () => replayMoment(line.minute),
  );

  /// The two kinds of feed row the 2D pitch ever retells.
  static const Set<String> _replayableLine = {'goal', 'chance'};

  /// What this line says, decided once — see [_lineText].
  ///
  /// **THE KEY IS PART OF THE CACHE KEY, and leaving it out printed the same
  /// sentence twice.** `feedOf` seeds a commentary row on its MINUTE — `1-c` —
  /// so two commentary events in the same minute shared a cache entry and the
  /// second one rendered the first one's text. The grudge match is where that
  /// shows: the engine inserts `commentary.snub` at minute 1 and the opening
  /// flow line is already there, so a hostile fixture opened by saying the same
  /// thing twice. Reported from the couch.
  ///
  /// The seed still decides WHICH variant of a pool is picked — that is what
  /// makes a line stable across rebuilds — and the key decides which pool. Two
  /// different pools in one minute are two different lines.
  String _textFor(FeedLine line) => _lineText.putIfAbsent(
    '${line.type}-${line.seed}-${line.key}',
    () => tPoolUnused(line.key, line.seed, _poolUsed, line.params),
  );

  /// **PLAY A RETOLD MOMENT AGAIN, on the same grass.**
  ///
  /// Full time only, from the panel over the pitch. The clip is rebuilt from the
  /// minute and the match's own seed — the same two numbers the live cut used —
  /// so what comes back is the passage that was played rather than another draw
  /// from the same table.
  ///
  /// **The switches and the pacing gap are not consulted.** Both exist to stop
  /// the screen cutting away on its own; this is the player asking for something
  /// they have already seen, and a control that refuses the thing it offers is
  /// worse than no control.
  void replayMoment(int minute) {
    if (_clip != null) return;
    final event = _retold.where((e) => e.minute == minute).firstOrNull;
    if (event == null) return;
    final ours = event.team != 'away';
    final clip = clipFor(
      event,
      ourSideLeft: widget.result['isHome'] == true,
      ours: ours,
      names: lineupNames(ref.read(gameProvider).state),
      scorerName: clipScorerName(
        ref.read(gameProvider).state,
        event,
        ours: ours,
        nameOf: cardDisplayName,
      ),
      seed: ((widget.result['seed'] as num?)?.toInt() ?? 0) + event.minute,
    );
    if (clip == null) return;
    setState(() {
      _replaying = true;
      _clip = clip;
      _clippedEvent = event;
      _clipScorerId = event.type == 'goal' && ours ? event.scorerId : null;
    });
  }

  /// Which minutes the pitch actually retold — the feed lines that can offer a
  /// replay. **A test seam** as well as the screen's own question.
  Set<int> get retoldMinutes => {for (final event in _retold) event.minute};

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
        ring: glassAccent(context, kit.accentBright),
      ),
      // The SURNAME, as a broadcast caption gives it, and the minute it went
      // in. His full name would not fit under a 72px circle.
      caption: "${card.name(def.name).split(' ').last} $minute'",
    );
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
            fontSize: 12,
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
      //
      // **And a gap under it, the same one that is above it.** It sat directly
      // on the commentary panel, so a control and the thing being read below it
      // were one block — the strip has to end before the reading starts. The
      // gap is `matchGap`, which is what the pitch band above already uses, so
      // the strip sits in equal air rather than being pushed down onto nothing.
      padding: const EdgeInsets.fromLTRB(matchInset, 0, matchInset, matchGap),
      // **AND THE AIR ABOVE IT IS THE AIR BELOW IT.** The cooldown bar was a
      // two-point row UNDER the panel and inside this padding, so the gap below
      // the buttons was eight and the gap above them six — the one seam on the
      // page that did not match, on the control the eye returns to most.
      // It goes inside the clip, which is where this file's own comment said it
      // belonged: it cannot square off the strip's corners from in there, and
      // it costs the column no height at all.
      child: SizedBox(
        key: const ValueKey('match-tactics'),
          // **ROUNDED AT BOTH ENDS, and ON GLASS.** Five square segments in a
          // row read as a slab rather than as one control; the outer two
          // corners are the strip's own and the clip is what closes them. The
          // cooldown hairline is inside the clip too, so it cannot square off
          // what it runs under.
          //
          // The glass is the same pane the scoreboard and the commentary sit
          // on: this was the last band on the screen painting its own surface,
          // which is what made it read as a bar laid over the page rather than
          // as part of it.
        height: 46,
        child: GlassPanel(
                    radius: 10,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Row(
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
              // Only while it is shut. A bar that is always there, empty, is a
              // control the player has to learn to ignore.
              if (cooldown)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  child: TweenAnimationBuilder<double>(
                    key: const ValueKey('match-tactic-cooldown'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: tacticCooldown,
                    curve: Curves.linear,
                    builder: (context, t, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: t,
                        child: ColoredBox(color: glassAccent(context, kit.accentBright)),
                      ),
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
          // **IT SHRINKS RATHER THAN OVERFLOWING.** An icon, a gap and a 12pt
          // line come to 44.4 inside a 46-point strip, which is 1.6 points of
          // headroom — gone the moment a phone is set to a larger system font,
          // and Android's default often is. Reported from a device as an
          // overflow along the bottom of the tactic bar.
          //
          // `scaleDown` only ever acts when the content genuinely will not fit,
          // so at ordinary settings nothing here changes at all.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: active ? tacticInk(context, id) : kit.textMuted,
                  ),
                ),
              ],
            ),
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
    required this.live,
    required this.strategyId,
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

  /// The ratings the remainder was last re-rolled with, or empty when nothing
  /// has re-simulated. See `MatchScreenState._liveRatings`.
  final Map<String, dynamic> live;

  /// The tactic being played RIGHT NOW, so the split moves with the strip.
  final String strategyId;

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
    // The LIVE tactic, handed down. It used to be `result['strategyId']`, which
    // nothing writes until a switch — so the board opened on Balanced's
    // multipliers whatever the card was set to. See [kickoffStrategy].
    final strat = strategies[strategyId] ?? strategies[defaultStrategy]!;
    final mult = tacticMultipliers(
      strat,
      (result['oppAttackRatio'] as num?)?.toDouble(),
    );
    // **THE LIVE FIGURES WHEN THERE ARE ANY, and the kickoff ones otherwise.**
    //
    // Reported from the couch twice over — once about our own caution ("that
    // player's rating drop should also affect the team rating and ATK/DEF on
    // the main card at the top of the match popup") and once about theirs
    // ("opponent got a red card and I did not see that affect their team rating
    // whilst I was in a game"). Both were right and both had the same cause:
    // every number on this board came off the fields the result was stamped
    // with at kickoff, and nothing ever wrote a second set.
    //
    // `reSimulateRemainder` writes the `live*` pair whenever it runs — a
    // tactic switch, a substitution, a sending-off, a booking — and it is the
    // side the remainder was actually rolled with. A match nobody was booked in
    // never re-sims, carries no `live*` fields, and reads exactly as it did.
    //
    // On the SAME basis as the fields they stand in for, so the tactic is still
    // applied here and applied once.
    num liveOr(String liveKey, String kickoffKey) =>
        asNum(live[liveKey] ?? result[kickoffKey]);

    final ourFifa = fifaSplitTactic(
      liveOr('liveAttackRating', 'ourAttackRating'),
      liveOr('liveDefenceRating', 'ourDefenceRating'),
      mult.atk,
      mult.def,
    );
    final theirFifa = fifaSplit(
      liveOr('liveOppAttackRating', 'effOppAttackRating'),
      liveOr('liveOppDefenceRating', 'effOppDefenceRating'),
    );
    final ourSplit = (atk: ourFifa.atk, def: ourFifa.def);
    final theirSplit = (atk: theirFifa.atk, def: theirFifa.def);
    final ourRating = liveOr(
      'liveSquadRating',
      'effectiveSquadRating',
    ).round();
    final theirRating = liveOr('liveOppRating', 'effectiveOppRating').round();
    // A cup tie or an older save may carry no split at all, and four zeroes
    // would be worse than nothing.
    final hasSplit = result['ourAttackRating'] != null;

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
      // **THE PROGRESS BAR IS THE CARD'S BOTTOM BORDER**, not a strip inside
      // it. It is a hairline and it was costing a gap above it and a row of its
      // own; run along the panel's own edge it says the same thing and costs
      // nothing. The panel's bottom padding goes with it, and the bar takes the
      // panel's radius on its two bottom corners so it follows the shape rather
      // than squaring it off.
      // **AND THE DOOR IS DOWN IN THE BUTTON ROW.** It was a `STATS` pill in
      // the board's top-right corner — the one control on the page not in the
      // row of controls, sitting on the scoreboard as if it were part of the
      // scoreline. Asked for directly. The board still takes the tap, which is
      // what keeps the statistics reachable at full time when the row is gone.
      child: GestureDetector(
        key: const ValueKey('match-stats-button'),
        behavior: HitTestBehavior.opaque,
        onTap: onStats,
        child: GlassPanel(
                density: GlassDensity.deep,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // **THE POSITION CHIPS ARE GONE.** They came across from the
            // next-match card, where they answer "who am I playing"; during the
            // match that question is answered and the table is a tap away on
            // the full-time screen. Asked for directly, and the row they cost
            // is the room the clock moved into.
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
                  color: isHome ? glassAccent(context, kit.accentBright) : ink,
                ),
              ),
              // **THE CLOCK GOES BETWEEN THE TWO CLUBS.** It was in the footer
              // beside the competition label, which is the quietest strip on
              // the card — and the gutter above the `VS` is the widest empty
              // space on the whole screen. Asked for directly.
              // **THE MINUTE ONLY — "Full Time" does not fit here and must not
              // try.** The gutter is a fixed `nmGutter` 34px, which is what
              // makes the ratings line up under the club names; a two-word
              // label wraps inside it and grows the row, which moved the whole
              // pitch band down by a line at the whistle. The label goes in the
              // footer strip, where there is width for it.
              gutter: Text(
                "$minute'",
                key: const ValueKey('match-clock'),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  color: glassAccent(context, kit.accentBright),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              right: Text(
                right,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  color: isHome ? ink : glassAccent(context, kit.accentBright),
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
            // **THE FOOTER STRIP IS GONE, and the BOARD is the stats door.**
            // The competition line went first ("Sunday League · Away" is a fact
            // the player brought with them), which left a chart icon alone in a
            // row of its own — asked for directly, and it was the last thing
            // holding that row open.
            //
            // **But deleting the icon outright would strand `MatchStatboard`
            // and `match.tab.stats`**, which is exactly the fault this queue
            // exists to find. So the whole board takes the tap instead: it
            // costs no height at all, and the numbers are what the panel is
            // about, so tapping them to see more of them is where a hand goes
            // anyway.
            if (finished)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  t('match.full_time').toUpperCase(),
                  key: const ValueKey('match-full-time'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: glassAccent(context, kit.accentBright),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: (minute / 90).clamp(0.0, 1.0),
                  backgroundColor: kit.border,
                  valueColor: AlwaysStoppedAnimation(glassAccent(context, kit.accentBright)),
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


class _FeedLine extends StatelessWidget {
  const _FeedLine({
    required this.line,
    required this.text,
    required this.state,
    this.onReplay,
  });

  final FeedLine line;

  /// The sentence, already picked. **Handed in rather than resolved here**: the
  /// feed rebuilds on every tick and the pick has to survive that AND never
  /// repeat within a match, which is a decision only the screen can make once.
  /// See [MatchScreenState._lineText].
  final String text;

  /// Play this moment again on the pitch, or null when there is nothing to play
  /// — every line during the match, and any line at full time the 2D pitch
  /// never retold. See [MatchScreenState._feedLine].
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
    // The sentence arrives already picked — see [text].
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
            ring: isGoal ? glassAccent(context, kit.accentBright) : kit.border,
          );

    // **A SUBSTITUTION IS TWO PLAYERS, and the row was drawing one.**
    //
    // The sentence named both — `match.subs.feed` is "{off} off, {on} on." —
    // but it sat under a single face and the head SUBS, so a change read as an
    // arrival with a footnote. Every commentary feed a player has ever seen
    // gives a substitution a block of its own with the man coming on above the
    // man going off and an arrow on each; that is what was asked for from the
    // couch, against a screenshot of one. The faces and the ids were already
    // here — what was missing was the row knowing about the SECOND man, which
    // is [FeedLine.offId].
    //
    // **Only when BOTH can be drawn.** A card the save has never heard of — a
    // man sold since, or one of theirs, whose players this port never names —
    // falls back to the sentence, which names them in words. Half a swap drawn
    // is worse than a sentence that has them both.
    final offCard = line.offId == null ? null : cardById(state, line.offId!);
    final offDef = getPlayerDef(offCard?.definitionId);
    final swap =
        line.type != 'subs' ||
            about == null ||
            def == null ||
            offCard == null ||
            offDef == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // On above off, which is the order the reference feed uses and
              // the order the change reads in: who is arriving is the news.
              _SwapRow(card: about, def: def, on: true),
              _SwapRow(card: offCard, def: offDef, on: false),
            ],
          );

    // **THE HEAD ROW, and what it is allowed to say.**
    //
    // A minute, and the KIND of thing that happened when there is a word for
    // it. Asked for from the couch: the feed should read like a match report —
    // a goal already gets its card and its heading, and a substitution or a
    // chance going past with nothing but a sentence does not say what it WAS.
    //
    // **Every word here is shipped copy, and three of them were sitting
    // unreached.** `match.subs` is the panel's own title, so both changes — our
    // sub and theirs — are headed by the word the game already uses for one.
    // `match.tab.tactics` named the tab bar that came off this screen, which
    // left it translated in ten catalogues with nothing able to print it, and
    // a tactic change mid-match is exactly what it named. Only the chance
    // needed a word the catalogues did not have: `match.chance` went into the
    // spec's `en.js` and was regenerated, the same way `match.replay` was.
    //
    // Still null for `commentary`, and deliberately: the flow pools are
    // atmosphere — "nerves jangling all around the ground" — and a heading over
    // one claims something happened. A line with no action is a minute over a
    // sentence, which is what those are.
    final action = switch (line.type) {
      'halftime' => t('match.half_time'),
      'fulltime' => t('match.full_time'),
      'injury' => t('match.subs.injured'),
      'subs' || 'opp_sub' => t('match.subs'),
      'tactics' => t('match.tab.tactics'),
      'chance' => t('match.chance'),
      // **THREE WORDS, not one.** A second caution and a straight red are
      // different offences — one is a booking too many, the other is violent
      // conduct or denying a goalscoring opportunity — and a feed that headed
      // both RED CARD would be telling the player the wrong story about the
      // afternoon. Asked for from the couch in exactly those terms.
      'booking' => t('match.card.${line.card ?? cardYellow}'),
      _ => null,
    };

    // **TIME OVER DESCRIPTION, not beside it.** Every line was a minute in a
    // 30-point gutter with the sentence flowing off it, so a long line wrapped
    // back under the gutter and the column the feed is scanned by stopped being
    // a column. Asked for from the couch as a card: the time and what happened
    // on one line, what was said underneath.
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              "${line.minute}'",
              // **READABLE.** It was `textMuted` at 11 over a pane with a
              // gradient behind it, which is the one column a player scans the
              // feed by.
              style: TextStyle(
                color: kit.textMuted,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (line.card case final card?) ...[
              const SizedBox(width: 8),
              CardGlyph(card: card),
            ],
            if (action case final label?) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    // A booking's head wears the card's own colour, so the row
                    // is read before it is read.
                    //
                    // **EXCEPT THE YELLOW ONE.** `cardYellowInk` is the shade a
                    // referee's card is, which is the right colour for a
                    // rectangle and the wrong one for eight letters of text —
                    // reported from the couch as not being readable. The GLYPH
                    // beside it is already carrying the colour, so the words
                    // take the feed's own ink and nothing is lost. A red still
                    // wears its own: it reads at any size, and it is the one a
                    // player must not miss.
                    color:
                        line.card == null || line.card == cardYellow
                        ? glassAccent(context, kit.accentBright)
                        : cardInk(line.card!),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        // **AND THE SWAP REPLACES THE SENTENCE, rather than sitting over it.**
        // Both names are in the two rows; printing "{off} off, {on} on."
        // underneath them is the same information a second time, which is what
        // makes a card read as a paragraph.
        if (swap case final rows?)
          rows
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The face stands IN FOR the ball glyph rather than beside it: two
              // marks in front of one sentence is a row with two subjects. A GOAL
              // never reaches here — it is its own card, and its head carries
              // both.
              if (face != null)
                Padding(padding: const EdgeInsets.only(right: 8), child: face),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: isGoal ? glassAccent(context, kit.accentBright) : null,
                  ),
                ),
              ),
              // A chance the pitch retold is worth seeing again too — see
              // [MatchScreenState._feedLine].
              if (onReplay case final replay?) _ReplayChip(onTap: replay),
            ],
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
      // **GREEN FOR OURS AND RED FOR THEIRS — the SEMANTIC green, not the
      // kit's.** Theirs has been red since the goal card went in; ours took
      // `kit.accent`, which is derived from the club's own strip. A club
      // playing in red therefore drew both goals in red, and the one pair of
      // rows on the screen whose whole job is to be told apart at a glance were
      // the same colour. Reported from the couch. `vsGreenOn` is the green
      // every stat row and every quest verdict already uses for "this went well
      // for us", and it is a colour rather than a kit.
      final scored = goal.ours ? vsGreenOn(context) : conceded;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: feedInset, vertical: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          decoration: BoxDecoration(
            color: scored.withValues(alpha: goal.ours ? 0.15 : 0.13),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: scored, width: 3)),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // **THE BALL AND THE WORD, on BOTH.** Theirs used to be
                  // headed by their NAME on the reasoning that we hold no card
                  // for their players — but the head is the row's ACTION, not
                  // its subject, and every other row in the feed uses it that
                  // way. `commentary.opp_goal` already names them in the
                  // sentence directly underneath, so the head was spending the
                  // one slot that says WHAT HAPPENED on a repeat. Reported from
                  // the couch: it should still say GOAL, the colour is what
                  // says whose.
                  Icon(Icons.sports_soccer, size: 14, color: scored),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t('match.goal_card.title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: scored,
                      ),
                    ),
                  ),
                  Text(
                    '${goal.left}-${goal.right}',
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
                      ring: scored,
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
                                fontSize: 12,
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
                  if (onReplay case final replay?) _ReplayChip(onTap: replay),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // **EACH LINE IS ITS OWN ROW.** They were a run of text down one pane with
    // three points between them, so ninety minutes of commentary read as a
    // paragraph — asked for directly. A plate of its own and a rule under it is
    // what makes a line a line, and it gives the minute down the left a ground
    // to be read off.
    return Padding(
      // **MORE AIR, inside and out.** Asked for from the couch: a bit more
      // padding for the entries. Nine and seven inside a two-point gap read as
      // a stack of strips rather than a stack of cards, and the two-row shape
      // above needs the room to hold together as one entry.
      padding: const EdgeInsets.symmetric(horizontal: feedInset, vertical: 3),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
        decoration: BoxDecoration(
          color: glassInk(context).withValues(alpha: feedPlateFill),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: glassInk(context).withValues(alpha: feedPlateEdge),
          ),
        ),
        child: card,
      ),
    );
  }
}

/// One man in a substitution: his face, which way he is going, and his name.
///
/// **The direction is a GLYPH, not a word.** The catalogues are generated from
/// the spec's own `en.js` and have no copy for "on" or "off" as a label — and
/// none can be added from here — so the arrow carries it, which is what every
/// feed this was modelled on does anyway. Up and green for the man arriving,
/// down and red for the man leaving.
class _SwapRow extends StatelessWidget {
  const _SwapRow({required this.card, required this.def, required this.on});

  final CardInstance card;
  final PlayerDef def;

  /// Coming ON. The arrow, the ring and the weight all follow it.
  final bool on;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // The feed's own two colours — `vsGreenOn` is the green every stat row uses
    // for "this went well for us" and `conceded` is the red a goal against is
    // drawn in. Not the kit's accent: a club playing in red would draw both
    // halves of the swap in one colour, which is the fault the goal card
    // already had and fixed.
    final tint = on ? vsGreenOn(context) : conceded;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          PlayerFace(
            position: def.position,
            tier: def.tier,
            variant: card.variant,
            size: 26,
            ring: tint,
          ),
          const SizedBox(width: 8),
          Icon(
            on ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: tint,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              card.name(def.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          // **AND WHY HE WENT OFF, when the match decided it and not the
          // manager.** An injury is the case this whole row was reported
          // against, and it is the one change a manager did not choose to
          // make. `match.subs.injured` is the word the bench panel already
          // writes over the same man's square.
          if (!on && card.injured) ...[
            const SizedBox(width: 6),
            Text(
              t('match.subs.injured').toUpperCase(),
              // Twelve, not ten: `architecture_test` keeps a floor under every
              // literal on the screen and it caught this one.
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
                color: kit.textMuted,
              ),
            ),
          ],
        ],
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

/// **THE ONE THING WORTH SEEING TWICE.** A goal or a chance goes past while the
/// manager is reading the line above it, and the passage is rebuilt from the
/// minute rather than recorded — so asking for it again costs nothing but the
/// chip.
///
/// It says the word as well as showing the glyph: `match.replay` is real shipped
/// copy in all ten catalogues, and a bare arrow on a row of sentences is a
/// control the player has to guess at.
class _ReplayChip extends StatelessWidget {
  const _ReplayChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return TextButton.icon(
      key: const ValueKey('feed-replay'),
      style: TextButton.styleFrom(
        foregroundColor: glassAccent(context, kit.accentBright),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.replay, size: 15),
      label: Text(t('match.replay'), maxLines: 1),
      onPressed: onTap,
    );
  }
}


