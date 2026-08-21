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
/// **IT IS THE SAME PITCH AS THE SQUAD TAB.** It was two scrolling lists, which
/// asks the manager to hold the shape in their head and rebuild it from position
/// labels — while the shape is the whole information, and they have already
/// learnt where everybody is from the Squad tab. So: the eleven in position on
/// [PitchBoard], a tap opens the bench from the bottom the way the Squad tab
/// does, and a tap there asks before it does anything. A hurt player wears a
/// cross and reads zero, because zero is what the sim scores him.
///
/// One rule survives from the lists and it is the important one: an EMPTY slot
/// needs no first tap. There is nobody to withdraw, which is the injury case.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/pitch_token.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pitch.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

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
  heightFraction: 0.92,
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

  /// A slot to arrive with the bench already open on.
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
  /// Changes made since the panel opened, on top of [SubsPanel.used].
  int _made = 0;

  /// Nobody comes off twice, and nobody who has been off comes back on.
  final Set<String> _spent = <String>{};

  /// The slot whose bench is open, or was opened for it.
  String? _openFor;

  @override
  void initState() {
    super.initState();
    final open = widget.openOn;
    if (open == null) return;
    _openFor = open;
    // Straight to the bench, because the manager has just been TOLD there is a
    // hole. Deferred a frame: there is no route to push a sheet onto until this
    // one is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openBench(open, null);
    });
  }

  /// Test seams.
  int get left => PlayerEnergy.maxSubs - widget.used - _made;
  String? get selectedSlot => _openFor;

  /// Tapping somebody on the pitch: he is the one coming off, and the bench
  /// opens to answer with.
  void _pick(PitchSlot slot) {
    if (left <= 0) return;
    final on = slot.cardInstanceId;
    // Somebody already withdrawn cannot be withdrawn again. An empty slot is
    // always a candidate — that is the injury case.
    if (on != null && _spent.contains(on)) return;
    setState(() => _openFor = slot.slotId);
    _openBench(slot.slotId, on);
  }

  /// The bench, from the bottom, the way the Squad tab opens it. A null
  /// [slotId] is a look rather than a choice — see [_BenchSheet.slotId].
  Future<void> _openBench(String? slotId, String? offId) async {
    await showBottomSheetPopup<void>(
      context,
      heightFraction: 0.66,
      child: _BenchSheet(
        slotId: slotId,
        offId: offId,
        spent: _spent,
        onChosen: (onId) => slotId == null
            ? Future.value(false)
            : _confirmAndApply(slotId, offId, onId),
      ),
    );
    if (mounted) setState(() => _openFor = null);
  }

  /// Ask, then do it.
  ///
  /// Returns whether the change went through, so the bench sheet knows whether
  /// to close: a manager who says no is still choosing, and taking the bench
  /// away from them would make trying somebody else cost a whole extra journey.
  Future<bool> _confirmAndApply(
    String slotId,
    String? offId,
    String onId,
  ) async {
    if (left <= 0) return false;
    // The write path enforces availability too, not just the list: a panel
    // rendered before a deal went through must never put a player who is at
    // another club onto the pitch.
    final state = ref.read(gameProvider).state;
    final coming = _cardById(state, onId);
    if (coming == null || !coming.isSelectable) return false;
    final going = offId == null ? null : _cardById(state, offId);

    // **The shipped line, not a new one.** `match.subs.feed` already says
    // "{off} off, {on} on." in ten languages and `match.subs.feed_on` covers
    // the hole — the buttons carry the question, which is what Confirm and
    // Cancel are for.
    final ok = await showCoachCard<bool>(
      context,
      titleKey: 'match.subs',
      bodyKey: going == null ? 'match.subs.feed_on' : 'match.subs.feed',
      bodyParams: {
        if (going != null) 'off': going.name(),
        'on': coming.name(),
      },
      actions: [
        CoachAction(
          labelKey: 'common.confirm',
          tone: CoachTone.confirm,
          onTap: () {},
          result: true,
        ),
        CoachAction(
          labelKey: 'common.cancel',
          tone: CoachTone.decline,
          onTap: () {},
          result: false,
        ),
      ],
    );
    if (ok != true || !mounted) return false;

    ref.read(gameProvider).update((s) {
      final squad = s['squad'];
      if (squad is! Map<String, dynamic>) return;
      final lineup = squad['lineup'];
      if (lineup is! List) return;
      for (final row in lineup) {
        if (row is Map<String, dynamic> && row['slotId'] == slotId) {
          row['cardInstanceId'] = onId;
        }
      }
    });
    setState(() {
      _made++;
      if (offId != null) _spent.add(offId);
    });
    widget.onSub((offId: offId, onId: onId, slotId: slotId));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(pitchSlotsProvider);
    final none = left <= 0;

    return Column(
      key: const ValueKey('subs-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: t('match.subs'),
          subtitle: none ? t('match.subs.none_left') : t('match.subs.pick_off'),
        ),
        Expanded(
          child: PitchBoard(
            slots: slots,
            slotBuilder: (context, slot) => _SubSlot(
              slot: slot,
              enabled:
                  !none &&
                  (slot.cardInstanceId == null ||
                      !_spent.contains(slot.cardInstanceId)),
              onTap: () => _pick(slot),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              // **The bench, before nominating anybody.** Who is available is
              // half of deciding who to take off, and needing to pick a man
              // first to find out made that a chicken and an egg.
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('subs-view-bench'),
                  onPressed: () => _openBench(null, null),
                  child: Text(t('match.subs.bench')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('subs-done'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(t('match.subs.done')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One place on the pitch, as this panel needs it: tappable, and dimmed once the
/// man in it has already been withdrawn.
class _SubSlot extends ConsumerWidget {
  const _SubSlot({
    required this.slot,
    required this.enabled,
    required this.onTap,
  });

  final PitchSlot slot;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = slot.card;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        key: ValueKey('sub-slot-${slot.slotId}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        // An empty slot is the injury hole, and it says so rather than reading
        // as a formation with a gap in it.
        child: card == null
            ? Tooltip(
                message: t('match.subs.injury_hole'),
                child: PitchEmptySlot(position: slot.slotPosition),
              )
            : PitchToken(slot: slot, proMode: ref.watch(proModeProvider)),
      ),
    );
  }
}

/// The bench, as real cards — the Squad tab's own sheet, with a different answer
/// to a tap.
class _BenchSheet extends ConsumerWidget {
  const _BenchSheet({
    required this.slotId,
    required this.offId,
    required this.spent,
    required this.onChosen,
  });

  /// The slot being filled, or null when the manager is only LOOKING.
  ///
  /// Seeing who is on the bench is half of deciding who to take off, and the
  /// panel used to make that a chicken and an egg: you had to nominate somebody
  /// before you were shown the alternatives.
  final String? slotId;
  final String? offId;
  final Set<String> spent;

  /// Resolves true once the change has gone through, which is when this closes.
  final Future<bool> Function(String onId) onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final bench = ref.watch(benchProvider);
    final state = ref.watch(gameProvider).state;
    final light = Theme.of(context).brightness == Brightness.light;

    return Column(
      key: const ValueKey('subs-bench-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: t('match.subs.bench'),
          subtitle: slotId == null
              ? t('match.subs.pick_off')
              : t('match.subs.pick_on'),
        ),
        if (bench.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              t('match.subs.empty_bench'),
              key: const ValueKey('subs-bench-empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                // **THREE ACROSS on a phone, and it counts rather than
                // measures.** A max-extent delegate fits as many 92px cards as
                // the width allows, which is four on most phones — four cards
                // across a sheet an inch or two wide leaves each of them too
                // small to read the face on. Three is the floor; a tablet gets
                // the extra columns its width actually earns.
                crossAxisCount: benchColumns(
                  MediaQuery.sizeOf(context).width,
                ),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
              ),
              itemCount: bench.length,
              itemBuilder: (context, i) {
                final entry = bench[i];
                // Unavailable is not merely unwise: a player at another club or
                // advertised for sale cannot take the field. And nobody who has
                // been withdrawn goes back on.
                final can =
                    slotId != null &&
                    !spent.contains(entry.instanceId) &&
                    (_cardById(state, entry.instanceId)?.isSelectable ?? false);
                return Opacity(
                  opacity: can ? 1 : 0.45,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: can
                        ? () async {
                            final done = await onChosen(entry.instanceId);
                            // Only on a YES. A manager who said no is still
                            // choosing, and taking the bench away would make
                            // trying somebody else a whole extra journey.
                            if (done && context.mounted) {
                              await Navigator.of(context).maybePop();
                            }
                          }
                        : null,
                    child: PlayerCard(
                      key: ValueKey('sub-bench-${entry.instanceId}'),
                      view: entry.card,
                      light: light,
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

CardInstance? _cardById(Map<String, dynamic>? state, String instanceId) {
  final cells = (state?['grid'] as Map<String, dynamic>?)?['cells'];
  if (cells is! List) return null;
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card != null && card.instanceId == instanceId) return card;
  }
  return null;
}
