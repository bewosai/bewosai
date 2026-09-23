import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';

import '../../core/calendar/nepali_calendar_service.dart';
import '../../core/i18n/translations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/calendar/nepal_time.dart';

/// Date-picking entry point used everywhere a form needs a date. Shows the
/// standard Material (Gregorian) picker, or a Bikram Sambat grid picker when
/// the user's "Show Bikram Sambat dates" setting is on — so a BS-preferring
/// user never has to mentally convert from an AD-only picker to enter a date.
/// Always returns a Gregorian [DateTime] (the wire format), regardless of
/// which calendar was shown.
class AppDatePicker {
  static Future<DateTime?> pick(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final first = firstDate ?? DateTime(2000);
    final last = lastDate ?? DateTime(2100);
    if (!Formatters.useNepaliCalendar) {
      return showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: first,
        lastDate: last,
      );
    }
    return showDialog<DateTime>(
      context: context,
      builder: (_) => _NepaliDatePickerDialog(
        initialDate: initialDate,
        firstDate: first,
        lastDate: last,
      ),
    );
  }
}

class _NepaliDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  const _NepaliDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_NepaliDatePickerDialog> createState() =>
      _NepaliDatePickerDialogState();
}

class _NepaliDatePickerDialogState extends State<_NepaliDatePickerDialog> {
  late NepaliDateTime _selected;
  late int _displayYear;
  late int _displayMonth;

  Language get _lang =>
      AppTranslations.language == 'ne' ? Language.nepali : Language.english;

  @override
  void initState() {
    super.initState();
    _selected = NepaliCalendarService.toNepali(widget.initialDate);
    _displayYear = _selected.year;
    _displayMonth = _selected.month;
  }

  /// The month [delta] away, or null when it can't be shown: outside the
  /// years the calendar package supports (constructing a date there throws —
  /// a red error screen), or wholly outside [firstDate, lastDate].
  ({int year, int month})? _target(int delta) {
    var y = _displayYear;
    var m = _displayMonth + delta;
    if (m > 12) {
      m = 1;
      y += 1;
    } else if (m < 1) {
      m = 12;
      y -= 1;
    }
    if (y < NepaliCalendarService.firstBsYear || y > NepaliCalendarService.lastBsYear) return null;
    final first = NepaliCalendarService.toGregorian(NepaliDateTime(y, m, 1));
    final last = first.add(
      Duration(days: NepaliCalendarService.daysInMonth(y, m) - 1),
    );
    if (last.isBefore(widget.firstDate) || first.isAfter(widget.lastDate)) {
      return null;
    }
    return (year: y, month: m);
  }

  void _shiftMonth(int delta) {
    if (_target(delta) == null) return;
    setState(() {
      var y = _displayYear;
      var m = _displayMonth + delta;
      if (m > 12) {
        m = 1;
        y += 1;
      } else if (m < 1) {
        m = 12;
        y -= 1;
      }
      _displayYear = y;
      _displayMonth = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = NepaliCalendarService.toNepali(NepalTime.now());
    final monthStart = NepaliDateTime(_displayYear, _displayMonth, 1);
    final daysInMonth = NepaliCalendarService.daysInMonth(_displayYear, _displayMonth);
    // Sun=1..Sat=7, from our own table (the package's weekday would use its own).
    final leadingBlanks = NepaliCalendarService.firstWeekday(_displayYear, _displayMonth) - 1;
    final weekdayLabels = _lang == Language.nepali
        ? ['आ', 'सो', 'मं', 'बु', 'बि', 'शु', 'श']
        : ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only the month grid scrolls (a short screen, e.g. a phone held
            // sideways, would otherwise overflow); OK/Cancel stay pinned below.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _target(-1) == null
                              ? null
                              : () => _shiftMonth(-1),
                        ),
                        Text(
                          monthStart.format('MMMM yyyy', _lang),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _target(1) == null
                              ? null
                              : () => _shiftMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: weekdayLabels
                          .map(
                            (w) => Expanded(
                              child: Center(
                                child: Text(
                                  w,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 4),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                          ),
                      itemCount: leadingBlanks + daysInMonth,
                      itemBuilder: (ctx, index) {
                        if (index < leadingBlanks) {
                          return const SizedBox.shrink();
                        }
                        final day = index - leadingBlanks + 1;
                        final candidate = NepaliDateTime(
                          _displayYear,
                          _displayMonth,
                          day,
                        );
                        final isSelected =
                            _selected.year == _displayYear &&
                            _selected.month == _displayMonth &&
                            _selected.day == day;
                        final gregorian = NepaliCalendarService.toGregorian(
                          candidate,
                        );
                        final outOfRange =
                            gregorian.isBefore(widget.firstDate) ||
                            gregorian.isAfter(widget.lastDate);
                        return InkWell(
                          onTap: outOfRange
                              ? null
                              : () => setState(() => _selected = candidate),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.orange : null,
                              shape: BoxShape.circle,
                              // Today, by the real date, is always ringed so it's easy to find.
                              border:
                                  !isSelected &&
                                      today.year == _displayYear &&
                                      today.month == _displayMonth &&
                                      today.day == day
                                  ? Border.all(color: AppColors.orange)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: outOfRange
                                    ? AppColors.textSecondary.withValues(
                                        alpha: 0.4,
                                      )
                                    : isSelected
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    NepaliCalendarService.toGregorian(_selected),
                  ),
                  child: Text(t('ok')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
