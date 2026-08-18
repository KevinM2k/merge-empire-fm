import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/providers/game_host.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/prefs_save_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The store is read into memory before the first frame: everything
  // downstream of it is synchronous, and a save layer that answers null while
  // it warms up would boot the player onto a default state.
  final store = await PrefsSaveStore.open();
  runApp(
    ProviderScope(
      overrides: [saveStoreProvider.overrideWithValue(store)],
      child: const MergeEmpireApp(),
    ),
  );
}

class MergeEmpireApp extends StatelessWidget {
  const MergeEmpireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Merge Empire Football Manager',
      home: GameHost(
        child: Scaffold(body: SafeArea(child: _Placeholder())),
      ),
    );
  }
}

/// Stands in until M3. It watches two derived providers rather than the save,
/// which is the pattern every real screen follows.
class _Placeholder extends ConsumerWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ref.watch(clubNameProvider)),
          Text('${ref.watch(coinsProvider)}'),
        ],
      ),
    );
  }
}
