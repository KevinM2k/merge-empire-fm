/// Every trait a player could roll, in one place — what it is and what it does.
///
/// The reel shows a pool a row at a time and the medal shows the one you
/// have; nowhere said what the other fourteen were, or what a match trait is
/// FOR. Asked for from the couch: a popup of all of them, to get people
/// excited about opening the match slot. A bottom sheet, because it is a
/// list to browse rather than a question to answer.
///
/// The PLAYER half is this position's own pool — a keeper is not shown
/// Finisher — and the MATCH half is the whole pool, because that one has no
/// position gating. The one he holds in each is marked.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/match_traits.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';

Future<void> showTraitCatalogue(
  BuildContext context, {
  required String position,
  required bool hardMode,
  required CardInstance? card,
  required Map<String, dynamic> ratios,
  String? heldPlayer,
  String? heldMatch,
}) => showBottomSheetPopup<void>(
  context,
  child: TraitCatalogueSheet(
    position: position,
    hardMode: hardMode,
    card: card,
    ratios: ratios,
    heldPlayer: heldPlayer,
    heldMatch: heldMatch,
  ),
);

class TraitCatalogueSheet extends StatelessWidget {
  const TraitCatalogueSheet({
    super.key,
    required this.position,
    required this.hardMode,
    required this.card,
    required this.ratios,
    this.heldPlayer,
    this.heldMatch,
  });

  final String position;
  final bool hardMode;

  /// The card the sheet was opened from: a first-slot trait's worth is a
  /// figure on HIM, so the ladder is computed on his card.
  final CardInstance? card;
  final Map<String, dynamic> ratios;

  /// The ids he already carries, one per slot, or null.
  final String? heldPlayer;
  final String? heldMatch;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pool = getTraitPoolForPosition(position, hardMode: hardMode)
        .where((t) => t.id != 'none')
        .toList();
    return Column(
      key: const ValueKey('trait-catalogue'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: t('squad.traits.all.title')),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              _Heading(text: t('squad.trait.slot.player')),
              for (final trait in pool)
                _Row(
                  rowKey: ValueKey('trait-catalogue-${trait.id}'),
                  icon: trait.icon,
                  name: traitName(trait),
                  desc: traitDesc(trait),
                  chips: traitLadderOn(card, trait, ratios),
                  held: trait.id == heldPlayer,
                ),
              const SizedBox(height: 14),
              _Heading(text: t('squad.trait.slot.match')),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t('squad.traits.match_blurb'),
                  style: TextStyle(fontSize: 12, height: 1.4, color: kit.textMuted),
                ),
              ),
              for (final trait in matchTraitList)
                _Row(
                  rowKey: ValueKey('trait-catalogue-${trait.id}'),
                  icon: trait.icon,
                  name: matchTraitName(trait),
                  desc: matchTraitDesc(trait),
                  when: matchTraitWhen(trait),
                  chips: matchTraitLadder(trait),
                  held: trait.id == heldMatch,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: kit.accentBright,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rowKey,
    required this.icon,
    required this.name,
    required this.desc,
    required this.held,
    this.when,
    this.chips = const [],
  });

  final Key rowKey;
  final String icon;
  final String name;
  final String desc;

  /// When it fires, and what each level is worth — the two things a
  /// description of the trait's character does not say.
  final String? when;
  final List<String> chips;

  /// The one he has: lit the way the medal is.
  final bool held;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: rowKey,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: held ? kit.accent.withValues(alpha: 0.16) : kit.surface2,
        border: Border.all(color: held ? kit.accent : kit.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: held ? kit.accentBright : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, height: 1.35, color: kit.textMuted),
                ),
                if (when case final w?) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${t('matchtrait.when').toUpperCase()} · $w',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: kit.accentBright,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final chip in chips)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: kit.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              chip,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
