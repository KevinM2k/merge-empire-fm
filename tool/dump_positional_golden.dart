/// Regenerates the Dart-owned match goldens.
///
///   dart run tool/dump_positional_golden.dart
///
/// Writes `test/fixtures/positional_golden.json` (league scenarios and cup
/// runs) and `test/fixtures/positional_season_golden.json` (whole seasons) by
/// replaying the scenario set in `test/support/positional_scenarios.dart`
/// through the Dart engine. Plain `dart run`, not node, so it regenerates from
/// a cloud container — which the `.mjs` dumpers cannot, because the JS is not
/// cloned there.
///
/// **Run it only for a change that is MEANT to move scorelines**, and say so
/// in the commit. A golden pins whatever it was handed: regenerating it over a
/// failing test is how a bug becomes the reference. The balance suite
/// (`test/engine/positional_balance_test.dart`) is what says the new numbers
/// are right; this only says they are the numbers.
library;

import 'dart:convert';
import 'dart:io';

import '../test/support/positional_scenarios.dart';

void main() {
  final matches = <String, dynamic>{};
  for (final sc in matchScenarios) {
    matches[sc.name] = runMatchScenario(sc);
  }
  final cups = <String, dynamic>{};
  for (final sc in cupScenarios) {
    cups[sc.label] = runCupScenario(sc);
  }
  cups['playCupRound'] = runCupOneShot();

  File(positionalGoldenPath).writeAsStringSync(
    jsonEncode({
      'fixedNow': positionalFixedNow,
      'matches': matches,
      'cups': cups,
    }),
  );

  final runs = <String, dynamic>{};
  for (final label in seasonRuns().keys) {
    runs[label] = runSeasonRun(label);
  }
  File(positionalSeasonGoldenPath).writeAsStringSync(
    jsonEncode({
      'fixedNow': positionalFixedNow,
      'seasons': seasonsPerRun,
      'runs': runs,
    }),
  );

  stderr.writeln(
    'wrote ${matches.length} match scenarios, ${cups.length} cup records, '
    '${runs.length} season runs',
  );
}
