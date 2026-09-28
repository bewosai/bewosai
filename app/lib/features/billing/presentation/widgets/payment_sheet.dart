import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';

/// Plan prices (Rs per year) — keep in step with client/src/constants/payments.js.
const planPrices = {'PREMIUM': 999, 'PREMIUMPLUS': 1999};

/// QR images bundled from assets/payments/ — replace those files to change them.
const _methods = [
  (name: 'eSewa', asset: 'assets/payments/esewa-qr.png', color: AppColors.success),
  (name: 'ConnectIPS', asset: 'assets/payments/connectips-qr.png', color: AppColors.info),
];

const _whatsapp = '9779744895505'; // wa.me format: country code + number
const _phone = '9744895505';
const _email = 'bewosai@gmail.com';

/// Price + eSewa / ConnectIPS QR codes for [plan], and how to get it activated
/// (send the screenshot; Bewosai sends back a coupon code for "Have a coupon?").
Future<void> showPaymentSheet(
  BuildContext context, {
  required String plan,
  required String planLabel,
  String userEmail = '',
  String businessName = '',
}) {
  final amount = planPrices[plan] ?? 0;
  final note = 'Hi Bewosai, I paid Rs $amount for $planLabel (1 year).\n'
      'Email: $userEmail\nBusiness: $businessName\nScreenshot attached.';

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: 'Upgrade to $planLabel'),
            const SizedBox(height: 4),
            Text('Rs $amount / year',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.orange)),
            const SizedBox(height: 12),
            Text('Scan either QR code and pay Rs $amount:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in _methods) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: m.color.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Text(m.name, style: TextStyle(fontWeight: FontWeight.w800, color: m.color)),
                          const SizedBox(height: 8),
                          AspectRatio(
                            aspectRatio: 1,
                            child: Image.asset(
                              m.asset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Center(
                                child: Text('QR code\ncoming soon',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (m != _methods.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 14),
            for (final (i, step) in [
              'Pay Rs $amount with eSewa or your bank app (ConnectIPS).',
              if (userEmail.isNotEmpty) 'Put your email $userEmail in the payment remarks.',
              "Send the payment screenshot to us — we'll activate $planLabel and send you a coupon code.",
              'Enter that code under "Have a Coupon?" on this screen.',
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. $step', style: const TextStyle(fontSize: 13.5)),
              ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Send screenshot on WhatsApp',
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/$_whatsapp?text=${Uri.encodeComponent(note)}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => launchUrl(Uri(
                scheme: 'mailto',
                path: _email,
                query: 'subject=${Uri.encodeComponent('Payment for $planLabel')}&body=${Uri.encodeComponent(note)}',
              )),
              child: const Text('Email $_email'),
            ),
            const SizedBox(height: 6),
            Text('Questions? Call $_phone',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    ),
  );
}
