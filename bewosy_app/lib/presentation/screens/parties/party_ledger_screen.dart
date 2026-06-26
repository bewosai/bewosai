import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';

class PartyLedgerScreen extends StatefulWidget {
  final Map<String, dynamic> party;

  const PartyLedgerScreen({super.key, required this.party});

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String _filterType = 'ALL';

  static const _typeColors = {
    'SALE': AppColors.info,
    'RECEIPT': AppColors.success,
    'PURCHASE': Color(0xFF7C3AED),
    'PAYMENT': AppColors.warning,
    'PAYMENT_IN': AppColors.success,
    'PAYMENT_OUT': AppColors.error,
    'OPENING': AppColors.navy500,
  };

  static const _typeIcons = {
    'SALE': Icons.receipt_long_rounded,
    'RECEIPT': Icons.arrow_downward_rounded,
    'PURCHASE': Icons.local_shipping_rounded,
    'PAYMENT': Icons.payments_rounded,
    'PAYMENT_IN': Icons.arrow_downward_rounded,
    'PAYMENT_OUT': Icons.arrow_upward_rounded,
    'OPENING': Icons.account_balance_wallet_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final id = widget.party['id'];
      final res = await api.get('/parties/$id/ledger/');
      final data = res.data as Map<String, dynamic>? ?? {};
      _entries = List<Map<String, dynamic>>.from(
          (data['entries'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
      _summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterType == 'ALL') return _entries;
    return _entries.where((e) => e['type'] == _filterType).toList();
  }

  double get _totalDebit =>
      _summary?['total_debit'] != null
          ? double.tryParse(_summary!['total_debit'].toString()) ?? 0
          : 0;

  double get _totalCredit =>
      _summary?['total_credit'] != null
          ? double.tryParse(_summary!['total_credit'].toString()) ?? 0
          : 0;

  double get _balance =>
      _summary?['balance'] != null
          ? double.tryParse(_summary!['balance'].toString()) ?? 0
          : 0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final party = widget.party;
    final isCustomer = (party['party_type'] ?? '').toString() == 'CUSTOMER';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              party['name']?.toString() ?? 'Ledger',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              isCustomer ? 'Customer Ledger' : 'Supplier Ledger',
              style: const TextStyle(fontSize: 11, color: AppColors.navy500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(settings),
                _buildFilterChips(),
                Expanded(child: _buildLedgerList(settings)),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(AppSettings settings) {
    final balanceColor = _balance >= 0 ? AppColors.success : AppColors.error;
    final balanceLabel = _balance >= 0 ? 'To Receive' : 'To Pay';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy900, AppColors.navy700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(children: [
            _SummaryTile(
              label: 'Total Debit',
              value: settings.formatAmount(_totalDebit),
              color: AppColors.error,
              icon: Icons.arrow_upward_rounded,
            ),
            Container(width: 1, height: 40, color: Colors.white12),
            _SummaryTile(
              label: 'Total Credit',
              value: settings.formatAmount(_totalCredit),
              color: AppColors.success,
              icon: Icons.arrow_downward_rounded,
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: balanceColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: balanceColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  balanceLabel,
                  style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                Text(
                  settings.formatAmount(_balance.abs()),
                  style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const types = ['ALL', 'SALE', 'RECEIPT', 'PURCHASE', 'PAYMENT_IN', 'PAYMENT_OUT'];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: types.length,
        itemBuilder: (ctx, i) {
          final type = types[i];
          final selected = _filterType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(type == 'ALL' ? 'All' : _typeLabel(type)),
              selected: selected,
              onSelected: (_) => setState(() => _filterType = type),
              selectedColor: AppColors.orange.withOpacity(0.15),
              checkmarkColor: AppColors.orange,
              labelStyle: TextStyle(
                color: selected ? AppColors.orange : AppColors.navy500,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected ? AppColors.orange : AppColors.lightBorder,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLedgerList(AppSettings settings) {
    final entries = _filtered;
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 48, color: AppColors.navy500),
            SizedBox(height: 12),
            Text('No ledger entries',
                style: TextStyle(color: AppColors.navy500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (ctx, i) => _LedgerEntryTile(
          entry: entries[i],
          settings: settings,
          typeColors: _typeColors,
          typeIcons: _typeIcons,
          typeLabel: _typeLabel,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'SALE' => 'Sale',
      'RECEIPT' => 'Receipt',
      'PURCHASE' => 'Purchase',
      'PAYMENT' => 'Payment',
      'PAYMENT_IN' => 'Payment In',
      'PAYMENT_OUT' => 'Payment Out',
      'OPENING' => 'Opening',
      _ => type,
    };
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final AppSettings settings;
  final Map<String, Color> typeColors;
  final Map<String, IconData> typeIcons;
  final String Function(String) typeLabel;

  const _LedgerEntryTile({
    required this.entry,
    required this.settings,
    required this.typeColors,
    required this.typeIcons,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final type = entry['type']?.toString() ?? '';
    final color = typeColors[type] ?? AppColors.navy500;
    final icon = typeIcons[type] ?? Icons.circle_outlined;
    final debit =
        double.tryParse(entry['debit']?.toString() ?? '0') ?? 0;
    final credit =
        double.tryParse(entry['credit']?.toString() ?? '0') ?? 0;
    final balance =
        double.tryParse(entry['running_balance']?.toString() ?? '0') ?? 0;
    final ref = entry['reference']?.toString() ?? '';
    final date = entry['date']?.toString() ?? '';
    final note = entry['note']?.toString() ?? '';
    final isDark = settings.isDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel(type),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
                const SizedBox(width: 6),
                if (ref.isNotEmpty)
                  Text('#$ref',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.navy500)),
              ]),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(note,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.navy500)),
              ],
              const SizedBox(height: 2),
              Text(date,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.navy500)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (debit > 0)
              Text(
                '+${settings.formatAmount(debit)}',
                style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            if (credit > 0)
              Text(
                '-${settings.formatAmount(credit)}',
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            const SizedBox(height: 2),
            Text(
              'Bal: ${settings.formatAmount(balance.abs())}',
              style: TextStyle(
                  fontSize: 10,
                  color: balance >= 0 ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ]),
    );
  }
}
