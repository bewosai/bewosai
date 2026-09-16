import '../../../../core/utils/formatters.dart';

class PurchaseItem {
  final int? id;
  final int? product;
  final String productName;
  final String hsCode;
  // Which of the product's units this line was billed in — see
  // SaleItem.unitLabel for the full rationale (same backend model on both).
  final String unitLabel;
  final double quantity;
  // Product's unit config, snapshotted via the product FK at read time —
  // lets a saved bill show the primary/secondary unit even though this
  // line only recorded which one it was billed in (mirrors SaleItem).
  final String productUnitName;
  final String productUnitSecondary;
  final double? productUnitConversionFactor;
  final double unitPrice;
  final double discountAmount;
  final double total;

  PurchaseItem({
    this.id,
    this.product,
    required this.productName,
    this.hsCode = '',
    this.unitLabel = '',
    required this.quantity,
    this.productUnitName = '',
    this.productUnitSecondary = '',
    this.productUnitConversionFactor,
    required this.unitPrice,
    this.discountAmount = 0,
    this.total = 0,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        id: json['id'] as int?,
        product: json['product'] as int?,
        productName: json['product_name'] as String? ?? '',
        hsCode: json['product_hs_code'] as String? ?? '',
        unitLabel: json['unit_label'] as String? ?? '',
        quantity: Formatters.toDouble(json['quantity']),
        productUnitName: json['product_unit_name'] as String? ?? '',
        productUnitSecondary: json['product_unit_secondary'] as String? ?? '',
        productUnitConversionFactor:
            json['product_unit_conversion_factor'] == null ? null : Formatters.toDouble(json['product_unit_conversion_factor']),
        unitPrice: Formatters.toDouble(json['unit_price']),
        discountAmount: Formatters.toDouble(json['discount_amount']),
        total: Formatters.toDouble(json['total']),
      );

  Map<String, dynamic> toJson() => {
        if (product != null) 'product': product,
        'product_name': productName,
        'unit_label': unitLabel,
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
  final String supplierPhone;
  final String supplierPan;
  final String supplierAddress;
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
  // Cash portion of paidAmount when paymentMethod is 'SPLIT' — the
  // remainder (paidAmount - cashAmount) is paid from bankAccount. Unused
  // (0) for every other payment method.
  final double cashAmount;
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
    this.supplierPhone = '',
    this.supplierPan = '',
    this.supplierAddress = '',
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
    this.cashAmount = 0,
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
        supplierPhone: json['supplier_phone'] as String? ?? '',
        supplierPan: json['supplier_pan'] as String? ?? '',
        supplierAddress: json['supplier_address'] as String? ?? '',
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
        cashAmount: Formatters.toDouble(json['cash_amount']),
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
        'cash_amount': paymentMethod == 'SPLIT' ? cashAmount : 0,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class PurchaseReturnItem {
  final int? purchaseItem;
  final int? product;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;

  PurchaseReturnItem({
    this.purchaseItem,
    this.product,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.total = 0,
  });

  factory PurchaseReturnItem.fromJson(Map<String, dynamic> json) => PurchaseReturnItem(
        purchaseItem: json['purchase_item'] as int?,
        product: json['product'] as int?,
        productName: json['product_name'] as String? ?? '',
        quantity: Formatters.toDouble(json['quantity']),
        unitPrice: Formatters.toDouble(json['unit_price']),
        total: Formatters.toDouble(json['total']),
      );

  Map<String, dynamic> toJson() => {
        if (purchaseItem != null) 'purchase_item': purchaseItem,
        if (product != null) 'product': product,
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

class PurchaseReturn {
  final int id;
  final int originalPurchase;
  final String originalPurchaseNumber;
  final DateTime? returnDate;
  final String reason;
  final double amount;
  final List<PurchaseReturnItem> items;
  final DateTime? createdAt;

  PurchaseReturn({
    required this.id,
    required this.originalPurchase,
    required this.originalPurchaseNumber,
    this.returnDate,
    required this.reason,
    required this.amount,
    this.items = const [],
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
        items: (json['items'] as List? ?? [])
            .map((e) => PurchaseReturnItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'original_purchase': originalPurchase,
        'return_date': returnDate != null ? Formatters.apiDate(returnDate!) : null,
        'reason': reason,
        'amount': amount,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
