/// The pitch as the match sim sees it: a 5-lane by 4-band grid laid over the
/// `FormationSlot` coordinate frame.
///
/// **This is new to the port** — nothing in `../merge-empire-fc/src/` knows
/// where a player stands. The JS decides a scoreline from two team numbers;
/// this frame is what lets the Dart sim decide WHICH attacker meets WHICH
/// defender and where, so the heatmap and the analysis fall out of the sim
/// rather than being drawn over it afterwards.
///
/// ## The frame
///
/// `x` runs 0–100 across and `y` 0–100 along, with **y = 100 the team's own
/// goal line** — the keeper stands at y:90 and the team attacks toward y = 0.
/// That is `FormationSlot`'s frame, reused rather than re-tabulated.
///
/// **Low x is the team's own RIGHT.** The pitch widget places a token at
/// `left: x%` with the own goal at the bottom of the screen, so the team
/// attacks UP the screen and `rb` at x:14 sits on screen-left — which is the
/// right-back's LEFT if you stand in his boots facing the goal he attacks. The
/// slot ids are the authority, because they are what the player reads on the
/// token: every `r*` slot in every shape has x < 50 and every `l*` slot has
/// x > 50, and `formations_test` pins that. So "your RW against their LB" and
/// "you attacked down the right" both mean lanes 0 and 1 for the team whose
/// frame this is, and the heatmap paints them where the RW's token stands.
///
/// The opponent's shape is mirrored into the same absolute frame with
/// [mirrorPoint] — `x → 100 − x`, `y → 100 − y` — so their right-back stands
/// in front of OUR left winger, which is where a right-back belongs.
///
/// ## The grid
///
/// Five lanes across (20 wide each) and four bands along (25 deep each), zone
/// index `band * 5 + lane`. Band 0 is the band in front of the goal a team
/// attacks; band 3 holds its own keeper. Lanes collapse to three flanks for
/// analysis copy — lanes 0–1 right, lane 2 centre, lanes 3–4 left.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/formations.dart';

const int pitchLanes = 5;
const int pitchBands = 4;
const int pitchZones = pitchLanes * pitchBands;

/// Width of one lane and depth of one band, in frame units.
const double laneWidth = 100 / pitchLanes;
const double bandDepth = 100 / pitchBands;

/// A point in the frame described in the library header.
typedef PitchPoint = ({double x, double y});

/// The three flanks the analysis copy speaks in. [right] is the team's own
/// right — lanes 0 and 1, low x.
enum Flank { right, centre, left }

/// Lane index of an across coordinate. x = 100 is the far touchline and lands
/// in the last lane rather than off the grid.
int laneOf(num x) {
  final lane = (x.clamp(0, 100) / laneWidth).floor();
  return lane >= pitchLanes ? pitchLanes - 1 : lane;
}

/// Band index of an along coordinate, same edge rule as [laneOf].
int bandOf(num y) {
  final band = (y.clamp(0, 100) / bandDepth).floor();
  return band >= pitchBands ? pitchBands - 1 : band;
}

int zoneOf(num x, num y) => bandOf(y) * pitchLanes + laneOf(x);

int zoneAt(PitchPoint p) => zoneOf(p.x, p.y);

int zoneLane(int zone) => zone % pitchLanes;

int zoneBand(int zone) => zone ~/ pitchLanes;

int zoneIndex(int lane, int band) => band * pitchLanes + lane;

PitchPoint zoneCentre(int zone) => (
  x: zoneLane(zone) * laneWidth + laneWidth / 2,
  y: zoneBand(zone) * bandDepth + bandDepth / 2,
);

Flank laneFlank(int lane) => lane <= 1
    ? Flank.right
    : lane == 2
    ? Flank.centre
    : Flank.left;

Flank zoneFlank(int zone) => laneFlank(zoneLane(zone));

/// Band 0: the band in front of the goal this frame's team attacks.
bool isAttackingBand(int zone) => zoneBand(zone) == 0;

/// A slot's point in its own team's frame.
PitchPoint slotPoint(FormationSlot slot) =>
    (x: slot.x.toDouble(), y: slot.y.toDouble());

/// The opponent's point in OUR frame. Their goal line is our y = 0 and their
/// right is our left.
PitchPoint mirrorPoint(PitchPoint p) => (x: 100 - p.x, y: 100 - p.y);

/// The zone [mirrorPoint] lands a zone's centre in. Both axes reverse, so lane
/// becomes `4 − lane` and band `3 − band`, which is `19 − zone`.
int mirrorZone(int zone) => pitchZones - 1 - zone;
