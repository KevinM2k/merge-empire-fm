/// The figures come off ONE sheet, so every frame rectangle must lie on it
/// and be the size the pack's pieces are.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';

void main() {
  test('every frame is on the 189×199 sheet and the size its piece is', () {
    for (final MapEntry(key: kit, value: frames) in cutawaySheetFrames.entries) {
      expect(frames.length, 14, reason: kit);
      for (final MapEntry(key: i, value: (x, y, w, h)) in frames.entries) {
        expect(x + w, lessThanOrEqualTo(189), reason: '$kit $i');
        expect(y + h, lessThanOrEqualTo(199), reason: '$kit $i');
        expect((w, h), i <= 10 ? (21, 31) : (19, 13), reason: '$kit $i');
      }
    }
  });

  test('the cache is asked for two files, not thirty-one', () {
    expect(cutawaySpritePaths(), ['sheet_characters.png', 'ball.png']);
  });
}
