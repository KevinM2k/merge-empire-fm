/// The auto-sell rules, as the player sets them. Ported from
/// `ui/components/AutoTierSheet.js`.
///
/// The rules themselves were ported in M1 and **nothing could switch them on**:
/// `setTierAction` had no caller anywhere, so `auto_tier_engine` was a fully
/// tested engine that no save could ever reach. This is the half that was
/// missing, and it is why the scout's auto-sell reveal has anything to reveal.
///
/// Two entry points, exactly as the JS has: the Settings row that has always
/// owned it, and a pill on the Players tab — because the rules FIRE there. A
/// scouted card of a switched-on tier never reaches the grid, and "that bronze
/// card never arrived" has to be explainable without going looking for it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/settings_controls.dart'
    show SettingsToggle;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';

/// "Off", or which tiers are being sold. Both entry points show the same line.
///
/// Named tiers up to three, then a count: four names is longer than the row it
/// has to fit on, and the sheet behind the tap says it properly anyway.
String autoTierSummary(Map<String, dynamic>? state) {
  final active = activeAutoTiers(state);
  if (active.isEmpty) return t('settings.autoTier.off');
  if (active.length <= 3) {
    return [for (final tier in active) tierLabel[tier] ?? 'T$tier'].join(', ');
  }
  return t('settings.autoTier.count', {'count': active.length});
}

final autoTierSummaryProvider = savePick<String>(autoTierSummary);

/// Whether any rule is on, which is what the pill is painted by.
final autoTierActiveProvider = savePick<bool>(
  (s) => activeAutoTiers(s).isNotEmpty,
);

/// Whether the rules are still dormant. They do nothing until the tutorial is
/// finished — every Sunday League draw is bronze, so a live bronze rule would
/// soft-lock the "scout until you have three" step — so the pill that opens this
/// stays hidden until then rather than offering a switch that does nothing.
/// `done !== false`, which is the JS's own test — NOT `done == true`.
///
/// A save with no `tutorial.done` at all, or a null one, is a save that is not
/// mid-tutorial: it is every save made before the flag existed, and most of the
/// saves in the wild. Requiring an explicit `true` read all of them as
/// mid-tutorial, which hid the ×N batch control and the auto-sell pill from
/// players who had finished the tutorial long ago.
final tutorialDoneProvider = savePick<bool>(tutorialFinished);

/// What one card of [tier] fetches.
///
/// A scouted card is brand new, so there is no ageing penalty and one figure
/// covers the whole tier.
num tierSellPrice(Map<String, dynamic>? state, int tier) {
  final defs = getPlayersByTier(tier);
  if (defs.isEmpty) return 0;
  return autoSellPrice(state, defs.first, null);
}

Future<void> showAutoTierSheet(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.8,
      child: const _AutoTierSheet(),
    );

class _AutoTierSheet extends ConsumerWidget {
  const _AutoTierSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = ref.watch(gameProvider).state;
    final tutorialDone = ref.watch(tutorialDoneProvider);
    // Watched so a toggle repaints the row it was made on.
    ref.watch(autoTierSummaryProvider);

    return ListView(
      key: const ValueKey('auto-tier-sheet'),
      // A fixed handful of rows: the sheet is as tall as they are.
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      children: [
        SheetHeader(
          title: t('settings.autoTier'),
          subtitle: t('settings.autoTier.body'),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        // Dormant until the tutorial is done, and it says so rather than letting
        // the switches look broken.
        if (!tutorialDone)
          Container(
            key: const ValueKey('auto-tier-dormant'),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              t('settings.autoTier.tutorial'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        // **NOT A `SwitchListTile`.** Two reasons, and the second is a bug.
        //
        // It is a MATERIAL row in a sheet where every other control is the
        // game's own — the same objection `settings_controls.dart` records
        // against Material's `Switch`: 52×32 with its own knob travel and state
        // layer, which beside the game's toggles reads as a borrowed control.
        //
        // And a `ListTile` paints its background and its ink on the nearest
        // `Material` ANCESTOR, which here is behind the sheet's own decorated
        // box — so Flutter asserts, and every test that opens this sheet, or
        // any screen that can, failed on it. [SettingsToggle] is a
        // `GestureDetector` and an `AnimatedContainer`; it has no ancestor to
        // find.
        for (final tier in autoTiers)
          _TierRow(
            key: ValueKey('auto-tier-$tier'),
            tier: tier,
            on: getTierAction(state, tier) == TierAction.sell,
            worth: formatCoins(tierSellPrice(state, tier)),
            onToggle: (on) => ref
                .read(gameProvider)
                .update(
                  (s) => setTierAction(
                    s,
                    tier,
                    on ? TierAction.sell : TierAction.keep,
                  ),
                ),
          ),
        const SizedBox(height: 12),
        // The two tiers no rule may cover, said out loud: nobody wants a chase
        // card sold out from under them, and tier nine is globally unique, so an
        // auto-sale there cannot be undone.
        Text(
          t('settings.autoTier.top_safe'),
          style: TextStyle(
            color: kit.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// One tier's rule: what it is, what it is worth, and the switch.
///
/// The whole row is the target rather than just the toggle — a rule with a
/// 48-pixel hit area on a sheet of them is a row you have to aim at.
class _TierRow extends StatelessWidget {
  const _TierRow({
    super.key,
    required this.tier,
    required this.on,
    required this.worth,
    required this.onToggle,
  });

  final int tier;
  final bool on;
  final String worth;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggle(!on),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tierEmoji[tier] ?? ''} ${tierLabel[tier] ?? 'T$tier'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t('settings.autoTier.worth', {'coins': worth}),
                    style: TextStyle(color: kit.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Not keyed: the ROW carries the tier's key, so a tap anywhere on it
            // is the same tap.
            SettingsToggle(value: on, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

/// The Settings row, and the Players-tab pill, both open the same sheet.
class AutoTierRow extends ConsumerWidget {
  const AutoTierRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ListTile(
      key: const ValueKey('auto-tier-row'),
      leading: Icon(Icons.sell_outlined, color: kit.textMuted),
      title: Text(t('settings.autoTier')),
      subtitle: Text(
        t('settings.autoTier.hint'),
        style: TextStyle(color: kit.textMuted, fontSize: 11),
      ),
      trailing: Text(
        '${ref.watch(autoTierSummaryProvider)} ›',
        style: TextStyle(
          color: kit.accentBright,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => showAutoTierSheet(context),
    );
  }
}
