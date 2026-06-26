import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_widgets.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _staff = [];
  List _activity = [];
  bool _loading = true;

  static const _roles = ['OWNER', 'MANAGER', 'ACCOUNTANT', 'SALESPERSON', 'VIEWER'];

  static const _permissions = <String, String>{
    'sales': 'Sales',
    'purchases': 'Purchases',
    'expenses': 'Expenses',
    'inventory': 'Inventory',
    'parties': 'Parties',
    'reports': 'Reports',
    'staff': 'Staff',
    'settings': 'Settings',
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    try {
      final r1 = await api.get('/staff/');
      final r2 = await api.get('/staff/activity/');
      _staff = (r1.data as List?) ?? [];
      _activity = (r2.data as List?) ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('staff'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.navy500,
          indicatorColor: AppColors.orange,
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Activity Log'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showInviteSheet(context, settings),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Invite Staff'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                // Staff list
                _staff.isEmpty
                    ? EmptyState(
                        icon: Icons.people_rounded,
                        message: settings.t('no_data'),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _fetch(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _staff.length,
                          itemBuilder: (ctx, i) {
                            final s = _staff[i];
                            final role = s['role'] ?? 'VIEWER';
                            final roleColor = switch (role) {
                              'OWNER' => AppColors.orange,
                              'MANAGER' => AppColors.info,
                              'ACCOUNTANT' => AppColors.success,
                              _ => AppColors.navy500,
                            };
                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      roleColor.withOpacity(0.15),
                                  child: Text(
                                    (s['name'] ?? '?')
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: roleColor),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s['name'] ?? '—',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      Text(s['email'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.navy500)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(role,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: roleColor)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        s['is_active'] == true
                                            ? 'Active'
                                            : 'Inactive',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: s['is_active'] == true
                                                ? AppColors.success
                                                : AppColors.navy500)),
                                  ],
                                ),
                              ]),
                            );
                          },
                        ),
                      ),
                // Activity log
                _activity.isEmpty
                    ? EmptyState(
                        icon: Icons.history_rounded,
                        message: 'No activity recorded yet',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _activity.length,
                        itemBuilder: (ctx, i) {
                          final a = _activity[i];
                          final action = a['action'] ?? '';
                          final actionColor = switch (action) {
                            'LOGIN' => AppColors.success,
                            'LOGOUT' => AppColors.navy500,
                            'CREATE' => AppColors.info,
                            'DELETE' => AppColors.error,
                            _ => AppColors.orange,
                          };
                          final actionIcon = switch (action) {
                            'LOGIN' => Icons.login_rounded,
                            'LOGOUT' => Icons.logout_rounded,
                            'CREATE' => Icons.add_circle_rounded,
                            'DELETE' => Icons.delete_rounded,
                            'UPDATE' => Icons.edit_rounded,
                            _ => Icons.info_rounded,
                          };
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        actionColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(actionIcon,
                                      size: 16, color: actionColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['description'] ??
                                            '${a['user_name'] ?? ''} $action',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        a['timestamp'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.navy500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }

  void _showInviteSheet(BuildContext context, AppSettings settings) {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String role = 'SALESPERSON';
    final Set<String> selectedPerms = {'sales'};
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, ctrl) => ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Invite Staff Member',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.mail_outline_rounded)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _roles
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => ss(() => role = v!),
                ),
                const SizedBox(height: 16),
                const Text('Module Permissions',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _permissions.entries.map((e) {
                    final sel = selectedPerms.contains(e.key);
                    return FilterChip(
                      label: Text(e.value),
                      selected: sel,
                      onSelected: (v) => ss(() {
                        if (v) {
                          selectedPerms.add(e.key);
                        } else {
                          selectedPerms.remove(e.key);
                        }
                      }),
                      selectedColor: AppColors.orange.withOpacity(0.15),
                      checkmarkColor: AppColors.orange,
                      labelStyle: TextStyle(
                        color: sel ? AppColors.orange : AppColors.navy500,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: sel
                            ? AppColors.orange
                            : AppColors.lightBorder,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Send Invitation',
                  loading: saving,
                  onPressed: saving
                      ? null
                      : () async {
                          ss(() => saving = true);
                          try {
                            await context.read<ApiService>().post(
                              '/staff/invite/',
                              data: {
                                'name': nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'role': role,
                                'permissions': selectedPerms.toList(),
                              },
                            );
                            if (context.mounted) {
                              Navigator.pop(ctx2);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Invitation sent successfully!')),
                              );
                              _fetch();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          }
                          ss(() => saving = false);
                        },
                  icon: Icons.send_rounded,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
