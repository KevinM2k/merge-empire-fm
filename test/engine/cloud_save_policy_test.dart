import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/cloud_save_policy.dart';

Map<String, dynamic> save({
  String club = '',
  String division = 'sunday_league',
  int matches = 0,
  int seasons = 1,
  int lastSeen = 0,
  int prestige = 0,
  int merges = 0,
  List<Object?>? cells,
  Map<String, dynamic>? assets,
}) => <String, dynamic>{
  'clubName': club,
  'lastSeen': lastSeen,
  'progression': <String, dynamic>{
    'currentDivision': division,
    'matchesPlayed': matches,
    'seasonCount': seasons,
  },
  'prestige': <String, dynamic>{'level': prestige},
  'stats': <String, dynamic>{'merges': merges},
  if (cells != null) 'grid': <String, dynamic>{'cells': cells},
  'clubAssets': ?assets,
};

SaveSummary summaryOf(Map<String, dynamic>? s) =>
    saveSummaryFromState(s, fallbackClubName: 'Your Club');

void main() {
  group('the summary', () {
    test('an unnamed club falls back rather than showing a blank', () {
      expect(summaryOf(save()).clubName, 'Your Club');
      expect(summaryOf(save(club: '   ')).clubName, 'Your Club');
      expect(summaryOf(save(club: 'Borough United')).clubName, 'Borough United');
    });

    test('SEASON ONE, NOT ZERO — a fresh save has played its first', () {
      expect(summaryOf(<String, dynamic>{}).seasonCount, 1);
      expect(summaryOf(null).seasonCount, 1);
    });

    test('and a null save still summarises to the opening division', () {
      expect(summaryOf(null).divisionId, 'sunday_league');
      expect(summaryOf(null).matchesPlayed, 0);
    });
  });

  group('the fingerprint', () {
    test('IT DOES NOT INCLUDE lastSeen', () {
      // A fingerprint has to survive the same save being played a few seconds
      // further on one device, or every background upload reads as a conflict.
      final a = summaryOf(save(club: 'X', matches: 4, lastSeen: 1000));
      final b = summaryOf(save(club: 'X', matches: 4, lastSeen: 999999));
      expect(saveFingerprint(a), saveFingerprint(b));
    });

    test('but it does include each of the four fields it names', () {
      final base = summaryOf(save(club: 'X', matches: 4));
      for (final other in [
        save(club: 'Y', matches: 4),
        save(club: 'X', matches: 5),
        save(club: 'X', matches: 4, seasons: 2),
        save(club: 'X', matches: 4, division: 'league_two'),
      ]) {
        expect(
          saveFingerprint(summaryOf(other)),
          isNot(saveFingerprint(base)),
        );
      }
    });
  });

  group('has this save got anywhere', () {
    test('a fresh install has not', () {
      expect(localSaveHasProgress(save()), isFalse);
      expect(localSaveHasProgress(null), isFalse);
      expect(localSaveHasProgress(<String, dynamic>{}), isFalse);
    });

    test('and ANY ONE of these is enough', () {
      // Deliberately generous: a false negative overwrites somebody's game, a
      // false positive costs one extra prompt.
      expect(localSaveHasProgress(save(matches: 1)), isTrue);
      expect(localSaveHasProgress(save(seasons: 2)), isTrue);
      expect(localSaveHasProgress(save(division: 'league_two')), isTrue);
      expect(localSaveHasProgress(save(prestige: 1)), isTrue);
      expect(localSaveHasProgress(save(merges: 1)), isTrue);
      expect(localSaveHasProgress(save(club: 'Named')), isTrue);
      expect(
        localSaveHasProgress(save(cells: [null, <String, dynamic>{}])),
        isTrue,
      );
      expect(
        localSaveHasProgress(
          save(assets: {
            'pitch': <String, dynamic>{'owned': true},
          }),
        ),
        isTrue,
      );
    });

    test('an empty grid and an unowned asset are not progress', () {
      expect(localSaveHasProgress(save(cells: [null, null])), isFalse);
      expect(
        localSaveHasProgress(
          save(assets: {
            'pitch': <String, dynamic>{'owned': false},
          }),
        ),
        isFalse,
      );
    });
  });

  group('a rejected precondition', () {
    test('is recognised however the API spells it', () {
      for (final message in [
        'Firestore REST commit 400: FAILED_PRECONDITION',
        'the document does not match the required base version',
        'stored version does not match',
        'Precondition failed',
      ]) {
        expect(isPreconditionFailure(message), isTrue, reason: message);
      }
    });

    test('and anything else is NOT — it re-throws rather than retrying', () {
      expect(isPreconditionFailure('PERMISSION_DENIED'), isFalse);
      expect(isPreconditionFailure('SocketException'), isFalse);
    });

    test('SAME LINEAGE MEANS RETRY, NOT CONFLICT', () {
      // Treating a drifted token as a conflict froze full saves for days while
      // the leaderboard — which has no precondition — kept advancing.
      final local = summaryOf(save(club: 'X', matches: 4, lastSeen: 10));
      expect(
        reconcileStaleUpload(
          local: local,
          cloudSummary: summaryOf(save(club: 'X', matches: 4, lastSeen: 99)),
          cloudLastSeen: 99,
        ),
        StaleUploadVerdict.retry,
      );
    });

    test('so does this device being at least as recent', () {
      expect(
        reconcileStaleUpload(
          local: summaryOf(save(club: 'X', matches: 9, lastSeen: 100)),
          cloudSummary: summaryOf(save(club: 'Y', matches: 4)),
          cloudLastSeen: 100,
        ),
        StaleUploadVerdict.retry,
      );
    });

    test('a missing cloud document is safe to overwrite', () {
      expect(
        reconcileStaleUpload(
          local: summaryOf(save()),
          cloudSummary: null,
          cloudLastSeen: 0,
        ),
        StaleUploadVerdict.retry,
      );
    });

    test('but a newer divergent cloud is a CONFLICT', () {
      expect(
        reconcileStaleUpload(
          local: summaryOf(save(club: 'X', matches: 4, lastSeen: 10)),
          cloudSummary: summaryOf(save(club: 'Y', matches: 40, lastSeen: 500)),
          cloudLastSeen: 500,
        ),
        StaleUploadVerdict.conflict,
      );
    });
  });

  group('the boot decision', () {
    CloudSaveVerdict decide({
      Map<String, dynamic>? local,
      Map<String, dynamic>? cloud,
      String? priorToken,
      String? cloudUpdateTime,
    }) => decideCloudSaveAction(
      localState: local,
      local: summaryOf(local),
      cloudSummary: cloud == null ? null : summaryOf(cloud),
      cloudState: cloud,
      priorToken: priorToken,
      cloudUpdateTime: cloudUpdateTime,
    );

    test('no cloud save at all means upload', () {
      expect(decide(local: save(matches: 3)).action, CloudSaveAction.upload);
    });

    test('a cloud save that has got nowhere means upload too', () {
      expect(
        decide(local: save(matches: 3), cloud: save()).action,
        CloudSaveAction.upload,
      );
    });

    test('a fresh local against a real cloud means RESTORE', () {
      expect(
        decide(local: save(), cloud: save(club: 'X', matches: 9)).action,
        CloudSaveAction.restore,
      );
    });

    test('the same save on both sides is NONE, and takes the later lastSeen', () {
      // A restore here is a reload loop on boot; the timestamp is still the one
      // thing the other device knows that this one does not.
      final verdict = decide(
        local: save(club: 'X', matches: 9, lastSeen: 100),
        cloud: save(club: 'X', matches: 9, lastSeen: 900),
      );
      expect(verdict.action, CloudSaveAction.none);
      expect(verdict.bumpLastSeen, 900);
    });

    test('and it does not bump backwards', () {
      final verdict = decide(
        local: save(club: 'X', matches: 9, lastSeen: 900),
        cloud: save(club: 'X', matches: 9, lastSeen: 100),
      );
      expect(verdict.bumpLastSeen, 0);
    });

    test('DIVERGENT BUT THE CLOUD HAS NOT MOVED means upload, not a prompt', () {
      // Local is simply ahead — the tab closed before the debounced upload
      // flushed. Nagging here is nagging about your own save.
      expect(
        decide(
          local: save(club: 'X', matches: 12),
          cloud: save(club: 'X', matches: 9),
          priorToken: '2026-08-23T10:00:00.000Z',
          cloudUpdateTime: '2026-08-23T10:00:01.000Z',
        ).action,
        CloudSaveAction.upload,
      );
    });

    test('but a cloud that moved on another device is a CHOICE', () {
      expect(
        decide(
          local: save(club: 'X', matches: 12),
          cloud: save(club: 'Y', matches: 40),
          priorToken: '2026-08-23T10:00:00.000Z',
          cloudUpdateTime: '2026-08-23T11:00:00.000Z',
        ).action,
        CloudSaveAction.choose,
      );
    });

    test('and with no prior token there is nothing to compare, so it asks', () {
      expect(
        decide(
          local: save(club: 'X', matches: 12),
          cloud: save(club: 'Y', matches: 40),
          cloudUpdateTime: '2026-08-23T11:00:00.000Z',
        ).action,
        CloudSaveAction.choose,
      );
    });
  });

  group('a change seen on resume', () {
    test('needs to be outside the slack to count', () {
      // A write this device made comes back with an updateTime a few hundred
      // milliseconds off the token it recorded. That is not somebody else.
      expect(cloudChangedElsewhere(cloudMs: 1400, syncedMs: 0), isFalse);
      expect(cloudChangedElsewhere(cloudMs: 1500, syncedMs: 0), isFalse);
      expect(cloudChangedElsewhere(cloudMs: 1501, syncedMs: 0), isTrue);
    });

    test('and an unparseable timestamp is zero rather than a throw', () {
      expect(cloudTimestampMs(null), 0);
      expect(cloudTimestampMs(''), 0);
      expect(cloudTimestampMs('not a date'), 0);
      expect(cloudTimestampMs('1970-01-01T00:00:01Z'), 1000);
    });
  });
}
