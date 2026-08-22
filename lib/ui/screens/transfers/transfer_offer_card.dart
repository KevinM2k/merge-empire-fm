/// A rival's bid for one of your players. Ported from
/// `ui/components/TransferOfferModal.js`.
///
/// One card for one yes/no question. The JS notes that it used to be three
/// stacked surfaces — a sheet with the numbers, a hand-positioned speech bubble
/// above it, and a first-time explainer over both — and that all three were
/// Colin: the advice, the explainer and the head on the bubble. So it is Colin's
/// card, the second of the three popup shapes, and everything he has to say is
/// in one speech.
///
/// **Declining is not free**, which is why this must never be dismissed
/// silently: it hands the buying club a grudge that makes them harder to beat
/// for the rest of the season. That is also the bug this screen fixes — an
/// offer nothing showed still timed out after five minutes and the timeout is
/// scored as a decline, so a player was collecting grudges from bids they were
/// never shown.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsGreenOn, vsRedOn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/coach_tip_engine.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// The pending bid, or null.
final pendingOfferProvider = savePick<Map<String, dynamic>?>((s) {
  final market = _map(s['transferMarket']);
  final offer = _map(market?['pendingOffer']);
  // Copied, not handed out: the save's own map is mutable and a widget holding
  // it would see the offer vanish under it the moment the answer lands.
  return offer == null ? null : <String, dynamic>{...offer};
});

/// The player's decision.
enum TransferAnswer { accepted, declined }

/// How good the bid IS, as a band with a name and a colour.
///
/// **Five names, translated ten times over, with nothing able to reach one of
/// them.** `transfer.market.jackpot` down to `transfer.market.below` sat in
/// every catalogue while the card printed the premium as a percentage buried
/// mid-sentence — a number the player has to rank for themselves, on the one
/// screen where the whole question is "is this a lot".
///
/// The thresholds are Colin's own, so the chip and his read can never disagree:
/// he calls 200% incredible and 60% a good deal, and below fair value he starts
/// talking about what the player is worth instead.
/// [context] only decides the LIGHTNESS of the two ends of the scale: `#4ADE80`
/// and `#F87171` are the dark-mode pair and neither carries on a light card.
({String key, Color colour}) transferBand(int premiumPct, [BuildContext? context]) =>
    switch (premiumPct) {
      >= 200 => (
        key: 'transfer.market.jackpot',
        colour: const Color(0xFFFFD700),
      ),
      >= 60 => (key: 'transfer.market.great', colour: context == null ? const Color(0xFF4ADE80) : vsGreenOn(context),
      ),
      >= 20 => (key: 'transfer.market.fair', colour: const Color(0xFFFBBF24)),
      >= 1 => (key: 'transfer.market.modest', colour: const Color(0xFFFB923C)),
      _ => (key: 'transfer.market.below', colour: context == null ? const Color(0xFFF87171) : vsRedOn(context),
      ),
    };

/// Colin's read on the bid.
///
/// Ordered most specific first, and every branch is about WHY rather than about
/// the price alone — the premium is already on the card as a number, so a line
/// that only said "good deal" would be the same fact twice.
String transferAdvice(
  Map<String, dynamic> state,
  Map<String, dynamic> offer,
  CardInstance? card,
) {
  final def = getPlayerDef(offer['definitionId'] as String?);
  final sellValue = _num(
    offer['marketBasePrice'] ?? offer['sellValue'] ?? def?.sellValue,
  );
  final premiumPct =
      ((_num(offer['price']) / (sellValue < 1 ? 1 : sellValue) - 1) * 100)
          .round();

  final seasons = card?.seasonsPlayed ?? 0;
  final injured = card?.injured ?? false;
  final form = _num(card?.raw['form']).toInt();
  final sponsored = card?.sponsor != null;
  final tier = _num(offer['tier'] ?? def?.tier ?? 1).toInt();
  final penalty = agingPenalty(seasons);
  final seasonsLeft = seasons >= 15 ? 0 : 15 - seasons;
  final injuryChance = getInjuryChance(seasons);

  // Could they replace the player after banking the fee? The one piece of
  // advice that is about the CLUB rather than the player.
  final coinsAfter =
      _num(_map(state['resources'])?['fanCoins']) + _num(offer['price']);
  final canReplace = coinsAfter >= scoutCost(state);

  if (premiumPct >= 200) return t('manager.transfer.incredible');
  if (seasons >= 14) {
    return t('manager.transfer.final_season', {
      'penalty': penalty,
      'seasonsLeft': seasonsLeft,
    });
  }
  if (seasons >= 10 && injured) {
    return t('manager.transfer.declining_injured', {
      'penalty': penalty,
      'seasonsLeft': seasonsLeft,
    });
  }
  if (seasons >= 10) {
    return t('manager.transfer.long_decline', {
      'seasons': seasons,
      'penalty': penalty,
      'seasonsLeft': seasonsLeft,
    });
  }
  if (injured) return t('manager.transfer.injured');
  if (!canReplace) {
    return t('manager.transfer.cant_replace', {
      'cost': formatCoins(scoutCost(state)),
    });
  }
  if (form >= 2) return t('manager.transfer.hot_form');
  if (injuryChance >= 0.35 && premiumPct >= 20) {
    return t('manager.transfer.injury_prone', {'seasons': seasons});
  }
  if (seasons >= 7) return t('manager.transfer.veteran', {'seasons': seasons});
  if (premiumPct >= 60) return t('manager.transfer.good_deal');
  if (sponsored) return t('manager.transfer.sponsored');
  if (tier >= 5 && !canReplace) return t('manager.transfer.high_tier');
  if (premiumPct <= 10 && tier <= 2) return t('manager.transfer.replaceable');
  return t('manager.transfer.fair');
}

