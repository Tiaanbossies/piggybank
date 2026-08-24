import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/settings/models/subscription.dart';

void main() {
  group('Subscription.fromJson', () {
    test('parses a free-tier, active subscription with no period end', () {
      final sub = Subscription.fromJson({
        'tier': 'free',
        'status': 'active',
        'current_period_end': null,
      });

      expect(sub.tier, SubscriptionTier.free);
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.currentPeriodEnd, isNull);
      expect(sub.message, isNull);
    });

    test('parses a pro-tier subscription with a period end and upgrade message', () {
      final sub = Subscription.fromJson({
        'tier': 'pro',
        'status': 'active',
        'current_period_end': '2026-09-22T00:00:00Z',
        'message': 'Subscription upgraded to PRO.',
      });

      expect(sub.tier, SubscriptionTier.pro);
      expect(sub.currentPeriodEnd, DateTime.parse('2026-09-22T00:00:00Z'));
      expect(sub.message, 'Subscription upgraded to PRO.');
    });

    test('maps the past_due status (snake_case JSON to camelCase enum)', () {
      final sub = Subscription.fromJson({
        'tier': 'pro',
        'status': 'past_due',
        'current_period_end': null,
      });

      expect(sub.status, SubscriptionStatus.pastDue);
    });

    test('maps the cancelled status', () {
      final sub = Subscription.fromJson({
        'tier': 'free',
        'status': 'cancelled',
        'current_period_end': null,
      });

      expect(sub.status, SubscriptionStatus.cancelled);
    });
  });
}
