// Plain JSON models for `/api/consents/*`. Lives in `core` (not a feature
// folder) since both `core/auth` (bootstrap-time consent check) and the
// `features/consent` UI layer need it.

/// One entry from `GET /consents/required` — mirrors
/// `backend/app/consents/schemas.py`'s `RequiredDocumentOut`.
class RequiredDocument {
  const RequiredDocument({required this.documentType, required this.documentVersion});

  final String documentType;
  final String documentVersion;

  factory RequiredDocument.fromJson(Map<String, dynamic> json) => RequiredDocument(
        documentType: json['document_type'] as String,
        documentVersion: json['document_version'] as String,
      );
}

/// One entry from `GET /consents/` — mirrors `ConsentOut`. Only the fields
/// the client actually needs (diffing against [RequiredDocument]) are kept;
/// `ip_address`/`created_at`/`updated_at` aren't modeled.
class ConsentRecord {
  const ConsentRecord({
    required this.id,
    required this.documentType,
    required this.documentVersion,
    required this.acceptedAt,
  });

  final String id;
  final String documentType;
  final String documentVersion;
  final DateTime acceptedAt;

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        id: json['id'] as String,
        documentType: json['document_type'] as String,
        documentVersion: json['document_version'] as String,
        acceptedAt: DateTime.parse(json['accepted_at'] as String),
      );
}
