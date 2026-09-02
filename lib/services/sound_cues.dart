/// Which sound each thing that happens makes. Ported from the `on(...)` block in
/// `main.js`.
///
/// **THE BUS IS THE WIRING, and that is the JS's decision worth keeping.** The
/// alternative is a `playX()` next to every action, which means the merge engine,
/// the transfer engine and the quest engine each know about audio — and it means
/// the same action makes a sound when it is taken from one screen and not from
/// another. Everything here is an event that already exists because something
/// else needed it.
///
/// **A TIER-7 MERGE IS A DIFFERENT SOUND**, and it is the only branch in the
/// table: the whole reward loop of the game is "merge up", so the moment a card
/// crosses into the top tiers has to be audibly bigger than the four hundred
/// merges before it.
///
/// Match sounds are NOT here — the whistle, the goals and the result belong to the
/// clock the match screen is running, not to an event fired when the maths was
/// done. See `screens/match/match_screen.dart`.
library;

import 'dart:async';

import 'package:merge_empire_fc/services/sound_service.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The tier at which a merge stops being routine.
const int epicMergeTier = 7;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Subscribes [service] to the bus, and hands back the teardown.
///
/// Returned rather than left registered: the bus holds strong references, so a
/// host that forgets this keeps a dead service alive and playing.
void Function() wireSoundCues(SoundService service) {
  // **ONE SOUND PER THING THAT HAPPENED, and a discovery outranks the rest.**
  //
  // Three cues describe the same moment. A merge fires `merge:complete`; if the
  // card it made has never been seen it ALSO fires `playerindex:discovered`; a
  // batch signing places four cards and fires `card:placed` four times. So one
  // tap produced a merge chime under a discovery fanfare, and four signings
  // produced a scout cue stacked on a discovery. `retriggerFloor` collapses
  // repeats of the SAME clip and can do nothing about two different ones.
  //
  // Asked for from the couch in exactly these terms: "even if we get 4 players,
  // if one of them is new, then we should play the new player sound, otherwise
  // we just play the normal sound, but we only play one."
  //
  // So the three of them go through an arbiter. Everything that lands inside
  // one window is one event; the discovery wins it if there was one, and
  // otherwise the loudest merge does.
  final arbiter = _OneSound(service);

  final handlers = <String, BusHandler>{
    // Every merge, and the one that is worth more than a sound effect.
    'merge:complete': (args) {
      final tier = (_map(_map(args)?['newDef'])?['tier'] as num?)?.toInt() ?? 0;
      arbiter.offer(tier >= epicMergeTier ? 'epicMerge' : 'merge', rank: 2);
    },
    // A signing arriving on the grid.
    'card:placed': (_) => arbiter.offer('scout', rank: 1),
    // The one negative cue in the set. It fires on a refused merge — not enough
    // coins, nothing to merge with — because a tap that does nothing and says
    // nothing reads as a broken button.
    'merge:refused': (_) => service.play('error'),
    'player:sold': (_) => service.play('sell'),
    'quest:completed': (_) => service.play('challenge'),
    // A card nobody has ever seen before. The JS plays nothing here, which is a
    // gap rather than a decision: `newDiscovery` is defined, is the biggest
    // sound in the set after the fanfares, and discovery is the game's own word
    // for the thing it would mark.
    'playerindex:discovered': (_) => arbiter.offer('newDiscovery', rank: 3),
    // Promotion only. A relegation already has the season-end screen's own
    // treatment, and a fanfare for going down would be worse than silence.
    'season:ended': (args) {
      if (_map(args)?['outcome'] == 'promoted') service.play('promotion');
    },
    'purchase:complete': (_) => service.play('coin'),
    'dailyreward:claimed': (_) => service.play('coin'),
    'trait:rolled': (_) => service.play('challenge'),
  };

  handlers.forEach(on);
  return () {
    handlers.forEach(off);
    arbiter.cancel();
  };
}

/// The arbiter: everything offered inside one window becomes one sound.
///
/// **Ranked rather than first-wins or last-wins**, because the order the bus
/// fires them in is not the order they matter in: `merge:complete` is emitted
/// before the discovery it caused, and a batch signing places its cards before
/// anything has looked at whether they are new.
///
/// The window is [_window], and it is the same reasoning as `retriggerFloor` in
/// `sound_service.dart`: a batch lands inside one `update`, and the whole point
/// is that a batch is one event to a listener.
class _OneSound {
  _OneSound(this.service);

  final SoundService service;

  static const Duration _window = Duration(milliseconds: 90);

  Timer? _timer;
  String? _cue;
  int _rank = 0;

  void offer(String cue, {required int rank}) {
    if (rank >= _rank) {
      _cue = cue;
      _rank = rank;
    }
    _timer ??= Timer(_window, _flush);
  }

  void _flush() {
    _timer = null;
    final cue = _cue;
    _cue = null;
    _rank = 0;
    if (cue != null) service.play(cue);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _cue = null;
    _rank = 0;
  }
}
