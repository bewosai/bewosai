import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const _email = 'bewosai@gmail.com';
  static const _phone = '9744895505';

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showAppSnackBar(context, '$label copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Get in touch'),
            const SizedBox(height: 10),
            AppSectionCard(
              children: [
                _contactTile(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _email,
                  onTap: () => launchUrl(Uri.parse('mailto:$_email')),
                  onCopy: () => _copy(context, 'Email', _email),
                ),
                Divider(height: 24, color: AppColors.divider),
                _contactTile(
                  context,
                  icon: Icons.call_outlined,
                  label: 'Phone',
                  value: _phone,
                  onTap: () => launchUrl(Uri.parse('tel:$_phone')),
                  onCopy: () => _copy(context, 'Phone number', _phone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_outlined, size: 18, color: AppColors.navy300),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
