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
/// **It is the third stated exception to `SheetHeader`.** The title is the
/// player's name written across his own portrait, which is the source's design
/// and a header the artwork is part of; a bar above it would say his name twice
/// and push the picture down to do it. The other two are Coach Colin's card and
/// the achievement banner.
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
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/player_name_card.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';
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

    // **`getCardStats`, not `getCardRating`.** The latter is the DEFINITION's
    // rating plus a merge bonus and knows nothing about traits, aging, form or
    // sponsor — so the one number a trait roll is bought to move was the one
    // number that could not move. This is the documented single source of truth,
    // and it folds the trait's directional bonus back into the overall.
    final stats = getCardStats(
      card,
      definitionRatios: _map(state?['definitionRatios']) ?? const {},
    );

    return ListView(
      key: ValueKey('player-detail-$instanceId'),
      padding: const EdgeInsets.all(16),
      children: [
        // **HE RUNS BEHIND THE BUTTONS.** The portrait was a 200px crop with
        // the controls stacked underneath it, which spent the top third of the
        // sheet on a head-and-shoulders of a figure drawn full length. The
        // artwork gets the room now and Replace/Bench float on its lower edge,
        // over a scrim so they stay readable against whatever he is wearing.
        Stack(
          children: [
            _Header(
              card: card,
              def: def,
              stats: stats,
              onLoanToUs: onLoanToUs,
              outOnLoan: outOnLoan,
              actionsBelow: !outOnLoan,
            ),
            // Replace and Bench are both about a SLOT, so they only appear for
            // a man who is in the eleven. From the bench the one thing wanted
            // is the opposite, and it is a single button.
            if (!outOnLoan)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _SlotActions(
                  slotId: slotId,
                  selectable: card.isSelectable,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        _Attributes(card: card, def: def, stats: stats),
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
    required this.stats,
    required this.onLoanToUs,
    required this.outOnLoan,
    required this.actionsBelow,
  });

  final CardInstance card;
  final PlayerDef def;
  final CardStats stats;
  final bool onLoanToUs;
  final bool outOnLoan;

  /// Whether Replace/Bench/Send On is floating over the artwork's lower edge.
  ///
  /// They share that edge with the name bar, and the buttons are drawn after
  /// it — so without this the pencil at the end of the name sat UNDER the Bench
  /// button and could not be tapped at all. The name bar lifts to clear them.
  final bool actionsBelow;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rating = stats.rating;
    final seasons = card.seasonsPlayed;
    final gamesLeft = _num(card.raw['loanMatchesLeft']).toInt();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            // **260, not 200.** The artwork is a full-length figure and 200 was
            // a head-and-shoulders crop of it; the extra sixty is where the
            // buttons now float, so it costs the sheet nothing.
            height: 260,
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
              padding: EdgeInsets.fromLTRB(14, 24, 14, actionsBelow ? 58 : 10),
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
                      // **Not offered on a loan, either direction.** Renaming
                      // somebody else's player is not ours to do, and renaming
                      // one of ours who is away puts a name on a card the
                      // player cannot see. The JS draws the same line.
                      if (!onLoanToUs && !outOnLoan) ...[
                        const SizedBox(width: 8),
                        _RenameButton(instanceId: card.instanceId),
                      ],
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

/// The pencil beside the name.
///
/// A round, dark, blurred-edge affordance over the artwork rather than a text
/// button, because it sits on the player's own kit — which is the club's
/// colour, and on half the kits in the game a coloured button on a shirt is the
/// same colour twice.
class _RenameButton extends StatelessWidget {
  const _RenameButton({required this.instanceId});

  final String instanceId;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: t('rename.title'),
    child: InkWell(
      key: const ValueKey('detail-rename'),
      customBorder: const CircleBorder(),
      onTap: () => showPlayerNameCard(context, instanceId: instanceId),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.42),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text('✏️', style: TextStyle(fontSize: 14, height: 1)),
      ),
    ),
  );
}

/// Rating, income and injury risk.
/// Replace / Bench, or Send On — floated over the bottom of the portrait.
///
/// **Over a scrim, not on the bare artwork.** The player's kit is the club's
/// colour and so is the button, so on half the kits in the game a Replace button
/// on a shirt was the same green on green.
class _SlotActions extends StatelessWidget {
  const _SlotActions({required this.slotId, required this.selectable});

  final String? slotId;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final Widget row;
    if (slotId != null) {
      row = Row(
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
            child: FilledButton.tonal(
              key: const ValueKey('detail-bench'),
              onPressed: () =>
                  Navigator.of(context).pop(PlayerDetailAction.bench),
              child: Text('↩  ${t('squad.detail.to_bench')}'),
            ),
          ),
        ],
      );
    } else if (selectable) {
      // Nobody unavailable can be sent on: the match engine rates a loaned or
      // listed player zero, so putting one in the side fields a hole.
      row = SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const ValueKey('detail-send-on'),
          onPressed: () => Navigator.of(context).pop(PlayerDetailAction.sendOn),
          child: Text('⇡  ${t('squad.detail.send_on')}'),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x8A000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
        child: row,
      ),
    );
  }
}

class _Attributes extends StatelessWidget {
  const _Attributes({
    required this.card,
    required this.def,
    required this.stats,
  });

