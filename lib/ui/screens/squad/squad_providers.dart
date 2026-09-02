/// The squad, derived from the save.
///
/// Every number here is asked of an engine — `computeSquadRatings` for the
/// split, `cleanAndFillLineup` for the eleven, `benchCandidates` for the rest.
/// The screen is handed answers; it never works one out.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart'
    show suspendedIn;
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

  /// The injured man this slot belongs to, when nobody is standing in it.
  ///
  /// **A hole says a player is missing; it does not say WHICH.** So the subs
  /// panel keeps him on the pitch, rated zero and crossed through — he is worth
  /// nothing there whether he is drawn or not, and drawn is the version a
  /// manager can pick a replacement from. See `LineupSlot.vacatedBy`.
  CardView? vacatedBy,

  /// Who [vacatedBy] IS, by instance id.
  ///
  /// **The view alone was not enough.** A substitution's confirmation shows the
  /// two cards it is swapping and looks the outgoing man up by id — so on an
  /// INJURY, where the slot is already empty, it had nobody to show and fell
  /// back to the one-sided "{on} comes on" line. Reported from the couch: an
  /// injury sub should show the swap like every other one.
  String? vacatedById,
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

  // **WHO IS MISSING FROM WHERE.** An injury vacates its victim's slot, so the
  // subs panel could only draw a gap — a formation with a space in it says a
  // man is missing but not WHICH, on the one panel whose job is picking his
  // replacement.
  //
  // **DERIVED, not stored.** Stamping the lineup row would have been exact and
  // it put a field in the save that the JS does not write — twenty-two rows of
  // `match_orchestration_parity_test` compare that map field for field, and
  // they failed immediately. So this reads what is already true: an injured
  // card that is not in the eleven belongs in one of the holes, and the holes
  // are matched to them by POSITION first so a keeper's hole never shows an
  // injured striker.
  final picked = {
    for (final slot in lineup)
      if (slot.cardInstanceId != null) slot.cardInstanceId,
  };
  final orphans = <Map<String, dynamic>>[
    for (final raw in gridCells(s))
      if (raw is Map<String, dynamic> &&
          raw['injured'] == true &&
          !picked.contains(raw['instanceId']))
        raw,
  ];
  final holes = [
    for (final slot in lineup)
      if (slot.cardInstanceId == null) slot,
  ];
  final banned = suspendedIn(s);
  final ratios = definitionRatiosOf(s);
  final vacatedBy = <String, Map<String, dynamic>>{};
  for (final hole in holes) {
    if (orphans.isEmpty) break;
    final natural = orphans.indexWhere(
      (raw) => cardViewFor(raw, proMode: pro, definitionRatios: ratios)
              ?.position ==
          hole.slotPosition,
    );
    vacatedBy[hole.slotId] = orphans.removeAt(natural >= 0 ? natural : 0);
  }

  return [
    for (final slot in lineup)
      () {
        final geometry = shape[slot.slotId];
        final raw = slot.cardInstanceId == null
            ? null
            : byId[slot.cardInstanceId];
        // The bans, so the token can say a man cannot play. NOT the state —
        // that switches the income line on, which a pitch token has no room
        // for. See `cardViewFor.banned`.
        final view = cardViewFor(
          raw,
          proMode: pro,
          banned: banned,
          definitionRatios: ratios,
        );
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
          vacatedBy: view != null
              ? null
              : cardViewFor(
                  vacatedBy[slot.slotId],
                  proMode: pro,
                  definitionRatios: ratios,
                ),
          vacatedById: view != null
              ? null
              : vacatedBy[slot.slotId]?['instanceId'] as String?,
          // Named rather than punished here: the penalty is the engine's, and
          // the screen's job is to say WHY a rating looks low.
          outOfPosition: view != null && view.position != slot.slotPosition,
          // **ZERO IF HE CANNOT PLAY**, because that is what the sim scores him.
          // `computeSquadRating` zeroes an injured or unavailable man in the
          // lineup outright, and the token went on showing his card rating — so
          // the side the manager could see was not the side being played, and
          // the one number that should have said "change this" said the
          // opposite. `getCardStats` is right not to know: it rates a CARD, and
          // whether he can take the field is the lineup's question.
          effRating:
              instance != null &&
                  (instance.injured ||
                      instance.isUnavailable ||
                      (view?.suspended ?? false))
              ? 0
              : stats.rating,
          penalty: view == null
              ? 0.0
              : computePositionPenalty(view.position, slot.slotPosition),
          seasons: instance?.seasonsPlayed ?? 0,
        );
      }(),
  ];
});

/// Everyone not in the eleven.
/// The bench, ordered FOR A SLOT.
///
/// **A bench in grid order is a bench in no order at all.** It came off the grid
/// cells as they happened to be laid out, so the man who plays where the hole is
/// could be anywhere in it — reported when the subs panel comes up, which is the
/// one moment a manager is reading the bench against the clock.
///
/// Two keys, in this order: whether he plays THERE, then how good he is. So the
/// natural replacements lead, best first, and the rest follow in the same order
/// — which is what "best matches first, then the rest in best order" asks for.
/// A null slot position is a bench nobody is filling a hole from, and it sorts
/// on rating alone.
///
/// Fitness is deliberately NOT a key. It is null in casual play, and in Pro a
/// tired specialist is still the man for the slot — the panel already draws the
/// bar, and the decision is the manager's.
final benchForSlotProvider =
    Provider.family<List<({String instanceId, CardView card})>, String?>((
      ref,
      slotPosition,
    ) {
      final bench = [...ref.watch(benchProvider)];
      bench.sort((a, b) {
        if (slotPosition != null) {
          final natural =
              (a.card.position == slotPosition ? 0 : 1) -
              (b.card.position == slotPosition ? 0 : 1);
          if (natural != 0) return natural;
        }
        return b.card.rating.compareTo(a.card.rating);
      });
      return bench;
    });

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
          cardViewFor(
                raw,
                proMode: pro,
                definitionRatios: definitionRatiosOf(s),
              ) !=
              null)
        (
          instanceId: raw['instanceId'] as String,
          card: cardViewFor(
            raw,
            proMode: pro,
            banned: suspendedIn(s),
            definitionRatios: definitionRatiosOf(s),
          )!,
        ),
  ];
});

final squadRatingsProvider = savePick<SquadRatings>((s) {
  final cards = _cards(s);
  final lineup = lineupFor(s);
  // **A BANNED MAN IS AN EMPTY SLOT to the number on the header.** Reported
  // from the couch, from the other end: sending a suspended player on made the
  // squad rating go UP. `computeSquadRatings` zeroes an injured or unavailable
  // one, but a ban is the port's own idea and not the JS's — that function is
  // compared field for field by the parity harness, so the suspension is
  // applied HERE, by handing it a hole where he stands. Which is what the sim
  // fields anyway.
  final banned = suspendedIn(s);
  final asMaps = [
    for (final slot in lineup)
      <String, dynamic>{
        'slotId': slot.slotId,
        'slotPosition': slot.slotPosition,
        'cardInstanceId': banned.contains(slot.cardInstanceId)
            ? null
            : slot.cardInstanceId,
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
    final view = cardViewFor(
      raw,
      proMode: pro,
      definitionRatios: ratios,
    );
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
