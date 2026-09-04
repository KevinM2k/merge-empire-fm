/// Renders the manager rig to contact sheets, so a change to him can be SEEN
/// rather than reasoned about.
///
/// ```bash
/// flutter test tool/rig_dump.dart          # → build/rig_dump/*.png
/// RIG_DUMP_DIR=/somewhere flutter test tool/rig_dump.dart
/// ```
///
/// Each sheet is a grid of the production widget captured at a chosen stride
/// phase, gesture progress, look and mood. The order of cells is printed as the
/// sheet is written, because the test font draws no readable labels.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_ball.dart'
    show ballGroundLine, ballHomeX, ballSize;
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// Device pixels per art unit.
const double _scale = 3;

typedef _Cell = ({
  String label,
  Map<String, dynamic> look,
  double t,
  Gesture? gesture,
  int pumpMs,
  bool carrying,
  bool ball,
  bool standing,
  Mood mood,
});

_Cell _cell(
  String label, {
  Map<String, dynamic> look = const {},
  double t = 0.25,
  Gesture? gesture,
  int pumpMs = 0,
  bool carrying = false,
  bool ball = false,
  bool standing = false,
  Mood mood = Mood.neutral,
}) => (
  label: label,
  look: {
    'build': 'regular',
    'outfit': 'kit',
    'style': 'crop',
    'hair': '#3a2a1c',
    'skin': '#e8b48c',
    'beard': 'none',
    'hat': 'none',
    'face': 'none',
    'neck': 'none',
    ...look,
  },
  t: t,
  gesture: gesture,
  pumpMs: pumpMs,
  carrying: carrying,
  ball: ball,
  standing: standing,
  mood: mood,
);

const Gesture _kick = Gesture(id: 'kick', ms: 520, weight: {});

Gesture _g(String id, [int ms = 2000]) => Gesture(id: id, ms: ms, weight: {});

