import 'package:flutter/material.dart';

/// A stand-in for the real player card, used to measure frame cost before the
/// full card port in M2. Every card gets its own RepaintBoundary so one card
/// animating does not repaint the whole grid.
///
/// Throwaway: M2 replaces this with the real card.
class ProbeCard extends StatelessWidget {
  const ProbeCard({
    required this.name,
    required this.rating,
    required this.kitColor,
    super.key,
  });

  final String name;
  final int rating;
  final Color kitColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('probe-card-frame'),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: kitColor, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$rating', style: const TextStyle(fontSize: 20)),
            Text(name, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
