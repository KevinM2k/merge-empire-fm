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
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/ui/popups/prestige_card.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One line, and how loudly to say it.
typedef Toast = ({String text, bool good, bool gem});

/// The ordinary line: a sentence, and whether it is good news.
Toast _say(String text, {bool good = false}) =>
    (text: text, good: good, gem: false);

/// **A gem line, and it is deliberately not an ordinary one.** Gems are the
/// premium currency — bought with real money or earned from a faucet that
/// mostly never re-arms — and every one of the four that hand them out did so
/// in silence. Whatever the occasion, arriving gems are worth more than a grey
/// line: this one is GOLD, wears the currency's own glyph, and is held longer
/// than a passing notice.
Toast _gems(String text) => (text: text, good: true, gem: true);

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Turn a bus event into a line, or null to stay quiet.
///
/// Quiet is the default and the important half: `coins:updated` fires on every
/// tick, and a toast for it would bury the ones that matter.
Toast? toastFor(String event, Object? args) {
  final data = _map(args);
  switch (event) {
    // A line the UI raised itself, already localised. The engines all name their
    // own event; this is for the handful of refusals that live in a widget and
    // have nowhere else to say so — a locked kit swatch, for one.
    case 'toast:info':
      final text = args is String ? args : '${data?['text'] ?? ''}';
      return text.isEmpty ? null : _say(text, good: false);

    // **Gems arrive from four faucets and not one of them said so.**
    // `gems:updated` carries a balance and nothing else, so no listener could
    // tell a welcome gift from a purchase, and all three `gems.toast.*`
    // strings sat translated in ten languages with nothing able to reach one.
    //
    // **EVERY grant speaks, and that is a stated exception to this file's
    // quiet-by-default rule.** The rule exists because `coins:updated` fires on
    // every tick and a line for it would bury the ones that matter; gems are
    // the opposite case. They are the premium currency, they arrive a handful
    // of times in a whole run, and a player who is handed some and not told has
    // been given nothing they know about. Occasion decides the WORDS, never
    // whether there are any.
    //
    // Three occasions have copy written for them. The rest get the currency's
    // own glyph and the number, which is what `toast.cup_gems` already does and
    // needs no key that does not exist — a new one is blocked on the spec repo.
    case 'gems:granted':
      final amount = data?['amount'];
      if (amount is! num || amount < 1) return null;
      final n = amount.toInt();
      return _gems(switch ('${data?['reason']}') {
        'tutorial' => t('gems.toast.tutorial', {'n': n}),
        'chl_title' => t('gems.toast.season', {'n': n}),
        final r when r.startsWith('division_first:') => t('gems.toast.season', {
          'n': n,
        }),
        'prestige' || 'first_prestige' => t('gems.toast.prestige', {'n': n}),
        _ => '+$n 💎',
      });

    case 'cup:won':
      final gems = data?['gems'];
      final cup = '${data?['cupName'] ?? ''}';
      if (gems is num && gems > 0) {
        return _say(t('toast.cup_gems', {'n': gems.toInt(), 'cup': cup}), good: true);
      }
      return _say(cup, good: true);

    // **A new adventure announces itself.** `performPrestige` empties the grid,
    // the club and the division and hands back a coin balance scaled by the new
    // multiplier — from the outside that is indistinguishable from something
    // having gone wrong, and the one sentence saying otherwise
    // (`prestige.season_begin_toast`) was translated ten times over with
    // nothing able to reach it. Good news, so it is the green toast.
    case 'prestige:complete':
      final mult = data?['multiplier'];
      if (mult is! num) return null;
      return _say(t('prestige.season_begin_toast', {
          'season': (data?['season'] as num?)?.toInt() ?? 1,
          'mult': formatPrestigeMultiplier(mult.toDouble()),
        }), good: true);

    // A rename says so, both ways round. It is the only confirmation there is:
    // the card closes on success, and the name it changed is behind it.
    case 'player:renamed':
      final name = '${data?['name'] ?? ''}';
      if (name.isEmpty) return null;
      return _say(data?['reset'] == true
            ? t('rename.toast_reset', {'name': name})
            : t('rename.toast_done', {'name': name}),
        good: data?['reset'] != true,
      );

    case 'quest:completed':
      // Match quests finish constantly; only a SEASON one is worth saying.
      if (data?['scope'] != 'season') return null;
      return _say(t('quests.season_done'), good: true);

    case 'quests:swept':
      final coins = data?['coins'];
      return _say(
        t('quests.swept', {
          'n': data?['count'] ?? 0,
          'coins': formatCoins(coins is num ? coins : 0),
        }),
        good: true,
      );

    case 'scout:short':
      // Fell short of the batch that was asked for. Said rather than swallowed:
      // four cards were tapped for and fewer arrived, and the player is watching
      // the reveal that is about to show them.
      return _say(t('grid.scouted_partial', {
          'got': data?['got'] ?? 0,
          'want': data?['want'] ?? 0,
        }), good: false);

    case 'scout:auto_sold':
      final coins = data?['coins'];
      return _say(t('grid.auto_sold', {
          'sold': data?['sold'] ?? 0,
          'coins': formatCoins(coins is num ? coins : 0),
        }), good: true);

    case 'merge:refused':
      // The pair was fine and the DIVISION said no: the player is being told to
      // keep climbing, not that they did something wrong.
      if (data?['reason'] == 'division_locked') {
        return _say(t('grid.tier_unlock_higher', {'tier': data?['tier'] ?? 0}), good: false);
      }
      if (data?['reason'] == 'insufficient_coins') {
        final coins = data?['coins'];
        return _say(t('merge.need_coins', {
            'coins': formatCoins(coins is num ? coins : 0),
          }), good: false);
      }
      return null;

    case 'cup:sponsor-signed':
      final player = data?['player'];
      final sponsor = data?['sponsor'];
      if (player is! String || sponsor is! String) return null;
      return _say(t('cup.win_reward.signed_toast', {
          'player': player,
          'sponsor': sponsor,
        }), good: true);

    case 'transfer:grudge':
      // A bid died with the card it was for. Pooled copy, so the club's reaction
      // is not the same sentence every time.
      final team = data?['team'];
      if (team is! String || team.isEmpty) return null;
      return _say(tPool('transfer.declined_grudge', {'team': team}), good: false);

    case 'loan:expired':
      // Named, because the copy has a {name} and an unfilled placeholder
      // renders as literal "{name}" on screen.
      final card = _map(data?['card']);
      final name = card?['displayName'] ?? card?['customName'];
      if (name is! String || name.isEmpty) return null;
      return _say(t('loan.departed_expired', {'name': name}));

    default:
      return null;
  }
}

