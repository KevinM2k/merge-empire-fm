/// A sheet's FRAME follows the theme, including one that arrives after it has
/// already been pushed.
///
/// The boot frame builds `MaterialApp` before the save has loaded, so
/// `themeChoiceProvider` has no settings to read and answers LIGHT for
/// everyone. The daily reward is queued on that same frame and drains in a
/// microtask before the app rebuilds on the loaded save — so a dark-mode player
/// got the reward as a white frame and a pale grabber around dark contents.
///
/// The frame's colours used to be read at the CALL, outside
/// `showModalBottomSheet`'s builder, which froze that pre-load light surface
/// for the life of the sheet. Read inside the builder they follow the theme,
/// because `BottomSheet` re-invokes it on every tick of the theme change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The colour the sheet's own frame is painted in.
Color frameColour(WidgetTester tester) {
  final box = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(const ValueKey('bottom-sheet-popup')),
          matching: find.byType(Container),
        )
        .first,
  );
  return ((box.decoration! as BoxDecoration).color)!;
}

/// A page whose theme can be flipped from outside, the way the boot frame's is
/// when the save finally lands.
///
/// Flipped through its key rather than a button: a tap while the sheet is up
/// lands on the modal barrier and closes it.
final flip = GlobalKey<_FlippableState>();

class _Flippable extends StatefulWidget {
  const _Flippable({super.key});

  @override
  State<_Flippable> createState() => _FlippableState();
}

class _FlippableState extends State<_Flippable> {
  bool light = true;

  void goDark() => setState(() => light = false);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: light),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showBottomSheetPopup<void>(
            context,
            child: const SizedBox(height: 120, child: Text('body')),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the frame is the theme it was opened in', (tester) async {
    await tester.pumpWidget(_Flippable(key: flip));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final light = buildAppTheme(kitId: '#4caf50', light: true)
        .extension<KitTheme>()!;
    expect(frameColour(tester), light.surface);
  });

  testWidgets('AND IT FOLLOWS A THEME THAT ARRIVES AFTER IT IS UP', (
    tester,
  ) async {
    // The boot case: the sheet is pushed on the pre-load LIGHT theme, and the
    // save lands a frame later and turns everything dark.
    await tester.pumpWidget(_Flippable(key: flip));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    flip.currentState!.goDark();
    await tester.pumpAndSettle();

    final dark = buildAppTheme(kitId: '#4caf50', light: false)
        .extension<KitTheme>()!;
    expect(
      frameColour(tester),
      dark.surface,
      reason: 'a frame read at the call site freezes the light surface',
    );
  });
}
