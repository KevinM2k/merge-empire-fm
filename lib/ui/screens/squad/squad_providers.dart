/// The squad, derived from the save.
///
/// Every number here is asked of an engine — `computeSquadRatings` for the
/// split, `cleanAndFillLineup` for the eleven, `benchCandidates` for the rest.
/// The screen is handed answers; it never works one out.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/fixture_preview.dart';
import 'package:merge_empire_fc/engine/lineup_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/stat_display.dart';
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

  /// What this player is worth IN THIS SLOT, fatigue included — not their card
  /// rating. A striker at left back is the same card and a different player, and
  /// the number on the token is the one the sim will use.
  int effRating,

  /// How much the slot costs them, 0 for a natural fit. Drives the token's
  /// green/amber/red, so a misfit is visible without doing the arithmetic.
  double penalty,

  /// Seasons played — the age tell, amber at ten and red at fourteen.
  int seasons,
});

/// The squad's headline numbers.
typedef SquadRatings = ({
  int overall,
  int attack,
  int defence,

  /// Under the division's opponent range — the answer to "why do I keep losing".
  bool belowPar,

  /// Over it. Worth its own flag rather than `!belowPar`: a side INSIDE the range
  /// is neither losing nor ready to go up, and painting that green told a
  /// mid-table squad it was fine.
  bool aboveRange,
});

/// The tactic's multipliers against the fixture actually being prepared for.
///
/// Counter Attack's attack multiplier keys off how committed forward the
/// opponent is, so the Squad screen — the screen where the tactic is PICKED —
/// has to price it against the next opponent, or the number moves the moment
/// the game kicks off. Falls back to the flat table when there is no fixture to
/// read.
({double atk, double def}) squadTacticMultipliers(Map<String, dynamic>? s) {
  final id = _map(s?['squad'])?['strategyId'];
  final strat =
      strategies[id is String ? id : defaultStrategy] ??
      strategies[defaultStrategy]!;
  return tacticMultipliers(strat, previewFixture(s)?.oppAttackRatio);
}

List<CardInstance?> _cards(Map<String, dynamic> s) => [
  for (final raw in gridCells(s)) CardInstance.from(raw),
];

String _formationId(Map<String, dynamic> s) =>
    _map(s['squad'])?['formation'] as String? ?? defaultFormation;

final formationIdProvider = savePick<String>(_formationId);

/// The saved eleven, cleaned of anyone sold, listed or loaned out.
///
/// CLEANED, not refilled. Topping the gaps up here would make a deliberately
/// empty slot impossible — see `cleanLineup`. The refill happens on the events
/// that change the squad, in `syncLineupWithGrid`.
List<LineupSlot> lineupFor(Map<String, dynamic> s) {
  final saved = _map(s['squad'])?['lineup'];
  final formationId = _formationId(s);
  final cards = _cards(s);
  if (saved is! List) return buildDefaultLineup(formationId, cards);
  return cleanLineup([
    for (final row in saved)
      if (row is Map<String, dynamic>)
        LineupSlot(
          slotId: row['slotId'] as String? ?? '',
          slotPosition: row['slotPosition'] as String? ?? 'MID',
          cardInstanceId: row['cardInstanceId'] as String?,
        ),
  ], cards);
}

final pitchSlotsProvider = savePick<List<PitchSlot>>((s) {
  final lineup = lineupFor(s);
  final byId = {
    for (final raw in gridCells(s))
      if (raw is Map<String, dynamic> && raw['instanceId'] is String)
        raw['instanceId'] as String: raw,
  };
  final shape = {
    for (final slot in getFormation(_formationId(s)).slots) slot.slotId: slot,
  };
  final pro = isProMode(s);

  return [
    for (final slot in lineup)
      () {
        final geometry = shape[slot.slotId];
        final raw = slot.cardInstanceId == null
            ? null
            : byId[slot.cardInstanceId];
        final view = cardViewFor(raw, proMode: pro);
        final instance = CardInstance.from(raw);
        final stats = getCardStats(
          instance,
          slotPosition: slot.slotPosition,
          definitionRatios: _map(s['definitionRatios']) ?? const {},
          fatigue: true,
        );
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
          effRating: stats.rating,
          penalty: view == null
              ? 0.0
              : computePositionPenalty(view.position, slot.slotPosition),
          seasons: instance?.seasonsPlayed ?? 0,
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
  final pro = isProMode(s);
  return [
    for (final raw in gridCells(s))
      if (raw is Map<String, dynamic> &&
          !picked.contains(raw['instanceId']) &&
          cardViewFor(raw, proMode: pro) != null)
        (
          instanceId: raw['instanceId'] as String,
          card: cardViewFor(raw, proMode: pro)!,
        ),
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

  // The printed ATK and DEF carry the TACTIC, exactly as the sim's do. Without
  // this the picker wrote a value to the save and nothing on the screen moved,
  // so every tactic looked like it did nothing — the one number that says what
  // a tactic buys was showing the untouched base.
  final mult = squadTacticMultipliers(s);
  final tuned = fifaSplitTactic(
    split.attack,
    split.defence,
    mult.atk,
    mult.def,
  );

  // Below the division's opponent range is the one thing worth colouring: it is
  // the answer to "why do I keep losing".
  final division = getDivision(
    _map(s['progression'])?['currentDivision'] as String? ?? divisions.first.id,
  );
  return (
    overall: overall,
    attack: tuned.atk,
    defence: tuned.def,
    belowPar: overall < division.opponentRatingRange.$1,
    aboveRange: overall > division.opponentRatingRange.$2,
  );
});

/// A candidate for one slot: who they are, and what they are worth THERE.
typedef SlotCandidate = ({
  String instanceId,
  CardView card,
  int effRating,
  double penalty,
  int seasons,
});

/// Everyone who could take [slotPosition], best-for-that-slot first.
///
/// Ordered by the EFFECTIVE rating rather than the card rating: a 78 striker at
/// left back is worth less there than a 70 defender, and a list sorted by card
/// rating puts the wrong man at the top.
///
/// `isSelectable` is the filter, not `!injured`. A loaned-out player is at
/// another club and a listed one is advertised; the match engine rates both
/// zero, so offering either let a manager field a hole in the side.
final slotCandidatesProvider = Provider.family<List<SlotCandidate>, String>((
  Ref ref,
  String slotPosition,
) {
  ref.watch(saveRevisionProvider);
  final s = ref.watch(gameProvider).state;
  if (s == null) return const <SlotCandidate>[];
  final picked = {
    for (final slot in lineupFor(s))
      if (slot.cardInstanceId != null) slot.cardInstanceId,
  };
  final pro = isProMode(s);
  final ratios = _map(s['definitionRatios']) ?? const <String, dynamic>{};

  final out = <SlotCandidate>[];
  for (final raw in gridCells(s)) {
    if (raw is! Map<String, dynamic>) continue;
    final id = raw['instanceId'];
    if (id is! String || picked.contains(id)) continue;
    final instance = CardInstance.from(raw);
    if (instance == null || !instance.isSelectable) continue;
    final view = cardViewFor(raw, proMode: pro);
    if (view == null) continue;
    out.add((
      instanceId: id,
      card: view,
      effRating: getCardStats(
        instance,
        slotPosition: slotPosition,
        definitionRatios: ratios,
        fatigue: true,
      ).rating,
      penalty: computePositionPenalty(view.position, slotPosition),
      seasons: instance.seasonsPlayed,
    ));
  }
  out.sort((a, b) => b.effRating - a.effRating);
  return out;
});
