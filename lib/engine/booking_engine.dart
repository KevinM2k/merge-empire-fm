/// Yellow and red cards.
///
/// **NOTHING IN THE SPEC BOOKS ANYBODY.** `generateMatchEvents` in
/// `../merge-empire-fc` emits goal, commentary, halftime, fulltime, chance,
/// corner, injury, no_sub and opp_sub, and no referee has ever reached for a
/// pocket in that repo. So this is a FEATURE of the port rather than a port of
/// anything, asked for from the couch — and that shapes the whole file.
///
/// **IT RUNS AFTER THE PARITY-PINNED GENERATOR, ON ITS OWN STREAM.**
/// `match_orchestration_reference.json` compares the JS's event feed field for
/// field, and this repo's own rule is that draw ORDER matters as much as the
/// formula: a single extra `nextDouble()` inside `generateMatchEvents` would
/// shift every later draw in the match and break the harness on a change that
/// has nothing to do with it. So bookings are minted here, from a generator
/// seeded off the match's own seed, and appended. The pinned events cannot see
/// this file and this file cannot move them.
///
/// **A SECOND YELLOW IS NOT A STRAIGHT RED**, and the feed has to say which.
/// One is a caution too many and the other is violent conduct or denying a
/// goalscoring opportunity — different offences, different lines, different
/// pictures. Asked for in exactly those terms. [Booking.card] is the
/// distinction and it is carried all the way to the row.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

/// What the referee produced, and when.
typedef Booking = ({
  int minute,
  String instanceId,
  String name,

  /// `yellow`, `second_yellow` or `red`.
  String card,
});

/// A card carries a yellow.
const String cardYellow = 'yellow';

/// A second caution, which is a sending-off — and reads as one.
const String cardSecondYellow = 'second_yellow';

/// Straight red: violent conduct, or denying a goalscoring opportunity.
const String cardRed = 'red';

/// Whether this card ends the player's match.
bool cardSendsOff(String card) => card != cardYellow;

/// **WHAT A YELLOW COSTS while the player is still on.**
///
/// A booked player plays within himself — he cannot dive into a tackle without
/// risking the second. Ten per cent of his rating, asked for from the couch.
/// Applied as a multiplier rather than a flat drop so it scales with the player
/// it is applied to: a point off a 30-rated rookie is not the same punishment
/// as a point off a 90-rated icon.
const double yellowCardRatingMult = 0.9;

/// How many bookings a match tends to produce, per side.
///
/// Real football averages about three and a half yellows across both sides. A
/// feed is read rather than watched, so this is deliberately quieter: most
/// matches show one or two, a fair number show none, and a sending-off is rare
/// enough to be an event when it happens.
const double yellowChancePerSide = 0.55;

/// The chance a booked player is booked AGAIN — which is a sending-off.
const double secondYellowChance = 0.12;

/// The chance of a straight red, per side, per match. Rare on purpose: it ends
/// somebody's afternoon and bans them from the next one.
const double straightRedChance = 0.035;

/// Who is bookable, in the order the caller wants them weighted.
typedef BookingCandidate = ({String instanceId, String name, String position});

/// How likely each line is to see a card. Defenders and holding midfielders
/// commit the fouls; a keeper almost never does.
const Map<String, double> bookingWeightByPosition = {
  'DEF': 1.6,
  'MID': 1.3,
  'FWD': 0.7,
  'GK': 0.15,
};

/// The cards OUR side picks up in one match.
///
/// [seed] is the match's own, so a match replays the same bookings — the same
/// promise the cutaway makes about its passages. [upTo] is the last minute a
/// card can be shown in; a booking in the 94th that the clock never reaches is
/// a suspension nobody saw earned.
List<Booking> rollBookings({
  required List<BookingCandidate> squad,
  required int seed,
  int from = 8,
  int upTo = 88,
}) {
  if (squad.isEmpty || upTo <= from) return const [];
  // **ITS OWN STREAM, off the match's seed.** See the library note: sharing the
  // event generator's would move every pinned draw in the match.
  final rng = math.Random(seed ^ 0x5EED_B00C);

  final weights = [
    for (final c in squad) bookingWeightByPosition[c.position] ?? 1.0,
  ];
  final total = weights.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return const [];

  BookingCandidate pick() {
    var roll = rng.nextDouble() * total;
    for (var i = 0; i < squad.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return squad[i];
    }
    return squad.last;
  }

  final out = <Booking>[];
  final minutes = <int>{};
  int minute() {
    for (var tries = 0; tries < 20; tries++) {
      final m = from + rng.nextInt(upTo - from);
      if (minutes.add(m)) return m;
    }
    return from;
  }

  // A straight red is rolled first and on its own: it is not a caution that
  // escalated, so it does not care whether anybody has been booked.
  if (rng.nextDouble() < straightRedChance) {
    final who = pick();
    out.add((
      minute: minute(),
      instanceId: who.instanceId,
      name: who.name,
      card: cardRed,
    ));
  }

  final sentOff = {for (final b in out) b.instanceId};
  final booked = <String>{};
  // Two rolls, so a match can produce two cautions without ever producing more
  // than a readable number of lines.
  for (var i = 0; i < 2; i++) {
    if (rng.nextDouble() >= yellowChancePerSide) continue;
    final who = pick();
    if (sentOff.contains(who.instanceId)) continue;
    if (!booked.add(who.instanceId)) continue;
    out.add((
      minute: minute(),
      instanceId: who.instanceId,
      name: who.name,
      card: cardYellow,
    ));
  }

  // And a caution can become a second one, which is a sending-off. Only for
  // somebody already carrying one, which is the whole meaning of it.
  for (final first in [...out]) {
    if (first.card != cardYellow) continue;
    if (rng.nextDouble() >= secondYellowChance) continue;
    var m = minute();
    // It has to come AFTER the caution it follows, or the story is nonsense.
    if (m <= first.minute) m = math.min(upTo, first.minute + 1 + rng.nextInt(20));
    if (m <= first.minute) continue;
    out.add((
      minute: m,
      instanceId: first.instanceId,
      name: first.name,
      card: cardSecondYellow,
    ));
  }

  out.sort((a, b) => a.minute.compareTo(b.minute));
  return out;
}

/// Everyone this match sent off, by card instance id — who serves a ban.
Set<String> sentOffIn(Iterable<Booking> bookings) => {
  for (final b in bookings)
    if (cardSendsOff(b.card)) b.instanceId,
};

/// Everyone carrying a caution at the final whistle, by card instance id.
///
/// A player who was sent off is NOT in here: he is suspended, which is a bigger
/// thing than a rating penalty and outlives the ninety minutes.
Set<String> cautionedIn(Iterable<Booking> bookings) {
  final off = sentOffIn(bookings);
  return {
    for (final b in bookings)
      if (b.card == cardYellow && !off.contains(b.instanceId)) b.instanceId,
  };
}
