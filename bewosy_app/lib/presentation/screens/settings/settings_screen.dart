import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('settings'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        children: [
          // Business info header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyPrimary, AppColors.navy700],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.store_rounded,
                    color: AppColors.orange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.currentBusiness?.name ?? 'My Business',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      auth.user?.email ?? '',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${auth.currentBusiness?.plan ?? 'Free'} Plan',
                        style: const TextStyle(
                            color: AppColors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          // Appearance
          _SectionHeader(title: 'Appearance'),
          _SettingTile(
            icon: Icons.palette_rounded,
            title: settings.t('theme'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in [ThemeMode.light, ThemeMode.dark])
                  GestureDetector(
                    onTap: () => settings.setTheme(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: settings.themeMode == mode
                            ? AppColors.orange
                            : Colors.transparent,
                        border: Border.all(
                          color: settings.themeMode == mode
                              ? AppColors.orange
                              : AppColors.lightBorder,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(
                          mode == ThemeMode.light
                              ? Icons.wb_sunny_rounded
                              : Icons.nights_stay_rounded,
                          size: 14,
                          color: settings.themeMode == mode
                              ? Colors.white
                              : AppColors.navy500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mode == ThemeMode.light
                              ? settings.t('light_mode')
                              : settings.t('dark_mode'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: settings.themeMode == mode
                                ? Colors.white
                                : AppColors.navy500,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          _SettingTile(
            icon: Icons.language_rounded,
            title: settings.t('language'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final lang in [('en', 'English', 'EN'), ('ne', 'à¤¨à¥‡à¤ªà¤¾à¤²à¥€', 'à¤¨à¥‡')])
                  GestureDetector(
                    onTap: () => settings.setLanguage(lang.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: settings.language == lang.$1
                            ? AppColors.orange
                            : Colors.transparent,
                        border: Border.all(
                          color: settings.language == lang.$1
                              ? AppColors.orange
                              : AppColors.lightBorder,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        lang.$3,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: settings.language == lang.$1
                              ? Colors.white
                              : AppColors.navy500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Date & Currency
          _SectionHeader(title: 'Regional'),
          _SettingTile(
            icon: Icons.calendar_today_rounded,
            title: settings.t('date_format'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ['AD', 'BS'])
                  GestureDetector(
                    onTap: () => settings.setDateMode(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: settings.dateMode == mode
                            ? AppColors.orange
                            : Colors.transparent,
                        border: Border.all(
                          color: settings.dateMode == mode
                              ? AppColors.orange
                              : AppColors.lightBorder,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        mode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: settings.dateMode == mode
                              ? Colors.white
                              : AppColors.navy500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _SettingTile(
            icon: Icons.attach_money_rounded,
            title: 'Currency',
            trailing: DropdownButton<String>(
              value: settings.currency,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'Rs.', child: Text('Rs. (NPR)')),
                DropdownMenuItem(value: 'â‚¹', child: Text('â‚¹ (INR)')),
                DropdownMenuItem(value: '\$', child: Text('\$ (USD)')),
              ],
              onChanged: (v) => settings.setCurrency(v!),
            ),
          ),

          // Privacy
          _SectionHeader(title: 'Privacy'),
          _SettingTile(
            icon: Icons.visibility_off_rounded,
            title: settings.t('private_mode'),
            subtitle: 'Hide amounts (show XXXXX)',
            trailing: Switch.adaptive(
              value: settings.privateMode,
              onChanged: (_) => settings.togglePrivateMode(),
              activeColor: AppColors.orange,
            ),
          ),

          // Tax
          _SectionHeader(title: 'Tax & Billing'),
          _SettingTile(
            icon: Icons.receipt_long_rounded,
            title: 'VAT / Tax',
            subtitle: 'No VAT (internal business management)',
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Disabled',
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),

          // Account
          _SectionHeader(title: 'Account'),
          _SettingTile(
            icon: Icons.delete_outline_rounded,
            title: settings.t('recycle_bin'),
            subtitle: 'View and restore deleted records',
            onTap: () => Navigator.pushNamed(context, '/recycle-bin'),
          ),
          _SettingTile(
            icon: Icons.people_outline_rounded,
            title: settings.t('staff'),
            subtitle: 'Manage staff members and permissions',
            onTap: () => Navigator.pushNamed(context, '/staff'),
          ),
          _SettingTile(
            icon: Icons.logout_rounded,
            title: settings.t('logout'),
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout?'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                }
              }
            },
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text('Bewosy v2.0.0',
                style: TextStyle(fontSize: 11, color: AppColors.navy500)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.navy500,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).dividerColor, width: 0.5)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20, color: iconColor ?? AppColors.orange),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: titleColor,
                      )),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.navy500)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.navy400, size: 20),
          ]),
        ),
      ),
    );
  }
}

