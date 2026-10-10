import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Category → icon mapping per the Stitch Transactions mockup, which shows a
/// distinct icon per merchant/category rather than one generic direction
/// arrow for every row. Shared by Transactions, the Dashboard's
/// recent-transactions preview, and Budgets rows so the same category
/// always gets the same icon everywhere.
///
/// Covers both the app's own canonical `commonCategories`
/// (transactions_provider.dart) and the real category vocabulary the demo
/// seed script + budgets use (`Petrol`, `Clothing`, `Medical`, `Dining Out`)
/// — the original mapping only covered the former, so real seeded data fell
/// through to the generic arrow for roughly half its categories. Matching is
/// case-insensitive since categories are free-text, user-entered fields.
IconData categoryIcon(String? category, {bool isExpense = true, bool isTransfer = false}) {
  switch (category?.trim().toLowerCase()) {
    case 'groceries':
      return Icons.shopping_cart_outlined;
    case 'dining':
    case 'dining out':
    case 'food':
      return Icons.restaurant_outlined;
    case 'transport':
    case 'gas':
    case 'petrol':
      return Icons.directions_car_outlined;
    case 'utilities':
      return Icons.bolt_outlined;
    case 'rent':
      return Icons.home_outlined;
    case 'shopping':
    case 'clothing':
      return Icons.shopping_bag_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'gym':
      return Icons.fitness_center_outlined;
    case 'healthcare':
    case 'medical':
      return Icons.local_hospital_outlined;
    case 'insurance':
      return Icons.shield_outlined;
    case 'salary':
    case 'freelance':
    case 'interest':
      return Icons.payments_outlined;
  }
  if (isTransfer) return Icons.swap_horiz;
  // A neutral tag, never a direction arrow: an arrow on an unknown category
  // read as "money went up/down", which the amount already says (S6).
  return Icons.sell_outlined;
}

/// Which tinted tile a category sits on (visual spec §1.3). A presentation
/// lookup over the same names as [categoryIcon]; nothing is stored.
CategoryFamily categoryFamily(String? category) {
  switch (category?.trim().toLowerCase()) {
    case 'groceries':
    case 'food':
    case 'salary':
    case 'freelance':
    case 'interest':
      return CategoryFamily.forest;
    case 'transport':
    case 'gas':
    case 'petrol':
      return CategoryFamily.ochre;
    case 'dining':
    case 'dining out':
    case 'shopping':
    case 'clothing':
    case 'entertainment':
      return CategoryFamily.clay;
    case 'utilities':
    case 'rent':
    case 'insurance':
    case 'gym':
    case 'healthcare':
    case 'medical':
      return CategoryFamily.sage;
  }
  return CategoryFamily.neutral;
}
