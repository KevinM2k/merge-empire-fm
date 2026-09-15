/// The trait box: two slots side by side, one reel under them.
///
/// **ONE BOX, TWO TILES.** The first slot and the second were two blocks, each
/// with its own reel and its own roll button, which read as two features that
/// happened to be stacked. Asked for from the couch: one box called Traits,
/// a PLAYER tile and a MATCH tile beside each other, and you pick the slot
/// you are rolling for by tapping it. The reel and the button underneath
/// belong to whichever tile is lit.
///
/// Both slots roll for coins — see `match_trait_engine.dart` for why the
/// second's gem gate went, and why every trait in its pool is conditional.
///
/// **The outcome is decided and PAID before the reel moves** — a spin that
/// decided at the end would have to be unwound when the debit was refused. So
/// the sheet is told to keep showing the man he was until the reels stop (the
/// [TraitHold] the first slot threads through the sheet); the second slot has
/// no rating to hold, and holds its own badge.
///
/// The wheel itself is `TraitReel`, ported from `mountTraitRoulette` in
/// `ui/components/TraitRoulette.js`. Both slots spin the same one.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart' show TraitGlyph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/match_traits.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/match_trait_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart' show findOurCard;
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/feature_unlock.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart' show proModeProvider;
import 'package:merge_empire_fc/ui/screens/squad/detail_controls.dart';
import 'package:merge_empire_fc/ui/screens/squad/trait_catalogue_sheet.dart';
import 'package:merge_empire_fc/ui/screens/squad/trait_reel.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// What the sheet is showing him as while the first slot's reels turn.
typedef TraitHold = ({Map<String, dynamic>? trait});

/// Which of the two slots the reel is spinning for.
enum TraitSlot { player, match }

class TraitBlock extends ConsumerStatefulWidget {
  const TraitBlock({
    super.key,
    required this.instanceId,
    required this.def,
    required this.hold,
    required this.onHold,
  });

  final String instanceId;
  final PlayerDef def;

  /// Owned by the sheet, because the rating and the trait's name are two
  /// readings of one question. Null when the reels are still.
  final TraitHold? hold;

  final ValueChanged<TraitHold?> onHold;

  @override
  ConsumerState<TraitBlock> createState() => TraitBlockState();
}

class TraitBlockState extends ConsumerState<TraitBlock> {
  /// One machine per slot, because switching tiles remounts the reel on the
  /// other pool and a remounted reel reads its start position on the way in.
  final GlobalKey<TraitReelState> _playerReel = GlobalKey<TraitReelState>();
  final GlobalKey<TraitReelState> _matchReel = GlobalKey<TraitReelState>();

  /// Test seams: the spin and the answer flash, as the reel times them.
  static const Duration spin = TraitReelState.spin;
  static const Duration flash = TraitReelState.flash;

  TraitSlot _slot = TraitSlot.player;
  bool _spinning = false;

  /// What the MATCH tile shows while its reels turn — the trait he HAD.
  Map<String, dynamic>? _shownMatch;

  /// Test seams.
  bool get spinning => _spinning;
  TraitSlot get slot => _slot;

  /// Where the reels start: on what the card ALREADY has — the JS's own first
  /// act. A reel parked on the top of the pool tells the player their man has
  /// whatever happens to sort first.
  ({int name, int level}) _initial(List<String> ids, Map<String, dynamic>? trait) {
    final id = trait?['id'] as String?;
    final at = ids.indexOf(id ?? '');
    return (
      name: at < 0 ? 0 : at,
      level: id == null || id == 'none'
          ? noneRow
          : (((trait?['level'] as num?)?.toInt() ?? 1) - 1).clamp(0, 2),
    );
  }

  void _select(TraitSlot slot) {
    if (_spinning || slot == _slot) return;
    setState(() => _slot = slot);
  }

