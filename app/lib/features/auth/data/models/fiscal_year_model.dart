import '../../../../core/utils/formatters.dart';

/// A closed period on a business — see accounts.CloseFiscalYearView on the
/// backend. Read-only from the app's side; closing is the only action.
class FiscalYear {
  final int id;
  final DateTime? startDate;
  final DateTime? endDate;
  final String label;
  final String status;
  final String closedByName;
  final DateTime? closedAt;

  FiscalYear({
    required this.id,
    this.startDate,
    this.endDate,
    required this.label,
    required this.status,
    this.closedByName = '',
    this.closedAt,
  });

  factory FiscalYear.fromJson(Map<String, dynamic> json) => FiscalYear(
        id: json['id'] as int,
        startDate: Formatters.parseDate(json['start_date'] as String?),
        endDate: Formatters.parseDate(json['end_date'] as String?),
        label: json['label'] as String? ?? '',
        status: json['status'] as String? ?? 'CLOSED',
        closedByName: json['closed_by_name'] as String? ?? '',
        closedAt: Formatters.parseDate(json['closed_at'] as String?),
      );
}
