import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/staff_model.dart';
import '../providers/staff_provider.dart';

void _shareStaffLoginLink(String name, String token) {
  final url = AppConstants.staffLoginUrl(token);
  SharePlus.instance.share(ShareParams(
    text: "Here's your staff login link for Bewosai${name.isNotEmpty ? ', $name' : ''} — "
        "open it to sign in, no password needed:\n\n$url",
  ));
}

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<StaffProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    final currentBusiness = context.watch<AuthProvider>().currentBusiness;
    final businessId = currentBusiness?.id;

    // Mirrors the backend's own staff-cap check (accounts/views.py
    // StaffListView/BusinessStaffInviteView) — shown proactively so an
    // owner isn't surprised by the rejection only after filling out the
    // whole invite form. Free=1, Premium=8 by default; a platform admin can
    // raise (or lower) this per-business via staff_limit_override, which
    // takes precedence over the plan default when set.
    const freeStaffLimit = 1;
    const premiumStaffLimit = 8;
    // effectivePlan (not plan) — a coupon/referral-granted PremiumPlus is
    // unlimited, and even plain Premium via that route must still unlock
    // the higher fixed limit, not just a directly-licensed one.
    final effectivePlan = currentBusiness?.effectivePlan ?? currentBusiness?.plan;
    final isUnlimited = currentBusiness?.staffLimitOverride == null && effectivePlan == 'PREMIUMPLUS';
    final planLimit = effectivePlan == 'FREE' ? freeStaffLimit : premiumStaffLimit;
    final staffLimit = currentBusiness?.staffLimitOverride ?? planLimit;
    final nonOwnerCount = sp.staff.where((s) => s.role != 'OWNER').length;
    final atStaffLimit = !isUnlimited && nonOwnerCount >= staffLimit;

    final filteredStaff = _search.isEmpty
        ? sp.staff
        : sp.staff.where((s) {
            final q = _search.toLowerCase();
            return s.userName.toLowerCase().contains(q) ||
                s.userEmail.toLowerCase().contains(q) ||
                s.role.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: const [HomeLogoButton()],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'staff_fab',
        onPressed: atStaffLimit || businessId == null
            ? null
            : () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _InviteStaffSheet(businessId: businessId),
                ),
        backgroundColor: atStaffLimit ? AppColors.textSecondary : null,
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Invite'),
      ),
      body: ResponsiveBody(
        child: sp.isLoading && sp.staff.isEmpty
            ? const LoadingView()
            : RefreshIndicator(
                onRefresh: () => context.read<StaffProvider>().load(),
                child: sp.staff.isEmpty
                    ? const EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'No staff members yet',
                        message: 'Invite teammates to help run your business.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SearchField(
                            hint: 'Search name, email, role',
                            onChanged: (v) => setState(() => _search = v),
                          ),
                          if (atStaffLimit) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.orangeLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                effectivePlan != 'FREE'
                                    ? 'This business is limited to $staffLimit staff member${staffLimit == 1 ? '' : 's'} besides the owner.'
                                    : 'Your Free plan allows up to $staffLimit staff member${staffLimit == 1 ? '' : 's'} besides the owner — upgrade to Premium to invite more.',
                                style: const TextStyle(
                                  color: AppColors.orangeDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (filteredStaff.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Center(
                                child: Text(
                                  'No matching staff',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ...filteredStaff
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppCard(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.orangeLight,
                                        child: Text(
                                          s.initial,
                                          style: const TextStyle(
                                            color: AppColors.orangeDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.userName.isNotEmpty
                                                  ? s.userName
                                                  : s.userEmail,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              s.userEmail,
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(
                                        label: s.role,
                                        color: s.role == 'OWNER'
                                            ? AppColors.orange
                                            : AppColors.navy500,
                                      ),
                                      if (s.role != 'OWNER' &&
                                          businessId != null)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.ios_share,
                                            size: 18,
                                            color: AppColors.orange,
                                          ),
                                          tooltip: 'Share login link',
                                          onPressed: () async {
                                            final provider = context.read<StaffProvider>();
                                            if (s.loginToken != null && s.loginToken!.isNotEmpty) {
                                              _shareStaffLoginLink(s.userName, s.loginToken!);
                                              return;
                                            }
                                            // No link generated yet (member predates this
                                            // feature) — mint one, then share it.
                                            final ok = await provider.regenerateLink(businessId, s.id);
                                            if (!context.mounted) return;
                                            if (ok && provider.lastInvited != null) {
                                              _shareStaffLoginLink(s.userName, provider.lastInvited!.loginToken!);
                                            } else {
                                              showAppSnackBar(context, provider.error ?? 'Failed to create a login link', isError: true);
                                            }
                                          },
                                        ),
                                      if (s.role != 'OWNER' &&
                                          businessId != null)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: AppColors.error,
                                          ),
                                          onPressed: () async {
                                            final provider = context
                                                .read<StaffProvider>();
                                            final confirmed =
                                                await showDeleteConfirmDialog(
                                                  context,
                                                  message:
                                                      'Remove ${s.userName.isNotEmpty ? s.userName : s.userEmail} from this business?',
                                                );
                                            if (confirmed) {
                                              provider.remove(businessId, s.id);
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
      ),
    );
  }
}

class _InviteStaffSheet extends StatefulWidget {
  final int businessId;
  const _InviteStaffSheet({required this.businessId});

  @override
  State<_InviteStaffSheet> createState() => _InviteStaffSheetState();
}

class _InviteStaffSheetState extends State<_InviteStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _role = 'CASHIER';
  bool _saving = false;
  // Set once the invite succeeds — a new staff member has no email/phone,
  // so their login link is the only way for them to sign in, and it's
  // shown here rather than the sheet just closing.
  StaffMember? _created;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<StaffProvider>();
    final ok = await provider.invite(
      businessId: widget.businessId,
      name: _nameController.text.trim(),
      role: _role,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _created = provider.lastInvited;
    });
    if (!ok) {
      showAppSnackBar(context, provider.error ?? 'Failed to invite staff', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: created != null ? _buildSuccess(created) : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Invite Staff'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: AppConstants.staffRoles
                .where((r) => r != 'OWNER')
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _role = v ?? 'CASHIER'),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Create Staff',
            isLoading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(StaffMember created) {
    final url = AppConstants.staffLoginUrl(created.loginToken ?? '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: '${created.userName} is ready'),
        const SizedBox(height: 8),
        Text(
          'Share this link with them — it\'s the only way they can sign in, since they have no email or password.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.navy50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(url, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!mounted) return;
                  showAppSnackBar(context, 'Login link copied');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Share',
                icon: Icons.ios_share,
                onPressed: () => _shareStaffLoginLink(created.userName, created.loginToken ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
