/// The formation and tactic pickers.
///
/// Both are bottom sheets — one of the three popup shapes — rather than a
/// fourth thing, and both write through `game.update` so the change is saved
/// and the header's ratings recompute off it.
///
/// **Tactic names and descriptions come from the CATALOGUE.** An earlier note
/// here said there were no keys for them and read the English off the data —
/// there are: `strategy.<id>.name`, `.desc` and the two `squad.tactic.injury_*`
/// lines are translated in all ten catalogues. Formation labels stay on the data,
/// because `4-4-2` is the same in every language.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart' show suspendedIn;
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart';
import 'package:merge_empire_fc/ui/screens/squad/pitch_token.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

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

/// The five shapes, as shapes.
///
/// A two-column grid of cards, each carrying a MINI PITCH with the eleven dots
/// on it — the shape itself decides the attack/defence balance in the sim, so
/// seeing it is the information. A list of "4-4-2 / Balanced" rows made a
/// manager decode the numbers back into a picture.
///
/// **Picking one applies it and re-marks the sheet; it does NOT close.** The
/// manager is comparing shapes, and yanking the list away after one tap makes
/// trying a second cost a whole extra journey. They close it themselves.
Future<void> showFormationPicker(BuildContext context, WidgetRef ref) {
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.6,
    child: Consumer(
      builder: (context, ref, _) {
        final kit = Theme.of(context).extension<KitTheme>()!;
        final current = ref.watch(formationIdProvider);
        return GridView.count(
          key: const ValueKey('formation-picker'),
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            for (final formation in formations.values)
              _PickCard(
                cardKey: 'formation-${formation.id}',
                active: formation.id == current,
                activeEdge: kit.accent,
                activeFill: kit.accent.withValues(alpha: 0.16),
                activeInk: kit.accentBright,
                onTap: formation.id == current
                    ? null
                    : () => setFormation(ref, formation.id),
                leading: FormationMini(
                  formation: formation,
                  accent: kit.accent,
                  border: kit.border,
                ),
                title: formation.label,
                subtitleIcon: _styleIcon(formation.style),
                subtitle: t('squad.formation.style.${formation.style}'),
                subtitleColor: _styleColor(context, formation.style),
              ),
          ],
        );
      },
    ),
  );
}

/// The shape's character, as the sim reads it: more forwards is more team ATK.
String _styleIcon(String style) => switch (style) {
  'attacking' => 'swords',
  'defensive' => 'shield',
  _ => 'scales',
};

Color _styleColor(BuildContext context, String style) => switch (style) {
  'attacking' => const Color(0xFFE87A3A),
  'defensive' => const Color(0xFF4A9EDD),
  _ => Theme.of(context).extension<KitTheme>()!.textMuted,
};

/// A formation drawn as eleven dots on a mini pitch, in the JS's own 100×140 box.
class FormationMini extends StatelessWidget {
  const FormationMini({
    super.key,
    required this.formation,
    required this.accent,
    required this.border,
    this.width = 34,
    this.height = 46,
  });

  final Formation formation;
  final Color accent;
  final Color border;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(
      painter: _FormationMiniPainter(
        slots: [for (final s in formation.slots) (s.x.toDouble(), s.y * 1.4)],
        accent: accent,
        border: border,
      ),
    ),
  );
}

class _FormationMiniPainter extends CustomPainter {
  const _FormationMiniPainter({
    required this.slots,
    required this.accent,
    required this.border,
  });

  final List<(double, double)> slots;
  final Color accent;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 140);
    final edge = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 92, 132),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0x1A7FB47F));
    canvas.drawRRect(rect, edge);
    canvas.drawLine(
      const Offset(4, 70),
      const Offset(96, 70),
      Paint()
        ..color = border
        ..strokeWidth = 3,
    );
    final dot = Paint()..color = accent;
    for (final (x, y) in slots) {
      canvas.drawCircle(Offset(x, y), 6.5, dot);
    }
  }

  @override
  bool shouldRepaint(_FormationMiniPainter old) =>
      old.accent != accent || old.border != border || old.slots != slots;
}

