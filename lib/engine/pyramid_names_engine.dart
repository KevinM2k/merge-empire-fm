/// Custom team names, ported from
/// `../merge-empire-fc/src/engine/pyramidNamesEngine.js`.
///
/// A team's name IS its identity everywhere — the pyramid, the fixtures, the
/// grudges, the promotion matching — so a rename is a propagation: the string is
/// rewritten in every name-keyed structure at once. That is also why names have
/// to stay unique across the whole pyramid: a duplicate corrupts the pyramid
/// shuffle's index matching, and two clubs swap histories.
///
/// The full 56-name set can be saved as a preset. Presets live in
/// `state.settings`, which a reset preserves, so a set survives New Team. They
/// apply POSITIONALLY (slot i of division d) through a temp-name pass, so a
/// shuffled or swapped set never collides with a name that is itself about to
/// move.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/util/club_name.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

List<Map<String, dynamic>> _teams(Map<String, dynamic>? pyramid, String divId) {
  final raw = pyramid?[divId];
  if (raw is! List) return const [];
  return [
    for (final t in raw)
      if (t is Map<String, dynamic>) t,
  ];
}

Map<String, dynamic>? _pyramid(Map<String, dynamic>? state) =>
    _map(_map(state?['progression'])?['leaguePyramid']);

/// Mirrors JS `Math.random()` rather than the seeded gameplay stream: this only
/// salts a preset id, and a preset is not part of anybody's match.
math.Random _rng = math.Random();

/// Swap in a reproducible stream. The preset id lands in the save, so a test
/// that wants to compare one has to be able to pin it.
void setPyramidNamesRandom(math.Random rng) => _rng = rng;

void resetPyramidNamesRandom() => _rng = math.Random();

/// Shorter than [clubNameMax] so a custom name cannot wreck a league-table row.
const int teamNameMax = 24;
const int teamNameMin = 2;
const int maxPresets = 10;

/// Every AI team name currently in the pyramid.
Set<String> allTeamNames(Map<String, dynamic>? state) {
  final names = <String>{};
  final pyramid = _pyramid(state);
  for (final div in divisions) {
    for (final team in _teams(pyramid, div.id)) {
      final name = team['name'];
      if (name is String && name.isNotEmpty) names.add(name);
    }
  }
  return names;
}

/// Why a name was refused.
enum NameRefusal { tooShort, profanity, duplicate }

/// Sanitise and validate a raw team name against length, profanity and
/// uniqueness — the pyramid's names AND the player's own club.
///
/// [current] is the name being replaced, so renaming a team to itself (a case or
/// spacing cleanup, say) passes.
({bool ok, String name, NameRefusal? reason}) validateTeamName(
  Map<String, dynamic>? state,
  Object? raw, {
  String? current,
}) {
  final name = sanitizeName(raw, teamNameMax);
  if (name.length < teamNameMin) {
    return (ok: false, name: name, reason: NameRefusal.tooShort);
  }
  if (containsProfanity(name)) {
    return (ok: false, name: name, reason: NameRefusal.profanity);
  }
  if (name != current) {
    if (allTeamNames(state).contains(name)) {
      return (ok: false, name: name, reason: NameRefusal.duplicate);
    }
    if ('${state?['clubName'] ?? ''}'.trim() == name) {
      return (ok: false, name: name, reason: NameRefusal.duplicate);
    }
  }
  return (ok: true, name: name, reason: null);
}

