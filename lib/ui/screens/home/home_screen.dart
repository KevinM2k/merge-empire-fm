/// The home screen. Ported from the Overview half of
/// `ui/screens/LeagueScreen.js`.
///
/// **It has no sub-tabs, and that is the point.** The port had a strip of them
/// across the top — Overview, Table, Fixtures, Training — which is the
/// arrangement the JS moved AWAY from. Ten orbs used to run up both sides of
/// the diorama and the scene was carrying more furniture than scene, so nine of
/// them went behind one burger and the strip went with them. What is left is
/// one screen:
///
/// - the scene, with the next fixture over it;
/// - **Coach Colin bottom left**, the one thing here that talks to you;
/// - **the burger bottom right**, holding the table, the fixtures, the index,
///   the quests, the training ground and the trophies;
/// - a sticky footer: the Deadline Day strip, and the button that plays the
///   match.
///
/// The two orbs hang off the footer's TOP edge rather than being measured from
/// the bottom of the screen. That is deliberate in the JS and worth keeping:
/// the footer changes height — an event strip appears, a cup button appears —
/// and anything anchored to a measured height sits at the wrong level the
/// moment the measurement and the real height disagree.
library;

import 'dart:async';

import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/event_strip.dart';
import 'package:merge_empire_fc/ui/screens/home/home_dock.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_idle.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/engine/weather_engine.dart' show windAccelFor;
import 'package:merge_empire_fc/ui/screens/home/pitch_ball.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart';
import 'package:merge_empire_fc/providers/weather_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

