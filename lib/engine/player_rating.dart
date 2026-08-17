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

/// A card's ATK and DEF, with its trait's directional bonuses folded in.
///
/// [attackRatio] resolves per-instance first, then the definition's — the same
/// precedence the JS callers apply before handing it to the split.
AtkDefSplit getCardSplit(CardInstance? card, {double? definitionRatio}) {
  if (card == null) return const AtkDefSplit(attack: 0, defence: 0);

  final def = getPlayerDef(card.definitionId);
  if (def == null) return const AtkDefSplit(attack: 0, defence: 0);

  final tb = getTraitBonus(card, def.position);
  final ratio = card.attackRatio ?? definitionRatio ?? def.attackRatio;

  return getCardAtkDefSplit(
    ratio,
    getEffectiveRating(card),
    atkBonus: tb.atkBonus,
    defBonus: tb.defBonus,
  );
}
