import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/sponsors.dart';

void main() {
  group('the company list', () {
    test('holds 18 sponsors', () {
      expect(companies.length, 18);
    });

    test('ids are unique and stable', () {
      expect(companies.map((c) => c.id).toSet().length, companies.length);
      // Existing saves reference these — they must never be renamed.
      for (final id in ['metatech', 'greenpower', 'fastfood']) {
        expect(companies.any((c) => c.id == id), isTrue, reason: id);
      }
    });

    test('names are unique', () {
      expect(companies.map((c) => c.name).toSet().length, companies.length);
    });

    test('every company has a name, icon and coach line', () {
      for (final c in companies) {
        expect(c.name, isNotEmpty, reason: c.id);
        expect(c.icon, isNotEmpty, reason: c.id);
        expect(c.drawback.msg, isNotEmpty, reason: c.id);
      }
    });

    test('every multiplier is a boost', () {
      for (final c in companies) {
        expect(c.mult, greaterThan(1), reason: c.id);
      }
    });

    test('multipliers span the documented range', () {
      final mults = companies.map((c) => c.mult).toList();
      expect(mults.reduce((a, b) => a < b ? a : b), 1.15);
      expect(mults.reduce((a, b) => a > b ? a : b), 3.00);
    });

    test('penalties are never negative', () {
      for (final c in companies) {
        expect(c.drawback.ratingPenalty, greaterThanOrEqualTo(0), reason: c.id);
        expect(c.drawback.injuryPenalty, greaterThanOrEqualTo(0), reason: c.id);
        expect(c.drawback.formPenalty, greaterThanOrEqualTo(0), reason: c.id);
      }
    });
  });

  group('risk and reward', () {
    test('clean deals exist and are the modest earners', () {
      final clean = companies.where((c) => c.drawback.isClean).toList();
      expect(clean.map((c) => c.id), [
        'greenpower',
        'localbakery',
        'purawater',
      ]);
      for (final c in clean) {
        expect(c.mult, lessThanOrEqualTo(1.25), reason: c.id);
      }
    });

    test('the biggest payer carries the heaviest rating penalty', () {
      final richest = companies.reduce((a, b) => a.mult >= b.mult ? a : b);
      final worstRating = companies.reduce(
        (a, b) => a.drawback.ratingPenalty >= b.drawback.ratingPenalty ? a : b,
      );
      expect(richest.id, 'dangerdrinks');
      expect(worstRating.id, 'dangerdrinks');
    });

    test('every deal paying above 1.8x costs something', () {
      for (final c in companies.where((c) => c.mult > 1.8)) {
        expect(c.drawback.isClean, isFalse, reason: c.id);
      }
    });

    test('no clean deal out-earns a costly one', () {
      final bestClean = companies
          .where((c) => c.drawback.isClean)
          .map((c) => c.mult)
          .reduce((a, b) => a > b ? a : b);
      final worstDirty = companies
          .where((c) => !c.drawback.isClean)
          .map((c) => c.mult)
          .reduce((a, b) => a < b ? a : b);
      expect(bestClean, lessThan(worstDirty));
    });

    test('rating penalty broadly tracks the payout', () {
      // Not strictly monotonic by design — the bands trade different axes —
      // but the top and bottom quartiles must not cross.
      final sorted = [...companies]..sort((a, b) => a.mult.compareTo(b.mult));
      final cheapest = sorted.take(4);
      final dearest = sorted.skip(sorted.length - 4);

      final avgCheap = cheapest
              .map((c) => c.drawback.ratingPenalty)
              .reduce((a, b) => a + b) /
          cheapest.length;
      final avgDear = dearest
              .map((c) => c.drawback.ratingPenalty)
              .reduce((a, b) => a + b) /
          dearest.length;

      expect(avgDear, greaterThan(avgCheap));
    });

    test('injury penalties stay within a plausible probability bump', () {
      for (final c in companies) {
        expect(c.drawback.injuryPenalty, lessThanOrEqualTo(0.10), reason: c.id);
      }
    });

    test('form penalties stay small', () {
      for (final c in companies) {
        expect(c.drawback.formPenalty, lessThanOrEqualTo(4), reason: c.id);
      }
    });
  });

  group('isClean', () {
    test('is true only when all three penalties are zero', () {
      const clean = SponsorDrawback(
        ratingPenalty: 0, injuryPenalty: 0, formPenalty: 0, msg: 'x',
      );
      expect(clean.isClean, isTrue);

      const rating = SponsorDrawback(
        ratingPenalty: 1, injuryPenalty: 0, formPenalty: 0, msg: 'x',
      );
      const injury = SponsorDrawback(
        ratingPenalty: 0, injuryPenalty: 0.01, formPenalty: 0, msg: 'x',
      );
      const form = SponsorDrawback(
        ratingPenalty: 0, injuryPenalty: 0, formPenalty: 1, msg: 'x',
      );
      expect(rating.isClean, isFalse);
      expect(injury.isClean, isFalse);
      expect(form.isClean, isFalse);
    });
  });

  group('getCompany', () {
    test('finds a known company', () {
      expect(getCompany('metatech')?.name, 'MetaTech');
      expect(getCompany('fastfood')?.mult, 2.00);
    });

    test('returns null for an unknown or null id', () {
      expect(getCompany('nike'), isNull);
      expect(getCompany(null), isNull);
    });
  });
}
