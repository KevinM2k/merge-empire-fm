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
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
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

/// The division as it stands. Ported from `_standingsHtml` in
/// `ui/screens/LeagueScreen.js`.
///
/// **Points is the hero** — a big gold figure — and P/W/D/L is a quiet
/// micro-line under it. The port had four equal columns of 12px grey, which made
/// the one number that decides the season the same weight as the games played.
///
/// **Promotion and relegation are BANDS with a hairline label**, not a colour on
/// a row: a tint on its own says "this row is special" without saying which kind
/// of special, and the label is what names it.
///
/// **Your own row is marked WITHOUT a hue** — a neutral lift, so it can never be
/// confused with the green promotion or red relegation band it might be sitting
/// in. Identity comes from the division-coloured left bar and the heavier name.
/// The port tinted your row with the accent, which in a green-accented division
/// made mid-table look exactly like a promotion place.
class LeagueTableView extends ConsumerWidget {
  const LeagueTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rows = ref.watch(leagueTableProvider);
    final divisionId = ref.watch(currentDivisionProvider);
    final division = getDivision(divisionId);
    final form = ref.watch(leagueFormProvider);

    final isTop = divisionId == 'champions_cup';
    final isBottom = divisionId == 'sunday_league';
    final relegStart = rows.length - 2;

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
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (!isTop && i == 0)
            _ZoneLabel(
              // The shared zone strings carry a ↑/↓; the band already reads as
              // promotion from its colour and position, so the glyph comes off.
              text: _stripArrows(t('play.zone_promo')),
              colour: kit.accentBright,
            ),
          if (!isBottom && relegStart >= 2 && i == relegStart)
            _ZoneLabel(
              text: _stripArrows(t('play.zone_relegation')),
              colour: const Color(0xFFF44336),
            ),
          _TableRow(
            position: i + 1,
            row: rows[i],
            zone: leagueZoneFor(i + 1, rows.length, divisionId),
            divisionColour: cssColor(division.color),
            form: form[rows[i].name] ?? const [],
          ),
        ],
      ],
    );
  }
}

String _stripArrows(String s) => s.replaceAll(RegExp(r'^[↑↓\s]+'), '').trim();

/// A hairline with a word on it, marking where a zone begins.
class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.text, required this.colour});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 9, 8, 5),
    child: Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: colour,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: colour.withValues(alpha: 0.3)),
        ),
      ],
    ),
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.position,
    required this.row,
    required this.zone,
    required this.divisionColour,
    required this.form,
  });

  final int position;
  final LeagueRow row;
  final LeagueZone zone;
  final Color divisionColour;
  final List<String> form;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;

    final zoneWash = switch (zone) {
      LeagueZone.promotion ||
      LeagueZone.champion => kit.accent.withValues(alpha: 0.08),
      LeagueZone.relegation => const Color(0xFFF44336).withValues(alpha: 0.08),
      LeagueZone.midtable => null,
    };
    final posColour = switch (zone) {
      LeagueZone.champion => const Color(0xFFFFD700),
      LeagueZone.promotion => kit.accentBright,
      LeagueZone.relegation => const Color(0xFFF87171),
      LeagueZone.midtable => kit.textMuted,
    };

    return Container(
      key: ValueKey('league-row-$position'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: zoneWash,
        borderRadius: BorderRadius.circular(12),
        // A neutral lift, layered OVER the zone wash rather than replacing it —
        // so "this is me" and "I am in the drop zone" are both readable at once.
        gradient: row.isPlayer
            ? LinearGradient(
                colors: [
                  ink.withValues(alpha: 0.11),
                  ink.withValues(alpha: 0.11),
                ],
              )
            : null,
        border: row.isPlayer
            ? Border(left: BorderSide(color: divisionColour, width: 3))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$position',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: posColour,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: row.isPlayer
                        ? FontWeight.w900
                        : FontWeight.w700,
                    color: row.isPlayer ? kit.accentBright : ink,
                  ),
                ),
                if (form.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (final r in form)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: _FormDot(result: r),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${row.pts}',
                style: const TextStyle(
                  fontSize: 21,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kit.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(text: 'P${row.played} · '),
                    TextSpan(
                      text: '${row.won}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink.withValues(alpha: 0.82),
                      ),
                    ),
                    TextSpan(text: 'W ${row.drawn}D ${row.lost}L'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One result in the last five. Tinted fill plus a colour hairline, so a run
/// reads as a shape before any letter is parsed.
class _FormDot extends StatelessWidget {
  const _FormDot({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final colour = switch (result) {
      'W' => const Color(0xFF4ADE80),
      'D' => const Color(0xFFFBBF24),
      _ => const Color(0xFFF87171),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colour.withValues(alpha: 0.33)),
      ),
      child: Text(
        result,
        style: TextStyle(
          fontSize: 8.5,
          height: 1,
          fontWeight: FontWeight.w900,
          color: colour,
        ),
      ),
    );
  }
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
