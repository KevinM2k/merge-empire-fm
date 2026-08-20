/// Name sanitisation and profanity screening, ported from
/// `../merge-empire-fc/src/utils/clubName.js`.
///
/// Club names are broadcast to other players on the global leaderboard, so a
/// raw user string must be cleaned of unicode tricks and screened before it
/// leaves the device. This is a client-side first line of defence — it is
/// bypassable by a direct REST write, so it is paired with server-side caps and
/// a report/moderation path. It blocks casual abuse, not a determined attacker.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math';

/// Max stored length. Server rules cap the field at 40.
const int clubNameMax = 30;
const int clubNameMin = 2;

/// Zero-width, bidi and control characters: invisible, and used to smuggle
/// profanity past filters, spoof other clubs, or break leaderboard layout.
/// Covers C0/C1 controls, zero-width, bidi overrides, invisible separators and
/// the BOM.
final RegExp _invisible = RegExp(
  '['
  '\u0000-\u001F' // C0 controls
  '\u007F-\u009F' // DEL and C1 controls
  '\u200B-\u200F' // zero-width and directional marks
  '\u202A-\u202E' // bidi overrides
  '\u2060-\u206F' // invisible separators
  '\uFEFF' // BOM
  ']',
);

final RegExp _whitespaceRun = RegExp(r'\s+');

