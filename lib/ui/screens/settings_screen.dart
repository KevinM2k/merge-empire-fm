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
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/i18n_providers.dart';
import 'package:merge_empire_fc/services/ad_consent.dart';
import 'package:merge_empire_fc/services/notifications.dart';
import 'package:merge_empire_fc/services/auth_service.dart';
import 'package:merge_empire_fc/services/leaderboard_service.dart';
import 'package:merge_empire_fc/services/store_review.dart';
import 'package:merge_empire_fc/ui/popups/club_name_card.dart';
import 'package:merge_empire_fc/ui/popups/prestige_card.dart' show proLockedAnswer;
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/connect_account_sheet.dart';
import 'package:merge_empire_fc/ui/screens/grid/auto_tier_sheet.dart';
import 'package:merge_empire_fc/ui/screens/settings_audio_row.dart';
import 'package:merge_empire_fc/ui/screens/settings/pyramid_editor_sheet.dart';
import 'package:merge_empire_fc/ui/screens/settings_controls.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/analytics.dart';

/// Is the OS refusing to deliver, while the player thinks it is not?
///
/// **Asked WITHOUT requesting**, which is the whole point: requesting would put
/// a system prompt in front of somebody who merely opened Settings. False on
/// any platform that cannot answer, because a warning nobody can act on is
/// worse than no warning.
final noticesBlockedProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(settingPick<bool>('notificationsEnabled', true))) return false;
  return !await notices.permissionGranted();
});

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
        // **THREE STATES, because a switch called "Light Mode" can only ever
        // disagree with the phone.** A player whose device goes dark at sunset
        // had to come in here and flip it back, twice a day. Asked for from the
        // couch: light, dark, or follow the device.
        //
        // `themeMode` is the key; `lightMode` is written alongside it and kept
        // truthful, because it is the one every existing save carries and the
        // only one the JS build knows about. See [themeChoiceProvider].
        SettingsRow(
          icon: 'sun',
          label: t('settings.theme'),
          trailing: Builder(
            builder: (context) {
              final choice = ref.watch(themeChoiceProvider);
              SettingsChoice pick(ThemeChoice v, String key) => (
                label: t('settings.theme.$key'),
                on: choice == v,
                onTap: () => _setTheme(ref, v),
                locked: false,
              );
              return SettingsSegment(
                key: const ValueKey('setting-themeMode'),
                choices: [
                  pick(ThemeChoice.light, 'light'),
                  pick(ThemeChoice.dark, 'dark'),
                  pick(ThemeChoice.system, 'system'),
                ],
              );
            },
          ),
        ),
        // **A TOGGLE THAT IS ON WHILE THE PHONE REFUSES IS A BROKEN FEATURE**,
        // and indistinguishable from one. `settings.notifications_blocked`
        // ships in ten languages and had no caller, so the switch read as
        // working while nothing could ever be delivered — which is the exact
        // line the JS gives its own hidden note to.
        //
        // Only while the toggle is ON: a warning about a feature the player has
        // turned off is noise.
        SettingSwitch(
          settingKey: 'notificationsEnabled',
          icon: 'bell',
          label: t('settings.notifications'),
          note: ref.watch(noticesBlockedProvider).valueOrNull == true
              ? t('settings.notifications_blocked')
              : null,
          // **THE ONE FOREGROUND MOMENT.** The runtime prompt cannot be raised
          // from `armNotices`, which runs as the app goes away — see the note
          // there. `force`, because a player who has just switched this on has
          // asked, whatever this process did earlier.
          onTurnedOn: () async {
            await ensureNoticePermission(force: true);
            ref.invalidate(noticesBlockedProvider);
          },
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
        // **AND ONLY WHERE THERE IS SOMETHING TO CONSENT TO.**
        //
        // The row went through a dead "coming soon" (wrong: it said the feature
        // was unfinished) to always-live-and-toast, matching `SettingsScreen.js`
        // — which is right about the WEB, where the same page is served to every
        // region and the button cannot know in advance. A store build does know:
        // `adConsentAvailable` is the UMP SDK's own `privacyOptionsRequired`,
        // cached at boot, so this can decide synchronously and a player outside
        // the EEA is not offered a control whose only possible outcome is a
        // toast saying it does not apply to them. Asked for from the couch.
        //
        // Google's requirement is that consent can be REVOKED at any time — and
        // it is, wherever consent was given. Where none was, there is nothing to
        // revoke.
        if (adConsentAvailable)
          SettingsAction(
            key: const ValueKey('privacy-btn'),
            icon: 'lock',
            label: t('settings.privacyOptions'),
            onTap: () async {
              final result = await showAdConsentForm();
              if (result == AdConsentFormResult.shown) return;
              emit('consent:unavailable');
            },
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
            // **REPORTED BEFORE THE RESET WIPES THE CONTEXT**, which is the
            // JS's own order and its own reasoning: a pro→casual bail, and
            // especially one a few seasons in, is the signal that Pro is too
            // hard rather than too rare, and every field that says so is about
            // to be thrown away. `standard` rather than `casual` is deliberate
            // — the mode was renamed in the UI and this value was not, so the
            // funnel stays comparable with pre-rename data.
            final state = ref.read(gameProvider).state;
            final progression = state?['progression'];
            final wasHard = _map(state?['settings'])?['hardMode'] == true;
            logAppEvent('difficulty_switch', {
              'from': wasHard ? 'pro' : 'standard',
              'to': hard ? 'pro' : 'standard',
              'source': 'settings',
              'division':
                  '${_map(progression)?['currentDivision'] ?? 'unknown'}',
              'season': _map(progression)?['seasonCount'] ?? 0,
              'matches_played': _map(progression)?['matchesPlayed'] ?? 0,
              'prestige_level': _map(state?['prestige'])?['level'] ?? 0,
            });
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
  /// **AND IT ASKS WHETHER TO RUN THE TUTORIAL AGAIN.** `reset.show_tutorial`
  /// and `fullReset.show_tutorial` — "Show the tutorial again" — sit translated
  /// in all ten catalogues with nothing able to print either, which is the
  /// loudest tell there is: the JS's reset dialog has this tick and the port
  /// dropped it. `resetState` and `fullResetState` have taken the flag since
  /// M1 and every caller was using the default.
  ///
  /// The default is the engine's own and the two differ on purpose: a soft
  /// reset is a repeat player starting again and skips it; a full wipe is the
  /// closest thing to a fresh install and runs it.
  void _confirmReset({required bool soft}) {
    var replayTutorial = !soft;
    showDialog<void>(
      context: context,
      barrierColor: coachCardScrim,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setTick) => CoachCardFrame(
          title: t(soft ? 'reset.title' : 'fullReset.title'),
          body: t(soft ? 'reset.body' : 'fullReset.body'),
          actions: [
            CoachAction(
              labelKey: 'common.cancel',
              tone: CoachTone.decline,
              onTap: () {},
            ),
            CoachAction(
              labelKey: soft ? 'reset.confirm' : 'fullReset.confirm',
              tone: CoachTone.decline,
              onTap: () {
                final game = ref.read(gameProvider);
                if (soft) {
                  game.resetState(replayTutorial: replayTutorial);
                } else {
                  game.fullResetState(replayTutorial: replayTutorial);
                }
                // Back to the game. The JS reloads the page here, and landing
                // on the Settings screen of a save that no longer exists is the
                // closest thing to nothing having happened.
                Navigator.of(context).maybePop();
              },
            ),
          ],
          child: _TutorialTick(
            label: t(soft ? 'reset.show_tutorial' : 'fullReset.show_tutorial'),
            value: replayTutorial,
            onChanged: (v) => setTick(() => replayTutorial = v),
          ),
        ),
      ),
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
        // **COLIN'S CHANNEL IS GONE, and the reason is that it controlled
        // nothing.** It was added when his voice rode the SFX toggle — the only
        // way to stop him talking was to mute the coin sounds with him — and
        // then `flutter_tts` was dropped for `ClipVoiceBackend`, which plays
        // `assets/voice/<locale>/<key>.mp3` when a clip is there and is silent
        // when it is not. There are no clips: `assets/voice/` holds a README
        // and nothing else. So the row was a switch and a slider that changed
        // nothing a player could hear, which is worse than no row at all.
        // Asked for from the couch.
        //
        // **The machinery stays**, and deliberately: `voiceEnabled` and
        // `voiceVolume` are still read by `providers/voice_providers.dart` and
        // still default to on, so dropping a folder of clips in is all it takes
        // for him to speak — see `assets/voice/README.md`. What comes back with
        // the clips is this row.
      ],
    ),
  ];

  List<Widget> _match() {
    final ours = ref.watch(settingPick<bool>('cutawayOurTeam', true));
    final opp = ref.watch(settingPick<bool>('cutawayOpponent', true));
    final fast = ref.watch(settingPick<bool>('matchSpeedFast', false));
    final hard = ref.watch(settingPick<bool>('hardMode', false));
    final proUnlocked = ref.watch(proModeUnlockedProvider);
    return [
      SettingsCard(
        children: [
          // TWO FLAGS drawn as one pair, not one choice out of two: the cutaway
          // can be on for both sides, one, or neither, and the JS's own buttons
          // toggle their own key each.
          SettingsRow(
            icon: 'video',
            // **NOT "2D PITCH VIEW" ANY MORE.** The pitch is always there —
            // `CutawayStage` draws the markings and twenty-two bodies for the
            // whole ninety minutes, and has since the band stopped flickering
            // in and out. What these two switch is whether a CHANCE cuts away
            // and is retold on it, which is also what decides whether that
            // moment can be replayed afterwards. Reported from the couch: the
            // name describes something that is no longer a choice.
            label: t('settings.cutaways'),
            trailing: SettingsSegment(
              key: const ValueKey('setting-pitchView'),
              choices: [
                (
                  label: t('settings.pitchView.ours'),
                  on: ours,
                  onTap: () => writeSetting(ref, 'cutawayOurTeam', !ours),
                  locked: false,
                ),
                (
                  label: t('settings.pitchView.opp'),
                  on: opp,
                  onTap: () => writeSetting(ref, 'cutawayOpponent', !opp),
                  locked: false,
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
                  locked: false,
                ),
                (
                  label: '2×',
                  on: fast,
                  onTap: () => writeSetting(ref, 'matchSpeedFast', true),
                  locked: false,
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
            // **THE NOTE HAS TO SAY THE WORD LOCKED, and it did not.** This
            // printed `prestige.body_pro_hint` — "Or prestige into Pro Mode —
            // fatigue, squad rotation and live subs make it a real test" — on
            // the reasoning that saying the same sentence as the prestige card
            // makes the lock legible. It does not: that line describes what Pro
            // IS, its leading "Or" belongs to the offer it was cut from, and a
            // player reading it under a dead segment learns what they are
            // missing and nothing about how to get it. Reported as the
            // difficulty needing to show that it is locked and what opens it.
            //
            // [proLockedAnswer] is the condition in the game's own shipped
            // words, and the tap adds the description on top of it.
            note: proUnlocked
                ? t('settings.difficulty.hint')
                : proLockedAnswer(),
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
                  locked: false,
                ),
                (
                  label: t('settings.difficulty.hard'),
                  on: hard,
                  // **LOCKED UNTIL THE CHAMPIONS LEAGUE IS WON.** Pro is a
                  // whole second game and offering it in the first minute is
                  // offering a difficulty the player has no way to judge — see
                  // [proModeUnlocked]. The row stays visible and dead rather
                  // than disappearing: a control that is not there answers
                  // nothing, and this one has a reason worth reading.
                  // **A LOCKED TAP ANSWERS.** `null` here meant pressing Pro
                  // did nothing at all, which is how "there is no info on why
                  // pro is locked" happens on a row that prints exactly that
                  // information underneath it. Still not a switch — it cannot
                  // turn Pro on — it says what would.
                  onTap: hard
                      ? null
                      : proUnlocked
                      ? () => _confirmDifficulty(hard: true)
                      : () => emit('prestige:locked'),
                  // A padlock ON the button. The row's note says why, and a
                  // note under a control nobody has worked out is locked is a
                  // sentence nobody reads.
                  locked: !proUnlocked,
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

  Map<String, dynamic>? _map(Object? v) =>
      v is Map<String, dynamic> ? v : null;

  /// Opted out is the only stored `false`; anything else is a save that has
  /// never been asked, and the JS defaults those to visible.
  bool _rankingsVisible(Map<String, dynamic>? save) =>
      _map(save?['leaderboard'])?['rankingsVisible'] != false;

  /// Opt in or out of the public boards.
  ///
  /// **The preference lands first and the server is told second**, because the
  /// two can disagree: a hide that never leaves the device is repaired on the
  /// next signed-in boot by `ensureLeaderboardOptOutApplied`, and the direction
  /// that matters is somebody who asked not to be listed still being listed.
  ///
  /// **Opting out HIDES rather than deletes.** Scores keep accruing so the
  /// rolling windows stay correct, and opting back in re-lists the same rows
  /// with nothing lost.
  void _setRankingsVisible(bool value) {
    final game = ref.read(gameProvider);
    game.update((s) {
      final board = _map(s['leaderboard']);
      if (board != null) board['rankingsVisible'] = value;
    });
    final state = game.state;
    if (state != null) {
      unawaited(setLeaderboardListed(state, listed: value));
    }
  }

  /// Open the sheet, or sign out. **The signed-out half is a QUESTION and the
  /// signed-in half is not** — connecting picks a provider, disconnecting has
  /// nothing to pick — so one is a sheet and the other happens where it is
  /// tapped, which is the JS's arrangement too.
  Future<void> _toggleAccount(bool signedIn) async {
    final game = ref.read(gameProvider);
    final state = game.state;
    if (state == null) return;
    if (signedIn) {
      AuthService.instance.signOut(state);
      // The save moved underneath the tab, which reads it.
      game.update((_) {});
      emit('toast:info', t('auth.signed_out'));
      return;
    }
    await showConnectAccountSheet(context);
  }

  List<Widget> _account() {
    // **The tab REDRAWS when the save moves.** `gameProvider` hands back the
    // same object however much the map inside it changes, so a screen watching
    // it alone holds whatever it read on the frame it opened — which is why
    // signing in left the row still saying nobody was. Every other live value
    // in the app reaches a widget through `savePick`, which watches this.
    ref.watch(saveRevisionProvider);
    final save = ref.watch(gameProvider).state;
    final signedIn = isSignedInLocal(save);
    final accountName = _map(save?['leaderboard'])?['accountName'];
    return [
    SettingsCard(
      children: [
        // **IT SIGNS IN NOW.** Twenty-six `auth.*` strings ship in ten
        // languages and exactly one had a caller, because the row had no route
        // behind it: `isSignedInLocal` answered off the save, which with no
        // plugin meant nobody was ever signed in and the row could only say so.
        // `services/auth_service.dart` is that plugin — Google and Apple hand
        // back an OAuth token and Identity Toolkit mints the Firebase session
        // over the same REST transport the leaderboard already uses.
        SettingsRow(
          key: const ValueKey('sign-in-btn'),
          icon: 'globe',
          label: t('auth.account_connection'),
          // Signed in, the useful line is WHO — an account row that says
          // "connected" and not to what is the same row twice.
          note: signedIn
              ? (accountName is String && accountName.isNotEmpty
                    ? accountName
                    : t('auth.connected'))
              : t('auth.connect_tap'),
          onTap: () => _toggleAccount(signedIn),
          trailing: Text(
            signedIn ? t('auth.sign_out') : t('auth.not_signed_in'),
            style: TextStyle(
              color: Theme.of(context).extension<KitTheme>()!.accentBright,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // The JS disables this one whenever nobody is signed in, which is now a
        // state a player can leave rather than the only one there is.
        SettingsRow(
          icon: 'trophy',
          label: t('leaderboard.rankings_visible'),
          note: signedIn ? null : t('auth.settings_hint'),
          trailing: SettingsToggle(
            key: const ValueKey('setting-rankingsVisible'),
            value: _rankingsVisible(save),
            onChanged: signedIn ? _setRankingsVisible : null,
          ),
        ),
      ],
    ),
    // **NO "SEND FEEDBACK" ROW, and that is the port catching up with the
    // spec.** It was a `PendingControl` saying "coming soon" — but the JS
    // HIDES its own button rather than disabling it, because the feature is
    // whole on the client and waiting on `submitFeedback` being deployed and
    // made publicly callable. See `services/feedback_service.dart`. So the port
    // was advertising a control the shipped game does not show; reported as
    // wanting it gone, which is what the JS already does.
    //
    // `flushFeedbackQueue` stays wired at boot either way — a queue drained
    // only by the release that unhides the button strands whatever the last one
    // put in it.
    ];
  }
}

/// Write the theme choice, and keep the legacy flag honest beside it.
///
/// `lightMode` is the key every save already carries and the only one the web
/// build reads, so it is written with the RESOLVED answer — `system` has no
/// boolean of its own, and leaving the old key stale would give a save moved
/// between the two builds a theme its owner never picked.
void _setTheme(WidgetRef ref, ThemeChoice choice) {
  writeSetting(ref, 'themeMode', choice.name);
  writeSetting(
    ref,
    'lightMode',
    switch (choice) {
      ThemeChoice.light => true,
      ThemeChoice.dark => false,
      ThemeChoice.system =>
        ref.read(systemBrightnessProvider) == Brightness.light,
    },
  );
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
        // **THE CLIP IS INSIDE THE RIM, not on the box.** `clipBehavior` on the
        // `Container` clips to the OUTSIDE of its own border, so the active
        // tab's full-bleed accent fill painted straight over the 1px rim at both
        // ends of the strip — invisible in dark mode and, against a white
        // border, reported as the selected button eating the corner. A
        // `ClipRRect` one radius in cuts the fill at the rim instead; the
        // `Container` already insets its child by the border's width, so the
        // two line up.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
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
                fontSize: 12,
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

/// The tick on a reset card: run the tutorial on the fresh save or skip it.
///
/// A row rather than a `CheckboxListTile`: Colin's card is not a settings page
/// and a Material tile brings its own metrics, its own ripple and its own
/// leading column to a body that is otherwise one sentence.
class _TutorialTick extends StatelessWidget {
  const _TutorialTick({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return InkWell(
      key: const ValueKey('reset-show-tutorial'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value ? kit.accentBright : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: value ? kit.accentBright : kit.border,
                  width: 1.5,
                ),
              ),
              child: value
                  ? Icon(Icons.check, size: 14, color: kit.accentBrightInk)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kit.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
