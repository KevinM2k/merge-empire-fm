/// Portrait only, on a phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/shell/orientation_lock.dart';

/// What the widget asked the platform for, in order.
List<List<String>> _asked = [];

void main() {
  setUp(() {
    _asked = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            _asked.add(List<String>.from(call.arguments as List));
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('the threshold', () {
    test('a phone gets portrait only', () {
      expect(orientationsFor(392), const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      // A folded fold is still a phone, and the tallest of them is 412 across.
      expect(orientationsFor(tabletShortestSide - 1).length, 2);
    });

    test('and a tablet or an unfolded fold keeps all four', () {
      expect(orientationsFor(tabletShortestSide).length, 4);
      expect(orientationsFor(834).length, 4);
      expect(
        orientationsFor(1024),
        contains(DeviceOrientation.landscapeLeft),
      );
    });

    test('the SHORTEST side is what is measured, so the answer does not '
        'change when the device is turned', () {
      // 800x360 and 360x800 are the same handset; a lock that read the WIDTH
      // would unlock itself the moment the player got it sideways.
      expect(
        orientationsFor(const Size(800, 360).shortestSide),
        orientationsFor(const Size(360, 800).shortestSide),
      );
    });
  });

  group('and it reaches the platform', () {
    Future<void> pumpAt(WidgetTester tester, Size size) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: OrientationLock(child: SizedBox.shrink()),
        ),
      ),
    );

    testWidgets('a phone is locked to portrait once', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      expect(_asked, hasLength(1));
      expect(_asked.single, [
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.portraitDown',
      ]);
    });

    testWidgets('a tablet is not', (tester) async {
      await pumpAt(tester, const Size(834, 1194));
      expect(_asked.single, hasLength(4));
    });

    testWidgets('AND A FOLD OPENING IS A NEW ANSWER, but an unrelated metrics '
        'change is not', (tester) async {
      await pumpAt(tester, const Size(374, 812));
      expect(_asked, hasLength(1));
      // The keyboard, the shade: same device, so nothing is asked again.
      await pumpAt(tester, const Size(374, 500));
      expect(_asked, hasLength(1));
      // Unfolded. That IS a different device.
      await pumpAt(tester, const Size(717, 812));
      expect(_asked, hasLength(2));
      expect(_asked.last, hasLength(4));
    });
  });
}
