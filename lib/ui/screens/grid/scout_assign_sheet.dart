/// Putting vouchers on the cards a scout is about to turn over.
///
/// **The port's own — there is no JS for this**, because in the JS a voucher
/// was one at a time and applied itself to the first card of a batch. There was
/// nothing to ask and nowhere to ask it. Vouchers are collectable now
/// (`scout_voucher_engine.dart`), so the questions "how many do I burn" and "on
/// which card" are real, and this is where they get answered.
///
/// **Deliberately NOT part of the reveal**, which is the obvious place to put it
/// and the wrong one, twice over. `scout_reveal.dart` says what it is in its own
/// header — *"A reveal asks nothing, holds nothing and is never the thing a
/// player is answering: it is an animation layer"* — and CLAUDE.md's rule is
/// that a fourth popup shape is a spec change first. It also could not work
/// there: `signPlayers` draws, prices and places card by card, and the reveal is
/// built from what it returns, so by the time a face-down card is on screen the
/// coins are gone and the tier is rolled. A voucher dropped at that point would
/// have to re-roll a card already sitting in the grid.
///
/// So it is a bottom sheet — one of the three shapes — and it runs BEFORE the
/// draw. It returns the assignment and the reveal is untouched.
///
/// **The backs are [CardBack], the reveal's own.** These are the cards the
/// player is about to watch flip, and the seam would show at the exact moment
/// the sheet closes and the reveal opens on the same batch.
///
/// **Drag AND tap, not drag alone.** The gesture is the point — a voucher goes
/// somewhere, and you can see where — but drag-only is unusable one-handed on a
/// phone, and the merge grid's own cards already answer to both.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/screens/grid/scout_reveal.dart' show CardBack;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart'
    show mouldedButtonStyle;
import 'package:merge_empire_fc/util/format.dart';

/// The card palette by tier, shared with the Scout button so a chip, the shop
/// tile it was bought from and the card that turns up are the same colour by
/// construction.
const Map<int, (Color, Color)> voucherAccent = <int, (Color, Color)>{
  2: (Color(0xFF78909C), Color(0xFF90A4AE)),
  3: (Color(0xFF43A047), Color(0xFF66BB6A)),
  4: (Color(0xFF1E88E5), Color(0xFF42A5F5)),
  5: (Color(0xFF8E24AA), Color(0xFFAB47BC)),
  6: (Color(0xFFF9A825), Color(0xFFFFCA28)),
  7: (Color(0xFFE53935), Color(0xFFEF5350)),
  8: (Color(0xFF00ACC1), Color(0xFF26C6DA)),
};

/// What one voucher in the tray is, once the division has had its say.
///
/// [usable] is false for a floor this division's pool cannot reach. That is a
/// real state rather than a defensive one: a prestige keeps the inventory and
/// drops the player back to Sunday League, so a World Class voucher can outlive
/// the division that sold it. Assigning one would fail the draw with
/// `no_candidate` and stop the whole batch — the engine refuses safely and burns
/// nothing, but a control that silently does nothing is worse than one that says
/// why, so the tile greys and names the division instead.
typedef VoucherChip = ({int floor, bool usable, String unlocksIn});

/// The tray, richest first, with each entry's division check already done.
List<VoucherChip> voucherChipsFor(Map<String, dynamic>? state) {
  final divisionId = (state?['progression'] as Map?)?['currentDivision']
      as String?;
  return [
    for (final floor in voucherInventory(state))
      (
        floor: floor,
        // The token is never division-locked: every division can scout.
        usable: floor == anyCardVoucher || voucherOffered(divisionId, floor),
        unlocksIn: floor == anyCardVoucher
            ? ''
            : voucherUnlockDivision(floor),
      ),
  ];
}

/// Open the sheet for a batch of [batch] cards.
///
/// Returns the assignment — one entry per slot, a floor or [anyCardVoucher] or
/// null — or **null when the player backed out**, which cancels the scout
/// outright rather than proceeding with nothing assigned.
///
/// That choice is worth stating. A modal sheet dismisses on a scrim tap and a
/// downward swipe, both easy to do by accident, and the alternative reading —
/// "carry on and charge me full price for four cards" — spends real coins on a
/// slip. Tapping Scout again costs a tap. This is not an enqueued popup and
/// holds nothing, so the queue's never-discard rule does not apply to it.
Future<List<int?>?> showScoutAssignSheet(
  BuildContext context, {
  required int batch,
  required Map<String, dynamic> state,
}) => showBottomSheetPopup<List<int?>>(
  context,
  heightFraction: 0.85,
  child: _AssignSheet(batch: batch, state: state),
);

