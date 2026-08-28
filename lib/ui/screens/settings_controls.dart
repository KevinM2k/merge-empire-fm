/// The rows a settings tab is built from, and the cards they sit in.
///
/// Ported from `.settings-card` / `.settings-row` / `.settings-group` in
/// `styles/screens.css`. The port had every setting as a bare `SwitchListTile`
/// on a flat `ListView`, which is why the screen read as a debug menu: a row of
/// Material list tiles has no grouping, no icon column and no card, so nothing
/// on the page said which settings belonged together.
///
/// **A ROW IS ICON | LABEL | CONTROL, and the control is on the RIGHT.** That is
/// the JS's `space-between`, and it is what lets a card mix a toggle, a
/// segmented control and a tappable value without the eye losing the column the
/// controls live in.
///
/// **A CARD IS THE GROUPING.** Rows inside one are divided by a hairline and
/// share its border; a new card means a new subject. The JS uses exactly two
/// containers — [SettingsCard] for an unlabelled group and [SettingsGroup] for
/// one with a heading — and nothing else on the screen draws its own box.
///
/// Each control writes through `game.update(...)`, which is what schedules the
/// save and notifies the providers — a raw write to the map would do neither.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// One button in a [SettingsSegment]: what it says, whether it is live, and
/// what pressing it does. A null [onTap] is a state the player cannot set.
typedef SettingsChoice = ({
  String label,
  bool on,
  VoidCallback? onTap,

  /// A padlock before the label. **A dead segment does not say WHY it is
  /// dead** — the row's note underneath does, and nobody reads a note about a
  /// control they have not worked out is locked. Pro mode was reported as
  /// needing one.
  bool locked,
});

/// Read one key out of `state['settings']`.
Provider<T> settingPick<T>(String key, T fallback) {
  return savePick<T>((s) {
    final settings = s['settings'];
    final value = settings is Map<String, dynamic> ? settings[key] : null;
    return value is T ? value : fallback;
  });
}

void writeSetting(WidgetRef ref, String key, Object? value) {
  ref.read(gameProvider).update((s) {
    final settings = s['settings'];
    if (settings is Map<String, dynamic>) settings[key] = value;
  });
}

/// The JS's `--color-surface-translucent`: the surface at 88%, so the kit's
/// background gradient shows through the card rather than being covered by it.
Color settingsSurface(KitTheme kit) => kit.surface.withValues(alpha: 0.88);

/// A card's shadow, which the JS only draws in LIGHT mode (`--card-shadow` is
/// `none` in the dark block). On a dark page a drop shadow is invisible and the
/// border is what separates the card; on a light one the border alone reads as a
/// wireframe.
List<BoxShadow> settingsShadow(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? [
        BoxShadow(
          color: const Color(0xFF111827).withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(0xFF111827).withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ]
    : const [];

/// Several rows in one card, split by hairlines.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      margin: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      decoration: BoxDecoration(
        color: settingsSurface(kit),
        border: Border.all(color: kit.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: settingsShadow(context),
      ),
      // The card clips, so a row's own ink splash stays inside its corners.
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: kit.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A card with a heading over it — the JS's `.settings-group`, used for Language
/// and Start Over so both read as one labelled block rather than as loose rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.head,
    required this.child,
    this.danger = false,
  });

  final String head;
  final Widget child;

  /// Tints the heading, so the block announces itself before anything in it is
  /// read.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      margin: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      decoration: BoxDecoration(
        color: settingsSurface(kit),
        border: Border.all(color: kit.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: settingsShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 9),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kit.border)),
            ),
            child: Text(
              head.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: danger ? dangerInk : kit.textMuted,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Icon, label, and whatever control the setting needs, on the right.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
    this.note,
  });

  /// A [gameIcons] name. The set is the game's own line art — Material's
  /// weights and metrics are a different family, and a screen mixing the two
  /// reads as two screens.
  final String icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  /// The small print under the row, for a setting whose consequence is not
  /// obvious from its name. The JS hangs it off the label's left edge, indented
  /// past the icon.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final body = Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, note == null ? 14 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameIcon(icon, size: 20, color: kit.accentBright),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
          if (note != null)
            Padding(
              // Indented past the icon, so the note reads as belonging to the
              // label rather than to the row.
              padding: const EdgeInsets.only(left: 30, top: 6, bottom: 6),
              child: Text(
                note!,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: kit.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

/// The JS's `.toggle`: a 48×28 pill with a 20px knob.
///
/// Not a `Switch`. Material's is 52×32 with a different knob travel and its own
/// state layer, and beside the game's own segmented controls it read as a
/// borrowed control — which is the same reason the icons are the JS's own.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;

  /// Null disables it — the JS's `.toggle-disabled`, at 45%.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: Opacity(
        opacity: onChanged == null ? 0.45 : 1,
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 28,
            decoration: BoxDecoration(
              color: value ? kit.accent : kit.border,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(4),
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A toggle wired to one `settings` key.
class SettingSwitch extends ConsumerWidget {
  const SettingSwitch({
    super.key,
    required this.settingKey,
    required this.icon,
    required this.label,
    this.note,
    this.defaultValue = true,
    this.enabled = true,
  });

  final String settingKey;
  final String icon;
  final String label;
  final String? note;
  final bool defaultValue;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingPick<bool>(settingKey, defaultValue));
    return SettingsRow(
      icon: icon,
      label: label,
      note: note,
      trailing: SettingsToggle(
        key: ValueKey('setting-$settingKey'),
        value: value,
        onChanged: enabled
            ? (next) => writeSetting(ref, settingKey, next)
            : null,
      ),
    );
  }
}

/// One named state per button, side by side — the JS's pitch-view, match speed
/// and difficulty controls.
///
/// **A PAIR OF NAMED STATES IS A SEGMENT, NOT A SWITCH.** "Match speed" as a
/// toggle asks the player to work out which way is fast; as `1× | 2×` it says
/// so. All three were switches here, which is what made the Match tab read as a
/// list of unexplained flags.
///
/// Each choice carries its OWN on state rather than the group carrying one
/// selected value, because the JS's pitch-view pair is two independent flags
/// drawn as a segment: the cutaway can be on for both sides, one, or neither. A
/// single-choice group is the same widget with the caller doing the comparison.
class SettingsSegment extends StatelessWidget {
  const SettingsSegment({super.key, required this.choices});

  final List<SettingsChoice> choices;

  /// A group nothing can change still shows which state is live. The JS does the
  /// same for difficulty, which only the new-team flow can set.
  bool get _readOnly => choices.every((c) => c.onTap == null);

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Opacity(
      opacity: _readOnly ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: kit.surface2,
          border: Border.all(color: kit.border),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < choices.length; i++) ...[
              if (i > 0) Container(width: 1, height: 30, color: kit.border),
              InkWell(
                key: ValueKey('segment-${choices[i].label}'),
                onTap: choices[i].onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  color: choices[i].on ? kit.accentBright : Colors.transparent,
                  // **A LOCKED CHOICE HAS TO LOOK LOCKED, and one 12px padlock
                  // beside a label the same weight and colour as the live one
                  // does not do it.** Reported against the difficulty row: the
                  // only difference between Pro-is-locked and Pro-is-simply-not-
                  // selected was a glyph most of the width of a full stop.
                  //
                  // The whole choice steps back rather than the group — the
                  // group's own `_readOnly` dim is for a segment nothing can
                  // change, and here Casual is perfectly live beside it — and
                  // the padlock comes up to the label's own size so the two
                  // read as one mark.
                  child: Opacity(
                    opacity: choices[i].locked ? 0.55 : 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (choices[i].locked) ...[
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: kit.textMuted,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          choices[i].label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: choices[i].on
                                ? kit.accentBrightInk
                                : kit.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The value on the right of a row that opens something — the JS's accent-bright
/// text with a chevron after it.
class SettingsValue extends StatelessWidget {
  const SettingsValue({super.key, required this.text, this.chevron = true});

  final String text;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A long club name must not push the chevron off the row, so the text
        // is the part that gives.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kit.accentBright,
            ),
          ),
        ),
        if (chevron) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: kit.textMuted),
        ],
      ],
    );
  }
}

