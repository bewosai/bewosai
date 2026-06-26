class BusinessModel {
  final int id;
  final String name;
  final String businessType;
  final String address;
  final String phone;
  final String email;
  final String plan;
  final String status;

  const BusinessModel({
    required this.id,
    required this.name,
    required this.businessType,
    required this.address,
    required this.phone,
    required this.email,
    required this.plan,
    required this.status,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> j) => BusinessModel(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        businessType: j['business_type'] ?? '',
        address: j['address'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        plan: j['plan'] ?? 'FREE',
        status: j['status'] ?? 'ACTIVE',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'business_type': businessType,
        'address': address,
        'phone': phone,
        'email': email,
        'plan': plan,
        'status': status,
      };
}
