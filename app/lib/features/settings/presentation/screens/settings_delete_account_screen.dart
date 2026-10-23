import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Permanently delete your own account (Google Play requires this in-app for
/// any app with sign-up). Confirmed with a fresh code sent to the account's
/// email, then the user is signed out.
class SettingsDeleteAccountScreen extends StatefulWidget {
  const SettingsDeleteAccountScreen({super.key});

  @override
  State<SettingsDeleteAccountScreen> createState() => _SettingsDeleteAccountScreenState();
}

class _SettingsDeleteAccountScreenState extends State<SettingsDeleteAccountScreen> {
  final _service = AuthService();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode(String email) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.sendOtp(email);
      if (mounted) setState(() => _codeSent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code we emailed you.');
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This deletes your account and all data of the businesses you own. It cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.deleteAccount(code);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      await auth.logout();
      messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSectionCard(children: [
              const Text('What gets deleted', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              const Text('• Your account and sign-in\n'
                  '• Every business you own, with all its sales, purchases, stock, parties, '
                  'payments, expenses and bank records\n'
                  '• Your staff access to businesses owned by others'),
              const SizedBox(height: 8),
              Text('This cannot be undone. Download any reports you need first.',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            if (email.isEmpty)
              const Text('This account has no email to confirm with. Please contact support to delete it.')
            else if (!_codeSent)
              FilledButton(
                onPressed: _busy ? null : () => _sendCode(email),
                child: Text(_busy ? 'Sending…' : 'Email a confirmation code to $email'),
              )
            else ...[
              Text('Enter the 6-digit code sent to $email', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: _busy ? null : _delete,
                child: Text(_busy ? 'Deleting…' : 'Delete my account'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _sendCode(email),
                child: const Text('Send a new code'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}
