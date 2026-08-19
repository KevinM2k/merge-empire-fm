/// The Training Ground, as a quick-nav sheet.
///
/// It was a sub-tab across the top of the home screen. Training is somewhere
/// you go to spend a few minutes and then leave, not somewhere you live, so it
/// sits behind the burger with the rest of the destinations.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_view.dart';

Future<void> showTrainingSheet(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.85,
      child: const TrainingView(),
    );
