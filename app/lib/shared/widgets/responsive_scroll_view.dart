import 'package:flutter/material.dart';

/// Standard scrollable page body: centers content and caps its width on
/// tablet/desktop so it doesn't stretch edge-to-edge, with padding that
/// scales with screen size. On phones (<600dp) it behaves like a plain
/// [ListView]. Pass [onRefresh] to get pull-to-refresh for free.
class ResponsiveScrollView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  const ResponsiveScrollView({
    super.key,
    required this.children,
    this.padding,
    this.maxWidth = 720,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final resolvedPadding = padding ?? EdgeInsets.all(isTablet ? 24 : 16);

    final list = ListView(
      padding: resolvedPadding,
      physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
      children: children,
    );

    final constrained = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? maxWidth : double.infinity),
        child: list,
      ),
    );

    return onRefresh != null ? RefreshIndicator(onRefresh: onRefresh!, child: constrained) : constrained;
  }
}
