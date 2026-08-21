/// The Training Ground, as a quick-nav sheet.
///
/// It was a sub-tab across the top of the home screen. Training is somewhere
/// you go to spend a few minutes and then leave, not somewhere you live, so it
/// sits behind the burger with the rest of the destinations.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_view.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Future<void> showTrainingSheet(BuildContext context) async {
  await showBottomSheetPopup<void>(
    context,
    heightFraction: 0.85,
    child: const TrainingView(),
  );
  // **On the way OUT, not the way in.** The JS fires its coach tip when you land
  // on the training sub-tab; here training is a sheet, and a tip that opened
  // over the sheet explaining the sheet would be covering the thing it is about.
  // Announced as it closes, so Colin's piece lands on the screen behind it.
  emit('nav:subtab', 'minigames');
}
