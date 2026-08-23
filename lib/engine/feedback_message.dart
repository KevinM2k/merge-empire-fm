/// What a feedback message is, before anything tries to send it. Ported from
/// the pure half of `../merge-empire-fc/src/services/feedbackService.js`.
///
/// **The context is most of the value.** A one-line complaint is not actionable
/// on its own; "stuck in elite league, season 14, Pro mode, VIP" is. So every
/// message carries a snapshot of where the player is, and the snapshot is built
/// here rather than at the seam so a test can read it.
///
/// **Nothing that identifies a person is in it.** The club name is one the
/// player typed for a football team, the leaderboard id is the app's own, and
/// there is no location, no device id and no contact detail — the contact field
/// is OPTIONAL and typed by the player who wants a reply.
///
/// Flutter-free: the POST and the retry queue are `services/feedback_service.dart`.
library;

import 'package:merge_empire_fc/data/config.dart';

/// Shorter than this is not a message. Four characters — "slow" is feedback,
/// "k" is a misfire.
const int feedbackMinLength = 4;

/// The server's own cap, applied here so a paste of a whole log is trimmed
/// rather than rejected.
const int feedbackMaxLength = 1000;

/// An email or a handle. Long enough for either.
const int feedbackMaxContact = 120;

/// Trim and clamp. Anything that is not a string is no message at all.
String normaliseMessage(Object? raw) => raw is String
    ? raw.trim().substring(
        0,
        raw.trim().length < feedbackMaxLength
            ? raw.trim().length
            : feedbackMaxLength,
      )
    : '';

/// Same treatment, to the contact field's own cap.
String normaliseContact(Object? raw) => raw is String
    ? raw.trim().substring(
        0,
        raw.trim().length < feedbackMaxContact
            ? raw.trim().length
            : feedbackMaxContact,
      )
    : '';

bool isValidFeedback(Object? raw) =>
    normaliseMessage(raw).length >= feedbackMinLength;

Map<String, dynamic>? _map(Object? v) =>
    v is Map<String, dynamic> ? v : null;

/// Where the player is, so a one-line complaint is actionable.
Map<String, dynamic> buildFeedbackMeta(
  Map<String, dynamic>? state, {
  required String platform,
}) {
  final settings = _map(state?['settings']);
  final progression = _map(state?['progression']);
  final leaderboard = _map(state?['leaderboard']);
  final boosts = _map(state?['boosts']);
  return <String, dynamic>{
    'appVersion': appVersion,
    'platform': platform,
    'locale': settings?['locale'] ?? 'en',
    'clubName': state?['clubName'] ?? '',
    'playerId': leaderboard?['playerId'] ?? '',
    'division': progression?['currentDivision'] ?? '',
    'season': progression?['seasonCount'] ?? 0,
    'matchesPlayed': progression?['matchesPlayed'] ?? 0,
    'prestige': _map(state?['prestige'])?['level'] ?? 0,
    'hardMode': settings?['hardMode'] == true,
    'signedIn': leaderboard?['authUid'] != null,
    'vip': boosts?['vipActive'] == true,
  };
}

/// One message, ready to post.
Map<String, dynamic> buildFeedbackPayload(
  Map<String, dynamic>? state, {
  required String message,
  String contact = '',
  required String platform,
}) => <String, dynamic>{
  'message': normaliseMessage(message),
  'contact': normaliseContact(contact),
  'meta': buildFeedbackMeta(state, platform: platform),
};
