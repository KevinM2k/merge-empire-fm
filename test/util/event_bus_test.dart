import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

void main() {
  tearDown(resetBus);

  group('on / emit', () {
    test('a registered handler receives the event', () {
      var calls = 0;
      on('coins:updated', (_) => calls++);
      emit('coins:updated');
      expect(calls, 1);
    });

    test('passes the payload through', () {
      Object? seen;
      on('match:complete', (args) => seen = args);
      emit('match:complete', 42);
      expect(seen, 42);
    });

    test('every handler for an event fires', () {
      final fired = <int>[];
      on('merge:happened', (_) => fired.add(1));
      on('merge:happened', (_) => fired.add(2));
      emit('merge:happened');
      expect(fired, [1, 2]);
    });

    test('emitting an event with no listeners is a no-op', () {
      expect(() => emit('nobody:listening'), returnsNormally);
    });

    test('the same handler registered twice only fires once', () {
      var calls = 0;
      void handler(Object? _) => calls++;
      on('kit:changed', handler);
      on('kit:changed', handler);
      emit('kit:changed');
      expect(calls, 1);
    });

    test('handlers are isolated per event', () {
      var a = 0;
      var b = 0;
      on('a', (_) => a++);
      on('b', (_) => b++);
      emit('a');
      expect(a, 1);
      expect(b, 0);
    });
  });

  group('off', () {
    test('removes a handler', () {
      var calls = 0;
      void handler(Object? _) => calls++;
      on('trophies:updated', handler);
      off('trophies:updated', handler);
      emit('trophies:updated');
      expect(calls, 0);
    });

    test('removing an unregistered handler is a no-op', () {
      expect(() => off('never:on', (_) {}), returnsNormally);
    });

    test('removing from an unknown event is a no-op', () {
      expect(() => off('unknown', (_) {}), returnsNormally);
    });
  });

  group('once', () {
    test('fires exactly once', () {
      var calls = 0;
      once('season:ended', (_) => calls++);
      emit('season:ended');
      emit('season:ended');
      emit('season:ended');
      expect(calls, 1);
    });

    test('receives the payload', () {
      Object? seen;
      once('scout:placed', (args) => seen = args);
      emit('scout:placed', 'card');
      expect(seen, 'card');
    });

    test('unregistering mid-emit does not disturb other handlers', () {
      // `once` removes itself from inside emit's own iteration. JS Sets
      // tolerate that; a naive Dart port throws ConcurrentModificationError.
      final fired = <String>[];
      on('nav:settings', (_) => fired.add('before'));
      once('nav:settings', (_) => fired.add('once'));
      on('nav:settings', (_) => fired.add('after'));

      expect(() => emit('nav:settings'), returnsNormally);
      expect(fired, ['before', 'once', 'after']);

      fired.clear();
      emit('nav:settings');
      expect(fired, ['before', 'after']);
    });

    test('can be cancelled before firing', () {
      var calls = 0;
      final cancel = once('never:fires', (_) => calls++);
      cancel();
      emit('never:fires');
      expect(calls, 0);
    });
  });

  group('a throwing handler', () {
    test('does not starve the handlers after it', () {
      // Every cross-cutting signal in the app rides this bus, so one bad
      // listener must not take the rest down with it.
      final fired = <String>[];
      on('boom', (_) => fired.add('first'));
      on('boom', (_) => throw StateError('bad listener'));
      on('boom', (_) => fired.add('third'));

      expect(() => emit('boom'), returnsNormally);
      expect(fired, ['first', 'third']);
    });

    test('is reported through the error hook', () {
      Object? reported;
      String? reportedEvent;
      setBusErrorHandler((event, error, _) {
        reportedEvent = event;
        reported = error;
      });

      on('boom', (_) => throw StateError('bad listener'));
      emit('boom');

      expect(reportedEvent, 'boom');
      expect(reported, isA<StateError>());
    });
  });

  group('handlers added during emit', () {
    test('do not fire for the in-flight event', () {
      final fired = <String>[];
      on('reentrant', (_) {
        fired.add('outer');
        on('reentrant', (_) => fired.add('inner'));
      });

      emit('reentrant');
      expect(fired, ['outer']);

      fired.clear();
      emit('reentrant');
      expect(fired, ['outer', 'inner']);
    });
  });

  group('resetBus', () {
    test('clears every listener', () {
      var calls = 0;
      on('anything', (_) => calls++);
      resetBus();
      emit('anything');
      expect(calls, 0);
    });
  });
}
