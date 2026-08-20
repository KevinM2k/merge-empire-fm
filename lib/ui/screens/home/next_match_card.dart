/// The fixture in front of you. Ported from `_nextMatchHtml` in
/// `ui/screens/LeagueScreen.js`.
///
/// The headline of the home screen, and the one thing that says what the Play
/// button is going to do. Five bands, top to bottom:
///
/// 1. **the standings**, one chip per side, on their own row — a name that
///    follows its position reads as the headline the position introduces, and the
///    chips stop the club names butting against the card's edge;
/// 2. **the two clubs**, with VS in the gutter between them;
/// 3. **the mirrored ATK/DEF block** with each side's rating flanking it, and the
///    modifiers that made those ratings what they are hung underneath;
/// 4. **the tactic**, in its own colour;
/// 5. **this fixture's match quests**.
///
/// **The HOME side is on the LEFT.** Not "us on the left with an AWAY label" —
/// the columns swap, which is what makes the card read like a fixture list
/// entry. Our name is the accent-coloured one, and that is the only distinction
/// the two columns need.
///
/// **The comparison is NUMBERS.** It has been five stars — which banded a 0–100
/// figure into five buckets, so 61 and 79 drew an identical row — and then a
/// proportional bar beside the figure, which is the same comparison drawn a
/// second time and less precisely.
///
/// Everything comes from `previewFixture`, the same call the match itself uses,
/// so the card cannot promise a fixture the sim then disagrees with.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/fixture_caption.dart';
import 'package:merge_empire_fc/ui/screens/home/match_quests_block.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/stat_display.dart';

/// One club's half of the card.
typedef MatchSide = ({
  String name,
  bool ours,
  int? rating,
  StatSide split,
  List<StatMod> mods,
  bool boot,

  /// Where they sit, and where they came from on the round just played. 3rd
  /// having climbed and 3rd having fallen are opposite stories.
  int? position,
  int? posDelta,
});

/// Everything the card draws, already in COLUMN order — home on the left.
typedef NextMatch = ({MatchSide left, MatchSide right, String? bonusNote});

/// The relegation lift, as the engine applies it. Named here because the chip
/// prints the figure.
const int _relegationBoost = 4;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

final nextMatchProvider = savePick<NextMatch?>((s) {
  final preview = previewFixture(s);
  if (preview == null) return null;

  final clubName =
      s['clubName'] is String && (s['clubName'] as String).isNotEmpty
      ? s['clubName'] as String
      : t('common.your_club');

  final table = buildLeagueTable(s);
  int rowFor(String name, {required bool ours}) =>
      table.indexWhere((LeagueRow r) => ours ? r.isPlayer : r.name == name);
  int? posOf(String name, {required bool ours}) {
    final i = rowFor(name, ours: ours);
    return i < 0 ? null : i + 1;
  }

  int? deltaOf(String name, {required bool ours}) {
    final i = rowFor(name, ours: ours);
    return i < 0 ? null : table[i].posDelta;
  }

  // Our split carries the TACTIC; the opponent's never does — they have not
  // picked one, and pretending otherwise would double-count the trade.
  final strategyId = _map(s['squad'])?['strategyId'];
  final strat =
      strategies[strategyId is String ? strategyId : defaultStrategy] ??
      strategies[defaultStrategy]!;
  final mult = tacticMultipliers(strat, preview.oppAttackRatio);
  final ours = fifaSplitTactic(
    preview.effAttack,
    preview.effDefence,
    mult.atk,
    mult.def,
  );
  final theirs = fifaSplit(
    preview.effOppAttackRating ?? 0,
    preview.effOppDefenceRating ?? 0,
  );

  // Each modifier is a delta ALREADY inside the rating beside it. The glyphs are
  // chosen for what is NOT already spoken for on this card: a house for home
  // advantage, a flame for a grudge, a bolt for a relegation scrap. A shield
  // would have read as the DEF row one line above, and a sword as ATK.
  final ourMods = <StatMod>[
    if (preview.isHome && preview.ourHomeAdv > 0)
      (
        icon: 'home',
        amount: preview.ourHomeAdv,
        colour: const Color(0xFF4ADE80),
        tip: t('play.mod.home_ours'),
      ),
    if (preview.playerInRelegationZone)
      (
        icon: 'bolt',
        amount: _relegationBoost,
        colour: const Color(0xFFFF9800),
        tip: t('play.mod.battle_ours'),
      ),
  ];
  final theirMods = <StatMod>[
    if (!preview.isHome && preview.theirHomeAdv > 0)
      (
        icon: 'home',
        amount: preview.theirHomeAdv,
        colour: const Color(0xFF4ADE80),
        tip: t('play.mod.home_theirs'),
      ),
    if (preview.grudgeBoost > 0)
      (
        icon: 'flame',
        amount: preview.grudgeBoost.round(),
        colour: vsRed,
        tip: t('play.mod.grudge'),
      ),
    if (preview.oppInRelegationZone)
      (
        icon: 'bolt',
        amount: _relegationBoost,
        colour: const Color(0xFFF44336),
        tip: t('play.mod.battle_theirs'),
      ),
  ];

  final usSide = (
    name: clubName,
    ours: true,
    rating: preview.effectiveSquadRating.round(),
    split: ours,
    mods: ourMods,
    boot: false,
    position: posOf(clubName, ours: true),
    posDelta: deltaOf(clubName, ours: true),
  );
  final themSide = (
    name: preview.opponentName,
    ours: false,
    rating: preview.effectiveOppRating?.round(),
    split: theirs,
    mods: theirMods,
    boot: preview.bootApplied,
    position: posOf(preview.opponentName, ours: false),
    posDelta: deltaOf(preview.opponentName, ours: false),
  );

  // Where the extra rating came from, when a club asset is supplying some.
  final cells = _map(s['grid'])?['cells'];
  final breakdown = computeSquadRatingBreakdown([
    for (final raw in (cells is List ? cells : const []))
      CardInstance.from(raw),
  ], fatigue: _map(s['settings'])?['hardMode'] == true);

  return (
    left: preview.isHome ? usSide : themSide,
    right: preview.isHome ? themSide : usSide,
    bonusNote: breakdown.matchBonus > 0
        ? t('league.rating_breakdown', {
            'base': breakdown.playerBase,
            'bonus': breakdown.matchBonus,
            // The JS carries a `matchBonusSource` and it is hard-null there
            // too, so the training line is the only path either build takes.
            'source': t('league.bonus_source_training'),
          })
        : null,
  );
});

