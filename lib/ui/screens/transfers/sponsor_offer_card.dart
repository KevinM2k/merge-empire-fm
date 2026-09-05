/// A company wanting to sponsor one of your players. Ported from
/// `ui/components/SponsorshipOfferModal.js`.
///
/// Colin's card again, and for the same reason as the transfer bid: it is one
/// yes/no question with a read attached.
///
/// **Every drawback is named.** A sponsor pays income and most of them cost
/// something — rating, injury risk, form — and a card that showed only the
/// boost would be selling the deal rather than presenting it. `SponsorDrawback`
/// carries all three, so all three are drawn, and a clean deal says so rather
/// than leaving an empty space that reads as an omission.
///
/// Unlike the transfer bid this one cannot be parked. There is nothing pending
/// to come back to: a declined roll is simply not re-offered this match, and a
/// dismissal that recorded no answer would swallow the offer entirely.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/sponsors.dart';
import 'package:merge_empire_fc/engine/coach_tip_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart' show scoutCost;
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/transfers/coach_verdict.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// Colin's read on a sponsor: sign it or not, and why.
///
/// **The card had no read at all** — the terms, the drawback's own line and two
/// buttons — on a deal whose catch is exactly the kind of thing a coach is for.
/// Asked for from the couch alongside the bid's: weigh who it is, whether they
/// start, how we are doing and whether we need the money.
///
/// Most specific first. A catch is only a catch on somebody who plays; a club
/// that is broke takes a deal a comfortable one would think twice about.
CoachRead sponsorRead(
  Map<String, dynamic> state,
  CardInstance player,
  Company company,
) {
  final def = getPlayerDef(player.definitionId);
  final impact = sponsorImpact(def, company);
  final name = player.name(def?.name ?? '');
  final starter = inStartingEleven(state, player.instanceId);
  final form = _num(player.raw['form']).toInt();
  final broke =
      _num(_map(state['resources'])?['fanCoins']) < scoutCost(state);

  CoachRead sign(String key, [Map<String, Object?> p = const {}]) =>
      (verdict: CoachVerdict.accept, text: t(key, p));
  CoachRead refuse(String key, [Map<String, Object?> p = const {}]) =>
      (verdict: CoachVerdict.decline, text: t(key, p));

  if (impact.clean) return sign('manager.sponsor.clean');
  if (starter && impact.ratingDrop > 0 && inDropZone(clubStanding(state))) {
    return refuse('manager.sponsor.relegation_starter', {'player': name});
  }
  if (impact.injuryPct > 0 && player.seasonsPlayed >= 7) {
    return refuse('manager.sponsor.injury_prone', {
      'player': name,
      'seasons': player.seasonsPlayed,
    });
  }
  if (impact.formDrop > 0 && form <= -1) {
    return refuse('manager.sponsor.poor_form', {'player': name});
  }
  if (broke) return sign('manager.sponsor.need_money');
  if (!starter) return sign('manager.sponsor.bench', {'player': name});
  if (impact.ratingDrop >= 3) {
    return (
      verdict: CoachVerdict.yourCall,
      text: t('manager.sponsor.rating_cost', {
        'player': name,
        'n': impact.ratingDrop,
      }),
    );
  }
  return sign('manager.sponsor.fair');
}

/// Offer the deal and settle it. Returns true when it was signed.
Future<bool> showSponsorOffer(
  BuildContext context,
  WidgetRef ref, {
  required CardInstance player,
  required Company company,
}) async {
  // **His explainer is a paragraph INSIDE the offer, not a tip over it.** The
  // JS makes that point twice: a coach tip stacked on top of the card it is
  // about is Colin talking over Colin. `takeTipOnce` returns true once ever, so
  // the first sponsor a player is offered comes with the lesson and no other
  // does.
  // Through `update`, because spending the id WRITES to the save — read the
  // map and mutate it by hand and the ledger never reaches the disk.
  final explain = ref
      .read(gameProvider)
      .update((s) => takeTipOnce(s, 'sponsor'));
  final read = sponsorRead(
    ref.read(gameProvider).state ?? const <String, dynamic>{},
    player,
    company,
  );
  bool? accepted;
  await showDialog<void>(
    context: context,
    barrierColor: coachCardScrim,
    // No parking, and no accidental dismissal: both answers have consequences
    // and neither of them is "nothing happened".
    barrierDismissible: false,
    builder: (_) => _SponsorOfferCard(
      player: player,
      company: company,
      explain: explain,
      read: read,
      onAnswer: (yes) => accepted = yes,
    ),
  );

  final game = ref.read(gameProvider);
  if (accepted == true) {
    game.update((s) => applySponsorship(s, player, company));
    return true;
  }
  game.update((s) {
    final stats = s.putIfAbsent('stats', () => <String, dynamic>{});
    if (stats is Map) {
      stats['sponsorsDeclined'] = _num(stats['sponsorsDeclined']).toInt() + 1;
    }
  });
  // The achievement sweep listens for this; declining sponsors is its own
  // small achievement track.
  emit('sponsor:declined');
  return false;
}

