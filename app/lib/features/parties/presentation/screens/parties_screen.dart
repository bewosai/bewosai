import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/excel_import_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/party_model.dart';
import '../providers/party_provider.dart';
import 'party_import_screen.dart';

// Same column order as PartyImportScreen's template, so an exported file
// can be edited and re-imported unchanged.
const _kExportHeaders = ['name', 'party_type', 'phone', 'email', 'address', 'opening_balance'];

Future<void> _exportParties(BuildContext context, List<Party> parties) async {
  try {
    final path = await ExcelImportUtils.writeRows(
      sheetName: 'Parties',
      headers: _kExportHeaders,
      rows: [
        for (final p in parties)
          [p.name, p.partyType, p.phone, p.email, p.address, p.openingBalance.toString()],
      ],
      fileName: 'bewosai_parties_export.xlsx',
    );
    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Bewosai parties export'));
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'Could not create the export file', isError: true);
    }
  }
}

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
    if (_filter == 'CUSTOMER' || _filter == 'SUPPLIER') {
      // A 'BOTH' party counts toward both the Customers and Suppliers KPI
      // cards above — filter the same way so a tab never silently drops a
      // party that its own summary count says should be there.
      list = list.where((p) => p.partyType == _filter || p.partyType == 'BOTH').toList();
    } else if (_filter == 'BOTH') {
      list = list.where((p) => p.partyType == 'BOTH').toList();
    }
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
      // No AppBar here previously — fine when this screen is the embedded
      // "Parties" bottom-nav tab (MainShell provides chrome for tab 0 only,
      // same as TransactionsScreen), but this screen is also pushed
      // standalone (e.g. the Dashboard's "Add Party" shortcut), where it had
      // no title, no back button, and no way back to Dashboard at all.
      appBar: AppBar(
        title: const Text('Parties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export Parties',
            onPressed: pp.parties.isEmpty ? null : () => _exportParties(context, pp.parties),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Import Parties',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PartyImportScreen()),
            ),
          ),
          const HomeLogoButton(),
        ],
      ),
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
                          label: 'To Receive',
                          value: pp.totalReceivable,
                          icon: Icons.call_received,
                          color: AppColors.success,
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
                                                ? AppColors.success
                                                : (p.balance < 0
                                                      ? AppColors.error
                                                      : AppColors
                                                            .textSecondary),
                                          ),
                                        ),
                                        Text(
                                          p.balance > 0
                                              ? 'To Receive'
                                              : (p.balance < 0
                                                    ? 'To Give'
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
                                        if (!ok) {
                                          showAppSnackBar(
                                            context,
                                            provider.error ??
                                                'Failed to delete party',
                                            isError: true,
                                          );
                                        }
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
  // Edited as an always-positive amount + explicit direction rather than a
  // signed number — entering "-500" to mean "I owe them" isn't obvious, so
  // the sign is derived from _obDirection at submit time instead.
  late final _openingBalanceController = TextEditingController(
    text: _cleanAmount(widget.party?.openingBalance.abs() ?? 0),
  );
  late String _obDirection =
      (widget.party?.openingBalance ?? 0) < 0 ? 'PAYABLE' : 'RECEIVABLE';
  late final _notesController = TextEditingController(
    text: widget.party?.notes ?? '',
  );
  late String _partyType = widget.party?.partyType ?? 'CUSTOMER';
  bool _saving = false;

  // Blank for zero (a new party) so there's no "0.0" to delete before typing;
  // whole numbers without the trailing ".0".
  static String _cleanAmount(double v) {
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

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
      openingBalance:
          (double.tryParse(_openingBalanceController.text) ?? 0).abs() *
          (_obDirection == 'PAYABLE' ? -1 : 1),
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
              SheetHeader(title: widget.party == null ? 'Add Party' : 'Edit Party'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DirectionButton(
                      label: 'To Receive',
                      selected: _obDirection == 'RECEIVABLE',
                      color: AppColors.success,
                      onTap: () => setState(() => _obDirection = 'RECEIVABLE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DirectionButton(
                      label: 'To Give',
                      selected: _obDirection == 'PAYABLE',
                      color: AppColors.error,
                      onTap: () => setState(() => _obDirection = 'PAYABLE'),
                    ),
                  ),
                ],
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

/// Toggle for the opening-balance direction — "To Receive" (they owe us) vs
/// "To Give" (we owe them) — matching the wording already used on the party
/// balance card, instead of asking the user to enter a signed amount.
class _DirectionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? color.withValues(alpha: 0.1) : null,
        side: BorderSide(color: selected ? color : AppColors.navy200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? color : AppColors.textSecondary,
        ),
      ),
    );
  }
}
