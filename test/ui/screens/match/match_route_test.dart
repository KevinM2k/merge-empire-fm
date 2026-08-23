/// The route a league match is played on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';

void main() {
  test('THE MATCH LEAVES INSTANTLY, so the summary lands on the whistle', () {
    // The awaited push does not resolve until the exit has finished animating,
    // and the summary is pushed after that — so three hundred milliseconds of
    // exit is three hundred milliseconds of the Play tab in the middle of a
    // result. Reported as the home page showing before the end-of-game screen.
    final route = MatchRoute<void>(builder: (_) => const SizedBox.shrink());
    expect(route.reverseTransitionDuration, Duration.zero);
    // The ENTRANCE is untouched — `transitionDuration` is the theme's, and
    // asking a route for it outside a tree is a null check on the theme.
    expect(route.fullscreenDialog, isTrue);
  });
}
