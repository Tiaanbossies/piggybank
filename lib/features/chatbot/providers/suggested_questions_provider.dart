import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../savings/providers/savings_provider.dart';

/// The starter questions shown before any data is in, and used to fill the
/// row up to three.
const genericPennyQuestions = [
  'How much did I spend on dining?',
  'Am I on track with my budget?',
  'Show my net worth trend',
];

/// Penny's suggestion chips (UX rework spec §2.5), built from the user's own
/// numbers so the empty chat opens on something worth asking (H4). UI-only
/// and derived from existing providers. In priority order:
/// 1. the category furthest over budget this month;
/// 2. the savings gap, when there is one;
/// then the generic questions, up to three chips.
///
/// A source that's loading or failed is skipped, so the row never fails.
/// The questions are plain asks, never alarms.
final suggestedQuestionsProvider = Provider.autoDispose<List<String>>((ref) {
  final questions = <String>[];

  final budgets = ref.watch(currentMonthBudgetProgressProvider).valueOrNull ?? const [];
  final over = budgets.where((b) => b.overBudget && b.category != null).toList()
    ..sort((a, b) => b.pctUsed.compareTo(a.pctUsed));
  if (over.isNotEmpty) questions.add('Why is ${over.first.category} over budget?');

  final gap = ref.watch(savingsOverviewProvider).valueOrNull?.gap;
  if (gap != null && gap > Decimal.zero) questions.add('Where should I cut to close my ${formatZAR(gap)} gap?');

  for (final q in genericPennyQuestions) {
    if (questions.length >= 3) break;
    questions.add(q);
  }
  return questions;
});
