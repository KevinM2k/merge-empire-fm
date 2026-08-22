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
    this.onContinue,
  });

  final SeasonOutcome outcome;

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
              const SizedBox(height: 24),
              _Line(
                label: t('season.end.stat_record'),
                value: '${outcome.position}',
                valueKey: 'season-end-position',
              ),
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
