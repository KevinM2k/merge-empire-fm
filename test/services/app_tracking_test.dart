/// Apple's prompt, at the seam. The plugin's own behaviour is NOT tested here
/// and cannot be — there is no iOS device in a cloud container, and the method
/// channel answers `notSupported` everywhere else.
///
/// What this pins is the decision logic, which is the part that was missing
/// rather than wrong: WHEN the prompt is asked for, what happens when it is not
/// answered, and that a failure leaves the ad stack serving.
library;

import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/app_tracking.dart';
import 'package:merge_empire_fc/util/analytics.dart';

class _Prompt implements TrackingPrompt {
  _Prompt(this.initial, {this.answer, this.throws = false, this.hangs = false});

  final TrackingStatus initial;
  final TrackingStatus? answer;
  final bool throws;
  final bool hangs;
  int asked = 0;
  int requested = 0;

  @override
  Future<TrackingStatus> status() async {
    asked += 1;
    if (throws) throw StateError('no plugin');
    return initial;
  }

  @override
  Future<TrackingStatus> request() async {
    requested += 1;
    if (hangs) return Completer<TrackingStatus>().future;
    return answer ?? initial;
  }
}

void main() {
  late List<({String name, Map<String, Object?> params})> sent;

  setUp(() {
    sent = [];
    setAnalyticsSink((name, params) => sent.add((name: name, params: params)));
  });

  tearDown(() => setAnalyticsSink(null));

  test('NOT DETERMINED IS THE ONE STATE THAT PROMPTS', () async {
    final prompt = _Prompt(
      TrackingStatus.notDetermined,
      answer: TrackingStatus.authorized,
    );
    expect(
      await requestTrackingIfNeeded(prompt: prompt),
      TrackingStatus.authorized,
    );
    expect(prompt.requested, 1);
    expect(trackingAuthorised, isTrue);
  });

  test('and a standing answer is never asked for again', () async {
    // Apple shows the dialog once per install and returns the same answer
    // forever after, so a re-request on a denied device is a round trip that
    // changes nothing.
    for (final standing in [
      TrackingStatus.denied,
      TrackingStatus.authorized,
      TrackingStatus.restricted,
      TrackingStatus.notSupported,
    ]) {
      final prompt = _Prompt(standing);
      expect(await requestTrackingIfNeeded(prompt: prompt), standing);
      expect(prompt.requested, 0, reason: '$standing re-prompted');
      expect(prompt.asked, 1);
    }
  });

  test('DENIED MEANS CONTEXTUAL, not blocked', () async {
    // The ads still serve; what changes is the eCPM. A gate here would turn a
    // personalisation question into a monetisation outage.
    await requestTrackingIfNeeded(prompt: _Prompt(TrackingStatus.denied));
    expect(trackingAuthorised, isFalse);
    expect(trackingStatus, TrackingStatus.denied);
  });

  test('a plugin that throws is `notSupported` rather than a failed boot', () {
    expect(
      requestTrackingIfNeeded(prompt: _Prompt(TrackingStatus.denied, throws: true)),
      completion(TrackingStatus.notSupported),
    );
  });

  test('EVERY OUTCOME IS REPORTED, because opt-in rate explains an eCPM', () async {
    await requestTrackingIfNeeded(
      prompt: _Prompt(
        TrackingStatus.notDetermined,
        answer: TrackingStatus.authorized,
      ),
    );
    expect(sent.single.name, 'att_status');
    expect(sent.single.params['status'], 'authorized');
  });

  test('A PROMPT NOBODY ANSWERS DOES NOT STRAND THE AD STACK', () {
    // The system dialog is modal and its future does not complete until it is
    // dismissed. iOS remembers the eventual reply for the next launch.
    fakeAsync((async) {
      TrackingStatus? settled;
      requestTrackingIfNeeded(
        prompt: _Prompt(TrackingStatus.notDetermined, hangs: true),
      ).then((s) => settled = s);
      async.elapse(trackingPromptTimeout + const Duration(seconds: 1));
      expect(settled, TrackingStatus.notDetermined);
    });
  });
}
