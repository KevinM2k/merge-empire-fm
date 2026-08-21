/// Renaming a player. Ported from `components/PlayerNameModal.js`.
///
/// **Nothing in the port could rename a card**, and the tells were all there:
/// `util/player_name.dart` is a ported, tested sanitiser and screener with no
/// caller anywhere in `lib/`; eight `rename.*` strings sit generated in all ten
/// catalogues with nothing able to reach one; `CardInstance.customName` is read
/// by five surfaces and written by none; and two SEASON QUESTS —
/// `season_rename` and `season_rename_many` — count renamed cards, so they
/// could never advance. The same shape as `trackEvent`.
///
/// **It is Colin's card, not a bottom sheet.** The JS makes it a sheet, but here
/// it opens from INSIDE the player detail sheet, and a sheet over a sheet is a
/// shape the queue does not have. The club's own name is asked for on a Coach
/// card for the same reason, and this is the same question about a different
/// name.
///
/// **A name is SCREENED on the way in.** `validatePlayerName` whitelists the
/// character set rather than escaping — so a renamed player can never carry
/// markup into a template — and screens with the same profanity list club names
/// use, because a name rides along in a cloud save.
///
/// **Typing the rolled name back in is a RESET, not a custom name.** Storing it
/// would pin the card to a name it would have had anyway, and would count
/// towards a quest about renaming players without renaming one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart'
    show cardById;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/player_name.dart';

/// Opens the card. Resolves to the card's new effective name, or null when it
/// was dismissed without a change.
Future<String?> showPlayerNameCard(
  BuildContext context, {
  required String instanceId,
}) => showDialog<String>(
  context: context,
  builder: (_) => PlayerNameCard(instanceId: instanceId),
);

class PlayerNameCard extends ConsumerStatefulWidget {
  const PlayerNameCard({super.key, required this.instanceId});

  final String instanceId;

  @override
  ConsumerState<PlayerNameCard> createState() => PlayerNameCardState();
}

class PlayerNameCardState extends ConsumerState<PlayerNameCard> {
  late final TextEditingController _field;

  /// What the card falls back to when the custom name is cleared: the name
  /// rolled when the instance was created, or the definition's own.
  late final String _defaultName;
  late final bool _hasCustom;
  String? _error;

  @override
  void initState() {
    super.initState();
    final card = cardById(ref.read(gameProvider).state, widget.instanceId);
    final def = getPlayerDef(card?.definitionId);
    _defaultName = card?.displayName ?? def?.name ?? '';
    _hasCustom = (card?.customName ?? '').isNotEmpty;
    _field = TextEditingController(text: card?.name(_defaultName) ?? '');
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Write the name onto the LIVE instance, looked up by id.
  ///
  /// By id and not by holding a reference: the detail sheet behind this card is
  /// showing a card it read out of the save, and writing through a stale copy
  /// would rename something that is no longer there.
  String _commit(String? value) {
    final game = ref.read(gameProvider);
    game.update((s) {
      final cells = (s['grid'] as Map<String, dynamic>?)?['cells'];
      if (cells is! List) return;
      for (final raw in cells) {
        if (raw is Map<String, dynamic> &&
            raw['instanceId'] == widget.instanceId) {
          if (value == null) {
            raw.remove('customName');
          } else {
            raw['customName'] = value;
          }
          return;
        }
      }
    });
    // Flushed rather than left to the two-second debounce: a rename is cheap to
    // lose and very annoying when it happens.
    game.saveNow();
    final now =
        cardById(game.state, widget.instanceId)?.name(_defaultName) ??
        _defaultName;
    emit('player:renamed', {
      'instanceId': widget.instanceId,
      'name': now,
      'reset': value == null,
    });
    return now;
  }

  void _submit() {
    final check = validatePlayerName(_field.text);
    if (!check.ok) {
      setState(() {
        _error = check.reason == 'profanity'
            ? t('rename.error_profanity')
            : t('rename.error_invalid');
      });
      return;
    }
    final name = _commit(check.name == _defaultName ? null : check.name);
    if (mounted) Navigator.of(context).pop(name);
  }

  /// Clear the custom name. The frame closes the card and resolves it with
  /// [_defaultName] — which is what the card is called the moment this runs.
  void _reset() => _commit(null);

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return CoachCardFrame(
      title: t('rename.title'),
      body: t('rename.subtitle'),
      actions: [
        CoachAction(labelKey: 'common.cancel', onTap: () {}),
        // Only when there is one to clear — a Reset on a card that has never
        // been renamed does nothing and says nothing.
        if (_hasCustom)
          CoachAction(
            labelKey: 'rename.reset',
            labelParams: {'name': _defaultName},
            result: _defaultName,
            onTap: _reset,
          ),
        CoachAction(
          labelKey: 'rename.confirm',
          tone: CoachTone.confirm,
          // The card stays up until the name is good, or the rejection would
          // appear on a card that has already closed.
          dismisses: false,
          onTap: _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('player-name-field'),
            controller: _field,
            autofocus: true,
            maxLength: playerNameMax,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            // Cleared on the next keystroke rather than the next submit: a
            // message about a name no longer in the field is about nothing.
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText: _defaultName,
              counterText: '',
              filled: true,
              fillColor: kit.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kit.border),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const ValueKey('player-name-error'),
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
