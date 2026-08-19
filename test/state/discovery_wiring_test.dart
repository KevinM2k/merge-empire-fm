/// Recording a discovery — the Player Index's only writer.
///
/// `main.js` does this on `card:placed` and `merge:complete` and the port had
/// neither, so `discoveredPlayers` never grew: the Index would have read 0 of 66
/// forever however much a player scouted, and the season quest that counts
/// discoveries could never advance.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/game_wiring.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// A definition every save has, at the bottom of the ladder.
const String _defId = 'player_t1_fwd';

/// The first male and first female variant, so a test can name the key it
/// expects rather than guessing which way the predicate falls.
int get _maleVariant => List.generate(
  variants.length,
  (i) => i,
).firstWhere((i) => !isVariantFemale(i));
int get _femaleVariant => List.generate(
  variants.length,
  (i) => i,
).firstWhere((i) => isVariantFemale(i));

({GameState game, GameWiring wiring}) _boot() {
  final state = createDefaultState();
  final game = GameState(
    store: MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
  );
  game.load();
  final wiring = GameWiring(game)..attach();
  addTearDown(wiring.detach);
  return (game: game, wiring: wiring);
}

Map<String, dynamic> _progression(GameState game) =>
    game.state!['progression'] as Map<String, dynamic>;

List<dynamic> _discovered(GameState game) =>
    _progression(game)['discoveredPlayers'] as List<dynamic>;

Map<String, dynamic> _counts(GameState game) =>
    _progression(game)['playerFoundCounts'] as Map<String, dynamic>;

void main() {
  tearDown(resetBus);

  test('a fresh save has discovered nobody', () {
    final boot = _boot();
    expect(_discovered(boot.game), isEmpty);
  });

  test('scouting a card records it', () {
    final boot = _boot();
    final cells = (boot.game.state!['grid'] as Map<String, dynamic>)['cells']
        as List<dynamic>;
    boot.game.update((_) => placeCard(_defId, cells));

    expect(_discovered(boot.game), hasLength(1));
    expect('${_discovered(boot.game).first}', startsWith('$_defId:'));
  });

  test('scouting the SAME card again counts it without a second entry', () {
    // The count is cumulative and the list is a set. Getting this backwards
    // makes the index read "×1" for a card a player has pulled ten times.
    final boot = _boot();
    final cells = (boot.game.state!['grid'] as Map<String, dynamic>)['cells']
        as List<dynamic>;
    boot.game.update((_) => placeCard(_defId, cells));
    final key = '${_discovered(boot.game).first}';
    // A second placement of the same definition can roll a different variant,
    // so the count is asserted against whatever key each one wrote.
    boot.game.update((_) => placeCard(_defId, cells));

    final total = _counts(
      boot.game,
    ).values.fold<int>(0, (sum, v) => sum + (v as num).toInt());
    expect(total, 2);
    expect(_counts(boot.game)[key], isNotNull);
  });

  test('the two genders are separate entries', () {
    // One definition is TWO index rows — the whole reason the key carries a
    // gender rather than being the definition id.
    final boot = _boot();
    boot.game.update((s) {
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      cells[0] = <String, dynamic>{
        'definitionId': _defId,
        'instanceId': 'a',
        'variant': _maleVariant,
      };
      cells[1] = <String, dynamic>{
        'definitionId': _defId,
        'instanceId': 'b',
        'variant': _femaleVariant,
      };
    });
    emit('card:placed', {
      'card': <String, dynamic>{
        'definitionId': _defId,
        'instanceId': 'a',
        'variant': _maleVariant,
      },
    });
    emit('card:placed', {
      'card': <String, dynamic>{
        'definitionId': _defId,
        'instanceId': 'b',
        'variant': _femaleVariant,
      },
    });

    expect(_discovered(boot.game), containsAll(['$_defId:m', '$_defId:f']));
  });

  test('a merge records the card it produced', () {
    // `merge:complete` names it `newCard`, not `card`. Reading the wrong field
    // silently records nothing, which is invisible until the index stays empty.
    final boot = _boot();
    emit('merge:complete', {
      'newCard': <String, dynamic>{
        'definitionId': 'player_t2_fwd',
        'instanceId': 'm1',
        'variant': _maleVariant,
      },
    });
    expect(_discovered(boot.game), contains('player_t2_fwd:m'));
  });

  test('the first sighting announces, and later ones do not', () {
    final boot = _boot();
    final announced = <Object?>[];
    on('playerindex:discovered', announced.add);

    for (var i = 0; i < 3; i++) {
      emit('card:placed', {
        'card': <String, dynamic>{
          'definitionId': _defId,
          'instanceId': 'c$i',
          'variant': _maleVariant,
        },
      });
    }
    expect(announced, ['$_defId:m']);
    expect(_counts(boot.game)['$_defId:m'], 3);
  });

  test('a payload with no definition is ignored', () {
    final boot = _boot();
    emit('card:placed', {'card': <String, dynamic>{'instanceId': 'x'}});
    emit('card:placed', null);
    emit('merge:complete', {'newCard': null});
    expect(_discovered(boot.game), isEmpty);
  });
}
