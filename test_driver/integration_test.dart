import 'package:integration_test/integration_test_driver.dart';

// Entry point for `flutter drive`, which is the only way traceAction timings
// get written to disk. Perf probes must be run this way, on a physical device
// in profile mode — simulator and debug-mode numbers are not meaningful.
Future<void> main() => integrationDriver();
