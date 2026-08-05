import 'package:flutter/material.dart';

/// Wraps a Scaffold's `body:` so page content is centered and capped in
/// width on tablet/desktop screens instead of stretching edge-to-edge.
/// A no-op below the tablet breakpoint (phones render exactly as before).
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
