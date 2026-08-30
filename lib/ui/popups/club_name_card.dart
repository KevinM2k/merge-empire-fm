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
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/club_name.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// Opens the card. Resolves to the stored name, or null if it was dismissed.
///
/// **The three key overrides are what stop there being a second name card.**
/// Prestige asks the same question with its own words — `prestige.name_prompt`,
/// `prestige.name_placeholder` and `prestige.kick_off`, all three translated ten
/// times over with nothing able to reach one — and the difference between that
/// card and this one is three strings, not a widget. Everything that matters
/// here (the screening, the dice, the error that appears on the card it was
/// earned on) is the same question either way round.
Future<String?> showClubNameCard(
  BuildContext context, {
  String? titleKey,
  String? placeholderKey,
  String? confirmKey,
}) => showDialog<String>(
  context: context,
  builder: (_) => ClubNameCard(
    titleKey: titleKey,
    placeholderKey: placeholderKey,
    confirmKey: confirmKey,
  ),
);

class ClubNameCard extends ConsumerStatefulWidget {
  const ClubNameCard({
    this.titleKey,
    this.placeholderKey,
    this.confirmKey,
    super.key,
  });

  /// The card's own heading, or null for the standing "name your club".
  final String? titleKey;

  /// The hint in the field. Takes `{name}` — the dice's current suggestion —
  /// and a key that does not use it simply ignores it, which is `t()`'s own
  /// behaviour for a param with no placeholder.
  final String? placeholderKey;

  /// The confirm button. Prestige's is "Kick Off!", because on that card the
  /// name is the last thing between the player and a new career.
  final String? confirmKey;

  @override
  ConsumerState<ClubNameCard> createState() => ClubNameCardState();
}

class ClubNameCardState extends ConsumerState<ClubNameCard> {
  /// The suggestion. Rerolled by the dice, and used as the answer when the
  /// field is left empty — so the dice is a way of ACCEPTING a name rather than
  /// only of seeing one.
  String _suggested = generateClubName();

  /// **A NEW CLUB ARRIVES ALREADY NAMED.**
  ///
  /// The field started empty on a fresh save with the suggestion only in the
  /// placeholder, so the card asked a player who has not seen the game yet to
  /// invent a football club before they could get past it — and the dice beside
  /// it reads as decoration rather than as the answer. Filled in, the card is a
  /// name to keep or to change, which is the same bargain the dice already
  /// makes: "a suggestion you then have to retype is not a suggestion".
  ///
  /// A save that HAS a name keeps it — this card is also how a club is renamed.
  late final TextEditingController _field = TextEditingController(
    text: ref.read(clubNameProvider).isEmpty
        ? _suggested
        : ref.read(clubNameProvider),
  );
  String? _error;

  /// **The naming funnel's two clocks.** The JS reports how long the card was
  /// up before a name was taken and whether the dice was what produced it —
  /// between them they say whether the suggestion is doing its job or whether
  /// players are sitting on this screen inventing a football club.
  final int _shownAt = DateTime.now().millisecondsSinceEpoch;
  bool _usedGenerateBtn = false;

  @override
  void initState() {
    super.initState();
    // A save with no name has never seen this card; one with a name is here to
    // rename. Two different moments, and summing them hides the first.
    emit('club:name-card-shown', {
      'isFirstTime': ref.read(clubNameProvider).isEmpty,
    });
  }

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
    emit('club:renamed', {
      'name': check.name,
      'nameLength': check.name.length,
      // Kept as it was offered — the dice's answer accepted, whether it was
      // left in the field or retyped.
      'usedSuggestion': typed.isEmpty || typed == _suggested,
      'usedGenerateBtn': _usedGenerateBtn,
      'timeToConfirmMs': DateTime.now().millisecondsSinceEpoch - _shownAt,
    });
    if (mounted) Navigator.of(context).pop(check.name);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return CoachCardFrame(
      title: t(widget.titleKey ?? 'club_name.title'),
      body: t('club_name.subtitle'),
      actions: [
        CoachAction(
          labelKey: 'common.cancel',
          tone: CoachTone.decline,
          onTap: () {},
        ),
        CoachAction(
          labelKey: widget.confirmKey ?? 'club_name.confirm',
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
                    hintText: t(
                      widget.placeholderKey ?? 'club_name.placeholder',
                      {'name': _suggested},
                    ),
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
                  _usedGenerateBtn = true;
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
                style: const TextStyle(fontSize: 11, color: dangerInk),
              ),
            ),
        ],
      ),
    );
  }
}
