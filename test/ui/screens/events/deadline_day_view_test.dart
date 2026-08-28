/// Arriving on the trading floor, taking the number a club comes back with, and
/// reading the night back in the currency the wallet is billed in.
///
/// The window being open IS the invitation, so the screen opens the session on
/// the way in — and it used to do that from `initState`, which is DURING a
/// build. Opening a session writes to the save, the save bumps
/// `saveRevisionProvider`, and Riverpod refuses a provider write while the tree
/// is building. In release the assertion is compiled out; in debug the screen
/// threw on the way in and the player landed on the intro instead of the floor.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart' show saveDebounceMs;
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/events/deadline_day_view.dart';
import 'package:merge_empire_fc/ui/screens/events/deadline_deal_sheets.dart';
import 'package:merge_empire_fc/ui/screens/events/event_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

void main() {
  tearDown(resetLocale);

  testWidgets('opens the session without throwing, and lands on the floor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = createDefaultState();
    final events = state['events'] as Map<String, dynamic>;
    // Forced outside the real calendar — the window opened on the last whole
    // hour, exactly as a dev override does on a device.
    events['devOverride'] = 'deadline_day';
    events['active'] = ['deadline_day'];

    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameProvider).load();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const EventScreen(),
          ),
        ),
      ),
    );
    // The frame that opens the session, then the one that paints the floor.
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('deadline-live')),
      findsOneWidget,
      reason: 'the window was open and the screen did not let us in',
    );

    // **AND THE HEAD IS COLIN, not the teacher emoji.** `🧑‍🏫` was a stand-in
    // from before there was any art of him, and it survived here — and on the
    // cup view and the event banner — while the dock, the floating head and his
    // own card all drew the real portrait. Reported off this screen.
    expect(find.byType(CoachFace), findsWidgets);
    expect(find.text('🧑‍🏫'), findsNothing);

    // The screen owns a 1Hz ticker for the whole hour, and opening the session
    // armed the save debounce; both have to go before the binding checks for
    // pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  });

  /// A save holding one signing that a club has countered.
  ///
  /// Built by hand rather than driven through a session: reaching a counter for
  /// real means seeding until a club haggles, which the engine's own tests do.
  /// What is pinned here is what the CARD does once the figure is on the
  /// listing.
  Map<String, dynamic> counteredSave() {
    final state = createDefaultState();
    // Enough in the bank that the card's own blocked line stays out of the way:
    // it takes the slot the counter line uses, and quite right too.
    (state['resources'] as Map<String, dynamic>)['fanCoins'] = 500000;
    state['deadlineDay'] = <String, dynamic>{
      'session': <String, dynamic>{
        'listings': <dynamic>[
          <String, dynamic>{
            'listingId': 'L1',
            'kind': 'signing',
            'status': 'live',
            'definitionId': 'p1',
            'playerName': 'Smith',
            'fromTeam': 'Rovers',
            'price': 3600,
            'spawnAt': 0,
            'expiresAt': 1 << 40,
            'haggleRounds': 2,
            'sellerCounter': <String, dynamic>{
              'price': 4500,
              'offer': <String, dynamic>{'cash': 3200, 'players': <dynamic>[]},
            },
          },
        ],
      },
      'history': <dynamic>[],
    };
    return state;
  }

  testWidgets('a countered listing offers THEIR number, not the sticker', (
    tester,
  ) async {
    // The engine stamped a figure on the listing and, until this landed, no
    // screen could take it: the card went on offering the asking price the club
    // had just refused, and the only sign of the counter was a snackbar with no
    // number in it.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = counteredSave();
    final listings =
        ((state['deadlineDay'] as Map)['session'] as Map)['listings'] as List;
    var countered = 0;
    var took = 0;

    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameProvider).load();
    final live = container.read(gameProvider).state!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DeadlineListingCard(
                  listing: listings.first as Map<String, dynamic>,
                  state: live,
                  clockRevision: 0,
                  onPass: () {},
                  onNegotiate: () {},
                  onTake: () => took++,
                  onCounter: () => countered++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('dd-counter-L1')),
      findsOneWidget,
      reason: 'nothing on the card says why the figure has moved',
    );
    // Nothing but cash was on the table, so the whole of their 4,500 is ours to
    // pay — and it replaces a sticker price of 3,600 the club has walked away
    // from. Both figures are under the ten thousand at which `formatCoins`
    // starts abbreviating, so the card has to print them in full and the two
    // cannot be confused for each other.
    expect(find.textContaining('4,500'), findsWidgets);
    expect(
      find.textContaining('3,600'),
      findsNothing,
      reason: 'the card is still quoting a price the club refused',
    );

    await tester.tap(find.byKey(const ValueKey('dd-take-L1')));
    await tester.pump();
    expect(countered, 1, reason: 'the button did not offer the counter');
    expect(took, 0, reason: 'it took the old price instead');
  });

  testWidgets("the ledger's wage line is a RATE, not a per-match figure", (
    tester,
  ) async {
    // The summary map is compared against the JS's own object field for field,
    // so its `wageBill` is the JS's per-match arithmetic — and nothing has
    // charged per match since wages became a drain on the income rate. The row
    // printed it anyway, with a "/ match" suffix, beside a spend and an income
    // the player really is billed. It asks the squad now.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = createDefaultState();
    (state['grid'] as Map<String, dynamic>)['cells'] = <dynamic>[
      <String, dynamic>{
        'instanceId': 'loanee',
        'definitionId': 'player_t5_mid',
        'seasonsPlayed': 0,
        'loanMatchesLeft': 6,
        // The terms the listing carried. Deliberately absurd, so a row reading
        // it instead of the squad is unmistakable.
        'loanWage': 999999,
      },
    ];

    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameProvider).load();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: DeadlineLedger(
                  summary: <String, dynamic>{
                    'sales': 0,
                    'signings': 0,
                    'loans': 1,
                    'loanOuts': 0,
                    'offers': <String, dynamic>{},
                    'income': 0,
                    'spend': 0,
                    'wageBill': 999999,
                    'net': 0,
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // A rate carries its own unit, and the retired suffix is gone with the
    // figure it labelled.
    expect(find.textContaining('/s'), findsWidgets);
    expect(find.textContaining('/ match'), findsNothing);
    expect(
      find.textContaining('999,999'),
      findsNothing,
      reason: "the row is reading the JS's per-match arithmetic",
    );
  });

  group('the deal wears its own colour', () {
    /// One live listing of a given kind, drawn on its own.
    Future<Color> facePaintedFor(
      WidgetTester tester, {
      required String kind,
      bool marquee = false,
      bool light = false,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final state = createDefaultState();
      (state['resources'] as Map<String, dynamic>)['fanCoins'] = 500000;
      final listing = <String, dynamic>{
        'listingId': 'L1',
        'kind': kind,
        'status': 'live',
        'definitionId': 'p1',
        'playerName': 'Smith',
        'fromTeam': 'Rovers',
        'price': 3600,
        'spawnAt': 0,
        'expiresAt': 1 << 40,
        if (marquee) 'marquee': true,
      };
      state['deadlineDay'] = <String, dynamic>{
        'session': <String, dynamic>{'listings': <dynamic>[listing]},
        'history': <dynamic>[],
      };
      (state['settings'] as Map<String, dynamic>)['theme'] = light
          ? 'light'
          : 'dark';

      final container = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(gameProvider).load();
      final live = container.read(gameProvider).state!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DeadlineListingCard(
                    listing: listing,
                    state: live,
                    clockRevision: 0,
                    onPass: () {},
                    onNegotiate: () {},
                    onTake: () {},
                    onCounter: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The FACE, which is what `backgroundBuilder` paints — not the Material
      // behind it, which is where `styleFrom` used to put the colour.
      final face = find.descendant(
        of: find.byKey(const ValueKey('dd-take-L1')),
        matching: find.byType(AnimatedContainer),
      );
      final decoration =
          tester.widget<AnimatedContainer>(face.first).decoration
              as BoxDecoration;
      return decoration.color!;
    }

    testWidgets('so two kinds do not share one accept button', (tester) async {
      // **`ElevatedButton.styleFrom(backgroundColor:)` never reached the
      // face.** The moulded style paints it in a `backgroundBuilder` over a
      // transparent Material, so the colour landed underneath and every accept
      // button on the board came out the theme's accent — four kinds of
      // business, one green button, and the fill it did apply covered the hard
      // bottom edge as well.
      final bid = await facePaintedFor(tester, kind: 'bid');
      final loan = await facePaintedFor(tester, kind: 'loan');
      final signing = await facePaintedFor(tester, kind: 'signing');

      expect(bid, const Color(0xFF43A047));
      expect(loan, const Color(0xFF8E5BC0));
      expect(signing, const Color(0xFF1E88C7));
      expect({bid, loan, signing}, hasLength(3));
    });

    testWidgets('and a marquee arrives in gold, whatever kind it is', (
      tester,
    ) async {
      // The spec's `marquee` branch outranks the kind and the port had no
      // branch at all, so the one listing on the board meant to arrive in gold
      // wore whatever its kind wears.
      expect(
        await facePaintedFor(tester, kind: 'bid', marquee: true),
        const Color(0xFFD8A01A),
      );
    });

    testWidgets('the accept button keeps its hard bottom edge', (tester) async {
      // What the buried fill cost: the edge bar is drawn INSIDE the face's box,
      // and a `backgroundColor` on the Material filled the full button rect
      // over the top of it.
      await facePaintedFor(tester, kind: 'bid');
      final face = find.descendant(
        of: find.byKey(const ValueKey('dd-take-L1')),
        matching: find.byType(AnimatedContainer),
      );
      final decoration =
          tester.widget<AnimatedContainer>(face.first).decoration
              as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.first.color, const Color(0xFF205C23));
      expect(decoration.boxShadow!.first.blurRadius, 0, reason: 'a bar, not a glow');

      // And nothing is painting over it: the Material behind the face has to
      // stay transparent for the edge to show.
      final materials = find.descendant(
        of: find.byKey(const ValueKey('dd-take-L1')),
        matching: find.byType(Material),
      );
      for (final m in materials.evaluate()) {
        expect((m.widget as Material).color?.a ?? 0, 0);
      }
    });
  });

}
