import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/shell/tab_transition.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';

void main() {
  test('moving right along the bar enters from the right', () {
    expect(
      enterModeFor(from: ShellTab.grid, to: ShellTab.shop, noSlide: false),
      EnterMode.fromRight,
    );
    expect(
      enterModeFor(from: ShellTab.home, to: ShellTab.club, noSlide: false),
      EnterMode.fromRight,
    );
  });

  test('moving left enters from the left', () {
    expect(
      enterModeFor(from: ShellTab.shop, to: ShellTab.grid, noSlide: false),
      EnterMode.fromLeft,
    );
    expect(
      enterModeFor(from: ShellTab.home, to: ShellTab.squad, noSlide: false),
      EnterMode.fromLeft,
    );
  });

  test('the same tab does not animate', () {
    for (final tab in tabOrder) {
      expect(
        enterModeFor(from: tab, to: tab, noSlide: false),
        EnterMode.none,
        reason: tab.name,
      );
    }
  });

  // The HUD's coin + and gem chip both deep-link this way.
  test('a deep link arrives with no transition at all', () {
    expect(
      enterModeFor(from: ShellTab.grid, to: ShellTab.shop, noSlide: true),
      EnterMode.none,
    );
    expect(
      enterModeFor(from: ShellTab.shop, to: ShellTab.grid, noSlide: true),
      EnterMode.none,
    );
  });

  test('the swipe threshold is the JS s 60px', () {
    expect(swipeThreshold, 60);
  });
}
