import 'package:flutter/material.dart';

void main() => runApp(const MergeEmpireApp());

class MergeEmpireApp extends StatelessWidget {
  const MergeEmpireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Merge Empire FC',
      home: Scaffold(body: Center(child: Text('Merge Empire FC'))),
    );
  }
}
