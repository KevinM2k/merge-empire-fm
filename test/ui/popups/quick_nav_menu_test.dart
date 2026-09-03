/// The quick-nav menu is the manager's PHONE now — asked for from the couch,
/// and a deliberate divergence from the JS's glass panel. What these pin is
/// that the case is drawn round the SAME menu: every tile still opens, and the
/// hardware round it is dressing rather than controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// Stands in for whatever a tile is nagging about — the real ones are
/// `savePick`s off the save; see `ui/shell/shell_quick_nav.dart`.
final _nagging = StateProvider<bool>((ref) => true);

void main() {
  tearDown(resetLocale);

  Future<void> open(
    WidgetTester tester,
    List<QuickNavGroup> groups, {
    double? battery,
  }) async {
    await tester.pumpWidget(
      // The phone re-reads its tiles from the route, so it wants a scope over
      // it — see `QuickNavGroupsBuilder`.
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  onPressed: () => showQuickNavMenu(
                    context,
                    groups: (_) => groups,
                    battery: battery,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  var opened = '';
  List<QuickNavGroup> groups() => [
    QuickNavGroup(
      titleKey: 'quicknav.group.league',
      items: [
        QuickNavItem(
          labelKey: 'subnav.fixtures',
          icon: Icons.calendar_month,
          onTap: () => opened = 'fixtures',
        ),
        QuickNavItem(
          labelKey: 'subnav.table',
          icon: Icons.format_list_numbered,
          dot: true,
          onTap: () => opened = 'table',
        ),
        QuickNavItem(
          labelKey: 'subnav.training',
          icon: Icons.fitness_center,
          onTap: () => opened = 'training',
        ),
      ],
    ),
    QuickNavGroup(
      titleKey: 'quicknav.group.rewards',
      items: [
        QuickNavItem(
          labelKey: 'scene.dock.trophies',
          icon: Icons.emoji_events,
          onTap: () => opened = 'trophies',
        ),
      ],
    ),
  ];

  setUp(() => opened = '');

  testWidgets('the menu is a handset: case, status bar, screen, home bar', (
    tester,
  ) async {
    await open(tester, groups());
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-nav-status')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-nav-home-bar')), findsOneWidget);
    // The status bar is glyphs and a clock, nothing to translate.
    expect(find.byKey(const ValueKey('quick-nav-battery')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-nav-battery-pct')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-nav-signal')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-nav-wifi')), findsOneWidget);
    // Phone-shaped: taller than wide, and never wider than a handset.
    final phone = tester.getRect(find.byKey(const ValueKey('quick-nav-phone')));
    expect(phone.width, lessThanOrEqualTo(330));
    expect(phone.height, greaterThan(phone.width));
  });

  testWidgets('and the same menu is on its screen, under the app\'s name', (
    tester,
  ) async {
    await open(tester, groups());
    expect(find.text(dugoutAppName), findsOneWidget);
    expect(find.text(t('quicknav.title')), findsNothing);
    expect(find.text(t('quicknav.group.league').toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-nav-subnav.fixtures')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-nav-subnav.table')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-nav-scene.dock.trophies')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('quick-nav-dot-subnav.table')), findsOneWidget);
    // Every tile sits INSIDE the case.
    final phone = tester.getRect(find.byKey(const ValueKey('quick-nav-phone')));
    for (final key in ['subnav.fixtures', 'subnav.table', 'scene.dock.trophies']) {
      final tile = tester.getRect(find.byKey(ValueKey('quick-nav-$key')));
      expect(phone.contains(tile.topLeft) && phone.contains(tile.bottomRight), isTrue,
          reason: '$key is off the phone');
    }
  });

  testWidgets('three tiles to a row, exactly', (tester) async {
    // It was wrapping to two: 92-wide tiles in a case narrower than the old
    // panel. The tile is a third of the row now, the way the spec's is.
    await open(tester, groups());
    final tops = [
      for (final key in ['subnav.fixtures', 'subnav.table', 'subnav.training'])
        tester.getRect(find.byKey(ValueKey('quick-nav-$key'))).top,
    ];
    expect(tops.toSet().length, 1, reason: 'the three did not share a row');
    final fixtures = tester.getRect(
      find.byKey(const ValueKey('quick-nav-subnav.fixtures')),
    );
    final training = tester.getRect(
      find.byKey(const ValueKey('quick-nav-subnav.training')),
    );
    expect(training.left, greaterThan(fixtures.right));
  });

  testWidgets('it is raised straight up from the bottom', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  onPressed: () =>
                      showQuickNavMenu(context, groups: (_) => groups()),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // Early in the raise it sits low, and on the SAME vertical line it settles
    // on: the lift is straight up out of the hand, not in from a corner.
    final early = tester.getCenter(find.byKey(const ValueKey('quick-nav-phone')));
    await tester.pumpAndSettle();
    final settled = tester.getCenter(find.byKey(const ValueKey('quick-nav-phone')));
    expect(early.dy, greaterThan(settled.dy + 40));
    expect(early.dx, closeTo(settled.dx, 1));
  });

  testWidgets('the app bar names the club signed in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  onPressed: () => showQuickNavMenu(
                    context,
                    groups: (_) => groups(),
                    clubName: 'Iron Stars',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.text('Iron Stars'), findsOneWidget);
    expect(find.text(dugoutAppName), findsOneWidget);
  });

  testWidgets('the battery is the game\'s energy', (tester) async {
    await open(tester, groups(), battery: 0.1);
    expect(find.text('10%'), findsOneWidget);
    expect(batteryLow(0.1), isTrue);
    expect(batteryLow(0.2), isTrue);
    expect(batteryLow(0.21), isFalse);
  });

  testWidgets('and reads full when nothing is behind the call', (tester) async {
    await open(tester, groups());
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('a tile opens its door and LEAVES THE PHONE OPEN', (tester) async {
    await open(tester, groups());
    await tester.tap(find.byKey(const ValueKey('quick-nav-subnav.table')));
    await tester.pumpAndSettle();
    expect(opened, 'table');
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsOneWidget);
  });

  testWidgets('THE TILES ARE READ FROM THE ROUTE, not frozen at open', (
    tester,
  ) async {
    // The doors on this phone open OVER it and closing one lands the player
    // back here, so a menu built once at open time goes on nagging about
    // something dealt with behind it — which is exactly what a finished drill
    // did. See `QuickNavGroupsBuilder`.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  onPressed: () => showQuickNavMenu(
                    context,
                    groups: (ref) => [
                      QuickNavGroup(
                        titleKey: 'quicknav.group.activity',
                        items: [
                          QuickNavItem(
                            labelKey: 'subnav.training',
                            icon: Icons.fitness_center,
                            dot: ref.watch(_nagging),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-nav-dot-subnav.training')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('open'))),
    );
    container.read(_nagging.notifier).state = false;
    await tester.pump();

    expect(find.byKey(const ValueKey('quick-nav-phone')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-nav-dot-subnav.training')),
      findsNothing,
    );
  });

  testWidgets('and tapping off the phone lowers it the way it came', (
    tester,
  ) async {
    await open(tester, groups());
    final settled = tester.getCenter(find.byKey(const ValueKey('quick-nav-phone')));
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    // By the last frames it is well down, on its way off — and straight down
    // the line it rose on, which is what makes the lowering the raise reversed.
    // Must stay INSIDE the raise's own duration, or the route has finished and
    // there is no phone left to measure.
    await tester.pump(const Duration(milliseconds: 280));
    final going = tester.getCenter(find.byKey(const ValueKey('quick-nav-phone')));
    expect(going.dy, greaterThan(settled.dy + 40));
    expect(going.dx, closeTo(settled.dx, 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsNothing);
    expect(opened, '');
  });

  testWidgets('a tap on the bezel puts the phone away; one on the glass does not', (
    tester,
  ) async {
    await open(tester, groups());
    final phone = tester.getRect(find.byKey(const ValueKey('quick-nav-phone')));
    final status = tester.getRect(find.byKey(const ValueKey('quick-nav-status')));
    // Empty glass under the status bar, between nothing tappable.
    await tester.tapAt(Offset(status.center.dx, status.bottom + 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsOneWidget);
    // The bezel: the strip between the phone's edge and the glass.
    await tester.tapAt(Offset(phone.left + 2, phone.center.dy));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsNothing);
    expect(opened, '');
  });

  testWidgets('and it is a phone\'s proportions, centred on the screen', (
    tester,
  ) async {
    await open(tester, groups());
    final phone = tester.getRect(find.byKey(const ValueKey('quick-nav-phone')));
    expect(phone.height / phone.width, greaterThan(1.6));
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(phone.center.dx, closeTo(screen.width / 2, 1));
  });

  testWidgets('no tile is under the thumb or the fingertips, at any size', (
    tester,
  ) async {
    for (final size in [const Size(400, 800), const Size(390, 700), const Size(360, 640)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, groups());
      final phone = tester.getRect(find.byKey(const ValueKey('quick-nav-phone')));
      final thumb = Rect.fromLTRB(
        phone.left + phone.width * phoneThumbZone.left,
        phone.top + phone.height * phoneThumbZone.top,
        phone.right,
        phone.top + phone.height * phoneThumbZone.bottom,
      );
      final fingers = phone.left + phone.width * phoneFingerReach;
      for (final key in ['subnav.fixtures', 'subnav.table', 'subnav.training', 'scene.dock.trophies']) {
        final tile = tester.getRect(find.byKey(ValueKey('quick-nav-$key')));
        expect(tile.overlaps(thumb), isFalse, reason: '$key is under the thumb at $size');
        expect(tile.left, greaterThanOrEqualTo(fingers - 0.5), reason: '$key is under the fingers at $size');
      }
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('it fits a short screen by scrolling the screen, not the case', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester, [for (var i = 0; i < 4; i++) ...groups()]);
    final phone = tester.getRect(find.byKey(const ValueKey('quick-nav-phone')));
    expect(phone.top, greaterThanOrEqualTo(0));
    expect(phone.bottom, lessThanOrEqualTo(560));
    expect(find.byKey(const ValueKey('quick-nav-home-bar')), findsOneWidget);
  });
}
