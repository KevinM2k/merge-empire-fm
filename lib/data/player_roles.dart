/// Roles a manager can give a wide player, and what each does to where he
/// attacks.
///
/// **New to the port** — the JS has no roles. A role moves the ATTACKING
/// ANCHOR the positional sim builds a player's influence around (see
/// `engine/pitch_influence.dart`): where on the pitch his work lands. It never
/// touches a rating. A winger is not a better player than an inside forward;
/// he is the same player standing somewhere else when the ball comes.
///
/// Three, all on WIDE slots — a winger, an inside forward and a wide
/// playmaker — because the flank is where a role is most visible on a heatmap
/// and where the brief asked for it. A slot is wide when it is a midfielder's
/// or a forward's and sits in the outer quarter of the pitch either side;
/// central slots and the back line take no role and the sheet offers none.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/formations.dart';

/// One role's pull on the attacking anchor, in frame units (0–100 across,
/// 0–100 along — see `engine/pitch_space.dart`).
class PlayerRole {
  const PlayerRole({
    required this.id,
    required this.inward,
    required this.forward,
    this.across = 1,
    this.along = 1,
  });

  final String id;

  /// Toward the centre line: positive comes inside, negative hugs the touchline.
  final double inward;

  /// Toward the goal he attacks: positive higher, negative deeper.
  final double forward;

  /// Multipliers on the map's spread across and along the pitch.
  final double across;
  final double along;
}

/// The save's word for no role: the slot's own anchor, untouched.
const String naturalRole = 'natural';

const Map<String, PlayerRole> playerRoles = {
  // Stays wide and gets to the byline: outside and a touch higher.
  'winger': PlayerRole(id: 'winger', inward: -6, forward: 4, across: 0.9),
  // Cuts in off the flank into the half-space and the box.
  'insideForward': PlayerRole(id: 'insideForward', inward: 14, forward: 5),
  // Drops in to build, so he is on the ball a band earlier and more widely.
  'widePlaymaker': PlayerRole(
    id: 'widePlaymaker',
    inward: 6,
    forward: -8,
    across: 1.2,
    along: 1.3,
  ),
};

/// The ids a save may hold, the natural setting first.
final List<String> roleIds = [naturalRole, ...playerRoles.keys];

/// Whether a slot may carry a role.
bool isWideSlot(FormationSlot slot) =>
    slot.slotPosition != 'GK' &&
    slot.slotPosition != 'DEF' &&
    (slot.x <= 25 || slot.x >= 75);

/// The role a save gives [slotId], or null for none or nonsense.
PlayerRole? roleFor(Map<String, dynamic>? roles, String slotId) {
  final id = roles?[slotId];
  return id is String ? playerRoles[id] : null;
}

/// `state['squad']['roles']` as a clean slotId → roleId map, dropping anything
/// that is not a known role.
Map<String, String> rolesOf(Map<String, dynamic>? squad) {
  final raw = squad?['roles'];
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.value is String && playerRoles.containsKey(e.value))
        '${e.key}': e.value as String,
  };
}
