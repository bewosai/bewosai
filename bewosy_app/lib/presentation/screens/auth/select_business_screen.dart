import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';

class SelectBusinessScreen extends StatelessWidget {
  const SelectBusinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Select Business')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your business workspace',
              style: TextStyle(fontSize: 14, color: AppColors.navy500),
            ),
            const SizedBox(height: 16),
            for (final biz in auth.businesses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: () async {
                    await auth.selectBusiness(biz);
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(
                          context, '/dashboard');
                    }
                  },
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.store_rounded,
                          color: AppColors.orange),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            biz.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            biz.plan,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.navy500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: AppColors.navy400),
                  ]),
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/create-business'),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Create New Business'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


