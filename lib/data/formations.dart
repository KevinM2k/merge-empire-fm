/// Formation shapes and the lineup operations that need no ratings, ported from
/// `../merge-empire-fc/src/data/formations.js`.
///
/// The JS file also holds `buildDefaultLineup` and `fillLineupGaps`, which score
/// players by effective rating and fatigue. Those pull in `traitEngine`,
/// `sponsorEngine` and `playerEnergyEngine`, so in this port they live in the
/// engine layer and this file stays pure data plus pure list surgery.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/state/card_instance.dart';

/// One position on the pitch. [x] and [y] are percentages of the pitch box,
/// with y growing toward our own goal — so the keeper has the largest y.
class FormationSlot {
  const FormationSlot({
    required this.slotId,
    required this.slotPosition,
    required this.x,
    required this.y,
  });

  final String slotId;
  final String slotPosition;
  final int x;
  final int y;
}

class Formation {
  const Formation({
    required this.id,
    required this.label,
    required this.style,
    required this.slots,
  });

  final String id;
  final String label;
  final String style;
  final List<FormationSlot> slots;
}

/// One entry in a saved lineup: which card, if any, occupies a slot.
class LineupSlot {
  const LineupSlot({
    required this.slotId,
    required this.slotPosition,
    required this.cardInstanceId,
  });

  final String slotId;
  final String slotPosition;
  final String? cardInstanceId;

  LineupSlot copyWith({String? cardInstanceId, bool clearCard = false}) =>
      LineupSlot(
        slotId: slotId,
        slotPosition: slotPosition,
        cardInstanceId: clearCard
            ? null
            : (cardInstanceId ?? this.cardInstanceId),
      );

  @override
  String toString() => 'LineupSlot($slotId, $slotPosition, $cardInstanceId)';
}

