/// The active locale, bridged to the widget tree.
///
/// `t()` stays a plain synchronous function over a module-scope singleton so the
/// engines and `dart test` can call it. This is the half that makes a change to
/// it rebuild the tree — the same split the save already uses.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';

final localeProvider = NotifierProvider<LocaleNotifier, String>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(saveRevisionProvider);
    final save = ref.watch(gameProvider).state;
    final settings = save?['settings'];
    final stored = settings is Map<String, dynamic> ? settings['locale'] : null;
    // setLocale narrows an unshipped id to English, so read it back rather than
    // trusting what the save held.
    setLocale(stored is String ? stored : null);
    return getLocale();
  }

  /// The Settings picker. Writing the save is what makes the choice survive a
  /// restart; [build] above is what applies it.
  void set(String id) {
    ref.read(gameProvider).update((s) {
      final settings = s['settings'];
      if (settings is Map<String, dynamic>) settings['locale'] = id;
    });
    setLocale(id);
    state = getLocale();
  }
}
