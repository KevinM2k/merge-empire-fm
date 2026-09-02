/// One audio channel: icon, label, volume, on/off — all on one row.
///
/// Ported from `_audioRow` and `_setAudioEnabled` in `screens/SettingsScreen.js`.
/// The port had the toggle and the slider as two separate rows, which is two
/// controls for one thing and leaves the pair of them able to disagree.
///
/// **THE TOGGLE AND THE SLIDER ARE ONE CONTROL, and that is the whole file.**
/// Two rules follow from it, both the JS's:
///
/// 1. **Turning a channel on at 0% would be silent** — a control that says it is
///    on while nothing can be heard is indistinguishable from a broken feature.
///    So switching on at zero nudges the volume to 5%.
/// 2. **Dragging above 0 turns the channel back on.** The slider stays live when
///    the channel is off, dimmed rather than dead, because reaching for the
///    volume is how a player says they want to hear it — being made to find the
///    toggle first is a step that explains nothing. Dragging to 0 turns it off.
///
/// **There is no iOS gate here, and the JS's reason for having one does not
/// port.** It hides the slider on iOS because every sound there goes through an
/// `HTMLAudioElement` and WebKit treats `HTMLMediaElement.volume` as read-only —
/// Apple reserves volume for the hardware buttons. That is a restriction on
/// WebViews, not on the platform: a native player sets its own gain. Re-check it
/// against the real engine when there is one, and if it turns out to be true
/// there too, the gate goes HERE and nowhere else.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/screens/settings_controls.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The volume a channel is turned on at when it was left at zero.
const double audioNudge = 0.05;

/// The JS's `step="5"` — 20 stops, so a drag lands on a round number.
const int audioVolumeSteps = 20;

class AudioChannelRow extends ConsumerWidget {
  const AudioChannelRow({
    super.key,
    required this.icon,
    required this.label,
    required this.enabledKey,
    required this.volumeKey,
    this.defaultEnabled = true,
  });

  final String icon;
  final String label;
  final String enabledKey;
  final String volumeKey;
  final bool defaultEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final on = ref.watch(settingPick<bool>(enabledKey, defaultEnabled));
    final volume = ref
        .watch(settingPick<num>(volumeKey, 1))
        .toDouble()
        .clamp(0.0, 1.0);

    void setEnabled(bool next) {
      writeSetting(ref, enabledKey, next);
      // Rule 1.
      if (next && volume == 0) writeSetting(ref, volumeKey, audioNudge);
    }

    void setVolume(double next) {
      final rounded = double.parse(next.toStringAsFixed(2));
      writeSetting(ref, volumeKey, rounded);
      // Rule 2, both ways.
      if (rounded > 0 && !on) writeSetting(ref, enabledKey, true);
      if (rounded == 0 && on) writeSetting(ref, enabledKey, false);
    }

    return SettingsRow(
      icon: icon,
      label: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sized rather than `Expanded`: the two channels' sliders have to
          // start and end at the same x or the pair reads as two unrelated
          // rows, and their labels are different lengths. The JS fixes the
          // LABEL column for the same reason; fixing the slider is the same
          // constraint from the other end and survives a longer translation.
          SizedBox(
            width: 108,
            child: Opacity(
              // Dimmed, not dead — see rule 2.
              opacity: on ? 1 : 0.35,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  overlayShape: SliderComponentShape.noOverlay,
                  // The value is already on the row as a percentage; a bubble
                  // over the thumb covers the label it belongs to.
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  key: ValueKey('setting-$volumeKey'),
                  value: volume,
                  divisions: audioVolumeSteps,
                  activeColor: kit.accentBright,
                  inactiveColor: kit.surface2,
                  onChanged: setVolume,
                ),
              ),
            ),
          ),
          SizedBox(
            // Wide enough for "100%" so the row does not reflow as the slider
            // crosses 100 — a number that moves the toggle is worse than none.
            width: 42,
            child: Text(
              '${(volume * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: on
                    ? kit.textMuted
                    : kit.textMuted.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SettingsToggle(
            key: ValueKey('setting-$enabledKey'),
            value: on,
            onChanged: setEnabled,
          ),
        ],
      ),
    );
  }
}
