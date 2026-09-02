/// Through Ball — the timing bar.
///
/// A marker ping-pongs across a track and the player taps when it is inside the
/// green zone. Five rounds; the sweep speed is the division's and does not
/// change within a session, while the zone shrinks every round — 100% → 85% →
/// 70% → 55% → 40% of the division's width, floored at 35% so the last round
/// stays hittable down in Sunday League.
///
/// The two pieces of arithmetic — where the marker is at a given moment, and
/// where the zone lands — are pure functions rather than something read back
/// out of the layout. The JS learnt that the hard way: once it moved the marker
/// with a transform, its old trick of parsing the element's `left` scored a miss
/// on every single tap, because `left` was a constant zero from then on.
///
/// **Closing is not a forfeit.** The JS banks what the session was worth on the
/// way out, so a player who leaves after three good rounds keeps them.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/divisions.dart'
    show currentDivisionIndex;
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudCoinInk;
import 'package:merge_empire_fc/ui/screens/minigames/minigame_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Half the marker's width, in logical pixels — the JS's `MARKER_HALF_PX`, and
/// the same reason: the marker is centred on its position rather than hung off
/// its left edge.
///
/// **FOUR, not three.** A six-pixel bar with a one-pixel casing either side has
/// four pixels of ink left in it; eight leaves six, which is a line rather than
/// a hair. Asked for from the couch along with the colour — see [markerInk].
const double markerHalfPx = 4;

/// How long a hit or a miss stays up before the next round starts.
const Duration throughBallFeedback = Duration(milliseconds: 700);

/// One lane's band, and the most air that goes between two of them.
///
/// The gap is shared out of whatever the page has left over — see the stack in
/// `build` — and capped, because five lanes spread the full height of a tall
/// phone stop being one thing to read down.
const double laneHeight = 34;

/// **FORTY, not thirty.** Five bars a third of an inch apart read as one
/// striped block, and the round in play is picked out by nothing but which one
/// has a marker on it. Asked for from the couch: more padding on each. The gap
/// is still shared out of what the page has left over — this is only the cap —
/// so a short screen closes up rather than scrolling.
const double laneGapMost = 40;

/// Where the marker is, as a percentage of the track, [elapsedMs] into a sweep.
///
/// A triangle wave: 0 → 100 → 0 over one [sweepMs], which is a ping-pong rather
/// than a wrap. A sawtooth would snap the marker back across the whole bar every
/// cycle, and the tap window would be a different shape at each end.
double markerPctAt(double elapsedMs, double sweepMs) {
  final phase = (elapsedMs % sweepMs) / sweepMs;
  return (phase < 0.5 ? phase * 2 : (1 - phase) * 2) * 100;
}

/// The green zone for [round], given the division's [baseZonePct].
///
/// [roll] is one `Math.random()` draw in 0..1. The position is randomised so the
/// player cannot rhythm-tap the whole session without watching, and clamped so
/// the shrunk zone still fits inside the track at both ends.
({double lo, double hi, double width}) throughBallZone(
  int round,
  double baseZonePct,
  double roll,
) {
  final shrink = math.max(0.35, 1 - round * 0.15);
  final width = baseZonePct * shrink;
  final half = width / 2;
  final minPos = math.max(ThroughBall.zonePosMinPct, half);
  final maxPos = math.min(ThroughBall.zonePosMaxPct, 100 - half);
  final pos = minPos + roll * math.max(0, maxPos - minPos);
  return (lo: pos - half, hi: pos + half, width: width);
}

class ThroughBallScreen extends ConsumerStatefulWidget {
  const ThroughBallScreen({super.key});

  @override
  ConsumerState<ThroughBallScreen> createState() => ThroughBallScreenState();
}

