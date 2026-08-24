/// Whether the device is struggling, and what it costs when it is.
///
/// **`util/device.dart` was ported, fixture-tested against the JS and called by
/// NOTHING.** Every threshold matched, the one-way promotion was implemented,
/// the parity harness compared seven constants — and no widget ever asked, so
/// the policy it exists to serve was inert.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/low_end_device.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';

void main() {
  tearDown(() => readHardware = () => (memoryGb: null, cores: null));

  group('the static heuristic', () {
    test('WEAK HARDWARE IS ANSWERED BEFORE THE FIRST FRAME', () {
      readHardware = () => (memoryGb: 1, cores: 2);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(lowEndDeviceProvider), isTrue);
    });

    test('and a platform that says nothing is NOT low-end', () {
      // Both figures are absent on iOS, where the hardware copes fine — so
      // missing means capable, which is the JS's own reading.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(lowEndDeviceProvider), isFalse);
    });

    test('MODEST MEMORY ALONE IS NOT ENOUGH', () {
      // Desktop browsers bucket memory low — often reporting 4GB on a strong
      // machine — so 4GB needs weak cores beside it. Two gigabytes or less is
      // decisive on its own, because no desktop reports that.
      readHardware = () => (memoryGb: 4, cores: 8);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(lowEndDeviceProvider), isFalse);
    });
  });

  group('what it costs the glass', () {
    Future<bool> blursWhen(WidgetTester tester, {required bool allowed}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: GlassQuality(
            blurAllowed: allowed,
            child: const Scaffold(
              body: Center(child: GlassPanel(child: Text('hi'))),
            ),
          ),
        ),
      );
      return find.byType(BackdropFilter).evaluate().isNotEmpty;
    }

    testWidgets('a capable device gets the blur', (tester) async {
      expect(await blursWhen(tester, allowed: true), isTrue);
    });

    testWidgets('AND A STRUGGLING ONE KEEPS EVERY WORD', (tester) async {
      // The file's own first rule is that the TINT carries legibility and the
      // blur does not — so a device that cannot afford the blur loses the
      // depth and nothing else.
      expect(await blursWhen(tester, allowed: false), isFalse);
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('and with nobody saying otherwise it blurs', (tester) async {
      // Every test and every screen built outside the app's own root.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: const Scaffold(
            body: Center(child: GlassPanel(child: Text('hi'))),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsWidgets);
    });
  });
}