/// Rename a team everywhere its name is stored.
///
/// Callers validate first — this only checks the team exists. Safe mid-season:
/// the fixtures, the opponents, the grudges and an active cup run all carry the
/// new name immediately. Historical records — the season history, the cup
/// history, the fixture-result keys — are left alone on purpose.
bool renameTeam(Map<String, dynamic> state, String? oldName, String? newName) {
  if (oldName == null ||
      newName == null ||
      oldName.isEmpty ||
      newName.isEmpty ||
      oldName == newName) {
    return false;
  }
  final pyramid = _pyramid(state);

  var found = false;
  for (final div in divisions) {
    for (final team in _teams(pyramid, div.id)) {
      if (team['name'] == oldName) {
        team['name'] = newName;
        found = true;
      }
    }
  }
  if (!found) return false;

  final prog = _map(state['progression']);
  if (prog == null) return true;

  final opponents = prog['seasonOpponents'];
  if (opponents is List) {
    prog['seasonOpponents'] = [
      for (final n in opponents) n == oldName ? newName : n,
    ];
  }

  final fixtures = prog['seasonFixtures'];
  if (fixtures is List) {
    for (final raw in fixtures) {
      final fx = _map(raw);
      if (fx == null) continue;
      if (fx['homeTeam'] == oldName) fx['homeTeam'] = newName;
      if (fx['awayTeam'] == oldName) fx['awayTeam'] = newName;
    }
  }

  final positions = _map(prog['opponentTablePositions']);
  if (positions != null && positions[oldName] != null) {
    positions[newName] = positions.remove(oldName);
  }

  // The last season's promotion and relegation badges are name-keyed too, and a
  // rename that skipped them would drop the chip off the renamed club's row.
  final lastStatus = _map(_map(prog['lastSeasonStatus'])?['teams']);
  if (lastStatus != null && lastStatus[oldName] != null) {
    lastStatus[newName] = lastStatus.remove(oldName);
  }

  final lastResult = _map(prog['lastMatchResult']);
  if (lastResult != null && lastResult['opponentName'] == oldName) {
    lastResult['opponentName'] = newName;
  }

  final run = _map(_map(prog['cups'])?['active']);
  if (run != null) {
    final runOpponents = run['opponents'];
    if (runOpponents is List) {
      run['opponents'] = [
        for (final n in runOpponents) n == oldName ? newName : n,
      ];
    }
    final results = run['results'];
    if (results is List) {
      for (final raw in results) {
        final r = _map(raw);
        if (r != null && r['opponentName'] == oldName) {
          r['opponentName'] = newName;
        }
      }
    }
    // Scout-report blurbs embed the name in prose.
    final contexts = run['contexts'];
    if (contexts is List) {
      run['contexts'] = [
        for (final c in contexts)
          if (c is String) c.split(oldName).join(newName) else c,
      ];
    }
  }

  final market = _map(state['transferMarket']);
  if (market != null) {
    final pending = _map(market['pendingOffer']);
    if (pending != null && pending['fromTeam'] == oldName) {
      pending['fromTeam'] = newName;
    }
    final grudges = _map(market['grudges']);
    if (grudges != null && grudges[oldName] != null) {
      grudges[newName] = grudges.remove(oldName);
    }
  }

  return true;
}

/// One positional rename request: slot [index] of division [divId].
typedef NameAssignment = ({String divId, int index, String name});

/// A request that was refused, and why.
typedef SkippedAssignment = ({
  String divId,
  int index,
  String name,
  NameRefusal reason,
});

typedef ApplyResult = ({int applied, List<SkippedAssignment> skipped});

