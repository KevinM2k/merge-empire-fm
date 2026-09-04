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

import 'dart:async';

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

/// What colour a row's icon is drawn in — the cards say where a subject starts,
/// this says what it IS. Keyed on the icon, which already names the subject, so
/// the table is one place rather than fifteen call sites.
///
/// **Not kit-derived, for [dangerInk]'s reason:** a subject colour that moves
/// with the club's kit identifies nothing. One saturation, only the hue moves;
/// [settingsTintInk] puts each on the page it is on.
const Map<String, Color> settingsIconTints = {
  // General
  'club': Color(0xFF307FCF),
  'shield': Color(0xFF7230CF),
  'sun': Color(0xFFCF9530),
  'bell': Color(0xFFCF304B),
  'star': Color(0xFFCFA730),
  'lock': Color(0xFF30CF9A),
  // Audio
  'sound': Color(0xFF309ACF),
  'music': Color(0xFFA730CF),
  'tap': Color(0xFF30CFC1),
  // Match
  'video': Color(0xFF30CF72),
  'bolt': Color(0xFFCF7A30),
  'swords': Color(0xFFCF303E),
  'tag': Color(0xFFCF309A),
  // Account
  'globe': Color(0xFF30A7CF),
  'trophy': Color(0xFFCFA730),
};

/// The ground a tint is solved against: every kit's surface is 95% lightness in
/// light mode and 12% in dark, so both are known ahead of a frame.
const Color settingsTintGroundLight = Color(0xFFF2F2F2);
const Color settingsTintGroundDark = Color(0xFF1F1F1F);

/// What every tint is solved to against that ground.
///
/// **A constant lightness is not a constant weight:** at HSL 36% the teal reads
/// 3.3:1 on the light card and the violet 9.3:1, so half the column shouts and
/// half whispers. Solved per hue instead, so only the hue tells them apart.
const double settingsTintContrastLight = 4.6;
const double settingsTintContrastDark = 7.0;

/// WCAG's ratio, which is what the targets above are expressed in.
double settingsContrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

final Map<(int, bool), Color> _tintInkCache = {};

/// A subject colour, moved to where it reads on the page it is on. Only the
/// lightness moves, and it stops at the first value clearing the target —
/// solving past it washes every tint towards the ink at the far end.
Color settingsTintInk(BuildContext context, Color base) => settingsTintFor(
  base,
  light: Theme.of(context).brightness == Brightness.light,
);

/// [settingsTintInk] without a tree, so the solve can be checked on its own.
Color settingsTintFor(Color base, {required bool light}) {
  return _tintInkCache.putIfAbsent((base.toARGB32(), light), () {
    final hsl = HSLColor.fromColor(base);
    final ground = light ? settingsTintGroundLight : settingsTintGroundDark;
    final want = light ? settingsTintContrastLight : settingsTintContrastDark;
    // Monotonic in lightness against a ground at either extreme, so twelve
    // halvings land inside a step nobody can see.
    var lo = light ? 0.0 : 0.02;
    var hi = light ? 0.98 : 1.0;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      final ok =
          settingsContrast(hsl.withLightness(mid).toColor(), ground) >= want;
      // `lo` is the passing end in light and the failing end in dark.
      if (light == ok) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hsl.withLightness(light ? lo : hi).toColor();
  });
}

/// The colour a row draws its icon — and its own controls — in.
Color settingsRowInk(BuildContext context, String icon) {
  final tint = settingsIconTints[icon];
  if (tint == null) {
    return Theme.of(context).extension<KitTheme>()!.accentBright;
  }
  return settingsTintInk(context, tint);
}

/// The plate an icon sits on. Sets the note's indent and the two rows' gutter.
const double settingsIconTileSize = 28;

/// The icon at the head of a row, in a tile of its subject's colour.
///
/// **A tile, not a tinted stroke:** eighteen points of line art carries almost
/// no colour. It is [DangerRow]'s plate one size down, so the two agree.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({super.key, required this.icon, this.muted = false});

  final String icon;

  /// A row that cannot be pressed. Its icon goes grey with its label rather
  /// than keeping a colour that promises a live control.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final light = Theme.of(context).brightness == Brightness.light;
    final base = settingsIconTints[icon] ?? kit.accentBright;
    return Container(
      width: settingsIconTileSize,
      height: settingsIconTileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // The base hue washes the plate, not the solved ink — that one has been
        // pushed away from the ground to be legible.
        color: muted
            ? kit.surface2
            : base.withValues(alpha: light ? 0.14 : 0.22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GameIcon(
        icon,
        size: 18,
        color: muted ? kit.textMuted : settingsRowInk(context, icon),
      ),
    );
  }
}

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
                fontSize: 12,
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
          // **ONE HEIGHT FOR EVERY ROW, set by the tallest control.** A segment
          // is a bordered pill and a toggle is not, so a card mixing the two
          // had rows of two different heights down it — and the theme setting
          // becoming a three-way segment is what made that obvious enough to
          // report. The floor is the segment's own height, so nothing moved:
          // the switch rows came UP to meet it.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: settingsRowContentHeight),
            child: Row(
              children: [
                SettingsIconTile(icon: icon),
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
          ),
          if (note != null)
            Padding(
              // Indented past the icon, so the note reads as belonging to the
              // label rather than to the row. The tile plus the gutter.
              padding: const EdgeInsets.only(
                left: settingsIconTileSize + 10,
                top: 6,
                bottom: 6,
              ),
              child: Text(
                note!,
                style: TextStyle(
                  fontSize: 12,
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
    this.onTurnedOn,
  });

  final String settingKey;
  final String icon;
  final String label;
  final String? note;
  final bool defaultValue;
  final bool enabled;

  /// Run after the setting is written, and only when it was switched ON.
  ///
  /// **A permission is asked for HERE or nowhere.** Notifications need a
  /// runtime prompt on both platforms and a prompt can only be raised while the
  /// app is on screen — switching the toggle on is the one moment that is both
  /// foreground and unambiguously the player asking for the feature.
  final Future<void> Function()? onTurnedOn;

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
            ? (next) {
                writeSetting(ref, settingKey, next);
                if (next && onTurnedOn != null) unawaited(onTurnedOn!());
              }
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
/// The height every settings row's content stands at.
///
/// The tallest control on the page sets it: a [SettingsSegment] is a bordered
/// pill — 30 points of choice plus its 1-point rule top and bottom — and a
/// [SettingsToggle] is shorter. Rows are measured against this rather than each
/// against its own trailing widget.
const double settingsRowContentHeight = 32;

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
    this.note,
  });

  final String icon;
  final String label;

  /// Null with a [reason] is the pending state — see [PendingControl] for why
  /// these are never hidden.
  final VoidCallback? onTap;
  final String? reason;

  /// The small print under a LIVE row, for one whose name is a destination
  /// rather than a description. Distinct from [reason], which explains why a
  /// row cannot be pressed: a row can only ever be one or the other, and the
  /// reason wins because a dead control has to say so first.
  final String? note;

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
            SettingsIconTile(icon: icon, muted: pending),
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
                  if ((reason ?? note) case final line?)
                    Text(
                      line,
                      style: TextStyle(fontSize: 12, color: kit.textMuted),
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
                      fontSize: 12,
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
    final meta = TextStyle(fontSize: 12, color: kit.textMuted, height: 1.5);
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
