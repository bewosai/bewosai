import '../../../../core/utils/formatters.dart';

class RecycleBinItem {
  final String type;
  final int id;
  final String label;
  final DateTime? deletedAt;

  RecycleBinItem({required this.type, required this.id, required this.label, this.deletedAt});

  factory RecycleBinItem.fromJson(Map<String, dynamic> json) => RecycleBinItem(
        type: json['type'] as String? ?? '',
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
        deletedAt: Formatters.parseDate(json['deleted_at'] as String?),
      );
}
