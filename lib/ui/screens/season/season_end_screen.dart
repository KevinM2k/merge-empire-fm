/// The season-end takeover.
///
/// Without it a player finishes their fourteenth match and the game stops: the
/// engine sets `progression.seasonComplete`, every gate refuses, and there is no
/// route onward. This is that route.
///
/// It shows a season that `endSeason` has ALREADY settled — the table, the
/// movement, the payout, the ageing and the next campaign are all its work, done
/// in one call. Nothing here decides any of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/engine/league_table.dart' show LeagueRow;
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Is the season over and waiting to be closed?
final seasonCompleteProvider = savePick<bool>((s) {
  final prog = s['progression'];
  return prog is Map<String, dynamic> && prog['seasonComplete'] == true;
});

final seasonJustEndedProvider = savePick<int>((s) {
  final prog = s['progression'];
  final n = prog is Map<String, dynamic> ? prog['seasonCount'] : null;
  return n is num ? n.toInt() : 1;
});

class SeasonEndScreen extends ConsumerStatefulWidget {
  const SeasonEndScreen({
    super.key,
    required this.outcome,
    required this.seasonNumber,
    this.record,
    this.winnerName,
    this.winnerIsUs = false,
    this.cup,
    this.finalTable = const [],
    this.onContinue,
  });

  final SeasonOutcome outcome;

  /// The season's own record, read off the save BEFORE `endSeason` rolled the
  /// counters on — see [seasonRecordOf]. Null draws the page without the stats
  /// band, for a caller that has not got one.
  final SeasonRecord? record;

  /// Who won the division, captured before `endSeason` rebuilt the table for
  /// the new campaign. **The one fact the summary can give that the player's
  /// own row cannot**, which is the JS's reason for it.
  final String? winnerName;
  final bool winnerIsUs;

  /// The division as it finished, for the fold. Captured with the winner, and
  /// for the same reason: `endSeason` rebuilds it for the new campaign.
  final List<LeagueRow> finalTable;

  /// This season's finished cup run, or null when there was not one — see
  /// [seasonCupRun].
  final ({String cupId, String outcome, int roundReached})? cup;

  /// The season that just finished, captured BEFORE `endSeason` rolled it on.
  final int seasonNumber;

  final VoidCallback? onContinue;

  @override
  ConsumerState<SeasonEndScreen> createState() => _SeasonEndScreenState();
}

class _SeasonEndScreenState extends ConsumerState<SeasonEndScreen> {
  /// **SHUT to begin with.** Twenty rows of a table the player has just spent a
  /// season in is not what they came to this page for — the verdict is, and the
  /// table is there for the one who wants to check the club below them. The JS
  /// folds it the same way.
  bool _tableOpen = false;

  /// The league you have just moved into, in the player's own language.
  ///
  /// This card is the one screen a promotion exists for, and it named the
  /// league in English to every player in the world — `Division.name` is the
  /// data record's literal and `division.<id>` is translated in all ten
  /// catalogues. See `divisionNameProvider`.
  String get _newDivisionName {
    final div = getDivision(widget.outcome.newDivision);
    return tName('division', {'id': div.id, 'name': div.name});
  }

  /// The division this season was played in, in the player's own language.
  String get _divisionName {
    final div = getDivision(widget.outcome.oldDivision);
    return tName('division', {'id': div.id, 'name': div.name});
  }

  /// The cup run as one sentence, or null when there was not one.
  String? get _cupLine {
    final run = widget.cup;
    if (run == null) return null;
    final def = getCupById(run.cupId);
    if (def == null) return null;
    // `tName` takes an id or a map, not a `Cup` — the definition's own name is
    // the fallback, so pass the id and let the catalogue answer. Same as
    // `fixture_caption.dart`.
    final name = tName('cup', {'id': def.id, 'name': def.name});
    if (run.outcome == 'won') return t('season.end.cup_won', {'cup': name});
    final rounds = def.rounds;
    // **The round is NAMED, not numbered.** `roundReached` is an index into the
    // cup's own list and printing it would read "out in the 2".
    final reached = run.roundReached.clamp(0, rounds.length - 1);
    return t('season.end.cup_out', {'cup': name, 'round': rounds[reached]});
  }

  String get _headline => switch (widget.outcome.outcome) {
    'promoted' => t('season.end.promoted', {
      'div': _newDivisionName,
    }),
    'relegated' => t('season.end.relegated', {
      'div': _newDivisionName,
    }),
    _ => t('season.end.stayed', {
      'div': _newDivisionName,
    }),
  };

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // First place is worth saying out loud even when it did not move you: the
    // top division has nowhere to be promoted to.
    final champion = widget.outcome.position == 1;

