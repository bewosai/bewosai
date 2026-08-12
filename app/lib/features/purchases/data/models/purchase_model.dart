import '../../../../core/utils/formatters.dart';

class PurchaseItem {
  final int? id;
  final int? product;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double total;

  PurchaseItem({
    this.id,
    this.product,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    this.total = 0,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        id: json['id'] as int?,
        product: json['product'] as int?,
        productName: json['product_name'] as String? ?? '',
        quantity: Formatters.toDouble(json['quantity']),
        unitPrice: Formatters.toDouble(json['unit_price']),
        discountAmount: Formatters.toDouble(json['discount_amount']),
        total: Formatters.toDouble(json['total']),
      );

  Map<String, dynamic> toJson() => {
        if (product != null) 'product': product,
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_amount': discountAmount,
      };

  double get lineTotal => (quantity * unitPrice) - discountAmount;
}

class Purchase {
  final int id;
  final String billNumber;
  final int? supplier;
  final String supplierName;
  final DateTime? purchaseDate;
  final DateTime? dueDate;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double total;
  final double paidAmount;
  final double dueAmount;
  final String paymentMethod;
  final int? bankAccount;
  final String status;
  final String notes;
  final String? billImage;
  final String? billImageUrl;
  final List<PurchaseItem> items;
  final DateTime? createdAt;

  Purchase({
    required this.id,
    required this.billNumber,
    this.supplier,
    required this.supplierName,
    this.purchaseDate,
    this.dueDate,
    required this.subtotal,
    required this.discount,
    this.taxRate = 0,
    this.taxAmount = 0,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMethod,
    this.bankAccount,
    required this.status,
    required this.notes,
    this.billImage,
    this.billImageUrl,
    required this.items,
    this.createdAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as int,
        billNumber: json['bill_number'] as String? ?? '',
        supplier: json['supplier'] as int?,
        supplierName: json['supplier_name'] as String? ?? '',
        purchaseDate: Formatters.parseDate(json['purchase_date'] as String?),
        dueDate: Formatters.parseDate(json['due_date'] as String?),
        subtotal: Formatters.toDouble(json['subtotal']),
        discount: Formatters.toDouble(json['discount']),
        taxRate: Formatters.toDouble(json['tax_rate']),
        taxAmount: Formatters.toDouble(json['tax_amount']),
        total: Formatters.toDouble(json['total']),
        paidAmount: Formatters.toDouble(json['paid_amount']),
        dueAmount: Formatters.toDouble(json['due_amount']),
        paymentMethod: json['payment_method'] as String? ?? 'CASH',
        bankAccount: json['bank_account'] as int?,
        status: json['status'] as String? ?? 'CONFIRMED',
        notes: json['notes'] as String? ?? '',
        billImage: json['bill_image'] as String?,
        billImageUrl: json['bill_image_url'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        if (billNumber.isNotEmpty) 'bill_number': billNumber,
        if (supplier != null) 'supplier': supplier,
        'purchase_date': purchaseDate != null ? Formatters.apiDate(purchaseDate!) : null,
        'due_date': dueDate != null ? Formatters.apiDate(dueDate!) : null,
        'discount': discount,
        'tax_rate': taxRate,
        'paid_amount': paidAmount,
        'payment_method': paymentMethod,
        'bank_account': bankAccount,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class PurchaseReturn {
  final int id;
  final int originalPurchase;
  final String originalPurchaseNumber;
  final DateTime? returnDate;
  final String reason;
  final double amount;
  final DateTime? createdAt;

  PurchaseReturn({
    required this.id,
    required this.originalPurchase,
    required this.originalPurchaseNumber,
    this.returnDate,
    required this.reason,
    required this.amount,
    this.createdAt,
  });

  factory PurchaseReturn.fromJson(Map<String, dynamic> json) => PurchaseReturn(
        id: json['id'] as int,
        originalPurchase: json['original_purchase'] is int
            ? json['original_purchase'] as int
            : int.tryParse('${json['original_purchase']}') ?? 0,
        originalPurchaseNumber: json['original_purchase_number'] as String? ?? '',
        returnDate: Formatters.parseDate(json['return_date'] as String?),
        reason: json['reason'] as String? ?? '',
        amount: Formatters.toDouble(json['amount']),
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'original_purchase': originalPurchase,
        'return_date': returnDate != null ? Formatters.apiDate(returnDate!) : null,
        'reason': reason,
        'amount': amount,
      };
}
