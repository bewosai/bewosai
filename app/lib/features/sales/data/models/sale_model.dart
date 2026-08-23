import '../../../../core/utils/formatters.dart';

class SaleItem {
  final int? id;
  final int? product;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double total;

  SaleItem({
    this.id,
    this.product,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    this.total = 0,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
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

class Sale {
  final int id;
  final String invoiceNumber;
  final int? customer;
  final String customerName;
  final String partyPhone;
  final String partyPan;
  final String partyAddress;
  final DateTime? saleDate;
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
  final String saleType;
  final String notes;
  final bool reminderEnabled;
  final DateTime? reminderAt;
  final List<SaleItem> items;
  final DateTime? createdAt;

  /// True for a sale created while offline and still waiting in the local
  /// outbox — see [SyncService]. Never comes from/goes to the API; purely a
  /// local UI signal ("Pending Sync" chip) until the real sync round-trip
  /// replaces this row with the server's version.
  final bool pendingSync;

  /// Set only for a queued offline sale the server has already rejected
  /// (e.g. a duplicate invoice number) — never comes from/goes to the API.
  /// Non-null means [pendingSync] is stuck until the user edits and resends
  /// this sale; see [SyncService].
  final String? syncError;

  Sale({
    required this.id,
    required this.invoiceNumber,
    this.customer,
    required this.customerName,
    required this.partyPhone,
    this.partyPan = '',
    this.partyAddress = '',
    this.saleDate,
    this.dueDate,
    required this.subtotal,
    required this.discount,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMethod,
    this.bankAccount,
    required this.status,
    required this.saleType,
    required this.notes,
    this.reminderEnabled = false,
    this.reminderAt,
    required this.items,
    this.createdAt,
    this.pendingSync = false,
    this.syncError,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as int,
        invoiceNumber: json['invoice_number'] as String? ?? '',
        customer: json['customer'] as int?,
        customerName: (json['customer_name'] ?? json['party_name']) as String? ?? '',
        partyPhone: json['party_phone'] as String? ?? '',
        partyPan: json['party_pan'] as String? ?? '',
        partyAddress: json['party_address'] as String? ?? '',
        saleDate: Formatters.parseDate(json['sale_date'] as String?),
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
        saleType: json['sale_type'] as String? ?? 'SALE',
        notes: json['notes'] as String? ?? '',
        reminderEnabled: json['reminder_enabled'] as bool? ?? false,
        reminderAt: Formatters.parseDate(json['reminder_at'] as String?),
        items: (json['items'] as List? ?? [])
            .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        if (invoiceNumber.isNotEmpty) 'invoice_number': invoiceNumber,
        if (customer != null) 'customer': customer,
        'sale_date': saleDate != null ? Formatters.apiDate(saleDate!) : null,
        'due_date': dueDate != null ? Formatters.apiDate(dueDate!) : null,
        'discount': discount,
        'tax_rate': taxRate,
        'paid_amount': paidAmount,
        'payment_method': paymentMethod,
        'bank_account': bankAccount,
        'status': status,
        'sale_type': saleType,
        'notes': notes,
        'reminder_enabled': reminderEnabled,
        if (reminderAt != null) 'reminder_at': reminderAt!.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  bool get isOverdue =>
      status == 'CONFIRMED' && dueAmount > 0 && dueDate != null && dueDate!.isBefore(DateTime.now());
}

class SaleReturnItem {
  final int? id;
  final int? saleItem;
  final int? product;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;

  SaleReturnItem({
    this.id,
    this.saleItem,
    this.product,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.total = 0,
  });

  factory SaleReturnItem.fromJson(Map<String, dynamic> json) => SaleReturnItem(
        id: json['id'] as int?,
        saleItem: json['sale_item'] as int?,
        product: json['product'] as int?,
        productName: json['product_name'] as String? ?? '',
        quantity: Formatters.toDouble(json['quantity']),
        unitPrice: Formatters.toDouble(json['unit_price']),
        total: Formatters.toDouble(json['total']),
      );

  Map<String, dynamic> toJson() => {
        if (saleItem != null) 'sale_item': saleItem,
        if (product != null) 'product': product,
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

class SaleReturn {
  final int id;
  final int originalSale;
  final String invoiceNumber;
  final DateTime? returnDate;
  final String reason;
  final double amount;
  final List<SaleReturnItem> items;
  final DateTime? createdAt;

  SaleReturn({
    required this.id,
    required this.originalSale,
    required this.invoiceNumber,
    this.returnDate,
    required this.reason,
    required this.amount,
    this.items = const [],
    this.createdAt,
  });

  factory SaleReturn.fromJson(Map<String, dynamic> json) => SaleReturn(
        id: json['id'] as int,
        originalSale: json['original_sale'] is int
            ? json['original_sale'] as int
            : int.tryParse('${json['original_sale']}') ?? 0,
        invoiceNumber: json['invoice_number'] as String? ?? '',
        returnDate: Formatters.parseDate(json['return_date'] as String?),
        reason: json['reason'] as String? ?? '',
        amount: Formatters.toDouble(json['amount']),
        items: (json['items'] as List? ?? [])
            .map((e) => SaleReturnItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'original_sale': originalSale,
        'return_date': returnDate != null ? Formatters.apiDate(returnDate!) : null,
        'reason': reason,
        'amount': amount,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class Quotation {
  final int id;
  final String quotationNumber;
  final int? customer;
  final String customerName;
  final DateTime? date;
  final DateTime? expiryDate;
  final double subtotal;
  final double discount;
  final double total;
  final String status;
  final String notes;
  final DateTime? createdAt;

  Quotation({
    required this.id,
    required this.quotationNumber,
    this.customer,
    required this.customerName,
    this.date,
    this.expiryDate,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.status,
    required this.notes,
    this.createdAt,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) => Quotation(
        id: json['id'] as int,
        quotationNumber: json['quotation_number'] as String? ?? '',
        customer: json['customer'] as int?,
        customerName: json['customer_name'] as String? ?? '',
        date: Formatters.parseDate(json['date'] as String?),
        expiryDate: Formatters.parseDate(json['expiry_date'] as String?),
        subtotal: Formatters.toDouble(json['subtotal']),
        discount: Formatters.toDouble(json['discount']),
        total: Formatters.toDouble(json['total']),
        status: json['status'] as String? ?? 'DRAFT',
        notes: json['notes'] as String? ?? '',
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        if (customer != null) 'customer': customer,
        'date': date != null ? Formatters.apiDate(date!) : null,
        'expiry_date': expiryDate != null ? Formatters.apiDate(expiryDate!) : null,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'status': status,
        'notes': notes,
      };
}
