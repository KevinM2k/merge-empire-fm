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
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pitch.dart';
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
    return Stack(
      key: const ValueKey('squad-screen'),
      children: [
        Column(
          children: [
            const SquadHeader(),
            // The pitch takes everything that is left. It used to give a
            // hundred and thirty pixels to a bench strip that was showing three
            // cards at a time.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: _Pitch(onAssign: _assign),
              ),
            ),
          ],
        ),
        // Subs sits over the pitch, bottom RIGHT — bottom left is the coach's,
        // everywhere he appears.
        const Positioned(right: 16, bottom: 16, child: _SubsButton()),
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
    final tactic =
        strategies[ref.watch(strategyIdProvider)] ??
        strategies[defaultStrategy]!;

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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('squad-formation'),
                  onPressed: () => showFormationPicker(context, ref),
                  child: Text(formation.label),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('squad-tactic'),
                  onPressed: () => showTacticPicker(context, ref),
                  child: Text(
                    '${tactic.icon}  ${tactic.shortName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('squad-auto'),
                  onPressed: () => autoFillLineup(ref),
                  icon: const Icon(Icons.autorenew, size: 16),
                  // The LABEL changes with the mode, because the two do
                  // genuinely different things: casual repicks the shape,
                  // Pro only rotates the legs.
                  label: Text(
                    t(
                      ref.watch(proModeProvider)
                          ? 'squad.formation.autoRotate'
                          : 'squad.formation.auto',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('squad-clear'),
                  onPressed: () => clearLineup(ref),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(t('squad.formation.clear')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Open a player, and act on whatever they asked for on the way out.
///
/// The sheet does not touch the LINEUP itself — bench and swap are changes to
/// the eleven, and the eleven is this screen's business. It reports what was
/// asked and the screen does it.
Future<void> _openDetail(
  BuildContext context,
  WidgetRef ref, {
  required String instanceId,
  String? slotId,
}) async {
  final action = await showPlayerDetail(
    context,
    ref,
    instanceId: instanceId,
    slotId: slotId,
  );
  if (action == null || slotId == null) return;

  switch (action) {
    case PlayerDetailAction.bench:
      // Vacating a slot is enough — `cleanAndFillLineup` refills it from the
      // bench on the way out, which is what stops an empty slot surviving.
      ref.read(gameProvider).update((s) {
        final squad = s['squad'];
        if (squad is! Map<String, dynamic>) return;
        final lineup = squad['lineup'];
        if (lineup is! List) return;
        for (final row in lineup) {
          if (row is Map<String, dynamic> && row['slotId'] == slotId) {
            row['cardInstanceId'] = null;
          }
        }
      });
    case PlayerDetailAction.swap:
      if (context.mounted) await showSlotPicker(context, ref, slotId: slotId);
  }
}

class _Pitch extends ConsumerWidget {
  const _Pitch({required this.onAssign});

  final void Function(WidgetRef ref, SquadDrag drag, String slotId) onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(pitchSlotsProvider);

    return SquadPitch(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const cardW = 62.0;
          const cardH = 80.0;
          return Stack(
            key: const ValueKey('squad-pitch'),
            children: [
              for (final slot in slots)
                Positioned(
                  left: (slot.x / 100) * (constraints.maxWidth - cardW),
                  top: (slot.y / 100) * (constraints.maxHeight - cardH),
                  width: cardW,
                  height: cardH,
                  child: _SlotTarget(slot: slot, onAssign: onAssign),
                ),
            ],
          );
        },
      ),
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
          child: GestureDetector(
            // A tap opens the player. Long-press still drags — the two do not
            // fight, because the drag has a 200ms hold before it starts.
            onTap: () => _openDetail(
              context,
              ref,
              instanceId: slot.cardInstanceId!,
              slotId: slot.slotId,
            ),
            // Named, not punished, here: the rating penalty is the engine's,
            // and the screen's job is to say why a number looks low.
            child: slot.outOfPosition
                ? Tooltip(message: t('squad.out_of_position'), child: tile)
                : tile,
          ),
        );
      },
    );
  }
}

/// Subs — the way to the bench.
///
/// The bench was an inline strip under the pitch showing three cards at a time
/// and eating a hundred and thirty pixels of a portrait screen. It is a SHEET
/// in the JS for that reason, opened from a button, and the pitch gets the room
/// back.
///
/// The count rides on the button: the bench is now out of sight, and a door
/// with nothing behind it should say so before it is opened.
class _SubsButton extends ConsumerWidget {
  const _SubsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(benchProvider).length;
    return FloatingActionButton.extended(
      key: const ValueKey('squad-subs'),
      heroTag: 'squad-subs',
      onPressed: () => showBenchSheet(context, ref),
      icon: const Icon(Icons.groups, size: 18),
      label: Text(t('squad.bench.count', {'n': count})),
    );
  }
}

/// The bench, as real cards.
///
/// Tapping one opens the player, the same sheet the pitch opens — which is
/// where Send On lives, so a benched player can be brought into the side
/// without a drag.
Future<void> showBenchSheet(BuildContext context, WidgetRef ref) {
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.72,
    child: Consumer(
      builder: (sheetContext, sheetRef, _) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        final bench = sheetRef.watch(benchProvider);
        if (bench.isEmpty) {
          return Center(
            key: const ValueKey('squad-bench-empty'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                t('squad.bench.empty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: kit.textMuted),
              ),
            ),
          );
        }
        return GridView.builder(
          key: const ValueKey('squad-bench'),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 92,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemCount: bench.length,
          itemBuilder: (context, i) {
            final entry = bench[i];
            return GestureDetector(
              onTap: () => _openDetail(
                sheetContext,
                sheetRef,
                instanceId: entry.instanceId,
                slotId: null,
              ),
              child: PlayerCard(
                key: ValueKey('squad-bench-${entry.instanceId}'),
                view: entry.card,
                light: Theme.of(context).brightness == Brightness.light,
              ),
            );
          },
        );
      },
    ),
  );
}
