import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/staff_access.dart';
import '../../data/models/staff_model.dart';
import '../../data/services/staff_service.dart' show defaultPermissionsFor;
import '../providers/staff_provider.dart';
import '../widgets/staff_access_editor.dart';

/// Old-style login link — only for staff added before email invitations.
void _shareStaffLoginLink(String name, String token) {
  final url = AppConstants.staffLoginUrl(token);
  SharePlus.instance.share(ShareParams(
    text: "Here's your staff login link for Bewosai${name.isNotEmpty ? ', $name' : ''}. "
        "In the Bewosai app, tap \"Staff? Use the link you were sent\" and paste it.\n\n$url\n\n"
        "Keep this link private — anyone with it can sign in as you.",
  ));
}

String _inviteMessage(String name, String businessName, String url) =>
    "Hi${name.isNotEmpty ? ' $name' : ''}, you're invited to join ${businessName.isNotEmpty ? businessName : 'our business'} on Bewosai. "
    'Open this link, verify your email and accept:\n$url\n\nThe link works once and expires in 7 days.';

String _date(DateTime? d) => d == null ? '' : '${d.day}/${d.month}/${d.year}';

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

  void _openInvite(int businessId) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _InviteStaffSheet(businessId: businessId),
      );

  Future<void> _resend(int businessId, StaffInvitation inv, String businessName) async {
    final provider = context.read<StaffProvider>();
    final ok = await provider.resendInvitation(businessId, inv.id);
    if (!mounted) return;
    final fresh = provider.lastInvitation;
    if (ok && fresh?.token != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: _InviteShareView(
            title: 'New invitation link',
            subtitle: '${fresh!.name} · ${fresh.roleLabel} — the old link no longer works.',
            name: fresh.name,
            businessName: businessName,
            token: fresh.token!,
          ),
        ),
      );
    } else {
      showAppSnackBar(context, provider.error ?? 'Could not resend the invitation', isError: true);
    }
  }

  Future<void> _cancel(int businessId, StaffInvitation inv) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: 'Cancel invitation?',
      message: 'The link sent to ${inv.name} will stop working.',
      confirmLabel: 'Cancel invitation',
    );
    if (!confirmed || !mounted) return;
    final provider = context.read<StaffProvider>();
    final ok = await provider.cancelInvitation(businessId, inv.id);
    if (!mounted) return;
    showAppSnackBar(context, ok ? 'Invitation cancelled' : (provider.error ?? 'Could not cancel'), isError: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    final auth = context.watch<AuthProvider>();
    final currentBusiness = auth.currentBusiness;
    final businessId = currentBusiness?.id;
    final businessName = currentBusiness?.name ?? '';

    // Mirrors the backend (accounts/views.py PLATFORM_LIMITS): 3 staff per
    // business from the app (5 on the website), on any plan; active staff plus
    // invitations still waiting count. A Super Admin override wins.
    final staffLimit = currentBusiness?.staffLimitOverride ?? 3;
    final used = sp.staff.where((s) => s.role != 'OWNER' && s.isActive).length +
        sp.invitations.where((i) => !i.isExpired).length;
    final atStaffLimit = used >= staffLimit;

    StaffMember? owner;
    for (final s in sp.staff) {
      if (s.role == 'OWNER') owner = s;
    }
    final team = sp.staff.where((s) => s.role != 'OWNER').where((s) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return s.userName.toLowerCase().contains(q) ||
          s.userEmail.toLowerCase().contains(q) ||
          staffRoleLabel(s.role).toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff'),
        actions: const [HomeLogoButton()],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'staff_fab',
        // A disabled button just looks broken — tap it at the limit and say why.
        onPressed: businessId == null
            ? null
            : atStaffLimit
                ? () => showAppSnackBar(
                      context,
                      'The app allows $staffLimit staff per business (waiting invitations count). Use the website to add up to 5, or remove someone first.',
                      isError: true,
                    )
                : () => _openInvite(businessId),
        backgroundColor: atStaffLimit ? AppColors.textSecondary : null,
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Add New Staff'),
      ),
      body: ResponsiveBody(
        child: sp.isLoading && sp.staff.isEmpty
            ? const LoadingView()
            : RefreshIndicator(
                onRefresh: () => context.read<StaffProvider>().load(),
                child: sp.staff.isEmpty && sp.error != null
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.error_outline,
                          title: 'Could not load staff',
                          message: sp.error!,
                          action: PrimaryButton(
                            label: 'Retry',
                            expand: false,
                            onPressed: () => context.read<StaffProvider>().load(),
                          ),
                        ),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          const _SectionTitle('Admin'),
                          AppCard(
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: AppColors.orangeLight,
                                  child: Icon(Icons.workspace_premium, color: AppColors.orangeDark),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (owner?.userName.isNotEmpty ?? false) ? owner!.userName : (auth.user?.name ?? 'Business Admin'),
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Business Admin · Full business access',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (atStaffLimit) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.orangeLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'The app allows $staffLimit staff member${staffLimit == 1 ? '' : 's'} per business besides the admin (waiting invitations count). Use the website to add up to 5.',
                                style: const TextStyle(color: AppColors.orangeDark, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          if (sp.invitations.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _SectionTitle('Invitations waiting (${sp.invitations.length})'),
                            ...sp.invitations.map((inv) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: AppCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(inv.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${inv.roleLabel}${inv.email.isNotEmpty ? ' · ${inv.email}' : ''}',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.schedule, size: 15, color: inv.isExpired ? AppColors.error : AppColors.orangeDark),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                inv.isExpired ? 'Expired — resend to send a new link' : 'Invitation pending · expires ${_date(inv.expiresAt)}',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: inv.isExpired ? AppColors.error : AppColors.orangeDark,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (businessId != null) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  icon: const Icon(Icons.send_outlined, size: 18),
                                                  label: const Text('Resend'),
                                                  onPressed: sp.isLoading ? null : () => _resend(businessId, inv, businessName),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                                  icon: const Icon(Icons.close, size: 18),
                                                  label: const Text('Cancel'),
                                                  onPressed: sp.isLoading ? null : () => _cancel(businessId, inv),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                          const SizedBox(height: 18),
                          _SectionTitle('Staff (${sp.staff.where((s) => s.role != 'OWNER').length})'),
                          if (sp.staff.where((s) => s.role != 'OWNER').length > 3) ...[
                            SearchField(
                              hint: 'Search name, email, role',
                              onChanged: (v) => setState(() => _search = v),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (team.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                _search.isNotEmpty ? 'No matching staff' : 'No staff yet. Tap "Add New Staff" to invite someone.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                            ),
                          ...team.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                onTap: businessId == null
                                    ? null
                                    : () => showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => _ManageStaffSheet(staffId: s.id, businessId: businessId),
                                        ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.orangeLight,
                                      child: Text(s.initial,
                                          style: const TextStyle(color: AppColors.orangeDark, fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.userName.isNotEmpty ? s.userName : s.userEmail,
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${staffRoleLabel(s.role)}${s.userEmail.isNotEmpty ? ' · ${s.userEmail}' : ' · old login link'}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            s.isActive ? '✓ Active' : 'Inactive — can\'t use the business',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: s.isActive ? AppColors.success : AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (businessId != null) ...[
                                      const SizedBox(width: 6),
                                      Text('Manage', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 13)),
                                      Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                                    ],
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
      );
}

/// The invitation link with every way to send it.
class _InviteShareView extends StatelessWidget {
  final String title;
  final String subtitle;
  final String name;
  final String businessName;
  final String token;
  const _InviteShareView({
    required this.title,
    required this.subtitle,
    required this.name,
    required this.businessName,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final url = AppConstants.staffInviteUrl(token);
    final message = _inviteMessage(name, businessName, url);

    Future<void> open(Uri uri) async {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok && context.mounted) {
        showAppSnackBar(context, 'That app isn\'t available — use Copy or More instead.', isError: true);
      }
    }

    Widget channel(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: Icon(icon, size: 20, color: color),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            onPressed: onTap,
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.navy50, borderRadius: BorderRadius.circular(12)),
          child: SelectableText(url, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Copy link',
          icon: Icons.copy_outlined,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) showAppSnackBar(context, 'Invitation link copied');
          },
        ),
        const SizedBox(height: 10),
        Row(children: [
          channel(Icons.chat, 'WhatsApp', const Color(0xFF25D366),
              () => open(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'))),
          const SizedBox(width: 10),
          channel(Icons.sms_outlined, 'SMS', AppColors.navy500, () => open(Uri(scheme: 'sms', queryParameters: {'body': message}))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          channel(Icons.send, 'Messenger', const Color(0xFF0084FF),
              () => open(Uri.parse('fb-messenger://share/?link=${Uri.encodeComponent(url)}'))),
          const SizedBox(width: 10),
          channel(Icons.ios_share, 'More', AppColors.orange, () => SharePlus.instance.share(ShareParams(text: message))),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'They open the link, verify their email with a code, and accept. The link works once and expires in 7 days.',
            style: TextStyle(color: AppColors.orangeDark, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
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
  final _emailController = TextEditingController();
  String _role = 'SALESPERSON';
  // What this person may use, starting from the role's preset and adjustable
  // feature by feature before the invitation is created.
  Map<String, dynamic> _permissions = defaultPermissionsFor('SALESPERSON');
  bool _saving = false;
  StaffInvitation? _created;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<StaffProvider>();
    final ok = await provider.invite(
      businessId: widget.businessId,
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      role: _role,
      permissions: _permissions,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _created = provider.lastInvitation;
    });
    if (!ok) {
      showAppSnackBar(context, provider.error ?? 'Could not create the invitation', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    final businessName = context.read<AuthProvider>().currentBusiness?.name ?? '';
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: created != null && created.token != null
          ? _InviteShareView(
              title: 'Staff added',
              subtitle: '${created.name} · ${created.roleLabel}. Send them this invitation.',
              name: created.name,
              businessName: businessName,
              token: created.token!,
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Add New Staff'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Staff name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the staff member\'s name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Their email (optional)',
              helperText: 'If you add it, only this email can accept the invitation.',
              helperMaxLines: 2,
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return null;
              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t) ? null : 'Enter a valid email or leave it empty';
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final (key, label, _) in staffRoleOptions) DropdownMenuItem(value: key, child: Text(label)),
            ],
            onChanged: (v) => setState(() {
              _role = v ?? 'SALESPERSON';
              _permissions = defaultPermissionsFor(_role); // a new role starts from its preset
            }),
          ),
          const SizedBox(height: 6),
          Text(staffRoleSummary(_role), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          const Text('Manage permissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(
            'Set by the role. Change any section — you can edit it again later.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          StaffAccessEditor(value: _permissions, onChanged: (p) => setState(() => _permissions = p)),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save & create invitation',
            isLoading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Everything you can do to one staff member, in one place: change their role
/// (which also resets their permissions to that role's defaults), adjust
/// access, switch them on/off, or remove them. Staff added before email
/// invitations also get their old login-link options here.
class _ManageStaffSheet extends StatefulWidget {
  final int staffId;
  final int businessId;
  const _ManageStaffSheet({required this.staffId, required this.businessId});

  @override
  State<_ManageStaffSheet> createState() => _ManageStaffSheetState();
}

class _ManageStaffSheetState extends State<_ManageStaffSheet> {
  String? _role; // the picked-but-not-yet-saved role
  Map<String, dynamic>? _permissions; // edited-but-not-yet-saved access, null = untouched
  bool _busy = false;

  StaffMember? _member(StaffProvider sp) {
    for (final s in sp.staff) {
      if (s.id == widget.staffId) return s;
    }
    return null;
  }

  /// Runs [action], reports the outcome, and (optionally) closes the sheet. The
  /// snackbar is shown before popping so it still has a live context.
  Future<void> _run(
    Future<bool> Function(StaffProvider provider) action, {
    String? success,
    bool close = false,
  }) async {
    final provider = context.read<StaffProvider>();
    setState(() => _busy = true);
    final ok = await action(provider);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      if (success != null) showAppSnackBar(context, success);
      if (close) Navigator.pop(context);
    } else {
      showAppSnackBar(context, provider.error ?? 'Something went wrong. Please try again.', isError: true);
    }
  }

  Future<void> _share(StaffMember m) async {
    if (m.loginToken != null && m.loginToken!.isNotEmpty) {
      _shareStaffLoginLink(m.userName, m.loginToken!);
      return;
    }
    // Predates login links — mint one first.
    await _run((p) async {
      final ok = await p.regenerateLink(widget.businessId, m.id);
      final token = p.lastLinkMember?.loginToken;
      if (ok && token != null && token.isNotEmpty) _shareStaffLoginLink(m.userName, token);
      return ok;
    });
  }

  Future<void> _newLink(StaffMember m) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: 'Get a new login link?',
      message: "${m.userName.isNotEmpty ? m.userName : 'This person'}'s current link stops working immediately.",
      confirmLabel: 'Get New Link',
    );
    if (!confirmed || !mounted) return;
    await _run((p) async {
      final ok = await p.regenerateLink(widget.businessId, m.id);
      final token = p.lastLinkMember?.loginToken;
      if (ok && token != null && token.isNotEmpty) _shareStaffLoginLink(m.userName, token);
      return ok;
    }, success: 'New link created — the old one no longer works');
  }

  Future<void> _remove(StaffMember m) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      message: 'Remove ${m.userName.isNotEmpty ? m.userName : 'this person'} from this business? They will no longer be able to sign in.',
    );
    if (!confirmed || !mounted) return;
    await _run((p) => p.remove(widget.businessId, m.id), success: 'Staff member removed', close: true);
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    final m = _member(sp);
    if (m == null) return const SizedBox.shrink(); // removed while open
    final role = _role ?? m.role;
    final roleChanged = role != m.role;
    final access = _permissions ?? m.permissions;
    final accessChanged = _permissions != null && !samePermissions(_permissions!, m.permissions);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: m.userName.isNotEmpty ? m.userName : 'Staff member'),
          if (m.userEmail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(m.userEmail, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: staffRoleOptions.any((r) => r.$1 == role) ? role : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final (key, label, _) in staffRoleOptions) DropdownMenuItem(value: key, child: Text(label)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _role = v),
          ),
          const SizedBox(height: 6),
          Text(staffRoleSummary(role), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (roleChanged) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Save role',
              isLoading: _busy,
              onPressed: () => _run(
                (p) => p.updateRole(widget.businessId, m.id, role),
                success: 'Role changed to ${staffRoleLabel(role)}',
              ),
            ),
          ],
          const Divider(height: 28),
          const Text('Permissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          StaffAccessEditor(
            value: access,
            enabled: !_busy && !roleChanged,
            onChanged: (p) => setState(() => _permissions = p),
          ),
          if (accessChanged) ...[
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Save access',
              isLoading: _busy,
              onPressed: () => _run(
                (p) async {
                  final ok = await p.updatePermissions(widget.businessId, m.id, access);
                  if (ok) setState(() => _permissions = null);
                  return ok;
                },
                success: 'Access updated',
              ),
            ),
          ],
          const Divider(height: 28),
          if (m.usesLoginLink) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share, color: AppColors.orange),
              title: const Text('Share old login link'),
              subtitle: const Text('Added before email invitations. For better security, remove and invite them by email.'),
              onTap: _busy ? null : () => _share(m),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.autorenew, color: AppColors.textSecondary),
              title: const Text('Get a new login link'),
              subtitle: const Text('Use this if the link was shared by mistake'),
              onTap: _busy ? null : () => _newLink(m),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.orange,
            title: const Text('Active'),
            subtitle: Text(m.isActive ? 'Can use this business' : "Blocked — can't use this business"),
            value: m.isActive,
            onChanged: _busy
                ? null
                : (v) => _run(
                      (p) => p.setActive(widget.businessId, m.id, v),
                      success: v ? 'Staff member activated' : 'Staff member deactivated',
                    ),
          ),
          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_remove_outlined, color: AppColors.error),
            title: const Text('Remove from business', style: TextStyle(color: AppColors.error)),
            onTap: _busy ? null : () => _remove(m),
          ),
        ],
      ),
    );
  }
}