  Future<void> _roll(List<Trait> pool) async {
    if (_spinning) return;
    if (_slot == TraitSlot.match) return _rollMatch();
    final was = _map(
      findOurCard(ref.read(gameProvider).state, widget.instanceId)?.raw['trait'],
    );
    final result = ref
        .read(gameProvider)
        .update((s) => rollTraitForCard(s, widget.instanceId));
    final roll = result.roll;
    if (!result.ok || roll == null) return;
    final landing = pool.indexWhere((t) => t.id == roll.id);
    if (landing < 0) return;
    // **A roll can LOSE.** `none` is in the pool, and when it comes up the
    // level it rolled alongside means nothing.
    final isNone = roll.id == 'none';
    final reel = _playerReel.currentState;
    if (reel == null) return;
    setState(() => _spinning = true);
    widget.onHold((trait: was));
    await reel.spinTo(
      nameIndex: landing,
      levelRow: isNone ? noneRow : (roll.level - 1).clamp(0, 2),
    );
    if (!mounted) return;
    setState(() => _spinning = false);
    widget.onHold(null);
    await reel.flashAnswer(
      isNone ? const Color(0xFFF87171) : const Color(0xFF00B45A),
    );
    if (!mounted) return;
    // A lost roll is not celebrated: the red band is the whole of its answer.
    if (isNone) return;
    final trait = getTrait(roll.id);
    if (trait == null) return;
    await showFeatureUnlock(
      context,
      title: traitTitle({'id': roll.id, 'level': roll.level}),
      subtitle: traitDesc(trait),
      icon: TraitGlyph(trait.icon, size: 44, color: Theme.of(context).extension<KitTheme>()!.accentBright),
      accent: Theme.of(context).extension<KitTheme>()!.accentBright,
      starCount: roll.level.clamp(1, 3),
    );
  }

