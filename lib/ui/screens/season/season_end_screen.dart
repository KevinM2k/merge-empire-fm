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
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
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

class SeasonEndScreen extends ConsumerWidget {
  const SeasonEndScreen({
    super.key,
    required this.outcome,
    required this.seasonNumber,
    this.record,
    this.onContinue,
  });

  final SeasonOutcome outcome;

  /// The season's own record, read off the save BEFORE `endSeason` rolled the
  /// counters on — see [seasonRecordOf]. Null draws the page without the stats
  /// band, for a caller that has not got one.
  final SeasonRecord? record;

  /// The season that just finished, captured BEFORE `endSeason` rolled it on.
  final int seasonNumber;

  final VoidCallback? onContinue;

  /// The league you have just moved into, in the player's own language.
  ///
  /// This card is the one screen a promotion exists for, and it named the
  /// league in English to every player in the world — `Division.name` is the
  /// data record's literal and `division.<id>` is translated in all ten
  /// catalogues. See `divisionNameProvider`.
  String get _newDivisionName {
    final div = getDivision(outcome.newDivision);
    return tName('division', {'id': div.id, 'name': div.name});
  }

  String get _headline => switch (outcome.outcome) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // First place is worth saying out loud even when it did not move you: the
    // top division has nowhere to be promoted to.
    final champion = outcome.position == 1;

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
                t('season.end.title', {'n': seasonNumber}),
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
                  color: outcome.outcome == 'relegated'
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
                  'id': outcome.oldDivision,
                  'name': getDivision(outcome.oldDivision).name,
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
                    TextSpan(text: '${outcome.position}'),
                    TextSpan(
                      text: ordinalSuffix(outcome.position),
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
              if (record case final r?)
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
              const SizedBox(height: 20),
              _Line(
                label: t('season.end.prize_label'),
                value: formatCoins(outcome.payout),
                valueKey: 'season-end-payout',
              ),
              if (outcome.gemsAwarded > 0)
                _Line(
                  label: t('shop.section.gems'),
                  value: '${outcome.gemsAwarded}',
                  valueKey: 'season-end-gems',
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('season-end-continue'),
                  onPressed: onContinue,
                  child: Text(
                    t('season.end.continue', {'n': seasonNumber + 1}),
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
