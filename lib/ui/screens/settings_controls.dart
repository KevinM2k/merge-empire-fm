/// The reusable rows a settings tab is built from.
///
/// Each writes through `game.update(...)`, which is what schedules the save and
/// notifies the providers — a raw write to the map would do neither.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

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

class SettingSwitch extends ConsumerWidget {
  const SettingSwitch({
    super.key,
    required this.settingKey,
    required this.label,
    this.description,
    this.defaultValue = true,
    this.enabled = true,
  });

  final String settingKey;
  final String label;
  final String? description;
  final bool defaultValue;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final value = ref.watch(settingPick<bool>(settingKey, defaultValue));
    return SwitchListTile(
      key: ValueKey('setting-$settingKey'),
      title: Text(label),
      subtitle: description == null
          ? null
          : Text(description!, style: TextStyle(color: kit.textMuted)),
      value: value,
      activeThumbColor: kit.accent,
      onChanged: enabled
          ? (next) => writeSetting(ref, settingKey, next)
          : null,
    );
  }
}

/// A 0..1 multiplier, shown as a percentage.
class SettingSlider extends ConsumerWidget {
  const SettingSlider({
    super.key,
    required this.settingKey,
    required this.label,
  });

  final String settingKey;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final value = ref.watch(settingPick<num>(settingKey, 1)).toDouble().clamp(
      0.0,
      1.0,
    );
    return ListTile(
      title: Text(label),
      subtitle: Slider(
        key: ValueKey('setting-$settingKey'),
        value: value,
        activeColor: kit.accent,
        onChanged: (next) =>
            writeSetting(ref, settingKey, double.parse(next.toStringAsFixed(2))),
      ),
      trailing: Text('${(value * 100).round()}%'),
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
    this.icon,
  });

  final String label;
  final String reason;
  final String controlKey;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ListTile(
      leading: icon == null ? null : Icon(icon, color: kit.textMuted),
      title: Text(label, style: TextStyle(color: kit.textMuted)),
      subtitle: Text(reason, style: TextStyle(color: kit.textMuted, fontSize: 12)),
      enabled: false,
      trailing: ElevatedButton(
        key: ValueKey(controlKey),
        onPressed: null,
        child: Text(label),
      ),
    );
  }
}

/// A destructive row. Painted apart so a tap reads as a decision.
class DangerRow extends StatelessWidget {
  const DangerRow({
    super.key,
    required this.rowKey,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String rowKey;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ListTile(
      key: ValueKey(rowKey),
      leading: const Icon(Icons.warning_amber, color: Colors.redAccent),
      title: Text(title, style: const TextStyle(color: Colors.redAccent)),
      subtitle: Text(description, style: TextStyle(color: kit.textMuted)),
      onTap: onTap,
    );
  }
}
