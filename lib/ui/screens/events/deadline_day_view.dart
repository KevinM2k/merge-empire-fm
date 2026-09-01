/// Deadline Day's trading floor. Ported from the `_renderDeadline*` half of
/// `ui/screens/EventScreen.js`.
///
/// The only screen in the game driven by a REAL clock: a listing burns a
/// five-minute fuse whether or not anyone is looking, and the window shuts on
/// the hour whatever the player is in the middle of. Three states — an intro
/// that only shows when the window refused to open, the live floor, and a
/// recap.
///
/// **What repaints, and what does not.** One ticker runs at 1Hz and it does
/// three different things on purpose:
///
/// - the clock, the fuse digits and the coin balance are TEXT, repainted every
///   tick;
/// - the feed is rebuilt only when the set of live listings actually changes,
///   because rebuilding it every second tears the buttons out from under a
///   thumb;
/// - the fuse BARS are `TweenAnimationBuilder`s spanning the whole fuse and
///   seeked into, not handed whatever is left as their duration. The JS learnt
///   this the hard way: duration-per-render snapped every bar back to full on
///   each rebuild and then drained the remainder over a shorter span, so a card
///   with forty seconds on it visibly jumped up and ran down several times too
///   fast.
///
/// The tick mutates the session DIRECTLY rather than through `game.update`.
/// It runs once a second for a whole hour, and the save debounce would simply
/// never fire; every deal and the session's start and end save explicitly.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/bar_fill.dart';
import 'package:merge_empire_fc/data/deadline_day.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/deadline_day_engine.dart';
import 'package:merge_empire_fc/engine/deal_advice_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart';
import 'package:merge_empire_fc/engine/loan_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/events/deadline_deal_sheets.dart';
import 'package:merge_empire_fc/ui/screens/events/event_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show readableInk;
import 'package:merge_empire_fc/ui/widgets/store_button.dart'
    show mouldedButtonStyle;
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Which side of the desk the feed is showing.
enum DeskSide { buy, sell }

/// The ink, fill and BUTTON FACE a listing's kind wears. Four kinds of business
/// on one board read as one undifferentiated feed without it.
///
/// **`ink` is TEXT and `face`/`edge` are a button.** The spec keeps them apart
/// (`_ddKindStyleRaw`) because they answer different questions: the ink prints
/// the card's spine and its chip straight onto the page, so it has to survive a
/// pale one; the face is a fill with white on top, which reads either way. That
/// is why only the ink goes through [readableInk] below.
typedef KindStyle = ({Color ink, Color tint, Color face, Color edge});

/// The kind's colours as the spec states them, before the theme has its say.
///
/// **The port had only `ink` and `tint`, and three of the four hues were not the
/// spec's** — loan was Material blue against the spec's purple, a loan OUT was
/// amber against teal, and a plain signing was purple against light blue. The
/// MARQUEE case was missing altogether, so the one listing on the board that is
/// meant to arrive in gold wore whatever its kind wears.
KindStyle _kindStyleRaw(Listing listing) {
  // Marquee first, and it OUTRANKS the kind: a marquee bid is still a marquee.
  if (listing['marquee'] == true) {
    return (
      ink: const Color(0xFFD8A01A),
      tint: const Color(0x29D8A01A),
      face: const Color(0xFFD8A01A),
      edge: const Color(0xFF916709),
    );
  }
  return switch (listing['kind']) {
    'bid' => (
      ink: const Color(0xFF66BB6A),
      tint: const Color(0x294CAF50),
      face: const Color(0xFF43A047),
      edge: const Color(0xFF205C23),
    ),
    'loan' => (
      ink: const Color(0xFFB07EDE),
      tint: const Color(0x2E8E5BC0),
      face: const Color(0xFF8E5BC0),
      edge: const Color(0xFF573472),
    ),
    'loanOut' => (
      ink: const Color(0xFF4DC3AE),
      tint: const Color(0x2E2B9C8A),
      face: const Color(0xFF2B9C8A),
      edge: const Color(0xFF17594E),
    ),
    _ => (
      ink: const Color(0xFF7FD4FF),
      tint: const Color(0x297FD4FF),
      face: const Color(0xFF1E88C7),
      edge: const Color(0xFF12587F),
    ),
  };
}

