/// One turn of the game loop — the pure half of the interval in
/// `../merge-empire-fc/src/main.js`.
///
/// The JS tick interleaves the work with the reasons not to do it, and reads
/// those reasons off the DOM: is a mini-game open, is the match popup up, is
/// Coach Colin already on screen. Those are real gates — a transfer bid landing
/// on top of the match popup is a bug a player sees — but they are questions
/// about the SCREEN, and asking the screen from inside the game loop is what
/// makes the loop untestable.
///
/// So they arrive as [TickGates] instead. What comes back is a [TickReport]: the
/// list of things that happened, for the caller to announce and render. Nothing
/// here emits, and nothing here draws.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/event_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/loan_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// How often the loop runs.
const int tickIntervalMs = Idle.tickMs;

/// A rival bid is rolled at most this often through active play.
const int transferCheckIntervalMs = 60 * 1000;

/// What the screen is doing, which decides what the tick is allowed to start.
///
/// Every one of these is a question about the SCREEN. They are inputs rather
/// than lookups so the loop can be run without one.
typedef TickGates = ({
  /// The match takeover is up. It suppresses the lineup refill after an injury
  /// heals — filling the hole an injury just left would be an auto-substitution
  /// — and any centre-screen card.
  bool matchOpen,

  /// A mini-game is running. A modal over one would never be dismissed.
  bool miniGameOpen,

  /// A transfer sheet is already open.
  bool transferOpen,

  /// Coach Colin is already on screen — a tip, the daily reward, a sponsor
  /// offer. Two of them back to back reads as him popping up twice.
  bool colinOnScreen,
});

const TickGates clearScreen = (
  matchOpen: false,
  miniGameOpen: false,
  transferOpen: false,
  colinOnScreen: false,
);

/// What one tick did.
typedef TickReport = ({
  /// Event windows that opened on this tick. Boot and resume are not enough:
  /// Deadline Day opens at six whether or not the app happens to be
  /// backgrounded, and a session left open since teatime never re-evaluated the
  /// trigger — the strip went blank rather than going live.
  List<String> eventsActivated,

  /// Idle income credited, which is zero far more often than not.
  num coinsEarned,

  /// The pip pool moved.
  bool energyChanged,

  /// Pro-mode fitness recovered. Always zero in Casual, which has no per-player
  /// fitness at all.
  double fitnessRecovered,

  /// At least one injury healed.
  bool injuriesHealed,

  /// Loans the squad could no longer pay for, which have gone home.
  List<({CardInstance card, String name, String? from})> loansRecalled,

  /// A rival's bid, when the roll came up and the screen was clear.
  Map<String, dynamic>? transferOffer,

  /// The save needs writing now rather than on the debounce — an event window
  /// changing or a loan being recalled is not something to lose.
  bool needsImmediateSave,
});

const TickReport _nothingHappened = (
  eventsActivated: <String>[],
  coinsEarned: 0,
  energyChanged: false,
  fitnessRecovered: 0,
  injuriesHealed: false,
  loansRecalled: [],
  transferOffer: null,
  needsImmediateSave: false,
);

/// The game loop, as a value.
///
/// Holds only what has to survive between ticks: when the last one ran, and when
/// a bid was last rolled for.
class GameLoop {
  GameLoop({int? startedAt})
    : _lastTickAt = startedAt ?? now(),
      _lastTransferCheckAt = 0;

  int _lastTickAt;
  int _lastTransferCheckAt;

  /// When the last tick ran. A resume moves this forward without ticking, so
  /// the time spent in the background is not credited twice — the offline
  /// earnings path has already paid for it.
  int get lastTickAt => _lastTickAt;

  /// Skip the elapsed time without doing any work.
  ///
  /// Called when the app comes back: the background time belongs to the offline
  /// calculation, and running it through the loop as well would pay it twice.
  void skipElapsed() => _lastTickAt = now();

  /// Run one tick.
  ///
  /// The instant comes off the shared clock rather than an argument. Half the
  /// work here reads that clock itself — the energy regeneration, the injury
  /// recovery, the event windows — so a caller passing a different one would
  /// have the loop and the engines disagreeing about what time it is.
  ///
  /// [hidden] is the app being in the background. The JS returns early there
  /// rather than burning battery on work the player cannot see, and the pause
  /// handler has already saved.
  TickReport tick(
    Map<String, dynamic> state, {
    TickGates gates = clearScreen,
    bool hidden = false,
  }) {
    final nowMs = now();
    final deltaMs = nowMs - _lastTickAt;
    _lastTickAt = nowMs;
    if (hidden) return _nothingHappened;

    // Open or close any window just crossed. Every tick rather than a coarser
    // cadence: lag here is a visibly blank strip and a countdown stuck on "1
    // minute".
    final activated = activateEligibleEvents(state, nowMs);

    final earned = computeIncomeDelta(state, deltaMs);
    if (earned > 0) {
      final resources = _map(state['resources']);
      if (resources != null) {
        resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + earned;
      }
    }

    final energyBefore = _num(_map(state['energy'])?['current']);
    processEnergyRegen(state);
    final energyChanged =
        _num(_map(state['energy'])?['current']) != energyBefore;

    // Pro mode recovers per-player fitness over real time. A no-op in Casual.
    final fitness = _map(state['settings'])?['hardMode'] == true
        ? processPlayerEnergyRegen(state, nowMs)
        : 0.0;

    // Heal anyone whose recovery has run out, and put the XI back to eleven now
    // they are fit — but not while the match is up.
    final healed = processInjuryRecovery(state, refillLineup: !gates.matchOpen);

    // Loan wages are a continuous drain, so affordability is a continuous
    // question rather than something only a played match asks. A squad that can
    // no longer cover what it borrowed loses the player, and the lender holds it
    // against us.
    final recalled = enforceLoanWages(state);

    // A coarse roll for a rival's bid. It deliberately does NOT stamp the clock
    // when the screen is busy: the roll simply retries next tick, so the bid
    // arrives as soon as the screen is clear rather than waiting out another
    // full minute.
    Map<String, dynamic>? offer;
    final screenClear =
        !gates.miniGameOpen &&
        !gates.matchOpen &&
        !gates.transferOpen &&
        !gates.colinOnScreen;
    if (screenClear &&
        nowMs - _lastTransferCheckAt >= transferCheckIntervalMs) {
      _lastTransferCheckAt = nowMs;
      offer = maybeGenerateIdleOffer(state);
    }

    return (
      eventsActivated: activated,
      coinsEarned: earned > 0 ? earned : 0,
      energyChanged: energyChanged,
      fitnessRecovered: fitness,
      injuriesHealed: healed,
      loansRecalled: recalled,
      transferOffer: offer,
      needsImmediateSave: activated.isNotEmpty || recalled.isNotEmpty,
    );
  }
}