/// **Two shapes diverge from `formations.js` on purpose**, and both are marked
/// where they do: 4-2-3-1's five bands and 5-3-2's back five are packed closer
/// together in the JS than a token is big, so they overlapped on screen. The
/// numbers are display-only — nothing in the sim reads `x` or `y` — and
/// `pitchTokenScale` in `pitch_token.dart` is what guarantees the rest of the
/// set, including any shape added later.
const Map<String, Formation> formations = {
  '4-3-3': Formation(
    id: '4-3-3',
    label: '4-3-3',
    style: 'attacking',
    slots: [
      FormationSlot(slotId: 'gk', slotPosition: 'GK', x: 50, y: 90),
      FormationSlot(slotId: 'rb', slotPosition: 'DEF', x: 14, y: 66),
      FormationSlot(slotId: 'rcb', slotPosition: 'DEF', x: 38, y: 66),
      FormationSlot(slotId: 'lcb', slotPosition: 'DEF', x: 62, y: 66),
      FormationSlot(slotId: 'lb', slotPosition: 'DEF', x: 86, y: 66),
      FormationSlot(slotId: 'rm', slotPosition: 'MID', x: 20, y: 42),
      FormationSlot(slotId: 'cm', slotPosition: 'MID', x: 50, y: 42),
      FormationSlot(slotId: 'lm', slotPosition: 'MID', x: 80, y: 42),
      FormationSlot(slotId: 'rf', slotPosition: 'FWD', x: 20, y: 18),
      FormationSlot(slotId: 'cf', slotPosition: 'FWD', x: 50, y: 18),
      FormationSlot(slotId: 'lf', slotPosition: 'FWD', x: 80, y: 18),
    ],
  ),
  '4-4-2': Formation(
    id: '4-4-2',
    label: '4-4-2',
    style: 'balanced',
    slots: [
      FormationSlot(slotId: 'gk', slotPosition: 'GK', x: 50, y: 90),
      FormationSlot(slotId: 'rb', slotPosition: 'DEF', x: 14, y: 66),
      FormationSlot(slotId: 'rcb', slotPosition: 'DEF', x: 38, y: 66),
      FormationSlot(slotId: 'lcb', slotPosition: 'DEF', x: 62, y: 66),
      FormationSlot(slotId: 'lb', slotPosition: 'DEF', x: 86, y: 66),
      FormationSlot(slotId: 'rm', slotPosition: 'MID', x: 14, y: 42),
      FormationSlot(slotId: 'rcm', slotPosition: 'MID', x: 38, y: 42),
      FormationSlot(slotId: 'lcm', slotPosition: 'MID', x: 62, y: 42),
      FormationSlot(slotId: 'lm', slotPosition: 'MID', x: 86, y: 42),
      FormationSlot(slotId: 'rs', slotPosition: 'FWD', x: 38, y: 18),
      FormationSlot(slotId: 'ls', slotPosition: 'FWD', x: 62, y: 18),
    ],
  ),
  // **FIVE bands, not four**, and the only shape in the set with five. The JS
  // packs them at 90 / 66 / 50 / 34 / 18 — a 24 to the keeper and then three 16s
  // — and 16% of the pitch is LESS than a token is tall, so the defence, the
  // holding pair and the three ahead of them literally overlapped.
  //
  // Spread evenly over the room the shape has instead: the defence drops back
  // toward the keeper and the forward comes up, which buys four equal 19s. That
  // is the widest even spacing available — a band centre has to stay half a token
  // clear of the touchline, which puts the keeper at 90 and the striker at 14.
  '4-2-3-1': Formation(
    id: '4-2-3-1',
    label: '4-2-3-1',
    style: 'balanced',
    slots: [
      FormationSlot(slotId: 'gk', slotPosition: 'GK', x: 50, y: 90),
      FormationSlot(slotId: 'rb', slotPosition: 'DEF', x: 14, y: 71),
      FormationSlot(slotId: 'rcb', slotPosition: 'DEF', x: 38, y: 71),
      FormationSlot(slotId: 'lcb', slotPosition: 'DEF', x: 62, y: 71),
      FormationSlot(slotId: 'lb', slotPosition: 'DEF', x: 86, y: 71),
      FormationSlot(slotId: 'rdm', slotPosition: 'MID', x: 37, y: 52),
      FormationSlot(slotId: 'ldm', slotPosition: 'MID', x: 63, y: 52),
      FormationSlot(slotId: 'rw', slotPosition: 'MID', x: 15, y: 33),
      FormationSlot(slotId: 'am', slotPosition: 'MID', x: 50, y: 33),
      FormationSlot(slotId: 'lw', slotPosition: 'MID', x: 85, y: 33),
      FormationSlot(slotId: 'cf', slotPosition: 'FWD', x: 50, y: 14),
    ],
  ),
  '5-3-2': Formation(
    id: '5-3-2',
    label: '5-3-2',
    style: 'defensive',
    slots: [
      FormationSlot(slotId: 'gk', slotPosition: 'GK', x: 50, y: 90),
      // **Widened from 14–86 to 10–90.** Five across one band is the tightest
      // row in the game and the JS's 18-unit gaps are narrower than a token,
      // so the back five overlapped each other. The full-back stops where
      // 3-5-2's wing-backs already stand, which is as far out as a token can go
      // and stay on the grass.
      FormationSlot(slotId: 'rb', slotPosition: 'DEF', x: 10, y: 66),
      FormationSlot(slotId: 'rcb', slotPosition: 'DEF', x: 30, y: 66),
      FormationSlot(slotId: 'cb', slotPosition: 'DEF', x: 50, y: 66),
      FormationSlot(slotId: 'lcb', slotPosition: 'DEF', x: 70, y: 66),
      FormationSlot(slotId: 'lb', slotPosition: 'DEF', x: 90, y: 66),
      FormationSlot(slotId: 'rm', slotPosition: 'MID', x: 25, y: 42),
      FormationSlot(slotId: 'cm', slotPosition: 'MID', x: 50, y: 42),
      FormationSlot(slotId: 'lm', slotPosition: 'MID', x: 75, y: 42),
      FormationSlot(slotId: 'rs', slotPosition: 'FWD', x: 37, y: 18),
      FormationSlot(slotId: 'ls', slotPosition: 'FWD', x: 63, y: 18),
    ],
  ),
  '3-5-2': Formation(
    id: '3-5-2',
    label: '3-5-2',
    style: 'attacking',
    slots: [
      FormationSlot(slotId: 'gk', slotPosition: 'GK', x: 50, y: 90),
      FormationSlot(slotId: 'rcb', slotPosition: 'DEF', x: 25, y: 66),
      FormationSlot(slotId: 'cb', slotPosition: 'DEF', x: 50, y: 66),
      FormationSlot(slotId: 'lcb', slotPosition: 'DEF', x: 75, y: 66),
      FormationSlot(slotId: 'rwb', slotPosition: 'MID', x: 10, y: 36),
      FormationSlot(slotId: 'rcm', slotPosition: 'MID', x: 30, y: 42),
      FormationSlot(slotId: 'cm', slotPosition: 'MID', x: 50, y: 46),
      FormationSlot(slotId: 'lcm', slotPosition: 'MID', x: 70, y: 42),
      FormationSlot(slotId: 'lwb', slotPosition: 'MID', x: 90, y: 36),
      FormationSlot(slotId: 'rs', slotPosition: 'FWD', x: 37, y: 18),
      FormationSlot(slotId: 'ls', slotPosition: 'FWD', x: 63, y: 18),
    ],
  ),
};

