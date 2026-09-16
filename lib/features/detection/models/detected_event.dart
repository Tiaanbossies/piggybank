enum DetectionSourceType { notification, email }

DetectionSourceType detectionSourceTypeFromJson(String value) =>
    DetectionSourceType.values.firstWhere((t) => t.name == value, orElse: () => DetectionSourceType.notification);

enum DetectionStatus { pending, confirmed, discarded, skippedInvalid }

DetectionStatus detectionStatusFromJson(String value) {
  switch (value) {
    case 'skipped_invalid':
      return DetectionStatus.skippedInvalid;
    default:
      return DetectionStatus.values.firstWhere((s) => s.name == value, orElse: () => DetectionStatus.pending);
  }
}

/// Mirrors `backend/app/detection/schemas.py`'s `DetectedEventOut`. Only a
/// skipped_invalid row has a null [extractedJson]/[eventKind] — a pending
/// row always has both populated by the backend's own write path
/// (`financial_event_extractor.process_detected_items`).
class DetectedEvent {
  const DetectedEvent({
    required this.id,
    required this.sourceType,
    required this.sourceRef,
    required this.rawText,
    required this.capturedAt,
    required this.status,
    required this.extractedJson,
    required this.eventKind,
    required this.errorReason,
  });

  final String id;
  final DetectionSourceType sourceType;
  final String sourceRef;
  final String rawText;
  final DateTime capturedAt;
  final DetectionStatus status;
  final Map<String, dynamic>? extractedJson;
  final String? eventKind;
  final String? errorReason;

  factory DetectedEvent.fromJson(Map<String, dynamic> json) => DetectedEvent(
        id: json['id'] as String,
        sourceType: detectionSourceTypeFromJson(json['source_type'] as String),
        sourceRef: json['source_ref'] as String,
        rawText: json['raw_text'] as String,
        capturedAt: DateTime.parse(json['captured_at'] as String),
        status: detectionStatusFromJson(json['status'] as String),
        extractedJson: (json['extracted_json'] as Map?)?.cast<String, dynamic>(),
        eventKind: json['event_kind'] as String?,
        errorReason: json['error_reason'] as String?,
      );
}
