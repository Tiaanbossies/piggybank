/// Mirrors `backend/app/detection/schemas.py`'s `NotificationSourceOut`.
class NotificationSource {
  const NotificationSource({
    required this.id,
    required this.appPackageName,
    required this.appLabel,
    required this.isActive,
  });

  final String id;
  final String appPackageName;
  final String appLabel;
  final bool isActive;

  factory NotificationSource.fromJson(Map<String, dynamic> json) => NotificationSource(
        id: json['id'] as String,
        appPackageName: json['app_package_name'] as String,
        appLabel: json['app_label'] as String,
        isActive: json['is_active'] as bool,
      );
}
