/// The Firebase project's own identifiers, ported from
/// `../merge-empire-fc/src/services/firebase.js`.
///
/// **Firebase issues one API key PER REGISTERED APP**, and which one a request
/// carries is not cosmetic: the iOS and Android keys are restricted to the
/// bundle id and the browser key is restricted by referrer, so sending the web
/// key from a device is a 403. That is the JS's own opening comment, and it is
/// the whole reason this table exists rather than one constant.
///
/// **What is NOT ported, and why.** The rest of `firebase.js` is a lazy
/// singleton around the Firebase JS SDK and a Firestore instance with two
/// WebView workarounds on it — forced long polling, `useFetchStreams: false`.
/// The port reaches Firestore over plain HTTPS (`services/firestore_rest.dart`)
/// precisely because that transport is the thing that fails in a native
/// WebView, so porting the workarounds would be porting the cure for an illness
/// this build does not have. The same call the coach's ref-counted suppression
/// got.
///
/// Deliberately Flutter-free, and it does not ask what platform it is on: it is
/// a table, and the caller says which row it wants. That is what lets all three
/// rows be tested from plain `dart test`.
library;

/// Which registered app a request is coming from.
enum FirebaseApp { web, ios, android }

/// One app's identifiers.
typedef FirebaseConfig = ({
  String apiKey,
  String appId,
  String authDomain,
  String projectId,
  String storageBucket,
  String messagingSenderId,

  /// Analytics, and only the web app has one.
  String? measurementId,
});

/// Shared by all three registered apps.
const String firebaseProjectId = 'merge-empire-fc';
const String _authDomain = 'merge-empire-fc.firebaseapp.com';
const String _storageBucket = 'merge-empire-fc.firebasestorage.app';
const String _messagingSenderId = '500974365483';

/// The per-app keys, from the Firebase console. The JS carries the same three.
const Map<FirebaseApp, (String key, String appId)> _apps = {
  FirebaseApp.web: (
    'AIzaSyA1jsF17_Q-wHESG0MqagAuEbDyjqoB5HQ',
    '1:500974365483:web:71d291492377a24506f36e',
  ),
  FirebaseApp.ios: (
    'AIzaSyAANuyjxLOqP65Herkt3wlRmfYCOljyxZM',
    '1:500974365483:ios:fe290c1253f4a8da06f36e',
  ),
  FirebaseApp.android: (
    'AIzaSyApKBesagIiA42AQU49S82SARwKhW5psN8',
    '1:500974365483:android:df104205b5442dc306f36e',
  ),
};

/// The config for one registered app.
///
/// **It falls back to the WEB row rather than to nothing**, which is the JS's
/// behaviour and the right one: a missing native key is a build that cannot
/// reach Firebase at all, and the browser key at least works everywhere the
/// referrer restriction is not enforced. The JS logs a warning at that point;
/// here the caller can compare against [FirebaseApp.web] if it wants to.
FirebaseConfig firebaseConfigFor(FirebaseApp app) {
  final (key, appId) = _apps[app] ?? _apps[FirebaseApp.web]!;
  return (
    apiKey: key,
    appId: appId,
    authDomain: _authDomain,
    projectId: firebaseProjectId,
    storageBucket: _storageBucket,
    messagingSenderId: _messagingSenderId,
    measurementId: app == FirebaseApp.web ? 'G-32J7EDZMSM' : null,
  );
}