/// Show the bid and settle it.
///
/// Returns what the player chose, or null when they parked it. Parking is safe
/// and deliberate — nothing is discarded, the offer is still pending, and the
/// squad can be looked over before answering. It is the one dismissal that does
/// NOT count as a decline.
Future<TransferAnswer?> showTransferOffer(
  BuildContext context,
  WidgetRef ref,
) async {
  final offer = ref.read(pendingOfferProvider);
  if (offer == null) return null;

  // Through `update`, because spending the id WRITES to the save.
  final explain = ref
      .read(gameProvider)
      .update((s) => takeTipOnce(s, 'transfer_offer'));

  final answer = await showDialog<TransferAnswer>(
    context: context,
    // Tapping outside parks it rather than answering, which is only safe
    // because nothing is lost by doing so.
    barrierDismissible: true,
    builder: (_) => _TransferOfferCard(offer: offer, explain: explain),
  );
  if (answer == null) return null;

  final game = ref.read(gameProvider);
  if (answer == TransferAnswer.accepted) {
    game.update((s) => acceptOffer(s));
  } else {
    game.update((s) => declineOffer(s));
  }
  return answer;
}

class _TransferOfferCard extends ConsumerWidget {
  const _TransferOfferCard({required this.offer, required this.explain});

  final Map<String, dynamic> offer;

  /// Whether this is the first bid this save has ever received, and so carries
  /// Colin's one-time explanation of what one IS.
  final bool explain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = ref.read(gameProvider).state ?? const <String, dynamic>{};
    final def = getPlayerDef(offer['definitionId'] as String?);
    final card = findCardById(state, offer['cardInstanceId']);

    // The offer snapshots the name when the bid was made; the live card wins, so
    // a rename between the bid landing and the card opening still shows through.
    final name =
        card?.name('${offer['playerName'] ?? ''}') ??
        '${offer['playerName'] ?? ''}';

    final price = _num(offer['price']);
    final sellValue = _num(
      offer['marketBasePrice'] ?? offer['sellValue'] ?? def?.sellValue,
    );
    final premiumPct = ((price / (sellValue < 1 ? 1 : sellValue) - 1) * 100)
        .round();

    // What the sale costs per second, sponsor multiplier included — the figure
    // the income bar visibly slows by.
    var incomePerSec = def?.idleIncomePerSec ?? 0;
    final multiplier = _num(_map(card?.sponsor)?['multiplier']);
    if (multiplier > 0) incomePerSec *= multiplier;

    // **THE MONEY IS NOT A SENTENCE.** Every fact used to be one paragraph —
    // the fee, the premium and the income all set in the same 13px grey — so
    // the number the whole card is about had to be found by reading. The two
    // ends of the question keep their words; the figure between them gets a
    // coin, a size and the band it falls in.
    final pitch = [
      t('transfer.they_want', {'player': name}),
      '${t('transfer.income_lost', {'rate': incomePerSec.toStringAsFixed(2)})}.',
    ].join(' ');
    final band = transferBand(premiumPct, context);

