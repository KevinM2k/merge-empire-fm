/// Team Names — the pyramid editor. Ported from
/// `../merge-empire-fc/src/ui/components/PyramidEditor.js`.
///
/// **The whole engine was here and nothing called it.** `pyramid_names_engine`
/// is five hundred lines — validation, renaming across the fixtures and the
/// grudges and a live cup run, bulk list editing, presets, export and import —
/// ported, tested against a fixture, and reachable from nowhere. The Settings
/// row for it was a `PendingControl` saying "coming soon". Twenty-five
/// `pyramid.*` strings sat translated in all ten catalogues with nothing able to
/// reach one. That is the sixth engine in this port found in that state.
///
/// Three things it does, in the JS's own order:
///
/// 1. **Rename one club.** Tap a row, type, commit. Validation is the engine's:
///    length, profanity, and uniqueness against every other AI name AND the
///    player's own club.
/// 2. **Edit a whole division as a list.** Fourteen names in a textarea, one per
///    line — because renaming fourteen clubs one at a time is not editing, it is
///    data entry. A blank line keeps the current name.
/// 3. **Presets.** Save the whole fifty-six-name pyramid, load one back, and
///    export or import it as text so it can be shared. They live in `settings`,
///    so they survive a New Team.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/pyramid_names_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart'
    show mouldedButtonStyle;
import 'package:merge_empire_fc/util/event_bus.dart';

Future<void> showPyramidEditor(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.92,
      child: const PyramidEditor(),
    );

/// Why a name was refused, in the catalogue's words.
String refusalKey(NameRefusal reason) => switch (reason) {
  NameRefusal.tooShort => 'pyramid.err_too_short',
  NameRefusal.profanity => 'pyramid.err_profanity',
  NameRefusal.duplicate => 'pyramid.err_duplicate',
};

class PyramidEditor extends ConsumerStatefulWidget {
  const PyramidEditor({super.key});

  @override
  ConsumerState<PyramidEditor> createState() => _PyramidEditorState();
}

class _PyramidEditorState extends ConsumerState<PyramidEditor> {
  /// Which division is being looked at. The stepper walks the pyramid.
  int _divIdx = 0;

  /// The row being renamed, or null.
  int? _editing;

  /// The whole division as a textarea, or null when it is a list of rows.
  bool _listMode = false;

  /// The import box is open.
  bool _importMode = false;

  final TextEditingController _rename = TextEditingController();
  final TextEditingController _list = TextEditingController();
  final TextEditingController _presetName = TextEditingController();
  final TextEditingController _import = TextEditingController();

