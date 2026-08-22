/// The free shelf — everything a rewarded video buys, in one place.
///
/// The GATE is live: `ad_gate_engine` decides whether a row is ready or waiting,
/// and a spent daily cap says so. The watch button is dead until M4 lands
/// AdMob, because an ad button with no ad behind it grants nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// How many rewarded views the daily cap has left, and how long until the next.
typedef AdGate = ({int remaining, bool ready, int waitMs});

final adGateProvider = savePick<AdGate>(
  (s) => (
    remaining: packAdsRemaining(s),
    ready: canWatchPackAd(s),
    waitMs: msUntilPackAd(s),
  ),
);

class FreeShelfSection extends ConsumerWidget {
  const FreeShelfSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(adGateProvider);
    final blocked = paidDisabledReason();
    // A cap that is spent says so; otherwise the row says how long until the
    // next view. Waiting is information, not a hidden row.
    //
    // **"ALREADY READY" GOES WHILE THERE IS NO AD**, which is the one of the
    // three that becomes a lie: the gate really is open and there is still
    // nothing to watch, so the tile read "Already ready" with "Coming soon"
    // directly under it. The cap and the countdown are facts about the gate and
    // stay true whatever the SDK is doing.
    final status = gate.remaining <= 0
        ? t('shop.daily_cap')
        : gate.ready
        ? (blocked == null ? t('shop.already_ready') : null)
        : formatAdWait(gate.waitMs);

    return ShopSectionFrame(
      id: ShopSectionId.free,
      child: ShopGrid(
        children: [
          ShopTile(
            tileKey: 'ad-match-cooldown',
            title: t('shop.match_cooldown_ad_name'),
            subtitle: t('shop.match_cooldown_ad_desc'),
            price: t('shop.claim_cta'),
            tone: StoreTone.ad,
            badge: status,
            disabledReason: blocked,
          ),
          ShopTile(
            tileKey: 'ad-lucky-boot',
            title: t('shop.lucky_boot_ad_name'),
            subtitle: t('shop.lucky_boot_ad_desc'),
            price: t('shop.claim_cta'),
            tone: StoreTone.ad,
            badge: status,
            disabledReason: blocked,
          ),
        ],
      ),
    );
  }
}
