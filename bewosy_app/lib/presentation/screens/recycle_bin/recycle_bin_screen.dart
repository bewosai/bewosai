import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_widgets.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});
  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List _items = [];
  bool _loading = true;
  String _selectedType = 'ALL';

  static const _types = ['ALL', 'sale', 'purchase', 'expense', 'party', 'product'];

  static const _typeIcons = <String, IconData>{
    'sale': Icons.receipt_long_rounded,
    'purchase': Icons.local_shipping_rounded,
    'expense': Icons.account_balance_wallet_rounded,
    'party': Icons.people_rounded,
    'product': Icons.inventory_2_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final params = _selectedType == 'ALL'
          ? <String, dynamic>{}
          : {'type': _selectedType};
      final res = await context.read<ApiService>().get('/recycle-bin/', params: params);
      _items = (res.data as List?) ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _restore(Map item) async {
    try {
      await context
          .read<ApiService>()
          .post('/recycle-bin/restore/', data: {
        'type': item['type'],
        'id': item['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restored successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiService.errorMessage(e))));
      }
    }
  }

  Future<void> _permanentDelete(Map item) async {
    final confirm = await showDeleteConfirm(context, permanent: true);
    if (!confirm || !mounted) return;
    try {
      await context
          .read<ApiService>()
          .delete('/recycle-bin/${item['type']}/${item['id']}/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permanently deleted'),
            backgroundColor: AppColors.error,
          ),
        );
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiService.errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('recycle_bin'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      body: Column(
        children: [
          // Type filter
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _types.length,
              itemBuilder: (ctx, i) {
                final type = _types[i];
                final selected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type == 'ALL' ? 'All' : type.capitalize()),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedType = type);
                      _fetch();
                    },
                    selectedColor: AppColors.orange.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.orange : AppColors.navy500,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color:
                          selected ? AppColors.orange : AppColors.lightBorder,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.delete_rounded,
                        message: settings.t('recycle_bin_empty'),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _fetch(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final item = _items[i];
                            final type =
                                item['type']?.toString() ?? 'sale';
                            final icon = _typeIcons[type] ??
                                Icons.delete_rounded;

                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(icon,
                                      color: AppColors.error, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['display_name'] ??
                                            item['name'] ??
                                            item['bill_number'] ??
                                            '—',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                      ),
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.errorLight,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            type.capitalize(),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.error),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Deleted: ${item['deleted_at'] ?? ''}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.navy500),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                                Column(children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.restore_rounded,
                                        color: AppColors.success,
                                        size: 22),
                                    tooltip: settings.t('restore'),
                                    onPressed: () => _restore(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_forever_rounded,
                                        color: AppColors.error,
                                        size: 22),
                                    tooltip:
                                        settings.t('permanent_delete'),
                                    onPressed: () =>
                                        _permanentDelete(item),
                                  ),
                                ]),
                              ]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}