  /// Whether anything changed, so the table behind can be told once at the end
  /// rather than on every keystroke.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    // **THE PYRAMID IS BUILT LAZILY, and this screen was reading it raw.**
    // `progression.leaguePyramid` is null in a fresh save — nothing fills it
    // until a season needs opponents — so a player who opened the team names
    // editor before their first season saw fourteen empty divisions and
    // concluded there were no teams in the pyramid. There are; nobody had asked
    // for them yet. `ensureLeaguePyramid` is the one thing that knows how to
    // make them, and it is idempotent, so asking on open costs a save that
    // already has one nothing.
    //
    // After the frame, because Riverpod refuses a write from `initState` — and
    // rightly: two listeners of one provider would see different states inside
    // the same build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pyramidTeams(_state, divisions.first.id).isNotEmpty) return;
      ref.read(gameProvider).update(ensureLeaguePyramid);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _rename.dispose();
    _list.dispose();
    _presetName.dispose();
    _import.dispose();
    // **One signal, at the end.** Renaming fourteen clubs should not rebuild the
    // league table fourteen times.
    if (_changed) emit('pyramid:renamed');
    super.dispose();
  }

  Map<String, dynamic> get _state =>
      ref.read(gameProvider).state ?? const <String, dynamic>{};

  Division get _div => divisions[_divIdx];

  List<Map<String, dynamic>> get _teams => pyramidTeams(_state, _div.id);

  /// **ON THE BUS, not a `SnackBar`.** `ScaffoldMessenger.of` walks up to the
  /// Scaffold BEHIND this sheet, so every refusal this screen has to give — a
  /// name too short, a duplicate, a preset limit — was posted underneath the
  /// sheet that provoked it.
  void _say(String key, {Map<String, Object?> params = const {}}) {
    if (!mounted) return;
    emit('toast:info', t(key, params));
  }

  void _step(int delta) {
    final next = _divIdx + delta;
    if (next < 0 || next >= divisions.length) return;
    setState(() {
      _divIdx = next;
      _editing = null;
      _listMode = false;
    });
  }

  void _commitRename(Map<String, dynamic> team) {
    final result = validateTeamName(
      _state,
      _rename.text,
      current: team['name'] as String?,
    );
    if (!result.ok) {
      _say(refusalKey(result.reason!));
      return;
    }
    if (result.name != team['name']) {
      ref
          .read(gameProvider)
          .update((s) => renameTeam(s, team['name'] as String?, result.name));
      _changed = true;
    }
    setState(() => _editing = null);
  }

  void _applyList() {
    final outcome = ref
        .read(gameProvider)
        .update((s) => applyNameList(s, _div.id, _list.text.split('\n')));
    _changed = _changed || outcome.applied > 0;
    setState(() => _listMode = false);
    // **What was SKIPPED is the interesting half.** A pasted list with a
    // duplicate in it silently keeping the old name is how somebody decides the
    // editor is broken.
    final skipped = outcome.skipped;
    if (skipped.isNotEmpty) {
      _say(refusalKey(skipped.first.reason));
    } else {
      _say('pyramid.applied', params: {'n': outcome.applied});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(saveRevisionProvider);
    final kit = Theme.of(context).extension<KitTheme>()!;
    final teams = _teams;
    final presets = listPresets(_state);

    return Column(
      key: const ValueKey('pyramid-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: t('pyramid.title'), subtitle: t('pyramid.hint')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              _Stepper(
                division: _div,
                // Up the pyramid is a HIGHER division and a lower index — the
                // list runs from the top down, so the arrows have to be read
                // against the ladder rather than against the array.
                onUp: _divIdx > 0 ? () => _step(-1) : null,
                onDown: _divIdx < divisions.length - 1 ? () => _step(1) : null,
              ),
              const SizedBox(height: 10),
              if (_listMode)
                _ListEditor(
                  controller: _list,
                  onCancel: () => setState(() => _listMode = false),
                  onApply: _applyList,
                )
              else ...[
                _Rows(
                  teams: teams,
                  editing: _editing,
                  controller: _rename,
                  onEdit: (i) => setState(() {
                    _editing = i;
                    _rename.text = '${teams[i]['name'] ?? ''}';
                    _rename.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _rename.text.length,
                    );
                  }),
                  onCommit: _commitRename,
                ),
                const SizedBox(height: 10),
                _WideButton(
                  key: const ValueKey('pyramid-list-open'),
                  glyph: '☰',
                  label: t('pyramid.edit_list', {
                    'division': tName('division', _div.id),
                  }),
                  onTap: () => setState(() {
                    _listMode = true;
                    _editing = null;
                    _list.text = [
                      for (final team in teams) '${team['name'] ?? ''}',
                    ].join('\n');
                  }),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Divider(color: kit.border, height: 1),
              ),
              Text(
                t('pyramid.presets').toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: kit.accentBright,
                ),
              ),
              const SizedBox(height: 8),
              if (presets.isEmpty)
                Text(
                  t('pyramid.no_presets'),
                  style: TextStyle(fontSize: 12, color: kit.textMuted),
                )
              else
                for (final raw in presets)
                  if (raw is Map<String, dynamic>)
                    _PresetRow(
                      preset: raw,
                      onLoad: () {
                        final outcome = ref
                            .read(gameProvider)
                            .update((s) => applyPreset(s, raw['id']));
                        _changed = true;
                        _say('pyramid.applied', params: {'n': outcome.applied});
                        setState(() {});
                      },
                      onExport: () {
                        Clipboard.setData(
                          ClipboardData(text: exportPresetText(raw)),
                        );
                        _say('pyramid.exported');
                      },
                      onDelete: () {
                        ref
                            .read(gameProvider)
                            .update((s) => deletePreset(s, raw['id']));
                        setState(() {});
                      },
                    ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      key: const ValueKey('pyramid-preset-name'),
                      controller: _presetName,
                      hint: t('pyramid.preset_name_placeholder'),
                      maxLength: 30,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    key: const ValueKey('pyramid-preset-save'),
                    onPressed: () {
                      final result = ref
                          .read(gameProvider)
                          .update((s) => savePreset(s, _presetName.text));
                      if (!result.ok) {
                        _say(
                          result.reason == PresetRefusal.full
                              ? 'pyramid.presets_full'
                              : 'pyramid.err_label',
                        );
                        return;
                      }
                      _presetName.clear();
                      _say('pyramid.saved');
                      setState(() {});
                    },
                    child: Text(t('pyramid.save_preset')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_importMode)
                _ImportBox(
                  controller: _import,
                  onCancel: () => setState(() => _importMode = false),
                  onApply: () {
                    final result = ref
                        .read(gameProvider)
                        .update(
                          (s) => importPresetText(
                            s,
                            _import.text,
                            _presetName.text.trim().isEmpty
                                ? t('pyramid.imported_label')
                                : _presetName.text,
                          ),
                        );
                    if (!result.ok) {
                      _say('pyramid.import_failed');
                      return;
                    }
                    _import.clear();
                    setState(() => _importMode = false);
                    _say('pyramid.saved');
                  },
                )
              else
                _WideButton(
                  key: const ValueKey('pyramid-import-open'),
                  glyph: '⇩',
                  label: t('pyramid.import'),
                  onTap: () => setState(() => _importMode = true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `‹ Division ›`, which is how a fifty-six-team pyramid fits on a phone.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.division,
    required this.onUp,
    required this.onDown,
  });

  final Division division;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('pyramid-up'),
          onPressed: onUp,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            tName('division', division.id),
            key: const ValueKey('pyramid-division'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kit.accentBright,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('pyramid-down'),
          onPressed: onDown,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// The division's clubs, one per row, each a tap away from being renamed.
class _Rows extends StatelessWidget {
  const _Rows({
    required this.teams,
    required this.editing,
    required this.controller,
    required this.onEdit,
    required this.onCommit,
  });

  final List<Map<String, dynamic>> teams;
  final int? editing;
  final TextEditingController controller;
  final void Function(int index) onEdit;
  final void Function(Map<String, dynamic> team) onCommit;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      decoration: BoxDecoration(
        color: kit.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kit.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < teams.length; i++)
            if (i == editing)
              Padding(
                key: const ValueKey('pyramid-rename'),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: controller,
                        maxLength: teamNameMax,
                        autofocus: true,
                        onSubmit: () => onCommit(teams[i]),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      key: const ValueKey('pyramid-rename-ok'),
                      onPressed: () => onCommit(teams[i]),
                      child: Text(t('common.ok')),
                    ),
                  ],
                ),
              )
            else
              InkWell(
                key: ValueKey('pyramid-row-$i'),
                onTap: () => onEdit(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${teams[i]['name'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.edit, size: 15, color: kit.accentBright),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// The whole division as text, one club a line.
class _ListEditor extends StatelessWidget {
  const _ListEditor({
    required this.controller,
    required this.onCancel,
    required this.onApply,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('pyramid-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(controller: controller, lines: 8),
        const SizedBox(height: 6),
        Text(
          t('pyramid.list_hint'),
          style: TextStyle(fontSize: 12, color: kit.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: Text(t('common.cancel')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton(
                key: const ValueKey('pyramid-list-apply'),
                onPressed: onApply,
                child: Text(t('pyramid.apply')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImportBox extends StatelessWidget {
  const _ImportBox({
    required this.controller,
    required this.onCancel,
    required this.onApply,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('pyramid-import'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Field(controller: controller, lines: 6, hint: t('pyramid.import_hint')),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: Text(t('common.cancel')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const ValueKey('pyramid-import-apply'),
              onPressed: onApply,
              child: Text(t('pyramid.import')),
            ),
          ),
        ],
      ),
    ],
  );
}

/// One saved pyramid: load it, copy it out, or bin it.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.onLoad,
    required this.onExport,
    required this.onDelete,
  });

  final Map<String, dynamic> preset;
  final VoidCallback onLoad;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      key: ValueKey('pyramid-preset-${preset['id']}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        decoration: BoxDecoration(
          color: kit.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kit.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${preset['label'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(onPressed: onLoad, child: Text(t('pyramid.load'))),
            TextButton(onPressed: onExport, child: Text(t('pyramid.export'))),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// One text box, so the sheet has one input treatment rather than five.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hint,
    this.maxLength,
    this.lines = 1,
    this.autofocus = false,
    this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final int lines;
  final bool autofocus;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: lines,
      minLines: lines,
      maxLength: maxLength,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        filled: true,
        fillColor: kit.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kit.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kit.border),
        ),
      ),
    );
  }
}

/// A full-width tinted button — the two "open a mode" controls.
class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.glyph,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        // A washed accent FACE with a stronger accent border — through the
        // helper, because neither colour reaches a moulded button from
        // `styleFrom`: the face is painted in a `backgroundBuilder` over a
        // transparent Material, so `backgroundColor` landed underneath it and
        // `side` drew a second outline 4pt clear of the first.
        //
        // Not `outline: true`, which forces the face transparent — the wash IS
        // this button's face, and it is what tells an editor's own controls
        // apart from the sheet they sit on.
        style: mouldedButtonStyle(
          face: kit.accent.withValues(alpha: 0.12),
          edge: kit.accent.withValues(alpha: 0.45),
          ink: kit.accentBright,
          dead: kit.surface2,
          deadInk: kit.textMuted,
          border: kit.border,
        ),
        icon: Text(glyph, style: const TextStyle(fontSize: 15)),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