const String defaultFormation = '4-3-3';

/// The lineup as the SAVE holds it.
///
/// Shared because three callers write it — the migration, the squad screen and
/// the wiring that keeps it in step with the grid — and three copies of the key
/// names is three chances to spell one of them differently.
List<Map<String, dynamic>> encodeLineup(List<LineupSlot> slots) => [
  for (final slot in slots)
    <String, dynamic>{
      'slotId': slot.slotId,
      'slotPosition': slot.slotPosition,
      'cardInstanceId': slot.cardInstanceId,
    },
];

/// Read a saved lineup back.
List<LineupSlot> decodeLineup(Object? raw) => [
  if (raw is List)
    for (final row in raw)
      if (row is Map<String, dynamic>)
        LineupSlot(
          slotId: row['slotId'] as String? ?? '',
          slotPosition: row['slotPosition'] as String? ?? 'MID',
          cardInstanceId: row['cardInstanceId'] as String?,
        ),
];

Formation getFormation(String? id) =>
    formations[id] ?? formations[defaultFormation]!;

/// Who the in-match subs panel may put on the bench: everyone in the grid not
/// already on the pitch who could actually take the field.
///
/// Injured players are deliberately KEPT — the panel renders them greyed with
/// the reason, and the manager is usually there because someone limped off, so
/// seeing who else is unavailable is the point. Unavailable players are DROPPED:
/// they are at another club or advertised for sale, not at the ground. Offering
/// one spent a substitution to put a zero-rated ghost on the pitch.
List<CardInstance> benchCandidates(
  List<CardInstance?> gridCells,
  List<LineupSlot> lineup,
) {
  final onIds = {
    for (final s in lineup)
      if (s.cardInstanceId != null) s.cardInstanceId,
  };
  return [
    for (final c in gridCells)
      if (c != null && !onIds.contains(c.instanceId) && !c.isUnavailable) c,
  ];
}

/// Preserve existing position assignments when switching formations. Cards that
/// fit the new shape's positions keep their role; the rest fall into whatever
/// slots remain rather than being dropped.
List<LineupSlot> migrateLineup(
  List<LineupSlot> fromLineup,
  String toFormationId,
) {
  final newSlots = getFormation(toFormationId).slots;

  // Group the old lineup's cards by the position they were playing.
  final oldByPos = <String, List<String>>{
    'GK': [],
    'DEF': [],
    'MID': [],
    'FWD': [],
  };
  for (final slot in fromLineup) {
    final id = slot.cardInstanceId;
    if (id != null && oldByPos.containsKey(slot.slotPosition)) {
      oldByPos[slot.slotPosition]!.add(id);
    }
  }

  final used = <String>{};

  // First pass: fill each slot with a position-matched card.
  final result = <LineupSlot>[];
  for (final slot in newSlots) {
    final pool = oldByPos[slot.slotPosition] ?? const <String>[];
    String? picked;
    for (final id in pool) {
      if (!used.contains(id)) {
        picked = id;
        break;
      }
    }
    if (picked != null) used.add(picked);
    result.add(
      LineupSlot(
        slotId: slot.slotId,
        slotPosition: slot.slotPosition,
        cardInstanceId: picked,
      ),
    );
  }

  // Second pass: anyone in the old lineup not yet placed takes an empty slot,
  // so changing shape never quietly drops a player.
  final leftover = [
    for (final s in fromLineup)
      if (s.cardInstanceId != null && !used.contains(s.cardInstanceId))
        s.cardInstanceId!,
  ];

  for (var i = 0; i < result.length && leftover.isNotEmpty; i++) {
    if (result[i].cardInstanceId == null) {
      result[i] = result[i].copyWith(cardInstanceId: leftover.removeAt(0));
    }
  }

  return result;
}
