import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'empty_state.dart';

export 'app_card.dart';
export 'status_badge.dart';
export 'empty_state.dart';
export 'kpi_card.dart';
export 'primary_button.dart';
export 'delete_confirm_dialog.dart';
export 'responsive_grid.dart';
export 'responsive_body.dart';
export 'home_logo_button.dart';
export 'app_bottom_nav.dart';
export 'feature_gate.dart';
export 'sheet_header.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.2)),
        ?trailing,
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const SearchField({super.key, this.hint = 'Search...', required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.navy300),
        isDense: true,
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
}

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  const AppFilterChip({super.key, required this.label, required this.selected, required this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.orangeGradient : null,
            color: selected ? null : AppColors.navy50,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: Text(
            count != null ? '$label ($count)' : label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.navy900,
    ),
  );
}

class SearchSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T) subtitleBuilder;
  final ValueChanged<T> onSelected;
  final bool allowClear;
  final VoidCallback? onClear;
  final String clearLabel;
  final VoidCallback? onAddNew;
  final String addNewLabel;
  /// When set, replaces the plain title/subtitle ListTile for each row with
  /// a richer custom layout (e.g. the product picker showing category,
  /// stock and price) — [onSelected]/[labelBuilder] still drive search
  /// filtering and the tap action either way.
  final Widget Function(BuildContext, T)? detailBuilder;

  const SearchSheet({
    super.key,
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.onSelected,
    this.allowClear = false,
    this.onClear,
    this.clearLabel = 'Walk-in Customer',
    this.onAddNew,
    this.addNewLabel = 'Add New',
    this.detailBuilder,
  });

  @override
  State<SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<SearchSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((i) => widget.labelBuilder(i).toLowerCase().contains(_query.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  SearchField(onChanged: (v) => setState(() => _query = v)),
                ],
              ),
            ),
            if (widget.onAddNew != null)
              ListTile(
                leading: const Icon(Icons.add_circle_outline, color: AppColors.orange),
                title: Text(widget.addNewLabel, style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddNew!();
                },
              ),
            if (widget.allowClear)
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: Text(widget.clearLabel),
                onTap: () {
                  widget.onClear?.call();
                  Navigator.pop(context);
                },
              ),
            if (widget.onAddNew != null || widget.allowClear) const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(icon: Icons.search_off, title: 'No results')
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        void onTap() {
                          widget.onSelected(item);
                          Navigator.pop(context);
                        }
                        if (widget.detailBuilder != null) {
                          return InkWell(
                            onTap: onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: widget.detailBuilder!(ctx, item),
                            ),
                          );
                        }
                        return ListTile(
                          title: Text(widget.labelBuilder(item)),
                          subtitle: Text(widget.subtitleBuilder(item)),
                          onTap: onTap,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppSectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const AppSectionCard({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.navy900.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2)),
            const SizedBox(height: 14),
          ],
          ...children,
        ],
      ),
    );
  }
}
