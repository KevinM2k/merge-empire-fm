/// The Play Games app id has three copies that must agree: the Dart pin, the
/// Android resource the manifest points at, and the number every Console
/// achievement id carries inside it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/pgs_achievements.dart';
import 'package:merge_empire_fc/data/pgs_app_id.dart';

/// A `CgkI…` id is a protobuf: field 1 is a message whose first field is the
/// game's numeric id as a varint.
int gameIdIn(String achievementId) {
  final bytes = base64.decode(base64.normalize(achievementId));
  expect(bytes[0], 0x0a);
  expect(bytes[2], 0x08);
  var i = 3;
  var value = 0;
  var shift = 0;
  while (true) {
    final b = bytes[i++];
    value |= (b & 0x7f) << shift;
    shift += 7;
    if (b & 0x80 == 0) return value;
  }
}

void main() {
  test('the manifest carries the pinned id', () {
    final strings = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    expect(strings, contains('name="game_services_project_id"'));
    expect(strings, contains('>$pgsAppIdAndroid<'));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('com.google.android.gms.games.APP_ID'));
    expect(manifest, contains('@string/game_services_project_id'));
  });

  test('every mapped achievement belongs to that game', () {
    final mapped = pgsAchievementIds.values.whereType<String>().toList();
    expect(mapped, isNotEmpty);
    for (final id in mapped) {
      expect('${gameIdIn(id)}', pgsAppIdAndroid, reason: id);
    }
  });
}
