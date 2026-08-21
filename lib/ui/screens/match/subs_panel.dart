/// Substitutions, mid-match.
///
/// **Nothing in the port could make one**, and the tells were the usual ones:
/// twenty `match.subs.*` strings translated in ten catalogues with nothing able
/// to reach one; `subsUsed` and `subbedOnIds` written into every result at
/// kickoff and never moved off zero; and `match_use_subs` and `match_sub_scores`
/// — two quests that could not advance.
///
/// **A substitution does NOT re-decide the match**, and that is the source's own
/// rule rather than a limitation here: the ninety minutes were settled at
/// kickoff and a change of personnel is a change the manager made, counted as
/// such. Only a change of TACTIC re-rolls the remainder. What a sub does is swap
/// the lineup in the save, and the match screen puts the kickoff eleven back at
/// full time so a substitution cannot quietly become next week's team.
///
/// The panel is two lists and one rule: tap somebody in the eleven to take him
/// off, then tap somebody on the bench to bring him on. An EMPTY slot needs no
/// first tap — there is nobody to withdraw, which is the injury case.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// One change, as the match screen needs to hear about it.
typedef SubMade = ({String? offId, String onId, String slotId});

/// Open the panel. Resolves when the manager is done with it.
Future<void> showSubsPanel(
  BuildContext context, {
  required int used,
  required void Function(SubMade) onSub,
  String? openOn,
}) => showBottomSheetPopup<void>(
  context,
  heightFraction: 0.9,
  child: SubsPanel(used: used, onSub: onSub, openOn: openOn),
);

class SubsPanel extends ConsumerStatefulWidget {
  const SubsPanel({
    super.key,
    required this.used,
    required this.onSub,
    this.openOn,
  });

  /// How many changes have already been made this match.
  final int used;

  final void Function(SubMade) onSub;

  /// A slot to arrive with already picked.
  ///
  /// The injury case: somebody has gone down, the sim has already vacated their
  /// slot, and asking the manager to tap the hole before they can tap a
  /// replacement is asking them to answer a question they were just told the
  /// answer to.
  final String? openOn;

  @override
  ConsumerState<SubsPanel> createState() => SubsPanelState();
}

class SubsPanelState extends ConsumerState<SubsPanel> {
  /// Who is coming off, and out of which slot. Null until one is picked — and
  /// an empty slot sets it with a null [SubMade.offId], because there is
  /// nobody to withdraw.
  ({String? offId, String slotId})? _off;

  /// Changes made since the panel opened, on top of [SubsPanel.used].
  int _made = 0;

  /// Nobody comes off twice, and nobody who has been off comes back on.
  final Set<String> _spent = <String>{};

  @override
  void initState() {
    super.initState();
    final open = widget.openOn;
    // No `offId`: the slot is empty, so there is nobody to withdraw. That is
    // exactly what makes the second tap the only one needed.
    if (open != null) _off = (offId: null, slotId: open);
  }

  /// Test seams.
  int get left => PlayerEnergy.maxSubs - widget.used - _made;
  String? get selectedSlot => _off?.slotId;

  void _pickOff(String slotId, String? cardId) {
    if (left <= 0) return;
    setState(() {
      _off = (_off?.slotId == slotId) ? null : (offId: cardId, slotId: slotId);
    });
  }

  void _bringOn(String onId) {
    final off = _off;
    if (off == null || left <= 0) return;
    // The write path enforces availability too, not just the list: a panel
    // rendered before a deal went through must never put a player who is at
    // another club onto the pitch.
    final card = _cardById(ref.read(gameProvider).state, onId);
    if (card == null || !card.isSelectable) return;

    ref.read(gameProvider).update((s) {
      final squad = s['squad'];
      if (squad is! Map<String, dynamic>) return;
      final lineup = squad['lineup'];
      if (lineup is! List) return;
      for (final row in lineup) {
        if (row is Map<String, dynamic> && row['slotId'] == off.slotId) {
          row['cardInstanceId'] = onId;
        }
      }
    });
    setState(() {
      _made++;
      if (off.offId != null) _spent.add(off.offId!);
      _off = null;
    });
    widget.onSub((offId: off.offId, onId: onId, slotId: off.slotId));
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final slots = ref.watch(pitchSlotsProvider);
    final bench = ref.watch(benchProvider);
    final state = ref.watch(gameProvider).state;
    final none = left <= 0;

    return Column(
      key: const ValueKey('subs-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: t('match.subs'),
          // The instruction changes with the step, because the two taps mean
          // different things and a panel that says "tap a player" for both is
          // a panel that explains nothing.
          subtitle: none
              ? t('match.subs.none_left')
              : _off == null
              ? t('match.subs.pick_off')
              : t('match.subs.pick_on'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              _GroupLabel(kit: kit, text: t('match.subs.on_pitch')),
              for (final slot in slots)
                _Row(
                  key: ValueKey('sub-slot-${slot.slotId}'),
                  kit: kit,
                  name: slot.card?.name ?? t('match.subs.empty_slot'),
                  detail: slot.slotPosition,
                  rating: slot.card == null ? null : slot.effRating,
                  selected: _off?.slotId == slot.slotId,
                  // Somebody already withdrawn cannot be withdrawn again, and
                  // an empty slot is always a candidate — that is the injury
                  // case, and it needs no first tap to make sense.
                  enabled:
                      !none &&
                      (slot.cardInstanceId == null ||
                          !_spent.contains(slot.cardInstanceId)),
                  badge: slot.card?.injured == true
                      ? t('match.subs.injured')
                      : null,
                  onTap: () => _pickOff(slot.slotId, slot.cardInstanceId),
                ),
              const SizedBox(height: 10),
              _GroupLabel(kit: kit, text: t('match.subs.bench')),
              if (bench.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    t('match.subs.empty_bench'),
                    style: TextStyle(color: kit.textMuted, fontSize: 12),
                  ),
                ),
              for (final entry in bench)
                _Row(
                  key: ValueKey('sub-bench-${entry.instanceId}'),
                  kit: kit,
                  name: entry.card.name,
                  detail: entry.card.position,
                  rating: entry.card.rating,
                  selected: false,
                  // Unavailable is not merely unwise: a player at another club
                  // or advertised for sale cannot take the field.
                  enabled:
                      !none &&
                      _off != null &&
                      !_spent.contains(entry.instanceId) &&
                      (_cardById(state, entry.instanceId)?.isSelectable ??
                          false),
                  badge: entry.card.injured ? t('match.subs.injured') : null,
                  onTap: () => _bringOn(entry.instanceId),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ElevatedButton(
            key: const ValueKey('subs-done'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(t('match.subs.done')),
          ),
        ),
      ],
    );
  }
}

CardInstance? _cardById(Map<String, dynamic>? state, String instanceId) {
  final cells = (state?['grid'] as Map<String, dynamic>?)?['cells'];
  if (cells is! List) return null;
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card != null && card.instanceId == instanceId) return card;
  }
  return null;
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.kit, required this.text});

  final KitTheme kit;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: kit.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.kit,
    required this.name,
    required this.detail,
    required this.rating,
    required this.selected,
    required this.enabled,
    required this.badge,
    required this.onTap,
  });

  final KitTheme kit;
  final String name, detail;
  final int? rating;
  final bool selected, enabled;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.45,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kit.accent.withValues(alpha: 0.22) : kit.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kit.accentBright : kit.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                detail,
                style: TextStyle(
                  color: kit.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  badge!,
                  style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                ),
              ),
            if (rating != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '$rating',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: kit.accentBright,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
