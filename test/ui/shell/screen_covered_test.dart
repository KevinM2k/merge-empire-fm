/// The screen underneath a sheet stops animating.
///
/// **THE SECOND ANIMATED SCREEN.** A modal bottom sheet is a `PopupRoute`: it
/// rises OVER the current route without pushing it out, so nothing in Flutter
/// tells the screen beneath that it has stopped being looked at, and its
/// tickers keep running. On the home tab that is a pitch scene, weather, a ball
/// and a walking manager, all animating behind something opaque — which is
/// exactly the diagnosis the customiser's lag was reported with, and the half
/// the first profile of it never measured. It profiled the BUILD.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/shell/screen_covered.dart';

/// A widget that counts the frames it is actually given.
class _Ticking extends StatefulWidget {
  const _Ticking({required this.onFrame});

  final VoidCallback onFrame;

  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => widget.onFrame());

  @override
  void initState() {
    super.initState();
    // Started HERE, not in the field: a `late final` is lazy, and nothing else
    // reads it — so the ticker was never created and the test measured zero
    // frames whether or not anything was covering it.
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('OPENING A SHEET COVERS THE SCREEN, and closing uncovers it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    late BuildContext ctx;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    expect(container.read(screenIsCoveredProvider), isFalse);
    final done = showBottomSheetPopup<void>(
      ctx,
      child: const SizedBox(height: 40),
    );
    await tester.pumpAndSettle();
    expect(container.read(screenIsCoveredProvider), isTrue);

    Navigator.of(ctx).pop();
    await done;
    await tester.pumpAndSettle();
    expect(container.read(screenIsCoveredProvider), isFalse);
  });

  testWidgets('SHEETS STACK, and the first to close does not hand back the '
      'frames the second is still holding', (tester) async {
    // The gem shelf opens over the confirm that could not be paid for.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late BuildContext ctx;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    final first = showBottomSheetPopup<void>(ctx, child: const SizedBox(height: 40));
    await tester.pumpAndSettle();
    final second = showBottomSheetPopup<void>(ctx, child: const SizedBox(height: 40));
    await tester.pumpAndSettle();
    expect(container.read(screenCoveredProvider), 2);

    Navigator.of(ctx).pop();
    await second;
    await tester.pumpAndSettle();
    expect(container.read(screenIsCoveredProvider), isTrue);

    Navigator.of(ctx).pop();
    await first;
    await tester.pumpAndSettle();
    expect(container.read(screenIsCoveredProvider), isFalse);
  });

  testWidgets('AND A TICKER UNDER A COVERED SCREEN IS GIVEN NO FRAMES', (
    tester,
  ) async {
    // The whole point: `TickerMode` off means the clock stops, and the widget
    // is not rebuilt or hidden — there is nothing to see behind an opaque
    // sheet, so what stops is only the work.
    var frames = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Consumer(
            builder: (context, ref, _) => TickerMode(
              enabled: !ref.watch(screenIsCoveredProvider),
              child: _Ticking(onFrame: () => frames++),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    final before = frames;
    expect(before, greaterThan(0));

    container.read(screenCoveredProvider.notifier).state = 1;
    await tester.pump();
    final held = frames;
    await tester.pump(const Duration(milliseconds: 200));
    expect(frames, held, reason: 'it kept animating behind the sheet');

    container.read(screenCoveredProvider.notifier).state = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(frames, greaterThan(held));
  });
}
