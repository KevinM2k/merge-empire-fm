/// The ranked list itself — the half of `LeaderboardScreen.js` that needed the
/// service.
///
/// **The board and "your standing" are different questions and always were.**
/// What `leaderboard_sheet.dart` already drew is computed locally and is
/// therefore always knowable: your club, your division, your trophies. This is
/// the part that needs a server, and it says so honestly when it cannot reach
/// one rather than showing an empty list.
///
/// **THE THREE SELECTORS ARE ONE QUERY.** Period, metric and reach each pick a
/// different board rather than filtering the same one — a different document
/// collection, a different score field and a different `where` — which is why
/// changing any of them refetches rather than re-sorts.
///
/// **Prestige is all-time whatever the period says.** It is a LEVEL, not a
/// score that accumulates in a window, so "this week's prestige" would rank
/// whoever prestiged this week rather than whoever has prestiged most. The
/// period control says so and goes quiet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';
import 'package:merge_empire_fc/engine/leaderboard_view.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/badge_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

/// What board is being looked at.
typedef BoardQuery = ({String scope, String period, String metric});

const BoardQuery defaultBoardQuery = (
  scope: 'all_global',
  period: '7d',
  metric: 'points',
);

/// **Where the player actually stands, once the board knows.**
///
/// The standing card above the board printed `leaderboard.rank_unranked` — a
/// dash — for every player on every board, and it was honest when there was no
/// service and stopped being honest when there was: the fetch has come back with
/// `playerRank` on it the whole time, two widgets below the card that needed it.
///
/// It lives here rather than in the sheet because the RANK IS A PROPERTY OF THE
/// BOARD, not of the save. Change the metric from points to prestige and the
/// number changes; the card reads whatever the three dropdowns are currently
/// asking about, which is the only reading of "my rank" that means anything.
///
/// Written when a fetch RESOLVES and nulled when one starts, so the card shows a
/// dash while a board is loading rather than the last board's answer.
final myBoardRankProvider = StateProvider<int?>((_) => null);

class LeaderboardBoard extends ConsumerStatefulWidget {
  const LeaderboardBoard({super.key});

  @override
  ConsumerState<LeaderboardBoard> createState() => _LeaderboardBoardState();
}

class _LeaderboardBoardState extends ConsumerState<LeaderboardBoard> {
  BoardQuery _query = defaultBoardQuery;
  Future<LeaderboardView>? _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool force = false}) {
    final state = ref.read(gameProvider).state;
    final pending = fetchLeaderboard(
      state,
      scope: _query.scope,
      period: _query.period,
      metric: _query.metric,
      force: force,
    );
    // The card goes back to a dash for as long as this is in flight — see
    // [myBoardRankProvider].
    ref.read(myBoardRankProvider.notifier).state = null;
    // **On the RESOLUTION, never inside the `FutureBuilder`.** The builder runs
    // during a build and Riverpod refuses a write from there; and the `mounted`
    // guard is what stops a board the player has navigated away from writing a
    // rank into a scope that has gone.
    unawaited(
      pending
          .then((view) {
            if (!mounted || _pending != pending) return;
            ref.read(myBoardRankProvider.notifier).state = view.playerRank;
          })
          // A board that will not load has no rank to report, and
          // `fetchLeaderboard` already answers an `error` view rather than
          // throwing — this is the belt on top of that.
          .catchError((_) {}),
    );
    // A BLOCK, not an arrow: `_pending = pending` evaluates to the future, and
    // `setState` asserts on a callback that returns one.
    setState(() {
      _pending = pending;
    });
  }

  void _pick(BoardQuery next) {
    if (next == _query) return;
    _query = next;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // Prestige forces all-time, so the period control has nothing to say.
    final prestige = _query.metric == 'prestige';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // **ONE ROW, THREE DROPDOWNS.**
        //
        // It was three labelled segment strips stacked down the page, each one
        // scrolling sideways because four metrics in ten languages will not fit
        // across a phone. Three rows of chrome above the thing they filter, on a
        // sheet whose whole subject is a ranked list — reported as wanting one
        // row with select dropdowns instead.
        //
        // A dropdown says where you are without being read left to right and
        // cannot run out of room however many metrics the board grows, which is
        // the same argument the manager customiser's axis picker already makes.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Picker(
                pickerKey: const ValueKey('leaderboard-metric'),
                label: t('leaderboard.metric'),
                value: _query.metric,
                options: [
                  for (final metric in leaderboardMetrics)
                    (value: metric, label: t('leaderboard.metric_$metric')),
                ],
                onPick: (metric) => _pick((
                  scope: _query.scope,
                  period: _query.period,
                  metric: metric,
                )),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Picker(
                pickerKey: const ValueKey('leaderboard-period'),
                label: t('leaderboard.period'),
                // Prestige forces all-time, so the control has nothing to say —
                // dead rather than hidden, because a control that vanishes reads
                // as a missing feature.
                value: prestige ? 'alltime' : _query.period,
                note: prestige ? t('leaderboard.prestige_hint') : null,
                options: [
                  for (final period in leaderboardPeriods)
                    (value: period, label: t('leaderboard.period_$period')),
                ],
                onPick: prestige
                    ? null
                    : (period) => _pick((
                        scope: _query.scope,
                        period: period,
                        metric: _query.metric,
                      )),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Picker(
                pickerKey: const ValueKey('leaderboard-scope'),
                label: t('leaderboard.reach_label'),
                value: _query.scope,
                options: [
                  for (final scope in leaderboardViewScopes)
                    (value: scope, label: _scopeLabel(scope)),
                ],
                onPick: (scope) => _pick((
                  scope: scope,
                  period: _query.period,
                  metric: _query.metric,
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<LeaderboardView>(
          future: _pending,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  t('leaderboard.refreshing'),
                  key: const ValueKey('leaderboard-loading'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kit.textMuted, fontSize: 12),
                ),
              );
            }
            final view = snapshot.data;
            if (view == null || view.error != null) {
              return _Message(
                messageKey: const ValueKey('leaderboard-error'),
                text: t('leaderboard.error'),
                actionLabel: t('leaderboard.refresh'),
                onAction: () => _load(force: true),
              );
            }
            if (view.isEmpty) {
              return _Message(
                messageKey: const ValueKey('leaderboard-empty'),
                text: t('leaderboard.empty'),
                actionLabel: t('leaderboard.refresh'),
                onAction: () => _load(force: true),
              );
            }
            return _Rows(view: view, metric: _query.metric);
          },
        ),
      ],
    );
  }

  /// The scope pill's own copy, which names the DIVISION and the REGION rather
  /// than the two enum halves — "Sunday League · GB" reads as a board and
  /// "division_regional" does not.
  String _scopeLabel(String scope) {
    final view = parseLeaderboardScope(scope);
    return switch ((view.tier, view.reach)) {
      (LeaderboardTier.division, LeaderboardReach.regional) =>
        t('leaderboard.tier_division'),
      (LeaderboardTier.division, LeaderboardReach.global) =>
        '${t('leaderboard.tier_division')} · ${t('leaderboard.reach_global')}',
      (LeaderboardTier.all, LeaderboardReach.regional) =>
        t('leaderboard.reach_regional'),
      (LeaderboardTier.all, LeaderboardReach.global) =>
        t('leaderboard.reach_global'),
    };
  }
}

