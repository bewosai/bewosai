import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/licensing/license_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shell/presentation/screens/contact_screen.dart';
import '../providers/billing_provider.dart';

const _planLabels = {'FREE': 'Free', 'PREMIUM': 'Premium', 'PREMIUMPLUS': 'Premium Plus'};
const _planFeatures = {
  'FREE': ['2 business profiles', '1 staff member', 'Core sales & inventory'],
  'PREMIUM': ['5 business profiles', '3 staff members', 'Bulk import/export', 'Priority support'],
  'PREMIUMPLUS': ['Unlimited business profiles', '5 staff members', 'Everything in Premium'],
};

Color _planColor(String plan) {
  switch (plan) {
    case 'PREMIUMPLUS':
      return AppColors.info;
    case 'PREMIUM':
      return AppColors.orange;
    default:
      return AppColors.textSecondary;
  }
}

String _fmtDate(DateTime? d) => Formatters.date(d);

class UpgradePlanScreen extends StatefulWidget {
  const UpgradePlanScreen({super.key});

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BillingProvider>().load());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    final billing = context.read<BillingProvider>();
    final ok = await billing.applyCoupon(code);
    if (!mounted) return;
    if (ok) {
      _codeController.clear();
      // Unlock Premium everywhere now (plan labels, Staff/Import gates, the
      // trial banner), not after the next sign-in.
      context.read<AuthProvider>().refreshBusinesses();
      context.read<LicenseProvider>().refresh();
    }
    showAppSnackBar(context, ok ? (billing.couponSuccess ?? 'Coupon applied!') : (billing.couponError ?? 'Could not apply this coupon.'), isError: !ok);
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    showAppSnackBar(context, 'Referral link copied');
  }

  void _shareLink(String link) {
    final code = context.read<BillingProvider>().referral?.referralCode;
    SharePlus.instance.share(ShareParams(
      text: "I'm using Bewosai to manage my business. Join using my referral link and get 1 month Premium free:\n\n$link"
          "${code == null || code.isEmpty ? '' : '\n\nOr enter my code $code when creating your business.'}",
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = auth.currentBusiness;
    final user = auth.user;
    final billing = context.watch<BillingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Plan'), actions: const [HomeLogoButton()]),
      body: ResponsiveBody(
        child: billing.isLoading && billing.subscription == null
            ? const LoadingView()
            : RefreshIndicator(
                onRefresh: billing.load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (user != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          "Your account's subscription (${user.email.isNotEmpty ? user.email : user.phone})"
                          "${business != null ? ' — covers every business you own, including ${business.name}' : ''}",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    _CurrentPlanCard(billing: billing),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Have a Coupon?'),
                    const SizedBox(height: 10),
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              decoration: const InputDecoration(labelText: '6-character code', hintText: 'A7K4P2', counterText: ''),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: PrimaryButton(
                              label: 'Apply',
                              expand: false,
                              isLoading: billing.isApplyingCoupon,
                              onPressed: _applyCoupon,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Refer & Earn'),
                    const SizedBox(height: 10),
                    _ReferAndEarnCard(billing: billing, onCopy: _copyLink, onShare: _shareLink),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final BillingProvider billing;
  const _CurrentPlanCard({required this.billing});

  @override
  Widget build(BuildContext context) {
    final sub = billing.subscription;
    final effectivePlan = sub?.effectivePlan ?? 'FREE';
    final color = _planColor(effectivePlan);

    String subtitle;
    final activeSub = sub?.activeSubscription;
    if (activeSub != null) {
      final endDate = DateTime.tryParse(activeSub['end_date'] as String? ?? '');
      final source = activeSub['source'] == 'REFERRAL' ? 'a referral reward' : 'a coupon';
      subtitle = 'Active until ${_fmtDate(endDate)} · from $source';
    } else if (sub?.activeLicense == true) {
      subtitle = 'Active until ${_fmtDate(sub?.licenseExpiry)} · licensed';
    } else {
      subtitle = 'Upgrade with a coupon or by referring a friend below';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(Icons.workspace_premium, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_planLabels[effectivePlan] ?? effectivePlan, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final plan in ['FREE', 'PREMIUM', 'PREMIUMPLUS'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanRow(plan: plan, isCurrent: plan == effectivePlan),
            ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                children: const [
                  TextSpan(text: 'Want to buy Premium or Premium Plus directly? '),
                  TextSpan(text: 'Contact us', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.orange)),
                  TextSpan(text: " and we'll set you up with a coupon."),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String plan;
  final bool isCurrent;
  const _PlanRow({required this.plan, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final color = _planColor(plan);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? color.withValues(alpha: 0.5) : AppColors.dividerLight, width: isCurrent ? 1.5 : 1),
        color: isCurrent ? color.withValues(alpha: 0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(label: _planLabels[plan] ?? plan, color: color),
              if (isCurrent) const Text('CURRENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in _planFeatures[plan] ?? [])
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReferAndEarnCard extends StatelessWidget {
  final BillingProvider billing;
  final void Function(String link) onCopy;
  final void Function(String link) onShare;
  const _ReferAndEarnCard({required this.billing, required this.onCopy, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final referral = billing.referral;
    final link = referral?.referralLink ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orangeLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.card_giftcard, color: AppColors.orangeDark, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      children: const [
                        TextSpan(text: 'Invite a friend to Bewosai — '),
                        TextSpan(text: 'you both get 1 month Premium', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: ' once they sign up and verify their account.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Your referral link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border.all(color: AppColors.dividerLight), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: link.isEmpty ? null : () => onCopy(link),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: link.isEmpty ? null : () => onShare(link),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  children: [
                    TextSpan(text: '${referral?.totalReferrals ?? 0}', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const TextSpan(text: ' successful referral(s)'),
                  ],
                ),
              ),
            ],
          ),
          if (referral != null && referral.rewards.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Referral History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            for (final r in referral.rewards)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.dividerLight), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            r.status == 'REWARDED' ? Icons.auto_awesome : Icons.circle,
                            size: r.status == 'REWARDED' ? 16 : 8,
                            color: r.status == 'REWARDED' ? AppColors.success : AppColors.navy300,
                          ),
                          const SizedBox(width: 8),
                          Text(r.referredBusinessName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text(
                        r.status == 'REWARDED' ? 'Premium rewarded' : r.status,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: r.status == 'REWARDED' ? AppColors.success : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
