import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Unlike apps that periodically snapshot local data, Bewosai has nothing
/// stored only on the device — every sale, expense, and record is written
/// straight to the server the moment it's created. This screen exists to
/// make that reassuring fact visible, and to let a user actively confirm
/// their connection to it, rather than to represent a literal backup job.
class SettingsBackupScreen extends StatefulWidget {
  const SettingsBackupScreen({super.key});

  @override
  State<SettingsBackupScreen> createState() => _SettingsBackupScreenState();
}

class _SettingsBackupScreenState extends State<SettingsBackupScreen> {
  final _authService = AuthService();
  bool _checking = false;
  DateTime? _lastVerified;
  bool? _lastVerifiedOk;

  Future<void> _verifyConnection() async {
    setState(() => _checking = true);
    try {
      await _authService.me();
      if (!mounted) return;
      setState(() {
        _lastVerified = DateTime.now();
        _lastVerifiedOk = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastVerified = DateTime.now();
        _lastVerifiedOk = false;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = auth.currentBusiness;
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Data & Cloud Storage')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy900, AppColors.navy700],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_done_rounded, color: AppColors.orange, size: 30),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your data never lives\nonly on this phone',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.3),
                  ),
                  if (business != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      business.name,
                      style: const TextStyle(color: AppColors.navy200, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              title: 'How this actually works',
              children: [
                _ExplainRow(
                  icon: Icons.bolt_rounded,
                  text: 'Every sale, expense, and record is saved to Bewosai\'s '
                      'servers the instant you create it — not on a timer, not '
                      'only when you remember to.',
                ),
                const SizedBox(height: 12),
                _ExplainRow(
                  icon: Icons.phonelink_erase_outlined,
                  text: 'Lost, broke, or switched phones? Nothing to restore — '
                      'just sign in on the new device and everything is already there.',
                ),
                const SizedBox(height: 12),
                _ExplainRow(
                  icon: Icons.lock_outline_rounded,
                  text: 'Only you and staff you\'ve invited to this business can see it.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              title: 'Account',
              children: [
                _InfoRow(label: 'Signed in as', value: user?.email ?? '—'),
                const Divider(height: 24),
                _InfoRow(label: 'Business', value: business?.name ?? '—'),
              ],
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              children: [
                if (_lastVerified != null) ...[
                  Row(
                    children: [
                      Icon(
                        _lastVerifiedOk == true ? Icons.check_circle : Icons.error_outline,
                        size: 18,
                        color: _lastVerifiedOk == true ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastVerifiedOk == true
                              ? 'Verified — synced as of ${Formatters.date(_lastVerified)}, ${DateFormat('hh:mm a').format(_lastVerified!)}'
                              : 'Couldn\'t reach the server. Check your internet connection.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _lastVerifiedOk == true ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                PrimaryButton(
                  label: 'Verify Connection Now',
                  icon: Icons.sync_rounded,
                  isLoading: _checking,
                  onPressed: _verifyConnection,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ExplainRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ExplainRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: AppColors.orangeLight, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: AppColors.orangeDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
