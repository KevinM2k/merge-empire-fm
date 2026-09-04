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
///
/// **It is a band across the middle of the screen, and it strikes in from the
/// left.** It used to be a rounded card 96pt off the bottom with a margin
/// either side, appearing and disappearing outright — small, in the corner
/// nobody watches, and with no motion to catch the eye on the way. Reported
/// from the couch: the line kept being missed.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/sound_providers.dart';
import 'package:merge_empire_fc/ui/popups/prestige_card.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show readableInk, semanticPlate;
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
    // own event; these are for the things that live in a widget and have
    // nowhere else to say so — a locked kit swatch, a purchase going through,
    // a wallet that is short.
    //
    // **TWO OF THE THREE WERE SHOUTING INTO NOTHING.** `toast:success` and
    // `toast:error` are emitted from thirteen places across the shop, the
    // squad, the customiser, the energy sheet and the sign-in flow, and neither
    // appeared in this switch or in [toastEvents] — so a completed purchase, a
    // refused one, an energy refill, a healed player and both sign-in outcomes
    // all said nothing whatsoever. Exactly the fault in this file's own header,
    // one layer up: the callers were right and there was no listener.
    //
    // `info` and `error` render alike — the tone is the palette's "something
    // is wrong" either way, because an info line here is a refusal too. They
    // stay separate events because the CALLERS mean different things by them.
    case 'toast:info':
    case 'toast:error':
      final text = args is String ? args : '${data?['text'] ?? ''}';
      return text.isEmpty ? null : _say(text, good: false);

    case 'toast:success':
      final text = args is String ? args : '${data?['text'] ?? ''}';
      return text.isEmpty ? null : _say(text, good: true);

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

    // **A LOCKED CONTROL THAT IS TAPPED HAS TO ANSWER.** The Pro segment is
    // dead until the first prestige and the row's own note says why — but a
    // note under a control is small print, and a player who has just pressed
    // the thing and had nothing happen is not reading small print. Reported as
    // there being no information about why Pro is locked.
    //
    // **The CONDITION leads it now.** This used to be `prestige.body_pro_hint`
    // alone, which describes Pro and never says how it opens — see
    // [proLockedAnswer]. Condition first, then what it buys, which is the order
    // the question was asked in.
    case 'prestige:locked':
      // The condition, then what Pro IS. `prestige.body_pro_hint` used to be the
      // second half and its "Or prestige into Pro Mode" describes a route that
      // is no longer the gate; `settings.difficulty.hint` is the same
      // description with none of the meta-loop in it, and it is what the row
      // itself prints once the lock is off.
      return _say(
        '${proLockedAnswer()} ${t('settings.difficulty.hint')}',
        good: false,
      );

    // **CONSENT IS NOT REQUIRED WHERE YOU ARE, which is not the same as
    // "coming soon".** The privacy row is always live — the JS shows it
    // unconditionally — and outside the EEA there is simply nothing to consent
    // to. `settings.consent_not_required` is that sentence and shipped in ten
    // languages with no caller. Not good news and not bad: an answer.
    case 'consent:unavailable':
      return _say(t('settings.consent_not_required'), good: false);

    // **THE CAPSTONE GEM ANNOUNCES ITSELF.** `quest:capstone` has been emitted
    // by `awardDivisionCapstone` since the quest engine was ported and nothing
    // listened, so clearing a division's whole season track paid a gem in
    // silence — the one lifetime-capped reward in the game, landing with no
    // more ceremony than a coin. `quests.capstone_toast` is its sentence and
    // shipped in ten languages with no caller.
    case 'quest:capstone':
      final gems = data?['gems'];
      if (gems is! num) return null;
      return _say(
        t('quests.capstone_toast', {
          'division': tName('division', data?['divisionId']),
          'n': gems.toInt(),
        }),
        good: true,
      );

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
  // See the note on the case: these two were emitted and never subscribed.
  'toast:success',
  'toast:error',
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
  'quest:capstone',
  'consent:unavailable',
  'prestige:locked',
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

