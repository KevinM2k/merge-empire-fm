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

import 'dart:math' as math;

import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/data/player_roles.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/pitch_influence.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

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

  /// The side's own position-weighted ATK/DEF — the same weighting
  /// `weightedTeamSplit` uses, unrounded and over the players present.
  ({double attack, double defence}) get teamMeans {
    var aNum = 0.0, aDen = 0.0, dNum = 0.0, dDen = 0.0;
    for (final p in players) {
      final aw = attackWeights[p.slotPosition] ?? 0.5;
      final dw = defenceWeights[p.slotPosition] ?? 0.5;
      aNum += p.attack * aw;
      aDen += aw;
      dNum += p.defence * dw;
      dDen += dw;
    }
    return (
      attack: aDen > 0 ? aNum / aDen : 0,
      defence: dDen > 0 ? dNum / dDen : 0,
    );
  }

  /// Scale so the side's means land on the TEAM figures the goal model was
  /// handed. Nothing to scale from leaves it alone.
  PitchSide scaledToTeam({required double attack, required double defence}) {
    final m = teamMeans;
    return scaled(
      attack: m.attack > 0 ? attack / m.attack : 1,
      defence: m.defence > 0 ? defence / m.defence : 1,
    );
  }
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
/// booking; it multiplies both stats. [roles] is `squad['roles']` cleaned by
/// `rolesOf`: a role on a wide slot moves that player's attacking anchor and
/// nothing else — see `data/player_roles.dart`.
PitchSide pitchSideFromLineup({
  required List<CardInstance> cards,
  required List<Map<String, dynamic>> lineup,
  required List<FormationSlot> slots,
  Map<String, dynamic> definitionRatios = const {},
  double Function(CardInstance card)? scale,
  bool mirrored = false,
  Map<String, String> roles = const {},
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
        role: isWideSlot(slot) ? playerRoles[roles[slot.slotId]] : null,
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
  PlayerRole? role,
}) {
  // The maps are a property of the SLOT position, not the card's — a striker
  // parked at centre-back attacks from where a centre-back stands.
  final placed = FormationSlot(
    slotId: slot.slotId,
    slotPosition: slotPosition,
    x: slot.x,
    y: slot.y,
  );
  var atk = attackingInfluence(placed, role: role);
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

// ── The attack ───────────────────────────────────────────────────────────────

/// Attacks one side mounts over a full ninety. With a start in the middle two
/// bands and roughly even duels, about a fifth of them end in a shot, which
/// lands both sides together on the ~13 shots a match the feed was already
/// showing before any of this existed — the figure to preserve.
const int attacksPerMatch = 34;

/// Duels an attack may take before it fizzles. Band 2 to a shot is three.
const int maxSequenceSteps = 4;

/// Prior chance a won duel carries the ball a lane across rather than
/// straight on, before the attackers ahead pull it — see [laneAttraction].
const double laneSwitchChance = 0.35;

/// How far the ball goes where the attackers are, 0..1.
///
/// After a won duel the next zone is one of three — straight on or a lane
/// either side — and the prior above is bent by the carrier weight waiting in
/// each: at 1 a lane with twice the mean attacking presence is twice as likely,
/// at 0 the lane is a coin flip. This is the mechanism by which a star winger
/// pulls his side's play down his flank rather than merely finishing what
/// arrives there; `positional_balance_test` asserts the shift.
const double laneAttraction = 1.0;

/// No single shot is ever a certainty. λ past what the shots can carry is
/// rolled as plain Poisson on top — see [calibrateShots].
const double shotCap = 0.95;

/// How much the other defenders in a zone stiffen the one who meets the ball.
/// **Zero until Phase 7**: the hook is here so turning it on is a constant and
/// a tuning pass. The combination is saturating — see [effectiveDefence] — so
/// a crowded zone cannot manufacture a defender better than any real one.
const double supportCoeff = 0.0;

/// Raw xG of a shot from each lane of the band in front of goal, before the
/// shooter's own quality. Central is worth three times wide; the calibration
/// rescales all of it, so only the ratios matter.
const List<double> shotZoneQuality = [0.10, 0.20, 0.32, 0.20, 0.10];

/// One recorded step: a duel or a shot, where, by whom, against whom, and how
/// it went. `outcome` is `win`/`lose` for a duel and `goal`/`miss`/`blocked`
/// for a shot; a shot's `xg` is the CALIBRATED probability it was rolled at.
///
/// Serialised by [toMap] as short keys, because a match records a couple of
/// hundred of these and the match screen holds the whole list.
class PositionalEvent {
  PositionalEvent({
    required this.minute,
    required this.zone,
    required this.side,
    required this.playerId,
    required this.type,
    required this.outcome,
    this.opponentId,
    this.xg,
  });

  final int minute;
  final int zone;

  /// `ours` or `theirs`. Zones are ALWAYS in our frame, whichever side acted.
  final String side;
  final String playerId;
  final String? opponentId;

  /// `duel` or `shot`.
  final String type;
  String outcome;
  double? xg;

  Map<String, dynamic> toMap() => {
    'm': minute,
    'z': zone,
    's': side,
    'p': playerId,
    if (opponentId != null) 'op': opponentId,
    't': type,
    'o': outcome,
    if (xg != null) 'xg': (xg! * 1000).round() / 1000,
  };
}

/// A shot that got away: the event it is recorded as, who took it, and what
/// it was worth before calibration.
class Shot {
  const Shot({required this.event, required this.shooter, required this.rawXg});

  final PositionalEvent event;
  final PitchPlayer shooter;
  final double rawXg;
}

/// Who is attacking whom, and which way.
class SequenceContext {
  SequenceContext({
    required this.attackers,
    required this.defenders,
    required this.side,
    List<double>? laneBias,
  }) : laneBias = laneBias ?? const [1, 1, 1, 1, 1],
       assert(laneBias == null || laneBias.length == pitchLanes);

  final PitchSide attackers;
  final PitchSide defenders;

  /// `ours` attacks toward band 0; `theirs` toward band 3.
  final String side;

  /// Per-lane multiplier on where attacks start. Phase 5's side bias.
  final List<double> laneBias;

  bool get towardZero => side == 'ours';

  /// The band a shot is taken from.
  int get shotBand => towardZero ? 0 : pitchBands - 1;
}

/// The side-bias dial, as `state['squad']['attackSide']` spells it.
const List<String> attackSides = ['balanced', 'left', 'centre', 'right'];
const String defaultAttackSide = 'balanced';

/// The save's setting, or balanced for anything it does not spell.
String attackSideOf(Map<String, dynamic>? squad) {
  final v = squad?['attackSide'];
  return v is String && attackSides.contains(v) ? v : defaultAttackSide;
}

/// Per-lane multipliers on where our attacks START, for a setting of the dial.
///
/// A committed side puts sixty per cent of the starts down that flank,
/// twenty-five through the middle and fifteen down the far side — the brief's
/// split — written as multipliers on an even fifth a lane, so they bend the
/// side's own presence rather than replace it. Centre puts the sixty in the one
/// middle lane. Balanced is ones. Where attacks start is all it moves: a duel
/// is still a duel, and the goals are still λ's.
List<double> laneBiasFor(String? side) => switch (side) {
  'right' => const [1.5, 1.5, 1.25, 0.375, 0.375],
  'left' => const [0.375, 0.375, 1.25, 1.5, 1.5],
  'centre' => const [0.5, 0.5, 3.0, 0.5, 0.5],
  _ => const [1, 1, 1, 1, 1],
};

/// The defender's number once the others in the zone are counted. Saturating
/// in the support, so ten men in a box are worth a bounded lift, not ten men.
double effectiveDefence(double defence, double support) =>
    defence * (1 + supportCoeff * (1 - math.exp(-math.max(0, support))));

/// Where attacks begin: the middle two bands, weighted by the attackers'
/// presence and the lane bias.
List<double> startZoneWeights(SequenceContext ctx) => [
  for (var z = 0; z < pitchZones; z++)
    (zoneBand(z) == 1 || zoneBand(z) == 2)
        ? ctx.attackers.attackingPresence[z] * ctx.laneBias[zoneLane(z)]
        : 0.0,
];

/// Raw xG of a shot from [zone] by [shooter]: the lane's quality times the
/// shooter's own, a 70 taking it at par.
double rawShotXg(int zone, PitchPlayer shooter) =>
    shotZoneQuality[zoneLane(zone)] * (0.5 + shooter.attack / 100);

/// One attack, drawn from the SEEDED stream, appended to [out] step by step.
/// Returns the shot it ended in, or null for a turnover, a block or a fizzle.
///
/// Draw order per attack: start zone, carrier, then per step the defender,
/// the duel, and after a won duel outside the shot band the next zone and
/// the next carrier. Nothing else in the match may draw between them.
Shot? runSequence(SequenceContext ctx, int minute, List<PositionalEvent> out) {
  final startIdx = weightedIndex(startZoneWeights(ctx), seeded.random());
  if (startIdx == null) return null;
  var zone = startIdx;
  final first = pickCarrier(ctx.attackers, zone, seeded.random());
  if (first == null) return null;
  var carrier = first;

  for (var step = 0; step < maxSequenceSteps; step++) {
    final defender = pickDefender(ctx.defenders, zone, seeded.random());
    final support = defender == null
        ? 0.0
        : ctx.defenders.defendingPresence[zone] - defender.defending[zone];
    final effDef = effectiveDefence(defender?.defence ?? 1, support);
    final won = seeded.random() < duelProbability(carrier.attack, effDef);

    if (zoneBand(zone) == ctx.shotBand) {
      final ev = PositionalEvent(
        minute: minute,
        zone: zone,
        side: ctx.side,
        playerId: carrier.id,
        opponentId: defender?.id,
        type: 'shot',
        outcome: won ? 'miss' : 'blocked',
      );
      out.add(ev);
      if (!won) return null;
      return Shot(event: ev, shooter: carrier, rawXg: rawShotXg(zone, carrier));
    }

    out.add(
      PositionalEvent(
        minute: minute,
        zone: zone,
        side: ctx.side,
        playerId: carrier.id,
        opponentId: defender?.id,
        type: 'duel',
        outcome: won ? 'win' : 'lose',
      ),
    );
    if (!won) return null;

    zone = nextZone(ctx, zone, seeded.random());
    carrier = pickCarrier(ctx.attackers, zone, seeded.random()) ?? carrier;
  }
  return null;
}

/// Where a won duel takes the ball: the next band toward goal, in this lane or
/// a neighbour, weighted by the prior and by who is waiting there.
///
/// The three candidate lanes are clamped onto the grid, so at the touchline
/// the "outside" option folds onto the same lane rather than vanishing. One
/// roll.
int nextZone(SequenceContext ctx, int zone, double roll) {
  final lane = zoneLane(zone);
  final band = zoneBand(zone) + (ctx.towardZero ? -1 : 1);
  final prior = <int, double>{};
  for (final (l, w) in [
    (lane - 1, laneSwitchChance / 2),
    (lane, 1 - laneSwitchChance),
    (lane + 1, laneSwitchChance / 2),
  ]) {
    final c = l.clamp(0, pitchLanes - 1);
    prior[c] = (prior[c] ?? 0) + w;
  }
  final lanes = prior.keys.toList();
  final pull = <double>[
    for (final l in lanes)
      carrierWeights(
        ctx.attackers,
        zoneIndex(l, band),
      ).fold(0.0, (a, b) => a + b),
  ];
  final mean = pull.fold(0.0, (a, b) => a + b) / lanes.length;
  final weights = <double>[
    for (var i = 0; i < lanes.length; i++)
      prior[lanes[i]]! *
          (mean > 0 ? 1 - laneAttraction + laneAttraction * pull[i] / mean : 1),
  ];
  final pick = weightedIndex(weights, roll) ?? lanes.indexOf(lane);
  return zoneIndex(lanes[pick], band);
}

/// Half-width of the mean-one factor a window's λ is spread by before the
/// shots are rolled, from the shots themselves.
///
/// A handful of Bernoullis is UNDER-dispersed against a Poisson of the same
/// mean — the same 1.27 expected goals came out as 30% draws where the Poisson
/// gave 27% — so the calibration bridge alone would have made the game
/// drawier than the goal model says, and by an amount that depends on how
/// many shots there were. Multiplying λ by a uniform factor on `[1 − j, 1 + j]`
/// keeps the expectation exactly λ and adds `λ² j² / 3` of variance; the
/// Poisson-binomial is short by `Σp²`, so `j² / 3 = Σp² / (λ² − Σp²)` puts it
/// back exactly, at every λ and every shot count. A fixed width was tried
/// first and matched only near 1.3 goals — a favourite at three expected goals
/// was being spread far too wide and dropping points to it. Clamped so the
/// factor cannot go negative. A run of play rather than a dice roll: some
/// afternoons everything goes in.
double calibrationSpread(List<double> probabilities, double lambda) {
  var sumSq = 0.0;
  for (final p in probabilities) {
    sumSq += p * p;
  }
  final room = lambda * lambda - sumSq;
  if (room <= 0) return 1;
  return math.min(1.0, math.sqrt(3 * sumSq / room));
}

/// Scale raw xG so the shots' probabilities sum to [lambda], no shot above
/// [shotCap]. Whatever the capped shots cannot carry comes back as
/// `overflow`, to be rolled as Poisson, so `Σ probabilities + overflow == λ`.
({List<double> probabilities, double overflow}) calibrateShots(
  List<double> rawXg,
  double lambda,
) {
  final lam = math.max(0.0, lambda);
  final p = List<double>.filled(rawXg.length, 0);
  final open = <int>[
    for (var i = 0; i < rawXg.length; i++)
      if (rawXg[i] > 0) i,
  ];
  var remaining = lam;
  while (open.isNotEmpty) {
    var total = 0.0;
    for (final i in open) {
      total += rawXg[i];
    }
    final k = remaining / total;
    final capped = <int>[];
    for (final i in open) {
      if (k * rawXg[i] > shotCap) capped.add(i);
    }
    if (capped.isEmpty) {
      for (final i in open) {
        p[i] = k * rawXg[i];
      }
      return (probabilities: p, overflow: 0);
    }
    for (final i in capped) {
      p[i] = shotCap;
      remaining -= shotCap;
      open.remove(i);
    }
    if (remaining <= 0) return (probabilities: p, overflow: 0);
  }
  return (probabilities: p, overflow: remaining);
}

/// One side's goals in one window of a match through the positional sim.
///
/// [lambda] is that side's expected goals FOR THE WINDOW — already scaled by
/// the window's fraction and the match variance, exactly the number the
/// Poisson sampler used to be handed. Attacks are spread evenly across the
/// minutes; with nobody to attack or nobody to defend, or a window too short
/// for a single attack, it falls back to `poissonGoals(lambda)` and records
/// nothing, so the expectation is λ in every case. [jitter] scales the
/// Poisson-matching spread — one is the game, zero lets a test see the shots
/// sum to λ exactly.
int positionalWindowGoals({
  required SequenceContext ctx,
  required double lambda,
  required double fromMinute,
  required double toMinute,
  required List<PositionalEvent> out,
  double fullMatchMinutes = 90,
  double jitter = 1,
}) {
  final lam = math.max(0.0, lambda);
  final span = toMinute - fromMinute;
  final attacks = span <= 0
      ? 0
      : (attacksPerMatch * span / fullMatchMinutes).round();
  if (attacks <= 0 ||
      ctx.attackers.players.isEmpty ||
      ctx.defenders.players.isEmpty) {
    return poissonGoals(lam);
  }

  final shots = <Shot>[];
  for (var i = 0; i < attacks; i++) {
    final minute = math.max(
      1,
      (fromMinute + (i + 0.5) * span / attacks).floor(),
    );
    final shot = runSequence(ctx, minute, out);
    if (shot != null) shots.add(shot);
  }
  if (shots.isEmpty) return poissonGoals(lam);

  // Drawn AFTER the attacks and before the shots, once per side per window,
  // at the width these shots need — see [calibrationSpread].
  final raw = [for (final s in shots) s.rawXg];
  final base = calibrateShots(raw, lam);
  final width = jitter <= 0
      ? 0.0
      : jitter * calibrationSpread(base.probabilities, lam);
  final cal = width <= 0
      ? base
      : calibrateShots(raw, lam * (1 + width * (2 * seeded.random() - 1)));
  var goals = 0;
  for (var i = 0; i < shots.length; i++) {
    final p = cal.probabilities[i];
    shots[i].event.xg = p;
    if (seeded.random() < p) {
      goals++;
      shots[i].event.outcome = 'goal';
    }
  }
  if (cal.overflow > 0) goals += poissonGoals(cal.overflow);
  return goals;
}
