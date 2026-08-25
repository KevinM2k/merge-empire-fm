/// What the HUD's energy `+` opens.
///
/// It emitted `nav:energy` and nothing listened, so it was a button that did
/// nothing — the same class of bug as the cog wired to a stub.
///
/// A bottom sheet, one of the three shapes, rather than a fourth thing. It says
/// where the player stands, when the next pip lands, and what the two routes to
/// more are: a rewarded video or the Shop's energy products. **The video WORKS
/// now** — see `services/admob_ads.dart`; the priced route is still waiting on
/// the billing bridge.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

/// The placement this sheet spends. A key from `ad_units.dart`.
const String energyPlacement = 'energy_pip';

/// Take the video, and top up if it was watched.
///
/// **PRO MODE REFILLS SOMETHING ELSE.** There are no pips there — the squad's
/// match fitness is the gate — so the same video buys a quarter of everyone's
/// fitness back rather than three of a currency that does not exist. The JS
/// branches on exactly this and so does the toast.
Future<void> watchEnergyAd(WidgetRef ref) async {
  final outcome = await ref.read(rewardedAdsProvider).show(energyPlacement);
  if (outcome == AdOutcome.unavailable) {
    emit('toast:info', t('toast.no_ad'));
    return;
  }
  if (outcome != AdOutcome.rewarded) return;
  final game = ref.read(gameProvider);
  final pro = game.state?['settings'] is Map<String, dynamic> &&
      (game.state!['settings'] as Map<String, dynamic>)['hardMode'] == true;
  if (pro) {
    game.update((s) => topUpAllEnergy(s, now(), PlayerEnergy.adRefillPct));
    emit('playerEnergy:updated');
    emit('toast:success', t('toast.energy_refilled'));
  } else {
    game.update((s) => onWatchAdComplete(s, 'energy'));
    emit('toast:success', t('toast.energy_added', {'n': Energy.adReward}));
  }
}

/// Where the player stands on energy.
typedef EnergyStatus = ({int current, int max, int nextPipMs, bool full});

final energyStatusProvider = savePick<EnergyStatus>((s) {
  final energy = s['energy'];
  final currentRaw = energy is Map<String, dynamic> ? energy['current'] : null;
  final current = currentRaw is num ? currentRaw.floor() : 0;
  final max = getEnergyMax(s);
  return (
    current: current,
    max: max,
    nextPipMs: msUntilNextPip(s),
    full: current >= max,
  );
});

