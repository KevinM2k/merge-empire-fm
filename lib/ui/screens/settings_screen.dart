/// The hidden Settings screen, reached from the HUD cog.
///
/// Four tabs, and no wrap at the ends — the JS's own rule. Anything that needs a
/// service M4 has not delivered ships disabled with a reason rather than hidden.
///
/// **THE SCREEN IS CARDS, NOT A LIST.** It had been a flat `ListView` of
/// `SwitchListTile`s, which is a debug menu: no grouping, no icon column, and
/// every setting the same weight as every other. `settings_controls.dart` carries
/// the JS's two containers and its rows; nothing here draws its own box.
///
/// **A PAIR OF NAMED STATES IS A SEGMENT.** Match speed as a toggle asks the
/// player to work out which way is fast; as `1× | 2×` it says so. The three
/// controls the JS draws that way — pitch view, speed, difficulty — were all
/// switches here, which is what made the Match tab read as unexplained flags.
///
/// **The danger zone is on GENERAL, where the JS puts it**, under its own
/// heading. It had been on Account, which is the tab about signing in.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/rating_prompt.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/i18n_providers.dart';
import 'package:merge_empire_fc/services/ad_consent.dart';
import 'package:merge_empire_fc/services/store_review.dart';
import 'package:merge_empire_fc/ui/popups/club_name_card.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/screens/grid/auto_tier_sheet.dart';
import 'package:merge_empire_fc/ui/screens/settings_audio_row.dart';
import 'package:merge_empire_fc/ui/screens/settings/pyramid_editor_sheet.dart';
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
                  children: [
                    const SizedBox(height: 13),
                    ...switch (_tab) {
                      SettingsTab.general => _general(),
                      SettingsTab.audio => _audio(),
                      SettingsTab.match => _match(),
                      SettingsTab.account => _account(),
                    },
                    // On every tab, as the JS does: this is the only place in
                    // the game that says which build a player is on.
                    SettingsFooterCard(
                      version: appVersion,
                      versionLabel: t('settings.version'),
                      tagline: t('settings.tagline'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _general() => [
    SettingsCard(
      children: [
        SettingsRow(
          key: const ValueKey('club-name-row'),
          icon: 'club',
          label: t('settings.clubName'),
          trailing: SettingsValue(
            text: ref.watch(clubNameProvider).isEmpty
                ? t('settings.notSet')
                : ref.watch(clubNameProvider),
          ),
          onTap: () => showClubNameCard(context),
        ),
        // **The pyramid editor is BUILT now**, and it always could have been:
        // `pyramid_names_engine` is five hundred ported, tested lines and this
        // row was a `PendingControl` saying "coming soon" over the top of them.
        SettingsAction(
          key: const ValueKey('team-names-btn'),
          icon: 'shield',
          label: t('pyramid.title'),
          onTap: () => showPyramidEditor(context),
        ),
        SettingSwitch(
          settingKey: 'lightMode',
          icon: 'sun',
          label: t('settings.lightMode'),
        ),
        SettingSwitch(
          settingKey: 'notificationsEnabled',
          icon: 'bell',
          label: t('settings.notifications'),
        ),
      ],
    ),
    SettingsCard(
      children: [
        // **Rate Us was the one of the four that only needed a URL**, and it
        // has one now: the store's own write-review page, opened in the system
        // browser. A tap here is also an ANSWER — a player who goes to the
        // store has been asked, so the prompt scheduler stops asking.
        SettingsAction(
          key: const ValueKey('rate-btn'),
          icon: 'star',
          label: t('settings.rateUs'),
          onTap: () {
            final game = ref.read(gameProvider);
            final state = game.state;
            if (state != null) {
              recordRatingDecision(state, 'done');
              game.scheduleSave();
            }
            unawaited(requestNativeReview());
          },
        ),
        // **Google requires that consent can be REVOKED at any time**, so this
        // row is not decoration — it is the entry point the policy asks for.
        // It appears only where consent applies (the EEA, the UK, Switzerland),
        // which is `adConsentAvailable`, cached at boot so this can decide
        // synchronously: a row that arrives a second after the screen is worse
        // than one that is always there.
        if (adConsentAvailable)
          SettingsAction(
            key: const ValueKey('privacy-btn'),
            icon: 'lock',
            label: t('settings.privacyOptions'),
            onTap: () => unawaited(showAdConsentForm()),
          )
        else
          PendingControl(
            controlKey: 'privacy-btn',
            icon: 'lock',
            label: t('settings.privacyOptions'),
            reason: t('settings.comingSoon'),
          ),
      ],
    ),
    SettingsGroup(head: t('settings.language'), child: _LanguageGrid()),
    SettingsGroup(
      head: t('settings.startOver'),
      danger: true,
      child: Column(
        children: [
          DangerRow(
            key: const ValueKey('reset-btn'),
            glyph: '⚽',
            title: t('settings.reset'),
            description: t('settings.resetHint'),
            onTap: () => _confirmReset(soft: true),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).extension<KitTheme>()!.border,
          ),
          DangerRow(
            key: const ValueKey('full-reset-btn'),
            glyph: '☠️',
            critical: true,
            title: t('fullReset.button'),
            description: t('fullReset.hint'),
            onTap: () => _confirmReset(soft: false),
          ),
        ],
      ),
    ),
  ];

  /// Switch difficulty, which starts the career over.
  ///
  /// **The copy is emphatic about the cost and so is this.** `toHard` and
  /// `toEasy` both end "Switching will start you over", and they are the whole
  /// explanation of what the other mode IS — fatigue, rotation and live subs on
  /// one side, auto-pick and coach tips on the other. So the card is the
  /// warning, and the target mode's own sentence is its body.
  ///
  /// **Written BEFORE the reset, not after.** `resetState` copies `settings`
  /// forward, so the flag set here is the one the new career starts under —
  /// and doing it the other way round would leave a window where the save is
  /// reset but still in the old mode.
  void _confirmDifficulty({required bool hard}) {
    showCoachCard<void>(
      context,
      titleKey: 'difficulty.switch.title',
      bodyKey: hard ? 'difficulty.switch.toHard' : 'difficulty.switch.toEasy',
      actions: [
        CoachAction(labelKey: 'difficulty.switch.cancel', onTap: () {}),
        CoachAction(
          labelKey: 'difficulty.switch.confirm',
          tone: CoachTone.decline,
          onTap: () {
            writeSetting(ref, 'hardMode', hard);
            ref.read(gameProvider).resetState();
            // Same reason the reset rows do it: landing back on the Settings
            // screen of a save that no longer exists is the closest thing to
            // nothing having happened.
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }

  /// Ask, then actually do it.
  ///
  /// Both rows used to open Colin's card with an EMPTY handler behind the
  /// confirm button — so a player could read the warning, agree to it, and watch
  /// nothing happen. The engine has had both resets since M1.
  void _confirmReset({required bool soft}) {
    showCoachCard<void>(
      context,
      titleKey: soft ? 'reset.title' : 'fullReset.title',
      bodyKey: soft ? 'reset.body' : 'fullReset.body',
      actions: [
        CoachAction(labelKey: 'common.cancel', onTap: () {}),
        CoachAction(
          labelKey: soft ? 'reset.confirm' : 'fullReset.confirm',
          tone: CoachTone.decline,
          onTap: () {
            final game = ref.read(gameProvider);
            if (soft) {
              game.resetState();
            } else {
              game.fullResetState();
            }
            // Back to the game. The JS reloads the page here, and landing on
            // the Settings screen of a save that no longer exists is the
            // closest thing to nothing having happened.
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }

  List<Widget> _audio() => [
    SettingsCard(
      children: [
        AudioChannelRow(
          icon: 'sound',
          label: t('settings.sound'),
          enabledKey: 'soundEnabled',
          volumeKey: 'soundVolume',
        ),
        AudioChannelRow(
          icon: 'music',
          label: t('settings.music'),
          enabledKey: 'musicEnabled',
          volumeKey: 'musicVolume',
          // The JS ships music off by default, and the schema agrees.
          defaultEnabled: false,
        ),
      ],
    ),
  ];

  List<Widget> _match() {
    final ours = ref.watch(settingPick<bool>('cutawayOurTeam', true));
    final opp = ref.watch(settingPick<bool>('cutawayOpponent', true));
    final fast = ref.watch(settingPick<bool>('matchSpeedFast', false));
    final hard = ref.watch(settingPick<bool>('hardMode', false));
    return [
      SettingsCard(
        children: [
          // TWO FLAGS drawn as one pair, not one choice out of two: the cutaway
          // can be on for both sides, one, or neither, and the JS's own buttons
          // toggle their own key each.
          SettingsRow(
            icon: 'video',
            label: t('settings.pitchView'),
            trailing: SettingsSegment(
              key: const ValueKey('setting-pitchView'),
              choices: [
                (
                  label: t('settings.pitchView.ours'),
                  on: ours,
                  onTap: () => writeSetting(ref, 'cutawayOurTeam', !ours),
                ),
                (
                  label: t('settings.pitchView.opp'),
                  on: opp,
                  onTap: () => writeSetting(ref, 'cutawayOpponent', !opp),
                ),
              ],
            ),
          ),
          SettingsRow(
            icon: 'bolt',
            label: t('settings.matchSpeed'),
            trailing: SettingsSegment(
              key: const ValueKey('setting-matchSpeedFast'),
              choices: [
                (
                  label: '1×',
                  on: !fast,
                  onTap: () => writeSetting(ref, 'matchSpeedFast', false),
                ),
                (
                  label: '2×',
                  on: fast,
                  onTap: () => writeSetting(ref, 'matchSpeedFast', true),
                ),
              ],
            ),
          ),
          // **PRO MODE WAS UNREACHABLE, and it is a whole difficulty mode.**
          // `hardMode` had fourteen readers across ten engines — player fatigue,
          // squad rotation, live subs, a different trait pool, different daily
          // rewards and quests, no auto-pick, a quieter coach — and exactly one
          // writer: `false`, in `createDefaultState`. Nothing in the app could
          // ever turn it on, so every one of those branches was dead for every
          // player who has ever installed the port.
          //
          // Both choices sat here with `onTap: null` and the note said why: "the
          // JS changes it only through the new-team flow". That flow is the
          // START OVER group further up this same screen — `resetState` has been
          // wired since the pass that found both reset rows confirming into an
          // empty handler — so what was missing is not the flow, it is the
          // CHOICE on the way into it.
          //
          // Which is precisely what `difficulty.switch.*` describes, five
          // strings of it, translated ten times over with no caller:
          // "Switching will start you over."
          SettingsRow(
            icon: 'swords',
            label: t('settings.difficulty'),
            note: t('settings.difficulty.hint'),
            trailing: SettingsSegment(
              key: const ValueKey('setting-hardMode'),
              choices: [
                (
                  label: t('settings.difficulty.easy'),
                  on: !hard,
                  // The mode you are ALREADY in is not a switch. Offering it
                  // would put a start-over warning behind a button that changes
                  // nothing.
                  onTap: hard ? () => _confirmDifficulty(hard: false) : null,
                ),
                (
                  label: t('settings.difficulty.hard'),
                  on: hard,
                  onTap: hard ? null : () => _confirmDifficulty(hard: true),
                ),
              ],
            ),
          ),
        ],
      ),
      // On the MATCH tab, where the JS has it — the rules fire when a signing
      // lands, which is a match-day concern. The Players tab has a pill onto the
      // same sheet.
      SettingsCard(
        children: [
          SettingsRow(
            key: const ValueKey('auto-tier-row'),
            icon: 'tag',
            label: t('settings.autoTier'),
            note: t('settings.autoTier.hint'),
            trailing: SettingsValue(text: ref.watch(autoTierSummaryProvider)),
            onTap: () => showAutoTierSheet(context),
          ),
        ],
      ),
    ];
  }

  List<Widget> _account() => [
    SettingsCard(
      children: [
        PendingControl(
          controlKey: 'sign-in-btn',
          icon: 'globe',
          label: t('auth.account_connection'),
          reason: t('settings.comingSoon'),
        ),
        // The JS disables this one whenever nobody is signed in, which here is
        // always — a toggle that writes a preference nothing can act on would be
        // worse than one that says why it cannot.
        SettingsRow(
          icon: 'trophy',
          label: t('leaderboard.rankings_visible'),
          trailing: const SettingsToggle(
            key: ValueKey('setting-rankingsVisible'),
            value: false,
            onChanged: null,
          ),
        ),
      ],
    ),
    SettingsCard(
      children: [
        PendingControl(
          controlKey: 'feedback-btn',
          icon: 'megaphone',
          label: t('settings.sendFeedback'),
          reason: t('settings.comingSoon'),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kit.surface,
          border: Border.all(color: kit.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final tab in SettingsTab.values)
              Expanded(
                child: InkWell(
                  key: ValueKey('settings-tab-${tab.name}'),
                  onTap: () => onTap(tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: tab == active ? kit.accent : Colors.transparent,
                    child: Text(
                      t('settings.tab.${tab.name}'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tab == active ? kit.accentInk : kit.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The flags in a GRID, five across, the way the JS draws them.
///
/// It was a ten-row `ListTile` list, which is most of a screen for one setting
/// and buries everything under it. A grid of flags is also the one control here
/// that a player who cannot read the current language can still use.
class _LanguageGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final current = ref.watch(localeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: GridView.count(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.92,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final lang in settingsLanguages)
            _LanguageTile(
              lang: lang,
              selected: lang.id == current,
              kit: kit,
              onTap: () => ref.read(localeProvider.notifier).set(lang.id),
            ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.lang,
    required this.selected,
    required this.kit,
    required this.onTap,
  });

  final ({String id, String flag, String label}) lang;
  final bool selected;
  final KitTheme kit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: lang.label,
    selected: selected,
    button: true,
    child: InkWell(
      key: ValueKey('language-${lang.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? kit.accent : kit.surface2,
          border: Border.all(
            color: selected ? kit.accentBright : kit.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 22, height: 1)),
            const SizedBox(height: 4),
            Text(
              // The CODE rather than the native label: five across leaves ~55px
              // and "Português" does not fit in it. The label is on the tile's
              // semantics, so a screen reader still gets the language's name.
              lang.id.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.3,
                color: selected ? kit.accentInk : kit.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
