/// The event bus, republished into Riverpod.
///
/// The bus stays where it is — pure Dart, no Flutter — because engines emit on
/// it and engines may not import Flutter. What this adds is the other end: a
/// widget subscribes to a provider and lets Riverpod own the teardown, instead
/// of every `State` remembering its own `off()` in `dispose`.
///
/// Names are the same strings the engines emit. Grep the engines before
/// inventing one.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// Every emission of [event], as a stream.
///
/// Use it with `ref.listen` for the things that happen once — a toast, a sound,
/// a takeover screen. For anything that is really a value on the save, watch the
/// derived provider in `game_providers.dart` instead: those survive a rebuild,
/// and a stream a widget subscribed to late has already missed its event.
final busEventProvider = StreamProvider.family<Object?, String>((ref, event) {
  final controller = StreamController<Object?>.broadcast();
  void handler(Object? args) => controller.add(args);
  on(event, handler);
  ref.onDispose(() {
    off(event, handler);
    controller.close();
  });
  return controller.stream;
});
