/// The free shelf — everything a rewarded video buys, in one place.
///
/// **Both tiles are LIVE now.** The gate was always live — `ad_gate_engine`
/// decides whether a row is ready or waiting and a spent daily cap says so —
/// and what was dead was the button, because there was no AdMob behind it. It
/// sat behind `paidDisabledReason()`, which is the IAP's block and not this
/// shelf's: these two cost a video, not money.
///
/// The grants are `engine/free_shelf_engine.dart`, so the caps and the day
/// boundary are decided there rather than by a widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/engine/free_shelf_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The two placements this shelf spends. Keys from `ad_units.dart`.
///
/// **`match_cooldown`, not `skip_cooldown`.** This tile is the shop's
/// match-cooldown ad — the JS shows it against `'match_cooldown'` and keeps
/// `'skip_cooldown'` for the mini-game skip on the Play tab, which is a
/// different button with a different cap and its own unit id. Both ids are in
/// `ad_units.dart`; this one was pointed at the other's, so the two placements
/// reported as one and the skip button had no placement of its own left.
const String cooldownPlacement = 'match_cooldown';
const String luckyBootPlacement = 'lucky_boot';

/// How many rewarded views the daily cap has left, and how long until the next.
typedef AdGate = ({int remaining, bool ready, int waitMs});

final adGateProvider = savePick<AdGate>(
  (s) => (
    remaining: packAdsRemaining(s),
    ready: canWatchPackAd(s),
    waitMs: msUntilPackAd(s),
  ),
);

/// What the two tiles are holding, so each redraws when its own thing changes.
typedef FreeShelfState = ({
  bool cooldownActive,
  int cooldownMinsLeft,
  int cooldownUsed,
  bool bootHeld,
});

final freeShelfProvider = savePick<FreeShelfState>(
  (s) => (
    cooldownActive: matchCooldownFree(s),
    cooldownMinsLeft: matchCooldownFreeMinsLeft(s),
    cooldownUsed: matchCooldownAdsUsed(s),
    bootHeld: luckyBootHeld(s),
  ),
);

class FreeShelfSection extends ConsumerWidget {
  const FreeShelfSection({super.key});

  /// One video, one grant. Every other outcome leaves the save alone.
  ///
  /// **`unavailable` says so and `dismissed` does not.** A video that would not
  /// fill is not the player's doing; one they closed early is a decision they
  /// have already been told the terms of.
  Future<void> _watch(
    WidgetRef ref, {
    required String placement,
    required void Function(Map<String, dynamic>) grant,
    required String toast,
  }) async {
    final outcome = await ref.read(rewardedAdsProvider).show(placement);
    if (outcome == AdOutcome.rewarded) {
      ref.read(gameProvider).update(grant);
      emit('toast:success', toast);
    } else if (outcome == AdOutcome.unavailable) {
      emit('toast:info', t('toast.ad_unavailable'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(adGateProvider);
    final shelf = ref.watch(freeShelfProvider);

    // A cap that is spent says so; otherwise the row says how long until the
    // next view. Waiting is information, not a hidden row.
    //
    // **AN OPEN GATE SAYS NOTHING**, which is what the JS does — `_renderLuckyBoot`
    // has two states, `✓ Active` and the Claim button, and no badge for "you may
    // watch one". "Already ready" sat on BOTH free tiles at once and reads as a
    // claim about the reward rather than about the gate: the player has not got
    // the thing, so being told it is ready is a lie in the only sense they care
    // about. `shop.already_ready` is an orphan key in the JS too.
    final String? gateStatus = gate.remaining <= 0
        ? t('shop.daily_cap')
        : gate.ready
        ? null
        : formatAdWait(gate.waitMs);
    final gateBlocked = gate.ready ? null : gateStatus;

    // The cooldown skip has a cap of its OWN — three a day — on top of the
    // shared frequency gate, and while the boost is running there is nothing to
    // buy.
    final cooldownBadge = shelf.cooldownActive
        ? t('shop.active_mins_left', {'mins': shelf.cooldownMinsLeft})
        : shelf.cooldownUsed >= matchCooldownAdCapPerDay
        ? t('shop.daily_cap')
        : gateStatus;
    final cooldownBlocked = shelf.cooldownActive
        ? t('shop.active_mins_left', {'mins': shelf.cooldownMinsLeft})
        : shelf.cooldownUsed >= matchCooldownAdCapPerDay
        ? t('shop.daily_cap')
        : gateBlocked;

    // A boot already waiting is HELD, not capped: there is one on the shelf and
    // a second would overwrite it.
    final bootBlocked = shelf.bootHeld ? t('shop.active') : gateBlocked;

    return ShopSectionFrame(
      id: ShopSectionId.free,
      child: ShopGrid(
        children: [
          ShopTile(
            tileKey: 'ad-match-cooldown',
            // **THE ONLY TWO TILES IN THE SHOP WITH NOTHING ON TOP.** Every
            // other shelf hands `ShopTile` a glyph and it is, in the widget's
            // own words, the first thing scanned; these two were a title and a
            // subtitle in a box, which is why the free shelf read as a notice
            // rather than as two things being offered. Reported from the couch.
            //
            // The clock for a cooldown that gets shortened and the clover for a
            // boot that changes your luck — both already in the game's own set,
            // in the yellow the ad tone is drawn in everywhere else.
            glyph: const GameIcon('stopwatch', size: 32, color: adOfferInk),
            title: t('shop.match_cooldown_ad_name'),
            subtitle: t('shop.match_cooldown_ad_desc'),
            price: t('shop.claim_cta'),
            tone: StoreTone.ad,
            badge: cooldownBadge,
            disabledReason: cooldownBlocked,
            onBuy: cooldownBlocked != null
                ? null
                : () => _watch(
                    ref,
                    placement: cooldownPlacement,
                    grant: grantMatchCooldownAd,
                    toast: t('shop.toast.no_match_cooldown'),
                  ),
          ),
          ShopTile(
            tileKey: 'ad-lucky-boot',
            glyph: const GameIcon('clover', size: 32, color: adOfferInk),
            title: t('shop.lucky_boot_ad_name'),
            subtitle: t('shop.lucky_boot_ad_desc'),
            price: t('shop.claim_cta'),
            tone: StoreTone.ad,
            badge: shelf.bootHeld ? t('shop.active') : gateStatus,
            disabledReason: bootBlocked,
            onBuy: bootBlocked != null
                ? null
                : () => _watch(
                    ref,
                    placement: luckyBootPlacement,
                    grant: (s) => grantLuckyBootAd(s),
                    toast: t('shop.toast.lucky_boot_active'),
                  ),
          ),
        ],
      ),
    );
  }
}