/// Folds the Unicode fullwidth forms to their ASCII equivalents.
///
/// The JS gets this from `String.normalize('NFKC')`, which Dart has no core
/// equivalent for. It is NOT cosmetic: the profanity screen strips every
/// non-`a-z` character before matching, so a fullwidth "ｆｕｃｋ" would collapse
/// to an empty string and sail through. Folding here restores the JS behaviour
/// — verified against it, where `validateClubName('ｆｕｃｋ')` is rejected.
///
/// Covers the fullwidth ASCII block and the ideographic space, which is the
/// part of NFKC this screen actually depends on.
String _foldFullwidth(String s) {
  final out = StringBuffer();
  for (final rune in s.runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      out.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000) {
      out.writeCharCode(0x20);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Cleans a raw name for storage and display: fold fullwidth lookalikes, strip
/// invisible characters, collapse whitespace runs, trim, and clamp to [max].
String sanitizeName(Object? raw, int max) {
  var s = raw?.toString() ?? '';
  s = _foldFullwidth(s);
  s = s.replaceAll(_invisible, '');
  s = s.replaceAll(_whitespaceRun, ' ').trim();
  if (s.length > max) s = s.substring(0, max);
  return s.trim();
}

String sanitizeClubName(Object? raw) => sanitizeName(raw, clubNameMax);

/// Leetspeak and lookalike folding, so "f4ggot", "sh!t" and "n1gger" still
/// match.
const Map<String, String> _leet = {
  '4': 'a',
  '@': 'a',
  '3': 'e',
  '1': 'i',
  '!': 'i',
  '0': 'o',
  r'$': 's',
  '5': 's',
  '7': 't',
  '+': 't',
  '8': 'b',
};

final RegExp _leetChars = RegExp(r'[4@31!0$57+8]');
final RegExp _nonLetters = RegExp('[^a-z]');

String _fold(String s) =>
    s.toLowerCase().replaceAllMapped(_leetChars, (m) => _leet[m[0]] ?? m[0]!);

/// Strong terms: long, unambiguous slurs and explicit profanity that
/// effectively never appear inside a legitimate word. Matched as a substring of
/// the folded, separator-stripped name, which catches "n_i_g_g_e_r", "f.u.c.k"
/// and other spacing tricks.
const List<String> _strong = [
  'nigger',
  'nigga',
  'faggot',
  'retard',
  'motherfuck',
  'fuck',
  'shit',
  'bitch',
  'whore',
  'rapist',
  'paedo',
  'wetback',
  'tranny',
  'pussy',
  'jizz',
  'hitler',
  'jihad',
];

/// Words that DO embed in innocent words — the Scunthorpe problem. These
/// require a word boundary instead of a raw substring, so legitimate names
/// pass. That trades some separator-evasion resistance for far fewer false
/// positives; the moderation path backs it up.
const List<String> _word = [
  'ass',
  'hell',
  'damn',
  'crap',
  'sex',
  'anal',
  'anus',
  'tit',
  'tits',
  'cunt',
  'cock',
  'dick',
  'cum',
  'coon',
  'spic',
  'chink',
  'dyke',
  'rape',
  'pedo',
  'slut',
  'twat',
  'wank',
  'kike',
  'fag',
  'nazi',
  'kkk',
  'isis',
  'penis',
  'vagina',
  'bastard',
];

/// True when the name contains screened profanity.
bool containsProfanity(Object? name) {
  final folded = _fold(name?.toString() ?? '');
  // Collapse anything that is not a letter so separator tricks fold together.
  final compact = folded.replaceAll(_nonLetters, '');

  for (final w in _strong) {
    if (compact.contains(w)) return true;
  }
  for (final w in _word) {
    if (RegExp('\\b$w\\b').hasMatch(folded)) return true;
  }
  return false;
}

/// The result of sanitising then validating a name.
typedef NameCheck = ({bool ok, String name, String? reason});

NameCheck validateClubName(Object? raw) {
  final name = sanitizeClubName(raw);
  if (name.length < clubNameMin) {
    return (ok: false, name: name, reason: 'too_short');
  }
  if (containsProfanity(name)) {
    return (ok: false, name: name, reason: 'profanity');
  }
  return (ok: true, name: name, reason: null);
}

// ── Suggesting one ──────────────────────────────────────────────────────────
// A player who cannot think of a name must not be stuck on the one screen that
// will not let them past. The generator is what fills the placeholder and what
// the dice button rerolls.

/// Front word: evocative, adjective-ish, sets the vibe.
const List<String> clubDescriptors = [
  'Blaze',
  'Iron',
  'Storm',
  'Thunder',
  'Golden',
  'Crimson',
  'Steel',
  'Midnight',
  'Ember',
  'Frost',
  'Titan',
  'Shadow',
  'Inferno',
  'Diamond',
  'Apex',
  'Neon',
  'Cobalt',
  'Onyx',
  'Surge',
  'Volt',
  'Eclipse',
  'Phoenix',
  'Viper',
  'Falcon',
  'Hawk',
  'Wolf',
  'Lion',
  'Eagle',
  'Bear',
  'Cobra',
  'Panther',
  'Raven',
  'Fox',
  'Royal',
  'Ancient',
  'Rapid',
  'Mighty',
  'Wild',
  'Savage',
  'Electric',
  'Cosmic',
  'Solar',
  'Lunar',
  'Arctic',
  'Desert',
  'Granite',
  'Obsidian',
  'Scarlet',
  'Azure',
  'Emerald',
  'Crystal',
  'Rogue',
  'Vortex',
  'Blitz',
  'Rebel',
  'Atomic',
  'Turbo',
  'Nova',
  'Comet',
  'Zephyr',
  'Raging',
  'Fearless',
  'Immortal',
  'Radiant',
  'Venom',
  'Fury',
  'Havoc',
  'Riot',
  'Feral',
  'Regal',
  'Imperial',
  'Northern',
  'Southern',
  'Eastern',
  'Western',
  'Molten',
  'Frozen',
  'Blazing',
  'Roaring',
  'Rampant',
  'Vivid',
  'Prime',
  'Ultra',
  'Hyper',
  'Grand',
  'Elite',
  'Noble',
  'Stellar',
  'Thundering',
  'Shimmer',
  'Onward',
  'Valiant',
  'Bold',
];

/// Back word: reads like a real club name or a terrace nickname.
const List<String> clubWords = [
  'United',
  'City',
  'Town',
  'Athletic',
  'Rovers',
  'Wanderers',
  'Rangers',
  'Albion',
  'Villa',
  'Palace',
  'Dynamo',
  'Sporting',
  'FC',
  'AFC',
  'SC',
  'CF',
  'FA',
  'Dortmund',
  'Reds',
  'Blues',
  'Hotspur',
  'County',
  'Forest',
  'Olympic',
  'Borough',
  'Legion',
  'Union',
  'Stars',
  'Galaxy',
  'Republic',
  'Corinthians',
  'Select',
  'Zenit',
  'Lokomotiv',
  'Spartak',
  'Ultras',
  'Gunners',
  'Toffees',
  'Saints',
  'Magpies',
  'Hammers',
  'Bhoys',
  'Jets',
  'Kings',
  'Empire',
  'Heat',
  'Athletico',
  'Internazionale',
  'Wednesday',
  'Argyle',
  'Alexandra',
  'Vale',
  'Orient',
  'Thistle',
  'Harriers',
  'Casuals',
  'Nomads',
  'Swifts',
  'Crusaders',
  'Diablos',
  'Sporting',
  'Racing',
  'Deportivo',
  'Calcio',
  'Sociedad',
];

/// Leading prefix for the minority "prefix + descriptor" format.
const List<String> clubPrefixes = [
  'FC',
  'AFC',
  'Inter',
  'Real',
  'Sporting',
  'Athletic',
  'Dynamo',
  'Deportivo',
  'Racing',
  'Olympique',
  'Atletico',
];

/// A random two-word club name.
///
/// ~82% "Descriptor + Club" ("Blaze Dortmund"), ~18% "Prefix + Descriptor"
/// ("Inter Blaze") — the JS's own split. Sanitised and screened like any other
/// name, because the word lists multiply out to tens of thousands of pairs and
/// nobody has read them all.
String generateClubName([Random? rng]) {
  final random = rng ?? Random();
  String pick(List<String> from) => from[random.nextInt(from.length)];
  for (var attempt = 0; attempt < 8; attempt++) {
    final name = random.nextDouble() < 0.82
        ? '${pick(clubDescriptors)} ${pick(clubWords)}'
        : '${pick(clubPrefixes)} ${pick(clubDescriptors)}';
    final clean = sanitizeClubName(name);
    if (clean.length >= clubNameMin && !containsProfanity(clean)) return clean;
  }
  // Extremely unlikely, so that a caller always gets a usable name.
  return 'Blaze United';
}
