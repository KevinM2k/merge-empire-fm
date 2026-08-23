import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/age_verification.dart';
import 'package:merge_empire_fc/util/time.dart';

void main() {
  setUp(() {
    resetAgeSignalSource();
    setClock(() => 1_700_000_000_000);
  });

  tearDown(() {
    resetAgeSignalSource();
    resetClock();
  });

  group('the signal', () {
    test('a device with no plugin records the attempt and stays UNKNOWN', () async {
      final state = <String, dynamic>{};
      expect(await checkAndUpdateAgeSignal(state), AgeGroup.unknown);
      final av = state['ageVerification'] as Map<String, dynamic>;
      expect(av['status'], 'unknown');
      // **`source` stays null on a no-signal boot**, which is what stops the
      // seven-day cache swallowing the first device that DOES get the API.
      expect(av['source'], isNull);
      expect(av['checkedAt'], 1_700_000_000_000);
      expect(av['parentalConsentGiven'], false);
    });

    test('and a second boot does not overwrite that attempt', () async {
      final state = <String, dynamic>{};
      await checkAndUpdateAgeSignal(state);
      setClock(() => 1_700_000_050_000);
      await checkAndUpdateAgeSignal(state);
      expect(
        (state['ageVerification'] as Map)['checkedAt'],
        1_700_000_000_000,
        reason: 'the attempt is recorded once',
      );
    });

    test('a real signal is written with source play_api', () async {
      ageSignalSource = () async => AgeGroup.teen;
      final state = <String, dynamic>{};
      expect(await checkAndUpdateAgeSignal(state), AgeGroup.teen);
      final av = state['ageVerification'] as Map<String, dynamic>;
      expect(av['status'], 'teen');
      expect(av['source'], 'play_api');
    });

    test('AND IT IS CACHED FOR SEVEN DAYS', () async {
      ageSignalSource = () async => AgeGroup.adult;
      final state = <String, dynamic>{};
      await checkAndUpdateAgeSignal(state);

      // Six days later the plugin is not asked again, even though it would now
      // answer differently.
      ageSignalSource = () async => AgeGroup.child;
      setClock(() => 1_700_000_000_000 + 6 * 24 * 60 * 60 * 1000);
      expect(await checkAndUpdateAgeSignal(state), AgeGroup.adult);

      // Eight days later it is.
      setClock(() => 1_700_000_000_000 + 8 * 24 * 60 * 60 * 1000);
      expect(await checkAndUpdateAgeSignal(state), AgeGroup.child);
    });

    test('a plugin that throws is UNKNOWN, not a crashed boot', () async {
      ageSignalSource = () async => throw StateError('bridge gone');
      final state = <String, dynamic>{};
      expect(await checkAndUpdateAgeSignal(state), AgeGroup.unknown);
    });

    test('re-querying keeps the consent a parent already gave', () async {
      ageSignalSource = () async => AgeGroup.child;
      final state = <String, dynamic>{};
      await checkAndUpdateAgeSignal(state);
      grantParentalConsent(state);

      setClock(() => 1_700_000_000_000 + 8 * 24 * 60 * 60 * 1000);
      await checkAndUpdateAgeSignal(state);
      expect(
        (state['ageVerification'] as Map)['parentalConsentGiven'],
        true,
        reason: 'a re-query is not a reason to ask the parent again',
      );
    });
  });

  group('what it gates', () {
    test('NO SIGNAL MEANS ALLOWED', () {
      expect(isIapAllowed(<String, dynamic>{}), isTrue);
      expect(
        isIapAllowed(<String, dynamic>{
          'ageVerification': <String, dynamic>{'status': 'unknown'},
        }),
        isTrue,
      );
    });

    test('an adult is allowed without consent', () {
      expect(
        isIapAllowed(<String, dynamic>{
          'ageVerification': <String, dynamic>{'status': 'adult'},
        }),
        isTrue,
      );
    });

    test('a minor is blocked until a parent allows it', () {
      final state = <String, dynamic>{
        'ageVerification': <String, dynamic>{'status': 'teen'},
      };
      expect(isIapAllowed(state), isFalse);
      grantParentalConsent(state);
      expect(isIapAllowed(state), isTrue);
      // The consent does not make them an adult.
      expect(isConfirmedMinor(state), isTrue);
    });

    test('consent on a save with no block at all still lands', () {
      final state = <String, dynamic>{};
      grantParentalConsent(state);
      final av = state['ageVerification'] as Map<String, dynamic>;
      expect(av['parentalConsentGiven'], true);
      expect(av['parentalConsentAt'], 1_700_000_000_000);
    });

    test('isConfirmedMinor is the two minor groups and nothing else', () {
      for (final (status, expected) in [
        ('child', true),
        ('teen', true),
        ('adult', false),
        ('unknown', false),
      ]) {
        expect(
          isConfirmedMinor(<String, dynamic>{
            'ageVerification': <String, dynamic>{'status': status},
          }),
          expected,
          reason: status,
        );
      }
    });

    test('the AdMob flags follow the STATUS, not the consent', () {
      final child = <String, dynamic>{
        'ageVerification': <String, dynamic>{'status': 'child'},
      };
      grantParentalConsent(child);
      final flags = getAdMobAgeFlags(child);
      expect(flags.tagForChildDirectedTreatment, isTrue);
      expect(flags.tagForUnderAgeOfConsent, isFalse);

      final teen = getAdMobAgeFlags(<String, dynamic>{
        'ageVerification': <String, dynamic>{'status': 'teen'},
      });
      expect(teen.tagForChildDirectedTreatment, isFalse);
      expect(teen.tagForUnderAgeOfConsent, isTrue);

      final none = getAdMobAgeFlags(<String, dynamic>{});
      expect(none.tagForChildDirectedTreatment, isFalse);
      expect(none.tagForUnderAgeOfConsent, isFalse);
    });
  });

  group('reading a save it does not understand', () {
    test('an unknown status string is permissive', () {
      // A save written by a newer build must not lock this one out of the shop.
      expect(
        isIapAllowed(<String, dynamic>{
          'ageVerification': <String, dynamic>{'status': 'pensioner'},
        }),
        isTrue,
      );
    });

    test("and Play's own numeric values map the way the API documents them", () {
      expect(AgeGroup.fromPlayValue(0), AgeGroup.unknown);
      expect(AgeGroup.fromPlayValue(1), AgeGroup.child);
      expect(AgeGroup.fromPlayValue(2), AgeGroup.teen);
      expect(AgeGroup.fromPlayValue(3), AgeGroup.adult);
      expect(AgeGroup.fromPlayValue(null), AgeGroup.unknown);
      expect(AgeGroup.fromPlayValue(9), AgeGroup.unknown);
    });
  });
}
