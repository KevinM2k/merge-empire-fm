/// The thing that actually runs the game: the save, the loop, the listeners and
/// the timer that drives them. Ported from the boot and tick wiring in
/// `../merge-empire-fc/src/main.js`.
///
/// The JS keeps all of this in module scope and reaches for the DOM whenever it
/// needs to know what the screen is doing. Here the screen answers a question
/// instead — [gates] is a callback the UI layer supplies — so the whole loop can
/// be started, ticked and stopped in a test with no widget binding anywhere.
///
/// What it does NOT do is draw, announce a toast, or play a sound. It emits on
/// the bus and the layer with a screen listens.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:async';

import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/quest_engine.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_tick.dart';
import 'package:merge_empire_fc/state/game_wiring.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';
import 'package:merge_empire_fc/util/club_name.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Emitted at most this often while idle income is trickling.
///
/// The rate labels have to stay live without a bus event on every frame, so a
/// sub-coin delta waits and a whole coin does not.
const int coinEmitIntervalMs = 500;

class GameRunner {
  GameRunner({
    required this.game,
    TickGates Function()? gates,
    bool Function()? hidden,
  }) : _gates = gates ?? (() => clearScreen),
       _hidden = hidden ?? (() => false),
       wiring = GameWiring(game);

  final GameState game;
  final GameWiring wiring;
  final TickGates Function() _gates;
  final bool Function() _hidden;

  GameLoop? _loop;
  Timer? _timer;
  int _lastCoinEmitAt = 0;

  bool get running => _timer != null;

  /// Load the save, register the listeners, and run the sweeps that a boot owes
  /// the player before the first frame.
  /// What the player is owed for the time the app was away, measured at the
  /// instant the save was read and held until something shows it.
  ///
  /// **IT HAS TO BE MEASURED HERE.** `processOfflineEarnings` works off
  /// `lastSeen`, and `lastSeen` is stamped by every `saveNow` — including the
  /// age-signal sweep this boot fires and forgets, and the two-second save
  /// debounce. Computed later, in the popup host's first post-frame callback,
  /// it was racing all of them and usually losing: a save seeded an hour in the
  /// past came back through a real boot with `lastSeen` moved forward
  /// 3,600,859ms and a window of ONE MILLISECOND. The card still opened, paid
  /// a couple of coins, and told the player they had been away "0s".
  OfflineEarnings? pendingOffline;

  Map<String, dynamic> boot() {
    final state = game.load();
    // Before the sweeps below, every one of which can stamp `lastSeen`.
    pendingOffline = processOfflineEarnings(state);
    // Before the sweeps below, every one of which can stamp `lastSeen`.

    _loop ??= GameLoop(startedAt: now());
    wiring.attach();
    // Anything unlocked by an older build gets its achievement row and its
    // badge now, rather than on the next thing that happens to fire a sweep.
    wiring.bootSweep();
    // **The welcome gift, which nothing has ever paid.** `grantTutorialGems` is
    // the onboarding faucet and its own doc says why it is load-bearing rather
    // than generous: cups are the only other route to gems and they do not
    // start until the third division, so without it a new player meets the gem
    // shop with an empty wallet and no idea what the currency is for. Its only
    // caller in the JS is the scripted tutorial, which is the one part of that
    // game the port does not have — `settleTutorial` is where the port already
    // admits it — so every save this port has ever written started with
    // nothing.
    //
    // **HERE rather than in `load`, and the parity harness is why.** The first
    // attempt put it beside `settleTutorial`, and
    // `game_state_test`'s reset fixtures failed: they load a save, reset it and
    // compare the result to the JS's, field for field, so a grant on that path
    // is the port inventing gems the JS never gave. Boot is a sweep the port
    // owes the player before the first frame, which is what this is, and it is
    // not a path the harness compares.
    //
    // The grant flags itself in the gem ledger, and the ledger survives both
    // resets, so it pays once per player rather than once per boot.
    game.onFreshState = prepareSave;
    prepareSave(state);
    return state;
  }

