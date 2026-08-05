import 'package:flutter/material.dart';

/// A grid that auto-fits its column count to the actual screen width instead
/// of using a hardcoded [columns] value everywhere. [columns] is the number
/// of tiles you want on a "normal" ~400dp-wide phone; narrower phones (e.g.
/// iPhone SE) naturally get slightly narrower tiles at the same column count,
/// and wider phones/tablets pick up extra columns automatically — so the same
/// call site looks right on every device without per-screen breakpoint logic.
class ResponsiveGrid extends StatelessWidget {
  final int columns;
  final double spacing;
  final double childAspectRatio;
  final List<Widget> children;
  static const double _referenceWidth = 400;

  const ResponsiveGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = 12,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _referenceWidth / columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, i) => children[i],
    );
  }
}