/// How long a line is held, once it has finished arriving. A gem payout gets
/// longer: it happens a handful of times in a whole run, and the ordinary hold
/// is sized for lines that repeat.
///
/// **SHORTER THAN IT WAS, because the player can now end it.** 2.6s and 3.6s
/// were the times of a band that had to outlast being ignored — it took no
/// taps and no route cared about it, so the timer was the only way it ever
/// left. It goes on the first pointer down and on a change of tab now (see
/// [ToastHostState._dismiss]), which means the hold only has to cover a line
/// nobody reacts to at all. Reported from the couch as sticking around too
/// long.
const Duration _hold = Duration(milliseconds: 1800);
const Duration _gemHold = Duration(milliseconds: 2600);

/// **A TOAST MOVES.** It used to be there and then not be there, which is the
/// one thing a notification cannot do: a banner that simply appears in the
/// middle of the screen reads as a rendering fault, and one that vanishes takes
/// the sentence with it before the eye has found it.
///
/// It strikes in from the LEFT and closes back the same way — see the wipe in
/// `_toastFace`. Out is a little slower than in, because a bolt arrives faster
/// than it fades.
const Duration _slideIn = Duration(milliseconds: 300);
const Duration _slideOut = Duration(milliseconds: 260);

/// **The strike, and it is fast.** Lightning that takes half a second is a
/// curtain; the band has to be open before the eye has finished moving to it.
/// Eased out, so the front of the bolt is quickest at the start.
final Curve _sweepCurve = Curves.easeOutQuart;

/// The currency's own colour, the achievement banner's gold. Not the kit's
/// accent — see the border below.
const Color _gemGold = Color(0xFFFFD700);


class ToastHost extends ConsumerStatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ToastHost> createState() => ToastHostState();
}

