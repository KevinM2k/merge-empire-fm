/// What happened while the squad was on its break. Ported from
/// `_showOffseasonReport` in `../merge-empire-fc/src/ui/screens/LeagueScreen.js`.
///
/// **Eleven `offseason.*` strings, translated into ten catalogues, with nothing
/// able to print one — and the engine had been producing the data all along.**
/// `endSeason` returns `injuryReport`, `sponsorReport` and `ageingReport` and
/// even emits them on `season:ended`; every reader of those three fields was a
/// test. This is the reader.
///
/// **It arrives, so it goes through `enqueuePopup`.** Nobody asks for the
/// offseason report — it lands after the season-end screen, on a save the
/// player has just finished with — which is the difference between this and the
/// prestige card, and it is the queue's whole reason to exist.
///
/// **Only what can actually happen is drawn.** The JS's ageing rows carry a
/// `fromTierName → toTierName` decline and an `ageingPenalty` note, and neither
/// can ever fire: `processAgeRegression` — in both codebases, character for
/// character — reports nothing but retirements, always with `retired: true` and
/// a zero penalty. Porting the branch would be porting a screen state the
/// shipped game cannot reach, so it is left out and said here instead.
///
/// **`offseason.subtitle` and the section header carry `<b>` markup**, which is
/// stripped at the `t()` boundary rather than honoured — the copy was written
/// for a DOM. This card was one of the nine that fix was made for.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart' show vsRedOn;

/// Whether the break did anything worth a card.
///
/// The JS's `hasOffseasonNews`, named rather than inlined: a season where
/// nobody was hurt, nobody was sponsored and nobody retired has an empty report,
/// and a popup that opens to say nothing happened is worse than no popup.
bool offseasonHasNews(SeasonOutcome outcome) =>
    outcome.injuryReport.recovered + outcome.injuryReport.shortened > 0 ||
    outcome.sponsorReport.expired > 0 ||
    outcome.ageingReport.isNotEmpty;

Future<void> showOffseasonReport(
  BuildContext context,
  SeasonOutcome outcome,
) => showDialog<void>(
  context: context,
  barrierColor: coachCardScrim,
  builder: (_) => OffseasonReportCard(outcome: outcome),
);

class OffseasonReportCard extends StatelessWidget {
  const OffseasonReportCard({super.key, required this.outcome});

  final SeasonOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final injuries = outcome.injuryReport;
    final veterans = outcome.ageingReport;

    // Singular and plural are separate KEYS rather than one string with a
    // number in it, which is how the catalogue can be right in ten languages
    // without the port knowing any of their rules.
    final summary = <({String glyph, String text})>[
      if (injuries.recovered > 0)
        (
          glyph: '⚕️',
          text: t(
            injuries.recovered == 1
                ? 'offseason.injuries_recovered_one'
                : 'offseason.injuries_recovered_n',
            {'n': injuries.recovered},
          ),
        ),
      if (injuries.shortened > 0)
        (
          glyph: '⏱️',
          text: t(
            injuries.shortened == 1
                ? 'offseason.injuries_shortened_one'
                : 'offseason.injuries_shortened_n',
            {'n': injuries.shortened},
          ),
        ),
      if (outcome.sponsorReport.expired > 0)
        (
          glyph: '📄',
          text: t(
            outcome.sponsorReport.expired == 1
                ? 'offseason.sponsors_expired_one'
                : 'offseason.sponsors_expired_n',
            {'n': outcome.sponsorReport.expired},
          ),
        ),
    ];

    return CoachCardFrame(
      key: const ValueKey('offseason-report'),
      title: t('offseason.title'),
      body: t('offseason.subtitle'),
      actions: [CoachAction(labelKey: 'common.continue', onTap: () {})],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in summary)
            _SummaryRow(glyph: row.glyph, text: row.text),
          if (veterans.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Heading(
              t(
                veterans.length == 1
                    ? 'offseason.veterans_declining_one'
                    : 'offseason.veterans_declining_n',
              ),
            ),
            for (final row in veterans)
              _VeteranRow(
                name: '${row['playerName'] ?? ''}',
                // Every row the engine can produce is a retirement; see the
                // header. The glyph is the JS's own for that case.
                note: t('offseason.retired'),
                // The port's shared "this went against us" red, theme-aware —
                // the same one a goal conceded and a wage line are drawn in.
                tone: vsRedOn(context),
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.glyph, required this.text});

  final String glyph;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(glyph, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _VeteranRow extends StatelessWidget {
  const _VeteranRow({
    required this.name,
    required this.note,
    required this.tone,
  });

  final String name;
  final String note;
  final Color tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(note, style: TextStyle(fontSize: 11, color: tone)),
            ],
          ),
        ),
        const Text('🚶', style: TextStyle(fontSize: 16)),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).extension<KitTheme>()!.textMuted,
      ),
    ),
  );
}
