/// Plain JSON model for `POST /api/chatbot/policy-check/{policy_id}` —
/// mirrors `backend/app/chatbot/schemas.py`'s `PolicyResearchResponse`
/// (cost-cutting plan, items 7 and 8).
library;

/// Only [ok] carries a reply. The others leave the app showing the
/// facts-only check, plus a line saying why Penny didn't answer.
enum ResearchStatus {
  ok,
  paused,
  unavailable,
  noResults;

  static ResearchStatus fromWire(String? value) => switch (value) {
        'ok' => ok,
        'paused' => paused,
        'no_results' => noResults,
        // An unknown status from a newer backend reads as "no answer now".
        _ => unavailable,
      };
}

/// One page Penny read. Built by the server from the search results, never
/// from the model's reply, but [title] and [domain] still come from other
/// people's websites: the app shows them as plain text.
class ResearchSource {
  const ResearchSource({required this.title, required this.domain, required this.url, required this.retrievedAt});

  final String title;
  final String domain;
  final String url;
  final DateTime retrievedAt;

  /// The link the app may open: http(s) with a host and no user:password@,
  /// else null. The server already filters; this is the second lock.
  Uri? get safeUri {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return uri;
  }

  factory ResearchSource.fromJson(Map<String, dynamic> json) => ResearchSource(
        title: json['title'] as String,
        domain: json['domain'] as String,
        url: json['url'] as String,
        retrievedAt: DateTime.parse(json['retrieved_at'] as String),
      );
}

class PolicyResearch {
  const PolicyResearch({
    required this.policyId,
    required this.status,
    this.reply,
    this.sources = const [],
    this.checkedOn,
    this.pausedUntil,
  });

  final String policyId;
  final ResearchStatus status;
  final String? reply;
  final List<ResearchSource> sources;

  /// The oldest date behind the sources.
  final DateTime? checkedOn;
  final DateTime? pausedUntil;

  /// True when there is an answer to show; an "ok" with an empty reply is
  /// treated as no answer rather than a blank card.
  bool get hasReply => status == ResearchStatus.ok && (reply?.trim().isNotEmpty ?? false);

  factory PolicyResearch.fromJson(Map<String, dynamic> json) => PolicyResearch(
        policyId: json['policy_id'] as String,
        status: ResearchStatus.fromWire(json['status'] as String?),
        reply: json['reply'] as String?,
        sources: [
          for (final s in (json['sources'] as List? ?? const [])) ResearchSource.fromJson(s as Map<String, dynamic>),
        ],
        checkedOn: _date(json['checked_on']),
        pausedUntil: _date(json['paused_until']),
      );
}

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);
