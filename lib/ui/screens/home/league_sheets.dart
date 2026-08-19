/// The table and the fixture list, as quick-nav sheets.
///
/// These were sub-tabs across the top of the home screen, which is the
/// arrangement the JS moved away from: they are DESTINATIONS — places you go to
/// check something and then leave — rather than places you live, so they belong
/// behind the burger with the index, the quests and the trophies.
///
/// The Play button does NOT come with them. It used to sit under the fixture
/// list, which put the one control the whole screen exists for two taps deep;
/// it lives in the home screen's sticky footer now.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

Future<void> showLeagueTableSheet(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.85,
      child: const LeagueTableView(),
    );

Future<void> showFixturesSheet(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.85,
      child: const FixturesView(),
    );

class LeagueTableView extends ConsumerWidget {
  const LeagueTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rows = ref.watch(leagueTableProvider);

    return ListView(
      key: const ValueKey('league-table'),
      padding: const EdgeInsets.symmetric(vertical: 8),
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
        for (var i = 0; i < rows.length; i++)
          _TableRow(position: i + 1, row: rows[i]),
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
      return Padding(
        key: const ValueKey('league-fixtures-empty'),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            t('common.loading'),
            style: TextStyle(color: kit.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('league-fixtures'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: fixtures.length,
      itemBuilder: (context, i) => _FixtureRow(index: i, row: fixtures[i]),
    );
  }
}

class _FixtureRow extends StatelessWidget {
  const _FixtureRow({required this.index, required this.row});

  final int index;
  final FixtureRow row;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final score = row.played ? '${row.homeGoals}–${row.awayGoals}' : 'v';
    final weight = row.involvesPlayer ? FontWeight.w700 : FontWeight.w400;

    return Container(
      key: ValueKey('league-fixture-$index'),
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
              style: TextStyle(fontWeight: weight),
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
              style: TextStyle(fontWeight: weight),
            ),
          ),
        ],
      ),
    );
  }
}
