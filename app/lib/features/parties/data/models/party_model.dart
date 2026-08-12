import '../../../../core/utils/formatters.dart';

class Party {
  final int id;
  final String name;
  final String partyType;
  final String customerType;
  final String phone;
  final String email;
  final String address;
  final String panNumber;
  final String vatNumber;
  final double openingBalance;
  final double balance;
  final String notes;
  final bool isActive;
  final DateTime? createdAt;

  Party({
    required this.id,
    required this.name,
    required this.partyType,
    required this.customerType,
    required this.phone,
    required this.email,
    required this.address,
    required this.panNumber,
    required this.vatNumber,
    required this.openingBalance,
    required this.balance,
    required this.notes,
    required this.isActive,
    this.createdAt,
  });

  factory Party.fromJson(Map<String, dynamic> json) => Party(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        partyType: json['party_type'] as String? ?? 'CUSTOMER',
        customerType: json['customer_type'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
        panNumber: json['pan_number'] as String? ?? '',
        vatNumber: json['vat_number'] as String? ?? '',
        openingBalance: Formatters.toDouble(json['opening_balance']),
        balance: Formatters.toDouble(json['balance']),
        notes: json['notes'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'party_type': partyType,
        if (customerType.isNotEmpty) 'customer_type': customerType,
        'phone': phone,
        'email': email,
        'address': address,
        'pan_number': panNumber,
        'vat_number': vatNumber,
        'opening_balance': openingBalance,
        'notes': notes,
        'is_active': isActive,
      };

  /// Full read-shape serialization for the offline cache — unlike [toJson]
  /// (a write body), this round-trips through [Party.fromJson] exactly.
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'party_type': partyType,
        'customer_type': customerType,
        'phone': phone,
        'email': email,
        'address': address,
        'pan_number': panNumber,
        'vat_number': vatNumber,
        'opening_balance': openingBalance,
        'balance': balance,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };

  bool get isCustomer => partyType == 'CUSTOMER' || partyType == 'BOTH';
  bool get isSupplier => partyType == 'SUPPLIER' || partyType == 'BOTH';
}

class PartyPayment {
  final int id;
  final int party;
  final String partyName;
  final String paymentType; // IN / OUT
  final double amount;
  final String paymentMethod;
  final int? bankAccount;
  final DateTime? date;
  final String note;
  final DateTime? createdAt;

  PartyPayment({
    required this.id,
    required this.party,
    required this.partyName,
    required this.paymentType,
    required this.amount,
    required this.paymentMethod,
    this.bankAccount,
    this.date,
    required this.note,
    this.createdAt,
  });

  factory PartyPayment.fromJson(Map<String, dynamic> json) => PartyPayment(
        id: json['id'] as int,
        party: json['party'] is int ? json['party'] as int : int.tryParse('${json['party']}') ?? 0,
        partyName: json['party_name'] as String? ?? '',
        paymentType: json['payment_type'] as String? ?? 'IN',
        amount: Formatters.toDouble(json['amount']),
        paymentMethod: json['payment_method'] as String? ?? 'CASH',
        bankAccount: json['bank_account'] as int?,
        date: Formatters.parseDate(json['date'] as String?),
        note: json['note'] as String? ?? '',
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'party': party,
        'payment_type': paymentType,
        'amount': amount,
        'payment_method': paymentMethod,
        'bank_account': bankAccount,
        'date': date != null ? Formatters.apiDate(date!) : null,
        'note': note,
      };
}

class LedgerEntry {
  final DateTime? date;
  final String type;
  final String ref;
  final double debit;
  final double credit;
  final double balance;
  final String note;

  LedgerEntry({
    this.date,
    required this.type,
    required this.ref,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.note,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        date: Formatters.parseDate(json['date'] as String?),
        type: json['type'] as String? ?? '',
        ref: json['ref']?.toString() ?? '',
        debit: Formatters.toDouble(json['debit']),
        credit: Formatters.toDouble(json['credit']),
        balance: Formatters.toDouble(json['balance']),
        note: json['note']?.toString() ?? '',
      );
}

class PartyLedger {
  final Party party;
  final double openingBalance;
  final List<LedgerEntry> entries;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;

  PartyLedger({
    required this.party,
    required this.openingBalance,
    required this.entries,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
  });

  factory PartyLedger.fromJson(Map<String, dynamic> json) => PartyLedger(
        party: Party.fromJson(json['party'] as Map<String, dynamic>),
        openingBalance: Formatters.toDouble(json['opening_balance']),
        entries: (json['entries'] as List? ?? [])
            .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalDebit: Formatters.toDouble(json['total_debit']),
        totalCredit: Formatters.toDouble(json['total_credit']),
        closingBalance: Formatters.toDouble(json['closing_balance']),
      );
}
