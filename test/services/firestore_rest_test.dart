import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/services/firestore_rest.dart';

/// Every call the transport made, so a test can assert on the URL and the body
/// rather than only on the answer.
late List<({String method, Uri url, Map<String, String> headers, Object? body})>
sent;

void reply(int status, Object? data, {String? rawText}) {
  firestoreSend = (method, url, headers, body) async {
    sent.add((method: method, url: url, headers: headers, body: body));
    return (status: status, data: data, rawText: rawText);
  };
}

void main() {
  setUp(() {
    sent = [];
    resetFirestoreSeams();
  });

  tearDown(resetFirestoreSeams);

  group('getting a document', () {
    test('the URL carries the project, the path and the key', () async {
      reply(200, {
        'name': 'projects/merge-empire-fc/databases/(default)/documents/a/b',
        'fields': {
          'score': {'integerValue': '5'},
        },
      });
      final doc = await restGetDocument('a/b');
      expect(doc!.data['score'], 5);
      expect(
        sent.single.url.path,
        '/v1/projects/merge-empire-fc/databases/(default)/documents/a/b',
      );
      expect(sent.single.url.queryParameters['key'], isNotEmpty);
      expect(sent.single.method, 'GET');
    });

    test('A 404 IS NULL, not a throw', () async {
      // A missing document is an answer. Every caller in the JS treats it so.
      reply(404, null);
      expect(await restGetDocument('a/b'), isNull);
    });

    test('and anything else throws with the server\'s own words', () async {
      reply(403, {
        'error': {'message': 'PERMISSION_DENIED'},
      });
      await expectLater(
        restGetDocument('a/b'),
        throwsA(
          isA<FirestoreRestException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.detail, 'detail', 'PERMISSION_DENIED'),
        ),
      );
    });
  });

  group('the headers', () {
    test('no token is the NORMAL case, and sends no Authorization', () async {
      // The JS's own note: leaderboard reads are public (rules: read if true).
      reply(200, null);
      await restGetDocument('a/b');
      expect(sent.single.headers.containsKey('Authorization'), isFalse);
      expect(sent.single.headers['X-Ios-Bundle-Identifier'], isNotEmpty);
    });

    test('a token becomes a bearer', () async {
      firestoreAuthToken = () async => 'tok';
      reply(200, null);
      await restGetDocument('a/b');
      expect(sent.single.headers['Authorization'], 'Bearer tok');
    });

    test('and a token source that THROWS is the same as no token', () async {
      firestoreAuthToken = () async => throw StateError('auth gone');
      reply(200, null);
      await restGetDocument('a/b');
      expect(sent.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('listing', () {
    test('the order and the page size go on the query string', () async {
      reply(200, {'documents': <Object?>[], 'nextPageToken': 'next'});
      final page = await restListDocuments(
        'l/g/a/points/entries',
        orderBy: 'score desc',
        pageSize: 25,
      );
      expect(page.nextPageToken, 'next');
      expect(sent.single.url.queryParameters['orderBy'], 'score desc');
      expect(sent.single.url.queryParameters['pageSize'], '25');
    });

    test('a 404 is an EMPTY PAGE, not a throw', () async {
      reply(404, null);
      final page = await restListDocuments('nope');
      expect(page.docs, isEmpty);
      expect(page.nextPageToken, isNull);
    });

    test('and rows that will not decode are dropped rather than crashing', () async {
      reply(200, {
        'documents': [
          {'name': 'projects/p/databases/(default)/documents/c/keep'},
          {'no': 'name'},
        ],
      });
      final page = await restListDocuments('c');
      expect(page.docs.map((d) => d.id), ['keep']);
    });
  });

  group('runQuery', () {
    test('an empty parent queries from the database ROOT', () async {
      // The only form that returns rows for a collection-group query here.
      reply(200, <Object?>[]);
      await restRunQuery('', {'from': <Object?>[]});
      expect(
        (sent.single.body as Map)['parent'],
        'projects/merge-empire-fc/databases/(default)/documents',
      );
    });

    test('and a parent path is resolved to a document name', () async {
      reply(200, <Object?>[]);
      await restRunQuery('l/g/a/points', {'from': <Object?>[]});
      expect(
        (sent.single.body as Map)['parent'],
        'projects/merge-empire-fc/databases/(default)/documents/l/g/a/points',
      );
    });

    test('A 200 CAN STILL BE AN ERROR — it streams one back in an array', () async {
      reply(200, [
        {
          'error': {'message': 'Missing or insufficient permissions.'},
        },
      ]);
      await expectLater(
        restRunQuery('', const {}),
        throwsA(
          isA<FirestoreRestException>().having(
            (e) => e.detail,
            'detail',
            'Missing or insufficient permissions.',
          ),
        ),
      );
    });

    test('rows come back unwrapped from their document envelope', () async {
      reply(200, [
        {
          'document': {
            'name': 'projects/p/databases/(default)/documents/c/one',
            'fields': {
              'n': {'integerValue': '1'},
            },
          },
        },
        // A read-time-only row with no document in it: the API sends these and
        // they are not results.
        {'readTime': '2026-01-01T00:00:00Z'},
      ]);
      final docs = await restRunQuery('', const {});
      expect(docs.map((d) => d.id), ['one']);
    });

    test('a body that is not a list at all is no rows', () async {
      reply(200, {'unexpected': true});
      expect(await restRunQuery('', const {}), isEmpty);
    });
  });

  group('committing', () {
    test('one write goes through the batch path', () async {
      reply(200, {});
      await restCommitWrite('c/d', set: {'score': 7}, increment: {'plays': 1});
      final writes = ((sent.single.body as Map)['writes'] as List).single as Map;
      expect(
        (writes['update'] as Map)['name'],
        'projects/merge-empire-fc/databases/(default)/documents/c/d',
      );
      expect((writes['updateMask'] as Map)['fieldPaths'], ['score']);
      expect(writes['updateTransforms'], hasLength(1));
    });

    test('AND 501 WRITES BECOME TWO ROUND TRIPS', () async {
      // Firestore's own limit is 500 a commit; the batching is the difference
      // between one request and five hundred on a flaky connection.
      reply(200, {});
      await restCommitWrites([
        for (var i = 0; i < 501; i++)
          (
            docPath: 'c/$i',
            set: <String, Object?>{'n': i},
            increment: const <String, num>{},
            serverTimestamps: const <String>[],
            merge: true,
            mustNotExist: false,
            ifUpdateTime: null,
          ),
      ]);
      expect(sent, hasLength(2));
      expect(((sent[0].body as Map)['writes'] as List), hasLength(500));
      expect(((sent[1].body as Map)['writes'] as List), hasLength(1));
    });

    test('nothing to write is no request at all', () async {
      reply(200, {});
      await restCommitWrites(const []);
      expect(sent, isEmpty);
    });

    test('a failed commit throws', () async {
      reply(400, {
        'error': {'message': 'invalid'},
      });
      await expectLater(
        restCommitWrite('c/d', set: {'a': 1}),
        throwsA(isA<FirestoreRestException>()),
      );
    });
  });

  group('deleting', () {
    test('A 404 IS A SUCCESS — the outcome asked for already holds', () async {
      reply(404, null);
      await restDeleteDocument('c/gone');
      expect(sent.single.method, 'DELETE');
    });

    test('but a 500 is not', () async {
      reply(500, null, rawText: 'boom');
      await expectLater(
        restDeleteDocument('c/d'),
        throwsA(isA<FirestoreRestException>()),
      );
    });

    test('a batch delete sends delete writes, in batches', () async {
      reply(200, {});
      await restCommitDeletes([for (var i = 0; i < 501; i++) 'c/$i']);
      expect(sent, hasLength(2));
      final first = ((sent[0].body as Map)['writes'] as List).first as Map;
      expect(
        first['delete'],
        'projects/merge-empire-fc/databases/(default)/documents/c/0',
      );
    });
  });
}
