/// The Squad tab — the eleven on the pitch, and the bench under it.
///
/// A card is dragged from the bench onto a slot to pick it, or between slots to
/// swap. The lineup is written back through `game.update`, and every rating on
/// the header is recomputed by the engine rather than adjusted by hand.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show readableInk, vsRedOn;
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
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart'
    show BidTargetMark;
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
        ? dangerInk
        : ratings.aboveRange
        ? kit.accentBright
        : const Color(0xFFFF9800);

    return Container(
      decoration: BoxDecoration(
        // **THE PAGE SHOWS THROUGH IT.** This band was `kit.bg` — the page's
        // own ground as a SOLID — so on a pattern kit the strip carrying the
        // rating, the formation and the counter-attack toggle was a flat slab
        // with the turf running up to it and stopping. Reported directly: there
        // is no turf behind them. A wash of the same colour keeps the band
        // readable and lets the backdrop through, which is what every other
        // surface on this page already does.
        color: kit.bg.withValues(alpha: 0.62),
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
                // Their HUES are fixed rather than kit-derived: the same two
                // colours mean attack and defence on every screen in the game.
                // The LIGHTNESS is not: both were chosen against near-black and
                // came out at 2.9:1 on a white page. Same hue, taken down —
                // see [readableInk].
                Text(
                  'ATK ${ratings.attack}',
                  key: const ValueKey('squad-atk'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: readableInk(context, const Color(0xFFE87A3A)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'DEF ${ratings.defence}',
                  key: const ValueKey('squad-def'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: readableInk(context, const Color(0xFF4A9EDD)),
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
          // **Scaled down, never clipped.** "Formation" is a word, not a value,
          // and a word that ends in an ellipsis reads as a bug. Flexing the
          // label let it truncate; a fixed one overflowed the chip. Shrinking
          // the whole row a hair on a narrow phone — or in a language whose word
          // for it is longer — keeps every part of it readable.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  GameIcon(icon!, size: 16, color: iconColor),
                  const SizedBox(width: 6),
                ],
                if (label != null) ...[
                  Text(
                    '$label:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kit.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  value,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ink,
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
          // Theme-aware: `#F87171` is the DARK red, and on a light sheet it
          // is a pink nobody reads a destructive action off.
          ink: vsRedOn(context),
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
    this.ink,
  });

  final String pillKey;
  final VoidCallback onTap;
  final String icon;
  final String label;

  /// The label's colour, already resolved for the theme — [vsRedOn] rather than
  /// a constant. Null is the plain one.
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    // **THE PILL FOLLOWS THE THEME, and it did not.** It was black glass in
    // both, so Clear's destructive red — which IS theme-aware, and resolves to
    // a deep `#C62828` on a light page — came out dark red on near-black.
    // Reported as unreadable. The pill carries its own ground because it sits
    // over the pitch rather than on a surface, so the ground has to flip with
    // the ink rather than with what is behind it.
    final light = Theme.of(context).brightness == Brightness.light;
    final tint = ink ?? (light ? const Color(0xFF1A1F26) : Colors.white);
    return Material(
      color: light
          ? Colors.white.withValues(alpha: 0.82)
          : Colors.black.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tint.withValues(alpha: 0.45)),
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
              GameIcon(icon, size: 14, color: tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tint,
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
  Widget build(BuildContext context, WidgetRef ref) => PitchBoard(
    slots: ref.watch(pitchSlotsProvider),
    slotBuilder: (context, slot) =>
        _SlotTarget(slot: slot, onAssign: onAssign),
  );
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
        final token = BidTargetMark(
          instanceId: slot.cardInstanceId,
          child: PitchToken(
            key: ValueKey('squad-slot-${slot.slotId}'),
            slot: slot,
            proMode: pro,
            highlighted: candidate.isNotEmpty,
          ),
        );
        return LongPressDraggable<SquadDrag>(
          data: (instanceId: slot.cardInstanceId, fromSlotId: slot.slotId),
          delay: const Duration(milliseconds: 200),
          // The token itself, lifted. It had been an EMPTY box, so dragging a
          // man off the pitch showed nothing under the finger at all.
          //
          // **Inside a Material**, because the feedback is built into the drag
          // OVERLAY and nothing up there is one: every `Text` on the lifted token
          // — the name, the rating, the position — drew Flutter's
          // missing-Material double yellow underline for the length of the drag.
          // The grid's own feedback already had this; the pitch's did not.
          feedback: Material(
            type: MaterialType.transparency,
            child: Transform.scale(
              scale: 1.1,
              child: PitchToken(slot: slot, proMode: pro),
            ),
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
    child: const _BenchSheet(),
  );
}

/// **The bench filters by line, which the spec has and the port did not.**
/// `SquadScreen.js` builds one `_benchFilterDefs()` and hangs the bar on both
/// the bench sheet and the slot picker; the port ported it onto the picker
/// only, so the one sheet in the game that can run to twenty-odd cards was the
/// one with no way to narrow it. Same bar, so the two cannot disagree.
class _BenchSheet extends ConsumerStatefulWidget {
  const _BenchSheet();

  @override
  ConsumerState<_BenchSheet> createState() => _BenchSheetState();
}

class _BenchSheetState extends ConsumerState<_BenchSheet> {
  /// Opens on the whole bench. The picker defaults to a line because it is
  /// filling one slot; this sheet is the squad, and a manager who opened it to
  /// look at their squad should see it.
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final all = ref.watch(benchProvider);
    if (all.isEmpty) {
      // Not a `Center`: it fills, so an empty bench was 72% of the
      // screen holding one sentence.
      return Padding(
        key: const ValueKey('squad-bench-empty'),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Text(
          t('squad.bench.empty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: kit.textMuted),
        ),
      );
    }
    final bench = [
      for (final entry in all)
        if (_filter == 'ALL' || entry.card.position == _filter) entry,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PositionFilterBar(
          keyPrefix: 'bench-filter',
          value: _filter,
          onChanged: (line) => setState(() => _filter = line),
        ),
        if (bench.isEmpty)
          // A line nobody plays. The bench itself is not empty, so it does not
          // get the sentence about dragging players onto it.
          Padding(
            key: const ValueKey('squad-bench-filtered-empty'),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Text(
              t('squad.picker.empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted),
            ),
          )
        else
          Flexible(
            child: GridView.builder(
              key: const ValueKey('squad-bench'),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              // Three across on a phone, wider on a tablet — the same count the
              // match's bench uses, because it is the same bench and two
              // different answers would read as a bug.
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: benchColumns(MediaQuery.sizeOf(context).width),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
              ),
              itemCount: bench.length,
              itemBuilder: (context, i) {
                final entry = bench[i];
                return GestureDetector(
                  onTap: () => _openDetail(
                    context,
                    ref,
                    instanceId: entry.instanceId,
                    slotId: null,
                  ),
                  child: BidTargetMark(
                    instanceId: entry.instanceId,
                    child: PlayerCard(
                      key: ValueKey('squad-bench-${entry.instanceId}'),
                      view: entry.card,
                      light: Theme.of(context).brightness == Brightness.light,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
