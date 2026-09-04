/// The two Match Day tiles — the things that change how the next match goes.
///
/// **THEY ARE NOT A SHELF OF THEIR OWN ANY MORE.** A heading over two tiles,
/// with Boosts & Items directly above it carrying its own, split one answer to
/// "what can I buy that helps me" across two headings eighteen points apart —
/// and the Boosts tab is named for the shelf they now sit in, so the Match Day
/// heading was a subdivision of a tab with four of them. Asked for from the
/// couch: put the two items under Boosts & Items and drop the heading. They go
/// at the END of that grid, which is the order they were already in relative to
/// it. See [matchDayTiles] and `_SpendShelf`.
///
/// **THEY COST GEMS NOW, AND THE SHELF IS NOT CALLED FREE.** Both were
/// rewarded-video tiles under a heading that said Free, which put the two
/// controls with the most effect on a match behind an advert — and made the
/// shelf's own name a promise about a price rather than a description of what
/// was on it. Asked for from the couch: two gems each, and drop the word free.
/// [matchDayGemCost] and [luckyBootGemCost] are those prices and say why they
/// are what they are — the Boot is the dearer of the two.
///
/// **The ad gate went with them, and so did two AdMob placements.** The gate
/// was three separate rules stacked on one tile — the shared frequency gate,
/// the day's three cooldown videos, and whether a boot was already held — and
/// two of the three existed only because a video was involved. What survives
/// is the third, which is about the GRANT: a boost already running has nothing
/// to sell, and a boot already on the shelf would be overwritten by a second.
/// `match_cooldown` and `lucky_boot` in `ad_units.dart` are no longer spent
/// from anywhere; the ids stay there because the console has them.
///
/// The grants are still `engine/free_shelf_engine.dart` — what changed is what
/// is handed over to reach them, not what they do.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/free_shelf_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart'
    show luckyBootPct;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudGemInk;
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// What the two tiles are holding, so each redraws when its own thing changes.
typedef MatchDayState = ({
  bool cooldownActive,
  int cooldownMinsLeft,
  bool bootHeld,
});

final matchDayProvider = savePick<MatchDayState>(
  (s) => (
    cooldownActive: matchCooldownFree(s),
    cooldownMinsLeft: matchCooldownFreeMinsLeft(s),
    bootHeld: luckyBootHeld(s),
  ),
);

/// Spend the gems, then grant — and both inside ONE update.
///
/// **The precondition is re-read INSIDE the update** rather than trusted from
/// the build that painted the button: a tile drawn a moment before the boost
/// started must not charge for a second one, and `spendGems` returning false
/// has to leave the grant unrun rather than half-applied.
void _buy(
  WidgetRef ref, {
  required int cost,
  required String reason,
  required bool Function(Map<String, dynamic>) blocked,
  required void Function(Map<String, dynamic>) grant,
}) {
  var paid = false;
  ref.read(gameProvider).update((state) {
    if (blocked(state)) return;
    if (!spendGems(state, cost, reason)) return;
    paid = true;
    grant(state);
  });
  // **ONLY THE REFUSAL SPEAKS.** A tap that did nothing has to say why, and an
  // empty wallet is the one thing the tile cannot show. The purchase itself
  // needs no line: the tile flips its badge to Active — with the minutes left
  // on the cooldown — and the button goes dead in the same frame. Reported from
  // the couch once the two channels started speaking at all: no toasts for
  // what is already obvious. The two `shop.toast.*` grant lines keep their
  // catalogue entries and lose their callers.
  if (!paid) emit('toast:error', t('shop.toast.not_enough_gems'));
}

/// The two tiles, for whichever grid is drawing them — see the note at the top.
///
/// A function rather than a widget because they are spliced into a shelf that
/// is not theirs: a widget would put a second `ShopGrid` inside the first, and
/// two grids under one heading do not share a column edge.
List<Widget> matchDayTiles(WidgetRef ref) {
  final shelf = ref.watch(matchDayProvider);

  // **WHAT IS LEFT OF THE GATE IS THE PART ABOUT THE GRANT.** The frequency
  // gate and the day's three videos went with the ads; a boost that is
  // already running has nothing to sell, and a boot already on the shelf
  // would be overwritten by a second. Both say so in the badge rather than
  // going quietly dead.
  final cooldownState = shelf.cooldownActive
      ? t('shop.active_mins_left', {'mins': shelf.cooldownMinsLeft})
      : null;
  final bootState = shelf.bootHeld ? t('shop.active') : null;

  // **THE BADGE AND THE REASON ARE TWO LINES, and they were saying the same
  // thing.** A tile's badge sits beside the title and its disabled reason
  // under the button; while a boost was running both resolved to "Active · 5m
  // left" and the card printed it twice, one under the other. Reported from
  // the couch on both tiles. The BADGE is the one that survives — it is the
  // brighter of the two and it is where a state belongs.
  String? notTwice(String? badge, String? reason) =>
      badge != null && badge == reason ? null : reason;

  return [
    ShopTile(
      tileKey: 'ad-match-cooldown',
      // **THE ONLY TWO TILES IN THE SHOP WITH NOTHING ON TOP.** Every
      // other shelf hands `ShopTile` a glyph and it is, in the widget's
      // own words, the first thing scanned; these two were a title and a
      // subtitle in a box, which is why they read as a notice rather
      // than as two things being offered. Reported from the couch.
      //
      // The clock for a cooldown that gets shortened and the clover for a
      // boot that changes your luck — both already in the game's own set,
      // and both in the GEM blue now rather than the yellow an ad
      // disclosure is drawn in. A purchase must never wear an ad's tone.
      glyph: const GameIcon('stopwatch', size: 32, color: hudGemInk),
      title: t('shop.match_cooldown_ad_name'),
      subtitle: t('shop.match_cooldown_ad_desc'),
      price: '$matchDayGemCost',
      tone: StoreTone.gem,
      badge: cooldownState,
      disabledReason: notTwice(cooldownState, cooldownState),
      onBuy: shelf.cooldownActive
          ? null
          : () => _buy(
              ref,
              cost: matchDayGemCost,
              reason: 'match_cooldown',
              blocked: matchCooldownFree,
              grant: grantMatchCooldownAd,
            ),
    ),
    ShopTile(
      tileKey: 'ad-lucky-boot',
      glyph: const GameIcon('clover', size: 32, color: hudGemInk),
      // **NOT "Free Lucky Boot".** The generated
      // `shop.lucky_boot_ad_name` says free and its description opens
      // "Watch an ad ·"; neither is true any more. Both replaced in
      // `en_copy.dart` and the other nine overlays.
      title: t('shop.lucky_boot_name'),
      // The figure comes off the engine, never a literal — see the note on
      // the key in `en_copy.dart`.
      subtitle: t('shop.lucky_boot_desc', {
        'pct': (luckyBootPct * 100).round(),
      }),
      price: '$luckyBootGemCost',
      tone: StoreTone.gem,
      badge: bootState,
      disabledReason: notTwice(bootState, bootState),
      onBuy: shelf.bootHeld
          ? null
          : () => _buy(
              ref,
              cost: luckyBootGemCost,
              reason: 'lucky_boot',
              blocked: luckyBootHeld,
              grant: grantLuckyBootAd,
            ),
    ),
  ];
}
