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
/// The market value is a standing offer on a clock — see `market_offer.dart`.
/// It was rolled fresh on every open, so closing and reopening the sheet shopped
/// for a better price; now it holds for its window and moves while you watch.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/traits.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart'
    show cardRed, suspendedIn;
import 'package:merge_empire_fc/engine/idle_engine.dart'
    show injuryMinutesLeft;
import 'package:merge_empire_fc/engine/squad_state_engine.dart'
    show ageBadgeIsUrgent, ageBadgeKeyFor;
import 'package:merge_empire_fc/ui/widgets/injury_cross.dart';
import 'package:merge_empire_fc/engine/loan_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/data/divisions.dart' show divisions;
import 'package:merge_empire_fc/engine/goal_model.dart' show getInjuryChance;
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart'
    show formGlyph, formInk;
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/card_glyph.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/player_name_card.dart';
import 'package:merge_empire_fc/ui/popups/feature_unlock.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';
import 'package:merge_empire_fc/ui/screens/squad/detail_controls.dart';
import 'package:merge_empire_fc/ui/screens/squad/match_trait_block.dart';
import 'package:merge_empire_fc/ui/screens/squad/trait_reel.dart';
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

  return showBottomSheetPopup<PlayerDetailAction>(
    context,
    heightFraction: 0.92,
    child: _PlayerDetail(instanceId: instanceId, slotId: slotId),
  );
}

/// What the sheet is SHOWING while a trait roll is in flight.
///
/// A box rather than a bare map, and that is the whole of it: `trait` being null
/// means he had NOTHING before the reels moved, which is what most first rolls
/// start from — so a bare null would have to mean both "he had none" and "no
/// roll is running", and the second reading is the one that would win.
typedef TraitHold = ({Map<String, dynamic>? trait});

/// [card] as he was before the reels started turning.
///
/// A COPY of the map, never written back: the save's key order is pinned against
/// the fixture, and this exists for a second and a half so a spin has something
/// left to reveal.
CardInstance _asHeld(CardInstance card, TraitHold hold) {
  final raw = Map<String, dynamic>.of(card.raw);
  if (hold.trait == null) {
    raw.remove('trait');
  } else {
    raw['trait'] = hold.trait;
  }
  return CardInstance(raw);
}

/// **ONE GAP BETWEEN THE CARDS, and it is this one.**
///
/// The sheet ran 12 under the hero and 10 between everything else, except round
/// the Pro-mode fitness bar where two of them stacked into 20. Four different
/// seams on a page of four cards is read as unfinished before a word on it is.
const double detailGap = 12;

class _PlayerDetail extends ConsumerStatefulWidget {
  const _PlayerDetail({required this.instanceId, required this.slotId});

  final String instanceId;
  final String? slotId;

  @override
  ConsumerState<_PlayerDetail> createState() => _PlayerDetailState();
}

class _PlayerDetailState extends ConsumerState<_PlayerDetail> {
  /// **THE WHOLE SHEET HOLDS, not just the badge over the reels.**
  ///
  /// The roll writes the save BEFORE the wheel moves — deliberately, because a
  /// spin that decided at the end would have to be unwound when the debit was
  /// refused — and every number on this sheet reads the save. So holding the
  /// trait's NAME back fixed half of it and left the rating, ATK and DEF
  /// announcing the answer over a wheel still pretending to decide it.
  ///
  /// It lives here rather than in [TraitBlock] because it is a fact about what
  /// the SHEET is showing, and two answers to that would be exactly the drift
  /// the badge already had.
  TraitHold? _hold;

