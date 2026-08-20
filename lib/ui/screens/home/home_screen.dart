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

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/event_strip.dart';
import 'package:merge_empire_fc/ui/screens/home/home_dock.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart';
import 'package:merge_empire_fc/providers/weather_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

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
        Positioned.fill(
          key: _sceneKey,
          child: _Scene(walkerBottom: _walkerBottom),
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
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const CoachDock(),
                      const Spacer(),
                      Padding(
                        // Clear of the orbs' own captions, and lifted so the
                        // pill's bottom sits on the discs' bottom rather than
                        // under the labels that ride over them.
                        padding: const EdgeInsets.only(bottom: 6),
                        child: CustomiseDock(anchorKey: _customiseKey),
                      ),
                      const Spacer(),
                      const MenuDock(),
                    ],
                  ),
                  const SizedBox(height: 10),
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
class _Scene extends ConsumerWidget {
  const _Scene({required this.walkerBottom});

  final double walkerBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final mood = ref.watch(managerMoodProvider);

    return PitchScene(
      mood: mood,
      walkerBottom: walkerBottom,
      // **The sky the player is actually standing under**, when there is a live
      // reading, and the seasonal model's otherwise. The engine has been able to
      // answer this since M1 and nothing has ever asked it on a clock — see
      // `weather_cycle.dart`.
      condition: ref.watch(weatherProvider).condition,
      // The thunder, timed behind the flash by the lightning layer itself. The
      // scene has no speaker: it says WHEN and this says with what.
      onThunder: () => ref.read(soundServiceProvider).play('thunder'),
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
      walker: ManagerWalker(
        // How he is getting on in what the player dressed him in. Read fresh
        // rather than cached, because both halves move on their own.
        comfort: ref.watch(managerComfortProvider),
        kit: kit.accent,
        skin: const Color(0xFFEEBB8C),
        hair: const Color(0xFF3A2A1C),
        // His own look and his own mood — both were ported data with nothing
        // reading them.
        look: ref.watch(managerLookProvider),
        mood: mood,
      ),
    );
  }
}