/// **A plain `StatefulWidget`, not a `Consumer`.** The sheet is handed the save
/// it is deciding about and reads nothing else — and nothing it does writes,
/// either: it returns an assignment and the caller spends it. Watching a
/// provider here would rebuild the tray under the player's finger the moment
/// anything else touched the save, mid-drag.
class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.batch, required this.state});

  final int batch;
  final Map<String, dynamic> state;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  /// Slot index → the index into [_chips] of the voucher on it.
  ///
  /// By tray POSITION rather than by floor, because the tray can hold several of
  /// the same floor and they are not interchangeable once one has been placed —
  /// keying by floor would let two slots claim the same chip.
  final Map<int, int> _assigned = {};

  late final List<VoucherChip> _chips = voucherChipsFor(widget.state);

  /// The unit price with no voucher on it. Read once: nothing in this sheet
  /// spends anything, so it cannot move while the sheet is open.
  late final int _unit = scoutCost(widget.state, ignoreVoucher: true);

  late final int _coins =
      ((widget.state['resources'] as Map?)?['fanCoins'] as num?)?.toInt() ?? 0;

  /// Tiers the player's own rules will cash in on sight.
  late final List<int> _autoSell = activeAutoTiers(widget.state);

  int? _floorOn(int slot) {
    final chip = _assigned[slot];
    return chip == null ? null : _chips[chip].floor;
  }

  bool _isPlaced(int chip) => _assigned.containsValue(chip);

  int get _uncovered => widget.batch - _assigned.length;
  int get _total => _uncovered * _unit;
  bool get _affordable => _total <= _coins;

  /// **Would this floor be sold the moment it lands?**
  ///
  /// True when any tier the voucher can produce is switched on for auto-sale.
  /// A floor guarantees at least [floor], so the range is [floor]..8 and
  /// `maxAutoTier` is 7 — a World Class voucher can therefore never warn, which
  /// is correct rather than a gap.
  bool _wouldAutoSell(int floor) {
    // The token can draw anything, so it is at risk if any rule is on at all.
    if (floor == anyCardVoucher) return _autoSell.isNotEmpty;
    return _autoSell.any((tier) => tier >= floor);
  }

  void _place(int chip, int slot) {
    if (!_chips[chip].usable) return;
    setState(() {
      // A chip already on another slot moves rather than duplicating, and a
      // slot already holding one is replaced — both are what a drag onto an
      // occupied target reads as.
      _assigned.removeWhere((_, c) => c == chip);
      _assigned[slot] = chip;
    });
  }

  void _clear(int slot) => setState(() => _assigned.remove(slot));

  /// The next free slot, for a TAPPED chip — a tap says "use this one", not
  /// "use it here", so the sheet picks the first card with nothing on it.
  int? get _nextFreeSlot {
    for (var i = 0; i < widget.batch; i++) {
      if (!_assigned.containsKey(i)) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: t('scout.assign.title'),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            t('scout.assign.hint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kit.textMuted),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var slot = 0; slot < widget.batch; slot++)
                    _Slot(
                      key: ValueKey('assign-slot-$slot'),
                      kit: kit,
                      slot: slot,
                      floor: _floorOn(slot),
                      unit: _unit,
                      // Only ever shown on a covered slot, so the null case
                      // never reaches it.
                      warns: switch (_floorOn(slot)) {
                        final f? => _wouldAutoSell(f),
                        _ => false,
                      },
                      onAccept: (chip) => _place(chip, slot),
                      onClear: () => _clear(slot),
                    ),
                ],
              ),
            ),
          ),
        ),
        _Footer(
          kit: kit,
          total: _total,
          uncovered: _uncovered,
          affordable: _affordable,
          onGo: _affordable
              ? () => Navigator.of(context).pop(<int?>[
                  for (var slot = 0; slot < widget.batch; slot++)
                    _floorOn(slot),
                ])
              : null,
        ),
        _Tray(
          kit: kit,
          chips: _chips,
          isPlaced: _isPlaced,
          onTap: (chip) {
            if (_isPlaced(chip)) {
              _assigned.removeWhere((_, c) => c == chip);
              setState(() {});
              return;
            }
            final slot = _nextFreeSlot;
            if (slot != null) _place(chip, slot);
          },
        ),
      ],
    );
  }
}

/// One face-down card, and whatever has been promised to it.
class _Slot extends StatelessWidget {
  const _Slot({
    super.key,
    required this.kit,
    required this.slot,
    required this.floor,
    required this.unit,
    required this.warns,
    required this.onAccept,
    required this.onClear,
  });

  final KitTheme kit;
  final int slot;
  final int? floor;
  final int unit;
  final bool warns;
  final void Function(int chip) onAccept;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const width = 104.0;
    final accent = floor == null ? null : voucherAccent[floor];

