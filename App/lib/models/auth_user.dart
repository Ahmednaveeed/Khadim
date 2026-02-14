class AuthUser {
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;

  AuthUser({
    required this.userId,
    required this.fullName,
    this.email,
    this.phone,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['user_id'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}