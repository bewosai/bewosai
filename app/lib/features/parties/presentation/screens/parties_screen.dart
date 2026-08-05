import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/party_model.dart';
import '../providers/party_provider.dart';

class PartiesScreen extends StatefulWidget {
  final bool openAddOnStart;
  const PartiesScreen({super.key, this.openAddOnStart = false});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  String _filter = 'ALL';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartyProvider>().load();
      if (widget.openAddOnStart) _openAddSheet();
    });
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PartyFormSheet(),
    );
  }

  List<Party> _filtered(List<Party> parties) {
    var list = parties;
    if (_filter != 'ALL')
      list = list.where((p) => p.partyType == _filter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.phone.contains(q) ||
                p.email.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PartyProvider>();
    final filtered = _filtered(pp.parties);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'parties_fab',
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Party'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () => context.read<PartyProvider>().load(),
          child: pp.isLoading && pp.parties.isEmpty
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ResponsiveGrid(
                      columns: 4,
                      spacing: 10,
                      childAspectRatio: 0.75,
                      children: [
                        KpiCard(
                          label: 'Total',
                          value: '${pp.parties.length}',
                          icon: Icons.people_outline,
                          color: AppColors.orange,
                        ),
                        KpiCard(
                          label: 'Customers',
                          value: '${pp.customers.length}',
                          icon: Icons.person_outline,
                          color: AppColors.info,
                        ),
                        KpiCard(
                          label: 'Suppliers',
                          value: '${pp.suppliers.length}',
                          icon: Icons.local_shipping_outlined,
                          color: AppColors.navy600,
                        ),
                        KpiCard.currency(
                          label: 'Receivable',
                          value: pp.totalReceivable,
                          icon: Icons.call_received,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SearchField(
                      hint: 'Search name, phone, email',
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ALL', 'CUSTOMER', 'SUPPLIER', 'BOTH'].map((
                          f,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppFilterChip(
                              label: f,
                              selected: _filter == f,
                              onTap: () => setState(() => _filter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No parties found',
                        message: 'Add a customer or supplier to get started.',
                      )
                    else
                      ...filtered.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: p.partyType == 'SUPPLIER'
                                            ? AppColors.infoBg
                                            : AppColors.orangeLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        p.partyType == 'SUPPLIER'
                                            ? Icons.local_shipping_outlined
                                            : Icons.person_outline,
                                        color: p.partyType == 'SUPPLIER'
                                            ? AppColors.info
                                            : AppColors.orangeDark,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (p.phone.isNotEmpty)
                                            Text(
                                              p.phone,
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.currency(p.balance.abs()),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: p.balance > 0
                                                ? AppColors.error
                                                : (p.balance < 0
                                                      ? AppColors.success
                                                      : AppColors
                                                            .textSecondary),
                                          ),
                                        ),
                                        Text(
                                          p.balance > 0
                                              ? 'Receivable'
                                              : (p.balance < 0
                                                    ? 'Payable'
                                                    : 'Settled'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => context.push(
                                          '/party-ledger/${p.id}',
                                        ),
                                        icon: const Icon(
                                          Icons.receipt_long_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Ledger',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.textPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) =>
                                            _PartyFormSheet(party: p),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () async {
                                        if (p.balance != 0) {
                                          final direction = p.balance > 0
                                              ? 'owed to you'
                                              : 'you owe them';
                                          showAppSnackBar(
                                            context,
                                            "Cannot delete '${p.name}' — outstanding balance of ${Formatters.currency(p.balance.abs())} ($direction) must be settled first.",
                                            isError: true,
                                          );
                                          return;
                                        }
                                        final provider = context
                                            .read<PartyProvider>();
                                        final confirmed =
                                            await showDeleteConfirmDialog(
                                              context,
                                              message:
                                                  'This will remove all associated records to the recycle bin.',
                                            );
                                        if (!confirmed) return;
                                        final ok = await provider.delete(p.id);
                                        if (!context.mounted) return;
                                        if (!ok)
                                          showAppSnackBar(
                                            context,
                                            provider.error ??
                                                'Failed to delete party',
                                            isError: true,
                                          );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PartyFormSheet extends StatefulWidget {
  final Party? party;
  const _PartyFormSheet({this.party});

  @override
  State<_PartyFormSheet> createState() => _PartyFormSheetState();
}

class _PartyFormSheetState extends State<_PartyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.party?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.party?.phone ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.party?.email ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.party?.address ?? '',
  );
  late final _openingBalanceController = TextEditingController(
    text: widget.party?.openingBalance.toString() ?? '0',
  );
  late final _notesController = TextEditingController(
    text: widget.party?.notes ?? '',
  );
  late String _partyType = widget.party?.partyType ?? 'CUSTOMER';
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final party = Party(
      id: widget.party?.id ?? 0,
      name: _nameController.text.trim(),
      partyType: _partyType,
      customerType: '',
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      panNumber: '',
      vatNumber: '',
      openingBalance: double.tryParse(_openingBalanceController.text) ?? 0,
      balance: 0,
      notes: _notesController.text.trim(),
      isActive: true,
    );
    final ok = await context.read<PartyProvider>().save(
      party,
      id: widget.party?.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      final err = context.read<PartyProvider>().error;
      showAppSnackBar(context, err ?? 'Failed to save party', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.party == null ? 'Add Party' : 'Edit Party',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 14),
              Row(
                children: AppConstants.partyTypes.map((t) {
                  final selected = _partyType == t;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _partyType = t),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selected
                              ? AppColors.orangeLight
                              : null,
                          side: BorderSide(
                            color: selected
                                ? AppColors.orange
                                : AppColors.navy200,
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? AppColors.orangeDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _openingBalanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Opening Balance'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save Party',
                isLoading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
