import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/firebase_config.dart';

void main() {
  test('EVERY APP HAS ITS OWN KEY, and they are all different', () {
    // Not cosmetic: the iOS and Android keys are restricted to the bundle id
    // and the browser key by referrer, so sending the wrong one from a device
    // is a 403. The JS's own opening comment.
    final keys = {
      for (final app in FirebaseApp.values) firebaseConfigFor(app).apiKey,
    };
    expect(keys, hasLength(FirebaseApp.values.length));
    for (final app in FirebaseApp.values) {
      expect(firebaseConfigFor(app).apiKey, isNotEmpty, reason: '$app');
      expect(firebaseConfigFor(app).appId, contains(':${app.name}:'));
    }
  });

  test('and the project is shared by all three', () {
    for (final app in FirebaseApp.values) {
      final config = firebaseConfigFor(app);
      expect(config.projectId, firebaseProjectId);
      expect(config.authDomain, contains(firebaseProjectId));
      expect(config.messagingSenderId, isNotEmpty);
    }
  });

  test('ANALYTICS IS THE WEB APP ALONE', () {
    // Only the browser app has a measurement id in the console.
    expect(firebaseConfigFor(FirebaseApp.web).measurementId, isNotEmpty);
    expect(firebaseConfigFor(FirebaseApp.ios).measurementId, isNull);
    expect(firebaseConfigFor(FirebaseApp.android).measurementId, isNull);
  });
}