  @override
  Widget build(BuildContext context) {
    final instanceId = widget.instanceId;
    final slotId = widget.slotId;
    ref.watch(saveRevisionProvider);
    final kit = Theme.of(context).extension<KitTheme>()!;
    final game = ref.read(gameProvider);
    final state = game.state;
    final saved = cardById(state, instanceId);
    final def = getPlayerDef(saved?.definitionId);
    if (saved == null || def == null) return const SizedBox.shrink();
    // Everything on the sheet is drawn from the man he is being SHOWN as, which
    // is the man he was until the reels stop.
    final hold = _hold;
    final card = hold == null ? saved : _asHeld(saved, hold);

    final onLoanToUs = isLoan(card);
    final outOnLoan = isLoanedOut(card);
    final proMode = state != null && isProMode(state);
    final suspended = suspendedIn(state).contains(instanceId);

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
              suspended: suspended,
              injuryMinsLeft: injuryMinutesLeft(state, card),
              divisionIndex: divisions
                  .indexWhere(
                    (d) =>
                        d.id == _map(state?['progression'])?['currentDivision'],
                  )
                  .clamp(0, divisions.length - 1),
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
                  // **A BANNED MAN CANNOT BE SENT ON.** Reported from the
                  // couch: the button was live, it put him on the pitch, and
                  // the squad rating went UP — he is scored zero, so the side
                  // it fielded was worse than the one it read.
                  selectable: card.isSelectable && !suspended,
                ),
              ),
          ],
        ),
        const SizedBox(height: detailGap),

        if (proMode) ...[_Fitness(card: card), const SizedBox(height: detailGap)],
        // **THE TRAIT COMES BEFORE CAREER STATS**, which is a reordering asked
        // for directly and is right for the same reason the block wears the
        // accent: it is the one thing on this sheet a player can CHANGE, and
        // the only place on it they can spend a coin. Career stats are a record
        // of what has happened; the trait is what happens next.
        // Whose player they are decides what it says. A loanee's trait would go
        // back with them; one out on loan cannot take the field, so the roll
        // would buy nothing this season.
        if (onLoanToUs)
          Text(
            t('squad.detail.no_traits_on_loan'),
            key: const ValueKey('detail-trait-loanee'),
            style: TextStyle(fontSize: 12, color: kit.textMuted),
          )
        else if (outOnLoan)
          Text(
            t('squad.detail.no_traits_while_away', {
              'name': card.name(),
              'team': '${_map(card.loanedOut)?['toTeam'] ?? ''}',
            }),
            key: const ValueKey('detail-trait-away'),
            style: TextStyle(fontSize: 12, color: kit.textMuted),
          )
        else ...[
          TraitBlock(
            instanceId: instanceId,
            def: def,
            hold: hold,
            onHold: (h) => setState(() => _hold = h),
          ),
          const SizedBox(height: detailGap),
          // The second slot: gem-gated, match-only. Same reel, its own block.
          MatchTraitBlock(instanceId: instanceId, def: def),
        ],
        const SizedBox(height: detailGap),
        _CareerStats(card: card, def: def),

        if (_map(card.sponsor) case final sponsor?) ...[
          const SizedBox(height: detailGap),
          _SponsorLine(sponsor: sponsor),
        ],

        const SizedBox(height: detailGap),
        // **NO MARKET VALUE BOX.** Selling is not on this sheet, so a price with
        // no button under it is a figure the player cannot act on — it belongs
        // with the Sell, on the Players tab's own sheet.
        if (onLoanToUs)
          _LoaneeBlock(
            card: card,
            onSendBack: () => _sendBack(context, ref, card),
          )
        else if (outOnLoan)
          _RecallBlock(card: card, onRecall: () => _recall(context, ref, card)),
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