    return DragTarget<int>(
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, _) {
        final hot = candidate.isNotEmpty;
        return GestureDetector(
          // Tapping a covered card takes the voucher back off it — the undo for
          // a drop in the wrong place, and the only one a slot needs.
          onTap: floor == null ? null : onClear,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: width,
                      height: width * 1.4,
                      child: CardBack(
                        kit: kit,
                        size: width,
                        // The back is rimmed in the tier's own glow, so a
                        // covered card already looks like what it is promising
                        // before any label is read.
                        tier: floor ?? 1,
                      ),
                    ),
                    if (hot || floor != null)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hot
                                  ? kit.accent
                                  : (accent?.$2 ?? kit.accent),
                              width: hot ? 3 : 2,
                            ),
                          ),
                        ),
                      ),
                    if (floor == null)
                      // The empty drop target. A dashed box would be the DOM
                      // idiom; a soft plate reads better against the card art
                      // and needs no painter.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            formatCoins(unit),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      _SlotBadge(floor: floor!, accent: accent),
                  ],
                ),
                const SizedBox(height: 4),
                if (warns)
                  Text(
                    t('scout.assign.autosell'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: dangerInk,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// What a covered card is promising, over the back of it.
class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.floor, required this.accent});

  final int floor;
  final (Color, Color)? accent;

  @override
  Widget build(BuildContext context) {
    final label = floor == anyCardVoucher
        ? t('scout.assign.any_tier')
        : t('scout.assign.promised', {
            'tier': tierLabel[floor] ?? 'T$floor',
          });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: accent?.$1 ?? Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t('scout.assign.free'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// The total, and the way out.
///
/// **Above the tray rather than below it**, so the running cost sits between the
/// cards and the vouchers that change it — the number moves as a chip lands, and
/// it is in the eyeline of both.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.kit,
    required this.total,
    required this.uncovered,
    required this.affordable,
    required this.onGo,
  });

  final KitTheme kit;
  final int total;
  final int uncovered;
  final bool affordable;
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!affordable)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              // **Why the way out is shut, rather than a dead button.** The
              // batch was offered on the strength of vouchers the player has
              // since declined to spend, so the uncovered slots cost more than
              // the wallet holds — `availableScoutBatchSizes` counts a held
              // voucher as a card, and only this screen knows whether it was
              // actually used.
              t('scout.assign.short'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: dangerInk,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const ValueKey('assign-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t('common.cancel')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const ValueKey('assign-go'),
                onPressed: onGo,
                // The face is asked for, never set through `backgroundColor` —
                // that colours the layer UNDER the moulded face and fails
                // silently. See `architecture_test`.
                style: mouldedButtonStyle(
                  face: kit.accent,
                  edge: kit.accent,
                  ink: kit.accentInk,
                  dead: kit.surface2,
                  deadInk: kit.textMuted,
                  border: kit.border,
                ),
                child: Text(
                  total <= 0
                      ? t('common.continue')
                      : '${t('common.continue')} · ${formatCoins(total)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Everything the player is holding, along the bottom.
class _Tray extends StatelessWidget {
  const _Tray({
    required this.kit,
    required this.chips,
    required this.isPlaced,
    required this.onTap,
  });

  final KitTheme kit;
  final List<VoucherChip> chips;
  final bool Function(int chip) isPlaced;
  final void Function(int chip) onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: kit.surface2,
      border: Border(top: BorderSide(color: kit.border)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                key: ValueKey('assign-chip-$i'),
                kit: kit,
                index: i,
                chip: chips[i],
                placed: isPlaced(i),
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.kit,
    required this.index,
    required this.chip,
    required this.placed,
    required this.onTap,
  });

  final KitTheme kit;
  final int index;
  final VoucherChip chip;
  final bool placed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = _ChipFace(kit: kit, chip: chip, placed: placed);
    if (!chip.usable) {
      return Tooltip(
        message: t('shop.voucher.unlocks_in', {
          'division': tName('division', chip.unlocksIn),
        }),
        child: body,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Draggable<int>(
        data: index,
        // No long press: a tray chip is not inside a scroller that wants the
        // same gesture, unlike a grid card, and a 200ms wait on a control whose
        // whole job is to be dragged reads as the sheet not responding.
        feedback: Material(
          type: MaterialType.transparency,
          child: Transform.scale(
            scale: 1.1,
            child: _ChipFace(kit: kit, chip: chip, placed: false),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: body),
        child: body,
      ),
    );
  }
}

class _ChipFace extends StatelessWidget {
  const _ChipFace({
    required this.kit,
    required this.chip,
    required this.placed,
  });

  final KitTheme kit;
  final VoucherChip chip;
  final bool placed;

  @override
  Widget build(BuildContext context) {
    final token = chip.floor == anyCardVoucher;
    final accent = voucherAccent[chip.floor];
    // **The token is the 🎲, not a tier-1 chip**, and that is the design
    // holding a mechanic up. Its worth is "free, and anything can turn up" —
    // it is the only voucher that can hand over an Icon — so drawing it at the
    // bottom of the tier ladder would say the opposite of what it does.
    final glyph = token
        ? t('shop.voucher.random_icon')
        : (tierEmoji[chip.floor] ?? '🎟️');
    final label = token
        ? t('shop.voucher.random')
        : (tierLabel[chip.floor] ?? 'T${chip.floor}');

    final face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent?.$2 ?? kit.border),
        gradient: accent == null
            ? null
            : LinearGradient(
                begin: const Alignment(-0.7, -1),
                end: const Alignment(0.7, 1),
                colors: [accent.$2, accent.$1],
              ),
        color: accent == null ? kit.surface : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(glyph, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent == null
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (!chip.usable) {
      // Greyed and desaturated together, the same pair the merge grid uses for
      // a target a card cannot go to — either alone still reads as available.
      return Opacity(
        opacity: 0.35,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: face,
        ),
      );
    }
    return Opacity(opacity: placed ? 0.35 : 1, child: face);
  }
}
