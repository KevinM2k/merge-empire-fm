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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';
import 'package:merge_empire_fc/engine/leaderboard_view.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/ui/screens/settings_controls.dart';
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
    setState(() {
      _pending = fetchLeaderboard(
        state,
        scope: _query.scope,
        period: _query.period,
        metric: _query.metric,
        force: force,
      );
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
        _Selector(
          key: const ValueKey('leaderboard-metric'),
          label: t('leaderboard.metric'),
          options: [
            for (final metric in leaderboardMetrics)
              (
                label: t('leaderboard.metric_$metric'),
                on: _query.metric == metric,
                onTap: () => _pick((
                  scope: _query.scope,
                  period: _query.period,
                  metric: metric,
                )),
                locked: false,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _Selector(
          key: const ValueKey('leaderboard-period'),
          label: t('leaderboard.period'),
          note: prestige ? t('leaderboard.prestige_hint') : null,
          options: [
            for (final period in leaderboardPeriods)
              (
                label: t('leaderboard.period_$period'),
                on: prestige ? period == 'alltime' : _query.period == period,
                // Dead rather than hidden while prestige is picked: a control
                // that vanishes reads as a missing feature.
                onTap: prestige
                    ? null
                    : () => _pick((
                        scope: _query.scope,
                        period: period,
                        metric: _query.metric,
                      )),
                locked: false,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _Selector(
          key: const ValueKey('leaderboard-scope'),
          label: t('leaderboard.reach_label'),
          options: [
            for (final scope in leaderboardViewScopes)
              (
                label: _scopeLabel(scope),
                on: _query.scope == scope,
                onTap: () => _pick((
                  scope: scope,
                  period: _query.period,
                  metric: _query.metric,
                )),
                locked: false,
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

class _Selector extends StatelessWidget {
  const _Selector({
    super.key,
    required this.label,
    required this.options,
    this.note,
  });

  final String label;
  final List<SettingsChoice> options;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: kit.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        // Scrolls, because four metrics in ten languages will not fit across a
        // phone and a wrapped segment stops reading as one control.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SettingsSegment(choices: options),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              note!,
              style: TextStyle(color: kit.textMuted, fontSize: 10),
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
              fontSize: 11,
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
                  style: TextStyle(color: kit.textMuted, fontSize: 10),
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
