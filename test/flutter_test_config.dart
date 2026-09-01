/// Package-wide setup for every widget test in the suite.
///
/// **AN AMBIENT ANIMATION HANGS `pumpAndSettle`, and that is not a bug in
/// either of them.** `pumpAndSettle` returns when the tree stops changing;
/// something that repeats for as long as it is on screen never lets it. The
/// shop's tile shine is exactly that, and shop tiles are rendered by the
/// shell's tests, the home screen's, the club's and the light-mode contrast
/// sweep as well as the shop's own — so gating it on each harness would leave
/// the next test anybody writes hanging with no clue as to why.
///
/// Dart's test runner looks for this file once per package and wraps the whole
/// run in it, which makes it the one honest place for a switch like this.
/// `shopShineEnabled` is off for tests and on for players; a test that wants
/// the animation can set it back for its own duration.
library;

import 'dart:async';

import 'package:merge_empire_fc/ui/screens/shop/shop_shine.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  shopShineEnabled = false;
  await testMain();
}
