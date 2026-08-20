/// Naming the club. Ported from `components/ClubNameModal.js`.
///
/// **It is Colin's card, not a form.** The port had no way to change the club
/// name at all, and the obvious fix — an `AlertDialog` with a `TextField` — would
/// have been the app's own voice on the one screen where the player is being
/// asked something. `CoachCardFrame` is the chrome, so this arrives the way
/// every other question does.
///
/// **A name is SCREENED before it is stored, not after.** It goes on the global
/// leaderboard, so `validateClubName` runs on the way in — the same call the JS
/// makes, sanitising unicode tricks first and then screening. The error text is
/// keyed off the reason it gives back, so the two cannot disagree about what was
/// wrong.
///
/// **There is always a name to hand.** The dice rerolls a generated one and the
/// placeholder shows one from the start, because a player who cannot think of a
/// name must not be stuck on a card that will not let them past.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/settings_controls.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/club_name.dart';

/// Opens the card. Resolves to the stored name, or null if it was dismissed.
Future<String?> showClubNameCard(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const ClubNameCard());

class ClubNameCard extends ConsumerStatefulWidget {
  const ClubNameCard({super.key});

  @override
  ConsumerState<ClubNameCard> createState() => ClubNameCardState();
}

class ClubNameCardState extends ConsumerState<ClubNameCard> {
  late final TextEditingController _field = TextEditingController(
    text: ref.read(clubNameProvider),
  );

  /// The suggestion in the placeholder. Rerolled by the dice, and used as the
  /// answer when the field is left empty — so the dice is a way of ACCEPTING a
  /// name rather than only of seeing one.
  String _suggested = generateClubName();
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = _field.text.trim();
    final check = validateClubName(typed.isEmpty ? _suggested : typed);
    if (!check.ok) {
      setState(() {
        _error = check.reason == 'profanity'
            ? t('club_name.error_profanity')
            : t('club_name.error_invalid');
      });
      return;
    }
    ref.read(gameProvider).update((s) => s['clubName'] = check.name);
    if (mounted) Navigator.of(context).pop(check.name);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return CoachCardFrame(
      title: t('club_name.title'),
      body: t('club_name.subtitle'),
      actions: [
        CoachAction(labelKey: 'common.cancel', onTap: () {}),
        CoachAction(
          labelKey: 'club_name.confirm',
          tone: CoachTone.confirm,
          // The card stays up until the name is good — otherwise a rejected
          // name closes the card the rejection was going to appear on.
          dismisses: false,
          onTap: _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('club-name-field'),
                  controller: _field,
                  autofocus: true,
                  maxLength: clubNameMax,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  // Clearing the error on the next keystroke rather than on the
                  // next submit: a message about a name that is no longer in
                  // the field is a message about nothing.
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    hintText: t('club_name.placeholder', {'name': _suggested}),
                    counterText: '',
                    filled: true,
                    fillColor: kit.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: kit.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('club-name-generate'),
                tooltip: t('club_name.generate'),
                icon: Icon(Icons.casino_outlined, color: kit.accentBright),
                onPressed: () => setState(() {
                  _suggested = generateClubName();
                  // Into the FIELD, not just the placeholder: a suggestion you
                  // then have to retype is not a suggestion.
                  _field.text = _suggested;
                  _error = null;
                }),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                key: const ValueKey('club-name-error'),
                style: const TextStyle(fontSize: 11, color: settingsDanger),
              ),
            ),
        ],
      ),
    );
  }
}
