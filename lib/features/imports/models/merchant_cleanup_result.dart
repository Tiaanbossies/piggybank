/// Mirrors `backend/app/transactions/schemas.py`'s `CleanMerchantNamesResult`
/// (response of `POST /transactions/clean-merchant-names`).
class MerchantCleanupResult {
  const MerchantCleanupResult({
    required this.processed,
    required this.cleaned,
    required this.skippedInvalid,
    required this.remaining,
  });

  final int processed;
  final int cleaned;
  final int skippedInvalid;
  final int remaining;

  factory MerchantCleanupResult.fromJson(Map<String, dynamic> json) => MerchantCleanupResult(
        processed: json['processed'] as int,
        cleaned: json['cleaned'] as int,
        skippedInvalid: json['skipped_invalid'] as int,
        remaining: json['remaining'] as int,
      );
}
