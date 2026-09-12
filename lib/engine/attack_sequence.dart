/// The two sides as the positional sim sees them, and who meets whom in a zone.
///
/// **New to the port** — see `pitch_space.dart` for the frame and
/// `pitch_influence.dart` for the maps. This file puts real players on those
/// maps: a [PitchPlayer] is one slot's occupant with his own ATK/DEF and his
/// attacking and defensive influence, and a [PitchSide] is the eleven (or
/// fewer — a hole is a hole) in ONE absolute frame. The opponent's side is
/// built mirrored, so both sides' maps index the same twenty zones and "the
/// defenders in the zone the ball is in" is one lookup on either.
///
/// Selection is where ratings first enter the positional model. The carrier
/// of an attack in a zone is drawn with weight `attacking[zone] × ATK`, the
/// defender who meets him with weight `defending[zone] × DEF` — so the sim
/// puts the winger on the ball on his flank and a better winger on it more
/// often, without a table saying so. Every pick takes its roll as an argument
/// rather than drawing one, so the sequence owns the seeded stream and a test
/// can sweep the unit interval and read exact shares.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/pitch_influence.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

/// One slot's occupant, with his maps already in the sim's absolute frame.
class PitchPlayer {
  const PitchPlayer({
    required this.id,
    required this.slotId,
    required this.slotPosition,
    required this.attack,
    required this.defence,
    required this.attacking,
    required this.defending,
    this.name = '',
  });

  /// The card's `instanceId`, or `ai:<slotId>` for a synthesised opponent.
  final String id;
  final String slotId;
  final String slotPosition;
  final String name;
  final double attack;
  final double defence;
  final InfluenceMap attacking;
  final InfluenceMap defending;

  PitchPlayer scaled({double attack = 1, double defence = 1}) => PitchPlayer(
    id: id,
    slotId: slotId,
    slotPosition: slotPosition,
    name: name,
    attack: this.attack * attack,
    defence: this.defence * defence,
    attacking: attacking,
    defending: defending,
  );

  @override
  String toString() =>
      'PitchPlayer($id $slotId ${attack.round()}/${defence.round()})';
}

/// A team on the pitch: the players who are actually there.
class PitchSide {
  PitchSide(List<PitchPlayer> players) : players = List.unmodifiable(players);

  final List<PitchPlayer> players;

  /// Everyone's attacking presence, zone by zone.
  late final InfluenceMap attackingPresence = InfluenceMap.sum(
    players.map((p) => p.attacking),
  );

  /// Everyone's defensive presence, zone by zone.
  late final InfluenceMap defendingPresence = InfluenceMap.sum(
    players.map((p) => p.defending),
  );

  /// Multiply every player's numbers, so a side built from card stats can be
  /// brought onto the TEAM figures the goal model was given — home advantage,
  /// the tactic multipliers and the rest land on the team split, and a duel
  /// should feel them too.
  PitchSide scaled({double attack = 1, double defence = 1}) => PitchSide([
    for (final p in players) p.scaled(attack: attack, defence: defence),
  ]);
}

/// Index drawn from [weights] at [roll] in `[0, 1)`; null when nothing has
/// weight. A roll at or past the total lands on the last weighted entry
/// rather than off the end.
int? weightedIndex(List<double> weights, double roll) {
  var total = 0.0;
  for (final w in weights) {
    if (w > 0) total += w;
  }
  if (total <= 0) return null;
  var target = roll * total;
  int? last;
  for (var i = 0; i < weights.length; i++) {
    final w = weights[i];
    if (w <= 0) continue;
    last = i;
    if (target < w) return i;
    target -= w;
  }
  return last;
}

/// How likely each player is to be on the ball in [zone].
List<double> carrierWeights(PitchSide side, int zone) => [
  for (final p in side.players) p.attacking[zone] * p.attack,
];

/// How likely each player is to be the one who meets the ball in [zone].
List<double> defenderWeights(PitchSide side, int zone) => [
  for (final p in side.players) p.defending[zone] * p.defence,
];

