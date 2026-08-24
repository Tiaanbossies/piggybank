/// Plain JSON model for `/api/subscription` — mirrors
/// `backend/app/subscriptions/schemas.py`'s `SubscriptionOut`/
/// `SubscriptionUpgradeOut` (the two share every field this client needs;
/// `message` is only ever present on the upgrade response).
library;

enum SubscriptionTier { free, pro }

SubscriptionTier subscriptionTierFromJson(String value) =>
    SubscriptionTier.values.firstWhere((t) => t.name == value);

enum SubscriptionStatus { active, cancelled, pastDue }

SubscriptionStatus subscriptionStatusFromJson(String value) => switch (value) {
      'active' => SubscriptionStatus.active,
      'cancelled' => SubscriptionStatus.cancelled,
      'past_due' => SubscriptionStatus.pastDue,
      _ => throw ArgumentError('Unknown subscription status: $value'),
    };

class Subscription {
  const Subscription({
    required this.tier,
    required this.status,
    required this.currentPeriodEnd,
    this.message,
  });

  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? currentPeriodEnd;
  final String? message;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        tier: subscriptionTierFromJson(json['tier'] as String),
        status: subscriptionStatusFromJson(json['status'] as String),
        currentPeriodEnd:
            json['current_period_end'] == null ? null : DateTime.parse(json['current_period_end'] as String),
        message: json['message'] as String?,
      );
}