  final CardInstance card;
  final PlayerDef def;
  final CardStats stats;

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
          _StatRow(label: t('squad.detail.rating'), value: '${stats.rating}'),
          // **ATK and DEF, because that is where a trait LANDS.** The bonuses are
          // directional and get folded back into the overall, so on the rating
          // alone a Finisher III reads as three points from nowhere. These are
          // the two numbers it actually moved.
          //
          // Not through `t()`, and that is the port rather than an oversight:
          // the source hardcodes these two abbreviations everywhere it shows
          // them (`SquadScreen.js:372`, `Card.js:34`) and has no key for either.
          _StatRow(label: 'ATK', value: '${stats.attack}'),
          _StatRow(label: 'DEF', value: '${stats.defence}'),
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
  });

  final CardInstance card;
  final PlayerDef def;
  final ({double mult, int price}) offer;
  final String? blocked;

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
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  // Through the helpers, so the money on this sheet is the same
                  // money as everywhere else — see `coinFigureInk`.
                  color: coinFigureInk(context),
                  shadows: coinFigureShadows(context),
                ),
              ),
            ],
          ),
          // **NO SELL BUTTON.** There were two sale flows for one card — this
          // one and the Players tab's own sheet, which is the one a tap on a card
          // opens and the one that shows him full length. Two buttons that take
          // the same money differently is a bug waiting to be found; one of them
          // had to go, and the sheet the player reaches by tapping the thing they
          // want to sell is the one that stays.
          //
          // The market VALUE stays, because it is information: what he is worth
          // belongs on the sheet about him whether or not you can sell him here.
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
  /// How long the reels run.
  ///
  /// **Nine hundred milliseconds was a flick, not a spin.** A roll is bought
  /// with coins and it is the only gamble on the screen; the wheel has to turn
  /// long enough to be worth having watched. The ease-out does the rest — most
  /// of the travel goes early, so a longer spin reads as slowing down rather
  /// than as waiting.
  static const Duration spin = Duration(milliseconds: 1900);

  /// How many times round before it lands. Enough to read as a spin rather than
  /// a jump, and the looping delegate is what makes it free.
  static const int _revolutions = 5;

  /// Row height, and the reel shows three rows: the one either side is what
  /// makes it a wheel rather than a label.
  static const double _rowHeight = 26;

  final FixedExtentScrollController _names = FixedExtentScrollController();
  final FixedExtentScrollController _levels = FixedExtentScrollController();

  bool _spinning = false;

  /// What he had when the spin started, shown for as long as it runs.
  ///
  /// **The outcome is written to the save BEFORE the reels move** — deliberately,
  /// because a spin that decided at the end would have to be unwound when the
  /// debit was refused. But the badge above the reels reads the save, so the
  /// answer was printed over a wheel still pretending to decide it. This is the
  /// old trait, held back so the reveal has something to reveal.
  ///
  /// `null` is not "he had nothing": [_holding] says whether this is in force at
  /// all, because "nothing" is exactly what most first rolls start from.
  Map<String, dynamic>? _heldBefore;
  bool _holding = false;

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
    // Read BEFORE the write, or there is nothing left to hold.
    final was = _map(
      cardById(ref.read(gameProvider).state, widget.instanceId)?.raw['trait'],
    );
    final result = ref
        .read(gameProvider)
        .update((s) => rollTraitForCard(s, widget.instanceId));
    final roll = result.roll;
    if (!result.ok || roll == null) return;

    final landing = pool.indexWhere((t) => t.id == roll.id);
    if (landing < 0) return;
    setState(() {
      _spinning = true;
      _heldBefore = was;
      _holding = true;
    });

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
    if (mounted) {
      setState(() {
        _spinning = false;
        _holding = false;
        _heldBefore = null;
      });
    }
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
    // Mid-spin this is what he had, not what he just won — see [_heldBefore].
    final trait = _holding ? _heldBefore : _map(card?.raw['trait']);

    final held = getTrait(trait?['id'] as String?);

    return Container(
      key: const ValueKey('detail-trait'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        // **A TRAIT IS A POSSESSION, SO THE BLOCK LOOKS LIKE ONE.** It was a
        // grey box with a grey heading and a line of text, sitting under a
        // portrait and a set of stats — the most interesting thing on the sheet
        // drawn as the least. A card that HAS one wears the accent on its
        // border and a tint behind it; one that does not stays quiet, which is
        // what makes the difference legible at a glance.
        border: Border.all(
          color: held == null ? kit.border : kit.accent,
          width: held == null ? 1 : 1.6,
        ),
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
          // What he has, above the reels — the reels are the SPIN and this is
          // the ANSWER, and a player who has not rolled anything yet needs to be
          // told which of the two they are looking at.
          if (held == null)
            Text(
              t('trait.name.none'),
              key: const ValueKey('detail-trait-label'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: kit.textMuted,
              ),
            )
          else
            _TraitBadge(trait: held, instance: trait!),
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
                          '${trait.icon} ${traitName(trait)}',
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

/// The trait a card is actually carrying, drawn as a thing he HAS.
///
/// Its glyph big enough to read, its name and level beside it, and — the part
/// that was missing entirely — **what it DOES**. A player looking at "Finisher
/// II" has been told a name and nothing else; the sentence under it is the
/// reason to have spent the coins.
class _TraitBadge extends StatelessWidget {
  const _TraitBadge({required this.trait, required this.instance});

  final Trait trait;
  final Map<String, dynamic> instance;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      key: const ValueKey('detail-trait-label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The glyph on its own disc, so it reads as a badge rather than as an
        // emoji that happens to start the line.
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kit.accent.withValues(alpha: 0.18),
            border: Border.all(color: kit.accent.withValues(alpha: 0.5)),
          ),
          child: Text(trait.icon, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Through the CATALOGUE. The record's `name` is an English
                // literal — see `trait_copy.dart`.
                traitTitle(instance),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: kit.accentBright,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                traitDesc(trait),
                key: const ValueKey('detail-trait-desc'),
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: kit.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
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