class ThroughBallScreenState extends ConsumerState<ThroughBallScreen>
    with SingleTickerProviderStateMixin {
  late final StateController<TickGates> _gates;
  late final GameState _game;
  late final Ticker _ticker;
  final math.Random _rng = math.Random();

  double _sweepMs = ThroughBall.sweepEasyMs;
  Duration _sweepStart = Duration.zero;

  /// **All five zones, drawn up front.** The five lanes are all on screen from
  /// the first frame — see the note in `build` — so all five have to KNOW where
  /// their green is before the first one runs. The draws happen in the same
  /// order they used to, one per round, so a session's zones are the sequence
  /// they always were; only the moment of asking moved.
  late final List<({double lo, double hi, double width})> _zones;

  /// Where the marker stopped on each round that has been played, or null for
  /// one that has not. A settled lane keeps its own marker where it landed —
  /// the evidence for the hit or the miss beside it.
  final List<double?> _settled = List<double?>.filled(
    ThroughBall.rounds,
    null,
  );

  /// The marker's position is MODEL state that the sweep writes and the tap
  /// reads, which is the whole point — see the library comment.
  final ValueNotifier<double> _markerPct = ValueNotifier<double>(0);

  int _round = 0;
  int _passed = 0;
  bool _locked = false;
  bool _hitLast = false;
  bool _showFeedback = false;
  bool _over = false;
  bool _banked = false;
  int _coins = 0;
  Timer? _next;

  /// Test seams.
  int get round => _round;
  int get passed => _passed;
  bool get finished => _round >= ThroughBall.rounds;
  double get markerPct => _markerPct.value;
  double get zoneLo => _zoneFor(_round).lo;
  double get zoneHi => _zoneFor(_round).hi;

  ({double lo, double hi, double width}) _zoneFor(int round) =>
      _zones[round.clamp(0, ThroughBall.rounds - 1)];
  int get coinsWon => _coins;
  bool get over => _over;

  /// Put the marker at a known point and hold it there.
  ///
  /// The sweep is real time and a test cannot tap on a particular millisecond,
  /// so the seam is the marker's POSITION — which is the same model value the
  /// tap reads. The JS's own bug is the argument for having one: once the
  /// marker moved by transform, reading its `left` back out of the DOM returned
  /// a constant zero and every tap scored a miss.
  @visibleForTesting
  void placeMarker(double pct) {
    _ticker.stop();
    _markerPct.value = pct;
  }

  @override
  void initState() {
    super.initState();
    _gates = ref.read(tickGatesProvider.notifier);
    _game = ref.read(gameProvider);
    final difficulty = throughBallDifficulty(currentDivisionIndex(_game.state));
    _sweepMs = difficulty.sweepMs;
    _zones = [
      for (var round = 0; round < ThroughBall.rounds; round++)
        throughBallZone(round, difficulty.zonePct, _rng.nextDouble()),
    ];
    _ticker = createTicker(_onTick);
    _startRound();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gates.state = (
        matchOpen: false,
        miniGameOpen: true,
        transferOpen: false,
        colinOnScreen: false,
      );
      // On entry, like every other drill: walking away mid-session must not
      // farm the reward timer.
      _game.update((s) => startMiniGame(s, MiniGameKind.throughBall));
    });
  }

  void _startRound() {
    _locked = false;
    _showFeedback = false;
    _sweepStart = Duration.zero;
    _markerPct.value = 0;
    // `isActive`, not `isTicking` — a ticker muted by an ancestor `TickerMode`
    // is still active, and starting it twice throws.
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_locked) return;
    if (_sweepStart == Duration.zero) _sweepStart = elapsed;
    final since = (elapsed - _sweepStart).inMicroseconds / 1000.0;
    _markerPct.value = markerPctAt(since, _sweepMs);
  }

  void _tap() {
    if (_locked || finished) return;
    final sound = ref.read(soundServiceProvider);
    unawaited(sound.play('tap'));
    _ticker.stop();
    _locked = true;

    final at = _markerPct.value;
    final zone = _zoneFor(_round);
    final inZone = at >= zone.lo && at <= zone.hi;
    if (inZone) _passed++;
    _settled[_round] = at;
    unawaited(sound.play(inZone ? 'goal' : 'goalAgainst'));

    setState(() {
      _hitLast = inZone;
      _showFeedback = true;
      _round++;
    });

    // The summary waits out the feedback beat rather than replacing it — the
    // last round's hit or miss is the one the player most wants to see.
    _next = Timer(throughBallFeedback, () {
      if (!mounted) return;
      if (finished) {
        setState(() {
          _over = true;
          _showFeedback = false;
        });
      } else {
        setState(_startRound);
      }
    });
  }

  /// Bank the session, once.
  int _award() {
    if (_banked) return _coins;
    _banked = true;
    _coins = _game.update(
      (s) => recordThroughBallResult(s, roundsPassed: _passed),
    );
    return _coins;
  }

  void _collect() {
    final coins = _award();
    if (coins > 0) unawaited(ref.read(soundServiceProvider).play('coin'));
    Navigator.of(context).maybePop();
  }

  /// What the session is worth so far, before it is banked.
  int get _preview => roundCoins(
    miniGameRewardBase(_game.state) * ThroughBall.rewardPerRoundMult * _passed,
  );

  @override
  void deactivate() {
    // Closing is not a forfeit — the JS banks on the way out too, so leaving
    // after three good rounds keeps them.
    _award();
    final gates = _gates;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        gates.state = clearScreen;
      } on StateError {
        // The scope went first; nothing left to gate.
      }
    });
    super.deactivate();
  }

  @override
  void dispose() {
    _next?.cancel();
    _ticker.dispose();
    _markerPct.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    return Scaffold(
      key: const ValueKey('through-ball-screen'),
      backgroundColor: kit.bg,
      appBar: const MiniGameHeader(titleKey: 'game.through_ball'),
      // Tapping ANYWHERE registers the hit. The track is a 34px band on a
      // phone and asking for a precise tap on it felt finicky in the JS too.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: finished ? null : _tap,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  t('mg.tap_green'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kit.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('game.throughball.score', {
                        'n': _passed,
                        'total': ThroughBall.rounds,
                      }),
                      key: const ValueKey('tb-score'),
                      style: TextStyle(
                        color: kit.accentBright,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      t('mg.round_n', {
                        'n': math.min(_round + 1, ThroughBall.rounds),
                        'total': ThroughBall.rounds,
                      }),
                      key: const ValueKey('tb-round'),
                      style: TextStyle(
                        color: kit.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // **ALL FIVE LANES, FROM THE FIRST FRAME.** One track was shown
                // at a time and re-drawn between rounds, which spends a whole
                // screen of empty space to show a session one fifth at a time
                // and gives the player nothing to read ahead to. Asked for
                // directly: five lanes stacked, the top one runs first, and the
                // next does not start until the one above it is finished.
                //
                // It also makes the difficulty curve VISIBLE rather than felt —
                // the green shrinks 100% → 85% → 70% → 55% → 40% down the
                // stack, so the last lane's sliver is on screen while the first
                // one is still being aimed at.
                //
                // **AND THE SPARE ROOM GOES BETWEEN THEM.** Five 34pt bands
                // with a 12pt gap is 218pt of a 500pt space, dead centre — the
                // lanes read as one striped block and the screen keeps the rest
                // of the room for nothing. The gap is worked out from what is
                // actually there and the stack sits above centre, which is
                // where the eye is while a marker is running. Asked for from
                // the couch.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final spare =
                          box.maxHeight - ThroughBall.rounds * laneHeight;
                      final gap = (spare / (ThroughBall.rounds + 1)).clamp(
                        12.0,
                        laneGapMost,
                      );
                      return Align(
                        alignment: const Alignment(0, -0.4),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var lane = 0;
                                lane < ThroughBall.rounds;
                                lane++
                              ) ...[
                                if (lane > 0) SizedBox(height: gap),
                                _Track(
                                  kit: kit,
                                  lane: lane,
                                  marker: lane == _round
                                      ? _markerPct
                                      : null,
                                  settledAt: _settled[lane],
                                  zoneLo: _zones[lane].lo,
                                  zoneWidth: _zones[lane].width,
                                  hit:
                                      _settled[lane] != null &&
                                      _settled[lane]! >= _zones[lane].lo &&
                                      _settled[lane]! <= _zones[lane].hi,
                                  live: lane == _round && !_over,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: _showFeedback
                      ? Text(
                          _hitLast ? t('mg.hit') : t('mg.miss'),
                          key: const ValueKey('tb-feedback'),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: _hitLast ? kit.accentBright : Colors.red,
                          ),
                        )
                      : null,
                ),
                if (_over) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Stat(
                        kit: kit,
                        label: t('mg.hits'),
                        value: '$_passed/${ThroughBall.rounds}',
                        valueKey: const ValueKey('tb-hits'),
                        colour: kit.accentBright,
                      ),
                      const SizedBox(width: 18),
                      _Stat(
                        kit: kit,
                        label: t('mg.reward'),
                        value: '+${formatCoins(_preview)} 💰',
                        valueKey: const ValueKey('tb-reward'),
                        colour: hudCoinInk,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const ValueKey('tb-collect'),
                      onPressed: _collect,
                      child: Text(t('common.collect')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One lane. Five of them are on screen at once, and which one is LIVE is the
/// only difference between them.
///
/// A lane that has not had its turn draws its green and nothing else — that is
/// the read-ahead the stack exists for. A lane that has had its turn keeps its
/// marker frozen where it landed, which is the evidence for the hit or the miss
/// rather than a word about it.
class _Track extends StatelessWidget {
  const _Track({
    required this.kit,
    required this.lane,
    required this.marker,
    required this.settledAt,
    required this.zoneLo,
    required this.zoneWidth,
    required this.hit,
    required this.live,
  });

  final KitTheme kit;
  final int lane;

  /// The running marker, and null for every lane that is not this round's.
  final ValueListenable<double>? marker;

  /// Where the marker stopped, for a lane already played.
  final double? settledAt;
  final double zoneLo, zoneWidth;
  final bool hit;
  final bool live;

  @override
  Widget build(BuildContext context) => Opacity(
    // The live lane is the one at full strength. A lane still waiting is
    // knocked back so the eye is not asked to choose between five identical
    // tracks; a played one is knocked back further, since it is a record.
    opacity: live
        ? 1
        : settledAt != null
        ? 0.5
        : 0.72,
    // The zone is laid out in PERCENTAGES of the track, so the width has to be
    // measured rather than assumed — a rotation mid-round changes it, and in
    // the JS a stale cached width was enough to make the two disagree about
    // where the marker was.
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Center(
          child: SizedBox(
            key: ValueKey('tb-lane-$lane'),
            height: laneHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kit.surface2,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: kit.border, width: 2),
                    ),
                  ),
                ),
                Positioned(
                  key: ValueKey('tb-zone-$lane'),
                  left: zoneLo / 100 * w,
                  width: zoneWidth / 100 * w,
                  top: 0,
                  bottom: 0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      ),
                      border: Border.symmetric(
                        vertical: BorderSide(
                          color: Color(0xFF76E876),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                // Only the marker rebuilds on a frame — the score line, the
                // zone and the track are the same widgets for the whole round.
                // It is a full-bleed `Positioned` with the offset inside it
                // rather than a `Positioned` with an animated `left`, because a
                // `Stack` positions only its DIRECT children and an
                // `AnimatedBuilder` between the two would swallow it.
                if (marker case final running?)
                  Positioned(
                    key: ValueKey('tb-marker-$lane'),
                    left: 0,
                    right: 0,
                    top: -4,
                    bottom: -4,
                    child: AnimatedBuilder(
                      animation: running,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          running.value / 100 * w - markerHalfPx,
                          0,
                        ),
                        child: child,
                      ),
                      child: _Marker(colour: markerInk(context)),
                    ),
                  )
                // Frozen where it stopped, in the colour of the answer.
                else if (settledAt case final at?)
                  Positioned(
                    key: ValueKey('tb-marker-$lane'),
                    left: 0,
                    right: 0,
                    top: -4,
                    bottom: -4,
                    child: Transform.translate(
                      offset: Offset(at / 100 * w - markerHalfPx, 0),
                      child: _Marker(
                        colour: hit ? const Color(0xFF76E876) : Colors.red,
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

/// The running marker's colour: the PAGE's ink, not a flat white.
///
/// **White is invisible in light mode**, which is the whole of a report from
/// the couch — the track is `kit.surface2`, and on a daylit page that is very
/// nearly white, so for most of every sweep the one thing the player is aiming
/// with simply was not there. It only appeared as it crossed the green zone.
///
/// The ink flips with the theme and the CASING under it does the rest: the bar
/// has to clear the track (light or dark) AND the fixed mid-green zone, which
/// is the same colour in both themes, so no single flat colour clears
/// everything. A dark bar in a light sleeve, or the reverse, clears all three.
Color markerInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? const Color(0xFF12181F)
    : Colors.white;

/// The sleeve drawn under [markerInk] — the opposite end of the same scale.
Color markerCasing(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? Colors.white
    : const Color(0xFF12181F);

/// The bar that says where the tap landed.
class _Marker extends StatelessWidget {
  const _Marker({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(
      width: markerHalfPx * 2,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(3),
          // The casing, drawn as a border so the bar keeps its own width and
          // the hit maths — which is model state, not layout — is untouched.
          border: Border.all(color: markerCasing(context), width: 1),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.kit,
    required this.label,
    required this.value,
    required this.valueKey,
    required this.colour,
  });

  final KitTheme kit;
  final String label, value;
  final Key valueKey;
  final Color colour;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: TextStyle(color: kit.textMuted, fontSize: 12)),
      Text(
        value,
        key: valueKey,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: colour,
        ),
      ),
    ],
  );
}
