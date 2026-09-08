import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/announcements/announcement_model.dart';
import '../../core/announcements/announcement_service.dart';
import '../../core/theme/app_colors.dart';

const _dismissedKey = 'dismissed_announcement_ids';

/// Shows every active platform announcement (Super Admin > Announcements)
/// as a dismissible card, mirroring the web app's notification-bell
/// Announcements section — previously nothing on mobile ever surfaced these
/// at all. Dismissals are stored locally (per-device), same reasoning as
/// web's localStorage approach: announcements are a broadcast with no
/// per-user "read" state on the backend.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  final _service = AnnouncementService();
  List<Announcement> _announcements = [];
  Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await _service.fetchActive();
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_dismissedKey) ?? [];
      if (!mounted) return;
      setState(() {
        _announcements = results;
        _dismissed = dismissed.toSet();
      });
    } catch (_) {
      // Silent — an announcement banner failing to load shouldn't block
      // or clutter the Dashboard with an error state of its own.
    }
  }

  Future<void> _dismiss(Announcement a) async {
    final prefs = await SharedPreferences.getInstance();
    final next = {..._dismissed, '${a.id}'};
    await prefs.setStringList(_dismissedKey, next.toList());
    if (!mounted) return;
    setState(() => _dismissed = next);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _announcements.where((a) => !_dismissed.contains('${a.id}')).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final a in visible) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.campaign_outlined, size: 20, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      if (a.body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(a.body, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3)),
                      ],
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _dismiss(a),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: AppColors.navy400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
