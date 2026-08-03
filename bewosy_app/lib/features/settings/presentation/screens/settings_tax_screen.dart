import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsTaxScreen extends StatelessWidget {
  const SettingsTaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final business = context.watch<AuthProvider>().currentBusiness;

    return Scaffold(
      appBar: AppBar(title: const Text('Tax & Compliance'), actions: const [HomeLogoButton()]),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _InfoTile(label: 'PAN', value: _value(business?.panNumber))),
                const SizedBox(width: 12),
                Expanded(child: _InfoTile(label: 'VAT', value: _value(business?.vatNumber))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _InfoTile(label: 'Currency', value: business?.currency ?? 'NPR')),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    label: 'Fiscal Year Start',
                    value: business?.fiscalYearStart ?? '07-16',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'PAN/VAT, currency, and fiscal year are set when the business is created. '
              'Contact support if these need to change.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _value(String? value) => value == null || value.trim().isEmpty ? 'Not set' : value;
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
