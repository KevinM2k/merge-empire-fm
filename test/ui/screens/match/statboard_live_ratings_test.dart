/// **A SIDE DOWN TO TEN HAS TO CHANGE THE RUN OF PLAY, not just the board.**
///
/// Reported from the couch about an away fixture: the opposition were sent off
/// and nothing about the match changed. The RATINGS did — `reSimulateRemainder`
/// cuts their figure by the man and hands the pair back for the scoreboard to
/// print — but every number `liveStatsFor` produces came off the kickoff
/// fields, so the possession bar, the momentum arrow and the idle pitch's shape
/// all went on describing eleven against eleven for the rest of the afternoon.
///
/// Which is the exact fault `match_statboard.dart`'s own note about the arrow
/// warns against, arrived at from the other direction: the remainder's chances
/// ARE re-rolled on the live pair — `chanceWeights` in `reSimulateRemainder` is
/// `adjSquad` against `oppAttack` — so from the sending-off on, the chances
/// were falling one way while the arrow over them pointed the other.
///
/// The pair is a SUBSTITUTION and not a second model, so a match nobody was
/// booked in carries no `live*` fields and reads exactly as it did — which is
/// the last group here, and it is the one that says this changed nothing else.
/// Its second and third cases are the sharp end of that: the live map's own
/// default for a missing rating is ZERO and this file's is FIFTY, so a fixture
/// the engine never rated must not re-sim its way into a walkover.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart';
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/match/match_statboard.dart';

void main() {
  /// Goalless and eventless, so the swing counted off the feed is nil and the
  /// only thing left moving the numbers is the rating gap — which is the one
  /// this file is about.
  const frame = (
    minute: 30,
    shown: <TimelineEvent>[],
    ourGoals: 0,
    theirGoals: 0,
    finished: false,
  );

  /// Two sides of a level match: sixty against seventy, so there is room in
  /// both directions.
  const kickoff = <String, dynamic>{
    'effectiveSquadRating': 60,
    'effectiveOppRating': 70,
    'ourAttackRating': 60,
    'ourDefenceRating': 60,
    'effOppAttackRating': 70,
    'effOppDefenceRating': 70,
  };

  LiveStats statsWith({
    required bool isHome,
    Map<String, dynamic> live = const {},
  }) => liveStatsFor(
    frame: frame,
    result: kickoff,
    isHome: isHome,
    strategyId: 'balanced',
    live: live,
  );

  /// What their referee costs a side of eleven that loses one of them — the
  /// same figure `reSimulateRemainder` scales their rating by.
  final theirRed = 70 * oppTeamRatingMult(0, 1);

  group('THE OPPOSITION GO DOWN TO TEN', () {
    test('and the run of play comes our way — at home', () {
      final before = statsWith(isHome: true);
      final after = statsWith(
        isHome: true,
        live: {'liveSquadRating': 60, 'liveOppRating': theirRed},
      );
      // Home: `possHome` and `dangerHome` are OURS.
      expect(after.possHome, greaterThan(before.possHome));
      expect(after.dangerHome, greaterThan(before.dangerHome));
    });

    test('and away from home, which is where it was reported', () {
      final before = statsWith(isHome: false);
      final after = statsWith(
        isHome: false,
        live: {'liveSquadRating': 60, 'liveOppRating': theirRed},
      );
      // Away: the HOME side is the opposition, so the same event has to move
      // both figures the other way. The venue conversion is
      // `liveStatsFor`'s own and predates this; what is asserted here is that
      // the cut arrives on the right side of it.
      expect(after.possHome, lessThan(before.possHome));
      expect(after.dangerHome, lessThan(before.dangerHome));
      expect(after.possAway, greaterThan(before.possAway));
    });

    test('and a sending-off is worth more than a caution', () {
      LiveStats withOpp(double mult) => statsWith(
        isHome: true,
        live: {'liveSquadRating': 60, 'liveOppRating': 70 * mult},
      );
      final caution = withOpp(oppTeamRatingMult(1, 0));
      final dismissal = withOpp(oppTeamRatingMult(0, 1));
      expect(dismissal.dangerHome, greaterThan(caution.dangerHome));
      // And a caution is worth something, which is the half that is easy to
      // lose: ten per cent of one man is about 0.9% of eleven, so it moves the
      // arrow's own figure without always moving the whole-number bar.
      final clean = statsWith(isHome: true);
      expect(caution.dangerHome, greaterThan(clean.dangerHome));
    });
  });

  group('OUR OWN CARDS COUNT THE SAME WAY', () {
    test('a man down of ours hands them the run of play', () {
      final before = statsWith(isHome: true);
      final after = statsWith(
        isHome: true,
        live: {
          'liveSquadRating': 60 * oppTeamRatingMult(0, 1),
          'liveOppRating': 70,
        },
      );
      expect(after.possHome, lessThan(before.possHome));
      expect(after.dangerHome, lessThan(before.dangerHome));
    });
  });

  group('AND A MATCH WITH NO CARDS IN IT READS EXACTLY AS IT DID', () {
    test('an empty live map is the kickoff pair', () {
      for (final home in [true, false]) {
        final plain = statsWith(isHome: home);
        expect(
          statsWith(isHome: home, live: const {}).possHome,
          plain.possHome,
        );
        expect(
          statsWith(isHome: home, live: const {}).dangerHome,
          plain.dangerHome,
        );
      }
    });

    test('and a live map carrying nulls falls back rather than to fifty', () {
      // `asNum` defaults a MISSING rating to 50, which is right for a fixture
      // the engine does not rate and wrong for a live map that happens to hold
      // a null — so the read is `is num` and the fallback is the kickoff field.
      final plain = statsWith(isHome: true);
      final withNulls = statsWith(
        isHome: true,
        live: const {'liveSquadRating': null, 'liveOppRating': null},
      );
      expect(withNulls.possHome, plain.possHome);
      expect(withNulls.dangerHome, plain.dangerHome);
    });

    test('AND A FIXTURE THE ENGINE DOES NOT RATE STAYS LEVEL', () {
      // **The two defaults disagree, and that is the whole of this test.**
      // `asNum` here reads a MISSING rating as 50 — a fixture nobody rated is a
      // level one — while `reSimulateRemainder` reads the same absence as ZERO,
      // through `fallbackOpp`. So a result with no `effectiveOppRating` re-sims
      // to a live opposition of nil, and taking that figure would hand us the
      // whole pitch on a fixture where nothing had happened.
      //
      // It is not hypothetical: a bare result is what the match screen's own
      // tests play, and it was two of them failing that found this.
      const unrated = <String, dynamic>{};
      final level = liveStatsFor(
        frame: frame,
        result: unrated,
        isHome: true,
        strategyId: 'balanced',
      );
      final resimmed = liveStatsFor(
        frame: frame,
        result: unrated,
        isHome: true,
        strategyId: 'balanced',
        live: const {'liveSquadRating': 0.0, 'liveOppRating': 0.0},
      );
      expect(resimmed.possHome, level.possHome);
      expect(resimmed.dangerHome, level.dangerHome);
    });
  });
}
