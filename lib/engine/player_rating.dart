/// The composed "how good is this card right now" rating.
///
/// Lives here rather than in `data/players.dart` because it needs the trait and
/// sponsor engines. The JS keeps `getEffectiveRating` in the data file and
/// imports the engines from there, which inverts the dependency; this port puts
/// the composition on the engine side, where its dependencies already are.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

int _jsRound(num v) => (v + 0.5).floor();

/// The single source of truth for how good a card is right now — aging, trait
/// rating bonus, sponsor drawback and current form.
///
/// Used by the match sim, squad rating, card display AND lineup auto-fill, so
/// they can never disagree about which card is actually better.
///
/// Does NOT apply fatigue: callers scale by the fatigue factor separately,
/// since fatigue only matters in Pro mode and live-match contexts, not to every
/// reader of this rating.
int getEffectiveRating(CardInstance? card) {
  if (card == null) return 0;

  final def = getPlayerDef(card.definitionId);
  if (def == null) return 0;

  final tb = getTraitBonus(card, def.position);
  final r = getCardRating(def, ratingBonus: card.ratingBonus);
  final cap = def.maxRating;

  final sponsor = card.sponsor;
  final drawback = sponsorDrawback(
    sponsor is Map<String, dynamic> ? sponsor : null,
  );
  final sponsorPenalty = _jsRound(r * drawback.ratingPenalty / 100);

  final aging = math.max(
    0,
    agingPenalty(card.seasonsPlayed) - tb.agingReduction,
  );

  final composed = r - sponsorPenalty - aging + tb.ratingBonus + card.form;
  return math.max(1, math.min(cap, composed)).round();
}

// **`getCardSplit` was here and it was the second implementation.** It took a
// card and returned its ATK/DEF with the trait's directional bonuses folded in
// — which is, expression for expression, what `getCardStats` in
// `squad_rating.dart` computes as its `eff` before wrapping it with the base
// split and the rating. That one has five callers and every screen showing an
// ATK/DEF pair goes through it; this one had none. The rule it named that WAS
// duplicated is the attack-ratio precedence, and that is `_attackRatio` there
// now.