class ToastHostState extends ConsumerState<ToastHost>
    implements TickerProvider {
  /// An UNMUTED ticker, for the same reason `CoinFlight` provides its own.
  ///
  /// **THE BAND GOES UP IN THE ROOT OVERLAY and the HOST is under every route
  /// in the game**, so a Navigator mutes its `TickerMode` and a toast fired
  /// from inside a mini-game, a shop sheet or the settings screen never slid
  /// in — it sat off-screen at the start of its own animation until the route
  /// was popped, and then arrived, about something the player had finished
  /// doing. Same fault as the frozen coin, found looking for it.
  ///
  /// `TickerMode(enabled: true)` is not the fix: it composes with its
  /// ancestors, so nesting an enabled one inside a muted one leaves it muted —
  /// and a `TickerMode` over the whole shell would un-mute every route in the
  /// app. One controller, 200ms either way.
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  final List<BusHandler> _handlers = [];
  Toast? _current;
  Timer? _clear;

  /// The line's own overlay entry, or null when nothing is being said.
  OverlayEntry? _entry;

  /// In, held, out. Driven forward when a line arrives and reversed when its
  /// time is up; the face reads [AnimationController.status] to know which way
  /// it is going, because the band leaves in the direction it came from rather
  /// than dropping back.
  /// **Built in `initState`, not lazily.** A `late final` initialiser used to
  /// reach for `TickerMode` — and on a host that never said anything, `dispose`
  /// is the first thing to touch the field, which looks up an ancestor of a
  /// widget that is already being torn down. The ticker is this host's own now
  /// (see [createTicker]) so the lookup has gone, but eager is still right:
  /// nothing should depend on when the field is first read.
  late final AnimationController _move;

  /// Test seam.
  Toast? get current => _current;

  @override
  void initState() {
    super.initState();
    _move = AnimationController(
      vsync: this,
      duration: _slideIn,
      reverseDuration: _slideOut,
    )..addStatusListener((status) {
      // Dismissed is the END of the line, not a frame of it: the entry comes
      // down only once nothing of the banner is left on screen.
      if (status == AnimationStatus.dismissed && _current == null) _drop();
    });
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
    _current = toast;
    _raise();
    // A second line replaces the first WITHOUT restarting the arrival: the band
    // is already in place, so re-running the slide would look like the screen
    // stuttering rather than like the words changing.
    //
    // Reduced motion still gets the line — it is the words that matter, and a
    // player who has asked for no animation has not asked for no news.
    if (_reducedMotion) {
      _move.value = 1;
    } else {
      _move.forward();
    }
    _clear?.cancel();
    // Long enough to read, short enough that two in a row both land — and
    // longer for gems, which turn up a handful of times in a whole run.
    _clear = Timer(toast.gem ? _gemHold : _hold, _dismiss);
  }

  /// Close the band, whatever ended it — its own timer, a tap, a change of tab.
  ///
  /// **A TOAST THE PLAYER HAS MOVED PAST IS LITTER.** It waits for nothing and
  /// answers nothing, so a band still lying across the middle of a screen the
  /// player has already left is furniture in front of the thing they went there
  /// to do. Asked for in one sentence: tap anything, or change tab, and it
  /// should be gone.
  ///
  /// Idempotent — a tap during the slide out, or a second one, finds `_current`
  /// already null and leaves the animation to finish.
  void _dismiss() {
    if (!mounted || _current == null) return;
    _clear?.cancel();
    _clear = null;
    _current = null;
    if (_reducedMotion) {
      _move.value = 0;
      _drop();
    } else {
      _move.reverse();
    }
  }

  bool get _reducedMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// **THE TOAST GOES IN THE OVERLAY, over whatever is on screen.**
  ///
  /// It used to be a `Stack` around this host's child, and this host lives
  /// inside `MaterialApp.home` — so every modal route in the game drew on top
  /// of it. A bottom sheet, a coach card, a dialog: all of them are Navigator
  /// routes, all of them are above `home`, and a line raised while one was open
  /// was painted underneath the thing the player was looking at.
  ///
  /// That is not a theoretical hole. The customiser's locked chips were fixed
  /// once already by routing their refusal through this bus instead of a
  /// `SnackBar`, and the very next playtest reported the same thing again:
  /// tapping a locked item does nothing. It was saying so the whole time,
  /// behind the sheet.
  ///
  /// Inserted fresh on each line rather than kept in place, because `insert`
  /// appends: a new entry goes above whatever routes are open NOW.
  void _raise() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // No Navigator above us — a widget test pumping this host bare. Fall
      // back to drawing in place so it is still findable.
      setState(() {});
      return;
    }
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    _entry = OverlayEntry(builder: (context) => _toastFace(context));
    overlay.insert(_entry!);
  }

  void _drop() {
    if (_entry == null) {
      if (mounted) setState(() {});
      return;
    }
    _entry!.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _clear?.cancel();
    _move.dispose();
    _entry?.remove();
    _entry = null;
    for (var i = 0; i < toastEvents.length; i++) {
      off(toastEvents[i], _handlers[i]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **A CHANGE OF TAB ENDS THE LINE.** Unconditionally, above the early
    // return: a listener registered only on the frames the band happens to be
    // up is a listener that is not there when it is needed.
    ref.listen(shellControllerProvider.select((ShellState s) => s.tab), (_, _) {
      _dismiss();
    });
    // The line itself lives in the overlay — see [_raise]. The in-place Stack
    // is only ever used by a test pumping this host with no Navigator above it.
    if (_entry != null || _current == null) return widget.child;
    return Stack(children: [widget.child, _toastFace(context)]);
  }
  /// **A LINE THAT IS ON TOP OF THE SCREEN, not printed on it.**
  ///
  /// It was a flat `kit.surface` fill with a one-pixel border and no shadow at
  /// all unless it carried gems — and a flat surface fill is exactly the thing
  /// that reads as page, which is the fourth time that has been reported in
  /// this app. It is worse here than anywhere: a toast is raised OVER a sheet,
  /// and a sheet's own panel is `kit.surface` too, so the box and the thing
  /// behind it were the same colour and all that was left of the toast was its
  /// red outline. Reported exactly as a clear box with a red border.
  ///
  /// So it takes the vocabulary the club's asset cards and the shop's look
  /// tiles already settled on: the tone's own colour washed into the lit
  /// corner over a raked `surface2 → surface`, and BOTH shadows — a soft cast
  /// for how far off the page it is, a tight contact one for the weight. One
  /// blurred shadow reads as a glow, which is what the gem line had.
  ///
  /// **And the ink follows the tone.** Every line printed `kit.accentBright`
  /// whatever it said, so a refusal was green type inside a red box: the two
  /// halves of the same toast disagreeing about whether it was bad news.
  /// `readableInk` is what keeps a red legible on a daylit surface.
  ///
  /// **AND IT IS A BAND ACROSS THE MIDDLE, not a card near the foot.** It sat
  /// 96pt off the bottom with a 16pt margin either side — the corner of the
  /// screen nobody is looking at, under the tab bar's own furniture, at a size
  /// that made it one more small thing among small things. Reported from the
  /// couch: the line kept being missed. Full bleed and dead centre is the one
  /// place on a phone that cannot be missed, and it costs nothing, because a
  /// toast is never the thing being answered — it does not take the tap it is
  /// sitting on.
  Widget _toastFace(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final toast = _current;
    if (toast == null) return const SizedBox.shrink();
    // **ONE tone decides the whole line**, and it used to decide only the
    // border: the ink was `accentBright` whatever had happened, so a refusal
    // was a green sentence inside a red outline.
    //
    // **Gold, literally, and not the club's accent.** The same argument the
    // achievement banner makes: this is a celebration rather than a notice, and
    // a green-kitted club would otherwise make a gem payout look like every
    // other line the layer prints.
    final tone = toast.gem
        ? _gemGold
        : toast.good
        ? kit.accentBright
        : dangerInk;
    return Positioned.fill(
      // **THE FIRST POINTER DOWN ANYWHERE ENDS IT, and it still takes no
      // taps.** A `Listener` is raw pointer events rather than a gesture, so it
      // never enters the arena and cannot win a tap off the button underneath;
      // `translucent` puts it in the hit-test result without claiming the hit,
      // so the overlay entries below — the whole app — are tested as though it
      // were not there. The band itself stays inside its [IgnorePointer]: the
      // rule that a toast is never the thing being answered is unchanged, and
      // this is deliberately not a tap TARGET.
      //
      // Down rather than up, because the tap that CAUSED the line is usually
      // still held: its own release would close the band before it had finished
      // arriving.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _dismiss(),
        child: IgnorePointer(
          // **THE MIDDLE OF WHAT IS LEFT, not the middle of the screen.**
          //
          // It was a bare `Alignment.center`, so with a keyboard up the band
          // landed across the bottom half of the visible strip — reported from
          // the couch after prestige, where the gem line opened directly over
          // the box the new club's name was about to be typed into. The middle
          // is where it belongs and is where it stays; it just no longer counts
          // the keyboard as screen it may use. With nothing up, `viewInsets` is
          // zero and this is exactly the centre it always was.
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Align(
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _move,
                builder: (context, child) {
                  // **IT STRIKES IN FROM THE LEFT AND CLOSES BACK THE SAME WAY.**
                  // A full-bleed band has one axis worth animating along: it
                  // already spans the screen, so sliding it up or fading it in is
                  // motion applied to the wrong dimension. Wiping it open left to
                  // right is the shape of the thing itself — and the sentence
                  // arrives with the wipe rather than under it, which is what makes
                  // it read as a strike rather than as a box growing.
                  //
                  // The clip is what moves; the band is laid out full width
                  // underneath at every frame, so nothing reflows and the text
                  // never re-wraps mid-animation.
                  final t = _sweepCurve.transform(_move.value);
                  return Stack(
                    children: [
                      ClipRect(clipper: _Wipe(t), child: child),
                      // The bolt's own leading edge, and only while it is travelling
                      // — parked at either end it would just be a stripe.
                      if (t > 0.02 && t < 0.995)
                        Positioned.fill(
                          child: CustomPaint(painter: _Strike(t: t, tone: tone)),
                        ),
                    ],
                  );
                },
                child: _band(context, toast, tone, kit),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Test seam: how far open the wipe is, 0 to 1.
  double get sweep => _move.value;

  /// The band itself: edge to edge, so there is no margin for the page to show
  /// through at the sides and nothing to read as a floating card.
  Widget _band(BuildContext context, Toast toast, Color tone, KitTheme kit) =>
      Material(
        color: Colors.transparent,
        child: Container(
          key: const ValueKey('toast'),
          width: double.infinity,
          // A little air above and below the sentence and no more: the band is
          // wide enough already, and a tall one starts to read as a screen of
          // its own rather than as something passing through. **Sixteen was
          // still too much** — reported from the couch alongside the placement
          // — and at [minFontSize] the line no longer needs air scaled to an
          // 18pt sentence.
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            // **IT WAS A HAIRLINE ROUND NOTHING.** `kit.surface` is the dark
            // theme's 12%-lightness ground — the same value the page behind
            // it is built from — so the box had no edge of its own and what
            // was on screen was a red outline floating over the scene.
            // Reported as "just a clear box with a red border".
            //
            // The chips' own plate instead, tinted by the tone: near-black in
            // the dark, a wash of the tone's hue in daylight, composited onto
            // the surface so it is opaque either way and the pitch cannot
            // come through it.
            color: Color.alphaBlend(semanticPlate(context, tone), kit.surface),
            // **NO CORNERS AND NO SIDES.** A full-bleed band is defined by the
            // two edges it does have; rounding a box that runs off both sides
            // of the screen just leaves four nicks in the middle of nothing.
            border: Border(
              top: BorderSide(color: tone, width: 1.5),
              bottom: BorderSide(color: tone, width: 1.5),
            ),
            boxShadow: [
              // What actually lifts it off the page. The gem line keeps its
              // glow on top of it.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
              ),
              if (toast.gem)
                BoxShadow(
                  color: _gemGold.withValues(alpha: 0.28),
                  blurRadius: 16,
                ),
            ],
          ),
          child: Text(
            toast.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              // Taken down to read on the light plate; the dark one keeps the
              // colour it was chosen at.
              color: readableInk(context, tone),
              // **THE APP'S FLOOR, and it used to be 18 and 20.** The
              // argument for big was that a full-bleed band makes a small
              // sentence read as a caption for something that is not there —
              // and a sentence big enough to answer that is a sentence big
              // enough to be in the way, which is what it turned out to be.
              // Asked for from the couch: the minimum size. The weight still
              // separates a gem payout from a plain notice, and the tone still
              // separates good news from a refusal.
              fontSize: minFontSize,
              height: 1.25,
              fontWeight: toast.gem ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      );
}

/// The wipe: the band, laid out full width, revealed only as far as the strike
/// has got. A clipper rather than a width, so nothing reflows and the sentence
/// never re-wraps mid-animation.
class _Wipe extends CustomClipper<Rect> {
  const _Wipe(this.t);

  final double t;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * t, size.height);

  @override
  bool shouldReclip(_Wipe old) => old.t != t;
}

/// The bolt's leading edge.
///
/// **A wipe on its own reads as a curtain, not as a strike.** What separates
/// them is the front: a hot vertical edge at the point the reveal has reached,
/// with a short tail smeared back along the way it came. Both are drawn in the
/// line's own tone — the same one that decides the ink and the band's two
/// edges — so a refusal strikes red and a gem payout strikes gold.
class _Strike extends CustomPainter {
  const _Strike({required this.t, required this.tone});

  final double t;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * t;
    // The tail, smeared back behind the front and no longer than a fifth of the
    // screen — a longer one stops being a bolt and becomes a gradient.
    final tail = math.min(size.width * 0.2, 96.0);
    canvas.drawRect(
      Rect.fromLTRB(x - tail, 0, x, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [tone.withValues(alpha: 0), tone.withValues(alpha: 0.55)],
        ).createShader(Rect.fromLTRB(x - tail, 0, x, size.height)),
    );
    // And the front itself: white-hot rather than the tone, because the thing
    // that reads as lightning is the blow-out at the tip.
    canvas.drawRect(
      Rect.fromLTRB(x - 2.5, 0, x + 1.5, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_Strike old) => old.t != t || old.tone != tone;
}
