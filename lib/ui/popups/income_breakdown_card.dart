/// The books, as Colin reads them. Ported from `_showIncomeBreakdown` in
/// `../merge-empire-fc/src/ui/components/HUD.js`.
///
/// **A Coach Colin card, and the JS's reason survives**: checking the books is
/// like asking the manager how the money is coming in. It reuses his chrome
/// there and it reuses `CoachCardFrame` here, so the one screen in the game that
/// is nothing but numbers still arrives in somebody's voice.
///
/// **The headline is the NET rate.** Wages come off after the multiplier, so a
/// gross figure with a wage line under it prints a number that never arrives —
/// and the negative case is the whole reason this screen was asked for: a
/// loaned-in player costs money every second, and the only sign of it was the
/// idle bar quietly running backwards.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/income_breakdown.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsAmberOn, vsRedOn;
import 'package:merge_empire_fc/util/format.dart';

Future<void> showIncomeBreakdown(
  BuildContext context, {
  required Map<String, dynamic>? state,
}) => showDialog<void>(
  context: context,
  builder: (_) => _IncomeCard(books: incomeBreakdown(state)),
);

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.books});

  final IncomeBreakdown books;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return CoachCardFrame(
      key: const ValueKey('income-breakdown'),
      title: t('hud.income.title'),
      badge: '💰',
      actions: [CoachAction(labelKey: 'common.close', onTap: () {})],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The one figure that matters, and the size says so.
          Text(
            '+${formatRate(books.net)}',
            key: const ValueKey('income-net'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              // Red when nothing is coming in. It is the only state on this
              // card a player has to do something about.
              color: books.capped ? vsRedOn(context) : kit.accentBright,
            ),
          ),
          const SizedBox(height: 12),
          _Heading(t('hud.income.base_players')),
          if (books.players.isEmpty)
            _Quiet(t('hud.income.no_players'))
          else ...[
            for (final row in books.players.take(incomeRowsShown))
              _Row(
                // A sponsored player and an injured one are both still earning,
                // and the figure alone does not say which is which — the star
                // and the plaster are why a row that looks wrong is explicable.
                label:
                    '${row.name}'
                    '${row.sponsored ? ' ★' : ''}'
                    '${row.injured ? ' 🤕' : ''}',
                value: '+${row.perSec.toStringAsFixed(2)}/s',
                tone: kit.accentBright,
                // An injured player earns a fraction; dimming the row says the
                // small number is a state rather than a bad signing.
                faded: row.injured,
              ),
            if (books.players.length > incomeRowsShown)
              _Quiet(
                t('hud.income.and_more', {
                  'n': books.players.length - incomeRowsShown,
                }),
              ),
            _Total(
              label: t('hud.income.base_total'),
              value: '+${books.base.toStringAsFixed(2)}/s',
              tone: kit.accentBright,
            ),
          ],
          const SizedBox(height: 12),
          _Heading(t('hud.income.multipliers')),
          if (books.factors.isEmpty)
            _Quiet(t('hud.income.none'))
          else ...[
            for (final factor in books.factors)
              _Row(
                // The merch row names the asset, and the asset names itself —
                // the engine hands over a key rather than a word so the club's
                // own copy is what appears.
                label: t(factor.key, {
                  ...factor.params,
                  if (factor.params['name'] case final String key)
                    'name': t(key),
                }),
                value: '×${factor.x.toStringAsFixed(2)}',
                tone: vsAmberOn(context),
              ),
            _Total(
              label: t('hud.income.combined'),
              value: '×${books.multiplier.toStringAsFixed(2)}',
              tone: vsAmberOn(context),
            ),
          ],
          // **The only block on this card that SUBTRACTS**, and its own section
          // rather than negative rows among the players: a wage is not a small
          // income, it is the reason the headline sits below what the
          // multipliers promise.
          if (books.loans.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Heading(t('hud.income.loan_wages')),
            for (final row in books.loans)
              _Row(
                label: row.name,
                value: '-${row.perSec.toStringAsFixed(2)}/s',
                tone: vsRedOn(context),
              ),
            _Total(
              label: t('hud.income.net'),
              value: '+${formatRate(books.net)}',
              tone: books.capped ? vsRedOn(context) : kit.accentBright,
            ),
            if (books.capped)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t('hud.income.wages_capped'),
                  key: const ValueKey('income-capped'),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: vsRedOn(context),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
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

class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).extension<KitTheme>()!.textMuted,
    ),
  );
}

/// A name on the left and a figure on the right.
///
/// **Tabular figures**, so a column of rates lines up on the decimal point
/// rather than wandering with the digits above it — which is the whole reason a
/// list of numbers is readable as a list at all.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.tone,
    this.faded = false,
  });

  final String label;
  final String value;
  final Color tone;
  final bool faded;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: faded ? 0.5 : 1,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: tone,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The line under a section, over a rule.
class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.only(top: 6),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).extension<KitTheme>()!.border),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: tone,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
