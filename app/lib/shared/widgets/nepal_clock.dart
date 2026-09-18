import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/calendar/nepal_time.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Today's date and the time right now in Nepal (NPT, UTC+5:45), shown in the
/// calendar the user chose (AD or Bikram Sambat) — so the real date is always
/// on screen, whatever the phone's own timezone is set to.
class NepalClock extends StatefulWidget {
  const NepalClock({super.key});

  @override
  State<NepalClock> createState() => _NepalClockState();
}

class _NepalClockState extends State<NepalClock> {
  Timer? _timer;
  DateTime _now = NepalTime.now();

  @override
  void initState() {
    super.initState();
    // Twice a minute keeps the displayed minute accurate without redrawing needlessly.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = NepalTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navy50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.orangeDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('EEEE').format(_now)}, ${Formatters.date(_now)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Icon(Icons.schedule_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '${DateFormat('h:mm a').format(_now)} NPT',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
