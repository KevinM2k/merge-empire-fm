/// Player rename sanitisation and validation, ported from
/// `../merge-empire-fc/src/utils/playerName.js`.
///
/// A player's name is cosmetic — it never touches rating, income, merging or
/// sell value — but it IS rendered into a lot of templates and it rides along
/// in cloud saves. Two consequences:
///
///   1. The allowed character set is restrictive on purpose. Only letters,
///      marks, digits, spaces and a few name punctuation marks survive, so a
///      renamed player can never carry markup into a template that does not
///      escape it. This is a whitelist, not an escape — nothing downstream has
///      to remember to sanitise.
///   2. Names are profanity-screened with the same list club names use, so a
///      slur cannot be smuggled into a shared save or a support screenshot.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/util/club_name.dart';

/// Short enough to fit the card front and the pitch label without ellipsis.
const int playerNameMax = 20;
const int playerNameMin = 2;

/// Everything outside this set is dropped: letters of any script, combining
/// marks, digits, space, apostrophe, hyphen and full stop — enough for
/// "N'Golo", "Alex-Sofia" and "J. Rodrigo", but no angle brackets, ampersands,
/// quotes or backticks, which is what keeps unescaped templates safe.
final RegExp _disallowed = RegExp(r"[^\p{L}\p{M}\p{N} '\-.]", unicode: true);

/// Cleans a raw player name for storage and display.
String sanitizePlayerName(Object? raw) {
  final stripped = (raw?.toString() ?? '').replaceAll(_disallowed, ' ');
  return sanitizeName(stripped, playerNameMax);
}

/// Sanitises then validates a raw player name.
NameCheck validatePlayerName(Object? raw) {
  final name = sanitizePlayerName(raw);
  if (name.length < playerNameMin) {
    return (ok: false, name: name, reason: 'too_short');
  }
  if (containsProfanity(name)) {
    return (ok: false, name: name, reason: 'profanity');
  }
  return (ok: true, name: name, reason: null);
}
