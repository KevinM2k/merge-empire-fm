/// Doing the deal — the confirm, the negotiation and the recap. Ported from the
/// sheet half of `ui/screens/EventScreen.js`.
///
/// **The clock stops for the whole conversation**, not just for the instant the
/// offer lands: picking swap players and working a cash slider IS making an
/// offer, and a fuse that burnt down while the sheet was open would take the
/// deal away mid-sentence. It starts again when the sheet closes — unless we
/// are handing straight over to the counter sheet, which is still the same
/// conversation.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/deadline_day_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// "Are you sure?" — the last gate before money moves.
///
/// Every branch names the PLAYER and the FIGURE. A confirm that says only "are
/// you sure?" is a dialog the player learns to dismiss without reading, which
/// is worse than no confirm at all.
Future<bool?> showDeadlineConfirm(
  BuildContext context,
  Map<String, dynamic> state,
  Listing listing,
) {
  final name = '${listing['playerName'] ?? ''}';
  final price = _num(listing['price']);
  final matches = _num(listing['matches']).toInt();
  final incoming = (listing['offer'] as Map?)?['incoming'] as List? ?? const [];

  final String body = switch (listing['kind']) {
    'bid' when incoming.isNotEmpty => t('event.deadline.confirm_sell_swap', {
      'name': name,
      'amount': formatCoins(_num((listing['offer'] as Map?)?['cash'])),
      'n': incoming.length,
    }),
    'bid' => t('event.deadline.confirm_sell', {
      'name': name,
      'amount': formatCoins(price),
    }),
    'loan' => t('event.deadline.confirm_loan', {
      'name': name,
      'amount': formatCoins(price),
      'matches': matches,
    }),
    'loanOut' => t('event.deadline.confirm_loan_out', {
      'name': name,
      'matches': matches,
      'fee': formatCoins(
        math.max(1, (_num(listing['feePerMatch']) * matches).round()),
      ),
    }),
    _ => t('event.deadline.confirm_sign', {
      'name': name,
      'amount': formatCoins(price),
    }),
  };

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('dd-confirm'),
      title: Text(t('event.deadline.confirm_title')),
      content: Text(body),
      actions: [
        TextButton(
          key: const ValueKey('dd-confirm-no'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t('common.cancel')),
        ),
        ElevatedButton(
          key: const ValueKey('dd-confirm-yes'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t('event.deadline.confirm_yes')),
        ),
      ],
    ),
  );
}

/// The negotiation sheet. Returns true when the board changed.
///
/// Two shapes behind one door, because they are the same conversation from
/// opposite sides: on a BID we are asking a buyer for more, and on a signing or
/// a loan we are making them an offer.
Future<bool?> showDeadlineDealSheet(
  BuildContext context,
  WidgetRef ref, {
  required Listing listing,
}) async {
  final game = ref.read(gameProvider);
  final listingId = '${listing['listingId']}';
  game.update((s) => pauseListing(s, listingId));

  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NegotiateSheet(listingId: listingId),
  );

  // Resume unless the deal is gone — a listing that was accepted, withdrawn or
  // expired has no clock left to hand back.
  game.update((s) => resumeListing(s, listingId));
  return changed;
}

class _NegotiateSheet extends ConsumerStatefulWidget {
  const _NegotiateSheet({required this.listingId});

  final String listingId;

  @override
  ConsumerState<_NegotiateSheet> createState() => _NegotiateSheetState();
}

class _NegotiateSheetState extends ConsumerState<_NegotiateSheet> {
  final Set<String> _selected = {};
  num? _cash;