/// Apply a positional name assignment.
///
/// Two-phase: every affected team is first parked on a unique temp name, so a
/// shuffled or swapped set — common when re-applying a preset after a few
/// seasons of promotion and relegation — never collides with a name that is
/// itself about to move.
ApplyResult _applyAssignments(
  Map<String, dynamic> state,
  List<NameAssignment> entries,
) {
  final pyramid = _pyramid(state);
  final skipped = <SkippedAssignment>[];
  final targets = <String>{};
  final assignments = <({String from, String to})>[];

  Map<String, dynamic>? teamAt(String divId, int index) {
    final teams = _teams(pyramid, divId);
    return index >= 0 && index < teams.length ? teams[index] : null;
  }

  // The names of teams NOT being reassigned keep their spot, so a target
  // colliding with one of those is a genuine conflict rather than a swap.
  final movingCurrent = <String>{};
  for (final e in entries) {
    final name = teamAt(e.divId, e.index)?['name'];
    if (name is String && name.isNotEmpty) movingCurrent.add(name);
  }
  final stayingNames = allTeamNames(state)..removeWhere(movingCurrent.contains);

  for (final e in entries) {
    final team = teamAt(e.divId, e.index);
    final currentName = team?['name'];
    if (currentName is! String || currentName.isEmpty) continue;
    final name = sanitizeName(e.name, teamNameMax);
    if (name == currentName) continue; // unchanged
    if (name.length < teamNameMin) {
      skipped.add((
        divId: e.divId,
        index: e.index,
        name: name,
        reason: NameRefusal.tooShort,
      ));
      continue;
    }
    if (containsProfanity(name)) {
      skipped.add((
        divId: e.divId,
        index: e.index,
        name: name,
        reason: NameRefusal.profanity,
      ));
      continue;
    }
    if (targets.contains(name) ||
        stayingNames.contains(name) ||
        '${state['clubName'] ?? ''}'.trim() == name) {
      skipped.add((
        divId: e.divId,
        index: e.index,
        name: name,
        reason: NameRefusal.duplicate,
      ));
      continue;
    }
    targets.add(name);
    assignments.add((from: currentName, to: name));
  }

  // Phase 1: park every moving team on a temp name, sanitiser-proof and unique.
  final temps = <String>[];
  for (var i = 0; i < assignments.length; i++) {
    final tmp =
        'zz-tmp-$i-${assignments[i].to.substring(0, math.min(8, assignments[i].to.length))}';
    temps.add(tmp);
    renameTeam(state, assignments[i].from, tmp);
  }
  // Phase 2: land on the real targets.
  for (var i = 0; i < assignments.length; i++) {
    renameTeam(state, temps[i], assignments[i].to);
  }

  return (applied: assignments.length, skipped: skipped);
}

/// Bulk-edit one division from a list of lines — the "edit as list" textarea.
///
/// Line i renames team i; a blank line keeps the current name.
ApplyResult applyNameList(
  Map<String, dynamic> state,
  String divId,
  List<Object?>? lines,
) {
  final entries = <NameAssignment>[];
  final list = lines ?? const [];
  for (var index = 0; index < list.length; index++) {
    final raw = '${list[index] ?? ''}'.trim();
    if (raw.isNotEmpty) {
      entries.add((divId: divId, index: index, name: raw));
    }
  }
  return _applyAssignments(state, entries);
}

// ── Presets ─────────────────────────────────────────────────────────────────
//
// `state.settings.customPyramids` holds
// `[{ id, label, createdAt, names: { divId: [8 names] } }]`.

List<dynamic> _presets(Map<String, dynamic> state) {
  var settings = _map(state['settings']);
  if (settings == null) {
    settings = <String, dynamic>{};
    state['settings'] = settings;
  }
  final existing = settings['customPyramids'];
  if (existing is List) return existing;
  final fresh = <dynamic>[];
  settings['customPyramids'] = fresh;
  return fresh;
}

List<dynamic> listPresets(Map<String, dynamic> state) => _presets(state);

/// Why a preset could not be saved.
enum PresetRefusal { label, full, parse }

String _presetId() => 'pyr_${now()}_${(_rng.nextDouble() * 1e6).floor()}';

/// Snapshot the current pyramid's names as a preset.
///
/// A label matching an existing preset overwrites it; otherwise it appends, up
/// to [maxPresets].
({bool ok, Map<String, dynamic>? preset, PresetRefusal? reason}) savePreset(
  Map<String, dynamic> state,
  Object? rawLabel,
) {
  final label = sanitizeName(rawLabel, 30);
  if (label.isEmpty) {
    return (ok: false, preset: null, reason: PresetRefusal.label);
  }

  final pyramid = _pyramid(state);
  final names = <String, dynamic>{
    for (final div in divisions)
      div.id: [for (final t in _teams(pyramid, div.id)) t['name'] ?? ''],
  };

  return _storePreset(state, label, names);
}