  /// Everything a save needs before it is played, whether it was just loaded
  /// or just made.
  ///
  /// **A RESET IS A BOOT WITHOUT THE BOOT.** The JS reloads the page after one,
  /// so its fresh save goes through the same start-up as any other. The port
  /// swaps the map in place and carried on — so the season's opponents and its
  /// schedule, rolled only here, were never rolled: the next-match card read
  /// "Opponent" and the Fixtures sheet sat on "loading" until the app was
  /// killed and reopened. `GameState.onFreshState` brings a reset back here.
  void prepareSave(Map<String, dynamic> state) {
    // **A NAME, before anything reads it.** The JS auto-names an unnamed club
    // at boot — a random one, renamed later in Settings — because asking first
    // was friction on the way in. Fixture rows for OUR matches carry a null
    // side and every reader substitutes the club's name, so an empty name is
    // also a fixture list with a hole in it.
    if (state['clubName'] is! String || (state['clubName'] as String).isEmpty) {
      final auto = generateClubName();
      state['clubName'] = auto;
      // The JS counts this: a club named for the player never saw the naming
      // card, so it is the branch of that funnel where the card is not the
      // thing to look at.
      emit('club:name-auto-assigned', {'nameLength': auto.length});
    }
    grantTutorialGems(state);
    // The season quest track, which nothing rolled outside the season boundary:
    // a fresh save reached the Quests sheet with an empty season track and the
    // "no quests" line, and stayed that way until its first season ended. Both
    // rolls are guarded — on the season number and on the fixture key — so this
    // is a no-op for a save that already has its tracks.
    //
    // Written straight onto the map rather than through `update`: boot runs
    // inside the first build, and `update` notifies the providers, which Riverpod
    // refuses mid-build. Nothing is listening yet either, so there is nothing to
    // notify — and no save is scheduled either, deliberately: a boot that writes
    // nothing should not arm a timer, and the first thing that touches a quest
    // persists the track with it. A process killed before then simply rolls
    // again, which is what the guards are for.
    rollSeasonQuests(state);
    ensureMatchQuests(state);
    // The season's OPPONENTS and its 56-fixture schedule, which nothing rolled
    // outside the season boundary either — so a save that had not yet finished a
    // season, and every save made before the schedule landed, reached the
    // Fixtures sheet with nothing in it and sat on "loading" for good. Guarded
    // the same way: it skips a save that already carries its schedule.
    initSeasonOpponents(state);
    // A look for the manager, which the JS generates on the diorama's first
    // render and saves. `randomAvatar` was ported with no caller, so every save
    // drew the same hardcoded man: one hairstyle, no hat, the kit and nothing
    // else — and the look packs the Shop sells had nothing to change.
    final club = _map(state['club']);
    if (club != null && _map(club['managerAvatar']) == null) {
      club['managerAvatar'] = randomAvatar(state);
    }
  }

  /// Start the loop. Calling it twice is a no-op rather than two loops.
  void start() {
    if (_timer != null) return;
    _loop ??= GameLoop(startedAt: now());
    _timer = Timer.periodic(
      const Duration(milliseconds: tickIntervalMs),
      (_) => tickOnce(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// The app went away: save what is pending and flush the durable mirror,
  /// which is the whole point of having one.
  void pause() {
    stop();
    game.saveNow();
    game.flushNativeMirror();
  }

  /// The app came back.
  ///
  /// The elapsed time is SKIPPED rather than ticked: it belongs to the offline
  /// earnings calculation, and running it through the loop as well would pay
  /// for it twice.
  void resume() {
    _loop?.skipElapsed();
    start();
  }

  /// One turn, with whatever the screen is doing folded in.
  TickReport tickOnce() {
    final state = game.state;
    final loop = _loop;
    if (state == null || loop == null) {
      throw StateError('the runner has to boot before it can tick');
    }
    final report = loop.tick(state, gates: _gates(), hidden: _hidden());
    _announce(state, report);
    return report;
  }

  /// Turn a tick into bus events and a save.
  ///
  /// The income line deliberately does NOT go through `update`: it moves the
  /// coin balance every second, and a debounced save reset that often would
  /// never land. It schedules a save with no cloud sync instead — passive income
  /// recomputes from `lastSeen` on load, so it need not churn the cloud — and
  /// wakes the UI directly.
  void _announce(Map<String, dynamic> state, TickReport report) {
    if (report.coinsEarned > 0) {
      game.scheduleSave(syncCloud: false);
      game.notifyChanged();
      final at = now();
      if (at - _lastCoinEmitAt >= coinEmitIntervalMs ||
          report.coinsEarned >= 1) {
        _lastCoinEmitAt = at;
        // **THE TRICKLE SAYS SO FIRST.** Coins earned by doing something fly to
        // the counter and swell it; the players' own idle income is a trickle
        // and must not, or the HUD is pulsing every second of the game. The bus
        // is synchronous and ordered, so the pair is exact: the flight layer
        // reads this as "the very next `coins:updated` is passive". Inside the
        // throttle with it, or a skipped update would leave the flag set and
        // swallow the next real reward.
        emit('coins:idle', report.coinsEarned);
        emit('coins:updated', _map(state['resources'])?['fanCoins']);
      }
    }

    if (report.energyChanged) {
      emit('energy:updated', _map(state['energy'])?['current']);
      game.notifyChanged();
    }

    if (report.fitnessRecovered > 0) {
      emit('playerEnergy:updated', report.fitnessRecovered);
      game.notifyChanged();
    }

    if (report.injuriesHealed) {
      // The HUD's rate readout moves when a player comes back, so it is told
      // the same way a coin landing tells it.
      emit('coins:updated', _map(state['resources'])?['fanCoins']);
      game.notifyChanged();
    }

    if (report.loansRecalled.isNotEmpty) {
      emit('loan:wages-unpaid', {'departed': report.loansRecalled});
      emit('coins:updated', _map(state['resources'])?['fanCoins']);
    }

    if (report.transferOffer != null) {
      emit('transfer:offered', report.transferOffer);
    }

    // An event window crossing and a loan going home are not things to lose to
    // a debounce.
    if (report.needsImmediateSave) {
      game.saveNow();
      game.notifyChanged();
    }
  }
}
