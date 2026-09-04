/// Renders the home diorama at several tiers, in both themes, so the backdrop
/// can be SEEN rather than reasoned about. Companion to `rig_dump.dart`.
///
/// ```bash
/// flutter test tool/scene_dump.dart        # → build/rig_dump/scene_*.png
/// ```
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

const double _w = 390;
const double _h = 400;
const double _scale = 2;

void main() {
  final dir = Directory(
    Platform.environment['RIG_DUMP_DIR'] ?? 'build/rig_dump',
  )..createSync(recursive: true);

  Future<ui.Image> capture(
    WidgetTester tester, {
    required int tier,
    required bool light,
    String condition = 'clear',
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: light),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: _w,
              height: _h,
              child: PitchScene(
                mood: Mood.neutral,
                tier: tier,
                condition: condition,
                walkerBottom: 150 + walkerBottomClearance,
                walkerBuilder: (ball) => ManagerWalker(
                  kit: const Color(0xFF4CAF50),
                  skin: const Color(0xFFE8B48C),
                  hair: const Color(0xFF3A2A1C),
                  look: const {'style': 'flow', 'outfit': 'kit'},
                  ballLayer: ball,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    late ui.Image image;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      image = await boundary.toImage(pixelRatio: _scale);
    });
    return image;
  }

  testWidgets('scenes', (tester) async {
    const tiers = [0, 1, 2, 3, 5];
    for (final light in [true, false]) {
      final images = <ui.Image>[];
      for (final tier in tiers) {
        images.add(await capture(tester, tier: tier, light: light));
      }
      await tester.runAsync(() async {
        const pad = 6.0;
        final cw = _w * _scale;
        final ch = _h * _scale;
        final w = tiers.length * (cw + pad) + pad;
        final h = ch + pad * 2;
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFF222222),
        );
        for (var i = 0; i < images.length; i++) {
          canvas.drawImage(images[i], Offset(pad + i * (cw + pad), pad), Paint());
        }
        final out = await rec.endRecording().toImage(w.round(), h.round());
        final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${dir.path}/scene_${light ? 'light' : 'dark'}.png');
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        stdout.writeln('${file.path}: tiers $tiers');
      });
    }
  });

  testWidgets('park closeup', (tester) async {
    for (final light in [true, false]) {
      final images = <ui.Image>[];
      for (final tier in [1, 2, 8]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(kitId: '#4caf50', light: light),
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: _w,
                  height: 300,
                  child: PitchScene(
                    mood: Mood.neutral,
                    tier: tier,
                    walkerBottom: 60 + walkerBottomClearance,
                    walkerBuilder: (ball) => ManagerWalker(
                      kit: const Color(0xFF4CAF50),
                      skin: const Color(0xFFE8B48C),
                      hair: const Color(0xFF3A2A1C),
                      look: const {'style': 'flow', 'outfit': 'kit'},
                      ballLayer: ball,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          images.add(await boundary.toImage(pixelRatio: 4));
        });
      }
      await tester.runAsync(() async {
        const pad = 6.0;
        final cw = _w * 4;
        const ch = 300 * 4.0;
        final w = images.length * (cw + pad) + pad;
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, ch + pad * 2), Paint()..color = const Color(0xFF222222));
        for (var i = 0; i < images.length; i++) {
          canvas.drawImage(images[i], Offset(pad + i * (cw + pad), pad), Paint());
        }
        final out = await rec.endRecording().toImage(w.round(), (ch + pad * 2).round());
        final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/park_${light ? 'light' : 'dark'}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
