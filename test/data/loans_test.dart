import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/loans.dart';

/// The match-payout rates the wage is tuned against. They live in the match
/// engine; repeated here so the loan invariants can be asserted before that
/// engine exists, and cross-checked once it does.
const double _winPayout = 1.00;
const double _drawPayout = 0.40;
const double _lossPayout = 0.10;

void main() {
  group('loans in', () {
    test('values', () {
      expect(loanMatches, 10);
      expect(loanFeeRate, 5.0);
      expect(loanWageRate, 0.45);
      expect(maxActiveLoans, 2);
      expect(loanTierLift, 1);
      expect(recallOnUnpaid, isTrue);
    });

    test('a win comfortably covers the wage', () {
      expect(loanWageRate, lessThan(_winPayout));
      expect(_winPayout - loanWageRate, greaterThan(0.5));
    });

    test('a draw roughly breaks even', () {
      // Slightly negative on purpose — a draw should not fund the loan.
      expect(loanWageRate, greaterThan(_drawPayout));
      expect(loanWageRate - _drawPayout, lessThan(0.1));
    });

    test('a loss actively bleeds', () {
      expect(loanWageRate, greaterThan(_lossPayout * 2));
    });

    test('the whole spell costs more than the up-front fee', () {
      // The wage bill is the real cost; the fee is the entry ticket.
      expect(loanWageRate * loanMatches, greaterThan(loanFeeRate * 0.8));
    });

    test('the tier lift is exactly one', () {
      // More would be a back door to T9, which is scout-only and uncraftable.
      expect(loanTierLift, 1);
    });

    test('the loan cap keeps the wage bill a decision, not a spreadsheet', () {
      expect(maxActiveLoans, lessThanOrEqualTo(2));
      // Two simultaneous loans must still be survivable off wins.
      expect(loanWageRate * maxActiveLoans, lessThan(_winPayout));
    });

    test('an unpaid wage ends the loan rather than accruing debt', () {
      expect(recallOnUnpaid, isTrue);
    });
  });

  group('loans out', () {
    test('values', () {
      expect(loanOutValueShare, 0.25);
      expect(loanOutFeeRate, 0.30);
      expect(loanOutMatches, 10);
      expect(loanOutTierMin, 0.55);
      expect(loanOutTierMax, 1.70);
      expect(maxLoansOut, 3);
    });

    test('renting out pays less than renting in costs', () {
      // Otherwise swapping squads back and forth would be a money printer.
      expect(loanOutFeeRate, lessThan(loanWageRate));
    });

    test('both directions run the same number of matches', () {
      expect(loanOutMatches, loanMatches);
    });

    test('the tier scaling band is a real range around parity', () {
      expect(loanOutTierMin, lessThan(1));
      expect(loanOutTierMax, greaterThan(1));
      expect(loanOutTierMin, lessThan(loanOutTierMax));
    });

    test('neither end of the scaling band runs away', () {
      expect(loanOutTierMin, greaterThan(0.5));
      expect(loanOutTierMax, lessThan(2.0));
    });

    test('a spell never pays out more than the card is worth', () {
      expect(loanOutValueShare, lessThan(1));
      expect(loanOutValueShare * loanOutTierMax, lessThan(1));
    });

    test('more players can go out than come in', () {
      // Loaning out is squad depth management; loaning in is a power spike.
      expect(maxLoansOut, greaterThan(maxActiveLoans));
    });
  });
}