/// The vertical seam between the stacked boxes on the Play page.
///
/// Asked for directly, and one number rather than a ten here and a ten there:
/// the seams on this page were set independently and did not agree.
const double playPageGap = 12;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey _sceneKey = GlobalKey();
  final GlobalKey _customiseKey = GlobalKey();

  /// His contact line, above the bottom of the scene.
  ///
  /// MEASURED, not assumed, and measured off the CUSTOMISE PILL rather than off
  /// the footer. The JS stacks the same number by hand — footer 10px up, badge
  /// 12px above that, badge 23px tall, him 12px clear of it — and notes that the
  /// day the Deadline Day strip joined the footer, the two anchors that were
  /// supposed to agree stopped agreeing. There is one anchor here: whatever the
  /// footer grows or loses, the pill moves, and he moves with it.
  ///
  /// The port had him derived from the footer's FULL height, which included the
  /// dock row itself — so he stood a whole orb higher than he should have, in
  /// the middle of the pitch rather than just over the controls.
  double _walkerBottom = 150 + walkerBottomClearance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// 12px, which is the gap the JS puts between the badge and his boots.
  static const double _walkerClearsPill = 12;

  void _measure() {
    final scene = _sceneKey.currentContext?.findRenderObject() as RenderBox?;
    final pill = _customiseKey.currentContext?.findRenderObject() as RenderBox?;
    if (scene == null || pill == null || !scene.hasSize || !pill.hasSize) {
      return;
    }
    // The pill's top edge, in the scene's own coordinates.
    final top = pill.localToGlobal(Offset.zero, ancestor: scene).dy;
    final bottom = scene.size.height - top + _walkerClearsPill;
    if ((bottom - _walkerBottom).abs() < 1) return;
    if (mounted) setState(() => _walkerBottom = bottom);
  }

  @override
  Widget build(BuildContext context) {
    // The footer changes height between builds — an event strip arrives, a cup
    // button appears — so the pill is re-read after every one.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    return Stack(
      key: const ValueKey('home-screen'),
      children: [
        // The scene fills the screen, so it is also the box the pill's position
        // is converted into — measuring against it is measuring against the
        // page.
        // One layer: the diorama's tick repainted the card and footer with it.
        Positioned.fill(
          key: _sceneKey,
          child: RepaintBoundary(child: _Scene(walkerBottom: _walkerBottom)),
        ),
        // The card is the page's HEADLINE and sits at the top, over the scene.
        // The port had it in the sticky footer directly above the Play button on
        // the reasoning that what the button is about to do belongs next to the
        // button — but the card is now five bands deep (standings, clubs, the
        // mirrored stats, the tactic, the match quests) and a footer that tall
        // leaves the diorama a strip. The button is the one thing that never
        // needs introducing.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Padding(
            // Clears the HUD and the notch. The SCENE behind it does not: it
            // runs to the top of the glass, which is the whole point of it.
            // No bar to clear here — just the notch and the floating cluster.
            padding: EdgeInsets.fromLTRB(
              13,
              hudClearanceOf(context, underBar: false),
              13,
              0,
            ),
            child: const NextMatchCard(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, playPageGap),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The dock rail: one row, both orbs and the pill between them,
                  // sharing the footer's top edge so all three are level by
                  // construction rather than by two offsets agreeing on paper.
                  // Bottom-aligned, because the orbs are a disc plus a caption
                  // and the pill is neither — it is their FEET that have to line
                  // up.
                  // **The three docks give before the row does.** Each is a
                  // disc plus a caption and the captions are translated, so on
                  // a 320pt phone in German the rail was four points wider than
                  // the screen. `Flexible` lets a caption ellipsise rather than
                  // the row reporting an overflow; the discs themselves are
                  // fixed and unaffected. Found by the long-language sweep.
                  // **NO SPACERS, AND THE ORBS ARE PINNED TO THE EDGES.** There
                  // were two `Spacer`s between three `Flexible`s, all at flex 1
                  // — so the pill in the middle got a fifth of the row and its
                  // label ellipsised to almost nothing ("the Customise button
                  // is mostly cut off"), while the burger sat centred inside a
                  // slot wider than itself and read as having moved inwards off
                  // the right edge ("the menu button is no longer on the
                  // right"). One layout, two reports.
                  //
                  // The weights give the pill the most room and the `Align`s
                  // put each orb against its own side of the rail whatever is
                  // left over. The captions can still ellipsise inside their
                  // own slot, which is what the long-language sweep asked for.
                  Row(
                    key: const ValueKey('dock-rail'),
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // **ALL THREE ARE `Expanded`, and the outer two are
                      // ALIGNED.** Two things had to be true at once and each
                      // obvious fix broke the other: a loose `Flexible` lets a
                      // dock take the whole slot (its caption is a `Text` and
                      // expands), and the row then packs to the left leaving
                      // the trailing space unused — which is the burger short
                      // of the right edge. Tight slots fix the packing; the
                      // `Align`s put each orb against its own side of the slot
                      // rather than centred in it.
                      const Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: CoachDock(),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          // Clear of the orbs' own captions, and lifted so the
                          // pill's bottom sits on the discs' bottom rather than
                          // under the labels that ride over them.
                          padding: const EdgeInsets.only(bottom: 6),
                          // **CENTRED, so the pill is its own size.** Its `Row`
                          // is `MainAxisSize.min`, but a tight slot stretches
                          // the `Container` round it to the full width — a
                          // lozenge four times the length of the word in it.
                          // The slot's job is to reserve the room; the pill's
                          // job is to be the size of its own contents.
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: CustomiseDock(anchorKey: _customiseKey),
                          ),
                        ),
                      ),
                      // **A COLUMN, not a second orb in the row.** Prestige
                      // leads the right-hand side and the burger stays where
                      // the player's thumb has learned it is — putting the new
                      // orb in the row instead would move the menu every time
                      // a career came up for renewal. It builds nothing at all
                      // on a save that cannot prestige, so the common case is
                      // the burger alone and the row is unchanged.
                      const Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PrestigeDock(),
                              SizedBox(height: 8),
                              MenuDock(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // **TWELVE BETWEEN THE BOXES ON THIS PAGE**, asked for
                  // directly — see [playPageGap]. It was ten here and ten under
                  // the event strip.
                  const SizedBox(height: playPageGap),
                  const EventStrip(),
                  const PlayMatchButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The diorama.
///
/// The division and the fixture number used to sit on it as two lines of text
/// above the figure. They are on the next-match card now, which is where the
/// fixture is described — a heading that names the same match a card directly
/// under it also names was the scene carrying furniture rather than scene.
class _Scene extends ConsumerStatefulWidget {
  const _Scene({required this.walkerBottom});

  final double walkerBottom;

  @override
  ConsumerState<_Scene> createState() => _SceneState();
}

/// The gesture rota, and the tap that jumps its queue.
///
/// **`manager_mood.dart` has carried every gesture, weight and gap since M1 and
/// nothing ever ran the timer.** Which gestures may play and how often is the
/// mood's job and `gesture_poses.dart` knows what each looks like; this only
/// runs the clock and hands the rig a cue.
class _SceneState extends ConsumerState<_Scene> {
  Timer? _next;
  GestureCue? _cue;

  /// **He has planted his feet, and it has to END.**
  ///
  /// A separate flag rather than reading `_cue.gesture.stops`, which is what it
  /// was: the cue is never cleared, so the world stopped for the bow and then
  /// stayed stopped until the NEXT gesture happened along — up to sixteen
  /// seconds of a man walking on a pitch that was not moving. The JS's own
  /// `_clearGesture` is on a timer for the gesture's own length, so this is too.
  bool _halted = false;
  Timer? _halt;

  /// He has the stray ball in his hands.
  ///
  /// **Which is why the rota has to know.** Arms cannot do two things at once
  /// and the ball is the one that has to win — it is visibly in them — so
  /// taking hold cancels whatever gesture was running and blocks the next.
  bool _carrying = false;

  /// A ball is rolling in or sitting at his boot, and he is looking at it.
  bool _watchingBall = false;

  /// The last two he played, so the rota keeps moving.
  ///
  /// A FILTER rather than a reroll, because the weights are lopsided: a crushed
  /// manager's pool is mostly two gestures, and rerolling until one of them is
  /// not picked lands back on them often enough to read as a loop.
  final List<String> _recent = [];

  /// True while the scene is live and movement is welcome — the JS's
  /// `_sceneInteractive()`.
  ///
  /// `TickerMode` already stops every animation here when the tab is offscreen,
  /// but a `Timer` is not an animation, so the rota has to ask for itself.
  bool get _live =>
      mounted &&
      // `of`, with the ignore the framework's own doc prints for it. It is
      // deprecated in favour of `valuesOf` — but `valuesOf` does not exist
      // before 3.44, so it is also the one line in the port that will not
      // COMPILE on an older SDK, and a clean analyze is not worth a build
      // nobody outside CI can run.
      // ignore: deprecated_member_use
      TickerMode.of(context) &&
      !MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion, or a hidden tab, can both arrive after mount.
    if (_live) {
      _arm();
    } else {
      _next?.cancel();
      _next = null;
    }
  }

  void _arm() {
    if (_next != null || !_live) return;
    _next = Timer(
      Duration(
        milliseconds: nextGestureDelay(ref.read(managerMoodProvider)).round(),
      ),
      () {
        _next = null;
        if (!_live) return;
        _play();
        _arm();
      },
    );
  }

  /// The stray ball, and what it asks of the man.
  ///
  /// The sim owns the ball and this owns the manager, so it reports rather than
  /// reaching in — the JS's `onEvent`, and the same three answers.
  /// The stray ball is about to leave his boot: swing at it. Not a rota
  /// gesture and not a celebration — it exists only for this cue, so it is
  /// built here rather than listed in `gestures` (where the customiser would
  /// offer it as an emote).
  void _onBallStrike() =>
      _start(const Gesture(id: 'kick', ms: 520, weight: {}));

  /// And the flick that lifts one into his hands before a pickup.
  void _onBallFlick() =>
      _start(const Gesture(id: 'flick', ms: 380, weight: {}));

  void _onBall(BallCue cue) {
    if (!mounted) return;
    switch (cue) {
      case BallCue.hold:
        // The arms are full. Cancel the running gesture rather than letting the
        // two fight over the same joints.
        _halt?.cancel();
        _halt = null;
        setState(() {
          _carrying = true;
          _cue = null;
          _halted = false;
        });
      case BallCue.release:
        setState(() => _carrying = false);
      case BallCue.ignore:
        // **He is letting this one run past him**, and without a tell that reads
        // as the ball getting lost rather than snubbed. So he reacts as it goes
        // by: arms folded for "can't be bothered", head in hands when he has had
        // enough. Both are already glum- and crushed-weighted, which is exactly
        // when an ignore comes up.
        _playNamed(
          ref.read(managerMoodProvider) == Mood.crushed
              ? 'handsonhead'
              : 'armsfolded',
        );
    }
  }

  /// Play one now, replacing whatever was running.
  void _play() {
    // The save, so the rota only rolls the emotes the player actually OWNS. The
    // free gestures are ungated, so a save with no packs behaves exactly as it
    // did before emotes existed.
    final g = pickGesture(
      ref.read(managerMoodProvider),
      null,
      ref.read(gameProvider).state,
      (fullTime: false, exclude: List.of(_recent)),
    );
    if (g == null) return;
    _recent.add(g.id);
    if (_recent.length > 2) _recent.removeAt(0);
    _start(g);
  }

  /// One gesture by name — the ball's snub, which is not a roll.
  void _playNamed(String id) {
    final g = getGesture(id);
    if (g != null) _start(g);
  }

  void _start(Gesture g) {
    // **Never over a carry.** His arms are visibly full of a football, and a
    // gesture would be two things happening to the same joints.
    if (_carrying || !mounted) return;
    // He plants his feet for one of the sixteen, and the world stops travelling
    // past him for exactly as long as he holds it — then eases back up. Every
    // exit winds it back on, including a gesture replaced by a tap part way
    // through, which is why the timer is cancelled rather than left to fire.
    _halt?.cancel();
    _halt = null;
    if (g.stops) {
      _halt = Timer(Duration(milliseconds: g.ms), () {
        _halt = null;
        if (mounted) setState(() => _halted = false);
      });
    }
    setState(() {
      _cue = GestureCue(g);
      _halted = g.stops;
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    _halt?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final mood = ref.watch(managerMoodProvider);
    // A mood change is a different pool AND a different rhythm, so the rota
    // restarts: a sixteen-second neutral gap must not sit through the
    // celebration the player has just earned.
    ref.listen(managerMoodProvider, (_, _) {
      _next?.cancel();
      _next = null;
      _arm();
    });

    return PitchScene(
      mood: mood,
      walkerBottom: widget.walkerBottom,
      // **The sky the player is actually standing under**, when there is a live
      // reading, and the seasonal model's otherwise. The engine has been able to
      // answer this since M1 and nothing has ever asked it on a clock — see
      // `weather_cycle.dart`.
      condition: ref.watch(weatherProvider).condition,
      // The thunder, timed behind the flash by the lightning layer itself. The
      // scene has no speaker: it says WHEN and this says with what.
      onThunder: () => ref.read(soundServiceProvider).play('thunder'),
      // He plants his feet for a bow, and the world eases to a stop with him —
      // for the length of the gesture, and no longer.
      frozen: _halted,
      // **A tap on him is answered by a person, not a menu** — the one thing on
      // this screen that is.
      onTapWalker: _play,
      // **The stray ball, at last** — `pitchBallSim.js`, and the last thing on
      // this screen that moves in the JS and did not exist here.
      onBallCue: _onBall,
      onBallStrike: _onBallStrike,
      onBallFlick: _onBallFlick,
      onBallWatch: (watching) {
        if (!mounted || watching == _watchingBall) return;
        setState(() => _watchingBall = watching);
      },
      // What the weather does to one in flight. `windAccelFor` has been ported
      // and tested since the weather landed and had no reader at all: the chain
      // resolved a gust and nothing was ever blown by it.
      ballWind: windAccelFor(
        ref.watch(weatherProvider).condition,
        ref.watch(weatherProvider).windKph,
      ).toDouble(),
      // And the CROWD answers him. Only the celebrations: `manager_mood.dart`
      // already marks which of the sixteen are worth getting out of your seat
      // for, and arms folded is not one of them.
      celebration: (_cue?.gesture.celebration ?? false) ? _cue : null,
      // The ground the club has actually built: it buys the sky's grandeur and
      // the floodlight pylons behind the stand. The HOUR is the theme's — see
      // `theme/sky.dart`.
      tier: ref.watch(stadiumTierProvider),
      // Some of the stand wears the club's colours. Support that grows with you
      // is the one thing a crowd can say about the season.
      kitColor: kit.accent,
      // `TickerMode` stops every animation here when the tab is offscreen, which
      // is the whole reason the shell puts each tab in one — no freeze of the
      // scene's own needed.
      // **HE IS ALIVE BETWEEN GESTURES NOW.** The dugout cam has had a complete
      // idle since it was built — four out-of-phase loops driving breath, a
      // weight rock, arm sway and a slow scan — and the manager on the HOME
      // screen, who is the one most players look at most, had none of it: he
      // walked, and between cues that was the whole of him.
      //
      // It layers UNDER the walk and under any gesture, joint by joint, which
      // is `poseOverIdle`'s entire job — so a playing gesture still outruns it
      // and nothing here competes with the stride.
      walkerBuilder: (ball) => ManagerIdle(
        mood: mood,
        // **AND THE MOOD'S LEAN, which was cam-only.** `--lean` is a whole-body
        // pitch about the boots — head down on a bad night, chest out on a
        // good one — and the stylesheet turns it about `50% 92%`, which is why
        // it is a rotation here rather than something the rig carries. It was
        // built for the dugout shot and never reached the touchline, so the one
        // manager most players look at had no posture at all.
        builder: (context, idle) => Transform.rotate(
          angle: idle.tilt * pi / 180,
          alignment: camBootPivot,
          child: ManagerWalker(
            // How he is getting on in what the player dressed him in. Read fresh
            // rather than cached, because both halves move on their own — and
            // through [sceneComfort], which is what stops him sweating under a
            // moon.
            comfort: sceneComfort(context, ref.watch(managerComfortProvider)),
            kit: kit.accent,
            skin: const Color(0xFFEEBB8C),
            hair: const Color(0xFF3A2A1C),
            // His own look and his own mood — both were ported data with nothing
            // reading them.
            look: ref.watch(managerLookProvider),
            mood: mood,
            gesture: _cue,
            carrying: _carrying,
            watchingBall: _watchingBall,
            idle: idle.pose,
            // Handed the ball rather than having it stacked over him: what
            // goes on TOP of it is his own near arm, closing round it.
            ballLayer: ball,
          ),
        ),
      ),
    );
  }
}