class NextMatchCard extends ConsumerWidget {
  const NextMatchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(nextMatchProvider);
    // No fixture is a real state — a finished season, or a save that has not
    // drawn one yet — and an empty card would be worse than none.
    if (match == null) return const SizedBox.shrink();

    // GLASS, and DEEP because the card is tall enough to cross the sky's own
    // gradient.
    //
    // It was forced DARK in both themes and it is not any more. The reason it
    // was forced has gone: the sky was one fixed dusk-blue on a day→night clock,
    // so a `surface` panel was pale-on-pale at the bright end of the cycle and
    // the card never read as glass at either end of it. The sky follows the
    // theme now, so in light mode this is a light pane under the app's own ink —
    // and the one card on the screen that ignored the theme stops being that.
    // [GlassPanel] carries both recipes; nothing here has to know which.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FixtureCaption(),
        GlassPanel(
          key: const ValueKey('next-match-card'),
          density: GlassDensity.deep,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: _body(context, ref, match),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, NextMatch match) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Standings first, on their own row. Tried inline as "Crystal Palace
        // (3rd)" to save the band: it wrapped to a second line on the longer
        // half of most fixtures, and a position hanging under one club and
        // beside the other looked worse than the row it replaced.
        _Row(
          left: _PosChip(side: match.left),
          right: _PosChip(side: match.right),
          gutter: const SizedBox.shrink(),
          bottomSpacing: 6,
        ),
        _Row(
          left: _Name(side: match.left, note: match.bonusNote),
          right: _Name(side: match.right, note: match.bonusNote),
          // VS is on the NAMES row, which is why the standings moved out to a
          // row of their own. In a gutter spanning both, it centred between the
          // chip and the name — beside neither.
          gutter: Text(
            t('common.vs').toUpperCase(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kit.textMuted,
            ),
          ),
        ),
        MatchStatRows(
          left: match.left.split,
          right: match.right.split,
          leftRating: match.left.rating,
          rightRating: match.right.rating,
          leftMods: match.left.mods,
          rightMods: match.right.mods,
          leftBoot: match.left.boot,
          rightBoot: match.right.boot,
        ),
        // A rule across the card, then the tactic. It is a different KIND of
        // thing from the numbers above it — a decision rather than a readout —
        // and the line is what says so. It also let the chip drop its glyph,
        // which is a row of vertical space back on a card that has none to give.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Container(
            height: 1,
            color: glassInk(context).withValues(alpha: 0.12),
          ),
        ),
        const _TacticChip(),
        const MatchQuestsBlock(),
      ],
    );
  }
}