/// A `squad.badge.*` string without the emoji the catalogue opens it with.
///
/// **Every one of the eight leads with one** — 🚑, 💀, ⚠️, 📉, 📅 — because
/// they were written for a DOM, and the port's rule is that emoji come out of
/// generated copy at the draw site. One helper rather than a `replaceFirst`
/// chain per badge: there are five different glyphs across the set and a badge
/// that grows a sixth would silently print it.
///
/// Anything outside the emoji block is left alone, so a language whose badge
/// opens on a letter is untouched.
String stripBadgeEmoji(String label) {
  final out = StringBuffer();
  var leading = true;
  for (final rune in label.runes) {
    // The pictographic blocks the catalogues actually use, plus the variation
    // selector that follows ⚠ and the zero-width joiner sequences can carry.
    final glyph =
        (rune >= 0x1F300 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        rune == 0xFE0F ||
        rune == 0x200D;
    if (leading && (glyph || rune == 0x20)) continue;
    leading = false;
    out.writeCharCode(rune);
  }
  return out.toString().trim();
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
    required this.divisionIndex,
    required this.suspended,
    required this.injuryMinsLeft,
  });

  final CardInstance card;
  final PlayerDef def;
  final CardStats stats;

  /// Higher leagues are more physical — see [getInjuryChance].
  final int divisionIndex;
  final bool onLoanToUs;
  final bool outOnLoan;

  /// Banned from the next fixture.
  final bool suspended;

  /// Whole minutes until he is fit, 0 when he is fit or due within the minute.
  final int injuryMinsLeft;

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
    // The league's own physicality, less whatever the card's trait takes back
    // off it — see the note on the `INJ` row.
    final ageBadge = ageBadgeKeyFor(card.seasonsPlayed);
    final injuryPct =
        (getInjuryChance(card.seasonsPlayed, divisionIndex) *
                (1 - getTraitBonus(card, def.position).injuryReduction).clamp(
                  0.0,
                  1.0,
                ) *
                100)
            .round();
    final gamesLeft = _num(card.raw['loanMatchesLeft']).toInt();
    final sponsorMult = _num(_map(card.sponsor)?['multiplier']);
    final income = def.idleIncomePerSec * (sponsorMult > 0 ? sponsorMult : 1);

    // **A GOLD RULE ROUND THE HERO.** The reference shot frames the portrait
    // and its two plates as one object; without an edge the artwork bleeds
    // straight into the sheet's own background and the plates read as floating
    // rather than as inset into something. `foregroundDecoration` so the rule
    // is drawn OVER the crop rather than pushing it in.
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4A64A).withValues(alpha: 0.75),
          width: 2,
        ),
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            // **A SHARE OF THE SHEET, not a fixed 260.** It went 200 → 260 when
            // the buttons moved onto it, and a constant is the wrong shape for
            // this: the artwork is a full-length figure and the sheet is 92% of
            // whatever screen it opens on, so 260 is generous on a small phone
            // and a postage stamp on a tall one. Floored at the old number so
            // nothing gets SMALLER, and capped so he cannot push the trait
            // block — the thing this sheet is for — off the bottom.
            height: (MediaQuery.sizeOf(context).height * 0.42).clamp(260, 420),
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
          // **THE NUMBERS LIVE ON HIM.** They were a ruled box UNDER the
          // picture — five label/value rows, an inventory readout on a card
          // about a person. What he is as a footballer goes top left, what he
          // has cost and what he pays goes top right, and the artwork keeps the
          // room the box was taking.
          // **A BAN IS THE FIRST THING ABOUT HIM.** Reported from the couch:
          // a sent-off player opened the same sheet as anybody else and the
          // only tell was a Send On button that should not have been there.
          // Big, centred and over the artwork — the same treatment an injury
          // gets on a bench card, because it says the same thing: this one
          // cannot take the field.
          if (suspended)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: CardGlyph(
                    key: ValueKey('detail-suspended'),
                    card: cardRed,
                    height: 96,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 10,
            left: 12,
            child: _HeaderPlate(
              key: const ValueKey('detail-attributes'),
              value: '$rating',
              valueKey: const ValueKey('detail-rating'),
              label: t('squad.stat.rating'),
              // **ATK and DEF, because that is where a trait LANDS.** The
              // bonuses are directional and get folded back into the overall,
              // so on the rating alone a Finisher III reads as three points
              // from nowhere. These are the two numbers it actually moved.
              //
              // Not through `t()`, and that is the port rather than an
              // oversight: the source hardcodes these two abbreviations
              // everywhere it shows them (`SquadScreen.js:372`, `Card.js:34`)
              // and has no key for either.
              rows: [
                (label: 'ATK', value: '${stats.attack}', tint: null),
                (label: 'DEF', value: '${stats.defence}', tint: null),
                // **INJURY RISK, which had gone missing entirely.**
                // `squad.detail.injury_risk` is translated in ten catalogues
                // and nothing printed it — the plate's own doc-comment still
                // said "rating, income and injury risk" while carrying two of
                // the three. Reported directly, and asked for HERE rather than
                // among the career tallies: it belongs with the other two
                // numbers about what this player is, not with the record of
                // what he has done.
                //
                // **And the TRAIT counts.** `injuryReduction` is one of the
                // things a roll can buy, so a figure that ignored it would make
                // the trait look like it did nothing — the one number it moves
                // being the one number that did not move is the same defect
                // `getCardStats` exists to prevent.
                // **THE `%` RIDES ON THE LABEL, not on the figure.** ATK and
                // DEF beside it are bare numbers, so `12%` under `INJ` was
                // the one value in the row with a unit stuck to it and read as
                // a different KIND of number at a glance. `INJ%` says what the
                // column is and leaves the three figures the same shape.
                // Asked for directly.
                (label: 'INJ%', value: '$injuryPct', tint: null),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 12,
            child: _HeaderPlate(
              key: const ValueKey('detail-career'),
              // A loanee arrives fresh, so their seasons count is always zero —
              // a stat with one possible value is a dead slot. What actually
              // runs down on a loan is the GAMES, so that takes its place.
              value: '${onLoanToUs ? gamesLeft : seasons}',
              valueKey: const ValueKey('detail-seasons'),
              valueColour: onLoanToUs ? const Color(0xFF7FE3D9) : null,
              label: t(
                onLoanToUs ? 'squad.stat.games_left' : 'squad.stat.seasons',
              ),
              rows: [
                (
                  label: t('squad.detail.income'),
                  value: '+${income.toStringAsFixed(2)}/s',
                  tint: null,
                ),
                // **AND HIS FORM, spelt out.** The cards carry it as a bare ▲
                // or ▼ and nothing anywhere said what the arrow meant — asked
                // for from the couch, and this is the right place: the sheet is
                // where a player comes to find out what a mark on a card is.
                // `squad.form.good` / `squad.form.bad` are the words the bench
                // legend uses, so the two agree.
                //
                // Absent for a player in neither, which is most of them: a row
                // reading "Form 0" is a slot spent saying nothing.
                if (card.form != 0)
                  (
                    label: t(
                      card.form > 0 ? 'squad.form.good' : 'squad.form.bad',
                    ),
                    value:
                        '${formGlyph(card.form.toInt())} '
                        '${card.form > 0 ? '+' : ''}${card.form}',
                    // The arrow's own two colours — `formInk` is what the cards
                    // and the bench legend paint it in, so the sheet that
                    // EXPLAINS the mark uses the same green and the same red.
                    tint: formInk(card.form.toInt()),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              // 72, not 58: `BRONZE PRO · DEF` was all but touching the tops
              // of Replace and Bench.
              padding: EdgeInsets.fromLTRB(14, 24, 14, actionsBelow ? 72 : 10),
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
                      // **HOW LONG HE IS OUT FOR, which the game never said.**
                      // Reported from the couch: "an injured player doesn't say
                      // how long they are out for — that should be shown in the
                      // player when you click on them in squad."
                      //
                      // The copy for it has shipped in ten languages the whole
                      // time and nothing could reach it: `squad.badge.injured`
                      // is "🚑 Injured{suffix}", and the suffix is
                      // `squad.badge.injured_min_left` (" ({min}m left)") or
                      // `squad.badge.injured_soon` under a minute. Even
                      // `hint.injured_on_grid` sends the player to the Squad tab
                      // "to see their recovery time" — a promise the port could
                      // not keep.
                      //
                      // The 🚑 goes, like every other emoji the port has taken
                      // out of shipped copy: it is a DOM flourish, and the app
                      // draws its own cross. `InjuryCross` is the one the bench
                      // card and the pitch token already wear, so a hurt man
                      // carries the same mark wherever he is looked at.
                      if (card.injured)
                        Container(
                          key: const ValueKey('detail-injured'),
                          padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCC2222),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const InjuryCross(size: 13),
                              const SizedBox(width: 5),
                              Text(
                                stripBadgeEmoji(
                                  t('squad.badge.injured', {
                                    'suffix': injuryMinsLeft > 0
                                        ? t('squad.badge.injured_min_left', {
                                            'min': injuryMinsLeft,
                                          })
                                        : t('squad.badge.injured_soon'),
                                  }),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // **WHERE HE IS ON THE AGE CURVE, which four more
                      // shipped keys were saying to nobody.** `ageBadgeKeyFor`
                      // is the ladder `coach_tips.dart` already runs on, so the
                      // badge on the sheet and the sentence out of Colin cannot
                      // disagree about the same player.
                      //
                      // The emoji goes, like the ambulance above it and every
                      // other one the port has taken out of generated copy: the
                      // catalogues were written for a DOM.
                      //
                      // `squad.badge.seasons_inj` is deliberately NOT drawn.
                      // It is "{seasons} season{s} · {pct}% inj", and this sheet
                      // already prints both halves of that in its own plates —
                      // the career plate's seasons and the attribute plate's
                      // INJ. A third copy of two numbers already on screen is
                      // the "two numbers for one man" trap, from the other end.
                      if (card.injured && ageBadge != null)
                        const SizedBox(width: 6),
                      if (ageBadge != null)
                        Container(
                          key: const ValueKey('detail-age-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ageBadgeIsUrgent(ageBadge)
                                ? const Color(0xFFCC2222)
                                : const Color(0xFFB07A12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            stripBadgeEmoji(t(ageBadge)),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if ((card.injured || ageBadge != null) &&
                          (onLoanToUs || outOnLoan))
                        const SizedBox(width: 6),
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
      ),
    );
  }
}

/// One of the two glass plates over the artwork.
///
/// A headline number with its word under it, then the rows that qualify it.
/// Both plates are the same object so the two corners cannot drift into
/// different type sizes, which is what happened to every pair before them.
class _HeaderPlate extends StatelessWidget {
  const _HeaderPlate({
    super.key,
    required this.value,
    required this.label,
    required this.rows,
    this.valueKey,
    this.valueColour,
  });

  final String value;
  final String label;
  /// A [tint] paints the VALUE, for a row whose figure carries a verdict —
  /// form is the one, and asked for from the couch: green up, red down.
  final List<({String label, String value, Color? tint})> rows;
  final Key? valueKey;
  final Color? valueColour;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    // Capped, because the two plates face each other across the artwork and a
    // long localised label — `Einnahmen`, `Temporadas` — would walk one into
    // the other.
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * 0.42,
    ),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
    ),
    // The rows set the width and the headline centres over them; without this
    // the stretch below has nothing finite to stretch to.
    child: IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            value,
            key: valueKey,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.05,
              color: valueColour ?? Colors.white,
            ),
          ),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFFD8D8D8),
            ),
          ),
          if (rows.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: Color(0x33FFFFFF)),
              ),
            ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        row.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFFBFBFBF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      row.value,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: row.tint ?? Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
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
        // A pencil, as asked — Material's, not the emoji that drew grey.
        child: const Icon(Icons.edit, size: 15, color: Colors.white70),
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
            child: HeroPill(
              buttonKey: const ValueKey('detail-swap'),
              glyph: 'refresh',
              label: t('squad.detail.replace'),
              gold: false,
              onTap: () => Navigator.of(context).pop(PlayerDetailAction.swap),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HeroPill(
              buttonKey: const ValueKey('detail-bench'),
              glyph: 'arrowDown',
              label: t('squad.detail.to_bench'),
              gold: true,
              onTap: () => Navigator.of(context).pop(PlayerDetailAction.bench),
            ),
          ),
        ],
      );
    } else if (selectable) {
      // Nobody unavailable can be sent on: the match engine rates a loaned or
      // listed player zero, so putting one in the side fields a hole.
      row = HeroPill(
        buttonKey: const ValueKey('detail-send-on'),
        glyph: 'arrowUp',
        label: t('squad.detail.send_on'),
        gold: true,
        onTap: () => Navigator.of(context).pop(PlayerDetailAction.sendOn),
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
                  fontSize: 12,
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
    final cells = <({String label, int value, bool highlight, String suffix})>[
      if (played > 0)
        (
          label: t('squad.stat.played'),
          value: played,
          highlight: false,
          suffix: '',
        ),
      if (goals > 0 || position == 'FWD' || position == 'MID')
        (
          label: '⚽ ${t('squad.stat.goals')}',
          value: goals,
          highlight: goals > 0,
          suffix: '',
        ),
      if (tackles > 0 || position == 'DEF' || position == 'MID')
        (
          label: '🛡️ ${t('squad.stat.tackles')}',
          value: tackles,
          highlight: false,
          suffix: '',
        ),
      if (position == 'GK')
        (
          label: '🧤 ${t('squad.stat.saves')}',
          value: saves,
          highlight: true,
          suffix: '',
        ),
    ];

    // **NO HEADING, AND A BOX PER STAT.** It was one bordered card with
    // `CAREER STATS` across the top and the figures in a row inside it — a
    // label naming what four labelled numbers already say, costing a line of
    // its own on a sheet where the trait block was falling below the fold.
    // Asked for directly, with the fold as the stated reason.
    //
    // Each stat gets its own box instead, which also reads better: the group
    // was one object with four things in it and is now four objects, which is
    // what they are.
    // **NO GAP OF ITS OWN.** It carried ten on top of the column's own
    // [detailGap], so the one seam on the sheet that was 22 was the one between
    // the trait and the stats — read straight off the screen as the spacing
    // being uneven.
    return Row(
        key: const ValueKey('detail-career-stats'),
        children: [
          for (final cell in cells)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    // **`surface2`, BECAUSE THE SHEET ITSELF IS `surface`.** A
                    // box filled with the colour of the page it is on is a
                    // hairline border and nothing else — reported as the boxes
                    // needing a background so they show.
                    color: kit.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kit.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${cell.value}${cell.suffix}',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: cell.highlight ? kit.accentBright : null,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        cell.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: kit.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('squad.detail.loan_games_left', {'n': left, 'total': total}),
            style: TextStyle(fontSize: 12, color: kit.textMuted),
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
            style: TextStyle(fontSize: 12, height: 1.5, color: kit.textMuted),
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
  const TraitBlock({
    super.key,
    required this.instanceId,
    required this.def,
    required this.hold,
    required this.onHold,
  });

  final String instanceId;
  final PlayerDef def;

  /// What the sheet is showing him as while the reels turn, or null when they
  /// are still. Owned by the sheet, because the rating and the trait's name are
  /// two readings of one question.
  final TraitHold? hold;

  final ValueChanged<TraitHold?> onHold;

  @override
  ConsumerState<TraitBlock> createState() => TraitBlockState();
}

class TraitBlockState extends ConsumerState<TraitBlock>
    with SingleTickerProviderStateMixin {
  /// The machine — see `trait_reel.dart`. Both slots spin the same one.
  final GlobalKey<TraitReelState> _reel = GlobalKey<TraitReelState>();

  /// Test seams: the spin and the answer flash, as the reel times them.
  static const Duration spin = TraitReelState.spin;
  static const Duration flash = TraitReelState.flash;

  bool _spinning = false;

  /// Test seam.
  bool get spinning => _spinning;

  /// Where the reels start: on what the card ALREADY has — the JS's own first
  /// act. A reel parked on the top of the pool tells the player their man has
  /// whatever happens to sort first.
  ({int name, int level}) _initial(
    List<Trait> pool,
    Map<String, dynamic>? trait,
  ) {
    final id = trait?['id'] as String?;
    final at = pool.indexWhere((t) => t.id == id);
    return (
      name: at < 0 ? 0 : at,
      level: id == null || id == 'none'
          ? noneRow
          : (((trait?['level'] as num?)?.toInt() ?? 1) - 1).clamp(0, 2),
    );
  }

  /// What this trait is worth on THIS card.
  ///
  /// **IT DESCRIBES [trait], NOT THE SAVE.** This read the live card for the
  /// "with" side while taking the trait's identity from the argument, and the
  /// two are DIFFERENT for the length of a spin: the roll writes the save before
  /// the reels move (see [_roll]), so the badge went on naming the old trait
  /// over chips already showing the new one's ATK and DEF. The answer arrived
  /// a second and a half early, in the two numbers the roll is bought to move.
  /// Reported from the couch. Both sides are composed from the trait being
  /// SHOWN now, which is also what makes this correct at rest.
  ///
  /// **The directional pair is BY DIFFERENCE.** `getCardStats` is the documented
  /// single source of truth for what a card is worth and it already folds the
  /// trait in, so the honest figure is that number minus the same card with the
  /// trait taken off — rather than recomposing the bonus fields here and
  /// drifting from the sim the first time either changes. It is also the only
  /// pair that CAN come back zero on a trait that promises it: the split is
  /// clamped at 100, which is the whole reason [traitStatScale] exists.
  ///
  /// **And the other seven axes are here at all now.** The block showed ATK and
  /// DEF and nothing else, so four of the nine outcomes in a forward's pool —
  /// Crowd Pleaser, Tough, Veteran, None — drew no chip whatsoever and the
  /// remaining five drew the same one or two. A bank of twenty mechanically
  /// distinct traits read on screen as three. The ten `feature.effect.*` strings
  /// are shipped in all ten catalogues and had NO caller in `lib/`; they are the
  /// short-form labels this needs, exactly.
  List<String> _effectsOf(
    CardInstance? card,
    Map<String, dynamic>? trait,
    Map<String, dynamic> ratios,
  ) {
    if (card == null || trait == null) return const [];
    final def = getTrait(trait['id'] as String?);
    final level = (trait['level'] as num?)?.toInt();
    final lvl = level == null ? null : getTraitLevel(def, level);
    if (lvl == null) return const [];

    final bare = CardInstance(<String, dynamic>{...card.raw}..remove('trait'));
    final shown = CardInstance(<String, dynamic>{...card.raw, 'trait': trait});
    final with_ = getCardStats(shown, definitionRatios: ratios);
    final without = getCardStats(bare, definitionRatios: ratios);

    // A percentage the copy writes whole: `0.13` is "13%".
    int pct(double v) => (v * 100).round();

    final rows = <String>[];
    void add(String key, int n) {
      if (n <= 0) return;
      rows.add(t('feature.effect.$key', {'n': '$n'}));
    }

    add('atk', with_.attack - without.attack);
    add('def', with_.defence - without.defence);
    add('income', pct(lvl.incomeBonus));
    add('matchrev', pct(lvl.matchRevBonus));
    add('injury', pct(lvl.injuryReduction));
    add('teaminjury', pct(lvl.teamInjuryReduction));
    add('recovery', pct(lvl.recoveryBonus));
    add('aging', lvl.agingReduction);
    // Below 1 tires slower, and the copy states the DRAIN it removes.
    add('stamina', pct(1 - (lvl.staminaMult ?? 1)));
    return rows;
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
    // **A roll can LOSE.** `none` is in the pool, and when it comes up the
    // level it rolled alongside means nothing — the reel has to say so rather
    // than stop on a numeral.
    final isNone = roll.id == 'none';
    final reel = _reel.currentState;
    if (reel == null) return;
    setState(() => _spinning = true);
    // **The outcome is written to the save BEFORE the reels move** — deliberately,
    // because a spin that decided at the end would have to be unwound when the
    // debit was refused. So the sheet is told to keep showing the man he was
    // until they stop; every number on it reads the save.
    widget.onHold((trait: was));
    await reel.spinTo(
      nameIndex: landing,
      levelRow: isNone ? noneRow : (roll.level - 1).clamp(0, 2),
    );
    if (!mounted) return;
    setState(() => _spinning = false);
    widget.onHold(null);

    // The band answers before anything else does.
    await reel.flashAnswer(
      isNone ? const Color(0xFFF87171) : const Color(0xFF00B45A),
    );
    if (!mounted) return;

    // **AND A LOST ROLL IS NOT CELEBRATED.** `getTrait('none')` is a real entry
    // rather than null, so the celebration fired for it too: a player who paid
    // coins and got nothing was shown a splash reading "✕ None" over up to
    // three gold stars. The red band above is the whole of the answer a loss
    // gets.
    if (isNone) return;

    // **AND THEN IT ANNOUNCES IT.** The reels stopping is the reveal and it is
    // over in a frame — the player has just spent coins on the most
    // interesting thing about this card and the sheet simply carried on. A club
    // asset unlock has had the payoff beat since it was ported; this is the
    // same one, with the trait's own glyph and what it DOES underneath.
    //
    // After the spin rather than with it: a splash over a moving reel would be
    // the answer arriving before the question finished being asked.
    final trait = getTrait(roll.id);
    if (trait == null) return;
    await showFeatureUnlock(
      context,
      title: traitTitle({'id': roll.id, 'level': roll.level}),
      subtitle: traitDesc(trait),
      icon: Text(trait.icon, style: const TextStyle(fontSize: 44)),
      accent: Theme.of(context).extension<KitTheme>()!.accentBright,
      starCount: roll.level.clamp(1, 3),
    );
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
    // Mid-spin this is what he had, not what he just won — see [TraitHold].
    final trait = widget.hold != null
        ? widget.hold!.trait
        : _map(card?.raw['trait']);

    final held = getTrait(trait?['id'] as String?);
    final initial = _initial(pool, _map(card?.raw['trait']));
    final ratios =
        _map(ref.watch(gameProvider).state?['definitionRatios']) ?? const {};

    return Container(
      key: const ValueKey('detail-trait'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // **A TRAIT IS A POSSESSION, SO THE BLOCK LOOKS LIKE ONE.** It was a
        // grey box with a grey heading and a line of text, sitting under a
        // portrait and a set of stats — the most interesting thing on the sheet
        // drawn as the least. A card that HAS one wears the accent: a wash
        // behind it, a heavier edge, and a level chip in the corner. One that
        // does not stays quiet, which is what makes the difference legible
        // before either is read.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: held == null
              // `surface2` at rest: the sheet is `surface`, so a card filled
              // with it had no body at all — only its border said it was there.
              ? [kit.surface2, kit.surface2]
              : [
                  Color.alphaBlend(
                    kit.accent.withValues(alpha: 0.16),
                    kit.surface,
                  ),
                  kit.surface,
                ],
        ),
        border: Border.all(
          color: held == null ? kit.border : kit.accent,
          width: held == null ? 1 : 1.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('squad.trait').toUpperCase(),
                  style: TextStyle(
                    color: held == null ? kit.textMuted : kit.accentBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              // **The level is ON THE MEDAL now**, not in this row. It is the
              // part that changes on a reroll of the same trait, and a numeral
              // in a header is a specification where on the medal it is what
              // the medal is worth. See [_TraitDisc].
            ],
          ),
          const SizedBox(height: 10),
          // What he has, above the reels — the reels are the SPIN and this is
          // the ANSWER, and a player who has not rolled anything yet needs to be
          // told which of the two they are looking at.
          if (held == null)
            Row(
              key: const ValueKey('detail-trait-label'),
              children: [
                TraitDisc(
                  glyph: '?',
                  colour: kit.textMuted,
                  fill: kit.surface2,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('trait.name.none'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: kit.textMuted,
                    ),
                  ),
                ),
              ],
            )
          else
            _TraitBadge(
              trait: held,
              instance: trait!,
              effects: _effectsOf(card, trait, ratios),
            ),
          const SizedBox(height: 12),
          TraitReel(
            key: _reel,
            names: [
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
            initialName: initial.name,
            initialLevel: initial.level,
          ),
          const SizedBox(height: 12),
          // **A GOLD BAR ACROSS THE CARD.** The cost rides on the button with
          // the dice beside it — this is the only gamble on the sheet, so the
          // thing you press says what it takes — and it takes the same gold the
          // hero's Bench pill does, because they are the two affirmative
          // controls on this sheet and there is no reason for them to be two
          // different colours.
          HeroPill(
            buttonKey: const ValueKey('detail-trait-roll'),
            // `star`, not 🎲: the emoji is a platform's own drawing on a sheet
            // where every other mark is the game's, and it rendered flat grey
            // in the Material fallback font. What a trait roll buys is a star
            // on the card.
            glyph: 'star',
            label: t('game.trait.cost', {'cost': formatCoins(cost)}),
            gold: true,
            onTap: _spinning || coins < cost ? null : () => _roll(pool),
          ),
          if (coins < cost)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t('game.trait.need_coins', {'cost': formatCoins(cost)}),
                key: const ValueKey('detail-trait-blocked'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: kit.textMuted),
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
/// What a trait is worth, **IN POINTS**.
///
/// **Percentages were the first answer and they were wrong.** A trait reads as
/// `ATK +228%` because the bonus is a multiplier on a small base — true, and
/// unreadable: reported straight back as too complicated. What a manager wants
/// is the number on the card moving, so this is the card's stats WITH the trait
/// minus the same card without it. Two integers, and no arithmetic to do.
///
/// Computed by DIFFERENCE rather than from the bonus fields, because
/// `getCardStats` is the documented single source of truth for what a card is
/// worth — reproducing its composition here is how the sheet and the sim come
/// to disagree.
class _TraitEffects extends StatelessWidget {
  const _TraitEffects({required this.rows});

  /// Already-formatted chip text — see `TraitBlockState._effectsOf`. The
  /// catalogue's `feature.effect.*` strings carry their own sign and unit
  /// ("-7% injury", "50% faster healing"), so there is nothing left to compose
  /// here and no place for a second set of English literals.
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Wrap(
      key: const ValueKey('detail-trait-effects'),
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final row in rows)
          DecoratedBox(
            decoration: BoxDecoration(
              color: kit.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                row,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: kit.accentBright,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TraitBadge extends StatelessWidget {
  const _TraitBadge({
    required this.trait,
    required this.instance,
    required this.effects,
  });

  final Trait trait;
  final Map<String, dynamic> instance;

  /// What the trait is worth on THIS card — see [_TraitEffects].
  final List<String> effects;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      key: const ValueKey('detail-trait-label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TraitDisc(
          glyph: trait.icon,
          colour: kit.accent,
          fill: kit.accent.withValues(alpha: 0.18),
          level: switch ((instance['level'] as num?)?.toInt() ?? 0) {
            final l when l > 0 => romanLevels[l.clamp(1, 3) - 1],
            _ => null,
          },
          levelInk: kit.accentInk,
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
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: kit.accentBright,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                traitDesc(trait),
                key: const ValueKey('detail-trait-desc'),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: kit.textMuted,
                ),
              ),
              // **AND WHAT IT IS ACTUALLY WORTH.** The block named the trait
              // and described it in prose — "a big, pure boost to attack" — and
              // said nowhere how big. This is the one gamble on the sheet and
              // the numbers are what a player is buying, so they belong under
              // the sentence that promises them. Asked for directly.
              //
              // **No new copy, and there could not be**: the catalogues are
              // generated and `ATK`/`DEF` are the same bare labels the match
              // stat rows use. A row that is worth nothing is simply not drawn.
              if (effects.isNotEmpty) ...[
                const SizedBox(height: 6),
                _TraitEffects(rows: effects),
              ],
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
///
/// **AND IT IS A DRUM, not a list.** The rows either side of the answer are
/// dimmed and turned away from the reader — `overAndUnderCenterOpacity` and a
/// tighter `diameterRatio` — which is the half of the roller a CSS strip
/// cannot do at all and is why the JS settles for a gradient over the top of
/// one. Flutter has the cylinder, so it gets both: the curve here and the
/// window's own edge fade over it.

