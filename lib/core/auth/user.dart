/// Mirrors `backend/app/auth/schemas.py`'s `UserOut`.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.salaryDay,
    this.hasPin = false,
  });

  final String id;
  final String email;
  final String? fullName;
  final String role;
  final bool isActive;
  final int? salaryDay;
  final bool hasPin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] as String,
        isActive: json['is_active'] as bool,
        salaryDay: json['salary_day'] as int?,
        hasPin: json['has_pin'] as bool? ?? false,
      );
}
