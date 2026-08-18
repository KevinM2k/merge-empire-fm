/// The save-slot policy: which stored copy boot trusts, in what order, and what
/// it does about the one that failed.
///
/// This is the half of the JS `storage.js` that was not `migrate()`. It is
/// load-bearing rather than incidental — the mirror exists because a process
/// killed mid-write leaves a truncated primary save, and without it boot falls
/// back to a fresh default and wipes the player's progress. So the ladder is
/// tested at every rung, including the two ways it can be asked to run on
/// identical bytes twice.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/save_slots.dart';

/// A parse-and-migrate stand-in: anything that is valid JSON carrying a version
/// this build understands loads, and everything else comes back null.
Map<String, dynamic>? _parse(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final version = decoded['version'];
    // A save from a NEWER build is unreadable, the same as corrupt JSON — and
    // that is the case the one-time backup exists for.
    if (version is int && version > 7) return null;
    return decoded;
  } on FormatException {
    return null;
  }
}

String _save(String label, {int version = 7}) =>
    jsonEncode({'version': version, 'label': label});

void main() {
  test('the keys are the ones the old build wrote', () {
    // A player upgrading has bytes under these exact names, so they are not
    // free to change.
    expect(saveKeyPrimary, 'mergeEmpireFC_save');
    expect(saveKeyLastGood, 'mergeEmpireFC_save_lastgood');
    expect(saveKeyBackup, 'mergeEmpireFC_save_backup');
    expect(resetPendingKey, 'mergeEmpireFC_resetPending');
  });

  group('the reset flag', () {
    test('reads the two words it knows', () {
      expect(parseResetPending('soft'), ResetMode.soft);
      expect(parseResetPending('full'), ResetMode.full);
      expect(resetModeName(ResetMode.soft), 'soft');
      expect(resetModeName(ResetMode.full), 'full');
    });

    test('anything else is no flag at all', () {
      // A half-written value must not send a boot down the force-overwrite
      // path, which would push a fresh save over a good cloud one.
      for (final raw in [null, '', 'SOFT', 'partial', 'true', '1']) {
        expect(parseResetPending(raw), isNull, reason: '$raw');
      }
    });
  });

  group('the recovery ladder', () {
    test('the primary wins when it loads', () {
      final r = recoverSave(
        primary: _save('primary'),
        lastGood: _save('mirror'),
        backup: _save('backup'),
        parse: _parse,
      );
      expect(r.save!['label'], 'primary');
      expect(r.recovered, isFalse);
      expect(r.bootedOnDefault, isFalse);
      expect(r.stashBackup, isNull);
    });

    test('a truncated primary falls through to the mirror', () {
      // The case the mirror exists for: a process killed mid-write.
      final truncated = '{"version":7,"label":"prim';
      final r = recoverSave(
        primary: truncated,
        lastGood: _save('mirror'),
        backup: null,
        parse: _parse,
      );
      expect(r.save!['label'], 'mirror');
      expect(r.recovered, isTrue);
      expect(r.bootedOnDefault, isFalse);
      // Nothing is stashed, and that is right rather than an oversight: the
      // mirror only wins when the primary is corrupt BYTES, and those carry
      // nothing the mirror does not already have. The case the stash exists for
      // — a save from a newer build — poisons both slots at once, because they
      // are written together.
      expect(r.stashBackup, isNull);
    });

    test('a save from a newer build is stashed, not discarded', () {
      final fromTheFuture = _save('future', version: 99);
      final r = recoverSave(
        primary: fromTheFuture,
        lastGood: null,
        backup: null,
        parse: _parse,
      );
      expect(r.save, isNull);
      expect(r.bootedOnDefault, isTrue);
      expect(r.stashBackup, fromTheFuture);
    });

    test('the backup becomes recoverable once the build catches up', () {
      // Which is the whole point of keeping it: a build that could not read it
      // yesterday can read it today.
      final r = recoverSave(
        primary: 'not json at all',
        lastGood: null,
        backup: _save('stashed'),
        parse: _parse,
      );
      expect(r.save!['label'], 'stashed');
      expect(r.recovered, isTrue);
      expect(r.stashBackup, 'not json at all');
    });

    test('a fallback holding the same bytes is skipped', () {
      // It can only fail the same way, and re-parsing it would be work for
      // nothing on the boot path.
      var parses = 0;
      final bad = 'not json at all';
      final r = recoverSave(
        primary: bad,
        lastGood: bad,
        backup: bad,
        parse: (raw) {
          parses++;
          return _parse(raw);
        },
      );
      expect(parses, 1);
      expect(r.save, isNull);
      expect(r.bootedOnDefault, isTrue);
      expect(r.stashBackup, bad);
    });

    test('nothing stored at all is a new player, not a recovery', () {
      final r = recoverSave(
        primary: null,
        lastGood: null,
        backup: null,
        parse: _parse,
      );
      expect(r.save, isNull);
      expect(r.recovered, isFalse);
      expect(r.bootedOnDefault, isTrue);
      // Nothing to preserve, so nothing is written — a fresh install must not
      // leave a backup slot behind it.
      expect(r.stashBackup, isNull);
    });

    test('a good primary never stashes a backup', () {
      // The stash is one-time and the caller writes it only if it is absent, so
      // a spurious one here would shadow a genuinely unreadable save later.
      for (final lastGood in [null, _save('mirror'), 'corrupt']) {
        final r = recoverSave(
          primary: _save('primary'),
          lastGood: lastGood,
          backup: 'corrupt too',
          parse: _parse,
        );
        expect(r.stashBackup, isNull, reason: '$lastGood');
      }
    });

    test('the mirror is preferred to the backup', () {
      // Trust order, not availability order: the mirror is a copy of the live
      // save and the backup is by definition one this build could not read.
      final r = recoverSave(
        primary: 'corrupt',
        lastGood: _save('mirror'),
        backup: _save('stashed'),
        parse: _parse,
      );
      expect(r.save!['label'], 'mirror');
    });

    test('a corrupt mirror does not stop the backup being tried', () {
      final r = recoverSave(
        primary: 'corrupt',
        lastGood: 'corrupt mirror',
        backup: _save('stashed'),
        parse: _parse,
      );
      expect(r.save!['label'], 'stashed');
      expect(r.recovered, isTrue);
      expect(r.stashBackup, 'corrupt');
    });

    test('a save that migrates to nothing is treated as unreadable', () {
      // `migrate` returns null for a structurally corrupt save, and the ladder
      // has to read that as "try the next slot" rather than "run on null".
      final r = recoverSave(
        primary: _save('primary'),
        lastGood: _save('mirror'),
        backup: null,
        parse: (raw) => raw.contains('primary') ? null : _parse(raw),
      );
      expect(r.save!['label'], 'mirror');
      expect(r.recovered, isTrue);
    });
  });
}
