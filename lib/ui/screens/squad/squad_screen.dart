/// The Squad tab — the eleven on the pitch, and the bench under it.
///
/// A card is dragged from the bench onto a slot to pick it, or between slots to
/// swap. The lineup is written back through `game.update`, and every rating on
/// the header is recomputed by the engine rather than adjusted by hand.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

/// What a drag carries: a bench card, or the slot it came from.
typedef SquadDrag = ({String? instanceId, String? fromSlotId});

class SquadScreen extends ConsumerWidget {
  const SquadScreen({super.key});

  /// Put [instanceId] in [slotId], moving out whoever was there.
  ///
  /// A swap rather than a bump to the bench: the player asked for one change,
  /// and quietly benching a second man is a change they did not ask for.
  void _assign(WidgetRef ref, SquadDrag drag, String slotId) {
    final game = ref.read(gameProvider);
    game.update((s) {
      final lineup = lineupFor(s);
      final incoming = drag.instanceId;
      final displaced = lineup
          .firstWhere(
            (l) => l.slotId == slotId,
            orElse: () => const LineupSlot(
              slotId: '',
              slotPosition: 'MID',
              cardInstanceId: null,
            ),
          )
          .cardInstanceId;

      final next = [
        for (final slot in lineup)
          if (slot.slotId == slotId)
            slot.copyWith(cardInstanceId: incoming, clearCard: incoming == null)
          else if (drag.fromSlotId != null && slot.slotId == drag.fromSlotId)
            slot.copyWith(
              cardInstanceId: displaced,
              clearCard: displaced == null,
            )
          else
            slot,
      ];

      final squad = s['squad'];
      if (squad is Map<String, dynamic>) {
        squad['lineup'] = [
          for (final slot in next)
            <String, dynamic>{
              'slotId': slot.slotId,
              'slotPosition': slot.slotPosition,
              'cardInstanceId': slot.cardInstanceId,
            },
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      key: const ValueKey('squad-screen'),
      children: [
        const SquadHeader(),
        Expanded(child: _Pitch(onAssign: _assign)),
        const Divider(height: 1),
        SizedBox(height: 132, child: _Bench(onAssign: _assign)),
      ],
    );
  }
}

/// The headline numbers. The bar is a bar rather than five star pips because
/// pips banded 0-100 into five buckets, so 61 and 79 drew the same row and the
/// number beside them did all the work.
class SquadHeader extends ConsumerWidget {
  const SquadHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ratings = ref.watch(squadRatingsProvider);
    final formation = getFormation(ref.watch(formationIdProvider));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 64, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: const ValueKey('squad-rating-bar'),
                    value: ratings.overall.clamp(0, 100) / 100,
                    minHeight: 8,
                    backgroundColor: kit.surface2,
                    valueColor: AlwaysStoppedAnimation(
                      ratings.belowPar ? Colors.redAccent : kit.accentBright,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${ratings.overall}',
                key: const ValueKey('squad-rating'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ratings.belowPar ? Colors.redAccent : kit.accentBright,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ATK ${ratings.attack}',
                key: const ValueKey('squad-atk'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE87A3A),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'DEF ${ratings.defence}',
                key: const ValueKey('squad-def'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A9EDD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              formation.label,
              key: const ValueKey('squad-formation'),
              style: TextStyle(color: kit.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pitch extends ConsumerWidget {
  const _Pitch({required this.onAssign});

  final void Function(WidgetRef ref, SquadDrag drag, String slotId) onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(pitchSlotsProvider);
    final kit = Theme.of(context).extension<KitTheme>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        const cardW = 62.0;
        const cardH = 80.0;
        return Stack(
          key: const ValueKey('squad-pitch'),
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kit.surface.withValues(alpha: 0.4),
                  border: Border.all(color: kit.border),
                ),
              ),
            ),
            for (final slot in slots)
              Positioned(
                left:
                    (slot.x / 100) * (constraints.maxWidth - cardW),
                top: (slot.y / 100) * (constraints.maxHeight - cardH),
                width: cardW,
                height: cardH,
                child: _SlotTarget(slot: slot, onAssign: onAssign),
              ),
          ],
        );
      },
    );
  }
}

class _SlotTarget extends ConsumerWidget {
  const _SlotTarget({required this.slot, required this.onAssign});

  final PitchSlot slot;
  final void Function(WidgetRef ref, SquadDrag drag, String slotId) onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    return DragTarget<SquadDrag>(
      onWillAcceptWithDetails: (d) => d.data.fromSlotId != slot.slotId,
      onAcceptWithDetails: (d) => onAssign(ref, d.data, slot.slotId),
      builder: (context, candidate, _) {
        final card = slot.card;
        if (card == null) {
          return Container(
            key: ValueKey('squad-slot-${slot.slotId}'),
            decoration: BoxDecoration(
              border: Border.all(
                color: candidate.isEmpty ? kit.border : kit.accent,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            alignment: Alignment.center,
            child: Text(
              slot.slotPosition,
              style: TextStyle(color: kit.textMuted, fontSize: 11),
            ),
          );
        }
        final tile = PlayerCard(
          key: ValueKey('squad-slot-${slot.slotId}'),
          view: card,
          light: Theme.of(context).brightness == Brightness.light,
          selected: candidate.isNotEmpty || slot.outOfPosition,
        );
        return LongPressDraggable<SquadDrag>(
          data: (instanceId: slot.cardInstanceId, fromSlotId: slot.slotId),
          delay: const Duration(milliseconds: 200),
          feedback: const SizedBox(width: 62, height: 80),
          childWhenDragging: const SizedBox.shrink(),
          // Named, not punished, here: the rating penalty is the engine's, and
          // the screen's job is to say why a number looks low.
          child: slot.outOfPosition
              ? Tooltip(message: t('squad.out_of_position'), child: tile)
              : tile,
        );
      },
    );
  }
}

class _Bench extends ConsumerWidget {
  const _Bench({required this.onAssign});

  final void Function(WidgetRef ref, SquadDrag drag, String slotId) onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bench = ref.watch(benchProvider);
    final kit = Theme.of(context).extension<KitTheme>()!;

    if (bench.isEmpty) {
      return Center(
        child: Text(
          t('squad.no_players'),
          key: const ValueKey('squad-bench-empty'),
          style: TextStyle(color: kit.textMuted, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('squad-bench'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: bench.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, i) {
        final entry = bench[i];
        final tile = SizedBox(
          width: 74,
          child: PlayerCard(
            key: ValueKey('squad-bench-${entry.instanceId}'),
            view: entry.card,
            light: Theme.of(context).brightness == Brightness.light,
          ),
        );
        return LongPressDraggable<SquadDrag>(
          data: (instanceId: entry.instanceId, fromSlotId: null),
          delay: const Duration(milliseconds: 200),
          feedback: const SizedBox(width: 74, height: 100),
          childWhenDragging: const SizedBox(width: 74),
          child: tile,
        );
      },
    );
  }
}
