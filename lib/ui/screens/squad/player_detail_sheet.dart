/// One player, in full. Ported from `_openDetail` in
/// `ui/screens/SquadScreen.js`.
///
/// The screen's centre of gravity: everything you can do to a single player is
/// here, and it is the only route to most of it. A tap on the pitch or the
/// bench opens it.
///
/// **What is on it depends on whose player they are**, and the three cases are
/// genuinely different rather than one layout with fields greyed out:
///
/// - **Ours, here.** Market value, a Sell with its own confirm, and the trait
///   wheel.
/// - **Ours, out on loan.** No sell — selling a player another club currently
///   holds is fiction — and no trait work, because rolling one costs real
///   currency on somebody who cannot take the field. Recall is the way home,
///   and it costs a grudge.
/// - **Theirs, on loan to us.** No market value, no sell, no traits: a trait
///   would go back with them at the end of the spell. Sending them back early
///   is the only lever.
///
/// The sell price is rolled ONCE, when the sheet opens, and the sale takes that
/// same number — the same rule `sell_sheet.dart` follows, and for the same
/// reason: rolling again on confirm pays out something other than the figure
/// the player just agreed to.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/loan_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/sell_card_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// What the sheet offers to do with this player, once it closes.
enum PlayerDetailAction {
  /// Out of the eleven. Only offered for a man who is in it.
  bench,

  /// Replace him — reopens the picker for his slot.
  swap,

  /// Into the eleven, from the bench.
  ///
  /// `squad.detail.send_on` is translated in all ten catalogues and had nothing
  /// able to reach it, in the JS or the port — the tell that a control went
  /// missing rather than was never wanted. Without it the bench is a dead end:
  /// it is a SHEET, so there is nothing to drag a card onto, and the only way
  /// into the side was to find an empty slot on the pitch and come at it from
  /// the other direction.
  sendOn,
}

/// Find a card by instance id, or null once it has left.
CardInstance? cardById(Map<String, dynamic>? state, String instanceId) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return null;
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card != null && card.instanceId == instanceId) return card;
  }
  return null;
}

/// Open the sheet.
///
/// Returns what the player asked for next — bench them, send them on, or swap
/// the slot — or null when they simply closed it. The caller owns all three
/// because they are changes to the LINEUP, and the lineup is the screen's
/// business.
Future<PlayerDetailAction?> showPlayerDetail(
  BuildContext context,
  WidgetRef ref, {
  required String instanceId,

  /// The slot they were tapped in, or null on the bench. Its presence is what
  /// decides whether the XI row is offered at all.
  String? slotId,
}) {
  final game = ref.read(gameProvider);
  final state = game.state;
  final card = cardById(state, instanceId);
  if (card == null) return Future.value(null);

  // Rolled here, ONCE — the sheet quotes this figure and the sale takes it.
  // Rolling again on confirm would pay out something other than what the player
  // just agreed to.
  final mult = rollMarketMult(card);
  final offer = (mult: mult, price: sellPriceAt(state, instanceId, mult));

  return showBottomSheetPopup<PlayerDetailAction>(
    context,
    heightFraction: 0.92,
    child: _PlayerDetail(instanceId: instanceId, slotId: slotId, offer: offer),
  );
}

class _PlayerDetail extends ConsumerWidget {
  const _PlayerDetail({
    required this.instanceId,
    required this.slotId,
    required this.offer,
  });

  final String instanceId;
  final String? slotId;
  final ({double mult, int price}) offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(saveRevisionProvider);
    final kit = Theme.of(context).extension<KitTheme>()!;
    final game = ref.read(gameProvider);
    final state = game.state;
    final card = cardById(state, instanceId);
    final def = getPlayerDef(card?.definitionId);
    if (card == null || def == null) return const SizedBox.shrink();

    final onLoanToUs = isLoan(card);
    final outOnLoan = isLoanedOut(card);
    final proMode = state != null && isProMode(state);

