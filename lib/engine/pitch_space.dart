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
/// The sim only ever goes from a zone INDEX outward — a map is sampled at
/// [zoneCentre] and a sequence moves by [zoneIndex] — so there is no
/// point-to-zone lookup here; the tests that pin the frame do that arithmetic
/// themselves.
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

/// The flank a zone is on **in the owner's own left and right**.
///
/// The grid is one absolute frame, so lane 0 is OUR right and, for the side
/// attacking the other way, their left. Every reading that speaks to a player —
/// the report's copy, the inspector's bars, the flank the 2D passage is drawn
/// down — wants it from the point of view of whoever is attacking, so the lane
/// reverses for them. One function because three places did this arithmetic and
/// a fourth was about to.
Flank zoneFlankFor(int zone, {required bool theirs}) {
  final lane = zoneLane(zone);
  return laneFlank(theirs ? pitchLanes - 1 - lane : lane);
}

/// A slot's point in its own team's frame.
PitchPoint slotPoint(FormationSlot slot) =>
    (x: slot.x.toDouble(), y: slot.y.toDouble());

/// The opponent's point in OUR frame. Their goal line is our y = 0 and their
/// right is our left.
PitchPoint mirrorPoint(PitchPoint p) => (x: 100 - p.x, y: 100 - p.y);

/// The zone [mirrorPoint] lands a zone's centre in. Both axes reverse, so lane
/// becomes `4 − lane` and band `3 − band`, which is `19 − zone`.
int mirrorZone(int zone) => pitchZones - 1 - zone;