/// The kind's colours with the theme's say on the INK, which is the half of
/// them that is printed as text. Every one of these hues was picked against
/// near-black — `#7FD4FF` on a light card is the terms line nobody can read.
KindStyle kindStyle(BuildContext context, Listing listing) {
  final raw = _kindStyleRaw(listing);
  return (
    ink: readableInk(context, raw.ink),
    tint: raw.tint,
    face: raw.face,
    edge: raw.edge,
  );
}

String _fuseClock(int ms) {
  final total = (ms / 1000).ceil();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

String _sessionClock(int ms) {
  final total = (ms / 1000).ceil();
  return '${(total ~/ 60).toString().padLeft(2, '0')}:'
      '${(total % 60).toString().padLeft(2, '0')}';
}

class DeadlineDayView extends ConsumerStatefulWidget {
  const DeadlineDayView({required this.event, super.key});

  final EventDef event;

  @override
  ConsumerState<DeadlineDayView> createState() => _DeadlineDayViewState();
}

class _DeadlineDayViewState extends ConsumerState<DeadlineDayView> {
  Timer? _ticker;
  DeskSide _side = DeskSide.buy;

  /// What the feed was built from last. The ids alone are not enough: talking a
  /// buyer up changes the MONEY on a board whose membership is identical, so a
  /// successful haggle would repaint nothing and the card would sit there
  /// quoting the price we had just improved on.
  String _signature = '';

  /// Bumped when the feed genuinely has to be rebuilt, so `build` can be cheap
  /// on the ticks where nothing moved.
  int _feedRevision = 0;

  /// Repainted every tick — the clock, the fuse digits and the balance.
  int _clockRevision = 0;

  @override
  void initState() {
    super.initState();
    // AFTER the frame, not during it. Both of these write to the save, the save
    // bumps `saveRevisionProvider`, and Riverpod refuses a provider write while
    // the tree is building — which is what `initState` is. In release the
    // assertion is compiled out and it works; in debug the screen threw on the
    // way in, so the floor never painted and the player arrived at the intro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openWindowIfInvited();
      _resumeStrandedHolds();
      setState(() => _feedRevision++);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _state => ref.read(gameProvider).state;

  /// The window being open IS the invitation.
  ///
  /// There used to be a door to push between arriving and the feed, which is a
  /// button whose only answer is yes.
  void _openWindowIfInvited() {
    final state = _state;
    if (state == null) return;
    final window = deadlineWindow(state);
    if (window.start == 0) return;
    if (sessionStatus(state, window.start) != 'idle') return;
    ref
        .read(gameProvider)
        .update((s) => startSession(s, window.start, windowEnd: window.end));
  }

  /// A hold belongs to an open sheet, and no sheet survives a reload.
  ///
  /// Anything still held when the floor is painted is a leftover from a
  /// conversation that ended with the app being closed. Hand the time back and
  /// let it run — a listing frozen mid-haggle would sit at the top of the feed
  /// until the window shut, blocking a slot and never expiring.
  void _resumeStrandedHolds() {
    ref.read(gameProvider).update((s) {
      for (final l in liveListings(s)) {
        if (l['status'] == 'live' && isPaused(l)) {
          resumeListing(s, '${l['listingId']}');
        }
      }
    });
  }

  void _tick() {
    final state = _state;
    if (state == null || !mounted) return;
    final window = deadlineWindow(state);
    if (sessionStatus(state, window.start) != 'live') {
      _ticker?.cancel();
      // `endSession` already ran inside `tickSession`; rebuilding flips the
      // screen to the recap.
      setState(() => _feedRevision++);
      return;
    }

    // Direct, not through `game.update`: see the header.
    tickSession(state);

    final all = liveListings(state);
    final signature = all
        .map(
          (l) =>
              '${l['listingId']}:${l['price'] ?? 0}:'
              '${(l['offer'] as Map?)?['cash'] ?? 0}:${isPaused(l) ? 1 : 0}',
        )
        .join('|');

    setState(() {
      _clockRevision++;
      if (signature != _signature) {
        _signature = signature;
        _feedRevision++;
      }
    });
  }

  void _act(void Function(Map<String, dynamic> s) change) {
    ref.read(gameProvider).update(change);
    // A deal changes the board, so the feed rebuilds on the next frame rather
    // than waiting for the tick to notice.
    setState(() => _feedRevision++);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final state = _state;
    if (state == null) return const SizedBox.shrink();

    final window = deadlineWindow(state);
    final status = window.start == 0
        ? 'idle'
        : sessionStatus(state, window.start);

    if (status == 'done') {
      return DeadlineSummaryView(event: widget.event);
    }
    if (status != 'live') {
      return _DeadlineIntro(event: widget.event);
    }

    // One instant for all three reads: `liveListings` takes the clock, and
    // three separate calls could cap and split against three different ones,
    // so a listing expiring mid-build could be counted on the tab and missing
    // from the feed under it.
    final at = now();
    final all = liveListings(state, at);
    final buy = liveListingsBySide(state, 'buy', at);
    final sell = liveListingsBySide(state, 'sell', at);
    final onSide = _side == DeskSide.buy ? buy : sell;
    final missed = missedCount(state);

    return Column(
      key: const ValueKey('deadline-live'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveHead(
          remainingMs: sessionRemainingMs(state),
          colinLine: _colinLine(state, onSide, all),
          onRules: () => showDeadlineRules(context, widget.event),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                t('event.deadline.budget'),
                style: TextStyle(fontSize: 11, color: kit.textMuted),
              ),
            ),
            Text(
              key: const ValueKey('dd-coins'),
              formatCoins(ref.watch(coinsProvider)),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SideTabs(
          side: _side,
          buyCount: buy.length,
          sellCount: sell.length,
          onChanged: (s) => setState(() => _side = s),
        ),
        const SizedBox(height: 10),
        if (onSide.isEmpty)
          _QuietSide(side: _side)
        else
          for (final listing in onSide)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DeadlineListingCard(
                key: ValueKey('dd-listing-${listing['listingId']}'),
                listing: listing,
                state: state,
                clockRevision: _clockRevision,
                onPass: () =>
                    _act((s) => dismissListing(s, '${listing['listingId']}')),
                onNegotiate: () => _negotiate(listing),
                onCounter: () => _counter(listing),
                onTake: () => _take(listing),
              ),
            ),
        if (missed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              missed == 1
                  ? t('event.deadline.missed_while_away_one')
                  : t('event.deadline.missed_while_away', {'n': missed}),
              key: const ValueKey('dd-missed'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.5, color: kit.textMuted),
            ),
          ),
      ],
    );
  }

  Future<void> _negotiate(Listing listing) async {
    final result = await showDeadlineDealSheet(context, ref, listing: listing);
    if (!mounted) return;
    if (result == true) setState(() => _feedRevision++);
    // A counter is the sheet's other outcome, and it used to end at a snackbar
    // reading "They want more" with no number in it and nothing to press: the
    // engine had stamped a figure on the listing that no screen could take.
    await _counter(listing);
  }

  /// Put their counter to the manager.
  ///
  /// Offered the moment it lands and again from the card, because it is the same
  /// number both times — it stands for the rest of the fuse, so walking away
  /// from the dialog is going away to think rather than saying no.
  Future<void> _counter(Listing listing) async {
    final state = _state;
    if (state == null) return;
    final id = '${listing['listingId']}';
    final counter = sellerCounter(state, id);
    if (counter == null) return;

    final take = await showSellerCounter(context, listing, counter);
    if (!mounted) return;
    if (take != true) {
      _say(t('event.deadline.counter_walked'));
      return;
    }

    final result = ref
        .read(gameProvider)
        .update((s) => acceptSellerCounter(s, id));
    setState(() => _feedRevision++);
    if (result['ok'] == true) {
      // A signing is a card arriving, which is what the achievement sweep and
      // the quest counters listen for — the same signal the offer path sends.
      emit('merge:happened');
      _say(
        t('event.deadline.offer_accepted', {
          'name': result['playerName'] ?? listing['playerName'] ?? '',
        }),
      );
      return;
    }
    _say(switch (result['reason']) {
      'not_enough_coins' => t('toast.not_enough_coins'),
      'no_counter' => t('event.deadline.fail_no_counter'),
      _ => t('event.deadline.fail_expired'),
    });
  }

  void _say(String line) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(line)));
  }

  Future<void> _take(Listing listing) async {
    final state = _state;
    if (state == null) return;
    final confirmed = await showDeadlineConfirm(context, state, listing);
    if (confirmed != true || !mounted) return;
    _act((s) => acceptListing(s, '${listing['listingId']}'));
  }

  /// Colin's running commentary.
  ///
  /// Three clauses at most, in this order: WHAT is happening named by kind,
  /// WHAT HE THINKS, and WHY when the reason is about the squad rather than the
  /// price. He is talking over a five-minute fuse, not writing a report.
  String _colinLine(
    Map<String, dynamic> state,
    List<Listing> live,
    List<Listing> all,
  ) {
    if (live.isEmpty) {
      // Say which side is quiet. "Nothing yet" under a tab strip reads as the
      // whole window being dead when the other tab has three deals on it.
      if (all.length <= live.length) return t('event.deadline.colin_quiet');
      return t(
        _side == DeskSide.sell
            ? 'event.deadline.colin_quiet_sell'
            : 'event.deadline.colin_quiet_buy',
      );
    }

    final at = now();
    // The thing about to expire outranks the thing that just landed — that is
    // the one still losable.
    final urgentPool = [
      for (final l in live)
        if (listingRemainingMs(l, at) <= listingTtlMs * 0.25) l,
    ]..sort((a, b) => listingRemainingMs(a, at) - listingRemainingMs(b, at));
    final recent = [...live]
      ..sort(
        (a, b) => ((b['spawnAt'] as num?) ?? 0).compareTo(
          (a['spawnAt'] as num?) ?? 0,
        ),
      );
    final urgent = urgentPool.isEmpty ? null : urgentPool.first;
    final focus = urgent ?? (recent.isEmpty ? null : recent.first);
    if (focus == null) return t('event.deadline.colin_quiet');

    final kind = switch (focus['kind']) {
      'bid' => 'bid',
      'loan' => 'loan',
      'loanOut' => 'loanout',
      _ => 'sign',
    };
    final headline = t(
      'event.deadline.colin_ev_${kind}_${urgent != null ? 'soon' : 'new'}',
      {'team': focus['fromTeam'] ?? '', 'player': focus['playerName'] ?? ''},
    );

    final advice = adviseOnListing(state, focus);
    final selling = listingSide(focus) == 'sell';
    final String verdict;
    if (advice.verdict == DealVerdict.blocked) {
      final reason = advice.reasons.isEmpty
          ? 'blocked_unknown_listing'
          : advice.reasons.first.id;
      verdict = t('event.deadline.$reason');
    } else if (advice.verdict == DealVerdict.poor &&
        advice.reasons.any((r) => r.id == 'below_standard')) {
      // Price is not the objection here, so "too dear" would be the wrong one —
      // he could be free and the answer would be the same.
      verdict = t('event.deadline.colin_v_below_standard');
    } else if (advice.verdict == DealVerdict.poor) {
      verdict = t(
        selling
            ? 'event.deadline.colin_v_poor_sell'
            : 'event.deadline.colin_v_poor_buy',
      );
    } else {
      verdict = t('event.deadline.colin_v_${advice.verdict.name}');
    }

    // If he has called it too dear he owes us a figure, and on a bid we have
    // received he owes us a view on whether to push. On a bid that IS over the
    // odds he says take it and stops: pushing a club that has already overpaid
    // is how a good deal turns into no deal.
    var number = '';
    final cheeky = advice.reasons.any((r) => r.id == 'try_cheeky');
    if (advice.suggestedOffer > 0) {
      number =
          ' ${t(cheeky ? 'event.deadline.colin_cheeky' : 'event.deadline.colin_offer_instead', {'amount': formatCoins(advice.suggestedOffer)})}';
    } else if (selling &&
        advice.verdict != DealVerdict.great &&
        advice.suggestedAsk > 0) {
      number =
          ' ${t('event.deadline.colin_ask_instead', {'amount': formatCoins(advice.suggestedAsk)})}';
    }

    final squadReason = <String, String>{
      // First: it is the actionable one.
      'find_money': 'colin_r_find_money',
      'cannot_afford': 'colin_r_cannot_afford',
      // No entry for `below_standard` — the verdict line above already IS that
      // sentence, and repeating it is not a second reason.
      'needs_cover': 'colin_r_cover',
      'glut_buy': 'colin_r_glut',
      'glut_sell': 'colin_r_glut',
      'position_gap': 'colin_r_gap',
      'upgrade': 'colin_r_upgrade',
      'best_in_position': 'colin_r_best',
      'only_one': 'colin_r_only',
    };
    var note = '';
    for (final reason in advice.reasons) {
      final key = squadReason[reason.id];
      if (key == null) continue;
      final position = reason.params['position'];
      note =
          ' ${t('event.deadline.$key', position == null ? const {} : {
                  // "in attack", not "at FWD" - he is a coach, not a spreadsheet.
                  'area': t('area.$position'),
                })}';
      break;
    }

    return '$headline $verdict$number$note';
  }
}

