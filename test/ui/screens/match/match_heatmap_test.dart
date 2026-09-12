/// The heatmap is the positional record drawn on the squad tab's pitch, in
/// the squad tab's frame: our goal at the bottom, our right on screen-left.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/match_analysis.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/ui/screens/match/match_heatmap.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pitch.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

PositionalEvent _ev(int zone, {String side = 'ours', String t = 'duel'}) =>
    PositionalEvent(
      minute: 10,
      zone: zone,
      side: side,
      playerId: side == 'ours' ? 'c1' : 'ai:rb',
      opponentId: side == 'ours' ? 'ai:lb' : 'c2',
      type: t,
      outcome: t == 'shot' ? 'miss' : 'win',
      xg: t == 'shot' ? 0.2 : null,
    );

Future<void> pumpMap(WidgetTester tester, Map<String, dynamic> positional) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 200,
              child: MatchHeatmap(positional: positional),
            ),
          ),
        ),
      ),
    );

void main() {
  group('positionalOf', () {
    test('is null for a result with no record or an empty one', () {
      expect(positionalOf(const {}), isNull);
      expect(positionalOf({'positional': positionalSummary(const [])}), isNull);
      expect(positionalOf({'positional': 'nonsense'}), isNull);
    });

    test('is the record when it holds events', () {
      final p = positionalSummary([_ev(3)]);
      expect(positionalOf({'positional': p}), same(p));
    });
  });

  group('MatchHeatmap', () {
    testWidgets('stands on the squad pitch and paints the zones', (
      tester,
    ) async {
      await pumpMap(
        tester,
        positionalSummary([_ev(3), _ev(17, side: 'theirs')]),
      );
      expect(find.byType(SquadPitch), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('match-heatmap')),
      );
      final painter = paint.painter! as HeatmapPainter;
      expect(painter.ours[3], 1);
      expect(painter.ours[17], 0);
      expect(painter.theirs[17], 1);
      expect(painter.ourInk, isNot(painter.theirInk));
    });

    testWidgets('keeps the pitch at 7:10 inside the height it is given', (
      tester,
    ) async {
      await pumpMap(tester, positionalSummary([_ev(0)]));
      final size = tester.getSize(find.byKey(const ValueKey('match-heatmap')));
      expect(size.height, closeTo(200, 0.5));
      expect(size.width, closeTo(140, 0.5));
    });

    test(
      'a zone paints where the frame says: band 0 at the top, lane 0 left',
      () {
        // Paint into a 100×140 canvas and read the one wash back.
        final painter = HeatmapPainter(
          ours: [
            for (var z = 0; z < pitchZones; z++) z == zoneIndex(0, 0) ? 5 : 0,
          ],
          theirs: List.filled(pitchZones, 0),
          ourInk: const Color(0xFF00FF00),
          theirInk: const Color(0xFFFF0000),
        );
        final rects = <Rect>[];
        painter.paint(_RecordingCanvas(rects), const Size(100, 140));
        expect(rects.length, 1);
        expect(rects.single.left, closeTo(1.5, 1e-9));
        expect(rects.single.top, closeTo(1.5, 1e-9));
        expect(rects.single.width, closeTo(20 - 3, 1e-9));
        expect(rects.single.height, closeTo(35 - 3, 1e-9));
      },
    );

    test('the busiest zone is the strongest and a quiet one still shows', () {
      final painter = HeatmapPainter(
        ours: [
          for (var z = 0; z < pitchZones; z++) z == 7 ? 10 : (z == 8 ? 1 : 0),
        ],
        theirs: List.filled(pitchZones, 0),
        ourInk: const Color(0xFF00FF00),
        theirInk: const Color(0xFFFF0000),
      );
      final paints = <Paint>[];
      painter.paint(_RecordingCanvas([], paints), const Size(100, 140));
      expect(paints.length, 2);
      expect(paints.first.color.a, greaterThan(paints.last.color.a));
      expect(paints.last.color.a, greaterThan(0.1));
      expect(paints.first.color.a, lessThan(0.8));
    });

    test('repaints only when the record or the inks change', () {
      final a = HeatmapPainter(
        ours: List.filled(pitchZones, 0),
        theirs: List.filled(pitchZones, 0),
        ourInk: const Color(0xFF00FF00),
        theirInk: const Color(0xFFFF0000),
      );
      expect(a.shouldRepaint(a), isFalse);
      expect(
        a.shouldRepaint(
          HeatmapPainter(
            ours: List.filled(pitchZones, 1),
            theirs: a.theirs,
            ourInk: a.ourInk,
            theirInk: a.theirInk,
          ),
        ),
        isTrue,
      );
    });
  });
}

/// Records the rectangles and paints a painter draws.
class _RecordingCanvas implements Canvas {
  _RecordingCanvas(this.rects, [this.paints]);

  final List<Rect> rects;
  final List<Paint>? paints;

  @override
  void drawRect(Rect rect, Paint paint) {
    rects.add(rect);
    paints?.add(paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
