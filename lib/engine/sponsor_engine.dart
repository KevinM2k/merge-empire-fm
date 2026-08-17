/// Sponsorship offers and their effects, ported from
/// `../merge-empire-fc/src/engine/sponsorEngine.js`.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/sponsors.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

/// At most one sponsor offer per 30 minutes of play.
const int sponsorMinIntervalMs = 30 * 60 * 1000;

/// Chance per eligible post-match check. Down from 30% when the cooldown
/// was added.
const double sponsorOfferChance = 0.20;

/// Offer generation uses unseeded randomness, matching the JS `Math.random()`.
/// Drawing from the shared seeded stream would shift every subsequent gameplay
/// draw and break parity with the JS engines.
math.Random _rng = math.Random();

/// Test seam. Pass a seeded generator for deterministic offers.
void setSponsorRandom(math.Random rng) => _rng = rng;

void resetSponsorRandom() => _rng = math.Random();

/// The drawback numbers for an active sponsor.
///
/// Preferred source is the fields baked onto `card.sponsor` at signing, but
/// older saves predate that migration and store only name and multiplier — so
/// fall back to looking the company up by name, and legacy cards still show and
/// apply their drawbacks.
({int ratingPenalty, double injuryPenalty}) sponsorDrawback(
  Map<String, dynamic>? sponsor,
) {
  if (sponsor == null) return (ratingPenalty: 0, injuryPenalty: 0.0);

  if (sponsor['ratingPenalty'] != null || sponsor['injuryPenalty'] != null) {
    return (
      ratingPenalty: (sponsor['ratingPenalty'] as num?)?.toInt() ?? 0,
      injuryPenalty: (sponsor['injuryPenalty'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final name = sponsor['name'];
  for (final c in companies) {
    if (c.name == name) {
      return (
        ratingPenalty: c.drawback.ratingPenalty,
        injuryPenalty: c.drawback.injuryPenalty,
      );
    }
  }
  return (ratingPenalty: 0, injuryPenalty: 0.0);
}

/// What one deal does to one player, in the units the offer card states.
///
/// The card is a DECISION, so its numbers derive from the same fields the match
/// engine reads rather than being described in prose twice:
///
///   incomePct   +% coins/sec, from the multiplier
///   ratingDrop  rating POINTS off this card's base — `ratingPenalty` is a
///               percentage OF it, rounded the same way the engine rounds it,
///               so this is the figure that actually bites
///   injuryPct   percentage POINTS added to the per-match injury roll, which is
///               how the engine applies it
///   formDrop    the one-off form debuff taken at signing
///
/// [clean] covers deals with nothing to declare — the card has to SAY so rather
/// than leave the row empty. A 1% rating penalty on a low-rated card rounds to
/// nothing and counts as clean, which is honest: it costs that player nothing,
/// because the engine rounds it away too.
({int incomePct, int ratingDrop, int injuryPct, int formDrop, bool clean})
sponsorImpact(PlayerDef? def, Company? company) {
  final d = company?.drawback;
  final ratingDrop = _jsRound((def?.rating ?? 0) * (d?.ratingPenalty ?? 0) / 100);
  final injuryPct = _jsRound((d?.injuryPenalty ?? 0) * 100);
  final formDrop = d?.formPenalty ?? 0;

  return (
    incomePct: _jsRound((company?.mult ?? 1) * 100 - 100),
    ratingDrop: ratingDrop,
    injuryPct: injuryPct,
    formDrop: formDrop,
    clean: ratingDrop == 0 && injuryPct == 0 && formDrop == 0,
  );
}

int _jsRound(num v) => (v + 0.5).floor();

/// A generated offer: which player, and from whom.
typedef SponsorshipOffer = ({CardInstance player, Company company});

/// Rolls a post-match sponsorship offer, or returns null.
///
/// Suppressed during the tutorial — the intro should not surprise the player
/// with a sign-a-sponsor decision before they have learned the core loop.
SponsorshipOffer? maybeGenerateSponsorshipOffer(Map<String, dynamic> state) {
  final tutorial = state['tutorial'];
  if (tutorial is! Map || tutorial['done'] != true) return null;

  final market = state['transferMarket'];
  final lastAt = (market is Map ? market['lastSponsorAt'] as num? : null) ?? 0;
  if (now() - lastAt < sponsorMinIntervalMs) return null;

  if (_rng.nextDouble() > sponsorOfferChance) return null;

  final grid = state['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  if (cells is! List) return null;

  final eligible = <CardInstance>[
    for (final c in cells)
      if (CardInstance.from(c) case final card?)
        if (card.sponsor == null) card,
  ];
  if (eligible.isEmpty) return null;

  final player = eligible[_rng.nextInt(eligible.length)];
  final company = companies[_rng.nextInt(companies.length)];

  final tm = state.putIfAbsent('transferMarket', () => <String, dynamic>{});
  if (tm is Map) tm['lastSponsorAt'] = now();

  return (player: player, company: company);
}

/// Signs [player] to [company]. Returns false when the deal cannot be applied.
bool applySponsorship(
  Map<String, dynamic> state,
  CardInstance player,
  Company company,
) {
  final grid = state['grid'];
  final cells = grid is Map ? grid['cells'] : null;
  if (cells is! List) return false;

  CardInstance? target;
  for (final c in cells) {
    final card = CardInstance.from(c);
    if (card != null && card.instanceId == player.instanceId) {
      target = card;
      break;
    }
  }
  if (target == null) return false;

  // Hard-enforce one sponsor per player at the write boundary. The offer
  // generator already filters, but this protects the invariant however the
  // caller arrived.
  if (target.sponsor != null) return false;

  final d = company.drawback;
  // Store the penalty numbers on the sponsor object itself so the squad detail
  // view and match engine read them without re-looking-up the company.
  // `signedSeason` lets endSeason clear sponsors that have run their term.
  final progression = state['progression'];
  target.raw['sponsor'] = <String, dynamic>{
    'name': company.name,
    'multiplier': company.mult,
    'ratingPenalty': d.ratingPenalty,
    'injuryPenalty': d.injuryPenalty,
    'signedSeason':
        (progression is Map ? progression['seasonCount'] as num? : null) ?? 1,
  };

  // Form is a one-time debuff at signing — the player sulks about the deal.
  if (d.formPenalty != 0) {
    target.raw['form'] = math.max(Form.min, target.form - d.formPenalty);
  }

  final resources = state['resources'];
  emit('coins:updated', resources is Map ? resources['fanCoins'] : null);
  return true;
}
