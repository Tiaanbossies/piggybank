/// Mirrors `backend/app/detection/schemas.py`'s `GmailConnectionStatusOut`.
class GmailConnectionStatus {
  const GmailConnectionStatus({required this.connected, this.scope, this.lastPolledAt});

  final bool connected;
  final String? scope;
  final DateTime? lastPolledAt;

  factory GmailConnectionStatus.fromJson(Map<String, dynamic> json) => GmailConnectionStatus(
        connected: json['connected'] as bool,
        scope: json['scope'] as String?,
        lastPolledAt: json['last_polled_at'] == null ? null : DateTime.parse(json['last_polled_at'] as String),
      );
}
