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

/// The diorama, and the next fixture over it.
///
/// The scene itself is still to come: 6,777 lines with a parallax backdrop and
/// a ball simulation, and it is the one piece of this screen that wants a game
/// loop rather than a widget tree. What is here now is the part that carries
/// information — which competition, which match — so the screen reads correctly
/// while the spectacle lands behind it.
class _Scene extends ConsumerWidget {
  const _Scene();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final division = ref.watch(divisionNameProvider);
    final match = ref.watch(nextMatchNumberProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kit.surface2, kit.bg],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 64, 13, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                division,
                key: const ValueKey('home-division'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kit.accentBright,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t('play.matchLabel', {'n': match}),
                key: const ValueKey('home-match-label'),
                style: TextStyle(fontSize: 12, color: kit.textMuted),
              ),
            ],
          ),
        ),
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
