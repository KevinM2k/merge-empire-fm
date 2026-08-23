import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/firestore_codec.dart';

void main() {
  group('decoding a typed value', () {
    test('AN INTEGER ARRIVES AS A STRING and comes back an int', () {
      // Firestore's JSON mapping stringifies int64 so the value survives a
      // JavaScript number. A caller must never see the string.
      expect(decodeFirestoreValue({'integerValue': '4200000000'}), 4200000000);
      expect(decodeFirestoreValue({'integerValue': 17}), 17);
    });

    test('the other scalars', () {
      expect(decodeFirestoreValue({'stringValue': 'Colin'}), 'Colin');
      expect(decodeFirestoreValue({'doubleValue': 1.5}), 1.5);
      expect(decodeFirestoreValue({'booleanValue': true}), isTrue);
      expect(decodeFirestoreValue({'nullValue': null}), isNull);
      expect(
        decodeFirestoreValue({'timestampValue': '2026-08-23T10:00:00Z'}),
        '2026-08-23T10:00:00Z',
      );
    });

    test('and anything else is null rather than half-decoded', () {
      // Nested objects are stored as JSON STRINGS, so a real map arriving here
      // means the document was not written by this game.
      expect(decodeFirestoreValue({'mapValue': <String, Object?>{}}), isNull);
      expect(decodeFirestoreValue({'arrayValue': <Object?>[]}), isNull);
      expect(decodeFirestoreValue('bare'), isNull);
      expect(decodeFirestoreValue(null), isNull);
    });
  });

  group('decoding a document', () {
    test('the id is the last path segment', () {
      final doc = decodeFirestoreDocument({
        'name':
            'projects/merge-empire-fc/databases/(default)/documents/'
            'leaderboards/global/alltime/points/entries/uid-77',
        'fields': {
          'score': {'integerValue': '9001'},
          'name': {'stringValue': 'Borough United'},
        },
        'updateTime': '2026-08-23T10:00:00.123456Z',
      })!;
      expect(doc.id, 'uid-77');
      expect(doc.data['score'], 9001);
      expect(doc.data['name'], 'Borough United');
      expect(doc.updateTime, '2026-08-23T10:00:00.123456Z');
    });

    test('updatedAt becomes MILLISECONDS, not a wrapper', () {
      final doc = decodeFirestoreDocument({
        'name': 'projects/p/databases/(default)/documents/c/d',
        'fields': {
          'updatedAt': {'timestampValue': '1970-01-01T00:00:10.000Z'},
        },
      })!;
      expect(doc.data['updatedAt'], 10000);
    });

    test('a response with no name is not a document', () {
      expect(decodeFirestoreDocument(null), isNull);
      expect(decodeFirestoreDocument(<String, Object?>{}), isNull);
      expect(decodeFirestoreDocument({'fields': <String, Object?>{}}), isNull);
    });

    test('a document with no fields decodes to an empty map', () {
      final doc = decodeFirestoreDocument({
        'name': 'projects/p/databases/(default)/documents/c/only-a-name',
      })!;
      expect(doc.id, 'only-a-name');
      expect(doc.data, isEmpty);
      expect(doc.updateTime, isNull);
    });
  });

  group('encoding', () {
    test('A WHOLE DOUBLE IS WRITTEN AS AN INTEGER', () {
      // The JS branches on `Number.isInteger`, and a Dart double holding 3.0
      // has to take the same branch or the two clients disagree about the TYPE
      // of a field they both write.
      expect(encodeFirestoreValue(3.0), {'integerValue': '3'});
      expect(encodeFirestoreValue(3), {'integerValue': '3'});
      expect(encodeFirestoreValue(3.5), {'doubleValue': 3.5});
    });

    test('the rest of the scalars', () {
      expect(encodeFirestoreValue(null), {'nullValue': null});
      expect(encodeFirestoreValue(false), {'booleanValue': false});
      expect(encodeFirestoreValue('hi'), {'stringValue': 'hi'});
    });

    test('and anything that is not a scalar is stringified, never thrown', () {
      // A background write must not take the app down because a field was the
      // wrong shape — the JS's last branch is `String(v)`.
      expect(encodeFirestoreValue([1, 2]), {'stringValue': '[1, 2]'});
    });

    test('infinity is a double, because it is not a whole number', () {
      expect(encodeFirestoreValue(double.infinity), {
        'doubleValue': double.infinity,
      });
    });
  });

  group('building a write', () {
    test('merge adds the updateMask that makes it a PATCH', () {
      final write = buildFirestoreWrite(
        'projects/p/databases/(default)/documents/c/d',
        set: {'score': 10, 'name': 'X'},
      );
      expect(
        (write['updateMask'] as Map)['fieldPaths'],
        ['score', 'name'],
        reason: 'without it the write REPLACES the row',
      );
    });

    test('and without merge there is no mask at all', () {
      final write = buildFirestoreWrite('n', set: {'score': 10}, merge: false);
      expect(write.containsKey('updateMask'), isFalse);
    });

    test('increments and server timestamps are TRANSFORMS', () {
      final write = buildFirestoreWrite(
        'n',
        set: {'name': 'X'},
        increment: {'plays': 1, 'ratio': 0.5},
        serverTimestamps: ['updatedAt'],
      );
      expect(write['updateTransforms'], [
        {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
        {
          'fieldPath': 'plays',
          'increment': {'integerValue': '1'},
        },
        {
          'fieldPath': 'ratio',
          'increment': {'doubleValue': 0.5},
        },
      ]);
    });

    test('no transforms means the key is absent, not empty', () {
      final write = buildFirestoreWrite('n', set: {'a': 1});
      expect(write.containsKey('updateTransforms'), isFalse);
    });

    test('the two preconditions, and mustNotExist WINS', () {
      expect(buildFirestoreWrite('n', mustNotExist: true)['currentDocument'], {
        'exists': false,
      });
      expect(buildFirestoreWrite('n', ifUpdateTime: 'T')['currentDocument'], {
        'updateTime': 'T',
      });
      expect(
        buildFirestoreWrite(
          'n',
          mustNotExist: true,
          ifUpdateTime: 'T',
        )['currentDocument'],
        {'exists': false},
        reason: "claiming a name outranks 'still as I left it'",
      );
      expect(buildFirestoreWrite('n').containsKey('currentDocument'), isFalse);
    });
  });

  group('the error body', () {
    test('RUNQUERY STREAMS ITS ERROR BACK AS A ONE-ELEMENT ARRAY', () {
      // The shape nothing else uses, and the one that matters most: a query
      // that fails on permissions comes back like this with a 200.
      expect(
        firestoreErrorBody([
          {
            'error': {'message': 'Missing or insufficient permissions.'},
          },
        ]),
        'Missing or insufficient permissions.',
      );
    });

    test('an object error, a string body and a raw fallback', () {
      expect(
        firestoreErrorBody({
          'error': {'message': 'PERMISSION_DENIED'},
        }),
        'PERMISSION_DENIED',
      );
      expect(firestoreErrorBody('plain text'), 'plain text');
      expect(firestoreErrorBody(null, 'raw'), 'raw');
      expect(firestoreErrorBody(null), '');
    });

    test('and it is clipped to 200 characters', () {
      expect(firestoreErrorBody('x' * 500).length, 200);
    });

    test('an empty array does not throw', () {
      expect(firestoreErrorBody(<Object?>[]), '');
    });
  });
}