void main() {
  final dir = Directory(
    Platform.environment['RIG_DUMP_DIR'] ?? 'build/rig_dump',
  )..createSync(recursive: true);

  Future<ui.Image> capture(WidgetTester tester, _Cell c, {double scale = _scale}) async {
    final key = GlobalKey();
    final beat = ValueNotifier<double>(c.t * 2);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: walkerWidth,
              height: walkerHeight,
              child: WalkBeat(
                notifier: beat,
                child: ManagerWalker(
                  kit: const Color(0xFF4CAF50),
                  skin: const Color(0xFFE8B48C),
                  hair: const Color(0xFF3A2A1C),
                  look: c.look,
                  mood: c.mood,
                  standing: c.standing,
                  carrying: c.carrying,
                  gesture: c.gesture == null ? null : GestureCue(c.gesture!),
                  ballLayer: c.ball
                      ? Positioned(
                          left: ballHomeX + (c.carrying ? -4 : 5),
                          bottom: ballGroundLine + (c.carrying ? 59 : 0),
                          width: ballSize,
                          height: ballSize,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF4F4F4),
                              border: Border.fromBorderSide(
                                BorderSide(color: Color(0xFF222222), width: 1.2),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (c.pumpMs > 0) await tester.pump(Duration(milliseconds: c.pumpMs));
    late ui.Image image;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      image = await boundary.toImage(pixelRatio: scale);
    });
    return image;
  }

  Future<void> sheet(
    WidgetTester tester,
    String name,
    List<_Cell> cells, {
    int cols = 8,
    double scale = _scale,
  }) async {
    final images = <ui.Image>[];
    for (final c in cells) {
      images.add(await capture(tester, c, scale: scale));
    }
    const pad = 6.0;
    final cw = walkerWidth * scale;
    final ch = walkerHeight * scale;
    final rows = (cells.length + cols - 1) ~/ cols;
    final w = cols * (cw + pad) + pad;
    final h = rows * (ch + pad) + pad;
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF6FA35A),
      );
      for (var i = 0; i < images.length; i++) {
        final x = pad + (i % cols) * (cw + pad);
        final y = pad + (i ~/ cols) * (ch + pad);
        canvas.drawRect(
          Rect.fromLTWH(x, y, cw, ch),
          Paint()..color = const Color(0xFF7DB36A),
        );
        canvas.drawImage(images[i], Offset(x, y), Paint());
      }
      final picture = rec.endRecording();
      final out = await picture.toImage(w.round(), h.round());
      final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${dir.path}/$name.png');
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      stdout.writeln('${file.path}: ${cells.map((c) => c.label).join(', ')}');
    });
  }

  testWidgets('walk', (tester) async {
    await sheet(tester, 'walk', [
      for (var i = 0; i < 8; i++)
        _cell('t=${i / 8}', t: i / 8, look: {'style': 'flow'}),
      _cell('standing', standing: true, look: {'style': 'flow'}),
      _cell('elated', mood: Mood.elated, t: 0.6),
      _cell('crushed', mood: Mood.crushed, t: 0.6),
    ]);
  });

  testWidgets('kick and carry', (tester) async {
    const t = 0.8;
    await sheet(tester, 'kick_carry', [
      for (final p in [0.0, 0.3, 0.45, 0.6, 0.7, 0.8, 1.0])
        _cell(
          'kick $p',
          t: t,
          gesture: _kick,
          pumpMs: (p * 520).round(),
          ball: true,
        ),
      _cell('carry t=.25', t: 0.25, carrying: true, pumpMs: 300, ball: true),
      _cell('carry t=.75', t: 0.75, carrying: true, pumpMs: 300, ball: true),
      _cell('ball at boot', t: 0.25, ball: true),
    ]);
  });

  testWidgets('hair', (tester) async {
    const styles = [
      'crop', 'buzz', 'afro', 'pony', 'bun', 'flow', 'mohawk',
      'spikes', 'mullet', 'curtains', 'dreads', 'slick', 'fauxhawk', 'braids',
    ];
    await sheet(tester, 'hair', [
      for (final s in styles) _cell(s, look: {'style': s}, t: 0.375),
      for (final s in ['pony', 'flow', 'dreads', 'curtains'])
        _cell('$s t=.875', look: {'style': s}, t: 0.875),
    ], cols: 7);
  });

  testWidgets('wardrobe', (tester) async {
    await sheet(tester, 'wardrobe', [
      for (final h in ['cap', 'beanie', 'flatcap', 'tophat', 'bucket', 'viking', 'crown', 'sunhat'])
        _cell(h, look: {'hat': h, 'style': 'flow'}),
      for (final o in ['tracksuit', 'coat', 'suit'])
        _cell(o, look: {'outfit': o}),
      for (final b in ['full', 'moustache', 'stubble'])
        _cell(b, look: {'beard': b}),
      for (final f in ['specs', 'shades', 'cigar'])
        _cell(f, look: {'face': f}),
    ]);
  });

  testWidgets('builds and gestures', (tester) async {
    await sheet(tester, 'builds_gestures', [
      for (final b in ['regular', 'lean', 'broad', 'belly', 'athletic', 'curvy'])
        _cell(b, look: {'build': b}, t: 0.25),
      for (final (g, p) in [
        ('fistpump', 0.5), ('applaud', 0.3), ('point', 0.5),
        ('handsonhips', 0.5), ('wave', 0.5), ('armsfolded', 0.5),
        ('bow', 0.5), ('checkwatch', 0.5), ('facepalm', 0.6), ('salute', 0.5),
      ])
        _cell(g, gesture: _g(g), pumpMs: (p * 2000).round(), standing: true),
    ]);
  });

  testWidgets('closeup', (tester) async {
    await sheet(tester, 'closeup', [
      _cell('neutral flow', look: {'style': 'flow'}, t: 0.375),
      _cell('elated cap', look: {'hat': 'cap', 'beard': 'stubble'}, mood: Mood.elated),
      _cell('crushed beanie coat', look: {'hat': 'beanie', 'outfit': 'coat', 'style': 'pony'}, mood: Mood.crushed),
      _cell('glum full beard suit', look: {'beard': 'full', 'outfit': 'suit', 'style': 'slick'}, mood: Mood.glum),
    ], cols: 4, scale: 7);
  });

  testWidgets('hats closeup', (tester) async {
    await sheet(tester, 'hats_closeup', [
      for (final h in ['cap', 'beanie', 'bucket', 'santa', 'visor', 'laurel', 'flatcap', 'headband'])
        _cell(h, look: {'hat': h, 'style': 'afro'}, t: 0.375),
    ], cols: 8, scale: 6);
  });

  testWidgets('life', (tester) async {
    // Seconds into the life cycle: the middle of the look-up, the survey and
    // the camera beat, plus the arms fold and a blown kiss, which turn him.
    await sheet(tester, 'life', [
      _cell('square', look: {'style': 'flow'}),
      _cell('look up', look: {'style': 'flow'}, pumpMs: 4700),
      _cell('survey', look: {'style': 'flow'}, pumpMs: 24100),
      _cell('camera', look: {'style': 'flow', 'hat': 'cap'}, pumpMs: 35400),
      _cell('armsfolded', gesture: _g('armsfolded'), pumpMs: 1000, standing: true, look: {'style': 'flow'}),
      _cell('blowkiss', gesture: _g('blowkiss'), pumpMs: 800, standing: true),
      _cell('applaud', gesture: _g('applaud'), pumpMs: 900, standing: true),
    ], cols: 7, scale: 5);
  });

  testWidgets('outfits closeup', (tester) async {
    await sheet(tester, 'outfits_closeup', [
      _cell('coat', look: {'outfit': 'coat', 'style': 'crop'}),
      _cell('coat scarf beanie', look: {'outfit': 'coat', 'hat': 'beanie', 'neck': 'scarf', 'style': 'slick'}),
      _cell('suit', look: {'outfit': 'suit', 'style': 'slick'}),
      _cell('suit beard', look: {'outfit': 'suit', 'beard': 'goatee', 'style': 'crop'}),
      _cell('tracksuit', look: {'outfit': 'tracksuit'}),
    ], cols: 5, scale: 7);
  });
}