    return CoachCardFrame(
      key: const ValueKey('transfer-offer'),
      title: t('transfer.card_title', {'club': offer['fromTeam'] ?? ''}),
      badge: '💸',
      // **What a bid MEANS, once ever.** A paragraph inside the offer rather
      // than a coach tip stacked on top of it — the JS makes that point twice,
      // and it is why `coachtip.transfer_offer.*` exists and still turns up in
      // `seenTips`.
      extraLines: [
        if (explain)
          (
            key: 'coachtip.transfer_offer.body',
            params: const {},
            strong: false,
          ),
      ],
      // Park, no, yes. Three answers stack rather than sharing a row, which is
      // the frame's own rule: at three, a row makes every label too narrow.
      actions: [
        CoachAction(
          labelKey: 'transfer.accept_amount',
          labelParams: <String, Object?>{'amount': formatCoins(price)},
          tone: CoachTone.confirm,
          onTap: () {},
          result: TransferAnswer.accepted,
        ),
        CoachAction(
          labelKey: 'common.decline',
          tone: CoachTone.decline,
          onTap: () {},
          result: TransferAnswer.declined,
        ),
        // **Parking is not an answer**, so it does not take a colour. Tapping
        // outside does the same thing, and nothing is lost by it.
        CoachAction(labelKey: 'transfer.minimize', onTap: () {}),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (def != null)
            SizedBox(
              height: 110,
              child: ArtImage(
                path: playerImagePath(
                  def.position,
                  def.tier,
                  _num(offer['variant']).toInt(),
                ),
                fit: BoxFit.contain,
                fallback: PlayerPortrait(
                  variantIndex: _num(offer['variant']).toInt(),
                  kitColor: kit.accent,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            pitch,
            key: const ValueKey('transfer-pitch'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            key: const ValueKey('transfer-price'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoinIcon(size: 22, solid: true, color: coinFigureInk(context)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  formatCoins(price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: coinFigureInk(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // What the figure MEANS, named and coloured: five bands the
              // catalogues have carried all along with nothing able to reach
              // one of them.
              Container(
                key: ValueKey('transfer-band-${band.key}'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: band.colour.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: band.colour.withValues(alpha: 0.4)),
                ),
                child: Text(
                  t(band.key),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: band.colour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // **THE PERCENTAGE AND THE GRUDGE WARNING ARE BOTH GONE, and that is
          // a decision rather than an oversight.** "367% over fair market
          // value" is a figure nobody can act on — the price is the price — and
          // making it legible (which is what the pass that built the band chip
          // did) does not make it useful. The CHIP stays: "JACKPOT" is a
          // judgement, which is what the player actually wanted off that line.
          //
          // "Declining will make {club} play harder" went with it for the same
          // reason. Colin's read below says what to do; a second sentence
          // warning about the answer he did not recommend is the card arguing
          // with itself.
          //
          // The consequence is deliberate and is recorded in `docs/REMAINING.md`:
          // `transfer.over_fair_market`, `transfer.at_fair_market` and
          // `transfer.decline_warning` are now shipped copy with no caller,
          // which anywhere else in this port is a bug. Here it is the point.
          Text(
            transferAdvice(state, offer, card),
            key: const ValueKey('transfer-advice'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: kit.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The way back to a bid that was parked.
///
/// **Parking had no return trip.** Minimise — and a tap outside, which does the
/// same thing — left an offer pending with nothing on screen saying so, and the
/// only other way it could come back was the idle roll announcing a bid the
/// player had already seen. So the one dismissal that is not an answer was also
/// the one that could lose you the offer.
///
/// `transfer.pill_label` — "Transfer offer — tap to review" — was translated
/// into all ten catalogues with nothing able to reach it, which is the tell.
///
/// It sits in the shell above the tab bar, so it follows the player across every
/// tab: the bid is about the squad, and the squad is three tabs away from
/// wherever the card was parked.
class TransferPill extends ConsumerStatefulWidget {
  const TransferPill({super.key});

  @override
  ConsumerState<TransferPill> createState() => _TransferPillState();
}

/// **IT WAS THERE AND NOBODY SAW IT.** A `surface`-filled stadium with a 55%
/// accent hairline is the quietest thing the palette can draw, sitting above a
/// tab bar the eye already skips — so the one control standing between a player
/// and an offer they parked read as chrome.
///
/// Filled in the club's accent now, with the accent's own ink on it, and it
/// BREATHES: 1.8 seconds, the same period as Colin's unread pulse, because they
/// are the same signal — something is waiting for you. Reduced motion stops the
/// clock and leaves it at full strength rather than mid-fade.
class _TransferPillState extends ConsumerState<TransferPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  void _sync() {
    final run =
        !MediaQuery.of(context).disableAnimations &&
        ref.read(pendingOfferProvider) != null;
    if (run == _pulse.isAnimating) return;
    if (run) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(pendingOfferProvider);
    // A pill for an offer that has been answered is a button to nowhere, and
    // the clock behind it has to stop with it.
    if (offer == null) {
      _pulse.stop();
      return const SizedBox.shrink();
    }
    _sync();
    final kit = Theme.of(context).extension<KitTheme>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            // A halo rather than a scale: a pill that grows shoves the tab bar
            // under it, and this one lives in the shell where nothing may move.
            final t = math.sin(_pulse.value * 2 * math.pi) * 0.5 + 0.5;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: kit.accentBright.withValues(alpha: 0.20 + 0.28 * t),
                    blurRadius: 10 + 10 * t,
                    spreadRadius: 1 + 2 * t,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Material(
            key: const ValueKey('transfer-pill'),
            color: kit.accentBright,
            shape: const StadiumBorder(),
            elevation: 6,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => unawaited(showTransferOffer(context, ref)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💸', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(
                      t('transfer.pill_label'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: kit.accentBrightInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card a bid names, or null when it has already left.
CardInstance? findCardById(Map<String, dynamic> state, Object? instanceId) {
  final cells = _map(state['grid'])?['cells'];
  if (cells is! List) return null;
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card != null && card.instanceId == instanceId) return card;
  }
  return null;
}