  Listing? get _listing {
    final state = ref.read(gameProvider).state;
    if (state == null) return null;
    for (final l in liveListings(state)) {
      if ('${l['listingId']}' == widget.listingId) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = ref.read(gameProvider).state;
    final listing = _listing;
    if (state == null || listing == null) {
      return const SizedBox.shrink();
    }

    final isBid = listing['kind'] == 'bid';
    final isLoan = listing['kind'] == 'loan';
    final price = _num(listing['price']);
    final wallet = _num(_map(state['resources'])?['fanCoins']);

    // Buying: the wallet is a hard ceiling. `submitOffer` refuses any cash we do
    // not hold before it even asks the seller, so letting the slider reach past
    // it only buys the player a rejection they could have been shown.
    final askCap = (price * 1.25).round();
    final cashCap = isBid
        ? (_num(listing['askAnchor'] ?? listing['price']) * 2.15).round()
        : math.min(askCap, wallet.round());
    // Selling: the floor is what they have ALREADY offered. Asking a buyer for
    // less than his own bid is not a negotiation.
    final floor = isBid ? price.round() : 0;
    final cash =
        (_cash ??
                (isBid
                    ? (price * 1.2).round()
                    : math.min(price.round(), cashCap)))
            .clamp(floor, math.max(floor, cashCap));

    // Our sellable players, best first — the pool for a swap.
    //
    // SIGNINGS ONLY. A loan used to offer this too, which was a straight trap:
    // the players we put in are surrendered permanently while the loanee goes
    // home after their spell, so you could give a real player away for good to
    // rent one for ten games and finish a man down. A loan is a fee and a wage.
    // Cash only.
    final swapPool = isBid || isLoan
        ? const <CardInstance>[]
        : _swapPool(state);

    final swapValue = _selected.fold<num>(
      0,
      (sum, id) => sum + playerValue(state, findOurCard(state, id)),
    );
    final total = cash + swapValue;
    final shortOfAsking = !isBid && wallet < price;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('dd-negotiate-sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isBid
                    ? t('event.deadline.ask_more_title')
                    : t('event.deadline.offer_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isBid
                    ? t('event.deadline.ask_more_body', {
                        'team': listing['fromTeam'] ?? '',
                        'name': listing['playerName'] ?? '',
                        'amount': formatCoins(price),
                      })
                    : t('event.deadline.offer_body', {
                        'name': listing['playerName'] ?? '',
                        'amount': formatCoins(price),
                      }),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: kit.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: kit.surface2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isBid
                                ? t('event.deadline.your_ask')
                                : t('event.deadline.cash_offer'),
                            style: TextStyle(
                              fontSize: 11,
                              color: kit.textMuted,
                            ),
                          ),
                        ),
                        Text(
                          formatCoins(cash),
                          key: const ValueKey('dd-neg-cash'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      key: const ValueKey('dd-neg-slider'),
                      value: cash.toDouble(),
                      min: floor.toDouble(),
                      // A zero-width range would throw; a deal with no room to
                      // move still has to render.
                      max: math.max(floor + 1, cashCap).toDouble(),
                      onChanged: (v) => setState(() => _cash = v.round()),
                    ),
                  ],
                ),
              ),
              if (swapPool.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  t('event.deadline.add_players').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: kit.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                // Three across, not four. At a quarter of the sheet each tile
                // was about 70px and the value under it was unreadable.
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 1.5,
                  children: [
                    for (final card in swapPool)
                      _SwapTile(
                        card: card,
                        state: state,
                        selected: _selected.contains(card.instanceId),
                        onTap: () => setState(() {
                          if (!_selected.remove(card.instanceId)) {
                            _selected.add(card.instanceId);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kit.surface2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('event.deadline.total_offer'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          formatCoins(total),
                          key: const ValueKey('dd-neg-total'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            // Coloured by whether we can PAY it, which is our
                            // business. Each seller's floor is hidden and their
                            // own, so there is no number to show against.
                            color: isBid || total <= wallet + swapValue
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ),
                    if (!isBid)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          t('event.deadline.offer_unknown'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: kit.textMuted,
                          ),
                        ),
                      ),
                    if (shortOfAsking)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t('event.deadline.wallet_caps', {
                            'amount': formatCoins(wallet),
                          }),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF5350),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('dd-neg-cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      key: const ValueKey('dd-neg-send'),
                      onPressed: () => _send(listing, isBid, cash),
                      child: Text(
                        isBid
                            ? t('event.deadline.send_ask')
                            : t('event.deadline.send_offer'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<CardInstance> _swapPool(Map<String, dynamic> state) {
    final pool = <({CardInstance card, num value})>[];
    for (final card in usableCards(state)) {
      if (card.raw['loanMatchesLeft'] != null || card.injured) continue;
      if (getPlayerDef(card.definitionId) == null) continue;
      pool.add((card: card, value: playerValue(state, card)));
    }
    pool.sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in pool.take(12)) e.card];
  }

  void _send(Listing listing, bool isBid, num cash) {
    final game = ref.read(gameProvider);
    final DealResult result;
    if (isBid) {
      result = game.update((s) => askForMore(s, widget.listingId, cash))!;
    } else {
      result = game.update(
        (s) => submitOffer(s, widget.listingId, <String, dynamic>{
          'cash': cash,
          'players': _selected.toList(),
        }),
      )!;
      // A signing is a card arriving, which is what the achievement sweep and
      // the quest counters listen for.
      if (result['ok'] == true) emit('merge:happened');
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    _reportOutcome(listing, isBid, result);
  }

  /// What the other club said, as Colin.
  ///
  /// A flat rejection is the one that used to read as nothing happening at all:
  /// the toast went by and the card sat there looking unchanged.
  void _reportOutcome(Listing listing, bool isBid, DealResult result) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final team = '${listing['fromTeam'] ?? ''}';
    final name = '${listing['playerName'] ?? ''}';

    final String line;
    if (result['ok'] != true) {
      line = switch (result['reason']) {
        // "We pushed it too far" — the club has walked, and the listing dies
        // with it rather than being refused.
        'withdrawn' => t('event.deadline.pulled_out_body', {
          'team': team,
          'name': name,
        }),
        // A flat no. This is the one that used to read as nothing happening at
        // all: the toast went by and the card sat there looking unchanged.
        'rejected' => t('event.deadline.fail_rejected'),
        'counter' => t('event.deadline.counter_title'),
        'not_enough_coins' => t('toast.not_enough_coins'),
        _ => t('event.deadline.fail_expired'),
      };
    } else if (isBid) {
      final outcome = '${result['outcome']}';
      if (outcome == 'withdrawn') {
        line = t('event.deadline.pulled_out_body', {
          'team': team,
          'name': name,
        });
      } else {
        // Quote the CASH, not the package. `price` is what the whole deal is
        // worth — cash plus whatever their players are valued at — and the
        // card's headline states the cash, so reporting the package here names
        // a figure the board then contradicts. Colin has to agree with the
        // button.
        final incoming =
            (listing['offer'] as Map?)?['incoming'] as List? ?? const [];
        final settled = incoming.isNotEmpty
            ? _num((listing['offer'] as Map?)?['cash'])
            : _num(result['price']);
        line = t('event.deadline.ask_$outcome', {
          'amount': formatCoins(settled),
          'team': team,
        });
      }
    } else {
      line = t('event.deadline.offer_accepted', {
        'name': result['playerName'] ?? name,
      });
    }

    messenger.showSnackBar(SnackBar(content: Text(line)));
  }
}

class _SwapTile extends StatelessWidget {
  const _SwapTile({
    required this.card,
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final CardInstance card;
  final Map<String, dynamic> state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final def = getPlayerDef(card.definitionId);
    final ratios = state['definitionRatios'];
    final stats = getCardStats(
      card,
      definitionRatios: ratios is Map<String, dynamic>
          ? ratios
          : const <String, dynamic>{},
    );

    return GestureDetector(
      key: ValueKey('dd-swap-${card.instanceId}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? kit.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? kit.accent : kit.border,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.name(def?.tierName ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Selection is a RING and the dimming is on the ART only: both
              // states leave the FIGURES at full contrast, which is the only
              // way the comparison colours mean anything.
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              formatCoins(playerValue(state, card)),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            Text(
              '★${stats.rating.round()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The recap, once the doors have shut.
class DeadlineSummaryView extends ConsumerWidget {
  const DeadlineSummaryView({required this.event, super.key});

  final EventDef event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = ref.read(gameProvider).state;
    final summary = state == null
        ? null
        : _map(_map(ensureDeadlineDay(state)['session'])?['summary']);

    return Column(
      key: const ValueKey('deadline-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 12),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            children: [
              const Text('🔒', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                t('event.deadline.shut_body'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: kit.textMuted),
              ),
              if (summary != null) ...[
                const SizedBox(height: 12),
                DeadlineLedger(summary: summary),
              ],
            ],
          ),
        ),
        if (state != null) DeadlineHistory(state: state, skipCurrent: true),
      ],
    );
  }
}

/// One evening's business, as a table.
class DeadlineLedger extends StatelessWidget {
  const DeadlineLedger({required this.summary, super.key});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final net = _num(summary['net']);
    final offers = _map(summary['offers']);
    final wageBill = _num(summary['wageBill']);
    final loanOuts = _num(summary['loanOuts']);

    Widget row(String label, String value, {Color? colour}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: kit.textMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: colour,
            ),
          ),
        ],
      ),
    );

    return Column(
      key: const ValueKey('dd-ledger'),
      children: [
        if (offers != null) ...[
          row(
            t('event.deadline.sum_off_signings'),
            '${_num(offers['signing']).toInt()}',
          ),
          row(
            t('event.deadline.sum_off_bids'),
            '${_num(offers['bid']).toInt()}',
          ),
          row(
            t('event.deadline.sum_off_loans'),
            '${_num(offers['loan']).toInt()}',
          ),
          if (_num(offers['loanOut']) > 0)
            row(
              t('event.deadline.sum_off_loanouts'),
              '${_num(offers['loanOut']).toInt()}',
            ),
        ],
        row(
          t('event.deadline.sum_signings'),
          '${_num(summary['signings']).toInt()}',
        ),
        row(t('event.deadline.sum_loans'), '${_num(summary['loans']).toInt()}'),
        row(t('event.deadline.sum_sales'), '${_num(summary['sales']).toInt()}'),
        if (loanOuts > 0)
          row(t('event.deadline.sum_loanouts'), '${loanOuts.toInt()}'),
        if (wageBill > 0)
          row(
            t('event.deadline.sum_wages'),
            '${formatCoins(wageBill)}${t('event.deadline.per_match_suffix')}',
          ),
        row(t('event.deadline.sum_spend'), formatCoins(_num(summary['spend']))),
        row(
          t('event.deadline.sum_income'),
          formatCoins(_num(summary['income'])),
        ),
        row(
          t('event.deadline.sum_net'),
          '${net >= 0 ? '+' : ''}${formatCoins(net)}',
          colour: net >= 0 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
        ),
        row(
          t('event.deadline.sum_missed'),
          '${_num(summary['missed']).toInt()}',
        ),
      ],
    );
  }
}

/// The last few windows. Three of them — this is a footnote, not an archive.
class DeadlineHistory extends StatelessWidget {
  const DeadlineHistory({
    required this.state,
    this.skipCurrent = false,
    super.key,
  });

  final Map<String, dynamic> state;
  final bool skipCurrent;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final raw = ensureDeadlineDay(state)['history'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();
    final entries = raw
        .skip(skipCurrent ? 1 : 0)
        .take(3)
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('dd-history'),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('event.deadline.past_windows').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kit.accentBright,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDate(
                        (_num(
                          entry['windowStart'] ?? entry['endedAt'],
                        )).toInt(),
                      ),
                      style: TextStyle(fontSize: 12, color: kit.textMuted),
                    ),
                  ),
                  Text(
                    t('event.deadline.hist_line', {
                      'signings': _num(entry['signings']).toInt(),
                      'sales': _num(entry['sales']).toInt(),
                    }),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
