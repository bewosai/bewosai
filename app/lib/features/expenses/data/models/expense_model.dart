import '../../../../core/utils/formatters.dart';

/// Expense category (data layer).
class ExpenseCategory {
  final int id;
  final String name;
  final String expenseType;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.expenseType,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      expenseType: json['expense_type']?.toString() ?? 'OTHER',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'expense_type': expenseType,
      };

  ExpenseCategory copyWith({
    int? id,
    String? name,
    String? expenseType,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      expenseType: expenseType ?? this.expenseType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Single expense entry (data layer).
class Expense {
  final int id;
  final int? category;
  final String categoryName;
  final double amount;
  final DateTime? date;
  final String description;
  final String paymentMethod;
  final String? receiptImage;
  final String? receiptImageUrl;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    this.category,
    required this.categoryName,
    required this.amount,
    this.date,
    required this.description,
    required this.paymentMethod,
    this.receiptImage,
    this.receiptImageUrl,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: _toInt(json['id']),
      category: _toIntOrNull(json['category']),
      categoryName: json['category_name']?.toString() ?? '',
      amount: Formatters.toDouble(json['amount']),
      date: Formatters.parseDate(json['date']?.toString()),
      description: json['description']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? 'CASH',
      receiptImage: json['receipt_image']?.toString(),
      receiptImageUrl: json['receipt_image_url']?.toString(),
      createdAt: Formatters.parseDate(json['created_at']?.toString()),
    );
  }

  /// Create / update body only (no id or read-only fields).
  Map<String, dynamic> toJson() => {
        if (category != null) 'category': category,
        'amount': amount,
        if (date != null) 'date': Formatters.apiDate(date!),
        'description': description,
        'payment_method': paymentMethod,
      };

  Expense copyWith({
    int? id,
    int? category,
    String? categoryName,
    double? amount,
    DateTime? date,
    String? description,
    String? paymentMethod,
    String? receiptImage,
    String? receiptImageUrl,
    DateTime? createdAt,
    bool clearCategory = false,
  }) {
    return Expense(
      id: id ?? this.id,
      category: clearCategory ? null : (category ?? this.category),
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptImage: receiptImage ?? this.receiptImage,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Safe parsers ──────────────────────────────────────────────────────────────

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return int.tryParse(v.toString()) ?? 0;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) {
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }
  return int.tryParse(v.toString());
}