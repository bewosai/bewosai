class Business {
  final int id;
  final String name;
  final String businessType;
  final String address;
  final String phone;
  final String email;
  final String? logo;
  final String panNumber;
  final String vatNumber;
  final String currency;
  final String fiscalYearStart;
  final double defaultTaxRate;
  final String plan;
  final String status;
  final int owner;
  final String ownerName;
  final int staffCount;
  // Platform-admin-only override of the plan-based staff cap (Free=1/
  // Premium=8) — null means "use the plan default". Never settable from
  // this app; surfaced read-only so the invite-limit check can match
  // whatever the backend will actually enforce (see accounts/views.py).
  final int? staffLimitOverride;

  Business({
    required this.id,
    required this.name,
    required this.businessType,
    required this.address,
    required this.phone,
    required this.email,
    this.logo,
    required this.panNumber,
    required this.vatNumber,
    required this.currency,
    required this.fiscalYearStart,
    required this.defaultTaxRate,
    required this.plan,
    required this.status,
    required this.owner,
    required this.ownerName,
    required this.staffCount,
    this.staffLimitOverride,
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        businessType: json['business_type'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        logo: json['logo'] as String?,
        panNumber: json['pan_number'] as String? ?? '',
        vatNumber: json['vat_number'] as String? ?? '',
        currency: json['currency'] as String? ?? 'NPR',
        fiscalYearStart: json['fiscal_year_start'] as String? ?? '07-16',
        defaultTaxRate: double.tryParse('${json['default_tax_rate'] ?? ''}') ?? 13,
        plan: json['plan'] as String? ?? 'FREE',
        status: json['status'] as String? ?? 'ACTIVE',
        owner: json['owner'] is int ? json['owner'] as int : int.tryParse('${json['owner']}') ?? 0,
        ownerName: json['owner_name'] as String? ?? '',
        staffCount: json['staff_count'] as int? ?? 1,
        staffLimitOverride: json['staff_limit_override'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'business_type': businessType,
        'address': address,
        'phone': phone,
        'email': email,
        'pan_number': panNumber,
        'vat_number': vatNumber,
        'currency': currency,
        'fiscal_year_start': fiscalYearStart,
        'default_tax_rate': defaultTaxRate,
      };

  Map<String, dynamic> toRawJson() => {
        'id': id,
        'name': name,
        'business_type': businessType,
        'address': address,
        'phone': phone,
        'email': email,
        'logo': logo,
        'pan_number': panNumber,
        'vat_number': vatNumber,
        'currency': currency,
        'fiscal_year_start': fiscalYearStart,
        'default_tax_rate': defaultTaxRate,
        'plan': plan,
        'status': status,
        'owner': owner,
        'owner_name': ownerName,
        'staff_count': staffCount,
        'staff_limit_override': staffLimitOverride,
      };
}