    return ListView(
      key: ValueKey('player-detail-$instanceId'),
      padding: const EdgeInsets.all(16),
      children: [
        _Header(
          card: card,
          def: def,
          onLoanToUs: onLoanToUs,
          outOnLoan: outOnLoan,
        ),
        const SizedBox(height: 12),

        // Replace and Bench are both about a SLOT, so they only appear for a
        // man who is in the eleven. From the bench the one thing wanted is the
        // opposite, and it is a single button.
        if (!outOnLoan) ...[
          if (slotId != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('detail-swap'),
                    onPressed: () =>
                        Navigator.of(context).pop(PlayerDetailAction.swap),
                    child: Text('⇄  ${t('squad.detail.replace')}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('detail-bench'),
                    onPressed: () =>
                        Navigator.of(context).pop(PlayerDetailAction.bench),
                    child: Text('↩  ${t('squad.detail.to_bench')}'),
                  ),
                ),
              ],
            )
          // Nobody unavailable can be sent on: the match engine rates a loaned
          // or listed player zero, so putting one in the side fields a hole.
          else if (card.isSelectable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('detail-send-on'),
                onPressed: () =>
                    Navigator.of(context).pop(PlayerDetailAction.sendOn),
                child: Text('⇡  ${t('squad.detail.send_on')}'),
              ),
            ),
          const SizedBox(height: 12),
        ],

        _Attributes(card: card, def: def),
        if (proMode) ...[const SizedBox(height: 10), _Fitness(card: card)],
        _CareerStats(card: card, def: def),

        if (_map(card.sponsor) case final sponsor?) ...[
          const SizedBox(height: 10),
          _SponsorLine(sponsor: sponsor),
        ],

        const SizedBox(height: 10),
        if (onLoanToUs)
          _LoaneeBlock(
            card: card,
            onSendBack: () => _sendBack(context, ref, card),
          )
        else ...[
          _MarketBlock(
            card: card,
            def: def,
            offer: offer,
            blocked: sellBlocked(state, instanceId),
            onSell: () => _sell(context, ref, card, def),
          ),
          if (outOnLoan) ...[
            const SizedBox(height: 10),
            _RecallBlock(
              card: card,
              onRecall: () => _recall(context, ref, card),
            ),
          ],
        ],
        const SizedBox(height: 10),
        // The trait block, which is the third thing this sheet is FOR and was
        // missing entirely: `rollTrait`, `applyTrait` and `traitRollCost` were
        // all ported with nothing able to spend a coin on them.
        //
        // Whose player they are decides what it says. A loanee's trait would go
        // back with them; one out on loan cannot take the field, so the roll
        // would buy nothing this season.
        if (onLoanToUs)
          Text(
            t('squad.detail.no_traits_on_loan'),
            key: const ValueKey('detail-trait-loanee'),
            style: TextStyle(fontSize: 11, color: kit.textMuted),
          )
        else if (outOnLoan)
          Text(
            t('squad.detail.no_traits_while_away', {
              'name': card.name(),
              'team': '${_map(card.loanedOut)?['toTeam'] ?? ''}',
            }),
            key: const ValueKey('detail-trait-away'),
            style: TextStyle(fontSize: 11, color: kit.textMuted),
          )
        else
          TraitBlock(instanceId: instanceId, def: def),
      ],
    );
  }

  /// **LETTING A PLAYER GO IS A DECISION, SO IT IS COLIN'S CARD.**
  ///
  /// All three of these were `AlertDialog`s — the app's own voice asking about
  /// the squad, on a screen whose whole premise is that you have a manager to
  /// talk to. The rule this port already keeps everywhere else is that every
  /// decision comes through him, with the answers COLOURED so the shape of the
  /// question is readable before the words are.
  ///
  /// It is irreversible and the button sits under the thumb at the bottom of a
  /// scrolling sheet, so nothing leaves the squad without being asked.
  Future<void> _sell(
    BuildContext context,
    WidgetRef ref,
    CardInstance card,
    PlayerDef def,
  ) async {
    final confirmed = await showCoachCard<bool>(
      context,
      titleKey: 'sell.title',
      bodyKey: 'sell.receive',
      bodyParams: {'name': card.name(def.name)},
      body: '${t('sell.receive')}: ${formatCoins(offer.price)}',
      // What the sale COSTS, in its own right: the bonuses go with him, and
      // burying that inside the offer is how somebody agrees to something they
      // did not read.
      extraLines: [(key: 'sell.lose_bonuses', params: const {}, strong: false)],
      actions: [
        CoachAction(
          labelKey: 'common.cancel',
          tone: CoachTone.decline,
          onTap: () {},
        ),
        CoachAction(
          labelKey: 'common.sell',
          tone: CoachTone.confirm,
          onTap: () {},
          result: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    ref
        .read(gameProvider)
        .update((s) => sellCard(s, card.instanceId, offer.mult));
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Sending a loanee back early leaves the club that lent them a season short
  /// of what they planned, so it is asked rather than done.
  Future<void> _sendBack(
    BuildContext context,
    WidgetRef ref,
    CardInstance card,
  ) async {
    final team =
        card.raw['loanFrom'] as String? ?? t('squad.detail.another_club');
    final confirmed = await showCoachCard<bool>(
      context,
      titleKey: 'squad.detail.send_back',
      bodyKey: 'squad.detail.send_back_confirm',
      bodyParams: {'name': card.name(), 'team': team},
      actions: [
        CoachAction(
          labelKey: 'common.cancel',
          tone: CoachTone.decline,
          onTap: () {},
        ),
        CoachAction(
          labelKey: 'squad.detail.send_back',
          tone: CoachTone.confirm,
          onTap: () {},
          result: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(gameProvider).update((s) => sendLoaneeBack(s, card.instanceId));
    if (context.mounted) Navigator.of(context).pop();
  }

  /// The same question from the other end, and it costs the same thing.
  Future<void> _recall(
    BuildContext context,
    WidgetRef ref,
    CardInstance card,
  ) async {
    final team = _map(card.loanedOut)?['toTeam'] as String? ?? '';
    final confirmed = await showCoachCard<bool>(
      context,
      titleKey: 'squad.detail.recall_loan',
      bodyKey: 'squad.detail.recall_confirm',
      bodyParams: {'name': card.name(), 'team': team},
      actions: [
        CoachAction(
          labelKey: 'common.cancel',
          tone: CoachTone.decline,
          onTap: () {},
        ),
        CoachAction(
          labelKey: 'squad.detail.recall_loan',
          tone: CoachTone.confirm,
          onTap: () {},
          result: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(gameProvider).update((s) => recallLoan(s, card.instanceId));
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// The photo, the headline numbers and the name.
class _Header extends StatelessWidget {
  const _Header({
    required this.card,
    required this.def,
    required this.onLoanToUs,
    required this.outOnLoan,
  });

  final CardInstance card;
  final PlayerDef def;
  final bool onLoanToUs;
  final bool outOnLoan;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rating = getCardRating(def, ratingBonus: card.ratingBonus);
    final seasons = card.seasonsPlayed;
    final gamesLeft = _num(card.raw['loanMatchesLeft']).toInt();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: ArtImage(
              path: playerImagePath(def.position, def.tier, card.variant),
              // `cover`, aligned to the top: this is a portrait crop, and
              // centring it cuts the head off.
              fit: BoxFit.cover,
              dimmed: card.injured,
              fallback: PlayerPortrait(
                variantIndex: card.variant,
                kitColor: kit.accent,
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$rating',
                    key: const ValueKey('detail-rating'),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    t('squad.stat.rating').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFFD8D8D8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // A loanee arrives fresh, so their seasons count is always
                  // zero — a stat with one possible value is a dead slot. What
                  // actually runs down on a loan is the GAMES, so that takes
                  // its place.
                  Text(
                    '${onLoanToUs ? gamesLeft : seasons}',
                    key: const ValueKey('detail-seasons'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: onLoanToUs
                          ? const Color(0xFF7FE3D9)
                          : Colors.white,
                    ),
                  ),
                  Text(
                    t(
                      onLoanToUs
                          ? 'squad.stat.games_left'
                          : 'squad.stat.seasons',
                    ).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Color(0xFFD8D8D8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (onLoanToUs || outOnLoan)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF26A69A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t(
                              onLoanToUs
                                  ? 'squad.detail.loaned_badge'
                                  : 'squad.detail.away_badge',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          card.name(def.name),
                          key: const ValueKey('detail-name'),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${tName('player.tier', '${def.tier}')} · '
                    '${t('pos.${def.position}')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE0E0E0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rating, income and injury risk.
class _Attributes extends StatelessWidget {
  const _Attributes({required this.card, required this.def});

  final CardInstance card;
  final PlayerDef def;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final sponsorMult = _num(_map(card.sponsor)?['multiplier']);
    final income = def.idleIncomePerSec * (sponsorMult > 0 ? sponsorMult : 1);

    return Container(
      key: const ValueKey('detail-attributes'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        children: [
          _StatRow(
            label: t('squad.detail.rating'),
            value: '${getCardRating(def, ratingBonus: card.ratingBonus)}',
          ),
          _StatRow(
            label: t('squad.detail.income'),
            value: '+${income.toStringAsFixed(2)}/s',
          ),
          _StatRow(
            label: t('squad.detail.seasons'),
            value: '${card.seasonsPlayed}',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: kit.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Per-player fitness. PRO MODE ONLY — casual play has team energy pips, and a
/// bar pinned at full for every casual player is a number that never moves.
class _Fitness extends StatelessWidget {
  const _Fitness({required this.card});

  final CardInstance card;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final fraction = energyPct(card).clamp(0.0, 1.0);
    final pct = (fraction * 100).round();
    final colour = fraction < 0.34
        ? const Color(0xFFEF5350)
        : fraction < 0.67
        ? const Color(0xFFFFB74D)
        : const Color(0xFF66BB6A);

    return Column(
      key: const ValueKey('detail-fitness'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t('squad.fitness.label').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: kit.textMuted,
                ),
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: colour,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: kit.border,
            valueColor: AlwaysStoppedAnimation(colour),
          ),
        ),
      ],
    );
  }
}

/// What they have actually done. Only shown once they have played.
class _CareerStats extends StatelessWidget {
  const _CareerStats({required this.card, required this.def});

  final CardInstance card;
  final PlayerDef def;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final stats = _map(card.raw['stats']);
    final played = _num(stats?['matchesPlayed']).toInt();
    if (played == 0) return const SizedBox.shrink();

    final goals = _num(stats?['goals']).toInt();
    final tackles = _num(stats?['tackles']).toInt();
    final saves = _num(stats?['saves']).toInt();
    final position = def.position;

    // Which columns show is by POSITION, not by whether the number is non-zero:
    // a striker on nought goals is information, and hiding it would read as the
    // stat not existing.
    final cells = <({String label, int value, bool highlight})>[
      (label: t('squad.stat.played'), value: played, highlight: false),
      if (goals > 0 || position == 'FWD' || position == 'MID')
        (
          label: '⚽ ${t('squad.stat.goals')}',
          value: goals,
          highlight: goals > 0,
        ),
      if (tackles > 0 || position == 'DEF' || position == 'MID')
        (
          label: '🛡️ ${t('squad.stat.tackles')}',
          value: tackles,
          highlight: false,
        ),
      if (position == 'GK')
        (label: '🧤 ${t('squad.stat.saves')}', value: saves, highlight: true),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        key: const ValueKey('detail-career-stats'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kit.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kit.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('squad.career_stats').toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: kit.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final cell in cells)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(
                            cell.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: kit.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cell.value}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cell.highlight ? kit.accentBright : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorLine extends StatelessWidget {
  const _SponsorLine({required this.sponsor});

  final Map<String, dynamic> sponsor;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('detail-sponsor'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x1AFFD700),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x4DFFD700)),
    ),
    child: Text(
      t('squad.detail.sponsor_line', {
        'name': sponsor['name'] ?? '',
        'mult': _num(sponsor['multiplier']).toStringAsFixed(2),
      }),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFD700),
      ),
    ),
  );
}

/// Market value and Sell — ours, and here.
class _MarketBlock extends StatelessWidget {
  const _MarketBlock({
    required this.card,
    required this.def,
    required this.offer,
    required this.blocked,
    required this.onSell,
  });

  final CardInstance card;
  final PlayerDef def;
  final ({double mult, int price}) offer;
  final String? blocked;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final outOnLoan = isLoanedOut(card);
    final team = _map(card.loanedOut)?['toTeam'] as String? ?? '';

    return Container(
      key: const ValueKey('detail-market'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('squad.detail.market_value').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: kit.textMuted,
                  ),
                ),
              ),
              Text(
                formatCoins(offer.price),
                key: const ValueKey('detail-price'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            key: const ValueKey('detail-sell'),
            onPressed: blocked == null ? onSell : null,
            child: Text(t('common.sell')),
          ),
          if (blocked != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                outOnLoan
                    ? t('squad.detail.cannot_sell_out_on_loan', {
                        'team': team,
                        'name': card.name(def.name),
                      })
                    : t('squad.detail.cannot_sell_last', {
                        'n': minSquadPlayers,
                      }),
                key: const ValueKey('detail-sell-blocked'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: kit.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Theirs, on loan to us. The only lever is sending them back.
class _LoaneeBlock extends StatelessWidget {
  const _LoaneeBlock({required this.card, required this.onSendBack});

  final CardInstance card;
  final VoidCallback onSendBack;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final left = _num(card.raw['loanMatchesLeft']).toInt();
    final total = _num(card.raw['loanTotalMatches'] ?? left).toInt();

    return Container(
      key: const ValueKey('detail-loanee'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${t('squad.detail.on_loan_from_label')} ',
                  style: TextStyle(color: kit.textMuted),
                ),
                TextSpan(
                  text:
                      card.raw['loanFrom'] as String? ??
                      t('squad.detail.another_club'),
                  style: const TextStyle(color: Color(0xFF26A69A)),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('squad.detail.loan_games_left', {'n': left, 'total': total}),
            style: TextStyle(fontSize: 11.5, color: kit.textMuted),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey('detail-sendback'),
            onPressed: onSendBack,
            child: Text(t('squad.detail.send_back')),
          ),
        ],
      ),
    );
  }
}

/// Ours, at another club. Recall is the way home, and it costs a grudge.
class _RecallBlock extends StatelessWidget {
  const _RecallBlock({required this.card, required this.onRecall});

  final CardInstance card;
  final VoidCallback onRecall;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final loan = _map(card.loanedOut);
    final team = loan?['toTeam'] as String? ?? '';

    return Container(
      key: const ValueKey('detail-recall-block'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '✈️ ${t('squad.detail.on_loan_at', {'team': team, 'matches': _num(loan?['matchesLeft']).toInt()})}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF26A69A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('squad.detail.recall_warning', {'team': team}),
            style: TextStyle(fontSize: 10.5, height: 1.5, color: kit.textMuted),
          ),
          const SizedBox(height: 9),
          OutlinedButton(
            key: const ValueKey('detail-recall'),
            onPressed: onRecall,
            child: Text(t('squad.detail.recall_loan')),
          ),
        ],
      ),
    );
  }
}

/// The trait wheel. Ported from `mountTraitRoulette` in
/// `ui/components/TraitRoulette.js`.
///
/// The JS builds two reels out of DOM strips — a column of names and a column of
/// levels — repeated seven times so a spin can run past them, with a pull lever
/// at the side. **Flutter has that widget**: `ListWheelScrollView` with a looping
/// delegate IS a reel, and a `FixedExtentScrollController` can be told to land on
/// an item over a duration and a curve. So the spin here is three revolutions and
/// a stop, with no clock and no repeated strips.
///
/// The outcome is decided and PAID before the reel moves — a spin that decided at
/// the end would have to be unwound when the debit turned out to be refused.
///
/// **The cost is on the control**, because a roll is a gamble with the player's
/// coins and "how much was that?" must not be a question they ask afterwards.
class TraitBlock extends ConsumerStatefulWidget {
  const TraitBlock({super.key, required this.instanceId, required this.def});

  final String instanceId;
  final PlayerDef def;

  @override
  ConsumerState<TraitBlock> createState() => TraitBlockState();
}

class TraitBlockState extends ConsumerState<TraitBlock> {
  /// How long the reels run. The JS spins for about this long before it settles.
  static const Duration spin = Duration(milliseconds: 900);

  /// How many times round before it lands. Enough to read as a spin rather than
  /// a jump, and the looping delegate is what makes it free.
  static const int _revolutions = 3;

  /// Row height, and the reel shows three rows: the one either side is what
  /// makes it a wheel rather than a label.
  static const double _rowHeight = 26;

  final FixedExtentScrollController _names = FixedExtentScrollController();
  final FixedExtentScrollController _levels = FixedExtentScrollController();

  bool _spinning = false;

  /// Test seam.
  bool get spinning => _spinning;

  @override
  void dispose() {
    _names.dispose();
    _levels.dispose();
    super.dispose();
  }

  Future<void> _roll(List<Trait> pool) async {
    if (_spinning) return;
    final result = ref
        .read(gameProvider)
        .update((s) => rollTraitForCard(s, widget.instanceId));
    final roll = result.roll;
    if (!result.ok || roll == null) return;

    final landing = pool.indexWhere((t) => t.id == roll.id);
    if (landing < 0) return;
    setState(() => _spinning = true);

    // Both reels animate at once; the level lands a beat later, which is the
    // order the player reads them in.
    await Future.wait([
      _names.animateToItem(
        pool.length * _revolutions + landing,
        duration: spin,
        curve: Curves.easeOutCubic,
      ),
      _levels.animateToItem(
        3 * _revolutions + (roll.level - 1).clamp(0, 2),
        duration: spin + const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      ),
    ]);
    if (mounted) setState(() => _spinning = false);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final card = cardById(ref.watch(gameProvider).state, widget.instanceId);
    final cost = traitRollCost(widget.def);
    final coins = ref.watch(coinsProvider);
    final pool = getTraitPoolForPosition(
      widget.def.position,
      hardMode: ref.watch(proModeProvider),
    );
    final trait = _map(card?.raw['trait']);

    return Container(
      key: const ValueKey('detail-trait'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('squad.trait').toUpperCase(),
            style: TextStyle(
              color: kit.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          // What he has, in words, above the reels — the reels are the SPIN and
          // this is the answer, and a player who has not rolled anything yet
          // needs to be told which of the two they are looking at.
          Text(
            trait == null ? t('trait.name.none') : traitLabel(trait),
            key: const ValueKey('detail-trait-label'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: trait == null ? kit.textMuted : kit.accentBright,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _rowHeight * 3,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _Reel(
                    reelKey: 'trait-reel-name',
                    controller: _names,
                    rowHeight: _rowHeight,
                    children: [
                      for (final trait in pool)
                        Text(
                          '${trait.icon} ${trait.name}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Reel(
                    reelKey: 'trait-reel-level',
                    controller: _levels,
                    rowHeight: _rowHeight,
                    children: const [
                      Text('I', textAlign: TextAlign.center),
                      Text('II', textAlign: TextAlign.center),
                      Text('III', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            key: const ValueKey('detail-trait-roll'),
            onPressed: _spinning || coins < cost ? null : () => _roll(pool),
            child: Text(t('game.trait.cost', {'cost': formatCoins(cost)})),
          ),
          if (coins < cost)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t('game.trait.need_coins', {'cost': formatCoins(cost)}),
                key: const ValueKey('detail-trait-blocked'),
                style: TextStyle(fontSize: 11, color: kit.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One reel.
///
/// Looping, so a spin can run several times round a pool of fifteen without the
/// JS's trick of repeating the strip seven times in the markup. The middle row is
/// the one that counts, which is what the highlight marks.
class _Reel extends StatelessWidget {
  const _Reel({
    required this.reelKey,
    required this.controller,
    required this.rowHeight,
    required this.children,
  });

  final String reelKey;
  final FixedExtentScrollController controller;
  final double rowHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kit.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kit.border),
      ),
      child: ListWheelScrollView.useDelegate(
        key: ValueKey(reelKey),
        controller: controller,
        itemExtent: rowHeight,
        // A reel the player cannot flick: the roll is bought, not spun by hand.
        physics: const NeverScrollableScrollPhysics(),
        perspective: 0.004,
        diameterRatio: 1.6,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (final child in children)
              Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: kit.accentBright),
                  child: child,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
