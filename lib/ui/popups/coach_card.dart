/// Coach Colin's card — one of the three popup shapes.
///
/// A centred dialog with a title, a body and a row of actions. Used for a tip,
/// a confirmation, or anything that wants the player to read one thing and
/// choose.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class CoachAction {
  const CoachAction({
    required this.labelKey,
    required this.onTap,
    this.destructive = false,
  });

  final String labelKey;
  final VoidCallback onTap;

  /// Reset and full reset. Painted apart so a tap is a decision.
  final bool destructive;
}

Future<T?> showCoachCard<T>(
  BuildContext context, {
  required String titleKey,
  required String bodyKey,
  List<CoachAction> actions = const [],
  Map<String, Object?> bodyParams = const {},
}) {
  final kit = Theme.of(context).extension<KitTheme>()!;
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('coach-card'),
      backgroundColor: kit.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kit.border),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: kit.accent,
            child: Icon(Icons.sports, size: 16, color: kit.accentInk),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(t(titleKey))),
        ],
      ),
      content: Text(t(bodyKey, bodyParams), style: TextStyle(color: kit.textMuted)),
      actions: [
        for (final action in actions)
          TextButton(
            key: ValueKey('coach-action-${action.labelKey}'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              action.onTap();
            },
            child: Text(
              t(action.labelKey),
              style: TextStyle(
                color: action.destructive ? Colors.redAccent : kit.accent,
              ),
            ),
          ),
      ],
    ),
  );
}
