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
    this.notificationPreferences,
  });

  final String id;
  final String email;
  final String? fullName;
  final String role;
  final bool isActive;
  final int? salaryDay;
  final bool hasPin;

  /// Null means "never saved" — the Notifications screen (blueprint Step 5b)
  /// treats an absent key the same as `true`, not `false`; see
  /// `NotificationsScreen._valueFor`.
  final Map<String, bool>? notificationPreferences;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] as String,
        isActive: json['is_active'] as bool,
        salaryDay: json['salary_day'] as int?,
        hasPin: json['has_pin'] as bool? ?? false,
        notificationPreferences: (json['notification_preferences'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value as bool)),
      );
}