/// Overwrite the preset carrying [label], or append a new one.
({bool ok, Map<String, dynamic>? preset, PresetRefusal? reason}) _storePreset(
  Map<String, dynamic> state,
  String label,
  Map<String, dynamic> names,
) {
  final presets = _presets(state);
  for (final raw in presets) {
    final existing = _map(raw);
    if (existing != null && existing['label'] == label) {
      existing['names'] = names;
      existing['createdAt'] = now();
      return (ok: true, preset: existing, reason: null);
    }
  }
  if (presets.length >= maxPresets) {
    return (ok: false, preset: null, reason: PresetRefusal.full);
  }
  final preset = <String, dynamic>{
    'id': _presetId(),
    'label': label,
    'createdAt': now(),
    'names': names,
  };
  presets.add(preset);
  return (ok: true, preset: preset, reason: null);
}

bool deletePreset(Map<String, dynamic> state, Object? presetId) {
  final presets = _presets(state);
  final idx = presets.indexWhere((p) => _map(p)?['id'] == presetId);
  if (idx >= 0) presets.removeAt(idx);
  return idx >= 0;
}

/// Apply a preset positionally across the whole pyramid.
///
/// Tolerates shape drift: a division missing from the preset, or a list shorter
/// or longer than the live league, just leaves the extra slots on their current
/// names.
ApplyResult applyPreset(Map<String, dynamic> state, Object? presetId) {
  final preset = _map(
    _presets(
      state,
    ).firstWhere((p) => _map(p)?['id'] == presetId, orElse: () => null),
  );
  if (preset == null) return (applied: 0, skipped: const []);

  final pyramid = _pyramid(state);
  final presetNames = _map(preset['names']);
  final entries = <NameAssignment>[];
  for (final div in divisions) {
    final list = presetNames?[div.id];
    if (list is! List) continue;
    final teams = _teams(pyramid, div.id);
    final count = math.min(list.length, teams.length);
    for (var i = 0; i < count; i++) {
      final raw = '${list[i] ?? ''}'.trim();
      if (raw.isNotEmpty) entries.add((divId: div.id, index: i, name: raw));
    }
  }
  return _applyAssignments(state, entries);
}

// ── Text export and import ──────────────────────────────────────────────────
//
// One `[division_id]` header per section, then one name per line. Division IDS
// rather than display names, so the text is locale-proof and a set shared
// between two players in different languages still lands in the right league.

String exportPresetText(Map<String, dynamic>? preset) {
  final presetNames = _map(preset?['names']);
  final lines = <String>[];
  for (final div in divisions) {
    final names = presetNames?[div.id];
    if (names is! List) continue;
    if (!names.any((n) => n != null && '$n'.isNotEmpty)) continue;
    lines.add('[${div.id}]');
    for (final n in names) {
      lines.add(n == null ? '' : '$n');
    }
  }
  return lines.join('\n');
}

final RegExp _headerPattern = RegExp(r'^\[([a-z_]+)\]$');

/// Parse exported text back into a names map. Unknown sections are ignored.
Map<String, dynamic>? parsePresetText(Object? text) {
  final known = {for (final d in divisions) d.id};
  final names = <String, dynamic>{};
  String? current;
  var any = false;
  for (final rawLine in '${text ?? ''}'.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    final header = _headerPattern.firstMatch(line);
    if (header != null) {
      current = known.contains(header.group(1)) ? header.group(1) : null;
      if (current != null) names.putIfAbsent(current, () => <dynamic>[]);
      continue;
    }
    if (current == null) continue;
    (names[current] as List).add(line);
    if (line.isNotEmpty) any = true;
  }
  return any ? names : null;
}

/// Import shared or backed-up text as a new preset.
///
/// Names are sanitised here; profanity and duplicate screening happen at apply
/// time, like any other preset.
({bool ok, Map<String, dynamic>? preset, PresetRefusal? reason})
importPresetText(Map<String, dynamic> state, Object? text, Object? rawLabel) {
  final parsed = parsePresetText(text);
  if (parsed == null) {
    return (ok: false, preset: null, reason: PresetRefusal.parse);
  }
  for (final divId in parsed.keys) {
    parsed[divId] = [
      for (final n in parsed[divId] as List) sanitizeName(n, teamNameMax),
    ];
  }
  final label = sanitizeName(rawLabel, 30);
  if (label.isEmpty) {
    return (ok: false, preset: null, reason: PresetRefusal.label);
  }
  return _storePreset(state, label, parsed);
}
