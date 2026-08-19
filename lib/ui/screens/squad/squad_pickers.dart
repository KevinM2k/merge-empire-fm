/// The formation and tactic pickers.
///
/// Both are bottom sheets — one of the three popup shapes — rather than a
/// fourth thing, and both write through `game.update` so the change is saved
/// and the header's ratings recompute off it.
///
/// Names come from the DATA (`Formation.label`, `Strategy.name`) rather than
/// the catalogue, because that is where the source keeps them: there are no
/// `tactic.*` or `formation.*` keys in any of the ten catalogues, so these read
/// English in the JS too. Translating them is a catalogue change, not a port
/// decision, and inventing keys here would put ten untranslated strings in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Change the shape, carrying the eleven across.
///
/// `migrateLineup` is what keeps a switch from wiping the side: it maps the
/// players onto the new slots by position rather than starting again.
void setFormation(WidgetRef ref, String formationId) {
  ref.read(gameProvider).update((s) {
    final squad = s['squad'];
    if (squad is! Map<String, dynamic>) return;
    final migrated = migrateLineup(lineupFor(s), formationId);
    squad['formation'] = formationId;
    squad['lineup'] = [
      for (final slot in migrated)
        <String, dynamic>{
          'slotId': slot.slotId,
          'slotPosition': slot.slotPosition,
          'cardInstanceId': slot.cardInstanceId,
        },
    ];
  });
}

void setStrategy(WidgetRef ref, String strategyId) {
  ref.read(gameProvider).update((s) {
    final squad = s['squad'];
    if (squad is Map<String, dynamic>) squad['strategyId'] = strategyId;
  });
}

final strategyIdProvider = savePick<String>((s) {
  final squad = s['squad'];
  final id = squad is Map<String, dynamic> ? squad['strategyId'] : null;
  return id is String && strategies.containsKey(id) ? id : defaultStrategy;
});

Future<void> showFormationPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(formationIdProvider);
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.55,
    child: ListView(
      key: const ValueKey('formation-picker'),
      children: [
        for (final formation in formations.values)
          _PickerRow(
            rowKey: 'formation-${formation.id}',
            title: formation.label,
            subtitle: formation.style,
            selected: formation.id == current,
            onTap: () {
              setFormation(ref, formation.id);
              Navigator.of(context).pop();
            },
          ),
      ],
    ),
  );
}

Future<void> showTacticPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(strategyIdProvider);
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.6,
    child: ListView(
      key: const ValueKey('tactic-picker'),
      children: [
        for (final strategy in strategies.values)
          _PickerRow(
            rowKey: 'tactic-${strategy.id}',
            title: '${strategy.icon}  ${strategy.name}',
            // The hint is the whole reason a tactic is a choice rather than a
            // setting — it says what the trade is.
            subtitle: strategy.hint,
            selected: strategy.id == current,
            onTap: () {
              setStrategy(ref, strategy.id);
              Navigator.of(context).pop();
            },
          ),
      ],
    ),
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.rowKey,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String rowKey;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ListTile(
      key: ValueKey(rowKey),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: kit.textMuted)),
      trailing: selected ? Icon(Icons.check, color: kit.accent) : null,
      onTap: onTap,
    );
  }
}

/// Pick somebody off the bench for one slot.
///
/// The other half of the detail sheet's Swap. Whoever is chosen drops into the
/// slot and the incumbent goes to the bench — a straight exchange rather than a
/// bump, because the player asked for one change and quietly benching a second
/// man is a change they did not ask for.
Future<void> showSlotPicker(
  BuildContext context,
  WidgetRef ref, {
  required String slotId,
}) {
  final bench = ref.read(benchProvider);
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.6,
    child: bench.isEmpty
        ? Center(
            key: const ValueKey('slot-picker-empty'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('squad.bench.empty')),
            ),
          )
        : ListView(
            key: const ValueKey('slot-picker'),
            children: [
              for (final entry in bench)
                _PickerRow(
                  rowKey: 'slot-pick-${entry.instanceId}',
                  title: entry.card.name,
                  subtitle: '${entry.card.position} · ${entry.card.rating}',
                  selected: false,
                  onTap: () {
                    swapIntoSlot(
                      ref,
                      slotId: slotId,
                      instanceId: entry.instanceId,
                    );
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
  );
}

/// Put [instanceId] in [slotId], sending whoever was there to the bench.
void swapIntoSlot(
  WidgetRef ref, {
  required String slotId,
  required String instanceId,
}) {
  ref.read(gameProvider).update((s) {
    final squad = s['squad'];
    if (squad is! Map<String, dynamic>) return;
    final lineup = squad['lineup'];
    if (lineup is! List) return;

    // If the incoming player is already in the eleven this is a swap between
    // two slots, so the outgoing one takes their old place rather than being
    // dropped — otherwise the side finishes a man short.
    String? previousSlotOfIncoming;
    String? outgoing;
    for (final row in lineup) {
      if (row is! Map<String, dynamic>) continue;
      if (row['cardInstanceId'] == instanceId) {
        previousSlotOfIncoming = row['slotId'] as String?;
      }
      if (row['slotId'] == slotId) outgoing = row['cardInstanceId'] as String?;
    }

    for (final row in lineup) {
      if (row is! Map<String, dynamic>) continue;
      if (row['slotId'] == slotId) row['cardInstanceId'] = instanceId;
      if (previousSlotOfIncoming != null &&
          row['slotId'] == previousSlotOfIncoming) {
        row['cardInstanceId'] = outgoing;
      }
    }
  });
}

/// Fill the eleven for them.
///
/// TWO DIFFERENT JOBS behind one button, and which one it does depends on the
/// mode:
///
/// - **Casual** picks the shape that wins the NEXT FIXTURE, not the one that
///   fields the highest total rating. Those are different questions and the sim
///   only asks the first.
/// - **Pro** rotates personnel to the freshest fit WITHIN the manager's chosen
///   formation, and never switches tactics under them — a shape the manager
///   picked is a decision, not a suggestion.
void autoFillLineup(WidgetRef ref) {
  ref.read(gameProvider).update((s) {
    final squad = s['squad'];
    if (squad is! Map<String, dynamic>) return;
    final cards = [for (final raw in gridCells(s)) CardInstance.from(raw)];

    if (isProMode(s)) {
      squad['lineup'] = encodeLineup(
        buildDefaultLineup(
          squad['formation'] as String? ?? defaultFormation,
          cards,
          fatigue: true,
        ),
      );
      return;
    }

    final pick = bestFormationForFixture(s);
    squad['formation'] = pick.formationId;
    squad['lineup'] = encodeLineup(pick.lineup);
  });
}

/// Empty every slot.
///
/// The lineup is REBUILT on the way out by `cleanAndFillLineup`, so a cleared
/// eleven does not stay cleared — which is the point: this is "start again from
/// the best available", not "field nobody".
void clearLineup(WidgetRef ref) {
  ref.read(gameProvider).update((s) {
    final squad = s['squad'];
    if (squad is! Map<String, dynamic>) return;
    final lineup = squad['lineup'];
    if (lineup is! List) return;
    for (final row in lineup) {
      if (row is Map<String, dynamic>) row['cardInstanceId'] = null;
    }
  });
}