/// Every event the layer listens to.
const List<String> toastEvents = [
  'toast:info',
  'player:renamed',
  'cup:won',
  'quest:completed',
  'quests:swept',
  'scout:short',
  'scout:auto_sold',
  'merge:refused',
  'cup:sponsor-signed',
  'transfer:grudge',
  'loan:expired',
  'prestige:complete',
  'gems:granted',
];

/// `loan:departed` is deliberately absent: its payload is a Dart RECORD rather
/// than a map, so nothing here can read a name out of it, and its copy needs
/// one. It wants a typed handler, not a guess.
///
/// `achievement:unlocked` USED to be here, saying "Achievement Unlocked!" and
/// nothing else — no name, no art, no coins, at the bottom of the screen in the
/// same slot as a refused merge. It has its own banner now
/// (`achievement_unlock.dart`): a reward that arrives where errors arrive is not
/// a reward.

/// How long a line is held. A gem payout gets longer: it happens a handful of
/// times in a whole run, and the ordinary 2.6s is sized for lines that repeat.
const Duration _hold = Duration(milliseconds: 2600);
const Duration _gemHold = Duration(milliseconds: 3600);

/// The currency's own colour, the achievement banner's gold. Not the kit's
/// accent — see the border below.
const Color _gemGold = Color(0xFFFFD700);

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
    // **And it is AUDIBLE.** A premium currency arriving is the one thing this
    // layer prints that a player should not be able to miss by looking away,
    // and the cue is the one already reserved for finding something rather than
    // for taking a coin — `coin` is the sound of every idle tick's income.
    if (toast.gem) playSoundFrom(ref, 'newDiscovery');
    setState(() => _current = toast);
    _clear?.cancel();
    // Long enough to read, short enough that two in a row both land — and
    // longer for gems, which turn up a handful of times in a whole run.
    _clear = Timer(toast.gem ? _gemHold : _hold, () {
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
                    // **Gold, literally, and not the club's accent.** The same
                    // argument the achievement banner makes: this is a
                    // celebration rather than a notice, and a green-kitted club
                    // would otherwise make a gem payout look like every other
                    // line the layer prints.
                    border: Border.all(
                      color: toast.gem
                          ? _gemGold
                          : toast.good
                          ? kit.accent
                          : Colors.redAccent,
                      width: toast.gem ? 1.5 : 1,
                    ),
                    boxShadow: toast.gem
                        ? [
                            BoxShadow(
                              color: _gemGold.withValues(alpha: 0.28),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    toast.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: toast.gem ? _gemGold : kit.accentBright,
                      fontSize: toast.gem ? 15 : 13,
                      fontWeight: toast.gem
                          ? FontWeight.w800
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
