enum Role { admin, staff }

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

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    role: json['role'] == 'ADMIN' ? Role.admin : Role.staff,
  );
}
