import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/business_model.dart';
import '../providers/auth_provider.dart';

/// Shown when [AuthStatus.needsBusiness].
/// Tap a business or create one → selectBusiness → ready → Dashboard.
/// No Navigator to dashboard; root Consumer switches on status.
class SelectBusinessScreen extends StatelessWidget {
  const SelectBusinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Business'),
        leading: auth.canCancelSwitchBusiness
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Cancel',
                onPressed: auth.isLoading
                    ? null
                    : () => context.read<AuthProvider>().cancelSwitchBusiness(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: auth.isLoading
                ? null
                : () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a business to continue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              if (auth.businesses.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.business_outlined,
                    title: 'No businesses yet',
                    message: 'Create your first business to get started.',
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: auth.businesses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final b = auth.businesses[i];
                      final isArchived = b.status == 'ARCHIVED';
                      return AppCard(
                        onTap: isArchived || auth.isLoading
                            ? null
                            : () => auth.selectBusiness(b),
                        child: Opacity(
                          opacity: isArchived ? 0.55 : 1,
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.orangeLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    b.name.isNotEmpty
                                        ? b.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.orangeDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        StatusBadge(
                                          label: b.plan,
                                          color: b.plan == 'PREMIUM'
                                              ? AppColors.orange
                                              : AppColors.navy400,
                                        ),
                                        const SizedBox(width: 6),
                                        StatusBadge(label: b.status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!isArchived)
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.navy300,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Add Another Business',
                icon: Icons.add,
                isLoading: auth.isLoading,
                onPressed: auth.isLoading
                    ? null
                    : () => _openCreateBusinessSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateBusinessSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateBusinessSheet(),
    );
  }
}

class _CreateBusinessSheet extends StatefulWidget {
  const _CreateBusinessSheet();

  @override
  State<_CreateBusinessSheet> createState() => _CreateBusinessSheetState();
}

class _CreateBusinessSheetState extends State<_CreateBusinessSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final business = Business(
      id: 0,
      name: _nameController.text.trim(),
      businessType: _typeController.text.trim(),
      address: '',
      phone: _phoneController.text.trim(),
      email: '',
      panNumber: '',
      vatNumber: '',
      currency: 'NPR',
      fiscalYearStart: '07-16',
      defaultTaxRate: 13,
      plan: 'FREE',
      status: 'ACTIVE',
      owner: 0,
      ownerName: '',
      staffCount: 1,
    );

    final ok = await auth.createBusiness(business);
    if (!mounted) return;

    if (ok) {
      // createBusiness → selectBusiness → ready; root shows Dashboard.
      Navigator.pop(context);
    } else if (auth.error != null) {
      showAppSnackBar(context, auth.error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'New Business'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Business Name *'),
              validator: (v) => Validators.required(v, 'Business name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _typeController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Business Type (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
              ),
              onFieldSubmitted: (_) {
                if (!auth.isLoading) _submit();
              },
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Create Business',
              isLoading: auth.isLoading,
              onPressed: auth.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}