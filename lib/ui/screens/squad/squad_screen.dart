/// The Squad tab — the eleven on the pitch, and the bench under it.
///
/// A card is dragged from the bench onto a slot to pick it, or between slots to
/// swap. The lineup is written back through `game.update`, and every rating on
/// the header is recomputed by the engine rather than adjusted by hand.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart';
import 'package:merge_empire_fc/ui/screens/squad/pitch_token.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pitch.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
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
              child: Stack(
                children: [
                  // The pitch takes the WHOLE space. Clear and Auto float over
                  // its top corners rather than reserving a band above it: they
                  // are two pills that cover a corner of empty grass, and the
                  // 52px of clearance they were given came off the one band the
                  // eleven have to stand in.
                  Positioned.fill(child: _Pitch(onAssign: _assign)),
                  const Positioned(
                    left: 12,
                    right: 12,
                    top: 10,
                    child: PitchCornerActions(),
                  ),
                ],
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

/// The headline numbers, and the two chips that change them.
///
/// **Clear and Auto are NOT part of this.** They live over the pitch's top
/// corners as translucent pills — see [PitchCornerActions]. As a third row of
/// buttons here they took forty more pixels off a pitch that has to hold eleven
/// men, which is most of why the eleven had nowhere to stand.
///
/// The bar is a bar rather than five star pips because pips banded a 0-100
/// figure into five buckets, so 61 and 79 drew the same row and the number
/// beside them did all the work.
class SquadHeader extends ConsumerWidget {
  const SquadHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ratings = ref.watch(squadRatingsProvider);
    final formationId = ref.watch(formationIdProvider);
    final tacticId = ref.watch(strategyIdProvider);

    // THREE bands, not two. Below the division's range is "this is why you keep
    // losing"; above it is "you are ready to go up"; inside it is neither, and
    // painting that green told a mid-table side it was fine.
    final band = ratings.belowPar
        ? const Color(0xFFF44336)
        : ratings.aboveRange
        ? kit.accentBright
        : const Color(0xFFFF9800);

    return Container(
      decoration: BoxDecoration(
        color: kit.bg,
        border: Border(bottom: BorderSide(color: kit.border)),
      ),
      padding: EdgeInsets.fromLTRB(14, hudClearanceOf(context), 14, 11),
      child: Column(
        children: [
          // One glass panel, matching the next-match card's.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: kit.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: const ValueKey('squad-rating-bar'),
                      value: ratings.overall.clamp(3, 100) / 100,
                      minHeight: 8,
                      backgroundColor: kit.surface2,
                      valueColor: AlwaysStoppedAnimation(band),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${ratings.overall}',
                  key: const ValueKey('squad-rating'),
                  style: TextStyle(
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: band,
                  ),
                ),
                const SizedBox(width: 10),
                // ATK and DEF carry the TACTIC — see `squadTacticMultipliers`.
                // Their hues are fixed rather than kit-derived: the same two
                // colours mean attack and defence on every screen in the game.
                Text(
                  'ATK ${ratings.attack}',
                  key: const ValueKey('squad-atk'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE87A3A),
                  ),
                ),
                const SizedBox(width: 8),
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Chip(
                  chipKey: 'squad-formation',
                  onTap: () => showFormationPicker(context, ref),
                  fill: Colors.white.withValues(alpha: 0.04),
                  edge: kit.border,
                  label: t('squad.formation.label'),
                  value: formationId,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // The chip wears the CURRENT tactic's colour — icon, hairline
                // and wash — so the header says which tactic is set without
                // being read.
                child: _Chip(
                  chipKey: 'squad-tactic',
                  onTap: () => showTacticPicker(context, ref),
                  fill: tacticTint(context, tacticId, 10),
                  edge: tacticTint(context, tacticId, 55),
                  icon: tacticIconName(tacticId),
                  iconColor: tacticColor(context, tacticId),
                  value: t('strategy.$tacticId.name'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One header chip: an optional label, the value in bold, and a caret.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.chipKey,
    required this.onTap,
    required this.fill,
    required this.edge,
    required this.value,
    this.label,
    this.icon,
    this.iconColor,
  });

  final String chipKey;
  final VoidCallback onTap;
  final Color fill;
  final Color edge;
  final String value;
  final String? label;
  final String? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: edge),
      ),
      child: InkWell(
        key: ValueKey(chipKey),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                GameIcon(icon!, size: 16, color: iconColor),
                const SizedBox(width: 6),
              ],
              if (label != null) ...[
                // Flexible, and the SMALLER share: the label is the part a
                // player already knows, so in a language whose word for it is
                // long — or on a narrow phone — it gives way before the value
                // does. Fixed, it simply overflowed the chip.
                Flexible(
                  flex: 2,
                  child: Text(
                    '$label:',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kit.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                flex: 3,
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Opacity(
                opacity: 0.7,
                child: Icon(Icons.expand_more, size: 13, color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clear and Auto, over the pitch's top corners.
///
/// Translucent dark pills rather than buttons in the header: they belong to the
/// pitch they act on, and the header has no room for a third row without taking
/// it from the eleven.
class PitchCornerActions extends ConsumerWidget {
  const PitchCornerActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CornerPill(
          pillKey: 'squad-clear',
          onTap: () => clearLineup(ref),
          icon: 'cross',
          label: t('squad.formation.clear'),
          ink: const Color(0xFFF87171),
          edge: const Color(0x80F87171),
        ),
        _CornerPill(
          pillKey: 'squad-auto',
          onTap: () => autoFillLineup(ref),
          icon: 'refresh',
          // The LABEL changes with the mode, because the two do genuinely
          // different things: casual repicks the shape, Pro only rotates legs.
          label: t(
            ref.watch(proModeProvider)
                ? 'squad.formation.autoRotate'
                : 'squad.formation.auto',
          ),
          ink: Colors.white,
          edge: const Color(0x47FFFFFF),
        ),
      ],
    );
  }
}

class _CornerPill extends StatelessWidget {
  const _CornerPill({
    required this.pillKey,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.ink,
    required this.edge,
  });

  final String pillKey;
  final VoidCallback onTap;
  final String icon;
  final String label;
  final Color ink;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: edge),
      ),
      child: InkWell(
        key: ValueKey(pillKey),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 14, color: ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
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
  if (action == null) return;
  // A beat for the sheet's own dismiss to start before the next one opens, or
  // the two animations fight and the second sheet arrives half-built. The JS
  // waits the same 60ms for the same reason.
  await Future<void>.delayed(const Duration(milliseconds: 60));
  if (!context.mounted) return;

  switch (action) {
    case PlayerDetailAction.bench:
      if (slotId == null) return;
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
      if (slotId == null) return;
      await showSlotPicker(context, ref, slotId: slotId);
    case PlayerDetailAction.sendOn:
      // From the bench, where there is no slot to name — the engine picks the
      // one that suits him.
      sendOnFromBench(ref, instanceId: instanceId);
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
          // **The eleven scale with the pitch.** The lines are 24% of the
          // pitch's height apart — the JS's own figures, and every formation is
          // laid out on them — so what decides whether a line has room around it
          // is how much of that 24% the token eats. The token was a fixed 74×97
          // whatever the pitch: forty pixels of grass between the bands on a tall
          // phone and eleven on a short one, with the keeper standing ON the goal
          // line. Scaled instead, and never scaled UP, so a big screen still
          // draws the token at the size it was designed at.
          //
          // Not an inset: giving the outer lines a margin by squeezing the
          // formation into a shorter field would take the room out of exactly
          // the place it is missing from — between the midfield and the attack.
          final scale = math.min(
            1.0,
            constraints.maxHeight / pitchTokenReferenceHeight,
          );
          return Stack(
            key: const ValueKey('squad-pitch'),
            clipBehavior: Clip.none,
            children: [
              for (final slot in slots)
                Positioned(
                  // CENTRED on the formation's own percentage, which is what
                  // `left:x%; top:y%; transform:translate(-50%,-50%)` means. It
                  // had been mapping 0-100% onto `0..(width - cardWidth)`, which
                  // pulls every slot toward the top-left and squeezes the gaps
                  // between them until eleven tokens sit on top of each other.
                  left: (slot.x / 100) * constraints.maxWidth,
                  top: (slot.y / 100) * constraints.maxHeight,
                  // The token sizes itself, so the half-shift has to come off its
                  // own measured box rather than a hard-coded height. The scale
                  // goes INSIDE it, about the token's own centre, so the slot
                  // stays exactly where the formation put it.
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Transform.scale(
                      scale: scale,
                      child: _SlotTarget(slot: slot, onAssign: onAssign),
                    ),
                  ),
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
    final pro = ref.watch(proModeProvider);

    return DragTarget<SquadDrag>(
      key: ValueKey('squad-drop-${slot.slotId}'),
      onWillAcceptWithDetails: (d) => d.data.fromSlotId != slot.slotId,
      onAcceptWithDetails: (d) => onAssign(ref, d.data, slot.slotId),
      builder: (context, candidate, _) {
        final card = slot.card;
        if (card == null) {
          // An empty slot is TAPPABLE: it opens the pick-for-this-slot sheet,
          // which is the JS's `data-occ="0"` handler and the only way to fill a
          // side without dragging.
          return GestureDetector(
            key: ValueKey('squad-slot-${slot.slotId}'),
            onTap: () => showSlotPicker(context, ref, slotId: slot.slotId),
            child: PitchEmptySlot(position: slot.slotPosition),
          );
        }
        final token = PitchToken(
          key: ValueKey('squad-slot-${slot.slotId}'),
          slot: slot,
          proMode: pro,
          highlighted: candidate.isNotEmpty,
        );
        return LongPressDraggable<SquadDrag>(
          data: (instanceId: slot.cardInstanceId, fromSlotId: slot.slotId),
          delay: const Duration(milliseconds: 200),
          // The token itself, lifted. It had been an EMPTY box, so dragging a
          // man off the pitch showed nothing under the finger at all.
          feedback: Transform.scale(
            scale: 1.1,
            child: PitchToken(slot: slot, proMode: pro),
          ),
          childWhenDragging: PitchEmptySlot(position: slot.slotPosition),
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
                ? Tooltip(message: t('squad.out_of_position'), child: token)
                : token,
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
    // The SAME PILL as Clear and Auto. It was an extended FAB, which is a
    // different height, a different radius, a different weight of type and an
    // elevation none of the other three controls on this pitch have — so the
    // one thing on the screen that opens a whole squad looked like it belonged
    // to a different app.
    return _CornerPill(
      pillKey: 'squad-subs',
      onTap: () => showBenchSheet(context, ref),
      icon: 'squad',
      label: t('squad.bench.count', {'n': count}),
      ink: Colors.white,
      edge: const Color(0x47FFFFFF),
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
