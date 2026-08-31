import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/recycle_bin_provider.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<RecycleBinProvider>().load(),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'sale':
        return Icons.receipt_long_outlined;
      case 'purchase':
        return Icons.shopping_bag_outlined;
      case 'party':
        return Icons.people_outline;
      case 'expense':
        return Icons.receipt_outlined;
      case 'product':
        return Icons.inventory_2_outlined;
      case 'quotation':
        return Icons.description_outlined;
      case 'bank_account':
        return Icons.account_balance_outlined;
      case 'bank_transaction':
        return Icons.swap_horiz;
      default:
        return Icons.delete_outline;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'sale':
        return AppColors.orange;
      case 'purchase':
        return AppColors.info;
      case 'party':
        return AppColors.navy600;
      case 'expense':
        return AppColors.error;
      case 'product':
        return AppColors.warning;
      case 'quotation':
        return AppColors.navy400;
      case 'bank_account':
      case 'bank_transaction':
        return AppColors.success;
      default:
        return AppColors.navy400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rb = context.watch<RecycleBinProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: const [HomeLogoButton()],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ResponsiveBody(
        child: rb.isLoading && rb.items.isEmpty
            ? const LoadingView()
            : RefreshIndicator(
                onRefresh: () => context.read<RecycleBinProvider>().load(),
                child: rb.items.isEmpty
                    ? const EmptyState(
                        icon: Icons.delete_outline,
                        title: 'Recycle bin is empty',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: rb.items
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppCard(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _colorFor(
                                            item.type,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconFor(item.type),
                                          color: _colorFor(item.type),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.label,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Deleted ${Formatters.dateShort(item.deletedAt)}',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.restore,
                                          color: AppColors.success,
                                        ),
                                        tooltip: 'Restore',
                                        onPressed: () => context
                                            .read<RecycleBinProvider>()
                                            .restore(item.type, item.id),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_forever,
                                          color: AppColors.error,
                                        ),
                                        tooltip: 'Delete Forever',
                                        onPressed: () async {
                                          final provider = context
                                              .read<RecycleBinProvider>();
                                          final confirmed =
                                              await showDeleteConfirmDialog(
                                                context,
                                                title: 'Delete permanently?',
                                                message:
                                                    'This cannot be undone.',
                                                confirmLabel: 'Delete Forever',
                                              );
                                          if (confirmed) {
                                            provider.permanentlyDelete(
                                              item.type,
                                              item.id,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
      ),
    );
  }
}
