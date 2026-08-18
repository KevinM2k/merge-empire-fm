/// The layer that makes the engines audible.
///
/// A dozen ported engines announce what they did on the bus — an achievement
/// unlocked, a cup lifted, a season quest finished, a loan expired — and until
/// this existed nothing in the app listened. The engines were all correct and
/// all silent.
///
/// Deliberately NOT a fourth popup shape: a toast interrupts nothing, waits for
/// nothing and is never the thing a player is answering. The three shapes are
/// for things that need a decision.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One line, and how loudly to say it.
typedef Toast = ({String text, bool good});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Turn a bus event into a line, or null to stay quiet.
///
/// Quiet is the default and the important half: `coins:updated` fires on every
/// tick, and a toast for it would bury the ones that matter.
Toast? toastFor(String event, Object? args) {
  final data = _map(args);
  switch (event) {
    case 'achievement:unlocked':
      return (text: t('ach.unlocked'), good: true);

    case 'cup:won':
      final gems = data?['gems'];
      final cup = '${data?['cupName'] ?? ''}';
      if (gems is num && gems > 0) {
        return (
          text: t('toast.cup_gems', {'n': gems.toInt(), 'cup': cup}),
          good: true,
        );
      }
      return (text: cup, good: true);

    case 'quest:completed':
      // Match quests finish constantly; only a SEASON one is worth saying.
      if (data?['scope'] != 'season') return null;
      return (text: t('quests.season_done'), good: true);

    case 'quests:swept':
      final coins = data?['coins'];
      return (
        text: t('quests.swept', {
          'n': data?['count'] ?? 0,
          'coins': formatCoins(coins is num ? coins : 0),
        }),
        good: true,
      );

    case 'loan:expired':
      // Named, because the copy has a {name} and an unfilled placeholder
      // renders as literal "{name}" on screen.
      final card = _map(data?['card']);
      final name = card?['displayName'] ?? card?['customName'];
      if (name is! String || name.isEmpty) return null;
      return (text: t('loan.departed_expired', {'name': name}), good: false);

    default:
      return null;
  }
}

/// Every event the layer listens to.
const List<String> toastEvents = [
  'achievement:unlocked',
  'cup:won',
  'quest:completed',
  'quests:swept',
  'loan:expired',
];

/// `loan:departed` is deliberately absent: its payload is a Dart RECORD rather
/// than a map, so nothing here can read a name out of it, and its copy needs
/// one. It wants a typed handler, not a guess.

class ToastHost extends ConsumerStatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ToastHost> createState() => ToastHostState();
}

class ToastHostState extends ConsumerState<ToastHost> {
  final List<BusHandler> _handlers = [];
  Toast? _current;
  Timer? _clear;

  /// Test seam.
  Toast? get current => _current;

  @override
  void initState() {
    super.initState();
    for (final event in toastEvents) {
      void handler(Object? args) {
        final toast = toastFor(event, args);
        if (toast != null) show(toast);
      }

      on(event, handler);
      _handlers.add(handler);
    }
  }

  void show(Toast toast) {
    if (!mounted) return;
    setState(() => _current = toast);
    _clear?.cancel();
    // Long enough to read, short enough that two in a row both land.
    _clear = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _current = null);
    });
  }

  @override
  void dispose() {
    _clear?.cancel();
    for (var i = 0; i < toastEvents.length; i++) {
      off(toastEvents[i], _handlers[i]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final toast = _current;

    return Stack(
      children: [
        widget.child,
        if (toast != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  key: const ValueKey('toast'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kit.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: toast.good ? kit.accent : Colors.redAccent,
                    ),
                  ),
                  child: Text(
                    toast.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kit.accentBright, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
