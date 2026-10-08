import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/chatbot/models/policy_research.dart';

ResearchSource _source(String url) =>
    ResearchSource(title: 't', domain: 'd', url: url, retrievedAt: DateTime.utc(2026, 10, 1));

void main() {
  group('PolicyResearch.fromJson', () {
    test('reads an answer with its sources', () {
      final research = PolicyResearch.fromJson({
        'policy_id': 'p1',
        'status': 'ok',
        'reply': 'Published figures suggest…',
        'model': 'qwen2.5:3b-instruct-q4_K_M',
        'sources': [
          {
            'title': 'Car insurance costs',
            'domain': 'example.co.za',
            'url': 'https://example.co.za/a',
            'retrieved_at': '2026-10-01T09:00:00Z',
          },
        ],
        'checked_on': '2026-10-01',
        'paused_until': null,
      });

      expect(research.status, ResearchStatus.ok);
      expect(research.hasReply, isTrue);
      expect(research.sources.single.domain, 'example.co.za');
      expect(research.sources.single.retrievedAt, DateTime.utc(2026, 10, 1, 9));
      expect(research.checkedOn, DateTime(2026, 10, 1));
      expect(research.pausedUntil, isNull);
    });

    test('reads a paused check, and an unknown status as unavailable', () {
      final paused = PolicyResearch.fromJson({
        'policy_id': 'p1',
        'status': 'paused',
        'reply': null,
        'sources': <Object>[],
        'checked_on': null,
        'paused_until': '2026-11-01',
      });
      expect(paused.status, ResearchStatus.paused);
      expect(paused.pausedUntil, DateTime(2026, 11, 1));
      expect(paused.hasReply, isFalse);

      expect(PolicyResearch.fromJson({'policy_id': 'p1', 'status': 'something_new'}).status,
          ResearchStatus.unavailable);
      expect(PolicyResearch.fromJson({'policy_id': 'p1', 'status': 'no_results'}).status, ResearchStatus.noResults);
    });

    test('an ok with an empty reply is not an answer', () {
      expect(const PolicyResearch(policyId: 'p1', status: ResearchStatus.ok, reply: '  ').hasReply, isFalse);
    });
  });

  group('ResearchSource.safeUri', () {
    test('opens http and https links', () {
      expect(_source('https://example.co.za/a').safeUri.toString(), 'https://example.co.za/a');
      expect(_source('http://example.co.za/a').safeUri, isNotNull);
    });

    test('never opens other schemes, credentials or hostless links', () {
      for (final url in [
        'javascript:alert(1)',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///sdcard/x',
        'tel:0821234567',
        'https://user:pass@example.co.za/',
        'https:///nohost',
        'not a url',
      ]) {
        expect(_source(url).safeUri, isNull, reason: url);
      }
    });
  });
}