/// The pinned head: the clock, the session bar and Colin.
///
/// Pinned OUTSIDE the feed. These are what a player is deciding against and the
/// feed is taller than the screen, so scrolling to the third listing must never
/// scroll the clock away.
class _LiveHead extends StatelessWidget {
  const _LiveHead({
    required this.remainingMs,
    required this.colinLine,
    required this.onRules,
  });

  final int remainingMs;
  final String colinLine;
  final VoidCallback onRules;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final fraction = (remainingMs / sessionMs).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '● ${t('event.deadline.live').toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: kit.accentBright,
                    ),
                  ),
                ),
                Text(
                  _sessionClock(remainingMs),
                  key: const ValueKey('dd-clock'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    key: const ValueKey('dd-rules'),
                    padding: EdgeInsets.zero,
                    tooltip: t('event.deadline.rules_btn'),
                    onPressed: onRules,
                    icon: Text(
                      '?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: kit.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: kit.border,
            valueColor: AlwaysStoppedAnimation(kit.accent),
          ),
          // Colin sits IN the head rather than above it, so the head stays put
          // and only the words change as bids come in.
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: Row(
              children: [
                // **COLIN'S FACE, not the teacher emoji.** `🧑‍🏫` was a
                // stand-in from before there was any art of him and it survived
                // into three screens, while the dock, the floating head and his
                // own card all drew the real portrait — so the same coach was a
                // photograph on one screen and a glyph on the next. Reported off
                // this one. [CoachFace] is the single crop; see
                // `coach_card.dart`.
                const CircleAvatar(
                  radius: 23,
                  child: CoachFace(fallbackSize: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    colinLine,
                    key: const ValueKey('dd-colin'),
                    // Not bold. It is a full sentence of running commentary and
                    // 700 across all of it reads as shouting rather than as
                    // emphasis — the accent LIVE label carries that. The floor
                    // is the floor, though: `uiBaseWeight`, not under it.
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: uiBaseWeight,
                      height: 1.45,
                    ),
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

/// The Buy / Sell strip.
///
/// The counts are the whole point: the tab you are NOT looking at is where a
/// deal can expire unseen, so it has to say how many are waiting on it.
class _SideTabs extends StatelessWidget {
  const _SideTabs({
    required this.side,
    required this.buyCount,
    required this.sellCount,
    required this.onChanged,
  });

  final DeskSide side;
  final int buyCount;
  final int sellCount;
  final ValueChanged<DeskSide> onChanged;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    Widget tab(DeskSide id, String label, int count) {
      final on = side == id;
      return Expanded(
        child: InkWell(
          key: ValueKey('dd-side-${id.name}'),
          onTap: () => onChanged(id),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            color: on ? kit.accent : Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: on ? kit.accentInk : kit.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: on
                        ? Colors.black.withValues(alpha: 0.22)
                        : kit.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    key: ValueKey('dd-count-${id.name}'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: on ? kit.accentInk : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kit.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          tab(DeskSide.buy, t('event.deadline.side_buy'), buyCount),
          Container(width: 1, height: 40, color: kit.border),
          tab(DeskSide.sell, t('event.deadline.side_sell'), sellCount),
        ],
      ),
    );
  }
}

class _QuietSide extends StatelessWidget {
  const _QuietSide({required this.side});

  final DeskSide side;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('dd-quiet'),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border, style: BorderStyle.solid),
      ),
      child: Text(
        t(
          side == DeskSide.sell
              ? 'event.deadline.waiting_sell'
              : 'event.deadline.waiting_buy',
        ),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: kit.textMuted),
      ),
    );
  }
}

