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
      final results = await Future.wait([
        api.get('/parties/', params: {'party_type': 'CUSTOMER', 'is_active': 'true'}),
        api.get('/parties/', params: {'party_type': 'SUPPLIER', 'is_active': 'true'}),
      ]);
      _customers = (results[0].data as List?) ?? [];
      _suppliers = (results[1].data as List?) ?? [];
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
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        heroTag: 'parties_fab',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showPartyForm(context, settings, null),
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
                          onRefresh: _fetch,
                          onEdit: (p) => _showPartyForm(context, settings, p),
                          onDelete: (p) => _confirmDelete(context, p)),
                      _PartyList(
                          items: _filter(_suppliers),
                          settings: settings,
                          type: 'SUPPLIER',
                          onRefresh: _fetch,
                          onEdit: (p) => _showPartyForm(context, settings, p),
                          onDelete: (p) => _confirmDelete(context, p)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> party) async {
    final name = party['name']?.toString() ?? 'this party';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Party', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete "$name"?\n\nThis will soft-delete the party. All past transactions will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<ApiService>().delete('/parties/${party['id']}/');
        _fetch();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$name" deleted'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ApiService.errorMessage(e))));
        }
      }
    }
  }

  void _showPartyForm(BuildContext context, AppSettings settings, Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final nameCtrl        = TextEditingController(text: existing?['name']?.toString() ?? '');
    final phoneCtrl       = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailCtrl       = TextEditingController(text: existing?['email']?.toString() ?? '');
    final addressCtrl     = TextEditingController(text: existing?['address']?.toString() ?? '');
    final panCtrl         = TextEditingController(text: existing?['pan_number']?.toString() ?? '');
    final vatCtrl         = TextEditingController(text: existing?['vat_number']?.toString() ?? '');
    final openingCtrl     = TextEditingController(text: existing?['opening_balance']?.toString() ?? '0');
    final notesCtrl       = TextEditingController(text: existing?['notes']?.toString() ?? '');
    String partyType      = existing?['party_type']?.toString() ?? 'CUSTOMER';
    String customerType   = existing?['customer_type']?.toString() ?? 'RETAIL';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            builder: (_, ctrl) => ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    height: 4, width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(
                  isEdit ? 'Edit Party' : settings.t('new_party'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                // Type toggle — only for new party
                if (!isEdit) ...[
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
                ],
                // Name (required)
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 12),
                // Phone
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_rounded)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                // Email
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.mail_outline_rounded)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                // Address
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_rounded)),
                  maxLines: 2,
                ),
                // Customer type dropdown
                if (partyType == 'CUSTOMER') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: customerType,
                    decoration: const InputDecoration(labelText: 'Customer Type'),
                    items: const [
                      DropdownMenuItem(value: 'RETAIL',      child: Text('Retail')),
                      DropdownMenuItem(value: 'WHOLESALE',   child: Text('Wholesale')),
                      DropdownMenuItem(value: 'DISTRIBUTOR', child: Text('Distributor')),
                      DropdownMenuItem(value: 'RESELLER',    child: Text('Reseller')),
                    ],
                    onChanged: (v) => ss(() => customerType = v!),
                  ),
                ],
                const SizedBox(height: 12),
                // PAN & VAT
                Row(children: [
                  Expanded(child: TextField(
                    controller: panCtrl,
                    decoration: const InputDecoration(
                        labelText: 'PAN Number',
                        prefixIcon: Icon(Icons.badge_outlined)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: vatCtrl,
                    decoration: const InputDecoration(
                        labelText: 'VAT Number',
                        prefixIcon: Icon(Icons.receipt_long_outlined)),
                  )),
                ]),
                const SizedBox(height: 12),
                // Opening balance
                TextField(
                  controller: openingCtrl,
                  decoration: InputDecoration(
                    labelText: 'Opening Balance',
                    prefixText: '${settings.currency} ',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    helperText: 'Positive = they owe you, Negative = you owe them',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
                const SizedBox(height: 12),
                // Notes
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes_rounded)),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: isEdit ? 'Update Party' : settings.t('save'),
                  loading: saving,
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx2).showSnackBar(
                                const SnackBar(content: Text('Name is required')));
                            return;
                          }
                          ss(() => saving = true);
                          try {
                            final api = context.read<ApiService>();
                            final data = <String, dynamic>{
                              'name':             nameCtrl.text.trim(),
                              'phone':            phoneCtrl.text.trim(),
                              'email':            emailCtrl.text.trim(),
                              'address':          addressCtrl.text.trim(),
                              'pan_number':       panCtrl.text.trim(),
                              'vat_number':       vatCtrl.text.trim(),
                              'opening_balance':  double.tryParse(openingCtrl.text.trim()) ?? 0,
                              'notes':            notesCtrl.text.trim(),
                              'party_type':       partyType,
                              if (partyType == 'CUSTOMER')
                                'customer_type':  customerType,
                            };
                            if (isEdit) {
                              await api.patch('/parties/${existing['id']}/', data: data);
                            } else {
                              await api.post('/parties/', data: data);
                            }
                            if (context.mounted) {
                              Navigator.pop(ctx2);
                              _fetch();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(isEdit ? 'Party updated!' : 'Party added!'),
                                backgroundColor: AppColors.success,
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ApiService.errorMessage(e))));
                            }
                          }
                          ss(() => saving = false);
                        },
                  icon: isEdit ? Icons.save_rounded : Icons.check_rounded,
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
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  const _PartyList({
    required this.items,
    required this.settings,
    required this.type,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: type == 'CUSTOMER' ? Icons.people_rounded : Icons.business_rounded,
        message: settings.t('no_data'),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final p = Map<String, dynamic>.from(items[i] as Map);
          final balance = double.tryParse(p['balance']?.toString() ?? '0') ?? 0;
          final isReceivable = balance > 0;

          return Dismissible(
            key: Key('party_${p['id']}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              onDelete(p);
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_rounded, color: AppColors.error),
            ),
            child: AppCard(
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
                      color: type == 'CUSTOMER' ? AppColors.orange : AppColors.info,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'] ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Row(children: [
                        if ((p['phone'] ?? '').toString().isNotEmpty) ...[
                          const Icon(Icons.phone_rounded, size: 12, color: AppColors.navy500),
                          const SizedBox(width: 3),
                          Text(p['phone'],
                              style: const TextStyle(fontSize: 12, color: AppColors.navy500)),
                        ],
                        if (p['customer_type'] != null && (p['customer_type'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.navy50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(p['customer_type'],
                                style: const TextStyle(fontSize: 10, color: AppColors.navy500)),
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
                        color: isReceivable ? AppColors.success : (balance < 0 ? AppColors.error : AppColors.navy500),
                      ),
                    ),
                    Text(
                      isReceivable ? 'Receivable' : (balance < 0 ? 'Payable' : 'Settled'),
                      style: TextStyle(
                        fontSize: 10,
                        color: isReceivable ? AppColors.success : (balance < 0 ? AppColors.error : AppColors.navy500),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      // Edit button
                      GestureDetector(
                        onTap: () => onEdit(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(children: [
                            Icon(Icons.edit_rounded, size: 12, color: AppColors.info),
                            SizedBox(width: 3),
                            Text('Edit', style: TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Ledger button
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).push(
                          MaterialPageRoute(builder: (_) => PartyLedgerScreen(party: p)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(children: [
                            Icon(Icons.book_rounded, size: 12, color: AppColors.orange),
                            SizedBox(width: 3),
                            Text('Ledger', style: TextStyle(fontSize: 10, color: AppColors.orange, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
