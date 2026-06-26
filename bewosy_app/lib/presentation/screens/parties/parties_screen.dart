import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_widgets.dart';
import 'party_ledger_screen.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});
  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _customers = [];
  List _suppliers = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    try {
      final r1 = await api.get('/parties/', params: {'party_type': 'CUSTOMER'});
      final r2 = await api.get('/parties/', params: {'party_type': 'SUPPLIER'});
      _customers = (r1.data as List?) ?? [];
      _suppliers = (r2.data as List?) ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List _filter(List list) {
    if (_search.isEmpty) return list;
    final q = _search.toLowerCase();
    return list
        .where((p) =>
            (p['name'] ?? '').toString().toLowerCase().contains(q) ||
            (p['phone'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('parties'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: settings.t('search'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showAddPartySheet(context, settings),
        icon: const Icon(Icons.add_rounded),
        label: Text(settings.t('new_party')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TabBar(
                  controller: _tabs,
                  labelColor: AppColors.orange,
                  unselectedLabelColor: AppColors.navy500,
                  indicatorColor: AppColors.orange,
                  tabs: [
                    Tab(
                        icon: const Icon(Icons.person_rounded, size: 18),
                        text: settings.t('customers')),
                    Tab(
                        icon: const Icon(Icons.business_rounded, size: 18),
                        text: settings.t('suppliers')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _PartyList(
                          items: _filter(_customers),
                          settings: settings,
                          type: 'CUSTOMER',
                          onRefresh: _fetch),
                      _PartyList(
                          items: _filter(_suppliers),
                          settings: settings,
                          type: 'SUPPLIER',
                          onRefresh: _fetch),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddPartySheet(BuildContext context, AppSettings settings) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String partyType = 'CUSTOMER';
    String customerType = 'RETAIL';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(settings.t('new_party'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                // Type toggle
                Row(children: [
                  for (final t in [
                    ('CUSTOMER', settings.t('customer'), Icons.person_rounded),
                    ('SUPPLIER', settings.t('supplier'), Icons.business_rounded),
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ss(() => partyType = t.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: partyType == t.$1
                                ? AppColors.orange
                                : Colors.transparent,
                            border: Border.all(
                              color: partyType == t.$1
                                  ? AppColors.orange
                                  : AppColors.lightBorder,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(t.$3,
                                  size: 16,
                                  color: partyType == t.$1
                                      ? Colors.white
                                      : AppColors.navy500),
                              const SizedBox(width: 6),
                              Text(t.$2,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: partyType == t.$1
                                        ? Colors.white
                                        : AppColors.navy500,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_rounded)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.mail_outline_rounded)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_rounded)),
                  maxLines: 2,
                ),
                if (partyType == 'CUSTOMER') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: customerType,
                    decoration:
                        const InputDecoration(labelText: 'Customer Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'RETAIL', child: Text('Retail')),
                      DropdownMenuItem(
                          value: 'WHOLESALE', child: Text('Wholesale')),
                      DropdownMenuItem(
                          value: 'DISTRIBUTOR',
                          child: Text('Distributor')),
                      DropdownMenuItem(
                          value: 'RESELLER', child: Text('Reseller')),
                    ],
                    onChanged: (v) => ss(() => customerType = v!),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: settings.t('save'),
                  loading: saving,
                  onPressed: saving
                      ? null
                      : () async {
                          ss(() => saving = true);
                          try {
                            await context.read<ApiService>().post(
                              '/parties/',
                              data: {
                                'name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'address': addressCtrl.text.trim(),
                                'party_type': partyType,
                                if (partyType == 'CUSTOMER')
                                  'customer_type': customerType,
                              },
                            );
                            if (context.mounted) {
                              Navigator.pop(ctx2);
                              _fetch();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          }
                          ss(() => saving = false);
                        },
                  icon: Icons.check_rounded,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyList extends StatelessWidget {
  final List items;
  final AppSettings settings;
  final String type;
  final VoidCallback onRefresh;
  const _PartyList(
      {required this.items,
      required this.settings,
      required this.type,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: type == 'CUSTOMER'
            ? Icons.people_rounded
            : Icons.business_rounded,
        message: settings.t('no_data'),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final p = items[i];
          final balance =
              double.tryParse(p['balance']?.toString() ?? '0') ?? 0;
          return AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: type == 'CUSTOMER'
                    ? AppColors.orange.withOpacity(0.15)
                    : AppColors.info.withOpacity(0.15),
                child: Text(
                  (p['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: type == 'CUSTOMER'
                        ? AppColors.orange
                        : AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'] ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Row(children: [
                      if (p['phone'] != null && p['phone'] != '') ...[
                        const Icon(Icons.phone_rounded,
                            size: 12, color: AppColors.navy500),
                        const SizedBox(width: 3),
                        Text(p['phone'],
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.navy500)),
                      ],
                      if (p['customer_type'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.navy50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(p['customer_type'],
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.navy500)),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    settings.formatAmount(balance.abs()),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: balance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                  Text(
                    balance > 0
                        ? 'Receivable'
                        : (balance < 0 ? 'Payable' : 'Settled'),
                    style: TextStyle(
                      fontSize: 10,
                      color: balance > 0
                          ? AppColors.error
                          : (balance < 0
                              ? AppColors.warning
                              : AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => PartyLedgerScreen(party: Map<String, dynamic>.from(p as Map)),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(children: [
                        Icon(Icons.book_rounded,
                            size: 12, color: AppColors.orange),
                        SizedBox(width: 4),
                        Text('Ledger',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.orange,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }
}
