import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsBusinessScreen extends StatefulWidget {
  const SettingsBusinessScreen({super.key});

  @override
  State<SettingsBusinessScreen> createState() => _SettingsBusinessScreenState();
}

class _SettingsBusinessScreenState extends State<SettingsBusinessScreen> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final business = context.read<AuthProvider>().currentBusiness;
    _nameController.text = business?.name ?? '';
    _typeController.text = business?.businessType ?? '';
    _phoneController.text = business?.phone ?? '';
    _addressController.text = business?.address ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateCurrentBusiness({
      'name': _nameController.text.trim(),
      'business_type': _typeController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Business Profile'), actions: const [HomeLogoButton()]),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _saving ? 'Saving...' : 'Save',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
