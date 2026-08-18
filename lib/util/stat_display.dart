/// The ATK and DEF display. Ported from
/// `../merge-empire-fc/src/utils/statDisplay.js`.
///
/// Under the FIFA model the match engine already produces the FIFA-style
/// numbers everywhere — the stronger stat sits just above the rating, the weaker
/// one drops below, team stats are position-weighted so they land near the
/// rating, and it is all on ONE scale, so comparing two teams is faithful. The
/// display is therefore a straight clamp and round of the sim's OWN numbers:
/// what the player sees is exactly what the sim runs on, with nothing to
/// reconcile.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

/// An ATK and DEF pair, ready to print.
typedef StatSplit = ({int atk, int def});

int _clamp(num v) => math.max(0, math.min(100, v.round()));

/// A card's or a team's ATK and DEF, clamped for display.
StatSplit fifaSplit(num atk, num def) => (atk: _clamp(atk), def: _clamp(def));

/// The same, with the active tactic's multipliers applied — the identical ones
/// the sim applies to its raw ratings, so the printed numbers move exactly as
/// the match numbers do.
StatSplit fifaSplitTactic(
  num atk,
  num def, [
  num atkMult = 1,
  num defMult = 1,
]) => (atk: _clamp(atk * atkMult), def: _clamp(def * defMult));