class _SponsorOfferCard extends StatelessWidget {
  const _SponsorOfferCard({
    required this.player,
    required this.company,
    required this.explain,
    required this.read,
    required this.onAnswer,
  });

  final CardInstance player;
  final Company company;

  /// His call, worked out before the card opened — see [sponsorRead].
  final CoachRead read;

  /// Whether this is the first sponsor this save has ever been offered, and so
  /// carries Colin's one-time explanation of what a sponsorship IS.
  final bool explain;

  /// `CoachAction` closes the card itself, so the answer comes back this way
  /// rather than as the dialog's result.
  final void Function(bool accepted) onAnswer;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final def = getPlayerDef(player.definitionId);
    final drawback = company.drawback;
    final boostPct = ((company.mult - 1) * 100).round();

    return CoachCardFrame(
      key: const ValueKey('sponsor-offer'),
      title: t('sponsor.title', {'company': company.name}),
      // **Colin relays the call, in the child rather than in `body`.** The
      // frame draws the body UNDER the child, and the offer has to be heard
      // before the terms are read: "they've been in touch, they want him" and
      // then the small print, then his call. Asked for from the couch — the
      // card should read as him telling us an offer has come in.
      // What a sponsorship is, once ever. Under the offer rather than over it.
      extraLines: [
        if (explain)
          (key: 'coachtip.sponsor.body', params: const {}, strong: false),
      ],
      // Red for no, green for yes — in a line and the same width, because they
      // are two answers to one question.
      actions: [
        CoachAction(
          labelKey: 'common.decline',
          tone: CoachTone.decline,
          onTap: () => onAnswer(false),
        ),
        CoachAction(
          labelKey: 'common.accept',
          tone: CoachTone.confirm,
          onTap: () => onAnswer(true),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoachTypewriter(
            text: t('coach.sponsor.relay', {
              'company': company.name,
              'player': player.name(def?.name ?? ''),
              'n': boostPct,
            }),
            textKey: const ValueKey('sponsor-relay'),
            textAlign: TextAlign.center,
            style: TextStyle(color: kit.textMuted, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 10),
          if (def != null)
            SizedBox(
              height: 96,
              child: ArtImage(
                path: playerImagePath(def.position, def.tier, player.variant),
                fit: BoxFit.contain,
                fallback: PlayerPortrait(
                  variantIndex: player.variant,
                  kitColor: kit.accent,
                ),
              ),
            ),
          // **THE COMPANY'S NAME IS ALREADY THE HEADING.** `sponsor.title` is
          // "{company} Offer" at the top of the card, and this row said it
          // again under the portrait — the same word twice on a card three
          // sentences long. Reported from the couch. The LOGO stays: it is the
          // thing the name row was really carrying, and it is not a repeat of
          // anything.
          const SizedBox(height: 4),
          Text(company.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 10),
          // **TWO PER ROW.** The terms were a column of full-width strips, so a
          // sponsor with three drawbacks pushed the buttons off a short phone
          // for the sake of four short phrases. Asked for from the couch: two
          // per row saves the space. `Wrap` rather than a `Row`, so a long
          // localised term takes a line of its own instead of being squeezed.
          _Terms(
            terms: [
              (label: t('sponsor.income_boost', {'n': boostPct}), good: true),
              if (drawback.isClean)
                (label: t('sponsor.no_catch'), good: true)
              else ...[
                if (drawback.ratingPenalty > 0)
                  (
                    label: t('sponsor.cost_rating', {
                      'n': drawback.ratingPenalty,
                    }),
                    good: false,
                  ),
                if (drawback.injuryPenalty > 0)
                  (
                    label: t('sponsor.cost_injury', {
                      'n': (drawback.injuryPenalty * 100).round(),
                    }),
                    good: false,
                  ),
                if (drawback.formPenalty > 0)
                  (
                    label: t('sponsor.cost_form', {'n': drawback.formPenalty}),
                    good: false,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            // The one piece of copy on this card that is a Dart constant rather
            // than a catalogue key, so it is the one that needs the dash rule
            // asked for by hand — `sponsors.dart` is what the parity fixtures
            // compare, and cannot be edited. See `withoutLongDash`.
            withoutLongDash(drawback.msg),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: kit.textMuted),
          ),
          const SizedBox(height: 10),
          CoachVerdictLine(
            read: read,
            textKey: const ValueKey('sponsor-advice'),
          ),
        ],
      ),
    );
  }
}

/// What a sponsorship pays and what it costs, two to a row.
///
/// **A `Wrap` rather than a `Row` of two.** Two per row is what the space
/// wants; a fixed pair is what breaks in German. A term that will not fit
/// beside its neighbour takes the next line on its own, which is the same
/// answer at any width and in any language.
class _Terms extends StatelessWidget {
  const _Terms({required this.terms});

  final List<({String label, bool good})> terms;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 14,
    runSpacing: 2,
    children: [for (final term in terms) _Term(label: term.label, good: term.good)],
  );
}

class _Term extends StatelessWidget {
  const _Term({required this.label, required this.good});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: good ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
      ),
    ),
  );
}