/// One piece of business on the board.
class DeadlineListingCard extends StatelessWidget {
  const DeadlineListingCard({
    required this.listing,
    required this.state,
    required this.clockRevision,
    required this.onPass,
    required this.onNegotiate,
    required this.onTake,
    required this.onCounter,
    super.key,
  });

  final Listing listing;
  final Map<String, dynamic> state;

  /// Bumped once a second. The fuse digits read it so they repaint without the
  /// card being rebuilt from scratch.
  final int clockRevision;

  final VoidCallback onPass;
  final VoidCallback onNegotiate;
  final VoidCallback onTake;

  /// Take the figure they came back with. Null on a listing they have not
  /// countered, which is every listing until we have made them an offer.
  final VoidCallback onCounter;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final style = kindStyle(context, listing);
    final held = isPaused(listing);
    final kind = listing['kind'];
    final isBid = kind == 'bid';
    final isLoan = kind == 'loan';
    final isLoanOut = kind == 'loanOut';
    final incoming =
        (listing['offer'] as Map?)?['incoming'] as List? ?? const [];
    final blocked = listingBlockedReason(state, listing);
    final price = (listing['price'] as num?) ?? 0;

    // On a mixed bid `price` is the whole package's worth — cash PLUS what
    // their players are valued at — so putting it on the button promises coins
    // that never arrive. The button states the CASH; the terms line underneath
    // names the players coming the other way.
    final bidCash = incoming.isNotEmpty
        ? ((listing['offer'] as Map?)?['cash'] as num?) ?? 0
        : price;