/// A left-aligned action inside a card — the JS's `.settings-action`, for Rate
/// Us and Privacy Options.
class SettingsAction extends StatelessWidget {
  const SettingsAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.reason,
  });

  final String icon;
  final String label;

  /// Null with a [reason] is the pending state — see [PendingControl] for why
  /// these are never hidden.
  final VoidCallback? onTap;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final pending = onTap == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            GameIcon(
              icon,
              size: 20,
              color: pending ? kit.textMuted : kit.accentBright,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: pending ? kit.textMuted : null,
                    ),
                  ),
                  if (reason != null)
                    Text(
                      reason!,
                      style: TextStyle(fontSize: 11, color: kit.textMuted),
                    ),
                ],
              ),
            ),
            if (!pending)
              Icon(Icons.chevron_right, size: 18, color: kit.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A control that needs a service this build has not got yet.
///
/// Disabled with a visible reason, never hidden: a control that vanishes reads
/// as a missing feature, one that explains itself reads as a feature that is
/// coming.
class PendingControl extends StatelessWidget {
  const PendingControl({
    super.key,
    required this.label,
    required this.reason,
    required this.controlKey,
    required this.icon,
  });

  final String label;
  final String reason;
  final String controlKey;
  final String icon;

  @override
  Widget build(BuildContext context) => SettingsAction(
    key: ValueKey(controlKey),
    icon: icon,
    label: label,
    reason: reason,
    onTap: null,
  );
}

/// A destructive row. Painted apart so a tap reads as a decision.
class DangerRow extends StatelessWidget {
  const DangerRow({
    super.key,
    required this.glyph,
    required this.title,
    required this.description,
    required this.onTap,
    this.critical = false,
  });

  /// The JS's own emoji, in its own tile. This is the one place emoji stay: a
  /// ball and a skull are what tell the two rows apart at a glance, and neither
  /// is in the line-art set.
  final String glyph;
  final String title;
  final String description;
  final VoidCallback onTap;

  /// The second, worse one. The JS tints its icon tile and its title.
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: critical
                    ? dangerInk.withValues(alpha: 0.16)
                    : kit.surface2,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(glyph, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: critical ? dangerInk : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: kit.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 22,
              color: kit.textMuted.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// What this build is, at the bottom of every tab.
///
/// The JS puts it on all four, and it is the only place in the game that says
/// which version a player is on — which is the first thing a support message
/// needs and the one thing a screenshot cannot tell you.
class SettingsFooterCard extends StatelessWidget {
  const SettingsFooterCard({
    super.key,
    required this.version,
    required this.tagline,
    required this.versionLabel,
  });

  final String version;
  final String tagline;
  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final meta = TextStyle(fontSize: 11, color: kit.textMuted, height: 1.5);
    return Container(
      margin: const EdgeInsets.fromLTRB(13, 6, 13, 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: settingsSurface(kit),
        border: Border.all(color: kit.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: settingsShadow(context),
      ),
      child: Column(
        children: [
          Text(
            'Merge Empire',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: kit.accentBright,
            ),
          ),
          const Text(
            'FOOTBALL MANAGER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text('$versionLabel $version', style: meta),
          Text(tagline, style: meta, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
