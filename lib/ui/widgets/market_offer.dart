/// The live sell quote for one card, and the clock it runs on.
///
/// The market is a CLOCK, not a slot machine. One roll stands for
/// [marketWindow]: reopening the sheet inside that window quotes the same
/// figure, and when it runs out the price moves under a player who is still
/// looking at it — which is what "time your sale" has been promising.
///
/// Both sheets that quote a player use this one, so the Players tab and the
/// Squad tab can never disagree about what he is worth.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/sell_card_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';

/// What the builder is handed: the standing offer and the seconds left on it.
typedef LiveOffer = ({double mult, int price, int secsLeft});

class MarketOffer extends ConsumerStatefulWidget {
  const MarketOffer({
    super.key,
    required this.instanceId,
    required this.builder,
  });

  final String instanceId;
  final Widget Function(BuildContext context, LiveOffer offer) builder;

  @override
  ConsumerState<MarketOffer> createState() => _MarketOfferState();
}

class _MarketOfferState extends ConsumerState<MarketOffer> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // A second, as in the JS: between rerolls the countdown is the only thing
    // moving.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(saveRevisionProvider);
    final state = ref.read(gameProvider).state;
    final quote = marketQuote(state, widget.instanceId);
    final secs = quote.refreshAt.difference(DateTime.now()).inMilliseconds;
    return widget.builder(context, (
      mult: quote.mult,
      price: quote.price,
      secsLeft: secs <= 0 ? 0 : (secs / 1000).ceil(),
    ));
  }
}