/// One of the board's three questions, as a dropdown.
///
/// A `null` [onPick] is a control that has nothing to choose right now — it
/// keeps its current answer and greys, rather than disappearing.
typedef PickerOption = ({String value, String label});

class _Picker extends StatelessWidget {
  const _Picker({
    required this.pickerKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onPick,
    this.note,
  });

  final Key pickerKey;
  final String label;
  final String value;
  final List<PickerOption> options;
  final void Function(String)? onPick;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final live = onPick != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: kit.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          key: pickerKey,
          // Vertical padding as well as horizontal: `isDense` shrink-wraps a
          // dropdown to its text, which is a tap target the height of a word.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kit.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              isExpanded: true,
              dropdownColor: kit.surface,
              iconEnabledColor: kit.textMuted,
              borderRadius: BorderRadius.circular(10),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: live
                    ? DefaultTextStyle.of(context).style.color
                    : kit.textMuted,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem<String>(
                    value: option.value,
                    key: ValueKey('leaderboard-option-${option.value}'),
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: live
                  ? (next) {
                      if (next != null) onPick!(next);
                    }
                  : null,
            ),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              note!,
              style: TextStyle(color: kit.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}


class _Message extends StatelessWidget {
  const _Message({
    required this.messageKey,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final Key messageKey;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            text,
            key: messageKey,
            textAlign: TextAlign.center,
            style: TextStyle(color: kit.textMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('leaderboard-refresh'),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.view, required this.metric});

  final LeaderboardView view;
  final String metric;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('leaderboard-rows'),
    children: [
      for (final entry in view.entries) _Row(entry: entry, metric: metric),
      // **The gap is drawn, not implied.** A jump from rank 50 to rank 812 with
      // nothing between them reads as a broken list; an ellipsis reads as a
      // long way down.
      if (view.showGap) const _Gap(),
      if (view.contextAbove case final above?)
        _Row(entry: above, metric: metric),
      if (view.playerBeyondTop && view.playerEntry != null)
        _Row(entry: view.playerEntry!, metric: metric),
      if (view.contextBelow case final below?)
        _Row(entry: below, metric: metric),
      if (view.showGapBeforeBottom) const _Gap(),
      for (final entry in view.bottomEntries) _Row(entry: entry, metric: metric),
      if (view.optedOut)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            t('leaderboard.opted_out'),
            key: const ValueKey('leaderboard-opted-out'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).extension<KitTheme>()!.textMuted,
            ),
          ),
        ),
    ],
  );
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      '···',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).extension<KitTheme>()!.textMuted,
        fontSize: 14,
        letterSpacing: 3,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.metric});

  final LeaderboardEntry entry;
  final String metric;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: ValueKey('leaderboard-row-${entry.playerId}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(10),
        // The player's own row is the one they came to find.
        border: Border.all(
          color: entry.isPlayer ? kit.accentBright : kit.border,
          width: entry.isPlayer ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              entry.rank == null ? t('leaderboard.rank_unranked') : '${entry.rank}',
              style: TextStyle(
                color: kit.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          BadgeIcon(badgeId: entry.badgeId, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.clubName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tName('division', {'id': entry.division, 'name': ''}),
                  style: TextStyle(color: kit.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            // Prestige is a LEVEL and the rest are counts, so it is the one
            // that is not formatted as a quantity of anything.
            metric == 'prestige'
                ? '${entry.prestigeLevel}'
                : formatCoins(entry.score.round()),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
