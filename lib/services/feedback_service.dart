/// Player feedback → the studio's `submitFeedback` Cloud Function. Ported from
/// `../merge-empire-fc/src/services/feedbackService.js`.
///
/// **It needs no account and no Firebase SDK.** The function records the message
/// and emails it on; nothing is written to the client's own Firestore
/// collections, so there is no rules entry, and a signed-out player is a
/// first-class caller — the JS attaches an Authorization header only when a
/// real session exists and the function treats it as optional. That is what
/// makes this the one service in M4 that is not blocked on the rest of M4, and
/// the port simply never sends one.
///
/// **Delivery is best-effort but never silently lost.** A send that fails for
/// transport reasons is queued and retried at the next boot. A rejection the
/// server made ON PURPOSE is not queued — retrying it would just be rejected
/// again — which is the whole of why [FeedbackError] exists.
///
/// The queue lives in its own preferences key, apart from the game save, so it
/// can neither corrupt nor bloat it.
///
/// **[sendFeedback] HAS NO CALLER, and that is the port matching the spec rather
/// than the port dropping something.** The JS hides its Send Feedback button on
/// purpose — its `SettingsScreen` comment says the whole feature is intact and
/// what it is waiting for is the function itself: "deploy submitFeedback and
/// make it publicly callable". A sheet built here would post player text at an
/// endpoint that may not answer, and queue it forever when it did not. So the
/// Settings row stays a `PendingControl` and the thirteen `feedback.*` strings
/// stay unreachable, in both codebases, until that deploy happens.
///
/// [flushFeedbackQueue] IS wired — at boot and on resume, the JS's own two call
/// sites — because a queue that is only drained by the release that unhides the
/// button is a queue that strands whatever the previous release put in it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:merge_empire_fc/engine/feedback_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String feedbackFunctionUrl =
    'https://us-central1-merge-empire-fc.cloudfunctions.net/submitFeedback';

const Duration feedbackTimeout = Duration(seconds: 15);

/// Its own key, deliberately not the save's.
const String feedbackQueueKey = 'mergeEmpireFC_feedbackQueue';

/// **A player with no signal must not fill their storage.** Five is enough to
/// survive a flight and small enough to be free.
const int feedbackQueueMax = 5;

/// Why a send did not land, when the player needs telling.
///
/// The two the UI reports rather than quietly queueing: too short (their fault,
/// and fixable in a second) and too many (the server throttling them, and
/// retrying would be rejected again).
class FeedbackError implements Exception {
  const FeedbackError(this.code, {this.status});

  /// `too_short` | `too_many` | `http_error`
  final String code;
  final int? status;

  @override
  String toString() => 'FeedbackError($code, status: $status)';
}

/// What a send did.
typedef FeedbackResult = ({bool ok, bool queued});

/// The POST, as a seam a test can replace.
typedef FeedbackPost = Future<void> Function(Map<String, dynamic> payload);

/// The real one. Throws [FeedbackError] on any non-2xx.
Future<void> postFeedback(Map<String, dynamic> payload) async {
  final client = HttpClient()..connectionTimeout = feedbackTimeout;
  try {
    final request = await client
        .postUrl(Uri.parse(feedbackFunctionUrl))
        .timeout(feedbackTimeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(feedbackTimeout);
    // Drained rather than ignored: an undrained response leaks the connection.
    await response.drain<void>().timeout(feedbackTimeout);
    if (response.statusCode >= 400) {
      throw FeedbackError(
        response.statusCode == 429 ? 'too_many' : 'http_error',
        status: response.statusCode,
      );
    }
  } finally {
    client.close(force: true);
  }
}

String _platform() {
  try {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
  } catch (_) {
    // No platform to ask.
  }
  return 'web';
}

Future<List<Map<String, dynamic>>> _readQueue() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(feedbackQueueKey);
    if (raw == null || raw.isEmpty) return [];
    final parsed = jsonDecode(raw);
    if (parsed is! List) return [];
    return [
      for (final item in parsed)
        if (item is Map<String, dynamic>) item,
    ];
  } catch (_) {
    // Storage disabled, or a queue written by a newer build. Either way there
    // is nothing here worth failing over.
    return [];
  }
}

Future<void> _writeQueue(List<Map<String, dynamic>> items) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await prefs.remove(feedbackQueueKey);
      return;
    }
    final kept = items.length <= feedbackQueueMax
        ? items
        : items.sublist(items.length - feedbackQueueMax);
    await prefs.setString(feedbackQueueKey, jsonEncode(kept));
  } catch (_) {
    // Storage full or disabled — dropping the queue is acceptable, and better
    // than an exception on a path the player did not ask to be on.
  }
}

/// Send one message.
///
/// Throws [FeedbackError] for the two the player is told about; everything else
/// is queued and reported as `queued: true`.
Future<FeedbackResult> sendFeedback(
  Map<String, dynamic>? state, {
  required String message,
  String contact = '',
  FeedbackPost post = postFeedback,
}) async {
  if (!isValidFeedback(message)) {
    throw const FeedbackError('too_short');
  }
  final payload = buildFeedbackPayload(
    state,
    message: message,
    contact: contact,
    platform: _platform(),
  );

  try {
    await post(payload);
    return (ok: true, queued: false);
  } on FeedbackError catch (e) {
    // **A rejection the server made on purpose must SURFACE.** Queueing a 400
    // means retrying a message the server has already refused, at every boot,
    // for as long as the queue holds it.
    final permanent =
        e.code == 'too_many' ||
        (e.status != null && e.status! >= 400 && e.status! < 500);
    if (permanent) rethrow;
    await _enqueue(payload);
    return (ok: true, queued: true);
  } catch (_) {
    // Transport: offline, DNS, a timeout. Temporary by definition.
    await _enqueue(payload);
    return (ok: true, queued: true);
  }
}

Future<void> _enqueue(Map<String, dynamic> payload) async {
  final queued = await _readQueue();
  await _writeQueue([
    ...queued,
    {...payload, 'queuedAt': DateTime.now().millisecondsSinceEpoch},
  ]);
}

/// Retry anything a failed send left behind. Called once at boot.
///
/// **Never throws and never blocks.** A still-failing item stays queued for the
/// next attempt; a HARD rejection is dropped, because a 400 will never succeed
/// and a queue that keeps one forever is a queue that never empties. Throttling
/// (429) and transport failures are temporary, so those stay.
Future<void> flushFeedbackQueue({FeedbackPost post = postFeedback}) async {
  final queued = await _readQueue();
  if (queued.isEmpty) return;

  final remaining = <Map<String, dynamic>>[];
  for (final payload in queued) {
    try {
      await post(payload);
    } on FeedbackError catch (e) {
      final permanent =
          e.status != null &&
          e.status! >= 400 &&
          e.status! < 500 &&
          e.status != 429;
      if (!permanent) remaining.add(payload);
    } catch (_) {
      remaining.add(payload);
    }
  }
  await _writeQueue(remaining);
}
