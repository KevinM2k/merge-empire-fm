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
/// - a sticky footer: the event strip, and the button that plays the match.
///
/// The two orbs hang off the footer's TOP edge rather than being measured from
/// the bottom of the screen. That is deliberate in the JS and worth keeping:
/// the footer changes height — an event strip appears, a cup button appears —
/// and anything anchored to a measured height sits at the wrong level the
/// moment the measurement and the real height disagree.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/events/event_providers.dart';
import 'package:merge_empire_fc/ui/screens/events/event_screen.dart';
import 'package:merge_empire_fc/ui/screens/home/home_dock.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Stack(
      key: ValueKey('home-screen'),
      children: [
        Positioned.fill(child: _Scene()),
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
          child: SafeArea(
            bottom: false,
            child: Padding(
              // Clears the HUD, which floats over every screen.
              padding: EdgeInsets.fromLTRB(13, 56, 13, 0),
              child: NextMatchCard(),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(13, 0, 13, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The dock rail: one row, both orbs, sharing the footer's top
                  // edge so they are level by construction.
                  Row(children: [CoachDock(), Spacer(), MenuDock()]),
                  SizedBox(height: 10),
                  _EventStrip(),
                  PlayMatchButton(),
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
  const _Scene();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final mood = ref.watch(managerMoodProvider);

    return PitchScene(
      mood: mood,
      // `TickerMode` stops every animation here when the tab is offscreen, which
      // is the whole reason the shell puts each tab in one — no freeze of the
      // scene's own needed.
      walker: ManagerWalker(
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

/// The way in to a live or upcoming event.
///
/// It rides in the sticky footer rather than above the match card. Over the
/// card it pushed everything down on a page with no spare height; here it sits
/// with the Play button, which is where the thumb already is, and for most of
/// the month it is not there at all.
class _EventStrip extends ConsumerWidget {
  const _EventStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final live = ref.watch(activeEventProvider);
    final upcoming = ref.watch(upcomingEventProvider);
    final id = live ?? upcoming;
    if (id == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        key: const ValueKey('home-event-strip'),
        onTap: () => openEventScreen(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: live != null ? kit.accent : kit.border),
          ),
          child: Row(
            children: [
              Text(
                live != null ? '●' : '⏳',
                style: TextStyle(
                  fontSize: 12,
                  color: live != null ? kit.accentBright : kit.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tName('event', id),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                live != null
                    ? t('event.deadline.live')
                    : t('event.banner.coming_up'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: live != null ? kit.accentBright : kit.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
