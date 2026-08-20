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
  final handlers = <String, BusHandler>{
    // Every merge, and the one that is worth more than a sound effect.
    'merge:complete': (args) {
      final tier = (_map(_map(args)?['newDef'])?['tier'] as num?)?.toInt() ?? 0;
      service.play(tier >= epicMergeTier ? 'epicMerge' : 'merge');
    },
    // A signing arriving on the grid.
    'card:placed': (_) => service.play('scout'),
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
    'playerindex:discovered': (_) => service.play('newDiscovery'),
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
  return () => handlers.forEach(off);
}
