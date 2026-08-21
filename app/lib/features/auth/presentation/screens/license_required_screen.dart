import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/licensing/license_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/auth_provider.dart';

const _codeLength = 5;

/// Shown in place of the whole app (see LicenseGate) once a business's
/// trial has ended with no active license — lets the owner enter the code
/// Super Admin generated for them without needing to reach for the web app.
/// Mirrors React's LicenseRequired.jsx (same 5-character code, same success/
/// error states) so the activation flow reads identically on both clients.
class LicenseRequiredScreen extends StatefulWidget {
  /// Called when the user taps "Continue to Bewosai" after a successful
  /// activation — LicenseGate uses this (not go_router) to dismiss the gate
  /// and resume showing the app, since this screen replaces the router's
  /// own widget rather than being a route inside it.
  final VoidCallback onContinue;

  const LicenseRequiredScreen({super.key, required this.onContinue});

  @override
  State<LicenseRequiredScreen> createState() => _LicenseRequiredScreenState();
}

class _LicenseRequiredScreenState extends State<LicenseRequiredScreen> {
  final _codeController = TextEditingController();
  Map<String, dynamic>? _activated;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final license = context.read<LicenseProvider>();
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != _codeLength) return;
    final ok = await license.activate(code);
    if (ok && mounted) {
      setState(() => _activated = license.status?.license);
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = context.watch<LicenseProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.orangeLight),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _activated != null
                      ? _buildActivated(_activated!)
                      : _buildForm(license),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(LicenseProvider license) {
    final canSubmit = _codeController.text.trim().length == _codeLength && !license.isActivating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.orangeGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.vpn_key_outlined, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Premium License Required',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4),
        ),
        const SizedBox(height: 8),
        Text(
          'Your free trial has ended. Enter the license code provided by your administrator to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: _codeLength,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            TextInputFormatter.withFunction(
              (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
            ),
          ],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 10),
          decoration: const InputDecoration(counterText: '', hintText: 'A7K9P'),
          onChanged: (_) {
            license.clearActivateError();
            setState(() {});
          },
          onSubmitted: (_) => _activate(),
        ),
        if (license.activateError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(license.activateError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: license.isActivating ? 'Activating…' : 'Activate License',
          isLoading: license.isActivating,
          onPressed: canSubmit ? _activate : null,
        ),
        const SizedBox(height: 14),
        Text(
          'Need a license? Please contact your administrator.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout, size: 15),
            label: const Text('Log out'),
          ),
        ),
      ],
    );
  }

  Widget _buildActivated(Map<String, dynamic> license) {
    final expiry = license['expiry_date'] != null ? DateTime.tryParse('${license['expiry_date']}') : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(32)),
            child: const Icon(Icons.check_circle, color: AppColors.success, size: 34),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'License Activated Successfully',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          expiry != null
              ? 'Premium access is active until ${Formatters.date(expiry)}.'
              : 'Premium access is now active.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Continue to Bewosai',
          onPressed: widget.onContinue,
        ),
      ],
    );
  }
}
