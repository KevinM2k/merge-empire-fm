/// Feedback: what a message is, and what happens when it will not send.
///
/// **`sendFeedback` has no caller and these tests are not pretending otherwise.**
/// The JS hides its Send Feedback button on purpose and keeps the service
/// intact; the port does the same. What is LIVE is the queue drain, which runs
/// at boot and on resume in both.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/feedback_message.dart';
import 'package:merge_empire_fc/services/feedback_service.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _state() {
  final s = createDefaultState();
  s['clubName'] = 'Real Nowhere';
  (s['progression'] as Map<String, dynamic>)
    ..['currentDivision'] = 'elite'
    ..['seasonCount'] = 14
    ..['matchesPlayed'] = 300;
  (s['settings'] as Map<String, dynamic>)['hardMode'] = true;
  return s;
}

Future<List<Map<String, dynamic>>> _queue() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(feedbackQueueKey);
  if (raw == null) return [];
  return [
    for (final item in jsonDecode(raw) as List<dynamic>)
      item as Map<String, dynamic>,
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what a message IS', () {
    test('four characters, and a paste of a log is trimmed not refused', () {
      expect(isValidFeedback('slow'), isTrue);
      expect(isValidFeedback('k'), isFalse);
      expect(isValidFeedback('   ok  '), isFalse, reason: 'trimmed to two');
      expect(isValidFeedback(null), isFalse);
      expect(isValidFeedback(42), isFalse);
      expect(normaliseMessage('x' * 5000), hasLength(feedbackMaxLength));
      expect(normaliseContact('y' * 500), hasLength(feedbackMaxContact));
      expect(normaliseMessage('  hello  '), 'hello');
    });
  });

  group('THE CONTEXT IS MOST OF THE VALUE', () {
    test('a one-line complaint arrives with where the player is', () {
      // "Stuck in elite league, season 14" is actionable; "it is slow" is not.
      final meta = buildFeedbackMeta(_state(), platform: 'ios');
      expect(meta['division'], 'elite');
      expect(meta['season'], 14);
      expect(meta['matchesPlayed'], 300);
      expect(meta['hardMode'], isTrue);
      expect(meta['clubName'], 'Real Nowhere');
      expect(meta['platform'], 'ios');
      expect(meta['appVersion'], isNotEmpty);
    });

    test('and a null save is a shape, not a crash', () {
      final meta = buildFeedbackMeta(null, platform: 'web');
      expect(meta['clubName'], '');
      expect(meta['season'], 0);
      expect(meta['signedIn'], isFalse);
    });
  });

  group('sending', () {
    test('too short never leaves the device', () async {
      var posted = false;
      await expectLater(
        sendFeedback(
          _state(),
          message: 'no',
          post: (_) async => posted = true,
        ),
        throwsA(isA<FeedbackError>()),
      );
      expect(posted, isFalse);
      expect(await _queue(), isEmpty);
    });

    test('a good one goes straight out and is not queued', () async {
      Map<String, dynamic>? sent;
      final res = await sendFeedback(
        _state(),
        message: '  Love the merge feel  ',
        contact: ' me@example.com ',
        post: (p) async => sent = p,
      );
      expect(res, (ok: true, queued: false));
      expect(sent!['message'], 'Love the merge feel');
      expect(sent!['contact'], 'me@example.com');
      expect(await _queue(), isEmpty);
    });

    test('A TRANSPORT FAILURE IS QUEUED, not lost', () async {
      final res = await sendFeedback(
        _state(),
        message: 'Cannot connect',
        post: (_) async => throw const SocketishFailure(),
      );
      expect(res, (ok: true, queued: true));
      final queued = await _queue();
      expect(queued, hasLength(1));
      expect(queued.single['message'], 'Cannot connect');
      expect(queued.single['queuedAt'], isA<int>());
    });

    test('BUT A REJECTION THE SERVER MADE ON PURPOSE SURFACES', () async {
      // Retrying it would just be rejected again, at every boot, forever.
      for (final code in [
        const FeedbackError('too_many', status: 429),
        const FeedbackError('http_error', status: 400),
      ]) {
        SharedPreferences.setMockInitialValues({});
        await expectLater(
          sendFeedback(_state(), message: 'Too fast now', post: (_) async {
            throw code;
          }),
          throwsA(isA<FeedbackError>()),
        );
        expect(await _queue(), isEmpty, reason: '${code.status} was queued');
      }
    });

    test('and a 500 is temporary, so it queues', () async {
      final res = await sendFeedback(
        _state(),
        message: 'Server fell over',
        post: (_) async => throw const FeedbackError('http_error', status: 503),
      );
      expect(res.queued, isTrue);
    });

    test('THE QUEUE IS CAPPED so no signal cannot fill their storage', () async {
      for (var i = 0; i < feedbackQueueMax + 3; i++) {
        await sendFeedback(
          _state(),
          message: 'message number $i',
          post: (_) async => throw const SocketishFailure(),
        );
      }
      final queued = await _queue();
      expect(queued, hasLength(feedbackQueueMax));
      // The OLDEST go, not the newest — the last thing they said is the thing
      // they most wanted to say.
      expect(queued.last['message'], 'message number ${feedbackQueueMax + 2}');
    });
  });

  group('the drain, which is the half that IS wired', () {
    test('sends what is waiting and empties the queue', () async {
      await sendFeedback(
        _state(),
        message: 'Held back',
        post: (_) async => throw const SocketishFailure(),
      );
      expect(await _queue(), hasLength(1));

      final sent = <String>[];
      await flushFeedbackQueue(
        post: (p) async => sent.add(p['message'] as String),
      );
      expect(sent, ['Held back']);
      expect(await _queue(), isEmpty);
    });

    test('a still-failing item STAYS, and a hard rejection is dropped', () async {
      SharedPreferences.setMockInitialValues({});
      await sendFeedback(
        _state(),
        message: 'Still no signal',
        post: (_) async => throw const SocketishFailure(),
      );
      await flushFeedbackQueue(post: (_) async => throw const SocketishFailure());
      expect(await _queue(), hasLength(1), reason: 'gave up too early');

      // A 400 will never succeed, and a queue that keeps one forever never
      // empties. Throttling is not that — a 429 stays.
      await flushFeedbackQueue(
        post: (_) async => throw const FeedbackError('http_error', status: 400),
      );
      expect(await _queue(), isEmpty);
    });

    test('and 429 is throttling, so it stays queued', () async {
      SharedPreferences.setMockInitialValues({});
      await sendFeedback(
        _state(),
        message: 'Slow down',
        post: (_) async => throw const SocketishFailure(),
      );
      await flushFeedbackQueue(
        post: (_) async => throw const FeedbackError('too_many', status: 429),
      );
      expect(await _queue(), hasLength(1));
    });

    test('an empty queue is free and never throws', () async {
      var called = false;
      await flushFeedbackQueue(post: (_) async => called = true);
      expect(called, isFalse);
    });
  });
}

/// Stands in for a socket error — anything that is not a [FeedbackError].
class SocketishFailure implements Exception {
  const SocketishFailure();
}