    final chip = listing['marquee'] == true
        ? t('event.deadline.chip_marquee')
        : isBid
        ? t('event.deadline.chip_bid')
        : isLoan
        ? t('event.deadline.chip_loan')
        : isLoanOut
        ? t('event.deadline.chip_loan_out')
        : t('event.deadline.chip_available');

    // Once they have countered, the sticker price is not the deal any more, so
    // the primary button stops naming it. Their number stands for the rest of
    // the fuse — a card still offering the old figure would be the board
    // disagreeing with the club about what the player costs.
    final counter = sellerCounter(state, '${listing['listingId']}');

    final acceptLabel = counter != null
        ? t('event.deadline.counter_accept', {
            'amount': formatCoins(counter.cash),
          })
        : isBid
        ? t('event.deadline.accept_bid', {'amount': formatCoins(bidCash)})
        : isLoan
        ? t('event.deadline.loan_for', {'amount': formatCoins(price)})
        : isLoanOut
        ? t('event.deadline.send_out')
        : t('event.deadline.sign_for', {'amount': formatCoins(price)});

    final card = _cardFor(listing, state);
    final def = card == null ? null : getPlayerDef(card.definitionId);
    final stats = card == null || def == null
        ? null
        : getCardStats(card, definitionRatios: _ratios(state));
    final traitId = (card?.raw['trait'] as Map?)?['id'];
    final trait = traitId is String && traitId != 'none'
        ? traits[traitId]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Chip.ofKind(label: chip, style: style),
                    if (listing['listedTarget'] == true) ...[
                      const SizedBox(width: 6),
                      _Chip(
                        label: t('event.deadline.chip_listed'),
                        ink: const Color(0xFFFFB74D),
                        tint: const Color(0x29FFB74D),
                      ),
                    ],
                    if (held) ...[
                      const SizedBox(width: 6),
                      _Chip(
                        label: t('event.deadline.chip_held'),
                        ink: const Color(0xFF90CAF9),
                        tint: const Color(0x2E42A5F5),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${listing['fromTeam'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: kit.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${listing['playerName'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (stats != null) ...[
                                const SizedBox(width: 6),
                                // ★ sits WITH THE NAME. It is a fact about the
                                // player, so it belongs to the player; stacked
                                // under the money it read as part of the money.
                                Text(
                                  '★${stats.rating.round()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (price > 0)
                                Text(
                                  // Their number once they have named one: a
                                  // headline still reading the asking price
                                  // beside a button offering a different figure
                                  // is the board disagreeing with the club about
                                  // what the player costs.
                                  formatCoins(
                                    counter?.price ?? (isBid ? bidCash : price),
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: isBid ? style.ink : null,
                                  ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 6),
                            child: Text(
                              '${listing['tierName'] ?? ''} · '
                              '${listing['position'] ?? ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: kit.textMuted,
                              ),
                            ),
                          ),
                          if (stats != null)
                            Row(
                              children: [
                                Text(
                                  'ATK ${stats.attack.round()}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'DEF ${stats.defence.round()}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          if (trait != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                // Through the catalogue — the record's `name`
                                // is an English literal. See `trait_copy.dart`.
                                '⚡ ${traitName(trait)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFCE93D8),
                                ),
                              ),
                            ),
                          if (_terms(listing) case final terms?)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                terms,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: style.ink,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (blocked != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t('event.deadline.blocked_$blocked'),
                      key: ValueKey('dd-blocked-${listing['listingId']}'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF5350),
                      ),
                    ),
                  )
                // Says WHY the button has changed its figure. In the card's own
                // ink rather than the blocked line's red: they have not refused
                // us, they have named a price.
                else if (counter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t('event.deadline.counter_title'),
                      key: ValueKey('dd-counter-${listing['listingId']}'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: style.ink,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('dd-pass-${listing['listingId']}'),
                        onPressed: onPass,
                        child: Text(
                          isBid
                              ? t('event.deadline.reject')
                              : t('event.deadline.pass'),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                    if (isBid || isLoan || kind == 'signing') ...[
                      const SizedBox(width: 7),
                      Expanded(
                        flex: 11,
                        child: OutlinedButton(
                          key: ValueKey('dd-negotiate-${listing['listingId']}'),
                          onPressed: onNegotiate,
                          // **Through the moulded helper, not `styleFrom`.**
                          // `side` is drawn by the button's own Material, on
                          // the FULL button rect — but the moulded face sits 4pt
                          // inside it, so a `side` here put a second outline
                          // 4pt above the first: a ridge along the top of the
                          // button, reported as a weird 3D edge. The helper's
                          // `edge` is the border the builder itself draws.
                          style: mouldedButtonStyle(
                            face: Colors.transparent,
                            edge: style.ink,
                            ink: style.ink,
                            dead: kit.surface2,
                            deadInk: kit.textMuted,
                            border: kit.border,
                            outline: true,
                          ),
                          child: Text(
                            isBid
                                ? t('event.deadline.ask_more')
                                : t('event.deadline.make_offer'),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 7),
                    Expanded(
                      flex: 14,
                      child: ElevatedButton(
                        key: ValueKey('dd-take-${listing['listingId']}'),
                        onPressed: blocked != null
                            ? null
                            : counter != null
                            ? onCounter
                            : onTake,
                        // **`backgroundColor` NEVER REACHED THE FACE.** The
                        // moulded style paints the face in a
                        // `backgroundBuilder` and leaves the Material behind it
                        // transparent, so this coloured the layer UNDER the
                        // face: every accept button on the board came out the
                        // theme's accent green whatever deal it belonged to,
                        // and the fill it did apply covered the hard bottom
                        // edge that makes the button look pressable at all.
                        // The spec passes `--btn-face`/`--btn-edge` to the same
                        // shared button, which is what these two are.
                        style: mouldedButtonStyle(
                          face: style.face,
                          edge: style.edge,
                          // A fill with white on top, both themes — the spec's
                          // note on why only the ink needs the light treatment.
                          ink: Colors.white,
                          dead: kit.surface2,
                          deadInk: kit.textMuted,
                          border: kit.border,
                        ),
                        child: Text(
                          acceptLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Fuse(
            listing: listing,
            style: style,
            held: held,
            clockRevision: clockRevision,
          ),
        ],
      ),
    );
  }

  /// A wage "per match" was invisible money — it left the balance in a lump
  /// between screens. It is a per-second drain on the income rate now, so the
  /// card quotes the RATE: the same figure the squad and multiplier screens
  /// show, and the one the income bar visibly slows by.
  String? _terms(Listing l) {
    final matches = (l['matches'] as num?)?.toInt() ?? 1;
    if (l['kind'] == 'loan') {
      return t('event.deadline.loan_terms', {
        'matches': matches,
        'wage': '-${formatRate(loanWageRateFor(state, l['definitionId']))}',
      });
    }
    if (l['kind'] == 'loanOut') {
      // The whole spell is settled the moment they leave, so quote the lump.
      final fee = math.max(
        1,
        (((l['feePerMatch'] as num?) ?? 0) * matches).round(),
      );
      return t('event.deadline.loan_out_terms', {
        'matches': matches,
        'fee': formatCoins(fee),
      });
    }
    final incoming = (l['offer'] as Map?)?['incoming'] as List? ?? const [];
    // The cash is already the headline figure — repeating it here read as a
    // second, different number. This line only carries what the headline
    // cannot: that players are coming the other way too.
    if (incoming.isNotEmpty) {
      return t('event.deadline.plus_players', {'n': incoming.length});
    }
    return null;
  }
}

Map<String, dynamic> _ratios(Map<String, dynamic> state) {
  final r = state['definitionRatios'];
  return r is Map<String, dynamic> ? r : const <String, dynamic>{};
}

/// The card a listing concerns — ours for a bid, theirs for a signing.
CardInstance? _cardFor(Listing l, Map<String, dynamic> state) {
  if (l['kind'] == 'signing' || l['kind'] == 'loan') {
    return CardInstance.from(l['card']);
  }
  return findOurCard(state, l['cardInstanceId']);
}

/// A chip takes an INK AND A TINT, not a [KindStyle]: it has no button on it, so
/// borrowing the kind's record meant the two chips that are not a kind — LISTED
/// and HELD — had to invent a face and an edge for a button they do not draw.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.ink, required this.tint});

  /// The kind's own colours, for the chip that names the kind. [KindStyle.ink]
  /// has already been through [readableInk] and running it twice is a no-op —
  /// the clamp is a minimum, so a colour already at or under it does not move.
  _Chip.ofKind({required String label, required KindStyle style})
    : this(label: label, ink: style.ink, tint: style.tint);

  final String label;
  final Color ink;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
        // Both of these are printed straight onto the card, so they take the
        // same light-mode treatment the kind's ink does.
        color: readableInk(context, ink),
      ),
    ),
  );
}

/// The fuse, along the bottom edge.
///
/// A hairline above the chips was the most important thing on the card rendered
/// as the least visible — it is the reason any of this is urgent — so it runs
/// the full width and carries the digits.
///
/// The bar animates over the WHOLE fuse and is seeked into, never handed the
/// remainder as its duration: see the header for what that costs.
class _Fuse extends StatelessWidget {
  const _Fuse({
    required this.listing,
    required this.style,
    required this.held,
    required this.clockRevision,
  });

  final Listing listing;
  final KindStyle style;
  final bool held;
  final int clockRevision;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final remaining = listingRemainingMs(listing);
    final fraction = (remaining / listingTtlMs).clamp(0.0, 1.0);

    return SizedBox(
      height: 16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: kit.border),
          Align(
            alignment: Alignment.centerLeft,
            child: held
                // Held: no animation, and the bar sits at whatever fraction was
                // left when the talking started. An animated bar on a stopped
                // clock says the opposite of what is true.
                ? BarFill(
                    fraction: fraction,
                    child: ColoredBox(color: style.ink),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: fraction, end: 0),
                    duration: Duration(milliseconds: math.max(0, remaining)),
                    builder: (_, value, _) => BarFill(
                      fraction: value,
                      child: ColoredBox(color: style.ink),
                    ),
                  ),
          ),
          Center(
            child: Text(
              _fuseClock(remaining),
              key: ValueKey('dd-fuse-${listing['listingId']}-$clockRevision'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// The safety net, not a doorway.
///
/// The floor opens the window itself, so the only way here is a window that
/// refused to start — in practice one that shut between the build and the call.
/// No "open the window" button: there is nothing for the player to do but wait,
/// and offering a button that can only fail is worse than saying so.
class _DeadlineIntro extends StatelessWidget {
  const _DeadlineIntro({required this.event});

  final EventDef event;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('deadline-intro'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(13, 15, 13, 13),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            children: [
              const Text('📰', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 6),
              Text(
                t('event.deadline.intro_body', deadlineRuleParams(event)),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: kit.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('dd-rules-intro'),
          onPressed: () => showDeadlineRules(context, event),
          child: Text(t('event.deadline.rules_btn')),
        ),
      ],
    );
  }
}

/// `mins` and `fuse`, which every rules line is written against.
Map<String, Object?> deadlineRuleParams(EventDef? event) {
  final trigger = event?.trigger;
  return {
    'mins': trigger is AnnualWindowTrigger
        ? trigger.durationMinutes
        : (sessionMs / 60000).round(),
    'fuse': math.max(1, (listingTtlMs / 60000).round()),
  };
}

/// When the doors open, in the player's own clock format.
String? deadlineOpenTimeLabel(EventDef? event) {
  final trigger = event?.trigger;
  if (trigger is! AnnualWindowTrigger) return null;
  final hour = trigger.startHour;
  if (hour == null) return null;
  return formatTimeOfDay(DateTime(2000, 1, 1, hour));
}

/// The rules, on demand.
///
/// They used to be printed down the intro screen, which only worked while there
/// WAS one — the window opens on its own now, so they live behind the ? on the
/// live board and inline on the closed screen.
Future<void> showDeadlineRules(BuildContext context, EventDef event) {
  final params = deadlineRuleParams(event);
  final openAt = deadlineOpenTimeLabel(event);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('dd-rules-sheet'),
      title: Text(t('event.deadline.intro_title')),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('event.deadline.intro_body', params)),
            const SizedBox(height: 10),
            for (final line in [
              t('event.deadline.rule_clock'),
              t('event.deadline.rule_fuse', params),
              t('event.deadline.rule_world'),
              openAt == null
                  ? t('event.deadline.rule_once')
                  : t('event.deadline.rule_nightly', {
                      'time': openAt,
                      'mins': params['mins'],
                    }),
            ])
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(line, style: const TextStyle(fontSize: 12.5)),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(t('event.deadline.rules_got_it')),
        ),
      ],
    ),
  );
}
