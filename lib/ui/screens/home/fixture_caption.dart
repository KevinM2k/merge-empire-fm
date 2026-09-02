/// `── PREMIER DIVISION · MATCH 12 ──`, over the next-match card. Ported from
/// `.league-fixture-caption` in `ui/screens/LeagueScreen.js`.
///
/// **It says WHICH fixture the card is.** Without it the card is two clubs and a
/// VS with no competition and no place in the season — a player could not tell a
/// league game from a cup tie except by the colour of the Play button, and could
/// not tell match 3 from match 30 at all.
///
/// The two rules either side are the JS's `:before`/`:after`: 62px each, fading
/// out of the club's accent into nothing, which is what stops a line of small
/// caps floating unattached over the glass.
///
/// A cup tie takes priority when one is due, because that is the fixture the
/// card is actually showing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/play_freeze.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// The competition, and where in it this fixture sits.
typedef FixtureLabel = ({String competition, String round});

final fixtureLabelProvider = savePick<FixtureLabel>((s) {
  // A due cup round IS the next fixture, so it names the caption.
  final cup = activeCup(s);
  if (cup != null && cupDue(s)) {
    final def = getCupById(cup['cupId'] as String?);
    final at = _num(cup['round']).toInt();
    final round = def != null && at < def.rounds.length
        ? def.rounds[at]
        : t('cup.tip.generic_round');
    // `tName` takes an id or a map, not a `Cup` — the definition's own name is
    // the fallback, so pass the id and let the catalogue answer.
    return (
      competition: def != null
          ? (t('cup.${def.id}') == 'cup.${def.id}'
                ? def.name
                : t('cup.${def.id}'))
          : tName('cup', cup['cupId']),
      round: round,
    );
  }

  final progression = _map(s['progression']);
  // **`seasonMatchesPlayed`, NOT `matchesPlayed`.** They are two different
  // counters and only one of them is a season: `matchesPlayed` is the CAREER
  // total and is reset by nothing but a full wipe, while `seasonMatchesPlayed`
  // is what `endSeason` puts back to zero. Reading the career one and then
  // clamping it to the season's length means the caption climbs to the cap and
  // stays there for ever — reported as the Play tab always saying "Match 14"
  // whatever the fixture was, which is exactly what fourteen career games and a
  // fourteen-match season produce. Every other consumer of this figure — the
  // table, the quests, the fixture preview, the cup launcher, the engine that
  // writes it — was already on the season counter.
  final played = _num(progression?['seasonMatchesPlayed']).toInt();
  return (
    competition: tName('division', progression?['currentDivision']),
    // Clamped, because the last match of a season is match 14 and not 15 — the
    // count is only reset once the season rolls over.
    round: t('play.matchLabel', {
      'n': played + 1 < matchesPerSeason ? played + 1 : matchesPerSeason,
    }),
  );
});

class FixtureCaption extends ConsumerWidget {
  const FixtureCaption({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // HELD with the card under it — see `play_freeze.dart`. "Match 6" over
    // match five's teams is the same fault told twice.
    final frozen = ref.watch(playFreezeProvider);
    final FixtureLabel label = frozen?.label ?? ref.watch(fixtureLabelProvider);

    // The ink the SKY wants — see [skyInk]. This line sits directly on the
    // diorama with nothing behind it, and it used to be white in both themes
    // because the sky ran from noon to midnight on a clock. It does not any
    // more: a daylit sky gets the app's own near-black with a white halo, a
    // floodlit one gets white with a dark halo.
    final (ink: ink, inkSoft: inkSoft, shadows: shadows) = skyInk(context);

    return Padding(
      key: const ValueKey('fixture-caption'),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 7),
      // **No ellipsis anywhere.** A division's name is a name; "PREMIER
      // DIVISI…" is not one. The JS clips it because it has nowhere else to go;
      // here the whole line scales down instead, so a long competition on a
      // narrow phone reads a point smaller and reads in full.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Rule(
              ink: kit.accentBright,
              halo: shadows.first.color,
              fromLeft: true,
            ),
            const SizedBox(width: 6),
            Text(
              label.competition.toUpperCase(),
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: ink,
                shadows: shadows,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '·',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: inkSoft.withValues(alpha: 0.55),
                shadows: shadows,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label.round.toUpperCase(),
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: inkSoft,
                shadows: shadows,
              ),
            ),
            const SizedBox(width: 6),
            _Rule(
              ink: kit.accentBright,
              halo: shadows.first.color,
              fromLeft: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two rules — the JS's 62px, fixed. Fixed rather than flexible
/// because the line is inside a `FittedBox` now: a flex child has no width to
/// flex against under unbounded constraints, and the scaling handles the case a
/// flex was there for.
class _Rule extends StatelessWidget {
  const _Rule({required this.ink, required this.halo, required this.fromLeft});

  final Color ink;

  /// The rule's own shadow, which inverts with the sky the same way the text's
  /// does — a dark line on a bright sky needs a light one under it.
  final Color halo;
  final bool fromLeft;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    child: Container(
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [ink.withValues(alpha: 0), ink],
        ),
        boxShadow: [
          BoxShadow(color: halo, blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
    ),
  );
}