  Future<void> _rollMatch() async {
    final game = ref.read(gameProvider);
    final was = matchTraitOf(findOurCard(game.state, widget.instanceId));
    final result = game.update((s) => rollMatchTraitForCard(s, widget.instanceId));
    final roll = result.roll;
    if (!result.ok || roll == null) return;
    final landing = matchTraitList.indexWhere((t) => t.id == roll.id);
    if (landing < 0) return;
    final reel = _matchReel.currentState;
    if (reel == null) return;
    setState(() {
      _spinning = true;
      _shownMatch = was ?? const <String, dynamic>{};
    });
    await reel.spinTo(nameIndex: landing, levelRow: (roll.level - 1).clamp(0, 2));
    if (!mounted) return;
    setState(() {
      _spinning = false;
      _shownMatch = null;
    });
    // Always green: there is no losing roll in this pool.
    await reel.flashAnswer(const Color(0xFF00B45A));
    if (!mounted) return;
    final trait = getMatchTrait(roll.id);
    if (trait == null) return;
    await showFeatureUnlock(
      context,
      title: matchTraitTitle({'id': roll.id, 'level': roll.level}),
      subtitle: matchTraitDesc(trait),
      icon: TraitGlyph(trait.icon, size: 44, color: Theme.of(context).extension<KitTheme>()!.accentBright),
      accent: Theme.of(context).extension<KitTheme>()!.accentBright,
      starCount: roll.level.clamp(1, 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = ref.watch(gameProvider).state;
    final card = findOurCard(state, widget.instanceId);
    final cost = traitRollCost(widget.def);
    final coins = ref.watch(coinsProvider);
    final pool = getTraitPoolForPosition(
      widget.def.position,
      hardMode: ref.watch(proModeProvider),
    );
    final ratios = _map(state?['definitionRatios']) ?? const {};

    // Mid-spin each tile shows what he had, not what he just won.
    final playerTrait = widget.hold != null
        ? widget.hold!.trait
        : _map(card?.raw['trait']);
    final playerHeld = getTrait(playerTrait?['id'] as String?);
    final shownMatch = _shownMatch ?? matchTraitOf(card);
    final matchTrait = shownMatch == null || shownMatch.isEmpty ? null : shownMatch;
    final matchHeld = getMatchTrait(matchTrait?['id'] as String?);

    final playerInitial = _initial(
      [for (final t in pool) t.id],
      _map(card?.raw['trait']),
    );
    final matchInitial = _initial(
      [for (final t in matchTraitList) t.id],
      matchTraitOf(card),
    );
    final lit = playerHeld != null || matchHeld != null;
    final matchSelected = _slot == TraitSlot.match;

    return Container(
      key: const ValueKey('detail-trait'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // A trait is a possession, so the box looks like one: a card that HAS
        // one wears the accent, one that does not stays quiet.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: lit
              ? [
                  Color.alphaBlend(kit.accent.withValues(alpha: 0.16), kit.surface),
                  kit.surface,
                ]
              : [kit.surface2, kit.surface2],
        ),
        border: Border.all(
          color: lit ? kit.accent : kit.border,
          width: lit ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('squad.traits').toUpperCase(),
                  style: TextStyle(
                    color: lit ? kit.accentBright : kit.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              // Every trait there is, and what it does — see the sheet.
              GestureDetector(
                key: const ValueKey('detail-trait-catalogue'),
                behavior: HitTestBehavior.opaque,
                onTap: () => showTraitCatalogue(
                  context,
                  position: widget.def.position,
                  hardMode: ref.read(proModeProvider),
                  card: card,
                  ratios: ratios,
                  heldPlayer: playerHeld?.id,
                  heldMatch: matchHeld?.id,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    t('squad.traits.all'),
                    style: TextStyle(
                      color: kit.accentBright,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationColor: kit.accentBright,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SlotTile(
                  tileKey: const ValueKey('detail-trait-slot-player'),
                  label: t('squad.trait.slot.player'),
                  selected: !matchSelected,
                  glyph: playerHeld?.icon ?? '?',
                  lit: playerHeld != null,
                  level: _roman(playerTrait),
                  levelKey: const ValueKey('detail-trait-level'),
                  caption: playerHeld == null
                      ? t('trait.name.none')
                      : traitTitle(playerTrait!),
                  onTap: () => _select(TraitSlot.player),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SlotTile(
                  tileKey: const ValueKey('detail-trait-slot-match'),
                  label: t('squad.trait.slot.match'),
                  selected: matchSelected,
                  // Open on every card — the gem gate went; see
                  // `matchTraitOf`.
                  glyph: matchHeld?.icon ?? '?',
                  lit: matchHeld != null,
                  level: _roman(matchTrait),
                  levelKey: const ValueKey('detail-matchtrait-level'),
                  caption: matchHeld == null
                      ? t('trait.name.none')
                      : matchTraitTitle(matchTrait!),
                  onTap: () => _select(TraitSlot.match),
                ),
              ),
            ],
            ),
          ),
          ...[
            const SizedBox(height: 6),
            // **THE PANE BELONGS TO THE LIT TILE.** A notch on its top edge
            // slides under whichever slot is selected, so the description and
            // the reel read as that slot's and not as a third thing. Asked
            // for from the couch: the spinner is the player's too.
            _PaneNotch(atRight: matchSelected, colour: kit.accent),
            _Pane(
              colour: kit.accent,
              fill: kit.surface.withValues(alpha: 0.5),
              children: [
            if (matchSelected && matchHeld != null) ...[
              _Description(
                icon: matchHeld.icon,
                title: matchTraitTitle(matchTrait!),
                desc: matchTraitDesc(matchHeld),
                when: matchTraitWhen(matchHeld),
                effects: [
                  if (getMatchTraitLevel(
                        matchHeld,
                        (matchTrait['level'] as num?)?.toInt() ?? 1,
                      )
                      case final level?)
                    matchTraitEffect(matchHeld, level),
                ],
              ),
              const SizedBox(height: 10),
            ] else if (!matchSelected && playerHeld != null) ...[
              _Description(
                icon: playerHeld.icon,
                title: traitTitle(playerTrait!),
                desc: traitDesc(playerHeld),
                effects: traitEffectsOn(card, playerTrait, ratios),
              ),
              const SizedBox(height: 10),
            ],
            if (matchSelected)
              Opacity(
                opacity: 1,
                child: TraitReel(
                key: _matchReel,
                keyPrefix: 'matchtrait-reel',
                names: [
                  for (final trait in matchTraitList)
                    _ReelName(icon: trait.icon, name: matchTraitName(trait)),
                ],
                initialName: matchInitial.name,
                initialLevel: matchInitial.level,
                ),
              )
            else
              TraitReel(
                key: _playerReel,
                names: [
                  for (final trait in pool)
                    _ReelName(icon: trait.icon, name: traitName(trait)),
                ],
                initialName: playerInitial.name,
                initialLevel: playerInitial.level,
              ),
            const SizedBox(height: 10),
            // The cost rides on the button: this is the only gamble on the
            // sheet, so the thing you press says what it takes.
            HeroPill(
              buttonKey: const ValueKey('detail-trait-roll'),
              glyph: 'star',
              label: t('game.trait.cost', {'cost': formatCoins(cost)}),
              gold: true,
              onTap: _spinning || coins < cost ? null : () => _roll(pool),
            ),
            if (coins < cost)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t('game.trait.need_coins', {'cost': formatCoins(cost)}),
                  key: const ValueKey('detail-trait-blocked'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kit.textMuted),
                ),
              ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _roman(Map<String, dynamic>? trait) {
    final id = trait?['id'] as String?;
    if (id == null || id == 'none') return null;
    final level = (trait?['level'] as num?)?.toInt() ?? 0;
    return level > 0 ? romanLevels[level.clamp(1, 3) - 1] : null;
  }
}

/// One slot: its name over the medal, and what it holds under it. The lit
/// one is the slot the reel below is spinning for.
class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.tileKey,
    required this.label,
    required this.selected,
    required this.glyph,
    required this.lit,
    required this.level,
    required this.levelKey,
    required this.caption,
    required this.onTap,
  });

  final Key tileKey;
  final String label;
  final bool selected;
  final String glyph;

  final bool lit;
  final String? level;
  final Key levelKey;
  final String caption;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = lit ? kit.accent : kit.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: tileKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
          child: Column(
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: selected ? kit.accentBright : kit.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              TraitDisc(
                glyph: glyph,
                colour: ink,
                fill: lit ? kit.accent.withValues(alpha: 0.18) : kit.surface2,
                level: level,
                levelInk: kit.accentInk,
                levelKey: levelKey,
                compact: true,
                selected: selected,
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                key: ValueKey('${(tileKey as ValueKey).value}-caption'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: lit ? kit.accentBright : kit.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The panel under the tiles: the lit slot's trait in words, the reel, the
/// roll. Bordered in the accent so it reads with the lit tile above it.
class _Pane extends StatelessWidget {
  const _Pane({
    required this.colour,
    required this.fill,
    required this.children,
  });

  final Color colour;
  final Color fill;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colour, width: 1.6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// The notch on the pane's top edge, under the lit tile. Slides between the
/// two rather than jumping, so the eye follows which slot took the pane.
class _PaneNotch extends StatelessWidget {
  const _PaneNotch({required this.atRight, required this.colour});

  final bool atRight;
  final Color colour;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 8,
    child: AnimatedAlign(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment(atRight ? 0.5 : -0.5, 1),
      child: CustomPaint(
        size: const Size(16, 8),
        painter: _NotchPainter(colour),
      ),
    ),
  );
}

class _NotchPainter extends CustomPainter {
  const _NotchPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_NotchPainter old) => old.colour != colour;
}

/// The lit slot's trait, named, described, and — for the first slot — costed
/// IN POINTS: what the card reads with it minus the card without.
class _Description extends StatelessWidget {
  const _Description({
    required this.icon,
    required this.title,
    required this.desc,
    required this.effects,
    this.when,
  });

  final String icon;
  final String title;
  final String desc;
  final List<String> effects;

  /// The circumstance a match trait fires in. Null for the first slot, which
  /// is always on.
  final String? when;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('detail-trait-label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TraitGlyph(icon, size: 16, color: kit.accentBright),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: kit.accentBright,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          key: const ValueKey('detail-trait-desc'),
          style: TextStyle(fontSize: 12, height: 1.35, color: kit.textMuted),
        ),
        // **WHEN on the left, WHAT on the right.** The room to the right of
        // the description was empty and the chips sat under it in a third
        // row; one row now, the circumstance leading and the figures
        // trailing. A first-slot trait has no WHEN and its chips lead.
        if (when != null || effects.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (when case final w?)
                Expanded(
                  child: Text(
                    '${t('matchtrait.when').toUpperCase()} · $w',
                    key: const ValueKey('detail-trait-when'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: kit.accentBright,
                    ),
                  ),
                ),
              if (effects.isNotEmpty)
                Wrap(
                  key: const ValueKey('detail-trait-effects'),
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final row in effects)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: kit.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            row,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: kit.accentBright,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One name on a reel: the trait's mark, then its name.
class _ReelName extends StatelessWidget {
  const _ReelName({required this.icon, required this.name});

  final String icon;
  final String name;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TraitGlyph(icon, size: 14, color: Theme.of(context).colorScheme.onSurface),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}