    return Scaffold(
      key: const ValueKey('season-end'),
      backgroundColor: kit.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t('season.end.title', {'n': widget.seasonNumber}),
                key: const ValueKey('season-end-title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kit.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              if (champion)
                Text(
                  t('season.end.champion'),
                  key: const ValueKey('season-end-champion'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: kit.accentBright,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _headline,
                key: const ValueKey('season-end-outcome'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.outcome.outcome == 'relegated'
                      ? Colors.redAccent
                      : kit.accent,
                ),
              ),
              const SizedBox(height: 20),
              // **WHERE HE FINISHED, as the figure the page is about.** It was
              // a row labelled `season.end.stat_record` — which is "Record",
              // the W-D-L line — with the POSITION as its value, so the one
              // number a season comes down to was mislabelled and the size of
              // a caption. The spec makes it the hero: the division over it,
              // the place with its ordinal, the outcome under it.
              Text(
                tName('division', {
                  'id': widget.outcome.oldDivision,
                  'name': getDivision(widget.outcome.oldDivision).name,
                }).toUpperCase(),
                key: const ValueKey('season-end-division'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: kit.textMuted,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${widget.outcome.position}'),
                    TextSpan(
                      text: ordinalSuffix(widget.outcome.position),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ],
                ),
                key: const ValueKey('season-end-position'),
                style: TextStyle(
                  fontSize: 54,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: kit.accentBright,
                ),
              ),
              const SizedBox(height: 16),
              // **THE SEASON IN THREE FIGURES.** `season.end.stat_record` and
              // `season.end.stat_goals` have sat translated in ten catalogues
              // with nothing able to print either — the whole band is the
              // spec's `.se-stats`, and it is what makes this a season
              // OVERVIEW rather than a verdict with a payout under it.
              if (widget.record case final r?)
                Row(
                  key: const ValueKey('season-end-stats'),
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(
                      value: '${seasonPoints(r)}',
                      label: t('table.col_pts'),
                    ),
                    _Stat(
                      value: '${r.wins}-${r.draws}-${r.losses}',
                      label: t('season.end.stat_record'),
                    ),
                    _Stat(
                      value: '${r.goalsFor}:${r.goalsAgainst}',
                      label: t('season.end.stat_goals'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // **WHO ACTUALLY WON IT.** `season.end.won_by` and its
              // `won_by_you` twin have sat translated in ten catalogues with
              // nothing able to print either, and it is the one fact this page
              // can give that the player's own row cannot.
              if (widget.winnerName case final name?)
                _SeasonLine(
                  lineKey: 'season-end-winner',
                  icon: 'trophy',
                  ink: widget.winnerIsUs ? kit.accentBright : kit.textMuted,
                  text: widget.winnerIsUs
                      ? t('season.end.won_by_you', {'div': _divisionName})
                      : t('season.end.won_by', {
                          'team': name,
                          'div': _divisionName,
                        }),
                ),
              // **AND HOW THE CUP WENT.** `cup_won` and `cup_out` are two more
              // of them, and a season with a cup run in it is not summarised by
              // its league finish alone.
              if (_cupLine case final line?)
                _SeasonLine(
                  lineKey: 'season-end-cup',
                  icon: widget.cup!.outcome == 'won' ? 'trophy' : 'cross',
                  ink: widget.cup!.outcome == 'won'
                      ? kit.accentBright
                      : kit.textMuted,
                  text: line,
                ),
              const SizedBox(height: 16),
              _Line(
                label: t('season.end.prize_label'),
                value: formatCoins(widget.outcome.payout),
                valueKey: 'season-end-payout',
              ),
              if (widget.outcome.gemsAwarded > 0)
                _Line(
                  label: t('shop.section.gems'),
                  value: '${widget.outcome.gemsAwarded}',
                  valueKey: 'season-end-gems',
                ),
              // **THE FINAL TABLE, FOLDED.** Twenty rows of a division the
              // player has just spent a season in is not what they came to
              // this page for — the verdict is — but the one who wants to
              // check the club below them should not have to leave to do it.
              // `season.end.view_table` and `hide_table` are two more keys
              // that shipped in ten languages with nothing able to print
              // either. The JS folds it exactly this way.
              if (widget.finalTable.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(
                  key: const ValueKey('season-end-table-toggle'),
                  onPressed: () => setState(() => _tableOpen = !_tableOpen),
                  child: Text(
                    t(
                      _tableOpen
                          ? 'season.end.hide_table'
                          : 'season.end.view_table',
                    ),
                  ),
                ),
                if (_tableOpen)
                  Flexible(
                    child: SingleChildScrollView(
                      key: const ValueKey('season-end-table'),
                      child: Column(
                        children: [
                          for (var i = 0; i < widget.finalTable.length; i++)
                            _TableRow(row: widget.finalTable[i], place: i + 1),
                        ],
                      ),
                    ),
                  ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('season-end-continue'),
                  onPressed: widget.onContinue,
                  child: Text(
                    t('season.end.continue', {'n': widget.seasonNumber + 1}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: kit.textMuted)),
          Text(
            value,
            key: ValueKey(valueKey),
            style: TextStyle(
              color: kit.accentBright,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One figure and its word, from the spec's `.se-stat`.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: kit.textMuted,
          ),
        ),
      ],
    );
  }
}

/// One fact about the season, on its own line — the spec's `.se-line`.
class _SeasonLine extends StatelessWidget {
  const _SeasonLine({
    required this.lineKey,
    required this.icon,
    required this.ink,
    required this.text,
  });

  final String lineKey;
  final String icon;
  final Color ink;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey(lineKey),
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(icon, size: 15, color: ink),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// One club in the folded final table.
///
/// Place, name, played and points — the four a player scans for. Not the whole
/// standings widget: that one is a live table with form dots and a movement
/// chevron, and neither means anything about a season that has finished.
class _TableRow extends StatelessWidget {
  const _TableRow({required this.row, required this.place});

  final LeagueRow row;
  final int place;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = row.isPlayer ? kit.accentBright : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$place',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ink ?? kit.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: row.isPlayer ? FontWeight.w900 : FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          Text(
            '${row.played}',
            style: TextStyle(
              fontSize: 11,
              color: kit.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${row.pts}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
