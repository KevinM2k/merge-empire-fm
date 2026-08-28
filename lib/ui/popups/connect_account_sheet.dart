/// The Connect Account sheet, ported from
/// `../merge-empire-fc/src/ui/components/ConnectAccountModal.js` and its
/// `AuthButtons.js`.
///
/// **These two buttons are the one place in the app that does NOT wear the
/// game's own button.** Everything else goes through `StoreButton` or the
/// moulded Material style — see `mouldedButtonStyle` — and both Google and
/// Apple publish layout rules for their sign-in buttons that a moulded gold
/// pill would break. The JS says the same thing in its own first line and
/// inline-styles them past its global button reset; here they are simply not
/// [StoreButton]s.
///
/// **Apple is hidden on Android and nowhere else.** That is `showAppleSignInButton`
/// in the JS, and it is Apple's rule rather than a product decision.
///
/// The copy is all shipped: twenty-six `auth.*` keys in ten languages, of which
/// one had a caller before the sign-in route existed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/auth_service.dart';
import 'package:merge_empire_fc/services/cloud_sync.dart';
import 'package:merge_empire_fc/services/platform_seams.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The JS's own `TERMS_URL`.
const String termsUrl = 'https://www.mergeempirefc.co.uk/terms-of-service.html';

/// Google's four-colour G, verbatim from `AuthButtons.js`.
const String _googleG =
    '<svg viewBox="0 0 48 48">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';

/// Apple's mark. The JS draws it in `currentColor`; the button is black, so the
/// colour is stated rather than inherited.
const String _appleLogo =
    '<svg viewBox="0 0 24 24">'
    '<path fill="#FFFFFF" d="M17.05 20.28c-.98.95-2.05.88-3.08.4-1.09-.5-2.08-.48-3.24 0-1.44.62-2.2.44-3.06-.4C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>'
    '</svg>';

/// Open the sheet. Resolves true when somebody signed in.
Future<bool> showConnectAccountSheet(BuildContext context) async {
  final signedIn = await showBottomSheetPopup<bool>(
    context,
    heightFraction: 0.5,
    child: const _ConnectBody(),
  );
  return signedIn ?? false;
}

class _ConnectBody extends ConsumerStatefulWidget {
  const _ConnectBody();

  @override
  ConsumerState<_ConnectBody> createState() => _ConnectBodyState();
}

class _ConnectBodyState extends ConsumerState<_ConnectBody> {
  /// **One at a time, and both buttons go dead.** The JS disables the button it
  /// was told to; a second provider tapped while the first is mid-flight is two
  /// sign-ins racing for one save, so the whole pair waits.
  bool _busy = false;

  Future<void> _signIn(String provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    final game = ref.read(gameProvider);
    final state = game.state;
    if (state == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      await AuthService.instance.signIn(state, provider: provider);
      // The save changed underneath the settings screen, which reads it.
      game.update((_) {});
      if (!mounted) return;
      emit('toast:success', t('auth.sign_in_success'));
      Navigator.of(context).pop(true);
      // **THE CLOUD IS RECONCILED AFTER THE SHEET IS GONE, not before.** The
      // sync can put a conflict card up, and a second route arriving on top of
      // the one being dismissed is how a decision ends up behind a sheet
      // nobody can see. The JS defers it for the same reason and says so.
      unawaited(runCloudBootSync(game));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      emit('toast:error', t(authErrorKey(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ListView(
      key: const ValueKey('connect-account-sheet'),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        SheetHeader(title: t('auth.connect_account'), padding: EdgeInsets.zero),
        const SizedBox(height: 12),
        Text(
          t('auth.connect_lead'),
          style: TextStyle(color: kit.textMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 18),
        if (AuthService.appleAvailable) ...[
          _BrandButton(
            buttonKey: const ValueKey('auth-apple'),
            label: t('auth.sign_in_apple'),
            logo: _appleLogo,
            face: const Color(0xFF000000),
            ink: Colors.white,
            border: const Color(0xFF000000),
            onTap: _busy ? null : () => _signIn('apple'),
          ),
          const SizedBox(height: 10),
        ],
        _BrandButton(
          buttonKey: const ValueKey('auth-google'),
          label: t('auth.sign_in_google'),
          logo: _googleG,
          face: const Color(0xFFFFFFFF),
          ink: const Color(0xFF1F1F1F),
          border: const Color(0xFFDADCE0),
          onTap: _busy ? null : () => _signIn('google'),
        ),
        const SizedBox(height: 14),
        // The JS's terms line: a sentence with the link inside it. A `String`
        // cannot carry a link, so the two halves are two spans of one
        // paragraph rather than a line and a button under it.
        Text.rich(
          TextSpan(
            style: TextStyle(color: kit.textMuted, fontSize: 11, height: 1.5),
            children: [
              TextSpan(text: '${t('auth.terms_prefix')} '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  key: const ValueKey('auth-terms'),
                  onTap: () => openExternalUrl(termsUrl),
                  child: Text(
                    t('auth.terms_link'),
                    style: TextStyle(
                      color: kit.accentBright,
                      fontSize: 11,
                      height: 1.5,
                      decoration: TextDecoration.underline,
                      decorationColor: kit.accentBright,
                    ),
                  ),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A sign-in button in its provider's own livery.
class _BrandButton extends StatelessWidget {
  const _BrandButton({
    required this.buttonKey,
    required this.label,
    required this.logo,
    required this.face,
    required this.ink,
    required this.border,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final String logo;
  final Color face;
  final Color ink;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      key: buttonKey,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: face,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E3C4043),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 18, height: 18, child: SvgArt(svg: logo)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
