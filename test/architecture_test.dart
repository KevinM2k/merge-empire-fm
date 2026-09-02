import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart' show minFontSize;

/// The spec requires the game logic to stay Flutter-free so it runs under plain
/// `dart test` and ports cleanly — the same discipline the JS side enforces by
/// running engine tests in a `node` environment with no `window`/`document`.
///
/// Discipline alone does not survive 37 engines, so it is checked.
void main() {
  const pureDirs = [
    'lib/engine',
    'lib/data',
    'lib/i18n',
    'lib/state',
    'lib/util',
  ];

  final flutterImport = RegExp(
    r'''^\s*import\s+['"]package:flutter/''',
    multiLine: true,
  );

  for (final dir in pureDirs) {
    test('$dir imports no Flutter libraries', () {
      final directory = Directory(dir);
      if (!directory.existsSync()) return;

      final offenders = <String>[];
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (flutterImport.hasMatch(entity.readAsStringSync())) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These files import package:flutter and must not — game logic has '
            'to run without a widget binding:\n${offenders.join('\n')}',
      );
    });
  }

  test('at least one pure directory exists and was actually scanned', () {
    // Guards the loop above from passing vacuously if the tree is restructured.
    final scanned = pureDirs.where((d) => Directory(d).existsSync()).toList();
    expect(scanned, isNotEmpty);
  });

  /// **`styleFrom` CANNOT COLOUR A MOULDED BUTTON, and it fails silently.**
  ///
  /// Every Elevated/Filled/Outlined button in the game wears
  /// `mouldedButtonStyle` through the theme, which paints the face in a
  /// `backgroundBuilder` and leaves the Material behind it transparent. So:
  ///
  /// * `backgroundColor:` colours the layer UNDER the face — invisible, except
  ///   that it fills the FULL button rect while the face sits 4pt inside it, so
  ///   it buries the hard bottom edge and the button reads as a flat slab.
  /// * `side:` is drawn by the Material on that same full rect, which puts a
  ///   second outline 4pt above the moulded one — a ridge along the top edge.
  ///
  /// Neither throws, neither analyses, and both have shipped: the coach card's
  /// cancels came out three-dimensional the wrong way up, every Deadline Day
  /// accept button was the theme's green whatever deal it belonged to, and the
  /// sell sheet's live Cancel wore a disabled button's ink on a disabled
  /// button's outline. The face and the edge have to go through the helper —
  /// `mouldedButtonStyle(face: ..., edge: ...)` — which is what reaches the
  /// builder.
  ///
  /// `foregroundColor:` is fine and deliberately not caught: it is the label's
  /// ink and it resolves normally.
  /// **NOTHING IS DECLARED SMALLER THAN [minFontSize].**
  ///
  /// The UI had drifted to 246 sizes under it — a spread of 7.5, 8, 8.5, 9,
  /// 9.5, 10, 10.5, 11 and 11.5 — because every tight slot was solved by taking
  /// a point off the type, and nothing anywhere said stop. Asked for from the
  /// couch by pointing at a line that was legible and saying that size is the
  /// floor.
  ///
  /// It is checked rather than trusted for the same reason the moulded style
  /// below it is: the next tight slot will want a 10 too, and a rule that lives
  /// only in a doc comment loses that argument every time. The way to fit type
  /// into a slot that cannot hold it is `FittedBox`, which shrinks at DRAW time
  /// and only where it is actually needed.
  test('no text is declared below the type floor', () {
    // **EVERY LITERAL ON THE LINE, not just one straight after the colon.**
    // The first cut matched `fontSize: 11` and missed `fontSize: small ? 11 :
    // 14` — which is the Invest button, one of the most-pressed controls in the
    // game, and it was reported as still being the small one while the sweep
    // said the app was clean. A ternary is the shape this fault takes.
    //
    // A number that is being MULTIPLIED or divided is a ratio rather than a
    // size — `size * 0.27` on a pack tile — so those are skipped; what such a
    // line needs is a `clamp`, and the clamp's own floor is a literal this does
    // check.
    final line = RegExp(r'fontSize:([^,;]*)');
    // The ratios come out FIRST — `size * 0.27`, `h / 3` — because Dart has no
    // variable-length lookbehind to spot them in place. What is left is the
    // sizes proper, including a clamp's own floor.
    final ratio = RegExp(r'([*/]\s*\d+(?:\.\d+)?)|(\d+(?:\.\d+)?\s*[*/])');
    final literal = RegExp(r'\b(\d+(?:\.\d+)?)\b');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in line.allMatches(lines[i])) {
          final expr = m.group(1)!.replaceAll(ratio, ' ');
          for (final n in literal.allMatches(expr)) {
            if (double.parse(n.group(1)!) < minFontSize) {
              offenders.add('${file.path}:${i + 1} —${m.group(1)}');
            }
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Text below ${minFontSize}pt. Use FittedBox to fit a slot rather '
          'than a smaller literal:\n${offenders.join('\n')}',
    );
  });

  test('no button colours its face through styleFrom', () {
    // The three that carry a moulded style. `TextButton` is left alone by the
    // theme on purpose — it is a text link — so it may style itself freely.
    final call = RegExp(
      r'(ElevatedButton|FilledButton|OutlinedButton)\.styleFrom\(',
    );
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in call.allMatches(src)) {
        // The argument list, found by balancing brackets from the open paren —
        // a fixed window would either miss a wrapped call or run into the next.
        var depth = 0;
        var i = m.end - 1;
        for (; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        final args = src.substring(m.end, i);
        for (final bad in ['backgroundColor:', 'side:']) {
          if (args.contains(bad)) {
            final line = src.substring(0, m.start).split('\n').length;
            offenders.add('${entity.path}:$line passes $bad');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These reach for a colour `styleFrom` cannot deliver on a moulded '
          'button. Ask `mouldedButtonStyle(face:, edge:, ...)` for the face '
          'instead:\n${offenders.join('\n')}',
    );
  });

  test('and the moulded style is still the thing being defended', () {
    // Guards the test above from passing because the app stopped moulding its
    // buttons, which would make it true and pointless at the same time.
    final theme = File('lib/ui/theme/app_theme.dart').readAsStringSync();
    expect(theme, contains('elevatedButtonTheme'));
    expect(theme, contains('mouldedButtonStyle'));
    final helper = File('lib/ui/widgets/store_button.dart').readAsStringSync();
    expect(
      helper,
      contains('backgroundBuilder'),
      reason: 'the face is painted there, which is the whole reason for this',
    );
  });

  // ---------------------------------------------------------------------------
  // Dead letters on the bus.
  // ---------------------------------------------------------------------------

  /// **A subscription to an event nobody emits is silent, and it is not rare.**
  ///
  /// `match:complete` shipped this way. `match_orchestration.dart` says, in a
  /// comment, that it deliberately does not emit at kick-off because "the UI
  /// fires it at full time" — and then no screen ever did. `game_host`
  /// subscribed to it to put a finished match on the four leaderboard rows and
  /// `game_wiring` subscribed to sweep achievements, so both hung off a signal
  /// that never arrived: every match a player finished, and no score on any
  /// global board. Nothing failed, nothing analysed, and the only symptom was a
  /// leaderboard that stayed still.
  ///
  /// That is the shape of the bug this catches: the two halves of a bus wiring
  /// live in different files by design — engines emit, the UI and the wiring
  /// listen — so neither half is wrong on its own and no test that builds one
  /// widget can see the gap. A grep over `lib/` can.
  ///
  /// Only `lib/` counts on either side. A test that emits an event is a test
  /// arranging its own fixture, not a caller — the same rule
  /// `tool/unreached.sh` uses.
  test('every bus event lib/ subscribes to is emitted somewhere in lib/', () {
    // What the port has decided it is not fixing yet. An entry here is a known
    // gap with a reason, not a way to make the test quiet — see
    // `docs/REMAINING.md`.
    const knownDeadLetters = {
      // Placing a scouted card emits `coins:updated` and, when the batch fell
      // short, `scout:short` — but never this. The coach tip host and the
      // achievement sweep both want it; both are covered by luck today,
      // because `signPlayers` emits `coins:updated` and the sweep listens to
      // that too. Where it belongs is a question about the scouting flow
      // rather than about the bus, so it is written down rather than guessed.
      'scout:placed',
    };

    final emitted = <String>{};
    final subscribed = <String, String>{};

    final emitCall = RegExp(r"""\bemit\(\s*'([^']+)'""");
    final listenCall = RegExp(r"""\b(?:on|_listen)\(\s*'([^']+)'""");
    // The wiring files register in bulk — `for (final event in const [...])`
    // then one `_listen(event, ...)` — so the names are in a list literal and
    // never appear beside a call at all. That loop is how the achievement
    // sweep subscribes, which is to say it is how `match:complete` was
    // subscribed to.
    final listenLoop = RegExp(
      r'for\s*\(\s*final\s+\w+\s+in\s+const\s*\[(.*?)\]\s*\)',
      dotAll: true,
    );
    final eventName = RegExp(r"'([a-z]+:[a-z_]+)'");

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Whole-line comments only. Every comment in this repo carries the
      // reasoning for the code under it and names the events freely — the file
      // head of `event_bus.dart` lists half of them — so a scan that counted
      // prose would report the bus as fully wired no matter what.
      final src = entity
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      for (final m in emitCall.allMatches(src)) {
        emitted.add(m.group(1)!);
      }
      for (final m in listenCall.allMatches(src)) {
        subscribed.putIfAbsent(m.group(1)!, () => entity.path);
      }
      for (final loop in listenLoop.allMatches(src)) {
        for (final m in eventName.allMatches(loop.group(1)!)) {
          subscribed.putIfAbsent(m.group(1)!, () => entity.path);
        }
      }
    }

    // The scan itself, before its verdict. Both sides have to have found real
    // work or "no dead letters" means "no events".
    expect(emitted, hasLength(greaterThan(50)));
    expect(subscribed, hasLength(greaterThan(20)));

    final dead = [
      for (final event in subscribed.keys.toList()..sort())
        if (!emitted.contains(event) && !knownDeadLetters.contains(event))
          '$event — subscribed in ${subscribed[event]}, emitted nowhere',
    ];

    expect(
      dead,
      isEmpty,
      reason:
          'These are dead letters: something in lib/ is listening and nothing '
          'in lib/ ever fires them, so the handler is unreachable and says so '
          'to nobody.\n${dead.join('\n')}',
    );
  });

  test('and match:complete is in the scan on BOTH sides', () {
    // The guard on the test above. It would pass just as happily if the regexes
    // stopped matching anything the wiring actually does, and the event that
    // was broken is the one worth naming: it is subscribed in a bulk loop and
    // emitted from a screen, so between them the two sides exercise every part
    // of that scan.
    final host = File('lib/providers/game_host.dart').readAsStringSync();
    expect(host, contains("on('match:complete', _submitMatch)"));

    final wiring = File('lib/state/game_wiring.dart').readAsStringSync();
    expect(wiring, contains("'match:complete',"));

    // Full time in the play button, and AFTER the outcome is settled: a tactic
    // change re-simulates the remainder and rewrites the scoreline in place, so
    // an emit above `settleMatch` would put the kick-off score on the board.
    final button = File(
      'lib/ui/screens/match/play_button.dart',
    ).readAsStringSync();
    final settle = button.indexOf('settleMatch(s, r)');
    final fire = button.indexOf("emit('match:complete', r)");
    expect(settle, greaterThan(-1));
    expect(fire, greaterThan(settle));
  });
}
