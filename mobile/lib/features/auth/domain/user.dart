enum Role {
  admin('ADMIN', 'Admin'),
  staff('STAFF', 'Warehouse'),
  technician('TECHNICIAN', 'Technician'),
  supervisor('SUPERVISOR', 'Supervisor');

  const Role(this.api, this.label);

  final String api;
  final String label;

  static Role fromApi(String v) =>
      values.firstWhere((r) => r.api == v, orElse: () => Role.staff);
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final Role role;

  bool get isAdmin => role == Role.admin;

  /// May create stock documents (the server enforces the same rule).
  bool get canWriteInventory => role == Role.admin || role == Role.staff;

  /// May see the dashboard and stock documents.
  bool get canSeeInventory => canWriteInventory || role == Role.supervisor;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    role: Role.fromApi(json['role'] as String),
  );
}
