/// Where on the pitch a player's attacking and defensive work lands.
///
/// **New to the port** — see `pitch_space.dart` for why. Each slot gets two
/// [InfluenceMap]s, one attacking and one defensive: twenty zone weights that
/// say how much of that player's contribution is felt in each zone. The sim
/// picks the carrier of an attack from the attacking maps in the zone the ball
/// is in and the defender from the defensive maps, so a winger meets a
/// full-back and a striker meets a centre-back without any table saying so.
///
/// ## Shape
///
/// An anisotropic Gaussian around an ANCHOR, sampled at the twenty zone
/// centres and normalised. Wider across than along — a player covers his lane
/// and the next more readily than he covers the band ahead — which is
/// [influenceAcross] against [influenceAlong].
///
/// The anchor is not the slot itself. Attacking work happens ahead of where a
/// player stands and defensive work behind it, by an amount that depends on
/// what he is there to do: the attacking anchor is the slot pushed toward goal
/// by `attackWeights[pos] × attackPushUp`, the defensive anchor is the slot
/// dropped back by `defenceWeights[pos] × defenceDropBack`.
///
/// ## Magnitude
///
/// Each map's total is the position's entry in `attackWeights` or
/// `defenceWeights` from `match_tactics.dart` — **reused, not re-tabulated**,
/// so team ATK/DEF and zone influence are derived from one table and cannot
/// drift apart. A keeper gets zero attacking influence for free, because his
/// attack weight is zero.
///
/// **Ratings never enter here.** A map is a property of the slot and the
/// position alone; the sim weights players by ATK/DEF at selection time.
/// Roles and tactics move the anchor and the spread, never the rating.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/player_roles.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';

/// Spread across the pitch, in frame units. One lane is 20.
const double influenceAcross = 16;

/// Spread along the pitch. One band is 25.
const double influenceAlong = 11;

/// How far toward goal a pure attacker's work lands ahead of his slot.
const double attackPushUp = 20;

/// How far behind his slot a pure defender's work lands.
const double defenceDropBack = 12;

/// Twenty zone weights whose sum is the player's [mass] in that phase.
class InfluenceMap {
  InfluenceMap(List<double> zones)
    : assert(zones.length == pitchZones),
      zones = List.unmodifiable(zones);

  static final InfluenceMap zero = InfluenceMap(
    List<double>.filled(pitchZones, 0),
  );

  final List<double> zones;

  double operator [](int zone) => zones[zone];

  double get mass => zones.fold(0.0, (a, b) => a + b);

  /// The zone with the most weight; the lowest index on a tie.
  int get peakZone {
    var best = 0;
    for (var z = 1; z < pitchZones; z++) {
      if (zones[z] > zones[best]) best = z;
    }
    return best;
  }

  /// Weight summed over a flank.
  double flankMass(Flank flank) {
    var sum = 0.0;
    for (var z = 0; z < pitchZones; z++) {
      if (zoneFlank(z) == flank) sum += zones[z];
    }
    return sum;
  }

  /// Weight summed over a band.
  double bandMass(int band) {
    var sum = 0.0;
    for (var lane = 0; lane < pitchLanes; lane++) {
      sum += zones[zoneIndex(lane, band)];
    }
    return sum;
  }

  /// This map seen from the other team's frame — see `mirrorZone`.
  InfluenceMap mirrored() =>
      InfluenceMap([for (var z = 0; z < pitchZones; z++) zones[mirrorZone(z)]]);

  /// Zone-by-zone total of several players' maps: a team's presence.
  static InfluenceMap sum(Iterable<InfluenceMap> maps) {
    final out = List<double>.filled(pitchZones, 0);
    for (final m in maps) {
      for (var z = 0; z < pitchZones; z++) {
        out[z] += m.zones[z];
      }
    }
    return InfluenceMap(out);
  }
}

/// A slot's attacking map in its own team's frame.
///
/// A [role] moves the anchor — inward is toward the centre line from
/// whichever side the slot is on, forward is toward goal — and scales the
/// spread. The mass is the position's regardless: a role is a place, not a
/// rating.
InfluenceMap attackingInfluence(FormationSlot slot, {PlayerRole? role}) {
  final weight = attackWeights[slot.slotPosition] ?? 0.5;
  final p = slotPoint(slot);
  final toCentre = p.x <= 50 ? 1.0 : -1.0;
  return influenceAround(
    (
      x: p.x + (role?.inward ?? 0) * toCentre,
      y: p.y - weight * attackPushUp - (role?.forward ?? 0),
    ),
    mass: weight,
    across: influenceAcross * (role?.across ?? 1),
    along: influenceAlong * (role?.along ?? 1),
  );
}

/// A slot's defensive map in its own team's frame.
InfluenceMap defensiveInfluence(FormationSlot slot) {
  final weight = defenceWeights[slot.slotPosition] ?? 0.5;
  final p = slotPoint(slot);
  return influenceAround((
    x: p.x,
    y: p.y + weight * defenceDropBack,
  ), mass: weight);
}

/// The Gaussian itself, so a role or a tactic can move the anchor or widen
/// the spread and get the same normalisation.
InfluenceMap influenceAround(
  PitchPoint anchor, {
  required double mass,
  double across = influenceAcross,
  double along = influenceAlong,
}) {
  if (mass <= 0) return InfluenceMap.zero;
  final raw = List<double>.filled(pitchZones, 0);
  var total = 0.0;
  for (var z = 0; z < pitchZones; z++) {
    final c = zoneCentre(z);
    final dx = (c.x - anchor.x) / across;
    final dy = (c.y - anchor.y) / along;
    raw[z] = math.exp(-0.5 * (dx * dx + dy * dy));
    total += raw[z];
  }
  return InfluenceMap([for (final w in raw) w / total * mass]);
}


