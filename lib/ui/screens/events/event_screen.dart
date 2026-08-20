/// The Event screen. Ported from `ui/screens/EventScreen.js`.
///
/// A route rather than a tab, opened by the strip on the Play screen — and it
/// rises from the bottom rather than sliding in from the side, because the way
/// in is pinned to the BOTTOM of that screen. `openEventRoute` already knows
/// this; the palette argument is the other half of it.
///
/// Three states, in the order a player meets them:
///
/// - **Shut.** For most of the month "no active event" means the doors open
///   again this evening, so the screen counts down rather than refusing. On the
///   last night of a window it shows tonight's ledger instead: an evening that
///   just happened outranks a countdown to nothing.
/// - **Open.** Sub-tabs come from the event's own `mechanics`, so a cup event
///   shows a bracket and Deadline Day shows a trading floor without either
///   having to know about the other.
/// - **Nothing at all.** No event live, none coming, none just gone.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/events/deadline_day_view.dart';
import 'package:merge_empire_fc/ui/screens/events/deadline_deal_sheets.dart';
import 'package:merge_empire_fc/ui/screens/events/event_challenges_view.dart';
import 'package:merge_empire_fc/ui/screens/events/event_cup_view.dart';
import 'package:merge_empire_fc/ui/screens/events/event_providers.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/time.dart';

const int _minuteMs = 60 * 1000;
const int _hourMs = 60 * _minuteMs;
const int _dayMs = 24 * _hourMs;

/// Open the Event screen.
///
/// A THEMED event is a fixed dark showpiece and forces dark for as long as it
/// is up; Deadline Day has no palette and keeps the player's own light mode.
/// That is a property of the EVENT, not of the screen.
Future<void> openEventScreen(BuildContext context, WidgetRef ref) {
  final id = ref.read(activeEventProvider) ?? ref.read(upcomingEventProvider);
  final event = id == null ? null : getEventById(id);
  return openEventRoute(
    context,
    ref,
    const EventScreen(),
    hasPalette: event?.theme.palette.isNotEmpty ?? false,
  );
}

class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key});

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  EventSubTab? _subTab;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final activeId = ref.watch(activeEventProvider);
    final active = activeId == null ? null : getEventById(activeId);

    final Widget body;
    if (active == null) {
      final upcomingId = ref.watch(upcomingEventProvider);
      final upcoming = upcomingId == null ? null : getEventById(upcomingId);
      body = upcoming == null
          ? const _NothingOn()
          : _ClosedView(event: upcoming);
    } else {
      body = _OpenView(
        event: active,
        subTab: _subTab,
        onSubTab: (tab) => setState(() => _subTab = tab),
      );
    }

    return Scaffold(
      backgroundColor: kit.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          active != null ? eventName(active) : t('event.banner.coming_up'),
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}

