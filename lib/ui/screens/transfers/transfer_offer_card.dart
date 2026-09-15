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
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/coach_tip_engine.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/transfers/coach_verdict.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
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

/// Colin's read on the bid: what he would do, and why.
///
/// Ordered most specific first, and every branch is about WHY rather than about
/// the price alone — the premium is already on the card as a number, so a line
/// that only said "good deal" would be the same fact twice.
///
/// **And about the CLUB as much as the player.** The generated set reasons from
/// the player's age, form and fee; asked for from the couch was a call that
/// weighs the table, whether they start, whether there is anyone behind them,
/// and whether the money is needed. Those branches sit where their urgency puts
/// them: a starter in a relegation fight outranks a good price, a club that is
/// skint takes a fair one it would otherwise shrug at.
CoachRead transferRead(
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
  final name =
      card?.name('${offer['playerName'] ?? ''}') ??
      '${offer['playerName'] ?? ''}';

  // The club's side of it: the table, the eleven, the bench, the coffers.
  final coins = _num(_map(state['resources'])?['fanCoins']);
  final coinsAfter = coins + _num(offer['price']);
  final cost = scoutCost(state);
  final canReplace = coinsAfter >= cost;
  final starter = inStartingEleven(state, offer['cardInstanceId'] as String?);
  final noBench = squadSize(state) <= 11;
  final standing = clubStanding(state);
  final division = getDivision(
    '${_map(state['progression'])?['currentDivision']}',
  );
  final flush = coins >= division.matchRevenueBase * 20;

  CoachRead sell(String key, [Map<String, Object?> p = const {}]) =>
      (verdict: CoachVerdict.accept, text: t(key, p));
  CoachRead hold(String key, [Map<String, Object?> p = const {}]) =>
      (verdict: CoachVerdict.decline, text: t(key, p));
  CoachRead shrug(String key, [Map<String, Object?> p = const {}]) =>
      (verdict: CoachVerdict.yourCall, text: t(key, p));

  if (premiumPct >= 200) return sell('manager.transfer.incredible');
  if (seasons >= 14) {
    return sell('manager.transfer.final_season', {
      'penalty': penalty,
      'seasonsLeft': seasonsLeft,
    });
  }
  if (seasons >= 10 && injured) {
    return sell('manager.transfer.declining_injured', {
      'penalty': penalty,
      'seasonsLeft': seasonsLeft,
    });
  }
  if (seasons >= 10) {
    return sell('manager.transfer.long_decline', {
      'seasons': seasons,
      'penalty': penalty,
      'seasonsLeft': seasonsLeft,
    });
  }
  if (injured) return sell('manager.transfer.injured');
  // A relegation fight is the one time a starter is not for sale at any fair
  // price; a runaway leader with money in the bank has no reason to sell one.
  if (starter && inDropZone(standing)) {
    return hold('manager.transfer.relegation', {'player': name});
  }
  if (starter && standing?.pos == 1 && flush && premiumPct < 60) {
    return hold('manager.transfer.flying');
  }
  if (!canReplace) {
    return hold('manager.transfer.cant_replace', {'cost': formatCoins(cost)});
  }
  if (starter && noBench && premiumPct < 60) {
    return hold('manager.transfer.starter_short', {'player': name});
  }
  // Could not afford a scout before the bid and can after it: the fee IS the
  // rebuild, and the club needs it more than the card.
  if (coins < cost && !(starter && form >= 2)) {
    return sell('manager.transfer.need_money', {'player': name});
  }
  if (form >= 2) return hold('manager.transfer.hot_form');
  if (injuryChance >= 0.35 && premiumPct >= 20) {
    return sell('manager.transfer.injury_prone', {'seasons': seasons});
  }
  if (seasons >= 7) return shrug('manager.transfer.veteran', {'seasons': seasons});
  if (premiumPct >= 60) return sell('manager.transfer.good_deal');
  if (!starter && premiumPct >= 0) {
    return sell('manager.transfer.bench_warmer', {'player': name});
  }
  if (sponsored) return shrug('manager.transfer.sponsored');
  if (tier >= 5 && !canReplace) return hold('manager.transfer.high_tier');
  if (premiumPct <= 10 && tier <= 2) return sell('manager.transfer.replaceable');
  return shrug('manager.transfer.fair');
}