/// The card's three-track shape: `[1fr | gutter | 1fr]`. Every row keys off the
/// SAME fixed gutter, and that is what makes the ratings line up under the names.
class _Row extends StatelessWidget {
  const _Row({
    required this.left,
    required this.right,
    required this.gutter,
    this.bottomSpacing = 0,
  });

  final Widget left;
  final Widget right;
  final Widget gutter;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomSpacing),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Center(child: left)),
        const SizedBox(width: nmGap),
        SizedBox(
          width: nmGutter,
          child: Center(child: gutter),
        ),
        const SizedBox(width: nmGap),
        Expanded(child: Center(child: right)),
      ],
    ),
  );
}

/// `POS: 3rd ⌃⌃` — quiet glass, because the card already spends its colour on
/// ATK/DEF and a red or green pill beside those read as a third opinion on the
/// same fixture. The one coloured thing is the movement chevron.
class _PosChip extends StatelessWidget {
  const _PosChip({required this.side});

  final MatchSide side;

  @override
  Widget build(BuildContext context) {
    final pos = side.position;
    if (pos == null) return const SizedBox.shrink();
    final delta = side.posDelta ?? 0;

    return Container(
      key: ValueKey('nm-pos-${side.ours ? 'ours' : 'theirs'}'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: glassInk(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: glassInk(context).withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${t('play.pos_label')}:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$pos',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
                ),
                // The ordinal rides high against the numeral's cap line, so
                // "3rd" reads as one mark rather than a digit with a letter
                // parked after it.
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Text(
                    ordinalSuffix(pos),
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // A held position emits NOTHING rather than a blank the layout has to
          // reserve — the row centres the chip on its own.
          if (delta != 0) ...[
            const SizedBox(width: 2),
            // One glyph for both directions, the fall being the rise turned
            // over, so the two can never drift apart as shapes.
            Transform.rotate(
              angle: delta > 0 ? 0 : 3.14159,
              child: GameIcon(
                'chevrons',
                size: 11,
                color: delta > 0 ? const Color(0xFF4ADE80) : vsRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The club, and the biggest thing on the card — everything under it is an
/// annotation on it.
class _Name extends StatelessWidget {
  const _Name({required this.side, required this.note});

  final MatchSide side;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          side.name,
          key: ValueKey('nm-name-${side.ours ? 'ours' : 'theirs'}'),
          textAlign: TextAlign.center,
          // WRAPS rather than truncating. A club name is the one thing on this
          // card the player chose, and "Wandering Rov…" is most two-word names at
          // half a phone's width. The clamp is a backstop, not the normal case.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            height: 1.12,
            fontWeight: FontWeight.w900,
            color: side.ours ? kit.accentBright : null,
          ),
        ),
        if (side.ours && note != null)
          Text(
            note!,
            key: const ValueKey('nm-bonus-note'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: kit.textMuted),
          ),
      ],
    );
  }
}

/// The tactic, wearing its own colour, and a way to change it without leaving.
/// The tactic, as a LINE rather than a badge.
///
/// It was a filled, hairlined chip. On a pane that is itself glass that is a
/// second panel inside the first — and the row above it is already separated by a
/// rule, so the chip was saying "these two words are a group" twice. The colour
/// carries it: the tactic's own hue on its name is the whole identity, and it is
/// the same hue the Squad picker and the in-match strip use.
///
/// **BOTH HALVES AT ONE SIZE.** "TACTIC" at 9.5 and the name at 12 read as a
/// label with a heading stuck on the end of it. One size, one weight, and the
/// only difference between them is that the label is muted and the name is the
/// tactic's colour.
class _TacticChip extends ConsumerWidget {
  const _TacticChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final id = ref.watch(strategyIdProvider);
    final hue = tacticColor(context, id);
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      height: 1.1,
    );

    return InkWell(
      key: const ValueKey('nm-tactic'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => showTacticPicker(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NO GLYPH. The name already wears the tactic's colour; a fourth
            // statement of the same thing, in the one place the card has no
            // vertical room, is the easiest row on it to give back.
            Text(
              t('play.tactic_label').toUpperCase(),
              style: style.copyWith(color: kit.textMuted),
            ),
            const SizedBox(width: 6),
            Text(
              t('strategy.$id.name').toUpperCase(),
              style: style.copyWith(color: hue, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 3),
            Icon(Icons.chevron_right, size: 14, color: kit.textMuted),
          ],
        ),
      ),
    );
  }
}