PitchPlayer? pickCarrier(PitchSide side, int zone, double roll) {
  final i = weightedIndex(carrierWeights(side, zone), roll);
  return i == null ? null : side.players[i];
}

PitchPlayer? pickDefender(PitchSide side, int zone, double roll) {
  final i = weightedIndex(defenderWeights(side, zone), roll);
  return i == null ? null : side.players[i];
}

/// Our side from the save's lineup and the shape it is set in.
///
/// A slot with no fit card is a hole: nobody is added for it, so the side's
/// presence is genuinely thinner there, which is what a man down should mean.
/// Coordinates come from the formation slot with the same id and fall back to
/// the same index for a lineup out of step with its shape. [scale] is the
/// per-player rating factor Pro mode applies for fatigue and the referee's
/// booking; it multiplies both stats.
PitchSide pitchSideFromLineup({
  required List<CardInstance> cards,
  required List<Map<String, dynamic>> lineup,
  required List<FormationSlot> slots,
  Map<String, dynamic> definitionRatios = const {},
  double Function(CardInstance card)? scale,
  bool mirrored = false,
}) {
  final byId = {for (final c in cards) c.instanceId: c};
  final bySlotId = {for (final s in slots) s.slotId: s};
  final players = <PitchPlayer>[];
  for (var i = 0; i < lineup.length; i++) {
    final row = lineup[i];
    final iid = row['cardInstanceId'];
    final card = iid is String ? byId[iid] : null;
    if (card == null || card.injured || card.isUnavailable) continue;
    if (getPlayerDef(card.definitionId) == null) continue;
    final slotId = row['slotId'] as String? ?? '';
    final slot = bySlotId[slotId] ?? (i < slots.length ? slots[i] : null);
    if (slot == null) continue;
    final slotPos = row['slotPosition'] as String? ?? slot.slotPosition;
    final st = getCardStats(
      card,
      slotPosition: slotPos,
      definitionRatios: definitionRatios,
    );
    final k = scale?.call(card) ?? 1.0;
    players.add(
      _player(
        id: card.instanceId,
        name: card.name(),
        slot: slot,
        slotPosition: slotPos,
        attack: st.attack * k,
        defence: st.defence * k,
        mirrored: mirrored,
      ),
    );
  }
  return PitchSide(players);
}

/// An AI side: eleven pseudo-players at the team's rating in one of its
/// shapes, split by position with the SAME call `teamSplitForFormation` makes,
/// so their numbers and the team ATK/DEF the goal model was given agree by
/// construction. Mirrored by default, because the AI is always the other side.
PitchSide pitchSideForAi(
  num rating,
  String? formationId, {
  bool mirrored = true,
}) {
  final slots = aiFormationSlots[formationId] ?? aiFormationSlots['4-4-2']!;
  return PitchSide([
    for (final slot in slots)
      () {
        final pos = slot.slotPosition;
        final split = getCardAtkDefSplit(positionAttackRatio[pos], rating);
        return _player(
          id: 'ai:${slot.slotId}',
          slot: slot,
          slotPosition: pos,
          attack: split.attack.toDouble(),
          defence: split.defence.toDouble(),
          mirrored: mirrored,
        );
      }(),
  ]);
}

PitchPlayer _player({
  required String id,
  required FormationSlot slot,
  required String slotPosition,
  required double attack,
  required double defence,
  required bool mirrored,
  String name = '',
}) {
  // The maps are a property of the SLOT position, not the card's — a striker
  // parked at centre-back attacks from where a centre-back stands.
  final placed = FormationSlot(
    slotId: slot.slotId,
    slotPosition: slotPosition,
    x: slot.x,
    y: slot.y,
  );
  var atk = attackingInfluence(placed);
  var def = defensiveInfluence(placed);
  if (mirrored) {
    atk = atk.mirrored();
    def = def.mirrored();
  }
  return PitchPlayer(
    id: id,
    slotId: slot.slotId,
    slotPosition: slotPosition,
    name: name,
    attack: attack,
    defence: defence,
    attacking: atk,
    defending: def,
  );
}