Future<void> showEnergySheet(BuildContext context, WidgetRef ref) {
  return showBottomSheetPopup<void>(
    context,
    // Taller since the refill moved onto it: the sheet carries the meter, the
    // countdown, the ad row and now a priced purchase, and at 0.45 the last of
    // those was below the fold on a short phone.
    heightFraction: 0.56,
    child: Consumer(
      builder: (sheetContext, sheetRef, _) {
        final kit = Theme.of(sheetContext).extension<KitTheme>()!;
        final status = sheetRef.watch(energyStatusProvider);

        return ListView(
          key: const ValueKey('energy-sheet'),
          padding: const EdgeInsets.all(16),
          children: [
            SheetHeader(
              title: t('shop.section.energy'),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            // **THE TANK, AS PIPS.** It was the bare figure `3/6` beside a
            // bolt, which is the one thing on an energy sheet that could be a
            // picture and was a fraction. A row of bolts says how much is left
            // AND how much the tank holds in one look, which is what the
            // fraction was asking the player to work out.
            _PipRow(status: status),
            const SizedBox(height: 8),
            Center(
              child: Text(
                // A full tank has no next pip to wait for, and a countdown to
                // nothing is worse than no countdown. FULL is the HUD's own word
                // for this; "already ready" is the ad gate's and said nothing
                // about the tank.
                status.full
                    ? t('hud.energy_full')
                    : formatDuration(status.nextPipMs),
                key: const ValueKey('energy-next'),
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 18),
            // **THE TWO ROUTES, SIDE BY SIDE.** They were stacked full-width
            // buttons with their refusals printed underneath, so the sheet read
            // as a column of things that do not work. They are two OPTIONS —
            // watch something, or pay — and options that are alternatives
            // belong beside each other, which is also what makes the greyed-out
            // one read as the other half of a choice rather than as a broken
            // control.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _EnergyOption(
                      optionKey: const ValueKey('energy-watch-ad'),
                      glyph: '📺',
                      title: t('energy.reward.up_to', {
                        'amount': Energy.adReward,
                        'coin': t('shop.section.energy'),
                      }),
                      // A full tank has nothing to add to; everything else is
                      // the SDK's business and answers honestly when asked.
                      note: status.full ? t('hud.energy_full') : null,
                      tint: kit.accentBright,
                      tone: StoreTone.ad,
                      cta: t('shop.claim_cta'),
                      // **THE CALLER'S `ref`, NOT THE SHEET'S.** Popping first
                      // is right — the video takes the screen — but `sheetRef`
                      // belongs to a `Consumer` inside the route being popped,
                      // so awaiting a video on it and then reading the game
                      // reads through a disposed element. Reported as "I
                      // watched the ad and got no energy", which is exactly
                      // what that looks like from the couch.
                      onTap: status.full
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(watchEnergyAd(ref));
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // BUY IT HERE. The refill is a gem item that already exists,
                  // is already priced and already works — and the only way to
                  // reach it was to close this sheet, land on the Shop's gems
                  // shelf, scroll to Boosts and find it. Someone who has opened
                  // the energy sheet has already said what they want.
                  Expanded(
                    child: _RefillButton(
                      sheetContext: sheetContext,
                      sheetRef: sheetRef,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const ValueKey('energy-to-shop'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                // Where the gems themselves come from, for the case the button
                // above is short of them.
                sheetRef
                    .read(shellControllerProvider.notifier)
                    .deepLinkShop(ShopSection.gems);
              },
              child: Text(t('nav.shop')),
            ),
          ],
        );
      },
    ),
  );
}

/// The energy refill, bought from the sheet that is asking for it.
///
/// Priced on the button and dead with a reason when it cannot be paid for —
/// the same bargain every other purchase in the game makes, rather than a
/// button that fails on the tap.
class _RefillButton extends ConsumerWidget {
  const _RefillButton({required this.sheetContext, required this.sheetRef});

  final BuildContext sheetContext;
  final WidgetRef sheetRef;

  static const String _itemId = 'energy_refill';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final item = getGemItem(_itemId);
    if (item == null) return const SizedBox.shrink();
    final state = ref.watch(gameProvider).state;
    ref.watch(saveRevisionProvider);
    final blocked = gemItemBlocked(state, _itemId);

    return _EnergyOption(
      optionKey: const ValueKey('energy-buy-refill'),
      glyph: '💎',
      title: t('gem.$_itemId.name'),
      note: blocked == null
          ? null
          : blocked == 'insufficient_gems'
          ? t('shop.toast.not_enough_gems')
          : t('settings.comingSoon'),
      tint: kit.accent,
      // Gems, so the button is the gem BLUE and the price is on it — the cost
      // was tacked onto the title, which is the one place a price does not go.
      tone: StoreTone.gem,
      cta: '${item.cost}',
      leading: const GameIcon('gem', size: 13),
      onTap: blocked != null
          ? null
          : () {
              ref.read(gameProvider).update((s) => buyGemItem(s, _itemId));
              Navigator.of(sheetContext).pop();
            },
    );
  }
}

/// The tank, drawn.
class _PipRow extends StatelessWidget {
  const _PipRow({required this.status});

  final EnergyStatus status;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // A tank can be tiered up a long way; past a dozen the pips stop being
    // countable and the figure is the honest answer.
    final pips = status.max <= 12;
    return Column(
      children: [
        if (pips)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < status.max; i++)
                Icon(
                  i < status.current ? Icons.bolt : Icons.bolt_outlined,
                  size: 26,
                  color: i < status.current ? kit.accentBright : kit.border,
                ),
            ],
          ),
        if (pips) const SizedBox(height: 6),
        Text(
          '${status.current}/${status.max}',
          key: const ValueKey('energy-count'),
          style: TextStyle(
            fontSize: pips ? 15 : 28,
            fontWeight: FontWeight.w900,
            color: pips ? kit.textMuted : kit.accentBright,
          ),
        ),
      ],
    );
  }
}

/// One way to get more energy: a glyph, what it gives, and why it cannot.
///
/// **A box, not a full-width button with its refusal underneath.** The routes
/// are alternatives, so they sit beside each other — and a dead one inside a box
/// of its own reads as the half of a choice that is not available yet, rather
/// than as a broken control in a column of them.
class _EnergyOption extends StatelessWidget {
  const _EnergyOption({
    required this.optionKey,
    required this.glyph,
    required this.title,
    required this.note,
    required this.tint,
    required this.tone,
    required this.cta,
    required this.onTap,
    this.leading,
  });

  final Key optionKey;
  final String glyph;
  final String title;

  /// What it costs, which is what colours the button — see [StoreButton].
  final StoreTone tone;

  /// The verb, or the price.
  final String cta;

  /// A glyph before [cta] — the currency it is priced in.
  final Widget? leading;

  /// Why it cannot be taken, or null when it can.
  final String? note;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final live = onTap != null;
    return Material(
      key: optionKey,
      color: live ? tint.withValues(alpha: 0.13) : kit.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        // The box stays tappable as well as the button: a large target that
        // does the same thing is a courtesy, not a second control.
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: live ? tint.withValues(alpha: 0.6) : kit.border,
            ),
          ),
          child: Column(
            children: [
              Opacity(
                opacity: live ? 1 : 0.45,
                child: Text(glyph, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: live ? kit.accentBright : kit.textMuted,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kit.textMuted, fontSize: 10),
                ),
              ],
              // **AND IT ENDS IN A BUTTON, in the currency's own colour.** The
              // whole box was the tap target and nothing on it said "press
              // this" — the shop's rule is one button, four colours, and the
              // colour always answers "what does this cost me?". Yellow is a
              // rewarded video and blue is gems, here as everywhere else.
              const Spacer(),
              const SizedBox(height: 10),
              StoreButton(
                key: ValueKey('${(optionKey as ValueKey).value}-btn'),
                tone: tone,
                label: cta,
                small: true,
                leading:
                    leading ??
                    (tone == StoreTone.ad
                        ? const GameIcon('video', size: 13)
                        : null),
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