/// The sentence alone. See [transferRead].
String transferAdvice(
  Map<String, dynamic> state,
  Map<String, dynamic> offer,
  CardInstance? card,
) => transferRead(state, offer, card).text;

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

  // The once-ever `coachtip.transfer_offer` explainer is still spent here so
  // the ledger matches the JS, but the card no longer prints it: this is
  // Colin passing on a bid, not the life story. Reported from the couch.
  ref.read(gameProvider).update((s) => takeTipOnce(s, 'transfer_offer'));

  final answer = await showDialog<TransferAnswer>(
    context: context,
    barrierColor: coachCardScrim,
    // Tapping outside parks it rather than answering, which is only safe
    // because nothing is lost by doing so.
    barrierDismissible: true,
    builder: (_) => _TransferOfferCard(offer: offer),
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
  const _TransferOfferCard({required this.offer});

  final Map<String, dynamic> offer;

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
    // Who they want is in Colin's own mouth now — see the relay below — so
    // the pane keeps only the figure it exists to set beside the fee.
    final rate = incomePerSec.toStringAsFixed(2);
    final read = transferRead(state, offer, card);

    return CoachCardFrame(
      key: const ValueKey('transfer-offer'),
      title: t('transfer.card_title', {'club': offer['fromTeam'] ?? ''}),
      // Park, no, yes. Three answers stack rather than sharing a row, which is
      // the frame's own rule: at three, a row makes every label too narrow.
      actions: [
        // **THE PRICE IS THE THING BEING WEIGHED**, so it wears the coin and
        // the coin's gold rather than sitting inside a run of white text on the
        // green face — see [CoachAction.coins].
        CoachAction(
          // **`common.accept`, not `transfer.accept`.** English's own entry is
          // "Accept Offer" and every other catalogue already reads just
          // "Accept" — so the one language with two words was the outlier, on a
          // button that also carries the price. The copy cannot be edited here
          // (the catalogues are generated), so the fix is to ask for the key
          // that already says the shorter thing.
          labelKey: 'common.accept',
          tone: CoachTone.confirm,
          coins: price.round(),
          onTap: () {},
          result: TransferAnswer.accepted,
        ),
        CoachAction(
          labelKey: 'common.decline',
          tone: CoachTone.decline,
          onTap: () {},
          result: TransferAnswer.declined,
        ),
      ],
      // **Parking is not an answer**, so it is not a third button the width of
      // the two that are. It is a `−` in the corner, and tapping outside has
      // always done the same thing.
      minimisable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // **COLIN TELLS US THE PHONE HAS RUNG.** The card opened on the terms
          // — a portrait, two panes, a grey line at the foot — and read as a
          // modal announcing a bid. Asked for from the couch: it should read as
          // an offer having come in and him telling us about it, then saying
          // whether to go ahead. So the first thing on the card is his voice,
          // typed the way every card's body is, and the last is his call.
          // **AND EVERYTHING HE NEEDS TO SAY IS IN THE ONE PARAGRAPH.** The
          // card carried a portrait, a pane for what you lose and a pane for
          // the fee with its band under it, and stood as tall as the pitch.
          // Asked for from the couch: no picture, the loss in his own words,
          // and no fee plate — the price is on the Accept button. The club,
          // the man and what he earns are set heavy so they can be found at
          // a glance.
          CoachTypewriter(
            text: t('coach.bid.relay', {
              'club': offer['fromTeam'] ?? '',
              'player': name,
              'price': formatCoins(price),
              'rate': rate,
            }),
            textKey: const ValueKey('transfer-relay'),
            strong: offer['fromTeam'] as String?,
            strongs: [name, '+$rate'],
            style: TextStyle(color: kit.textMuted, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 10),
          CoachVerdictLine(
            read: read,
            textKey: const ValueKey('transfer-advice'),
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
/// The card a rival has a bid in for, or null.
final bidTargetProvider = Provider<String?>((ref) {
  final offer = ref.watch(pendingOfferProvider);
  final id = offer?['cardInstanceId'];
  return id is String && id.isNotEmpty ? id : null;
});

/// **A BID NAMES A PLAYER AND THE SQUAD PAGE DREW HIM LIKE THE OTHER
/// TWENTY-NINE.** Answering an offer meant finding the man first, on a page
/// whose whole job is that they all look the same — so the one thing on it the
/// player has been asked about was the one thing not marked.
///
/// A ring and the note's own glyph, over whatever it wraps: the pitch draws a
/// `PitchToken` and everything else draws a `PlayerCard`, and a mark that looks
/// like one thing on the pitch and another on the bench is a mark the player
/// has to learn twice — the same argument `TraitBadge` settled.
class BidTargetMark extends ConsumerWidget {
  const BidTargetMark({
    super.key,
    required this.instanceId,
    required this.child,
  });

  final String? instanceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (instanceId == null || ref.watch(bidTargetProvider) != instanceId) {
      return child;
    }
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Stack(
      key: ValueKey('bid-target-$instanceId'),
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          // Outside the child rather than over it: the card underneath is
          // already the club's colours and a wash on top would say "selected",
          // which is a thing the player did.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: kit.accentBright.withValues(alpha: 0.55),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        ),
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: kit.accentBright,
              shape: BoxShape.circle,
              border: Border.all(color: kit.surface, width: 1.5),
            ),
            child: const Text('💸', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

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
                  // A dark halo under the gold one, so the pill separates from
                  // a light page as well as from a dark one.
                  const BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: gameGold.withValues(alpha: 0.24 + 0.34 * t),
                    blurRadius: 10 + 12 * t,
                    spreadRadius: 1 + 3 * t,
                  ),
                ],
              ),
              child: child,
            );
          },
          // **GOLD, NOT THE KIT.** It was `accentBright` — the club's own
          // colour, on pages already wearing it top to bottom — so the one
          // thing on screen saying a bid is still waiting looked like part of
          // the furniture, and covering something while looking like furniture
          // reads as a bug rather than as an overlay. Reported as needing to
          // stand out. Gold is what money wears everywhere else in this game,
          // including the card this pill opens.
          // **MOULDED, because flat gold read as a banner.** The pill was a
          // single solid fill with one hairline round it — which is a label,
          // and a label is a thing you read rather than a thing you press. The
          // copy has said "tap to review" the whole time and it was still
          // reported as not obviously tappable, so the affordance has to be in
          // the SHAPE.
          //
          // Three parts, and they are the same three every [StoreButton] has:
          // a gradient down the face so it is lit from above, a hard edge
          // underneath giving it a thickness, and a chevron saying there is
          // somewhere to go. The face DROPS onto that edge on a press — see
          // `_pressed` — which is the one gesture Material's ripple cannot
          // express and the reason the ink splash is turned off.
          child: _PillFace(
            onTap: () => unawaited(showTransferOffer(context, ref)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💸', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Text(
                  t('transfer.pill_label'),
                  // 14: at 12.5 it read as the smallest type on the page.
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    // The pill's own ink: gold is a fixed colour in both
                    // themes, so what reads on it is too.
                    color: _pillInk,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 16, color: _pillInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill's ink and its two golds.
///
/// A gradient needs a lighter and a darker end and [gameGold] is one literal, so
/// the pair is derived from it rather than invented: the highlight is gold lifted
/// toward white, the shade is gold toward black, and the hard edge under the
/// face is the same shade again taken further. That way a change to `gameGold`
/// moves all four together.
const Color _pillInk = Color(0xFF20160A);
const Color _pillTop = Color(0xFFFFE985);
const Color _pillBottom = Color(0xFFE8B400);
const Color _pillEdge = Color(0xFF8A6100);

/// The moulded face of [TransferPill]. Pressed, it drops onto its own edge.
class _PillFace extends StatefulWidget {
  const _PillFace({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PillFace> createState() => _PillFaceState();
}

class _PillFaceState extends State<_PillFace> {
  bool _down = false;

  /// The thickness of the edge, and therefore how far the face travels.
  static const double _lift = 3;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const ValueKey('transfer-pill'),
        // **OPAQUE, because the face is a decoration and decorations do not hit
        // test.** The `Material` this replaced registered a hit anywhere inside
        // itself; a `Container` only does where its child happens to be, so a
        // tap that landed in the gap between the emoji and the label fell
        // straight through the one control standing between a player and a bid
        // they parked.
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          // DOWN onto the edge, and the edge shortens by the same amount, so
          // the pill's outside stays where it is — this sits in the shell above
          // the tab bar, where nothing may move.
          transform: Matrix4.translationValues(0, _down ? _lift - 1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_pillTop, gameGold, _pillBottom],
              stops: [0, 0.45, 1],
            ),
            border: Border.all(color: _pillEdge, width: 1),
            boxShadow: [
              BoxShadow(
                color: _pillEdge,
                offset: Offset(0, _down ? 1 : _lift),
                blurRadius: 0,
              ),
            ],
          ),
          child: widget.child,
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
