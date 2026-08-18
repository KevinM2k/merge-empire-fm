/// The squad, derived from the save.
///
/// Every number here is asked of an engine — `computeSquadRatings` for the
/// split, `cleanAndFillLineup` for the eleven, `benchCandidates` for the rest.
/// The screen is handed answers; it never works one out.
library;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// One place on the pitch: where it sits, what it wants, and who is in it.
typedef PitchSlot = ({
  String slotId,
  String slotPosition,
  int x,
  int y,
  String? cardInstanceId,
  CardView? card,
  bool outOfPosition,
});

/// The squad's headline numbers.
typedef SquadRatings = ({int overall, int attack, int defence, bool belowPar});

List<CardInstance?> _cards(Map<String, dynamic> s) => [
  for (final raw in gridCells(s)) CardInstance.from(raw),
];

String _formationId(Map<String, dynamic> s) =>
    _map(s['squad'])?['formation'] as String? ?? defaultFormation;

final formationIdProvider = savePick<String>(_formationId);

/// The saved eleven, cleaned of anyone sold, listed or loaned out, and topped
/// up from the bench — which is what stops an empty slot surviving a transfer.
List<LineupSlot> lineupFor(Map<String, dynamic> s) {
  final saved = _map(s['squad'])?['lineup'];
  final formationId = _formationId(s);
  final cards = _cards(s);
  if (saved is! List) return buildDefaultLineup(formationId, cards);
  return cleanAndFillLineup(
    [
      for (final row in saved)
        if (row is Map<String, dynamic>)
          LineupSlot(
            slotId: row['slotId'] as String? ?? '',
            slotPosition: row['slotPosition'] as String? ?? 'MID',
            cardInstanceId: row['cardInstanceId'] as String?,
          ),
    ],
    formationId,
    cards,
  );
}

final pitchSlotsProvider = savePick<List<PitchSlot>>((s) {
  final lineup = lineupFor(s);
  final byId = {
    for (final raw in gridCells(s))
      if (raw is Map<String, dynamic> && raw['instanceId'] is String)
        raw['instanceId'] as String: raw,
  };
  final shape = {for (final slot in getFormation(_formationId(s)).slots) slot.slotId: slot};

  return [
    for (final slot in lineup)
      () {
        final geometry = shape[slot.slotId];
        final raw = slot.cardInstanceId == null ? null : byId[slot.cardInstanceId];
        final view = cardViewFor(raw);
        return (
          slotId: slot.slotId,
          slotPosition: slot.slotPosition,
          x: geometry?.x ?? 50,
          y: geometry?.y ?? 50,
          cardInstanceId: slot.cardInstanceId,
          card: view,
          // Named rather than punished here: the penalty is the engine's, and
          // the screen's job is to say WHY a rating looks low.
          outOfPosition: view != null && view.position != slot.slotPosition,
        );
      }(),
  ];
});

/// Everyone not in the eleven.
final benchProvider = savePick<List<({String instanceId, CardView card})>>((s) {
  final lineup = lineupFor(s);
  final picked = {
    for (final slot in lineup)
      if (slot.cardInstanceId != null) slot.cardInstanceId,
  };
  return [
    for (final raw in gridCells(s))
      if (raw is Map<String, dynamic> &&
          !picked.contains(raw['instanceId']) &&
          cardViewFor(raw) != null)
        (instanceId: raw['instanceId'] as String, card: cardViewFor(raw)!),
  ];
});

final squadRatingsProvider = savePick<SquadRatings>((s) {
  final cards = _cards(s);
  final lineup = lineupFor(s);
  final asMaps = [
    for (final slot in lineup)
      <String, dynamic>{
        'slotId': slot.slotId,
        'slotPosition': slot.slotPosition,
        'cardInstanceId': slot.cardInstanceId,
      },
  ];
  final eleven = asMaps.length == 11 ? asMaps : null;
  final split = computeSquadRatings(cards, lineup: eleven, fatigue: true);
  final overall = computeSquadRating(cards, lineup: eleven, fatigue: true);

  // Below the division's opponent range is the one thing worth colouring: it is
  // the answer to "why do I keep losing".
  final division = getDivision(
    _map(s['progression'])?['currentDivision'] as String? ?? divisions.first.id,
  );
  return (
    overall: overall,
    attack: split.attack,
    defence: split.defence,
    belowPar: overall < division.opponentRatingRange.$1,
  );
});
