import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import 'reports_screen.dart';

class _PopularReport {
  final String label;
  final String desc;
  final IconData icon;
  final int tabIndex;
  const _PopularReport(this.label, this.desc, this.icon, this.tabIndex);
}

class _ReportCategory {
  final String label;
  final IconData icon;
  final List<int> tabIndexes;
  const _ReportCategory(this.label, this.icon, this.tabIndexes);
}

/// Reports entry point reached from Settings → View Report: a Popular Reports
/// grid plus a Browse All Reports category list, both deep-linking into
/// [ReportsScreen]'s tabs (indexes must match `kReportTabs` there).
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  static const _popular = [
    _PopularReport('Stock Report', 'Product-wise stock valuation', Icons.inventory_2_outlined, 2),
    _PopularReport('Sales Report', 'Detailed invoice list', Icons.point_of_sale, 4),
    _PopularReport('Day Book', 'Daily cash register', Icons.book_outlined, 6),
    _PopularReport('All Transaction Report', 'Every transaction, one feed', Icons.receipt_long_outlined, 7),
    _PopularReport('Profit & Loss Report', 'Revenue, COGS, net profit', Icons.trending_up, 1),
    _PopularReport('Party Statement', 'Per-party running ledger', Icons.people_outline, 8),
    _PopularReport('Cash In Hand Statement', 'Running cash balance', Icons.account_balance_wallet_outlined, 9),
    _PopularReport('Bank Statement', 'Per-account running balance', Icons.account_balance_outlined, 10),
  ];

  static const _categories = [
    _ReportCategory('Transaction Report', Icons.swap_horiz, [7, 4, 6]),
    _ReportCategory('Parties Report', Icons.people_outline, [8, 3]),
    _ReportCategory('Inventory Report', Icons.inventory_2_outlined, [2]),
    _ReportCategory('Income & Expenses Report', Icons.account_balance_wallet_outlined, [1, 5]),
    _ReportCategory('Business Status Report', Icons.insights_outlined, [0, 9]),
  ];

  void _open(BuildContext context, int tabIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportsScreen(initialTabIndex: tabIndex)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Report'), actions: const [HomeLogoButton()]),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Popular Reports'),
            const SizedBox(height: 10),
            ResponsiveGrid(
              columns: 2,
              spacing: 12,
              childAspectRatio: 1.25,
              children: _popular.map((r) => _PopularTile(report: r, onTap: () => _open(context, r.tabIndex))).toList(),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Browse All Reports'),
            const SizedBox(height: 10),
            ..._categories.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CategoryTile(category: c, onSelect: (i) => _open(context, i)),
                )),
          ],
        ),
      ),
    );
  }
}

class _PopularTile extends StatelessWidget {
  final _PopularReport report;
  final VoidCallback onTap;
  const _PopularTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.navy100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(report.icon, size: 18, color: AppColors.orange),
              ),
              const SizedBox(height: 10),
              Text(report.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(report.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final _ReportCategory category;
  final ValueChanged<int> onSelect;
  const _CategoryTile({required this.category, required this.onSelect});

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Icon(widget.category.icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.category.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              Icon(_open ? Icons.expand_less : Icons.expand_more, color: AppColors.navy300),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.category.tabIndexes.map((i) {
              return AppFilterChip(
                label: kReportTabs[i],
                selected: false,
                onTap: () => widget.onSelect(i),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
