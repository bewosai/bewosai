// Pure business entity — no JSON, no Flutter dependency
class BusinessEntity {
  final int id;
  final String name;
  final String businessType;
  final String address;
  final String phone;
  final String email;
  final String plan;
  final String status;

  const BusinessEntity({
    required this.id,
    required this.name,
    required this.businessType,
    required this.address,
    required this.phone,
    required this.email,
    required this.plan,
    required this.status,
  });
}
