import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../banking/presentation/providers/banking_provider.dart';
import '../../../banking/presentation/screens/banking_screen.dart' show BankAccountFormSheet;
import 'settings_tax_screen.dart';

class SettingsBusinessScreen extends StatefulWidget {
  const SettingsBusinessScreen({super.key});

  @override
  State<SettingsBusinessScreen> createState() => _SettingsBusinessScreenState();
}

class _SettingsBusinessScreenState extends State<SettingsBusinessScreen> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxRateController = TextEditingController();
  bool _saving = false;

  File? _logoFile;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    final business = context.read<AuthProvider>().currentBusiness;
    _nameController.text = business?.name ?? '';
    _typeController.text = business?.businessType ?? '';
    _emailController.text = business?.email ?? '';
    _phoneController.text = business?.phone ?? '';
    _addressController.text = business?.address ?? '';
    _logoUrl = business?.logo;
    final taxRate = business?.defaultTaxRate ?? 13;
    _taxRateController.text = taxRate == taxRate.roundToDouble()
        ? taxRate.toStringAsFixed(0)
        : taxRate.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BankingProvider>().load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() {
      _logoFile = File(picked.path);
      _logoUrl = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateCurrentBusiness(
      {
        'name': _nameController.text.trim(),
        'business_type': _typeController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'default_tax_rate': double.tryParse(_taxRateController.text) ?? 13,
      },
      logo: _logoFile,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showAppSnackBar(
      context,
      ok ? 'Business profile saved' : (auth.error ?? 'Failed to save'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = _logoFile != null || (_logoUrl?.isNotEmpty ?? false);
    final panNumber = context.watch<AuthProvider>().currentBusiness?.panNumber;
    final bankAccounts = context.watch<BankingProvider>().accounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Business Profile'), actions: const [HomeLogoButton()]),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: InkWell(
                onTap: _pickLogo,
                customBorder: const CircleBorder(),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.navy50,
                      backgroundImage: _logoFile != null
                          ? FileImage(_logoFile!) as ImageProvider
                          : (hasLogo ? NetworkImage(_logoUrl!) : null),
                      child: hasLogo
                          ? null
                          : Icon(Icons.storefront_outlined, size: 36, color: AppColors.textSecondary),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap to change logo',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Business Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _typeController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Business Type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Business Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taxRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Default Tax Rate (%)',
                helperText: 'Applied by default to new sales (e.g. VAT 13%)',
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _saving ? 'Saving...' : 'Save',
              isLoading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'FINANCIAL INFORMATION'),
            const SizedBox(height: 10),
            AppSectionCard(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsTaxScreen()),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Registration Number (PAN)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              (panNumber?.isNotEmpty ?? false) ? panNumber! : 'Not set — view in Tax & Compliance',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.navy300),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader(title: 'BANK ACCOUNT (${bankAccounts.length})'),
            const SizedBox(height: 10),
            AppSectionCard(
              children: [
                if (bankAccounts.isEmpty)
                  Text('No bank accounts yet', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
                else
                  for (final a in bankAccounts) ...[
                    InkWell(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => BankAccountFormSheet(account: a),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.info),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(a.accountName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                          const Icon(Icons.chevron_right, size: 20, color: AppColors.navy300),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                  ],
                InkWell(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const BankAccountFormSheet(),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle, size: 20, color: AppColors.orange),
                      SizedBox(width: 14),
                      Text('Add Other Bank Account', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
