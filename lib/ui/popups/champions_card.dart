/// The night the game is won. Ported from `_showChampionsCelebration` in
/// `../merge-empire-fc/src/ui/screens/LeagueScreen.js`.
///
/// **Nine `champ.*` strings shipped in ten languages with nothing able to print
/// one**, and the queue could not tell from here whether they were the endgame
/// or a duplicate of the prestige card. They are not a duplicate. The JS has
/// TWO surfaces and they are different moments: `_showPrestigeColin` is the
/// dock star, which the port already had, and this is the CELEBRATION — fired
/// once, from the season-end chain, when the top flight has been won.
///
/// **It is the same prestige flow underneath.** Both of the JS's cards call
/// `_doPrestige`, so this one calls [confirmAndPrestige] rather than growing a
/// second reset. What it adds is the moment: a title, what the reset buys, what
/// Pro mode is, and — the option the dock card has never offered — the right to
/// say no and go on defending it.
///
/// **`champ.defend` is why the card can be dismissed at all.** The JS's own
/// note is that declining is respected and the permanent New Adventure offer
/// stays available afterwards, which is exactly what the port's prestige orb
/// already is.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/prestige_card.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Whether this season was the one that won it.
///
/// Read off the OUTCOME rather than off `wonChampionsCup`: the flag is
/// permanent — it is what keeps the prestige orb on the dock for ever after —
/// so a save that won the title three seasons ago would celebrate again every
/// May. The title is a thing that happened once, on this table.
bool wonTheTitle(SeasonOutcome outcome) =>
    outcome.oldDivision == 'champions_cup' && outcome.position == 1;

Future<int?> showChampionsCelebration(
  BuildContext context,
  WidgetRef ref,
) async {
  final pro = ref.read(hardModeProvider);
  final mult = formatPrestigeMultiplier(
    nextPrestigeMultiplier(ref.read(gameProvider).state),
  );

  final answer = await showDialog<bool>(
    context: context,
    builder: (_) => _ChampionsCard(pro: pro, mult: mult),
  );
  // Null is the barrier tap and `champ.defend` is the button; both mean the
  // same thing and neither writes anything.
  if (answer == null || !context.mounted) return null;
  return confirmAndPrestige(context, ref, toPro: answer);
}

class _ChampionsCard extends StatelessWidget {
  const _ChampionsCard({required this.pro, required this.mult});

  /// A save already in Pro is not pitched Pro. The JS hides the whole block
  /// and the button with it — an upsell to somewhere the player is standing.
  final bool pro;
  final String mult;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return CoachCardFrame(
      key: const ValueKey('champions-card'),
      title: t('champ.title'),
      badge: '🏆',
      actions: [
        CoachAction(
          labelKey: 'champ.new_adventure',
          tone: CoachTone.confirm,
          onTap: () {},
          result: false,
        ),
        if (!pro)
          CoachAction(
            labelKey: 'champ.pro_cta',
            tone: CoachTone.confirm,
            onTap: () {},
            result: true,
          ),
        // Not a decline: nothing is being refused, the career simply carries
        // on. The orb keeps the offer standing for whenever they want it.
        CoachAction(labelKey: 'champ.defend', onTap: () {}),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('champ.subtitle'),
            key: const ValueKey('champ-subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: kit.accentBright,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t('champ.body'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: kit.textMuted),
          ),
          const SizedBox(height: 14),
          // **Two offers, and they are boxed because they are offers.** The
          // body above is the moment; these are what the buttons under them
          // actually do, and running them together as one paragraph is how a
          // player agrees to a career reset having read the congratulations.
          _Teaser(
            heading: t('prestige.title'),
            body: t('champ.prestige_teaser', {'mult': mult}),
            tone: kit.accentBright,
          ),
          if (!pro) ...[
            const SizedBox(height: 8),
            _Teaser(
              heading: t('champ.pro_title'),
              body: t('champ.pro_teaser'),
              tone: kit.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _Teaser extends StatelessWidget {
  const _Teaser({
    required this.heading,
    required this.body,
    required this.tone,
  });

  final String heading;
  final String body;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kit.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: tone,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 12, height: 1.5, color: kit.textMuted),
          ),
        ],
      ),
    );
  }
}
