/// The Play tab — four sub-tabs over the league.
///
/// Tapping the Play tab in the bar always lands here on OVERVIEW, even when the
/// player was last looking at the table. That rule is the JS's and it could not
/// be honoured until sub-tabs existed; [LeagueScreenState.resetToOverview] is
/// what the shell calls.
///
/// Overview is a placeholder. It is the DIORAMA — 6,777 lines with a parallax
/// scene and a ball simulation — and the port design gates its technique on
/// profile-mode timings from a physical device, which have not been taken. The
/// table and the fixtures need none of that, so they are real.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/league/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

enum LeagueSubTab {
  overview('subnav.overview'),
  table('subnav.table'),
  fixtures('subnav.fixtures'),
  training('subnav.training');

  const LeagueSubTab(this.labelKey);

  final String labelKey;
}

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => LeagueScreenState();
}

class LeagueScreenState extends ConsumerState<LeagueScreen> {
  LeagueSubTab _sub = LeagueSubTab.overview;

  LeagueSubTab get subTab => _sub;

  void setSubTab(LeagueSubTab tab) => setState(() => _sub = tab);

  /// What the bar's Play tab calls. Tapping Play is "take me home", and landing
  /// on last week's table is not home.
  void resetToOverview() {
    if (_sub != LeagueSubTab.overview) setSubTab(LeagueSubTab.overview);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('league-screen'),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: _SubTabStrip(active: _sub, onTap: setSubTab),
        ),
        Expanded(
          child: switch (_sub) {
            LeagueSubTab.overview => const _OverviewPending(),
            LeagueSubTab.table => const LeagueTableView(),
            LeagueSubTab.fixtures => const FixturesView(),
            LeagueSubTab.training => const _TrainingPending(),
          },
        ),
      ],
    );
  }
}

class _SubTabStrip extends StatelessWidget {
  const _SubTabStrip({required this.active, required this.onTap});

  final LeagueSubTab active;
  final void Function(LeagueSubTab) onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final tab in LeagueSubTab.values)
          TextButton(
            key: ValueKey('league-subtab-${tab.name}'),
            onPressed: () => onTap(tab),
            child: Text(
              t(tab.labelKey),
              style: TextStyle(
                color: tab == active ? kit.accent : kit.textMuted,
                fontWeight: tab == active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

class LeagueTableView extends ConsumerWidget {
  const LeagueTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rows = ref.watch(leagueTableProvider);

    return Column(
      key: const ValueKey('league-table'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            ref.watch(divisionNameProvider),
            style: TextStyle(
              color: kit.accentBright,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => _TableRow(position: i + 1, row: rows[i]),
          ),
        ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.position, required this.row});

  final int position;
  final LeagueRow row;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // The player's own club is the row they are looking for; everything else is
    // context for it.
    final colour = row.isPlayer ? kit.accentBright : null;
    final weight = row.isPlayer ? FontWeight.w700 : FontWeight.w400;

    return Container(
      key: ValueKey('league-row-$position'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: row.isPlayer ? kit.surface2 : null,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$position',
              style: TextStyle(color: kit.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              row.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colour, fontWeight: weight),
            ),
          ),
          _Cell('${row.played}', kit.textMuted),
          _Cell(row.gd > 0 ? '+${row.gd}' : '${row.gd}', kit.textMuted),
          _Cell('${row.pts}', colour ?? kit.accent, bold: true),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, this.colour, {this.bold = false});

  final String text;
  final Color colour;
  final bool bold;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: colour,
        fontSize: 12,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
  );
}

class FixturesView extends ConsumerWidget {
  const FixturesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final fixtures = ref.watch(fixturesProvider);

    if (fixtures.isEmpty) {
      return Column(
        key: const ValueKey('league-fixtures-empty'),
        children: [
          Expanded(
            child: Center(
              child: Text(
                t('common.loading'),
                style: TextStyle(color: kit.textMuted),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: PlayMatchButton(),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: _FixtureList(fixtures: fixtures)),
        const Padding(
          padding: EdgeInsets.all(12),
          child: PlayMatchButton(),
        ),
      ],
    );
  }
}

class _FixtureList extends StatelessWidget {
  const _FixtureList({required this.fixtures});

  final List<FixtureRow> fixtures;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ListView.builder(
      key: const ValueKey('league-fixtures'),
      itemCount: fixtures.length,
      itemBuilder: (context, i) {
        final row = fixtures[i];
        final score = row.played ? '${row.homeGoals}–${row.awayGoals}' : 'v';
        return Container(
          key: ValueKey('league-fixture-$i'),
          color: row.involvesPlayer ? kit.surface2 : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${row.round}',
                  style: TextStyle(color: kit.textMuted, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  row.homeTeam,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: row.involvesPlayer
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  score,
                  style: TextStyle(
                    color: row.played ? kit.accentBright : kit.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  row.awayTeam,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: row.involvesPlayer
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The diorama. Its technique is gated on profile-mode timings from a physical
/// device — see "Open questions" in docs/REMAINING.md — so it is named rather
/// than half-built.
class _OverviewPending extends StatelessWidget {
  const _OverviewPending();

  @override
  Widget build(BuildContext context) => _Pending(
    key: const ValueKey('league-overview-pending'),
    label: t('subnav.overview'),
  );
}

class _TrainingPending extends StatelessWidget {
  const _TrainingPending();

  @override
  Widget build(BuildContext context) => _Pending(
    key: const ValueKey('league-training-pending'),
    label: t('subnav.training'),
  );
}

class _Pending extends StatelessWidget {
  const _Pending({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: kit.textMuted, fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            t('settings.comingSoon'),
            style: TextStyle(color: kit.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
