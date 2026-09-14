/// Mirrors `backend/app/transactions/schemas.py`'s `CategorizeBatchResult`
/// (response of `POST /transactions/categorize-batch`).
class CategorizeBatchResult {
  const CategorizeBatchResult({
    required this.processed,
    required this.categorized,
    required this.skippedInvalid,
    required this.remaining,
  });

  final int processed;
  final int categorized;
  final int skippedInvalid;
  final int remaining;

  factory CategorizeBatchResult.fromJson(Map<String, dynamic> json) => CategorizeBatchResult(
        processed: json['processed'] as int,
        categorized: json['categorized'] as int,
        skippedInvalid: json['skipped_invalid'] as int,
        remaining: json['remaining'] as int,
      );
}
