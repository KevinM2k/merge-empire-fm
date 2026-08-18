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
