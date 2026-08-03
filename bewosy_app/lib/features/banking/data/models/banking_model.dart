import '../../../../core/utils/formatters.dart';

class BankAccount {
  final int id;
  final String accountName;
  final String bankName;
  final String accountNumber;
  final String accountType;
  final double openingBalance;
  final String? qrCode;
  final String? qrCodeUrl;
  final double balance;
  final bool isActive;
  final DateTime? createdAt;

  BankAccount({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    required this.openingBalance,
    this.qrCode,
    this.qrCodeUrl,
    required this.balance,
    required this.isActive,
    this.createdAt,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: json['id'] as int,
        accountName: json['account_name'] as String? ?? '',
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountType: json['account_type'] as String? ?? 'CASH',
        openingBalance: Formatters.toDouble(json['opening_balance']),
        qrCode: json['qr_code'] as String?,
        qrCodeUrl: json['qr_code_url'] as String?,
        balance: Formatters.toDouble(json['balance']),
        isActive: json['is_active'] as bool? ?? true,
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'account_name': accountName,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_type': accountType,
        'opening_balance': openingBalance,
      };
}

class BankTransaction {
  final int id;
  final int account;
  final String accountName;
  final String transactionType; // CREDIT / DEBIT
  final double amount;
  final DateTime? date;
  final String description;
  final String reference;
  final DateTime? createdAt;

  BankTransaction({
    required this.id,
    required this.account,
    required this.accountName,
    required this.transactionType,
    required this.amount,
    this.date,
    required this.description,
    required this.reference,
    this.createdAt,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> json) => BankTransaction(
        id: json['id'] as int,
        account: json['account'] is int ? json['account'] as int : int.tryParse('${json['account']}') ?? 0,
        accountName: json['account_name'] as String? ?? '',
        transactionType: json['transaction_type'] as String? ?? 'CREDIT',
        amount: Formatters.toDouble(json['amount']),
        date: Formatters.parseDate(json['date'] as String?),
        description: json['description'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        createdAt: Formatters.parseDate(json['created_at'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'account': account,
        'transaction_type': transactionType,
        'amount': amount,
        'date': date != null ? Formatters.apiDate(date!) : null,
        'description': description,
        'reference': reference,
      };
}
