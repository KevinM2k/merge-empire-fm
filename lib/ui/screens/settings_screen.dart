/// The hidden Settings screen, reached from the HUD cog.
///
/// Four tabs, and no wrap at the ends — the JS's own rule. Anything that needs a
/// service M4 has not delivered ships disabled with a reason rather than hidden.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/i18n_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/grid/auto_tier_sheet.dart';
import 'package:merge_empire_fc/ui/screens/settings_controls.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

enum SettingsTab { general, audio, match, account }

/// The picker. Its ids must be exactly `supportedLocales` — a device language
/// that resolves to a catalogue nobody can switch back from is a trap, which is
/// why the JS asserts it and so does the test here.
const List<({String id, String flag, String label})> settingsLanguages = [
  (id: 'en', flag: '🇬🇧', label: 'English'),
  (id: 'es', flag: '🇪🇸', label: 'Español'),
  (id: 'pt', flag: '🇧🇷', label: 'Português'),
  (id: 'fr', flag: '🇫🇷', label: 'Français'),
  (id: 'de', flag: '🇩🇪', label: 'Deutsch'),
  (id: 'it', flag: '🇮🇹', label: 'Italiano'),
  (id: 'ja', flag: '🇯🇵', label: '日本語'),
  (id: 'ko', flag: '🇰🇷', label: '한국어'),
  (id: 'zh', flag: '🇨🇳', label: '中文'),
  (id: 'ar', flag: '🇸🇦', label: 'العربية'),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialTab});

  final SettingsTab? initialTab;

  @override
  ConsumerState<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SettingsTab _tab = widget.initialTab ?? SettingsTab.general;

  void openTab(SettingsTab tab) => setState(() => _tab = tab);

  /// No wrap at the ends, matching the JS: a swipe past the last tab does
  /// nothing rather than looping round.
  void _step(int delta) {
    final next = SettingsTab.values.indexOf(_tab) + delta;
    if (next < 0 || next >= SettingsTab.values.length) return;
    setState(() => _tab = SettingsTab.values[next]);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Scaffold(
      appBar: AppBar(title: Text(t('settings.tab.${_tab.name}'))),
      body: Container(
        decoration: kit.background,
        child: Column(
          children: [
            _TabStrip(active: _tab, onTap: openTab),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v != 0) _step(v < 0 ? 1 : -1);
                },
                child: ListView(
                  key: ValueKey('settings-body-${_tab.name}'),
                  children: switch (_tab) {
                    SettingsTab.general => _general(),
                    SettingsTab.audio => _audio(),
                    SettingsTab.match => _match(),
                    SettingsTab.account => _account(context),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _general() => [
    SettingSwitch(settingKey: 'lightMode', label: t('settings.lightMode')),
    SettingSwitch(
      settingKey: 'notificationsEnabled',
      label: t('settings.notifications'),
    ),
    const Divider(),
    // The row that has always owned the auto-sell rules. The Players tab has a
    // pill onto the same sheet, because that is where they fire.
    const AutoTierRow(),
    const Divider(),
    _LanguagePicker(),
  ];

  List<Widget> _audio() => [
    SettingSwitch(settingKey: 'soundEnabled', label: t('settings.sound')),
    SettingSlider(settingKey: 'soundVolume', label: t('settings.sound')),
    const Divider(),
    SettingSwitch(
      settingKey: 'musicEnabled',
      label: t('settings.music'),
      defaultValue: false,
    ),
    SettingSlider(settingKey: 'musicVolume', label: t('settings.music')),
  ];

  List<Widget> _match() => [
    SettingSwitch(
      settingKey: 'matchSpeedFast',
      label: t('settings.matchSpeed'),
      defaultValue: false,
    ),
    SettingSwitch(
      settingKey: 'cutawayOurTeam',
      label: t('settings.cutawayOurTeam'),
    ),
    SettingSwitch(
      settingKey: 'cutawayOpponent',
      label: t('settings.cutawayOpponent'),
    ),
    const Divider(),
    // Read-only here. The JS changes it only through the new-team flow, and it
    // is named for the old "Hard" label while the UI says Pro.
    SettingSwitch(
      settingKey: 'hardMode',
      label: t('settings.difficulty'),
      description: t('settings.difficulty.hint'),
      defaultValue: false,
      enabled: false,
    ),
  ];

  List<Widget> _account(BuildContext context) => [
    PendingControl(
      controlKey: 'sign-in-btn',
      icon: Icons.account_circle,
      label: t('auth.connect_account'),
      reason: t('settings.comingSoon'),
    ),
    PendingControl(
      controlKey: 'feedback-btn',
      icon: Icons.feedback,
      label: t('settings.sendFeedback'),
      reason: t('settings.comingSoon'),
    ),
    const Divider(),
    DangerRow(
      rowKey: 'reset-btn',
      title: t('settings.reset'),
      description: t('settings.resetHint'),
      onTap: () => showCoachCard<void>(
        context,
        titleKey: 'reset.title',
        bodyKey: 'reset.body',
        actions: [
          CoachAction(labelKey: 'common.cancel', onTap: () {}),
          CoachAction(
            labelKey: 'reset.confirm',
            destructive: true,
            onTap: () {},
          ),
        ],
      ),
    ),
    DangerRow(
      rowKey: 'full-reset-btn',
      title: t('fullReset.button'),
      description: t('fullReset.hint'),
      onTap: () => showCoachCard<void>(
        context,
        titleKey: 'fullReset.title',
        bodyKey: 'fullReset.body',
        actions: [
          CoachAction(labelKey: 'common.cancel', onTap: () {}),
          CoachAction(
            labelKey: 'fullReset.confirm',
            destructive: true,
            onTap: () {},
          ),
        ],
      ),
    ),
  ];
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.active, required this.onTap});

  final SettingsTab active;
  final void Function(SettingsTab) onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final tab in SettingsTab.values)
          TextButton(
            key: ValueKey('settings-tab-${tab.name}'),
            onPressed: () => onTap(tab),
            child: Text(
              t('settings.tab.${tab.name}'),
              style: TextStyle(
                color: tab == active ? kit.accent : kit.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final current = ref.watch(localeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            t('settings.language'),
            style: TextStyle(color: kit.textMuted),
          ),
        ),
        for (final lang in settingsLanguages)
          ListTile(
            key: ValueKey('language-${lang.id}'),
            leading: Text(lang.flag, style: const TextStyle(fontSize: 20)),
            title: Text(lang.label),
            trailing: lang.id == current
                ? Icon(Icons.check, color: kit.accent)
                : null,
            onTap: () => ref.read(localeProvider.notifier).set(lang.id),
          ),
      ],
    );
  }
}
