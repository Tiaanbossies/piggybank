/// Mirrors `backend/app/detection/schemas.py`'s `EmailSourceOut`.
class EmailSource {
  const EmailSource({
    required this.id,
    required this.senderEmail,
    required this.label,
    required this.isActive,
  });

  final String id;
  final String senderEmail;
  final String label;
  final bool isActive;

  factory EmailSource.fromJson(Map<String, dynamic> json) => EmailSource(
        id: json['id'] as String,
        senderEmail: json['sender_email'] as String,
        label: json['label'] as String,
        isActive: json['is_active'] as bool,
      );
}
