import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/insights_api.dart';
import '../models/insight.dart';

/// History list — a plain `FutureProvider` fetch, same shape as
/// `importHistoryProvider`. Re-fetched (via invalidation) after every
/// successful ask so the just-asked question's persisted row appears here,
/// even though its richer `data_scope` detail is only ever shown on
/// [InsightsAskController.state.lastResult] (see that class's doc comment).
final insightHistoryProvider = FutureProvider.autoDispose<List<Insight>>((ref) {
  return ref.watch(insightsApiProvider).list();
});

/// Holds only the in-flight/just-asked state for the question box — the
/// answered-history list itself lives in [insightHistoryProvider], not here.
/// Follows the same `StateNotifier` pattern as `ChatbotController`.
class InsightsAskState {
  const InsightsAskState({this.asking = false, this.lastResult});

  final bool asking;
  final InsightAskResult? lastResult;

  InsightsAskState copyWith({bool? asking, InsightAskResult? lastResult}) =>
      InsightsAskState(asking: asking ?? this.asking, lastResult: lastResult ?? this.lastResult);
}

class InsightsAskController extends StateNotifier<InsightsAskState> {
  InsightsAskController(this._ref) : super(const InsightsAskState());

  final Ref _ref;

  /// Rethrows on failure (paywall vs. rate-limit vs. other) so the screen
  /// decides how to present it, matching `ChatbotController.sendMessage`.
  Future<void> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || state.asking) return;

    state = state.copyWith(asking: true);
    try {
      final result = await _ref.read(insightsApiProvider).ask(trimmed);
      state = InsightsAskState(asking: false, lastResult: result);
      _ref.invalidate(insightHistoryProvider);
    } catch (e) {
      state = state.copyWith(asking: false);
      rethrow;
    }
  }
}

final insightsAskControllerProvider = StateNotifierProvider.autoDispose<InsightsAskController, InsightsAskState>((ref) {
  return InsightsAskController(ref);
});