/// No event live, none coming, and none just gone.
class _NothingOn extends StatelessWidget {
  const _NothingOn();

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Center(
      key: const ValueKey('event-empty'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('event.empty.title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              t('event.empty.body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.6, color: kit.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shut, but not gone.
///
/// The countdown reruns once a second, and only the LINE is rebuilt — a whole
/// screen rebuilt every second would move the scroller under the player's
/// finger. Midnight is the one crossing that needs the whole screen, because
/// the evening's ledger expires with the sentence above it.
class _ClosedView extends ConsumerStatefulWidget {
  const _ClosedView({required this.event});

  final EventDef event;

  @override
  ConsumerState<_ClosedView> createState() => _ClosedViewState();
}

class _ClosedViewState extends ConsumerState<_ClosedView> {
  Timer? _ticker;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final event = widget.event;
    final state = ref.watch(gameProvider).state;
    final isDeadlineDay = event.mechanics.contains('deadlineDay');
    final tonight = state == null ? null : tonightSummary(state, event);
    final params = deadlineRuleParams(event);
    final openAt = deadlineOpenTimeLabel(event);

    return ListView(
      key: const ValueKey('event-closed'),
      padding: const EdgeInsets.all(13),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 66,
                backgroundColor: kit.bg,
                child: const Text('🧑‍🏫', style: TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 14),
              Text(
                t('event.banner.coming_up').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: kit.accentBright,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                closedLine(event),
                key: ValueKey('event-closed-countdown-$_tick'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              if (isDeadlineDay) ...[
                const SizedBox(height: 9),
                Text(
                  t('event.deadline.colin_wait'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: kit.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (tonight != null) ...[
          const SizedBox(height: 14),
          Text(
            t('event.deadline.tonight_title').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kit.accentBright,
            ),
          ),
          const SizedBox(height: 8),
          DeadlineLedger(summary: tonight),
        ],
        if (isDeadlineDay) ...[
          const SizedBox(height: 14),
          // Rules INLINE here and behind the ? only on the live board. Shut,
          // there is nothing else on this screen and the wait is the natural
          // moment to read them; open, they would be four rows of explanation
          // sitting on top of a board with a five-minute fuse.
          Text(
            t('event.deadline.intro_title').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kit.accentBright,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in [
            t('event.deadline.rule_clock'),
            t('event.deadline.rule_fuse', params),
            t('event.deadline.rule_world'),
            openAt == null
                ? t('event.deadline.rule_once')
                : t('event.deadline.rule_nightly', {
                    'time': openAt,
                    'mins': params['mins'],
                  }),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                line,
                style: const TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ),
          if (state != null)
            DeadlineHistory(state: state, skipCurrent: tonight != null),
        ],
      ],
    );
  }
}

/// Which sentence the shut screen is answering with.
///
/// Two shapes, deliberately. Tonight's is answered with a TIME — "tomorrow at
/// 6:00 pm" — because a duration is the wrong unit for a wait you are going to
/// sleep through; nobody plans around "in 21 hours". Past midnight it is the
/// same day's window again and the countdown becomes the useful answer.
String closedLine(EventDef event) {
  final ms = eventStartsInMs(event).clamp(0, 1 << 62);
  final at = now();
  int midnightOf(int stamp) {
    final d = DateTime.fromMillisecondsSinceEpoch(stamp);
    return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  final days = ((midnightOf(at + ms) - midnightOf(at)) / _dayMs).round();
  if (days == 1) {
    return t('event.deadline.closed_today', {
      'time': deadlineOpenTimeLabel(event) ?? '',
    });
  }
  return t('event.deadline.opens_in', {'t': closedCountdown(ms)});
}

String closedCountdown(int ms) {
  if (ms >= _dayMs) {
    final n = (ms / _dayMs).ceil();
    return t('event.deadline.dur_d', {'n': n, 's': n == 1 ? '' : 's'});
  }
  if (ms >= _hourMs) {
    final h = ms ~/ _hourMs;
    final m = ((ms % _hourMs) / _minuteMs).round();
    return t('event.deadline.dur_hm', {
      'h': h,
      'm': m,
      'hs': h == 1 ? '' : 's',
      'ms': m == 1 ? '' : 's',
    });
  }
  final m = (ms / _minuteMs).ceil().clamp(1, 60);
  return t('event.deadline.dur_m', {'m': m, 'ms': m == 1 ? '' : 's'});
}

class _OpenView extends StatelessWidget {
  const _OpenView({
    required this.event,
    required this.subTab,
    required this.onSubTab,
  });

  final EventDef event;
  final EventSubTab? subTab;
  final ValueChanged<EventSubTab> onSubTab;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final tabs = subTabsFor(event);
    // Clamped, so a stale tab from a previous event does not land on one this
    // event has not got.
    final current = tabs.contains(subTab) ? subTab! : tabs.first;

    return Column(
      key: const ValueKey('event-open'),
      children: [
        if (tabs.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 8),
            child: Container(
              decoration: BoxDecoration(
                color: kit.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kit.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: InkWell(
                        key: ValueKey('event-subtab-${tab.name}'),
                        onTap: () => onSubTab(tab),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          color: tab == current
                              ? kit.accent
                              : Colors.transparent,
                          child: Text(
                            t(eventSubTabLabelKey(tab)).toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: tab == current
                                  ? kit.accentInk
                                  : kit.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
            child: switch (current) {
              EventSubTab.deadline => DeadlineDayView(event: event),
              EventSubTab.cup => EventCupView(event: event),
              EventSubTab.challenges => EventChallengesView(event: event),
            },
          ),
        ),
      ],
    );
  }
}
