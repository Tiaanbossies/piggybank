/// Plain JSON models for `/api/insights` — mirrors
/// `backend/app/insights/schemas.py`'s `InsightOut`/`InsightResponse`, and the
/// `date_scope`/`counts` shape assembled by `backend/app/services/ai_context.py`.
library;

class Insight {
  const Insight({
    required this.id,
    required this.generatedAt,
    required this.summaryText,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
  });

  final String id;
  final DateTime generatedAt;
  final String summaryText;
  final String model;
  final int? promptTokens;
  final int? completionTokens;

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        id: json['id'] as String,
        generatedAt: DateTime.parse(json['generated_at'] as String),
        summaryText: json['summary_text'] as String,
        model: json['model'] as String,
        promptTokens: json['prompt_tokens'] as int?,
        completionTokens: json['completion_tokens'] as int?,
      );
}

/// Result of a freshly-asked question — includes `dataScope`, which the
/// backend computes at answer-time but does not persist onto [Insight] rows,
/// so this richer detail is only ever available for the just-asked answer,
/// not for history entries re-fetched later.
class InsightAskResult {
  const InsightAskResult({
    required this.answer,
    required this.model,
    required this.dateScopeDays,
    required this.counts,
  });

  final String answer;
  final String model;
  final int? dateScopeDays;
  final Map<String, int> counts;

  factory InsightAskResult.fromJson(Map<String, dynamic> json) {
    final dataScope = json['data_scope'] as Map<String, dynamic>? ?? const {};
    final dateScope = dataScope['date_scope'] as Map<String, dynamic>? ?? const {};
    final counts = dataScope['counts'] as Map<String, dynamic>? ?? const {};
    return InsightAskResult(
      answer: json['answer'] as String,
      model: dataScope['model'] as String? ?? '',
      dateScopeDays: dateScope['days'] as int?,
      counts: counts.map((key, value) => MapEntry(key, value as int)),
    );
  }
}