/// The five tactics, each keeping its OWN hue whether or not it is selected.
///
/// The icon disc is always the tactic's colour, and selecting a row pulls that
/// same colour out into the border, the wash and the name — five rows, five
/// identities. It is what lets a manager read the in-match strip later without
/// parsing the label.
///
/// **Every row is priced.** ATK and DEF carry the signed percentage the tactic
/// applies, and a tactic that changes injury risk says so. A picker with only
/// names on it made five tactics look like five labels.
Future<void> showTacticPicker(BuildContext context, WidgetRef ref) {
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.72,
    child: Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(strategyIdProvider);
        return ListView(
          key: const ValueKey('tactic-picker'),
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            for (final strategy in strategies.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TacticRow(
                  strategy: strategy,
                  active: strategy.id == current,
                  onTap: strategy.id == current
                      ? null
                      : () => setStrategy(ref, strategy.id),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _TacticRow extends StatelessWidget {
  const _TacticRow({
    required this.strategy,
    required this.active,
    required this.onTap,
  });

  final Strategy strategy;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final hue = tacticColor(context, strategy.id);
    final ink = Theme.of(context).colorScheme.onSurface;
    final injPct = ((strategy.injMod - 1) * 100).round();

    return Material(
      color: active ? tacticTint(context, strategy.id) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? hue : kit.border, width: 2),
      ),
      child: InkWell(
        key: ValueKey('tactic-${strategy.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tacticTint(context, strategy.id, active ? 26 : 13),
                ),
                child: Center(
                  child: Opacity(
                    opacity: active ? 1 : 0.8,
                    child: GameIcon(
                      tacticIconName(strategy.id),
                      size: 17,
                      color: hue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (active) ...[
                          GameIcon('check', size: 13, color: hue),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            t('strategy.${strategy.id}.name'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: active ? hue : ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        // **COUNTER ATTACK'S ATK IS A RANGE, NOT A SWAP.** The
                        // pill said `ATK -8% ⇄ +8%`, which reads as the two
                        // trading places — and nothing trades. Its DEF is a flat
                        // +8% like anyone else's; what moves is the ATK, lifted
                        // by `commitmentGain` against a side that commits forward
                        // and cut against a deep block. So the attack pill shows
                        // the two ends of that range and the defence pill is an
                        // ordinary one.
                        if (strategy.id == 'counterAttack') ...[
                          _RangePill(
                            label: 'ATK',
                            low: strategy.atkMult * (1 - strategy.commitmentGain),
                            high:
                                strategy.atkMult * (1 + strategy.commitmentGain),
                          ),
                          _ModPill(label: 'DEF', mult: strategy.defMult),
                        ] else ...[
                          _ModPill(label: 'ATK', mult: strategy.atkMult),
                          _ModPill(label: 'DEF', mult: strategy.defMult),
                        ],
                        if (strategy.injMod > 1.05)
                          _RiskPill(
                            label: t('squad.tactic.injury_up', {'n': injPct}),
                            ink: dangerInk,
                            edge: dangerInk,
                          )
                        else if (strategy.injMod < 1.0)
                          _RiskPill(
                            label: t('squad.tactic.injury_down', {'n': injPct}),
                            ink: kit.accentBright,
                            edge: kit.accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('strategy.${strategy.id}.desc'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: kit.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `atkMult`/`defMult` are multipliers on squad ATK/DEF where 1.0 is no change,
/// so the pill shows the signed percentage — All Out Attack is ATK +20%.
class _ModPill extends StatelessWidget {
  const _ModPill({required this.label, required this.mult});

  final String label;
  final double mult;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final light = Theme.of(context).brightness == Brightness.light;
    final v = ((mult - 1) * 100).round();
    if (v == 0) {
      return _Pill(
        text: '$label ±0%',
        ink: kit.textMuted,
        edge: kit.border,
        heavy: false,
      );
    }
    // The bright pill colours wash out on white, so light mode takes darker ones.
    final col = v > 0
        ? (light ? const Color(0xFF15803D) : const Color(0xFF4ADE80))
        : (light ? const Color(0xFFDC2626) : const Color(0xFFF87171));
    return _Pill(
      text: '$label ${v > 0 ? '+' : ''}$v%',
      ink: col,
      edge: col.withValues(alpha: 0.4),
    );
  }
}

/// A multiplier that MOVES: the two ends of its range, low to high.
///
/// Only Counter Attack has one. `-15% → +1%` says what the tactic actually does
/// — it is a bet on the opponent, and the pill is the odds.
class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.low,
    required this.high,
  });

  final String label;
  final double low;
  final double high;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final col = light ? const Color(0xFF1D4ED8) : const Color(0xFF4FC3F7);
    String pct(double m) {
      final v = ((m - 1) * 100).round();
      return '${v > 0 ? '+' : ''}$v%';
    }

    return _Pill(
      text: '$label ${pct(low)} → ${pct(high)}',
      ink: col,
      edge: col.withValues(alpha: 0.4),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.label, required this.ink, required this.edge});

  final String label;
  final Color ink;
  final Color edge;

  @override
  Widget build(BuildContext context) =>
      _Pill(text: label, ink: ink, edge: edge);
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.ink,
    required this.edge,
    this.heavy = true,
  });

  final String text;
  final Color ink;
  final Color edge;
  final bool heavy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: edge),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: heavy ? FontWeight.w900 : FontWeight.w800,
        color: ink,
      ),
    ),
  );
}

/// One card in the formation grid.
class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.cardKey,
    required this.active,
    required this.activeEdge,
    required this.activeFill,
    required this.activeInk,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitleIcon,
    required this.subtitle,
    required this.subtitleColor,
  });

  final String cardKey;
  final bool active;
  final Color activeEdge;
  final Color activeFill;
  final Color activeInk;
  final VoidCallback? onTap;
  final Widget leading;
  final String title;
  final String subtitleIcon;
  final String subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: active ? activeFill : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? activeEdge : kit.border, width: 2),
      ),
      child: InkWell(
        key: ValueKey(cardKey),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: active ? activeInk : ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        GameIcon(subtitleIcon, size: 11, color: subtitleColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            subtitle,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pick somebody for one slot.
///
/// Opened by tapping an empty slot on the pitch, and by Swap on an occupied one.
///
/// **Everyone is rated FOR THIS SLOT.** A striker offered at left back shows what
/// he would actually be worth there, coloured by what the slot costs him, and the
/// list is ordered by that rather than by card rating — otherwise the top of the
/// list is the best card rather than the best choice.
///
/// **The filter defaults to the slot's own position** and can be widened. And
/// nobody unavailable is offered: `isUnavailable` covers the loaned-out and the
/// listed as well as the injured, and the match engine rates all three zero, so
/// offering one let a manager field a hole in the side.
Future<void> showSlotPicker(
  BuildContext context,
  WidgetRef ref, {
  required String slotId,
}) {
  final slotPos = ref
      .read(pitchSlotsProvider)
      .firstWhere(
        (slot) => slot.slotId == slotId,
        orElse: () => ref.read(pitchSlotsProvider).first,
      )
      .slotPosition;

  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.72,
    child: _SlotPicker(slotId: slotId, slotPosition: slotPos),
  );
}

class _SlotPicker extends ConsumerStatefulWidget {
  const _SlotPicker({required this.slotId, required this.slotPosition});

  final String slotId;
  final String slotPosition;

  @override
  ConsumerState<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends ConsumerState<_SlotPicker> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    // **The slot's own line, unless nobody plays it.** The JS defaults the
    // filter to `slotPos` and stops there, which on a squad with no reserve
    // keeper opens the picker on an empty sheet and a chip the manager has to
    // work out to un-press. If the default line offers nobody, it opens on ALL.
    final line = widget.slotPosition;
    final any = ref
        .read(slotCandidatesProvider(widget.slotPosition))
        .any((entry) => entry.card.position == line);
    _filter = any ? line : 'ALL';
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final candidates = [
      for (final entry in ref.watch(
        slotCandidatesProvider(widget.slotPosition),
      ))
        if (_filter == 'ALL' || entry.card.position == _filter) entry,
    ];
    final light = Theme.of(context).brightness == Brightness.light;

    return Column(
      key: const ValueKey('slot-picker'),
      children: [
        PositionFilterBar(
          keyPrefix: 'slot-filter',
          value: _filter,
          onChanged: (line) => setState(() => _filter = line),
        ),
        Expanded(
          child: candidates.isEmpty
              ? Center(
                  key: const ValueKey('slot-picker-empty'),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      t('squad.picker.empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kit.textMuted, fontSize: 13),
                    ),
                  ),
                )
              // **CARDS, THREE ACROSS — the bench's own grid.** The JS lists
              // them as rows and the port followed it, so the one sheet in the
              // game where a manager compares players against each other showed
              // each of them as a 40px thumbnail on a line of text, while the
              // bench two taps away showed the same men as cards. Asked for
              // directly, and it is the same [benchColumns] count so the two
              // sheets do not disagree about how wide a player is.
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: benchColumns(
                      MediaQuery.sizeOf(context).width,
                    ),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    // The bench's own, now the slot rating is on the card
                    // rather than on a pill under it — a cell taller than the
                    // card it holds left a strip of gap where the pill was.
                    childAspectRatio: 0.78,
                  ),
                  itemCount: candidates.length,
                  itemBuilder: (context, i) {
                    final entry = candidates[i];
                    return GestureDetector(
                      key: ValueKey('slot-pick-${entry.instanceId}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        swapIntoSlot(
                          ref,
                          slotId: widget.slotId,
                          instanceId: entry.instanceId,
                        );
                        Navigator.of(context).pop();
                      },
                      // **WHAT HE IS WORTH IN THIS SLOT, in the chip the card
                      // already has.** It was a coloured bar UNDER the card —
                      // reported from the couch with a shot of it: a `26` in
                      // the corner and a red `13` on a strip below, two
                      // numbers for one player with the one that mattered the
                      // further from his face. "Put that score in the top left
                      // in place of the 26 and make the background red." The
                      // colours are the pitch token's own, which is where the
                      // out-of-position judgement is already made.
                      child: PlayerCard(
                        view: entry.card,
                        light: light,
                        ratingInstead: (
                          value: entry.effRating,
                          ink: penaltyColor(entry.penalty),
                          background: penaltyBg(entry.penalty),
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


/// The line filter — All, GK, DEF, MID, FWD.
///
/// **The spec hangs this bar on TWO sheets** and the port had it on one.
/// `_benchFilterDefs()` in `SquadScreen.js` is built once and passed to both
/// `_openSlotPicker` and the bench sheet, so the bench had a way to narrow
/// twenty-odd cards down to the four centre backs; the port's bench had none,
/// which is the half of this that was asked for. One bar, both sheets — two
/// copies would drift the moment either gained a line.
///
/// It scrolls, because five chips of translated position names do not fit
/// across a 320pt phone in every language.
class PositionFilterBar extends StatelessWidget {
  const PositionFilterBar({
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// What the chips' keys are prefixed with, so two bars on two sheets are two
  /// findable things.
  final String keyPrefix;

  static const List<String> lines = ['ALL', 'GK', 'DEF', 'MID', 'FWD'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: ChoiceChip(
                  key: ValueKey('$keyPrefix-$line'),
                  label: Text(
                    line == 'ALL' ? t('pi.filter.all') : t('pos.$line'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: value == line,
                  onSelected: (_) => onChanged(line),
                ),
              ),
            ),
        ],
      ),
    );
  }
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

/// Send a bench player on, into the slot that suits him best.
///
/// **An empty slot first**, the one where he loses least to the position — a
/// side with a hole in it wants filling before it wants improving. With eleven
/// out there he takes the place of whoever he compares best against, measured
/// per slot rather than on card ratings: a 78 striker does not improve left
/// back, and comparing the printed numbers says he does.
///
/// **He always comes on.** An earlier version refused when he improved nobody,
/// on the reasoning that demoting a better player is not what was asked — but a
/// squad of equals then made the button do nothing at all, with no way to tell
/// that from a broken one. A manager rotating fresh legs into a side of
/// identical ratings is a real thing to want, and it is their tap.
void sendOnFromBench(WidgetRef ref, {required String instanceId}) {
  ref.read(gameProvider).update((s) {
    final squad = s['squad'];
    if (squad is! Map<String, dynamic>) return;
    final lineup = squad['lineup'];
    if (lineup is! List) return;

    final incoming = CardInstance.from(
      gridCells(s).firstWhere(
        (raw) => raw is Map<String, dynamic> && raw['instanceId'] == instanceId,
        orElse: () => null,
      ),
    );
    if (incoming == null) return;
    // **A BAN IS THE ONE REFUSAL LEFT.** The button is hidden for a suspended
    // man, and this is the other end of the same rule: he is scored zero, so
    // fielding him is fielding a hole, and `refillLineupFromBench` would put
    // him straight back out again anyway.
    if (suspendedIn(s).contains(instanceId)) return;
    final ratios = _ratios(s);

    int worthIn(CardInstance? card, String slotPosition) => card == null
        ? -1
        : getCardStats(
            card,
            slotPosition: slotPosition,
            definitionRatios: ratios,
            fatigue: true,
          ).rating;

    Map<String, dynamic>? best;
    var bestScore = -1 << 20;
    for (final row in lineup) {
      if (row is! Map<String, dynamic>) continue;
      final position = '${row['slotPosition']}';
      final mine = worthIn(incoming, position);
      final sitting = row['cardInstanceId'];
      // An empty slot outranks every occupied one — the +1000 is what makes
      // "fill the hole" beat "improve the best-improvable slot" without a second
      // pass.
      final score = sitting == null
          ? 1000 + mine
          : mine -
                worthIn(
                  CardInstance.from(
                    gridCells(s).firstWhere(
                      (raw) =>
                          raw is Map<String, dynamic> &&
                          raw['instanceId'] == sitting,
                      orElse: () => null,
                    ),
                  ),
                  position,
                );
      if (score > bestScore) {
        bestScore = score;
        best = row;
      }
    }
    if (best == null) return;
    best['cardInstanceId'] = instanceId;
  });
}

Map<String, dynamic> _ratios(Map<String, dynamic> s) {
  final r = s['definitionRatios'];
  return r is Map<String, dynamic> ? r : const <String, dynamic>{};
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
    // **AUTO MUST NOT PICK A BANNED MAN.** Both paths scored on `isSelectable`,
    // which is injury and availability and says nothing about a ban — so Auto
    // walked a suspended player straight into the eleven, and only Auto did.
    final banned = suspendedIn(s);

    if (isProMode(s)) {
      squad['lineup'] = encodeLineup(
        buildDefaultLineup(
          squad['formation'] as String? ?? defaultFormation,
          cards,
          fatigue: true,
          banned: banned,
        ),
      );
      return;
    }

    final pick = bestFormationForFixture(s, banned: banned);
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
