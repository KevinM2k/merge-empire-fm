import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/sound_cues.dart';
import 'package:merge_empire_fc/services/sound_service.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// A service that records rather than synthesises.
class _Spy implements SoundService {
  final played = <String>[];

  @override
  Future<void> play(String cue, {bool overlap = false}) async {
    played.add(cue);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _Spy spy;
  late void Function() teardown;

  setUp(() {
    spy = _Spy();
    teardown = wireSoundCues(spy);
  });
  tearDown(() => teardown());

  /// Past the arbiter's window, so whatever it decided has been played.
  Future<void> settle(WidgetTester? _) =>
      Future<void>.delayed(const Duration(milliseconds: 140));

  group('ONE SOUND PER THING THAT HAPPENED', () {
    test('a merge that discovers a card plays the discovery, not both', () async {
      emit('merge:complete', {
        'newDef': {'tier': 2},
      });
      emit('playerindex:discovered', {'definitionId': 'x'});
      await settle(null);
      expect(spy.played, ['newDiscovery']);
    });

    test('and a merge that discovers nothing plays the merge', () async {
      emit('merge:complete', {
        'newDef': {'tier': 2},
      });
      await settle(null);
      expect(spy.played, ['merge']);
    });

    test('four signings are one sound', () async {
      for (var i = 0; i < 4; i++) {
        emit('card:placed', {'index': i});
      }
      await settle(null);
      expect(spy.played, ['scout']);
    });

    test('and four signings with one new player are the discovery', () async {
      for (var i = 0; i < 4; i++) {
        emit('card:placed', {'index': i});
      }
      emit('playerindex:discovered', {'definitionId': 'x'});
      await settle(null);
      expect(spy.played, ['newDiscovery']);
    });

    test('an epic merge still gets its own fanfare', () async {
      emit('merge:complete', {
        'newDef': {'tier': epicMergeTier},
      });
      await settle(null);
      expect(spy.played, ['epicMerge']);
    });

    test('two merges far enough apart are two sounds', () async {
      emit('merge:complete', {
        'newDef': {'tier': 2},
      });
      await settle(null);
      emit('merge:complete', {
        'newDef': {'tier': 2},
      });
      await settle(null);
      expect(spy.played, ['merge', 'merge']);
    });

    test('and everything else is untouched by the arbiter', () async {
      emit('player:sold', null);
      emit('quest:completed', null);
      expect(spy.played, ['sell', 'challenge']);
    });
  });
}
